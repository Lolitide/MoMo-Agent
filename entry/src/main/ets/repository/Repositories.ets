/*
 * ============================================================================
 * 文件名：repository/Repositories.ets
 * ============================================================================
 * 【用途】仓库层（数据出入口）：MemoryRepository（记忆增删清/恢复示例/订阅）、
 *   EventRepository（今日事件）、ComicRepository（今日漫画）、UserRepository（用户）。
 *   页面只依赖本层（UIKit -> Repository -> MockData/CloudDB）。
 *   另含演示模式支持：Memory/Event/Comic/User/MemoryTree/Companion 六个仓库都提供
 *   activateDemo()/deactivateDemo()，切换时快照真实数据、退出时原样还原。
 * 【前置条件 / 假设】
 *   - 依赖：MockData、DemoMockData、Models、DateUtil、CloudDBService；
 *   - 假设：单例（get()）；支持本地内存 + 云端持久化；事件总线为静态回调数组；
 *   - 假设：演示态由 DemoModeService 统一协调，仓库自身不判断「是否应该进演示态」，
 *     只负责在被告知时切换，并在演示态下短路一切落盘/联网动作。
 * 【输入 / 输出（后置条件）】
 *   - 输入：add/update/delete/clearAll/restoreSamples 等写操作；getAll/getById 读操作；
 *   - 输出：读操作返回数据（clone 或直接引用，约定只读）；
 *     写操作触发 subscribe 监听者（页面刷新视图）；
 *   - 后置：clearAll 后可用 restoreSamples() 复原演示数据。
 * 【关键类 / 算法】
 *   - 发布-订阅（pub/sub）：register/unregister + notify 循环调用；
 *   - getToday()：按日期过滤；loadFailed 模拟错误（漫画页错误态）。
 * 【参考源】
 *   - 废案 repository/（EventRepository/ComicRepository/…）；MVC/MVVM 分层惯例
 * ============================================================================
 */
import { MockData } from '../mock/MockData';
import { DemoMockData } from '../mock/DemoMockData';
import {
  Comic, ComicPage, CompanionState, DailyMemory, EventItem, Memory, MemoryTreeNode, MemoryType, User,
  PersonalityProfile
} from '../model/Models';
import { LongTermMemory } from '../service/cloud/CloudDBModels';
import { CloudDBService } from '../service/cloud/CloudDBService';
import { SystemDataService, SystemEvent } from '../service/system/SystemDataService';
import { AIServiceCloud } from '../service/ai/AIServiceCloud';
import { OnboardingService } from '../service/OnboardingService';

export type RepoListener = () => void;

// 记忆仓库（单例）：内存数组 + 云端持久化 + 发布订阅；add/update/delete/clearAll 后 notify 全量刷新花园视图
export class MemoryRepository {
  private static instance: MemoryRepository | null = null;
  private memories: Memory[] = MockData.buildMemories();
  private listeners: RepoListener[] = [];
  private isCloudEnabled: boolean = false;
  private userId: string = '';
  // ===== 演示态（内存隔离区）=====
  // demoActive 为 true 时，memories 指向 DemoMockData 的实例数组，
  // 所有写操作只改内存、不落盘、不上云；deactivateDemo() 用 realMemories 还原。
  private demoActive: boolean = false;
  private realMemories: Memory[] = [];
  private realUserId: string = '';
  private realCloudEnabled: boolean = false;

  static get(): MemoryRepository {
    if (MemoryRepository.instance === null) {
      MemoryRepository.instance = new MemoryRepository();
    }
    return MemoryRepository.instance;
  }

  /**
   * 是否处于演示内存区
   */
  isDemo(): boolean {
    return this.demoActive;
  }

  /**
   * 切换到演示内存区：先快照真实数据引用与云端开关，再灌入演示种子。
   * 清空 userId + 关闭 isCloudEnabled，使 syncToCloud/deleteFromCloud 直接短路。
   */
  activateDemo(): void {
    if (this.demoActive) {
      return;
    }
    this.realMemories = this.memories;
    this.realUserId = this.userId;
    this.realCloudEnabled = this.isCloudEnabled;
    // 断开云身份，配合下方 syncToCloud/deleteFromCloud 的守卫形成双保险
    this.userId = '';
    this.isCloudEnabled = false;
    this.demoActive = true;
    this.memories = DemoMockData.buildMemories();
    this.notify();
  }

  /**
   * 丢弃演示数据并还原真实数据。直接替换数组引用，不走 add()，
   * 因此不会触发 DataSyncService 的游客持久化监听。
   */
  deactivateDemo(): void {
    if (!this.demoActive) {
      return;
    }
    this.memories = this.realMemories;
    this.userId = this.realUserId;
    this.isCloudEnabled = this.realCloudEnabled;
    this.realMemories = [];
    this.demoActive = false;
    this.notify();
  }

  /**
   * 启用云端同步
   */
  async enableCloudSync(userId: string): Promise<void> {
    if (this.demoActive) {
      // 演示态下不建立云同步：演示数据只应留在内存里
      return;
    }
    this.userId = userId;
    this.isCloudEnabled = true;

    try {
      // 从云端加载数据
      await this.loadFromCloud();
    } catch (err) {
      console.error('从云端加载记忆失败:', err);
    }
  }

  /**
   * 从云端加载记忆
   */
  private async loadFromCloud(): Promise<void> {
    if (!this.isCloudEnabled || !this.userId || this.demoActive) {
      return;
    }

    try {
      const cloudDB = CloudDBService.get();

      const cloudMemories = await cloudDB.getUserMemories(this.userId);

      // 转换为 Memory 对象
      this.memories = cloudMemories.map(cm => this.cloudMemoryToMemory(cm));

      this.notify();
    } catch (err) {
      console.error('加载云端记忆失败:', err);
      return Promise.reject(new Error(`加载云端记忆失败: ${err}`));
    }
  }

  /**
   * 云端记忆转本地记忆
   */
  private cloudMemoryToMemory(cloudMemory: LongTermMemory): Memory {
    const dateObj = new Date(cloudMemory.dateTimestamp);
    const memory = new Memory(
      cloudMemory.memoryId,
      cloudMemory.title,
      dateObj,
      cloudMemory.type as MemoryType,
      cloudMemory.importance
    );
    memory.tags = cloudMemory.getTags();
    memory.summary = cloudMemory.summary;
    memory.content = cloudMemory.content;
    memory.sourceEvents = cloudMemory.getSourceEvents();
    memory.relatedMemoryIds = cloudMemory.getRelatedMemoryIds();
    return memory;
  }

  /**
   * 本地记忆转云端记忆
   */
  private async memoryToCloudMemory(memory: Memory): Promise<LongTermMemory> {
    const cloudMemory = new LongTermMemory(this.userId, memory.id);
    cloudMemory.title = memory.title;
    cloudMemory.date = memory.date;
    cloudMemory.dateTimestamp = memory.dateObj.getTime();
    cloudMemory.summary = memory.summary;
    cloudMemory.content = memory.content;
    cloudMemory.type = memory.type;
    cloudMemory.importance = memory.importance;
    cloudMemory.setTags(memory.tags);
    cloudMemory.setSourceEvents(memory.sourceEvents);
    cloudMemory.setRelatedMemoryIds(memory.relatedMemoryIds);

    return cloudMemory;
  }

  /**
   * 同步到云端
   */
  private async syncToCloud(memory: Memory): Promise<void> {
    if (!this.isCloudEnabled || !this.userId) {
      return;
    }

    try {
      const cloudDB = CloudDBService.get();

      const cloudMemory = await this.memoryToCloudMemory(memory);
      await cloudDB.upsertMemory(cloudMemory);
    } catch (err) {
      console.error('同步记忆到云端失败:', err);
      // 不抛出错误，允许离线操作
    }
  }

  /**
   * 从云端删除
   */
  private async deleteFromCloud(memoryId: string): Promise<void> {
    if (!this.isCloudEnabled || !this.userId) {
      return;
    }

    try {
      const cloudDB = CloudDBService.get();

      const cloudMemory = await cloudDB.getMemory(this.userId, memoryId);
      if (cloudMemory) {
        await cloudDB.deleteMemory(cloudMemory);
      }
    } catch (err) {
      console.error('从云端删除记忆失败:', err);
    }
  }

  getAll(): Memory[] {
    return this.memories;
  }

  getById(id: string): Memory | null {
    for (let i = 0; i < this.memories.length; i++) {
      if (this.memories[i].id === id) {
        return this.memories[i];
      }
    }
    return null;
  }

  add(m: Memory): void {
    this.memories.unshift(m);
    // 演示态：只改内存，不落盘、不上云
    if (this.demoActive) {
      this.notify();
      return;
    }
    this.syncToCloud(m);
    this.notify();
  }

  update(m: Memory): void {
    for (let i = 0; i < this.memories.length; i++) {
      if (this.memories[i].id === m.id) {
        this.memories[i] = m;
        break;
      }
    }
    if (this.demoActive) {
      this.notify();
      return;
    }
    this.syncToCloud(m);
    this.notify();
  }

  delete(id: string): void {
    const next: Memory[] = [];
    for (let i = 0; i < this.memories.length; i++) {
      if (this.memories[i].id !== id) {
        next.push(this.memories[i]);
      }
    }
    this.memories = next;
    if (this.demoActive) {
      this.notify();
      return;
    }
    this.deleteFromCloud(id);
    this.notify();
  }

  clearAll(): void {
    this.memories = [];
    this.notify();
  }

  restoreSamples(): void {
    // 演示态下「恢复示例数据」应恢复成演示种子（条数由设置页的演示条数决定），
    // 而不是普通 Mock 的 8 条
    this.memories = this.demoActive ? DemoMockData.buildMemories() : MockData.buildMemories();
    this.notify();
  }

  /**
   * 演示态下按当前设置的条数重建演示记忆（设置页拖动「演示记忆条数」后调用）。
   * 【为什么必须单独开一个方法】restoreSamples() 在非演示态会把真实记忆替换成示例数据，
   * 而本方法在非演示态是**空操作** —— 调条数绝不能碰真实数据。
   * 非演示态只把数字记在 DemoMockData 里，等下次 enable() 生效。
   */
  refreshDemoData(): boolean {
    if (!this.demoActive) {
      return false;
    }
    this.memories = DemoMockData.buildMemories();
    this.notify();
    return true;
  }

  subscribe(cb: RepoListener): void {
    this.listeners.push(cb);
  }

  unsubscribe(cb: RepoListener): void {
    const next: RepoListener[] = [];
    for (let i = 0; i < this.listeners.length; i++) {
      if (this.listeners[i] !== cb) {
        next.push(this.listeners[i]);
      }
    }
    this.listeners = next;
  }

  private notify(): void {
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i]();
    }
  }
}

export class EventRepository {
  private static instance: EventRepository | null = null;
  private isGenerating: boolean = false;
  private systemDataService: SystemDataService | null = null;
  private useSystemData: boolean = false;
  private isCloudEnabled: boolean = false;
  private userId: string = '';
  private cachedDailyMemory: DailyMemory | null = null;
  // ===== 演示态 =====
  private demoActive: boolean = false;
  private realDailyMemory: DailyMemory | null = null;
  private realCloudEnabled: boolean = false;

  static get(): EventRepository {
    if (EventRepository.instance === null) {
      EventRepository.instance = new EventRepository();
    }
    return EventRepository.instance;
  }

  /**
   * 是否处于演示态
   */
  isDemo(): boolean {
    return this.demoActive;
  }

  /**
   * 切换到演示态：快照当天的真实缓存与云开关，改用预制 L1 数据
   */
  activateDemo(): void {
    if (this.demoActive) {
      return;
    }
    this.realDailyMemory = this.cachedDailyMemory;
    this.realCloudEnabled = this.isCloudEnabled;
    this.isCloudEnabled = false;
    this.demoActive = true;
    this.cachedDailyMemory = DemoMockData.buildDailyMemory();
  }

  /**
   * 丢弃演示缓存，还原进入前的真实当日缓存与云开关
   */
  deactivateDemo(): void {
    if (!this.demoActive) {
      return;
    }
    this.cachedDailyMemory = this.realDailyMemory;
    this.isCloudEnabled = this.realCloudEnabled;
    this.realDailyMemory = null;
    this.demoActive = false;
  }

  /**
   * 启用云端同步
   */
  async enableCloudSync(userId: string): Promise<void> {
    this.userId = userId;
    this.isCloudEnabled = true;
  }

  /**
   * 初始化系统数据服务
   */
  async initSystemData(context: Context): Promise<void> {
    try {
      this.systemDataService = SystemDataService.get();
      await this.systemDataService.initialize(context);
      this.useSystemData = this.systemDataService.hasPermissions();
      console.info('系统数据服务初始化成功，useSystemData:', this.useSystemData);
    } catch (err) {
      console.error('系统数据服务初始化失败:', err);
      this.useSystemData = false;
    }
  }

  /**
   * 获取今天的日期（YYYY-MM-DD）
   */
  private getTodayDate(): string {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  /**
   * 获取今天的日期（YYYY.MM.DD 格式，用于显示）
   */
  private getTodayDisplayDate(): string {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    return `${year}.${month}.${day}`;
  }

  /**
   * 获取今日记忆（优先云端，然后系统数据，最后降级到 Mock）
   */
  async getToday(): Promise<DailyMemory> {
    // 演示态：直接用预制 L1，跳过云端与系统数据读取（保证现场无网也秒开）
    if (this.demoActive) {
      if (this.cachedDailyMemory === null) {
        this.cachedDailyMemory = DemoMockData.buildDailyMemory();
      }
      return this.cachedDailyMemory;
    }
    if (this.cachedDailyMemory && this.cachedDailyMemory.date === this.getTodayDisplayDate()) {
      return this.cachedDailyMemory;
    }
    // 优先从云端加载
    if (this.isCloudEnabled && this.userId) {
      try {
        const cloudDB = CloudDBService.get();

        const today = this.getTodayDate();
        const record = await cloudDB.getDailyRecord(this.userId, today);

        if (record && record.summary) {
          const dailyMemory = new DailyMemory();
          dailyMemory.date = this.getTodayDisplayDate();
          dailyMemory.summary = record.summary;
          const cloudEvents = record.getEvents();
          const eventItems: EventItem[] = [];
          for (let i = 0; i < cloudEvents.length; i++) {
            const event = cloudEvents[i];
            eventItems.push(new EventItem(`event_${i}`, event.content, event.time, 'life', event.content));
          }
          dailyMemory.events = eventItems;

          this.cachedDailyMemory = dailyMemory;
          console.info('从云端加载今日记忆成功');
          return dailyMemory;
        }
      } catch (err) {
        console.error('从云端加载今日记忆失败:', err);
      }
    }

    // 如果启用了系统数据，尝试读取
    if (this.useSystemData && this.systemDataService) {
      try {
        const systemEvents: SystemEvent[] = await this.systemDataService.getTodayEvents();

        if (systemEvents.length > 0) {
          const daily = new DailyMemory();
          daily.date = this.getTodayDisplayDate();
          daily.summary = ''; // 等待生成
          const eventItems: EventItem[] = [];
          for (let i = 0; i < systemEvents.length; i++) {
            const event = systemEvents[i];
            eventItems.push(new EventItem(event.id, event.title, event.time, event.category, event.description));
          }
          daily.events = eventItems;

          console.info(`从系统读取到 ${systemEvents.length} 个事件`);
          return daily;
        }
      } catch (err) {
        console.error('读取系统数据失败，降级到 Mock:', err);
      }
    }

    // 降级：返回 Mock 数据
    return MockData.buildDailyMemory();
  }

  /**
   * 生成今日总结（调用 AI 服务）
   */
  async generateDailySummary(events: EventItem[], mood?: string): Promise<string> {
    // 演示态：不联网，秒回预制文案（现场演示的稳定性优先）
    if (this.demoActive) {
      const summary = DemoMockData.demoDailySummaryText();
      const daily = new DailyMemory();
      daily.date = this.getTodayDisplayDate();
      daily.events = events;
      daily.insights = this.cachedDailyMemory ? this.cachedDailyMemory.insights : [];
      daily.summary = summary;
      this.cachedDailyMemory = daily;
      return summary;
    }

    if (this.isGenerating) {
      const error = new Error('正在生成中，请稍候');
      return Promise.reject(error);
    }

    this.isGenerating = true;
    try {
      const summary = await AIServiceCloud.get().generateDailySummary(events, mood);
      const daily = new DailyMemory();
      daily.date = this.getTodayDisplayDate();
      daily.events = events;
      daily.summary = summary;
      this.cachedDailyMemory = daily;
      return summary;
    } catch (err) {
      console.error('真实云端总结生成失败:', err);
      throw new Error(String(err));
    } finally {
      this.isGenerating = false;
    }
  }

  updateTodaySummary(summary: string, events: EventItem[]): void {
    const daily = new DailyMemory();
    daily.date = this.getTodayDisplayDate();
    daily.events = events;
    daily.summary = summary;
    this.cachedDailyMemory = daily;
  }

  async appendCheckIn(text: string): Promise<DailyMemory> {
    // 首次真实打卡不混入演示数据；已有云端/系统数据时沿用当天缓存。
    let daily: DailyMemory;
    if (this.cachedDailyMemory && this.cachedDailyMemory.date === this.getTodayDisplayDate()) {
      daily = this.cachedDailyMemory;
    } else {
      daily = new DailyMemory();
      daily.date = this.getTodayDisplayDate();
    }
    const event = new EventItem(`checkin_${Date.now()}`, '你告诉默默的此刻', this.getCurrentTime(), 'life', text);
    const events: EventItem[] = [];
    for (let i = 0; i < daily.events.length; i++) {
      events.push(daily.events[i]);
    }
    events.unshift(event);
    const updated = new DailyMemory();
    updated.date = daily.date;
    updated.summary = '';
    updated.events = events;
    updated.insights = daily.insights;
    this.cachedDailyMemory = updated;
    return updated;
  }

  private getCurrentTime(): string {
    const now = new Date();
    return `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
  }

  /**
   * 获取历史总结记录
   */
  async getHistorySummaries(limit: number): Promise<DailyMemory[]> {
    try {
      const records = await AIServiceCloud.get().getHistorySummaries(limit);

      const result: DailyMemory[] = [];
      for (let i = 0; i < records.length; i++) {
        const record = records[i];
        const daily = new DailyMemory();
        daily.date = record.date;
        daily.summary = record.summary;
        const sourceEvents = record.getEvents();
        const eventItems: EventItem[] = [];
        for (let j = 0; j < sourceEvents.length; j++) {
          const e = sourceEvents[j];
          const item = new EventItem(`event_${j}`, e.content, e.time, 'life', e.content);
          eventItems.push(item);
        }
        daily.events = eventItems;
        result.push(daily);
      }
      return result;
    } catch (err) {
      console.error('获取历史记录失败:', err);
      return [MockData.buildDailyMemory()];
    }
  }
}

export class ComicRepository {
  private static instance: ComicRepository | null = null;
  loadFailed: boolean = false;
  private isGenerating: boolean = false;
  private generatedComic: Comic | null = null;
  private generatedScript: ComicPanel[] | null = null;
  // ===== 演示态 =====
  private demoActive: boolean = false;
  private demoComic: Comic | null = null;
  private realGeneratedComic: Comic | null = null;
  private realGeneratedScript: ComicPanel[] | null = null;

  static get(): ComicRepository {
    if (ComicRepository.instance === null) {
      ComicRepository.instance = new ComicRepository();
    }
    return ComicRepository.instance;
  }

  /**
   * 是否处于演示态
   */
  isDemo(): boolean {
    return this.demoActive;
  }

  /**
   * 切换到演示态：快照真实生成结果，再载入预制漫画。
   * 预制漫画同时填入 generatedComic 与 generatedScript，使
   * A_Home（getGeneratedToday）、B_DailyComic（getGeneratedToday）、
   * B_ComicViewer（getToday）三条路径拿到同一批占位图。
   */
  activateDemo(): void {
    if (this.demoActive) {
      return;
    }
    this.realGeneratedComic = this.generatedComic;
    this.realGeneratedScript = this.generatedScript;
    this.demoComic = DemoMockData.buildComic();
    this.generatedComic = this.demoComic;
    this.generatedScript = DemoMockData.buildComicPanels();
    this.demoActive = true;
  }

  /**
   * 丢弃演示漫画，还原进入前的生成结果
   */
  deactivateDemo(): void {
    if (!this.demoActive) {
      return;
    }
    this.generatedComic = this.realGeneratedComic;
    this.generatedScript = this.realGeneratedScript;
    this.realGeneratedComic = null;
    this.realGeneratedScript = null;
    this.demoComic = null;
    this.demoActive = false;
  }

  /**
   * 纯本地的演示漫画生成：不联网，供「生成演示漫画」与真实生成的失败降级复用
   */
  generateDemoTodayComic(): Comic {
    const comic = DemoMockData.buildComic();
    this.demoComic = comic;
    this.generatedComic = comic;
    this.generatedScript = DemoMockData.buildComicPanels();
    return comic;
  }

  getToday(): Comic {
    // 演示态优先返回预制漫画：否则会落到 MockData.buildComic()（该结果没有图片，
    // 与「演示态必须首屏有内容」冲突）
    if (this.demoActive && this.demoComic !== null) {
      return this.demoComic;
    }
    return this.generatedComic || MockData.buildComic();
  }

  getGeneratedToday(): Comic | null {
    return this.generatedComic;
  }

  /**
   * 已生成的漫画分镜脚本（用户可能选了其中一套，供重新生成图片时复用）
   */
  getGeneratedScript(): ComicPanel[] | null {
    return this.generatedScript;
  }

  /**
   * 登记一份由网关生成的漫画（脚本 + 出图已完成）。
   * 供走 DemoAIGateway 的调用链使用：页面先拿到 Comic，再回填到仓库，
   * 使首页卡片、今日漫画页、漫画查看器读到同一份结果。
   */
  setGeneratedComic(comic: Comic, panels?: ComicPanel[]): void {
    this.generatedComic = comic;
    if (panels !== undefined) {
      this.generatedScript = panels;
    }
  }

  /**
   * 生成今日漫画（调用 AI 服务）
   */
  async generateTodayComic(summary: string, events: EventItem[], profile?: PersonalityProfile): Promise<Comic> {
    if (this.isGenerating) {
      const error = new Error('正在生成中，请稍候');
      return Promise.reject(error);
    }

    this.isGenerating = true;
    try {
      const panels = await AIServiceCloud.get().generateComicScript(summary, events, profile);
      const imageUrls = await AIServiceCloud.get().generateComicImages(panels);

      const comic = new Comic();
      comic.id = `comic-${Date.now()}`;
      comic.date = this.getToday().date;
      comic.sourceDate = comic.date;
      comic.title = `默默的一天 vol.${Date.now() % 100}`;
      comic.message = '今天也有好好陪你，明天见面的路上记得看一眼窗外的云。';
      comic.profileVersion = profile ? profile.version : 0;
      comic.styleKey = profile ? profile.comicStyle : '';
      comic.generationStatus = 'success';

      const comicPages: ComicPage[] = [];
      for (let i = 0; i < panels.length; i++) {
        const panel = panels[i];
        const page = new ComicPage();
        page.index = i;
        page.title = panel.description || `分镜 ${i + 1}`;
        page.image = imageUrls[i];
        comicPages.push(page);
      }
      comic.pages = comicPages;
      this.generatedComic = comic;
      this.generatedScript = panels;

      return comic;
    } catch (err) {
      console.error('真实云端漫画生成失败:', err);
      throw new Error(String(err));
    } finally {
      this.isGenerating = false;
    }
  }

  /**
   * 仅生成漫画脚本（用于预览）
   */
  async generateComicScript(summary: string, events: EventItem[]): Promise<ComicPanel[]> {
    try {
      return await AIServiceCloud.get().generateComicScript(summary, events);
    } catch (err) {
      console.error('生成漫画脚本失败:', err);
      const emptyPanels: ComicPanel[] = [];
      return emptyPanels;
    }
  }
}

interface ComicPanel {
  title?: string;
  prompt: string;
  description?: string;
  imageUrl?: string;
}

export class UserRepository {
  private static instance: UserRepository | null = null;
  private cachedUser: User = new User();
  private loaded: boolean = false;
  // ===== 演示态 =====
  // 演示身份只存在于内存：activateDemo() 覆盖缓存与 loaded 标记，
  // deactivateDemo() 用 realCachedUser / realLoaded 原样还原，
  // 全程不读写 momo_onboarding_v1，因此不会污染游客的真实档案。
  private demoActive: boolean = false;
  private realCachedUser: User = new User();
  private realLoaded: boolean = false;

  static get(): UserRepository {
    if (UserRepository.instance === null) {
      UserRepository.instance = new UserRepository();
    }
    return UserRepository.instance;
  }

  /**
   * 是否处于演示态
   */
  isDemo(): boolean {
    return this.demoActive;
  }

  /**
   * 切换到演示身份：档案预置为「已完成」，因此不会被 OnboardingProfilePage 拦截
   */
  activateDemo(): void {
    if (this.demoActive) {
      return;
    }
    this.realCachedUser = this.cachedUser;
    this.realLoaded = this.loaded;
    this.cachedUser = DemoMockData.buildUser();
    this.loaded = true;
    this.demoActive = true;
  }

  /**
   * 还原真实身份缓存
   */
  deactivateDemo(): void {
    if (!this.demoActive) {
      return;
    }
    this.cachedUser = this.realCachedUser;
    this.loaded = this.realLoaded;
    this.realCachedUser = new User();
    this.realLoaded = false;
    this.demoActive = false;
  }

  getUser(): User {
    return this.cachedUser;
  }

  clearCachedProfile(): void {
    // 演示态下不清理演示身份：设置页的「重新体验首次打卡」在演示中应保持可用
    if (this.demoActive) {
      return;
    }
    this.cachedUser = new User();
    this.loaded = false;
  }

  async load(): Promise<User> {
    // 演示态：不读也不会写 OnboardingService（momo_onboarding_v1）
    if (this.demoActive) {
      return this.cachedUser;
    }
    const service = OnboardingService.get();
    const userId = await service.getCurrentUserId();
    const profile = await service.loadProfile(userId);
    this.cachedUser = service.profileToUser(userId, this.cachedUser.name, profile);
    this.loaded = true;
    return this.cachedUser;
  }

  async saveProfile(profile: PersonalityProfile): Promise<User> {
    // 演示态：只改内存，演示结束后随缓存一起丢弃
    if (this.demoActive) {
      this.cachedUser.profile = profile;
      this.cachedUser.profileCompleted = true;
      this.cachedUser.profileVersion = profile.version;
      this.loaded = true;
      return this.cachedUser;
    }
    const service = OnboardingService.get();
    const userId = await service.getCurrentUserId();
    await service.saveProfile(userId, profile);
    this.cachedUser.profile = profile;
    this.cachedUser.profileCompleted = true;
    this.cachedUser.profileVersion = profile.version;
    this.loaded = true;
    return this.cachedUser;
  }

  async isProfileCompleted(): Promise<boolean> {
    if (!this.loaded) {
      await this.load();
    }
    return this.cachedUser.profileCompleted;
  }
}

export class CompanionRepository {
  private static instance: CompanionRepository | null = null;

  static get(): CompanionRepository {
    if (CompanionRepository.instance === null) {
      CompanionRepository.instance = new CompanionRepository();
    }
    return CompanionRepository.instance;
  }

  getState(): CompanionState {
    // 演示态：给默默一个更「有精神」的初始状态，便于现场展示动作表现
    if (MemoryRepository.get().isDemo()) {
      return DemoMockData.buildCompanion();
    }
    return MockData.buildCompanion();
  }
}

export class MemoryTreeRepository {
  private static instance: MemoryTreeRepository | null = null;

  static get(): MemoryTreeRepository {
    if (MemoryTreeRepository.instance === null) {
      MemoryTreeRepository.instance = new MemoryTreeRepository();
    }
    return MemoryTreeRepository.instance;
  }

  getTree(): MemoryTreeNode {
    // 演示态：返回与 14 条演示记忆一致的分组，避免出现树里没有的节点
    if (MemoryRepository.get().isDemo()) {
      return DemoMockData.buildTreeNodes();
    }
    return MockData.buildTreeNodes();
  }

  findNode(root: MemoryTreeNode | null, id: string): MemoryTreeNode | null {
    if (root === null) {
      return null;
    }
    if (root.id === id) {
      return root;
    }
    for (let i = 0; i < root.children.length; i++) {
      const found = this.findNode(root.children[i], id);
      if (found !== null) {
        return found;
      }
    }
    return null;
  }

  collectNodeIds(root: MemoryTreeNode | null, ids: string[]): void {
    if (root === null) {
      return;
    }
    ids.push(root.id);
    for (let i = 0; i < root.children.length; i++) {
      this.collectNodeIds(root.children[i], ids);
    }
  }

  findMemoryByNode(root: MemoryTreeNode | null, id: string): Memory | null {
    const node = this.findNode(root, id);
    if (node === null) {
      return null;
    }
    if (node.type === 'memory') {
      const m = MemoryRepository.get().getById(id);
      if (m !== null) {
        return m;
      }
    }
    return null;
  }
}

export class MemoryTypeUtilSafe {
  static makeMemory(id: string, title: string, summary: string, content: string, type: MemoryType): Memory {
    const m = new Memory(id, title, new Date(), type, 2);
    m.summary = summary;
    m.content = content;
    return m;
  }
}
