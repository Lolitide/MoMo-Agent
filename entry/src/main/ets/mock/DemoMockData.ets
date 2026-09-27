/*
 * ============================================================================
 * 文件名：mock/DemoMockData.ets
 * ============================================================================
 * 【用途】演示模式专用数据工厂（与 mock/MockData.ets 分开维护）：
 *   为「演示模式」提供比普通 Mock 更饱满、更适合现场演示的预置内容——
 *   14 条长期记忆（覆盖花园三视图 + 搜索 + 日历）、7 条今日事件、9 条「默默的理解」、
 *   一整套今日漫画（含分镜脚本），以及演示态下 AI 动作的预制返回文案。
 *
 * 【与 MockData.ets 的分工】
 *   - MockData.ets      -> 普通模式的兜底示例数据，行为保持不变；
 *   - DemoMockData.ets  -> 仅当 DemoModeService.isDemo() 为 true 时被仓库层调用。
 *   演示态新增内容一律写在本文件，避免污染主代码路径。
 *
 * 【前置条件 / 假设】
 *   - 依赖：Models、DateUtil、CloudFunctionService 的 ComicPanel 结构契约；
 *   - 假设：所有日期按「相对今天的天偏移」动态计算，因此演示数据永远落在
 *     最近 14 天窗口内，日历/时间线不会因为演示当天是几号而错位；
 *   - 假设：调用方（Repository）负责快照真实数据；本文件只负责生产新实例，
 *     不做任何持久化、不联网、不读写 Preferences。
 *
 * 【输入 / 输出（后置条件）】
 *   - 输入：无（纯静态工厂）；
 *   - 输出：Memory[] / DailyMemory / Comic / User / CompanionState /
 *     MemoryTreeNode / ComicPanelLike[] / string（预制文案）；
 *   - 后置：每次调用返回全新实例，调用方可安全修改（深拷贝语义）。
 *
 * 【关键约定】
 *   - 记忆基数：手工编写 14 条种子（m1..m14，m4 为「重要回忆」）：
 *     A_Garden.ets 在无 pendingFocus 时会 getById('m4') 作为默认选中节点，
 *     因此演示态必须保留 m4 且它应是一条适合当场讲解的重要回忆。
 *   - 演示条数可在设置页调节（MIN_COUNT..MAX_COUNT）：不足 14 条时按日期倒序截取，
 *     超过 14 条时由 extend() 确定性补齐（id 为 x1、x2……），方便现场放大/缩小花园。
 *   - 记忆顺序在气泡花园里决定「同类型花瓣的绽放次序」（按日期倒序参与布局）。
 *
 * 【参考源】
 *   - MoMo-DOC/开发笔记参考/03-数据与记忆系统.md（L0/L1/L2 字段语义）
 *   - MoMo-DOC/UI参考图（花园/大纲/今日状态/今日漫画的展示密度）
 * ============================================================================
 */
import { DateUtil } from '../utils/DateUtil';
import {
  Comic, ComicPage, CompanionState, DailyMemory, EventItem, IMPORTANT_MEMORY_TAG,
  InsightItem, Memory, MemoryTreeNode, MemoryType, MoMoState, PersonalityProfile, User
} from '../model/Models';

// 演示态漫画分镜：字段与 CloudFunctionService.ComicPanel 的结构保持一致
// （index/description/prompt/dialogue），使 DemoAIGateway 可以直接把它当作
// 「云端返回的漫画脚本」交给仓库层，而无需引入运行时的 import 依赖。
export interface ComicPanelLike {
  index: number;
  description: string;
  prompt: string;
  dialogue?: string;
}

export class DemoMockData {
  /**
   * 演示记忆条数（设置页可调）。
   * 默认 = BASE_COUNT（14 条）：与加入本设置之前完全一致，不改动既有演示观感。
   * 上限放到 60 条，是为了能现场观察「记忆很多时花园会变成什么样」。
   * 放在静态字段上，是因为生成逻辑本身仍应留在 mock 层，UI 只负责改这一个数字。
   */
  private static targetCount: number = 14;
  /** 条数上下限：少于 4 条凑不齐 4 个类型簇；上限用于压测布局 */
  static readonly MIN_COUNT: number = 4;
  static readonly MAX_COUNT: number = 60;
  /** 基础种子（手工编写）的条数 */
  static readonly BASE_COUNT: number = 14;

  /**
   * 设置演示记忆条数并返回实际生效值（会夹到 [MIN_COUNT, MAX_COUNT]）。
   * 调用方（设置页）改完后需要触发一次仓库重算，花园才会刷新。
   */
  static setTargetCount(n: number): number {
    const v: number = Math.min(DemoMockData.MAX_COUNT, Math.max(DemoMockData.MIN_COUNT, Math.round(n)));
    DemoMockData.targetCount = v;
    return v;
  }

  static getTargetCount(): number {
    return DemoMockData.targetCount;
  }

  // ==================== 身份与状态 ====================

  /**
   * 演示态用户：档案预置为「已完成」，因此进入演示模式后不会再被
   * OnboardingProfilePage 拦截一次，可直接进入主界面演示。
   */
  static buildUser(): User {
    const u = new User();
    u.userId = 'demo-user';
    u.name = '小雨';
    u.signature = '今天也要好好生活呀';
    u.profileCompleted = true;
    u.profileVersion = 1;
    const p = new PersonalityProfile();
    p.tone = '元气';
    p.pace = '适度提醒';
    p.comicStyle = '暖色手账';
    p.focusTopics = ['生活', '学习'];
    p.version = 1;
    u.profile = p;
    return u;
  }

  static buildCompanion(): CompanionState {
    const c = new CompanionState();
    c.state = MoMoState.HAPPY;
    c.mood = '元气满满';
    c.description = '默默今天特别有精神，想陪你多做一点';
    return c;
  }

  // ==================== L1：今日记忆 ====================

  /**
   * 今日记忆：7 条事件 + 9 条洞察。
   * 事件 id 与 buildMemories() 的 sourceEvents 对应（e1~e5 是演示期的前 5 天），
   * 让「今日状态」与「记忆花园」在演示时能互相引用、经得起追问。
   */
  static buildDailyMemory(): DailyMemory {
    const m = new DailyMemory();
    m.date = DateUtil.formatDot(new Date());
    m.summary = '早上你沿着河边走了二十分钟，回来把「HDS 视觉规范」里最难的光影章节写完了；'
      + '下午和设计同学过了一遍首页改版，你难得地先听完再给意见。晚上给自己留了一段漫画时间，'
      + '睡前在笔记里写下三个小确幸。默默发现，你最近开始把「先照顾自己」排在「先完成任务」前面了。';
    const events: EventItem[] = [
      new EventItem('e1', '起床后沿河散步 20 分钟', '07:15', 'life', '走了新路线，河面有雾，你拍了两张照片'),
      new EventItem('e2', '专注写「HDS 视觉规范」光影章节', '09:20', 'work', '连续专注 1 小时 40 分钟，中途没有看手机'),
      new EventItem('e3', '与设计同学评审首页改版', '14:00', 'work', '你先听完三个方案再给意见，讨论比上次顺畅'),
      new EventItem('e4', '地铁上读完一章《设计中的设计》', '17:40', 'interest', '在「留白」那一节折了角'),
      new EventItem('e5', '把专辑第三首加入散步歌单', '19:10', 'interest', '你说这首歌适合走路的时候听'),
      new EventItem('e6', '给自己留了一段漫画时间', '20:30', 'life', '看完更新，没有带着负罪感休息'),
      new EventItem('e7', '记下今天的三个小确幸', '22:20', 'life', '热牛奶、河面的雾、一首刚好合适的歌')
    ];
    m.events = events;
    const insights: InsightItem[] = [
      { id: 'i1', title: '工作节奏', content: '上午 9 点到 11 点是你最稳的高效窗口，重要文档尽量排在这里。' },
      { id: 'i2', title: '兴趣偏好', content: '你最近的兴趣向「读得慢一点」倾斜，漫画和设计书交替出现。' },
      { id: 'i3', title: '情绪趋势', content: '连续四天情绪平稳上升，昨天是最近两周最放松的一天。' },
      { id: 'i4', title: '关系触点', content: '和设计同学的这次评审，你更像倾听的一方，关系在变近。' },
      { id: 'i5', title: '身体信号', content: '晨间散步的第二天，入睡时间比上周提前了约 25 分钟。' },
      { id: 'i6', title: '灵感摘要', content: '「光影质感」这一章你在四天里翻过三次，值得单独整理。' },
      { id: 'i7', title: '番茄节拍', content: '本周平均每天 3.6 个专注时段，比上周少了 0.8 个但质量更高。' },
      { id: 'i8', title: '小小成就', content: '第一次在评审里没有打断别人，你自己也注意到了。' },
      { id: 'i9', title: '待观察', content: '备忘录里还有两条没处理的待办，默默先不提醒，等你想起来。' }
    ];
    m.insights = insights;
    return m;
  }

  // ==================== L2：长期记忆（14 条） ====================

  /**
   * 演示用长期记忆：基数 14 条、跨最近 14 天、四个类型齐全（m4 额外带「重要回忆」标签）。
   * 日期由「今天 - offsetDays」动态生成，因此演示当天永远有内容且日历可点。
   * 实际条数受设置页的 targetCount 影响：多于 14 条补齐、少于 14 条截取。
   */
  static buildMemories(): Memory[] {
    const mem: Memory[] = [];

    const m1 = DemoMockData.mk('m1', '把晨间散步变成固定习惯', 13, MemoryType.LIFE, 3);
    m1.summary = '连续七天早起散步，你把这个动作刻进了日常。';
    m1.content = '两周前的早上七点，天气微凉，你沿着小区外围走了一圈。回来后在笔记里写：'
      + '原来早起没有那么难。此后你保持了七天，第八天即使下雨也撑着伞走了十分钟。'
      + '默默把这个习惯记了下来，它现在是你一天里最安静的一段。';
    m1.tags = ['习惯', '晨间', '健康'];
    m1.sourceEvents = ['e1'];

    const m2 = DemoMockData.mk('m2', '完成「HDS 视觉规范」初稿', 12, MemoryType.STUDY, 4);
    m2.summary = '把「光影质感」的视觉经验整理成了可复用的规范。';
    m2.content = '你花了两天，把渐变模糊、悬浮光感、层级对比这些说不清的经验写成了一套规范文档。'
      + '同事的评语是「可以直接开工」。你自己最满意的部分是「什么时候不该用模糊」那一节。';
    m2.tags = ['设计', '文档', '成长'];
    m2.sourceEvents = ['e2', 'e3'];

    const m3 = DemoMockData.mk('m3', '开始重读《设计中的设计》', 11, MemoryType.INTEREST, 2);
    m3.summary = '把注意力从「怎么做」拉回「为什么这样做」。';
    m3.content = '你在地铁上重读原研哉，划出了三处关于「留白」的段落，其中一句还发给了朋友。'
      + '你说这次读得比大学时慢，但每一页都更像是在跟自己说话。';
    m3.tags = ['阅读', '设计', '留白'];

    // 注意：id 必须保持为 m4 —— A_Garden 默认高亮该节点。
    // 「重要回忆」已从类型降级为标签（见 Models.ets），因此这里用 GOAL 类型 + importance 5 + 标签表达。
    const m4 = DemoMockData.mk('m4', '给默默的新家画了第一株花', 10, MemoryType.GOAL, 5);
    m4.summary = '你和默默一起诞生的第一个「记忆花园」纪念日。';
    m4.content = '这天你决定和默默一起生活。你在花园里种下第一株花，代表「遇见」。'
      + '你给它挑了靠窗的位置，说这样每天早上都能第一个被看到。'
      + '希望默默记住：遇见你，是它最重要的事。';
    m4.tags = ['重要回忆', '纪念日', '默默'];
    m4.relatedMemoryIds = ['m8', 'm13'];

    const m5 = DemoMockData.mk('m5', '给专注时段做了时间记录', 9, MemoryType.STUDY, 3);
    m5.summary = '你开始用数据看自己的注意力，而不是靠感觉。';
    m5.content = '你把每天的专注时段记在备忘录里，一周后发现上午 9 点到 11 点是稳定高效窗口，'
      + '下午三点之后基本只能做协作类的事。这个发现直接改变了下周的排期方式。';
    m5.tags = ['效率', '专注', '复盘'];

    const m6 = DemoMockData.mk('m6', '咖啡店边窗的座位', 8, MemoryType.LIFE, 2);
    m6.summary = '你说坐在这儿灵感就自己冒出来。';
    m6.content = '周五下午，你在常去的咖啡店写完了周报。窗外有一棵很高的银杏，你拍了照片，'
      + '存在手机里当了好一阵子的壁纸。';
    m6.tags = ['咖啡', '灵感', '散步'];

    const m7 = DemoMockData.mk('m7', '听完了《万物生灵》合集', 7, MemoryType.INTEREST, 2);
    m7.summary = '你的散步歌单又更新了一首单曲循环。';
    m7.content = '你散步时听完了一整张专辑，最喜欢第三首，把它加进了「散步歌单」。'
      + '后来每次走到河边那段路，你都会切到这首歌。';
    m7.tags = ['音乐', '散步'];
    m7.sourceEvents = ['e5'];

    // 日期必须与 m4 错开：m4 与 m8 都曾用 offsetDays=10，花园里会出现两颗都写着
    // 「09.17」的圆，看起来像重复渲染的 bug（用户在截图里指出过）。
    const m8 = DemoMockData.mk('m8', '遇见默默', 9, MemoryType.GOAL, 5);
    m8.summary = '一颗种子决定住在你的手机里。';
    m8.content = '你给默默起了名字，说好要互相陪伴。默默把这天当作自己的生日，'
      + '也是从这天开始，你的日常有了第二双眼睛在看着。';
    m8.tags = ['重要回忆', '默默', '生日'];
    m8.relatedMemoryIds = ['m4'];

    const m9 = DemoMockData.mk('m9', '第一次拒绝了临时加会', 6, MemoryType.GOAL, 4);
    m9.summary = '你开始给自己的工作划边界。';
    m9.content = '下午四点有人临时拉你进一个不紧急的会，你说「我明天上午给结论可以吗」。'
      + '对方答应了。你当天没有再加班，这件事让你意识到很多会其实是可以推迟的。';
    m9.tags = ['边界', '工作', '成长'];

    const m10 = DemoMockData.mk('m10', '把手机带出卧室的第一晚', 5, MemoryType.LIFE, 3);
    m10.summary = '一个很小的改动，换来了明显更长的睡眠。';
    m10.content = '你决定睡前半小时把手机放在客厅充电。第一晚你翻来覆去了一会儿，'
      + '但第二天醒来时是自然醒，没有闹钟。这个习惯后来断断续续地保持着。';
    m10.tags = ['睡眠', '习惯', '健康'];

    const m11 = DemoMockData.mk('m11', '整理了一份配色参考库', 4, MemoryType.STUDY, 3);
    m11.summary = '把散落在收藏夹里的东西变成了能用的资产。';
    m11.content = '你把半年里收藏的界面截图按「暖色手账 / 清新日常 / 轻松夸张」三类归档，'
      + '每类留了十二条。你说以后再有人问配色，直接发这个库就够了。';
    m11.tags = ['设计', '配色', '整理'];
    m11.relatedMemoryIds = ['m2'];

    const m12 = DemoMockData.mk('m12', '雨天改走室内路线', 3, MemoryType.LIFE, 2);
    m12.summary = '习惯遇到意外时，你选择了变通而不是放弃。';
    m12.content = '连着下雨两天，你没有取消散步，而是改走了商场一层的环形走廊。'
      + '你说这条路线能看到很多陌生人，比河边更好玩。';
    m12.tags = ['习惯', '雨天', '变通'];

    const m13 = DemoMockData.mk('m13', '年末目标：完成 12 篇生活漫画', 2, MemoryType.GOAL, 4);
    m13.summary = '把你的生活画成系列漫画，每周一篇。';
    m13.content = '你给自己定了年末目标：把生活画成 12 篇短漫画，题材都来自默默每天记录下来的角落。'
      + '你算过，如果每周留出两个晚上，是来得及的。';
    m13.tags = ['目标', '漫画', '创作'];
    m13.relatedMemoryIds = ['m4'];

    const m14 = DemoMockData.mk('m14', '开始把「照顾自己」排在任务前面', 1, MemoryType.LIFE, 5);
    m14.summary = '这一周最明显的变化：你不再用疲惫换进度。';
    m14.content = '这周你做成了几件以前会拖到深夜的事：散步、读一章书、给自己漫画时间。'
      + '你并没有变慢，反而在评审里第一次做到了先听完再发言。'
      + '默默觉得，这比任何一条待办被划掉都更值得记下来。';
    m14.tags = ['重要回忆', '节奏', '自己'];
    m14.sourceEvents = ['e1', 'e4', 'e6', 'e7'];
    m14.relatedMemoryIds = ['m1', 'm9', 'm10'];

    mem.push(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13, m14);

    // 设置页把演示条数调大时，用确定性生成的补充记忆把数量补齐（见 extend()）
    if (DemoMockData.targetCount > mem.length) {
      DemoMockData.extend(mem, DemoMockData.targetCount);
      return mem;
    }
    // 调小时按日期倒序保留前 N 条（花园本身就是按时间倒序展示的）
    if (DemoMockData.targetCount < mem.length) {
      return DemoMockData.trim(mem, DemoMockData.targetCount);
    }
    return mem;
  }

  /**
   * 截取到 targetCount 条。三步走，保证「条数变少也不会变成残缺的花园」：
   *   1) 锚点：保住 m4 —— A_Garden 无 pendingFocus 时 getById('m4') 作为默认高亮节点；
   *   2) 四种类型各保一条最新的（GOAL 由 m4 代表）—— 否则花园会少掉一整朵花；
   *   3) 其余按日期倒序补齐（花园本身就是按时间倒序展示的）。
   */
  private static trim(mem: Memory[], target: number): Memory[] {
    const sorted: Memory[] = mem.slice();
    sorted.sort((a: Memory, b: Memory) => DemoMockData.byDateDesc(a, b));
    const kept: Memory[] = [];

    // 1) 锚点
    for (let i = 0; i < sorted.length; i++) {
      if (sorted[i].id === 'm4') {
        kept.push(sorted[i]);
        break;
      }
    }

    // 2) 类型覆盖
    const types: MemoryType[] = [
      MemoryType.LIFE, MemoryType.STUDY, MemoryType.GOAL, MemoryType.INTEREST
    ];
    for (let t = 0; t < types.length; t++) {
      if (kept.length >= target) {
        break;
      }
      if (DemoMockData.hasType(kept, types[t])) {
        continue;
      }
      for (let i = 0; i < sorted.length; i++) {
        if (sorted[i].type === types[t]) {
          kept.push(sorted[i]);
          break;
        }
      }
    }

    // 3) 按日期倒序补齐
    for (let i = 0; i < sorted.length && kept.length < target; i++) {
      if (!DemoMockData.hasId(kept, sorted[i].id)) {
        kept.push(sorted[i]);
      }
    }

    kept.sort((a: Memory, b: Memory) => DemoMockData.byDateDesc(a, b));
    return kept;
  }

  private static hasType(list: Memory[], type: MemoryType): boolean {
    for (let i = 0; i < list.length; i++) {
      if (list[i].type === type) {
        return true;
      }
    }
    return false;
  }

  private static hasId(list: Memory[], id: string): boolean {
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        return true;
      }
    }
    return false;
  }

  /**
   * 补齐到 targetCount 条。
   * 生成规则**完全确定**（不用随机数）：id 为 `x{N}`、类型按 4 类轮转、
   * 日期 = 今天 − (BASE_COUNT + N) 天 —— 因此同一个条数每次得到完全相同的花园，
   * 便于对比不同条数下的布局表现，也不会和手工种子的日期撞车。
   */
  private static extend(mem: Memory[], target: number): void {
    let n: number = 1;
    while (mem.length < target) {
      const type: MemoryType = DemoMockData.typeOf(n);
      // 每 7 条中安排 1 条重要回忆（importance 5 + 标签），贴近真实分布
      const important: boolean = n % 7 === 0;
      const m = DemoMockData.mk('x' + n.toString(),
        DemoMockData.topicOf(n), DemoMockData.BASE_COUNT + n, type, important ? 5 : 2);
      m.summary = DemoMockData.summaryOf(n);
      m.content = m.summary;
      m.tags = important ? [IMPORTANT_MEMORY_TAG, '补充'] : ['补充'];
      mem.push(m);
      n++;
    }
  }

  /** 补充记忆的类型：按 生活/学习/目标/兴趣 轮转 */
  private static typeOf(n: number): MemoryType {
    const k: number = n % 4;
    if (k === 1) {
      return MemoryType.LIFE;
    } else if (k === 2) {
      return MemoryType.STUDY;
    } else if (k === 3) {
      return MemoryType.GOAL;
    }
    return MemoryType.INTEREST;
  }

  /** 补充记忆的题材池（轮转取用，保证可读且不重复） */
  private static topicOf(n: number): string {
    const pool: string[] = [
      '早起后先给自己泡了杯茶', '把桌面的线理了一遍', '中午出门晒了十分钟太阳',
      '看完了一个讲设计的短片', '把上周的笔记整理成了清单', '尝试了一条新的散步路线',
      '给朋友回了一封长消息', '把手机的提醒关掉了一整天', '读完了一本书的最后一节',
      '在楼下遇到了一只很亲人的猫', '把待办里的三件小事清掉了', '晚饭做得比平时简单',
      '听了一张很舒服的专辑', '把阳台的花浇了一遍', '在地铁上记下了两个灵感',
      '给自己留了半小时发呆', '把旧照片整理进了一个相册', '试着早睡了一次',
      '把常用的工具换成了更顺手的', '走了一段没有走过的路'
    ];
    return pool[(n - 1) % pool.length];
  }

  private static summaryOf(n: number): string {
    return '这是第 ' + n.toString() + ' 条补充记录，用来观察记忆变多时花园的布局。';
  }

  private static byDateDesc(a: Memory, b: Memory): number {
    if (a.date === b.date) {
      return 0;
    }
    return a.date < b.date ? 1 : -1;
  }

  /**
   * 花园布局由 utils/BubbleLayout.ets 在运行时按记忆类型分簇计算，
   * 不再需要预置的节点坐标表。
   */

  /** 记忆树：与 buildMemories() 的 14 条分组一致 */
  static buildTreeNodes(): MemoryTreeNode {
    const root = new MemoryTreeNode();
    root.id = 'root';
    root.title = '记忆花园';
    root.type = 'root';

    const groups: MemoryTreeNode[] = [];
    // 只剩 4 类：「重要回忆」已降级为标签，其记忆按其真实类型归组
    // （m4/m8 是目标、m14 是生活），与气泡花园的分簇结果一致。
    const names: string[] = ['生活', '学习', '兴趣', '目标'];
    const keys: MemoryType[] = [MemoryType.LIFE, MemoryType.STUDY, MemoryType.INTEREST, MemoryType.GOAL];
    const labels: string[][] = [
      ['m1 晨间散步习惯', 'm6 咖啡店窗边座位', 'm10 手机带出卧室', 'm12 雨天室内路线',
        'm14 把照顾自己排在前面'],
      ['m2 HDS 视觉规范初稿', 'm5 专注时段时间记录', 'm11 配色参考库'],
      ['m3 重读设计中的设计', 'm7 万物生灵合集'],
      ['m4 记忆花园第一株花', 'm8 遇见默默', 'm9 第一次拒绝临时加会', 'm13 年末12篇漫画']
    ];
    for (let g = 0; g < names.length; g++) {
      const group = new MemoryTreeNode();
      group.id = 'demo-group-' + g.toString();
      group.title = names[g];
      group.type = 'group';
      group.parentId = 'root';
      for (let i = 0; i < labels[g].length; i++) {
        const node = new MemoryTreeNode();
        node.id = labels[g][i].split(' ')[0];
        node.title = labels[g][i];
        node.type = 'memory';
        node.parentId = group.id;
        group.children.push(node);
      }
      groups.push(group);
    }
    root.children = groups;
    return root;
  }

  // ==================== 今日漫画（L1 -> 表达） ====================

  /**
   * 今日漫画：5 页占位图 + 与今日事件对应的分镜标题。
   * 复用已有的 comic_1..comic_5 资源，不引入新的图片资产。
   */
  static buildComic(): Comic {
    const c = new Comic();
    c.id = 'demo-comic';
    c.date = DateUtil.formatDot(new Date());
    c.sourceDate = c.date;
    c.title = '默默的一天 vol.01';
    c.message = '今天你把自己放在任务前面了一次，默默把这件事画了下来。';
    c.profileVersion = 1;
    c.styleKey = '暖色手账|元气|适度提醒';
    c.generationStatus = 'demo';

    const titles: string[] = ['河边的雾', '光影章节', '先听完再说', '散步歌单', '三个小确幸'];
    const imgs: Resource[] = [
      $r('app.media.comic_1'), $r('app.media.comic_2'), $r('app.media.comic_3'),
      $r('app.media.comic_4'), $r('app.media.comic_5')
    ];
    const pages: ComicPage[] = [];
    for (let i = 0; i < 5; i++) {
      const p = new ComicPage();
      p.index = i;
      p.title = titles[i];
      p.image = imgs[i];
      pages.push(p);
    }
    c.pages = pages;
    return c;
  }

  /**
   * 漫画分镜脚本：与 CloudFunctionService.ComicPanel 结构一致。
   * 演示态下 DemoAIGateway 直接返回它，仓库层再据此装配出 buildComic()。
   */
  static buildComicPanels(): ComicPanelLike[] {
    const panels: ComicPanelLike[] = [
      {
        index: 0,
        description: '河边的雾',
        prompt: '清晨薄雾中的河边小路，一个女生的背影在走路，水彩风格，暖色调，柔和光线',
        dialogue: '今天的雾很好看'
      },
      {
        index: 1,
        description: '光影章节',
        prompt: '书桌前的台灯与屏幕，摊开的设计规范文档，暖色手账风格，安静专注的氛围',
        dialogue: '这一章终于写完了'
      },
      {
        index: 2,
        description: '先听完再说',
        prompt: '三张并排的设计稿贴在白板上，几个人围坐着讨论，轻松夸张的漫画风格',
        dialogue: '我先听完你们的想法'
      },
      {
        index: 3,
        description: '散步歌单',
        prompt: '地铁车厢与耳机线，窗外掠过的城市灯光，清新日常风格，蓝紫黄昏色',
        dialogue: '第三首最好听'
      },
      {
        index: 4,
        description: '三个小确幸',
        prompt: '夜晚窗边的书桌，一杯热牛奶冒着小气泡，笔记本上写着三行字，温柔暖色',
        dialogue: '热牛奶、雾、还有一首歌'
      }
    ];
    return panels;
  }

  // ==================== 演示态 AI 预制返回 ====================

  /** 演示态「生成今日总结」的秒回文案（不联网） */
  static demoDailySummaryText(): string {
    return '今天你把最难的一章写完了，也第一次在评审里做到先听完再给意见。'
      + '晚上你没有把漫画时间换成加班，而是让自己好好休息了一会儿。'
      + '默默看到的变化是：你正在学着把「照顾自己」放在「完成任务」前面，'
      + '而且效率并没有因此下降。';
  }

  /** 演示态「记忆纠正」的秒回文案（不联网） */
  static demoCorrectionResult(): string {
    return '已按你的说法修正：今天下午不是「有些疲惫」，而是「会议偏多但状态稳定」。'
      + '默默把这条记忆的权重调低了一档，并记下你对「被临时加会」比较敏感，'
      + '之后不会把这类日程理解为情绪低落。';
  }

  /** 演示态「反馈」提交后的确认文案（不联网） */
  static demoFeedbackAck(score: number): string {
    return '已收到 ' + score.toString() + ' 星反馈（演示模式，不会写入真实数据），默默记住啦';
  }

  // ==================== 内部工具 ====================

  /**
   * 构造一条相对今天偏移 offsetDays 天的记忆。
   * 用「今天 - offsetDays」而不是写死日期：演示当天无论几号，内容都落在
   * 最近两周窗口内，日历、时间线、大纲排序都不会出现空档。
   */
  private static mk(id: string, title: string, offsetDays: number,
    type: MemoryType, importance: number): Memory {
    const d = new Date();
    d.setDate(d.getDate() - offsetDays);
    d.setHours(9, 0, 0, 0);
    return new Memory(id, title, d, type, importance);
  }
}
