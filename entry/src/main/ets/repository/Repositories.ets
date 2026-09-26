/*
 * ============================================================================
 * 文件名：repository/Repositories.ets
 * ============================================================================
 * 【用途】仓库层（数据出入口）：MemoryRepository（记忆增删清/恢复示例/订阅）、
 *   EventRepository（今日事件）、ComicRepository（今日漫画）、UserRepository（用户）。
 *   页面只依赖本层（UIKit -> Repository -> MockData/CloudDB）。
 * 【前置条件 / 假设】
 *   - 依赖：MockData、Models、DateUtil、CloudDBService；
 *   - 假设：单例（get()）；支持本地内存 + 云端持久化；事件总线为静态回调数组。
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
import {
  Comic, CompanionState, DailyMemory, Memory, MemoryTreeNode, MemoryType, User
} from '../model/Models';

export type RepoListener = () => void;

// 记忆仓库（单例）：内存数组 + 云端持久化 + 发布订阅；add/update/delete/clearAll 后 notify 全量刷新花园视图
export class MemoryRepository {
  private static instance: MemoryRepository | null = null;
  private memories: Memory[] = MockData.buildMemories();
  private listeners: RepoListener[] = [];
  private isCloudEnabled: boolean = false;
  private userId: string = '';

  static get(): MemoryRepository {
    if (MemoryRepository.instance === null) {
      MemoryRepository.instance = new MemoryRepository();
    }
    return MemoryRepository.instance;
  }

  /**
   * 启用云端同步
   */
  async enableCloudSync(userId: string): Promise<void> {
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
    if (!this.isCloudEnabled || !this.userId) {
      return;
    }

    try {
      const { CloudDBService } = await import('../service/cloud/CloudDBService');
      const cloudDB = CloudDBService.get();

      const cloudMemories = await cloudDB.getUserMemories(this.userId);

      // 转换为 Memory 对象
      this.memories = cloudMemories.map(cm => this.cloudMemoryToMemory(cm));

      this.notify();
    } catch (err) {
      console.error('加载云端记忆失败:', err);
      throw err;
    }
  }

  /**
   * 云端记忆转本地记忆
   */
  private cloudMemoryToMemory(cloudMemory: any): Memory {
    const dateObj = new Date(cloudMemory.dateTimestamp);
    const memory = new Memory(
      cloudMemory.memoryId,
      cloudMemory.title,
      dateObj,
      cloudMemory.type,
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
  private async memoryToCloudMemory(memory: Memory): Promise<any> {
    const { LongTermMemory } = await import('../service/cloud/CloudDBModels');

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
      const { CloudDBService } = await import('../service/cloud/CloudDBService');
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
      const { CloudDBService } = await import('../service/cloud/CloudDBService');
      const { LongTermMemory } = await import('../service/cloud/CloudDBModels');
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
    this.deleteFromCloud(id);
    this.notify();
  }

  clearAll(): void {
    this.memories = [];
    this.notify();
  }

  restoreSamples(): void {
    this.memories = MockData.buildMemories();
    this.notify();
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
  private systemDataService: any = null;
  private useSystemData: boolean = false;
  private isCloudEnabled: boolean = false;
  private userId: string = '';
  private cachedDailyMemory: DailyMemory | null = null;

  static get(): EventRepository {
    if (EventRepository.instance === null) {
      EventRepository.instance = new EventRepository();
    }
    return EventRepository.instance;
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
      const { SystemDataService } = await import('../service/system/SystemDataService');
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
    // 优先从云端加载
    if (this.isCloudEnabled && this.userId) {
      try {
        const { CloudDBService } = await import('../service/cloud/CloudDBService');
        const cloudDB = CloudDBService.get();

        const today = this.getTodayDate();
        const record = await cloudDB.getDailyRecord(this.userId, today);

        if (record && record.summary) {
          const dailyMemory = new DailyMemory();
          dailyMemory.date = this.getTodayDisplayDate();
          dailyMemory.summary = record.summary;
          dailyMemory.events = record.getEvents().map((e, index) => ({
            id: `event_${index}`,
            title: e.content,
            time: e.time,
            category: 'life',
            description: e.content
          }));

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
        const systemEvents = await this.systemDataService.getTodayEvents();

        if (systemEvents.length > 0) {
          const daily = new DailyMemory();
          daily.date = this.getTodayDisplayDate();
          daily.summary = ''; // 等待生成
          daily.events = systemEvents.map((e, index) => ({
            id: e.id,
            title: e.title,
            time: e.time,
            category: e.category,
            description: e.description
          }));

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
   * @param events 今日事件列表
   * @param mood 心情（可选）
   * @returns Promise<string> 生成的总结文本
   */
  async generateDailySummary(events: any[], mood?: string): Promise<string> {
    if (this.isGenerating) {
      throw new Error('正在生成中，请稍候');
    }

    this.isGenerating = true;
    try {
      const { AIServiceCloud } = await import('../service/ai/AIServiceCloud');
      const summary = await AIServiceCloud.get().generateDailySummary(events, mood);

      // 更新缓存
      if (this.cachedDailyMemory) {
        this.cachedDailyMemory.summary = summary;
      }

      return summary;
    } catch (err) {
      // AI 服务失败，降级到 Mock
      console.error('生成总结失败，使用 Mock 数据:', err);
      return MockData.buildDailyMemory().summary;
    } finally {
      this.isGenerating = false;
    }
  }

  /**
   * 获取历史总结记录
   * @param limit 查询数量
   * @returns Promise<DailyMemory[]>
   */
  async getHistorySummaries(limit: number = 30): Promise<DailyMemory[]> {
    if (!this.isCloudEnabled || !this.userId) {
      return [MockData.buildDailyMemory()];
    }

    try {
      const { AIServiceCloud } = await import('../service/ai/AIServiceCloud');
      const records = await AIServiceCloud.get().getHistorySummaries(limit);

      // 转换为 DailyMemory 格式
      return records.map(record => {
        const daily = new DailyMemory();
        daily.date = record.date;
        daily.summary = record.summary;
        daily.events = record.getEvents().map((e, index) => ({
          id: `event_${index}`,
          title: e.content,
          time: e.time,
          category: 'life',
          description: e.content
        }));
        return daily;
      });
    } catch (err) {
      console.error('获取历史记录失败:', err);
      return [MockData.buildDailyMemory()];
    }
  }

  /**
   * 保存今日事件到云端
   * @param events 今日事件列表
   * @param mood 心情（可选）
   */
  async saveTodayEvents(events: any[], mood?: string): Promise<void> {
    if (!this.isCloudEnabled || !this.userId) {
      return;
    }

    try {
      const { CloudDBService } = await import('../service/cloud/CloudDBService');
      const { DailyRecord } = await import('../service/cloud/CloudDBModels');
      const cloudDB = CloudDBService.get();

      const today = this.getTodayDate();
      let record = await cloudDB.getDailyRecord(this.userId, today);

      if (!record) {
        record = new DailyRecord(this.userId, today);
      }

      record.mood = mood || '平静';
      record.setEvents(events.map(e => ({
        time: e.time,
        content: e.description || e.title,
        mood: mood
      })));

      await cloudDB.upsertDailyRecord(record);
      console.info('今日事件保存成功');
    } catch (err) {
      console.error('保存今日事件失败:', err);
    }
  }

  /**
   * 生成今日总结（调用 AI 服务）
   */
  async generateDailySummary(events: EventItem[], mood?: string): Promise<string> {
    if (this.isGenerating) {
      const error = new Error('正在生成中，请稍候');
      return Promise.reject(error);
    }

    this.isGenerating = true;
    try {
      const aiModule = await import('../service/ai/AIServiceCloud');
      const AIServiceCloud = aiModule.AIServiceCloud;
      const summary = await AIServiceCloud.get().generateDailySummary(events, mood);
      return summary;
    } catch (err) {
      console.error('生成总结失败，使用 Mock 数据:', err);
      return MockData.buildDailyMemory().summary;
    } finally {
      this.isGenerating = false;
    }
  }

  /**
   * 获取历史总结记录
   */
  async getHistorySummaries(limit: number): Promise<DailyMemory[]> {
    try {
      const aiModule = await import('../service/ai/AIServiceCloud');
      const AIServiceCloud = aiModule.AIServiceCloud;
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

  static get(): ComicRepository {
    if (ComicRepository.instance === null) {
      ComicRepository.instance = new ComicRepository();
    }
    return ComicRepository.instance;
  }

  getToday(): Comic {
    return MockData.buildComic();
  }

  /**
   * 生成今日漫画（调用 AI 服务）
   */
  async generateTodayComic(summary: string, events: EventItem[]): Promise<Comic> {
    if (this.isGenerating) {
      const error = new Error('正在生成中，请稍候');
      return Promise.reject(error);
    }

    this.isGenerating = true;
    try {
      const aiModule = await import('../service/ai/AIServiceCloud');
      const AIServiceCloud = aiModule.AIServiceCloud;

      const panels = await AIServiceCloud.get().generateComicScript(summary, events);
      const imageUrls = await AIServiceCloud.get().generateComicImages(panels);
      const localPaths = await AIServiceCloud.get().downloadComicImages(imageUrls);

      const comic = new Comic();
      comic.id = `comic-${Date.now()}`;
      comic.date = this.getToday().date;
      comic.title = `默默的一天 vol.${Date.now() % 100}`;
      comic.message = '今天也有好好陪你，明天见面的路上记得看一眼窗外的云。';

      const comicPages: ComicPage[] = [];
      for (let i = 0; i < panels.length; i++) {
        const panel = panels[i];
        const page = new ComicPage();
        page.index = i;
        page.title = panel.title || `分镜 ${i + 1}`;
        page.image = $r('app.media.comic_1');
        comicPages.push(page);
      }
      comic.pages = comicPages;

      return comic;
    } catch (err) {
      console.error('生成漫画失败，使用 Mock 数据:', err);
      return MockData.buildComic();
    } finally {
      this.isGenerating = false;
    }
  }

  /**
   * 仅生成漫画脚本（用于预览）
   */
  async generateComicScript(summary: string, events: EventItem[]): Promise<ComicPanel[]> {
    try {
      const aiModule = await import('../service/ai/AIServiceCloud');
      const AIServiceCloud = aiModule.AIServiceCloud;
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
}

export class UserRepository {
  private static instance: UserRepository | null = null;

  static get(): UserRepository {
    if (UserRepository.instance === null) {
      UserRepository.instance = new UserRepository();
    }
    return UserRepository.instance;
  }

  getUser(): User {
    return MockData.buildUser();
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