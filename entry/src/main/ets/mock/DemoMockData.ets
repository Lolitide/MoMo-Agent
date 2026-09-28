/*
 * ============================================================================
 * 文件名：mock/DemoMockData.ets
 * ============================================================================
 * 【用途】演示模式专用数据工厂（与 mock/MockData.ets 分开维护）：
 *   为「演示模式」提供比普通 Mock 更饱满、更适合现场演示的预置内容——
 *   14 条长期记忆（覆盖花园三视图 + 搜索 + 日历）、7 条今日事件、9 条「默默的理解」、
 *   一整套今日漫画（4 页横版分镜），以及演示态下 AI 动作的预制返回文案。
 *
 * 【演示故事线（本文件所有内容都围绕它组织）】
 *   一天：上午在一个复现不了的 Bug 上耗了两个多小时 → 中午和朋友吃饭放松 →
 *   下午换了思路把问题解决 → 晚上听音乐、休息，结束充实的一天。
 *   今日状态（事件/洞察）、今日漫画（4 页横图）、长期记忆、预制 AI 文案
 *   互相引用同一批人物与细节，现场无论点到哪里都能自圆其说。
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
 *   - 演示漫画用的是 comic_demo_1..4 这组**横版**图（约 3:2），与普通模式的
 *     comic_1..5 分开存放；横竖比不同，展示层需要按 isDemo 走 Contain 布局。
 *
 * 【参考源】
 *   - MoMo-DOC/演示模式参考图（4 张横版分镜，剧情即本文件的演示故事线）
 *   - MoMo-DOC/开发笔记参考/03-数据与记忆系统.md（L0/L1/L2 字段语义）
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
   * 今日记忆：7 条事件 + 9 条洞察，对应演示故事线的一天。
   * 事件时间点与今日漫画的四个分镜（9:00 / 12:30 / 16:00 / 21:30）对齐，
   * 现场从「今日状态」跳到「今日漫画」时，两边讲的是同一件事。
   */
  static buildDailyMemory(): DailyMemory {
    const m = new DailyMemory();
    m.date = DateUtil.formatDot(new Date());
    m.summary = '今天是那种「开头不顺利、结尾很踏实」的一天：上午你卡在一个复现不了的 Bug 上，'
      + '中午和朋友吃了顿饭，回来换了思路，下午四点终于把它修好并跑通了全部用例。'
      + '晚上你戴上耳机听音乐，没有再打开电脑。默默觉得，今天最了不起的地方不是修好了它，'
      + '而是中间那两个小时里，你一次都没有崩。';
    const events: EventItem[] = [
      new EventItem('e1', '起床后给自己煮了杯咖啡', '08:10', 'life', '昨晚十一点半睡，醒来没有赖床'),
      new EventItem('e2', '排查一个复现不了的 Bug', '09:00', 'work', '先复现、再看日志，你没有急着改代码'),
      new EventItem('e3', '定位到是并发时序问题', '10:40', 'work', '问题不在你昨天怀疑的地方，你推翻了自己的假设'),
      new EventItem('e4', '和朋友一起吃了午饭', '12:30', 'life', '聊了一个多小时，你说「美食果然能治愈一切」'),
      new EventItem('e5', '回到工位继续试方案', '14:00', 'work', '试了三种改法，前两种都没成'),
      new EventItem('e6', '终于修好，全部用例跑通', '16:00', 'work', '你举着手在椅子上坐了好一会儿'),
      new EventItem('e7', '戴上耳机听音乐', '21:30', 'life', '没有再打开电脑，说今天真的很棒')
    ];
    m.events = events;
    const insights: InsightItem[] = [
      { id: 'i1', title: '工作节奏', content: '上午 9 点到 11 点是你最稳的排查窗口，需要动脑的事尽量排在这里。' },
      { id: 'i2', title: '情绪趋势', content: '下午四点之后情绪明显上扬，正好是问题被解决的时间点。' },
      { id: 'i3', title: '关系触点', content: '中午这顿饭之后，你下午的效率回升了。朋友对你不是「社交」，是「充电」。' },
      { id: 'i4', title: '身体信号', content: '连续三天在零点前睡，入睡时间比上周提前了约 25 分钟。' },
      { id: 'i5', title: '兴趣偏好', content: '你的歌单只在「一天的活干完之后」才被打开，音乐对你是收尾仪式。' },
      { id: 'i6', title: '灵感摘要', content: '「问题不在昨天怀疑的地方」这个思路，你已经用它破局三次了。' },
      { id: 'i7', title: '番茄节拍', content: '今天有 4 个专注时段，其中两个花在同一个问题上。' },
      { id: 'i8', title: '小小成就', content: '面对一个复现不了的 Bug，你今天一次都没有烦躁到关掉编辑器。' },
      { id: 'i9', title: '待观察', content: '那两种没成功的改法你先回滚了，没有留在代码里——这个习惯很值钱。' }
    ];
    m.insights = insights;
    return m;
  }

  // ==================== L2：长期记忆（14 条） ====================

  /**
   * 演示用长期记忆：基数 14 条、跨最近 14 天、四个类型齐全（含 3 条「重要回忆」标签）。
   * 日期由「今天 - offsetDays」动态生成，因此演示当天永远有内容且日历可点。
   * 实际条数受设置页的 targetCount 影响：多于 14 条补齐、少于 14 条截取。
   */
  static buildMemories(): Memory[] {
    const mem: Memory[] = [];

    const m1 = DemoMockData.mk('m1', '给自己做早饭的第一周', 13, MemoryType.LIFE, 3);
    m1.summary = '从周一开始每天早起二十分钟，第七天已经不用看教程了。';
    m1.content = '你原来早上只来得及灌一杯咖啡。这周你试着提前二十分钟起床，煎蛋、吐司、'
      + '有时候再加一小碟水果。到第七天你已经不用看教程，动作熟练得像做了很久。'
      + '默默觉得，这不是一顿早饭的事，是你开始认真对待一天的开始。';
    m1.tags = ['早餐', '习惯', '健康'];

    const m2 = DemoMockData.mk('m2', '读完《重构》的前六章', 12, MemoryType.STUDY, 4);
    m2.summary = '你把书里的手法一条条对照到了自己的项目里。';
    m2.content = '你花了两周读完前六章，每读完一节就去翻自己项目里对应的代码，'
      + '在注释里标出「这里可以这么改」。你说以前以为重构就是重写，'
      + '现在知道它是「在不改变行为的前提下，让下一次修改更便宜」。';
    m2.tags = ['阅读', '工程', '成长'];

    const m3 = DemoMockData.mk('m3', '开始重读《设计中的设计》', 11, MemoryType.INTEREST, 2);
    m3.summary = '把注意力从「怎么做」拉回「为什么这样做」。';
    m3.content = '你在通勤路上重读原研哉，划出了三处关于「留白」的段落。'
      + '你说写代码和做设计其实是一件事：最难的从来不是往里加，而是知道哪里该空着。';
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

    const m5 = DemoMockData.mk('m5', '整理了一份项目踩坑笔记', 9, MemoryType.STUDY, 3);
    m5.summary = '你把散落在聊天记录里的坑，变成了一份能查的文档。';
    m5.content = '你把半年里踩过的坑按「环境 / 并发 / 缓存」三类归档，'
      + '每条都写了「现象 → 原因 → 怎么避免」。今天上午你第一个打开的就是它。';
    m5.tags = ['复盘', '文档', '工程'];
    m5.sourceEvents = ['e2'];

    const m6 = DemoMockData.mk('m6', '周末去了一直想去的江边公园', 8, MemoryType.LIFE, 2);
    m6.summary = '你在草地上坐了一下午，什么都没做。';
    m6.content = '那个公园你收藏了很久，一直说「等有空再去」。周六你终于去了，'
      + '带了一本书却一页没翻，就在草地上坐着看人遛狗。你说这种「什么都没做」的下午，'
      + '比睡到中午更解乏。';
    m6.tags = ['散步', '周末', '放空'];

    const m7 = DemoMockData.mk('m7', '听完了《万物生灵》合集', 7, MemoryType.INTEREST, 2);
    m7.summary = '你的散步歌单又更新了一首单曲循环。';
    m7.content = '你散步时听完了一整张专辑，最喜欢第三首，把它加进了「散步歌单」。'
      + '后来每次走到河边那段路，你都会切到这首歌。今天收工之后，你放的也是它。';
    m7.tags = ['音乐', '散步'];
    m7.sourceEvents = ['e7'];
    m7.relatedMemoryIds = ['m3'];

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

    const m11 = DemoMockData.mk('m11', '给常用工具做了一套自己的配置', 4, MemoryType.STUDY, 3);
    m11.summary = '把重复的动作，一次性变成不用想的动作。';
    m11.content = '你花了一个晚上把编辑器、终端和常用快捷键都调成了顺手的样子，'
      + '还写了个小脚本一键起项目。你说这不叫折腾，叫「把时间从重复里拿回来」。';
    m11.tags = ['效率', '工具', '整理'];
    m11.relatedMemoryIds = ['m2'];

    const m12 = DemoMockData.mk('m12', '雨天改走室内路线', 3, MemoryType.LIFE, 2);
    m12.summary = '习惯遇到意外时，你选择了变通而不是放弃。';
    m12.content = '连着下雨两天，你没有取消散步，而是改走了商场一层的环形走廊。'
      + '你说这条路线能看到很多陌生人，比河边更好玩。';
    m12.tags = ['习惯', '雨天', '变通'];

    const m13 = DemoMockData.mk('m13', '给反复出问题的模块补上了测试', 2, MemoryType.GOAL, 4);
    m13.summary = '你决定不再靠「下次小心」来保证质量。';
    m13.content = '那个模块今年出过三次线上问题，你花了一个周末给它补了十一个用例，'
      + '把每个出问题的场景都钉在了测试里。你说与其每次救火，不如把火源围起来。';
    m13.tags = ['工程', '质量', '目标'];
    m13.relatedMemoryIds = ['m4', 'm5'];

    const m14 = DemoMockData.mk('m14', '开始把「照顾自己」排在任务前面', 1, MemoryType.LIFE, 5);
    m14.summary = '这一周最明显的变化：你不再用疲惫换进度。';
    m14.content = '这周你做成了几件以前会拖到深夜的事：好好吃早饭、中午和朋友吃饭、'
      + '晚上听完一整张专辑。你并没有变慢——今天那个卡了两天的 Bug，'
      + '就是在这种节奏里被解决的。默默觉得，这比任何一条待办被划掉都更值得记下来。';
    m14.tags = ['重要回忆', '节奏', '自己'];
    m14.sourceEvents = ['e1', 'e4', 'e6'];
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

  /** 补充记忆的题材池（轮转取用，保证可读且不重复）：延续「开发者的一天」这套语境 */
  private static topicOf(n: number): string {
    const pool: string[] = [
      '给常用的那段代码补了注释', '把桌面的线理了一遍', '中午出门晒了十分钟太阳',
      '看完了一个讲架构的短片', '把上周的笔记整理成了清单', '尝试了一条新的散步路线',
      '给朋友回了一封长消息', '把手机的提醒关掉了一整天', '读完了一本书的最后一节',
      '在楼下遇到了一只很亲人的猫', '把待办里的三件小事清掉了', '晚饭做得比平时简单',
      '听了一张很舒服的专辑', '把阳台的花浇了一遍', '在地铁上记下了两个灵感',
      '给自己留了半小时发呆', '把旧照片整理进了一个相册', '试着早睡了一次',
      '把一个脚本改得顺手了一些', '走了一段没有走过的路'
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
      ['m1 做早饭的第一周', 'm6 江边公园的下午', 'm10 手机带出卧室', 'm12 雨天室内路线',
        'm14 把照顾自己排在前面'],
      ['m2 读完《重构》前六章', 'm5 项目踩坑笔记', 'm11 一套顺手的工具配置'],
      ['m3 重读《设计中的设计》', 'm7 万物生灵合集'],
      ['m4 记忆花园第一株花', 'm8 遇见默默', 'm9 拒绝临时加会', 'm13 给模块补上测试']
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
   * 今日漫画：4 页横版分镜，对应演示故事线的四个时刻
   * （上午改 Bug / 中午和朋友吃饭 / 下午解决问题 / 晚上听音乐休息）。
   * 图为 comic_demo_1..4（约 3:2 横版），与普通模式的 comic_1..5 分开存放，
   * 因此展示层按 isDemo 切到 Contain 布局，避免横图被 Cover 裁掉左右两侧的台词框。
   */
  static buildComic(): Comic {
    const c = new Comic();
    c.id = 'demo-comic';
    c.date = DateUtil.formatDot(new Date());
    c.sourceDate = c.date;
    c.title = '修 Bug 的一天';
    c.message = '今天你卡了很久，但一次都没有放弃。默默把这一天画了下来。';
    c.profileVersion = 1;
    c.styleKey = '暖色手账|元气|适度提醒';
    c.generationStatus = 'demo';

    const titles: string[] = ['上午 · 忙着改 Bug', '中午 · 和朋友吃饭', '下午 · 终于解决了', '晚上 · 听音乐休息'];
    const imgs: Resource[] = [
      $r('app.media.comic_demo_1'), $r('app.media.comic_demo_2'),
      $r('app.media.comic_demo_3'), $r('app.media.comic_demo_4')
    ];
    const pages: ComicPage[] = [];
    for (let i = 0; i < titles.length; i++) {
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
   * dialogue 就是参考图上那几句台词，现场对照着讲能对上。
   */
  static buildComicPanels(): ComicPanelLike[] {
    const panels: ComicPanelLike[] = [
      {
        index: 0,
        description: '上午 · 忙着改 Bug',
        prompt: '上午九点的书桌前，女生托着腮盯着笔记本，头顶一团乱线，旁边小白猫皱着眉，暖色手账风格',
        dialogue: '忙着修改项里的 Bug。虽然有点头大，但还是一点点在解决！'
      },
      {
        index: 1,
        description: '中午 · 和朋友吃饭',
        prompt: '中午十二点半的小餐馆，两个女生边吃边笑，小白猫举着烤串，桌上摆满菜和奶茶，暖光',
        dialogue: '和朋友一起吃饭，聊天放松了一下，心情也变好了不少！美食果然能治愈一切～'
      },
      {
        index: 2,
        description: '下午 · 终于解决了',
        prompt: '下午四点，女生双手举高欢呼，小白猫跟着蹦起来撒星星，屏幕上是跑通的代码，明亮室内光',
        dialogue: '终于解决困扰很久的技术问题！试了很多种方法，最后成功了！那一刻真的太有成就感了！'
      },
      {
        index: 3,
        description: '晚上 · 听音乐休息',
        prompt: '晚上九点半，女生戴着耳机靠在床上闭眼微笑，小白猫蜷在身边睡着，暖黄床头灯，安静',
        dialogue: '听音乐、休息，结束充实的一天。虽然有点累，但今天真的很棒！明天也要加油呀～'
      }
    ];
    return panels;
  }

  // ==================== 演示态 AI 预制返回 ====================

  /** 演示态「生成今日总结」的秒回文案（不联网） */
  static demoDailySummaryText(): string {
    return '今天你在一个复现不了的 Bug 上卡了两个多小时，中午没有硬撑，'
      + '而是出去和朋友吃了顿饭，回来换了思路，下午四点把它解决了。'
      + '默默看到的变化是：你开始懂得在卡住的时候先离开一下，'
      + '而且这并没有让你变慢——全部用例是在今天跑通的。';
  }

  /** 演示态「记忆纠正」的秒回文案（不联网） */
  static demoCorrectionResult(): string {
    return '已按你的说法修正：今天下午不是「有些焦躁」，而是「问题解决之后的放松」。'
      + '默默把这条记忆的权重调低了一档，并记下你对「复现不了的 Bug」比较敏感，'
      + '之后不会把这类时段理解为情绪低落。';
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
