/*
 * ============================================================================
 * 文件名：mock/MockData.ets
 * ============================================================================
 * 【用途】Mock 数据工厂：为各仓库提供初始/示例数据（今日事件、记忆、漫画图集、
 *   用户信息、每日摘要/观点），模拟“真实服务”在本地返回。
 * 【前置条件 / 假设】
 *   - 依赖：Models、系统资源（comic_1..5 占位图）、Theme；
 *   - 假设：本轮数据全部本地生成/固定，不联网；日期使用“今天”动态计算。
 * 【输入 / 输出（后置条件）】
 *   - 输入：无（工厂静态方法 / 常量表）；
 *   - 输出：Memory[]/EventItem[]/Comic/User/DailyMemory 等实例；
 *   - 后置：每次调用返回新实例（深拷贝），仓库可安全修改。
 * 【关键类 / 算法】
 *   - seedMemories()：12+ 条样例记忆（含树/花园/大纲三视图所需字段）；
 *   - getTodayComic()：5 页占位图 + 文案；getUser()：昵称“酪酪肽”。
 * 【参考源】
 *   - MoMo_DOC/占位图片（漫画素材）；需求文档（示例数据字段）
 * ============================================================================
 */
import { DateUtil } from '../utils/DateUtil';
import {
  Comic, ComicPage, CompanionState, DailyMemory, EventItem, GardenNodeItem, InsightItem,
  Memory, MemoryTreeNode, MemoryType, MoMoState, User
} from '../model/Models';

export class MockData {
  static buildUser(): User {
    const u = new User();
    return u;
  }

  static buildCompanion(): CompanionState {
    const c = new CompanionState();
    c.state = MoMoState.IDLE;
    c.mood = '安静陪伴';
    c.description = '默默在安静地陪着你';
    return c;
  }

  static buildDailyMemory(): DailyMemory {
    const m = new DailyMemory();
    m.date = DateUtil.formatDot(new Date());
    m.summary = '今天你完成了不少事情：上午专注写方案、下午与同事讨论了发布计划，晚上给自己留了轻松的看漫画时间。默默发现你的节奏平衡得很好。';
    const events: EventItem[] = [
      new EventItem('e1', '起床后散步 20 分钟', '07:20', 'life', '在小区里走了一圈，天气很舒服'),
      new EventItem('e2', '专注写「HDS 视觉规范」方案', '09:30', 'work', '连续专注 1 小时 40 分钟'),
      new EventItem('e3', '与设计同学评审首页改版', '14:00', 'work', '讨论了深色模式与动效细节'),
      new EventItem('e4', '晚饭后看了会的漫画', '19:40', 'interest', '你最喜欢的那部更新了两话'),
      new EventItem('e5', '记下今天的三个小确幸', '22:10', 'life', '热牛奶、窗边晚风、一首喜欢的歌')
    ];
    m.events = events;
    const insights: InsightItem[] = [
      { id: 'i1', title: '工作节奏', content: '你上午效率明显更高，下午适合协作与评审。' },
      { id: 'i2', title: '兴趣偏好', content: '周末前你大概率会想再看一次漫画。' },
      { id: 'i3', title: '情绪趋势', content: '连续三天情绪稳定上升，状态很好。' },
      { id: 'i4', title: '关系触点', content: '和设计同学的方案讨论让你印象深刻。' },
      { id: 'i5', title: '身体信号', content: '晨间散步让全天心率更平稳。' },
      { id: 'i6', title: '灵感摘要', content: '「视觉规范」中关于光感的章节值得反复看。' },
      { id: 'i7', title: '番茄节拍', content: '你最近一周平均每天 4 个专注时段。' },
      { id: 'i8', title: '小小成就', content: '连续三天完成自己定的晨间目标。' }
    ];
    m.insights = insights;
    return m;
  }

  static buildComic(): Comic {
    const c = new Comic();
    c.id = 'comic-2026';
    c.date = DateUtil.formatDot(new Date());
    c.title = '默默的一天 vol.28';
    c.message = '今天也有好好陪你，明天见面的路上记得看一眼窗外的云。';
    const pages: ComicPage[] = [];
    const titles: string[] = ['清晨', '专注时刻', '讨论', '漫画时间', '晚安'];
    const imgs: Resource[] = [
      $r('app.media.comic_1'), $r('app.media.comic_2'), $r('app.media.comic_3'),
      $r('app.media.comic_4'), $r('app.media.comic_5')
    ];
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

  static buildMemories(): Memory[] {
    const mem: Memory[] = [];
    const mk = (id: string, title: string, y: number, m: number, d: number, type: MemoryType, imp: number): Memory => {
      const mm = new Memory(id, title, new Date(y, m, d), type, imp);
      return mm;
    };
    const m1 = mk('m1', '第一次养成了晨间散步的习惯', 2026, 10, 24, MemoryType.LIFE, 3);
    m1.summary = '连续七天早起散步，你把这个习惯刻进了日常。';
    m1.content = '10 月 24 日早上 7 点，天气微凉，你在小区里走了一圈。回来后在笔记里写了：原来早起没有那么难。之后你保持了七天，默默把这个习惯记了下来。';
    m1.tags = ['习惯', '晨间', '健康'];
    m1.sourceEvents = ['e1'];
    const m2 = mk('m2', '完成 HDS 设计规范初稿', 2026, 10, 22, MemoryType.STUDY, 4);
    m2.summary = '把「光影质感」的视觉经验整理成了可复用的规范。';
    m2.content = '你花了两天时间，把渐变模糊、悬浮光感等视觉经验写成了一套可复用的规范文档，被团队评价为「可以直接开工」。';
    m2.tags = ['设计', '文档', '成长'];
    m2.sourceEvents = ['e2', 'e3'];
    const m3 = mk('m3', '开始重读《设计中的设计》', 2026, 10, 20, MemoryType.INTEREST, 2);
    m3.summary = '把注意力从「怎么做」拉回「为什么这样做」。';
    m3.content = '你在地铁上重读原研哉，划出了三处关于「留白」的段落，其中一句还发给了朋友。';
    m3.tags = ['阅读', '设计'];
    const m4 = mk('m4', '给默默的新家画了第一株花', 2026, 10, 28, MemoryType.IMPORTANT, 5);
    m4.summary = '你和默默一起诞生的第一个「记忆花园」纪念日。';
    m4.content = '这天你决定和默默一起生活。你在花园里种下了第一株花，代表「遇见」。希望默默记住：遇见你，是它最重要的事。';
    m4.tags = ['纪念日', '默默', '重要'];
    m4.relatedMemoryIds = ['m8'];
    const m5 = mk('m5', '年末目标：完成 12 篇漫画', 2026, 10, 18, MemoryType.GOAL, 3);
    m5.summary = '把你的生活画成系列漫画，每周一篇。';
    m5.content = '你给自己定了年末目标：把生活画成 12 篇短漫画。题材都来自默默每天记录的角落。';
    m5.tags = ['目标', '漫画', '创作'];
    m5.relatedMemoryIds = ['m4'];
    const m6 = mk('m6', '咖啡店边窗的座位', 2026, 10, 12, MemoryType.LIFE, 2);
    m6.summary = '你说坐在这儿灵感就自己冒出来。';
    m6.content = '周五下午，你在常去的咖啡店写完了周报。窗外有棵很高的银杏，你拍了照片。';
    m6.tags = ['咖啡', '灵感'];
    const m7 = mk('m7', '听完了《万物生灵》合集', 2026, 10, 15, MemoryType.INTEREST, 2);
    m7.summary = '你的三月歌单又更新了一首单曲循环。';
    m7.content = '你散步时听完了一整张专辑，最喜欢第三首，把它加入了「散步歌单」。';
    m7.tags = ['音乐', '散步'];
    const m8 = mk('m8', '遇见默默', 2026, 10, 28, MemoryType.IMPORTANT, 5);
    m8.summary = '一颗种子决定住在你的手机里。';
    m8.content = '你给默默起了名字，说好要互相陪伴。默默把这天当作自己的生日。';
    m8.tags = ['默默', '生日', '重要'];
    m8.relatedMemoryIds = ['m4'];
    mem.push(m1, m2, m3, m4, m5, m6, m7, m8);
    return mem;
  }

  static buildGardenNodes(): GardenNodeItem[] {
    const nodes: GardenNodeItem[] = [];
    const positions: number[][] = [
      [30, 46], [52, 40], [70, 47], [40, 56],
      [62, 56], [24, 58], [48, 64], [78, 60]
    ];
    for (let i = 0; i < 8; i++) {
      const n = new GardenNodeItem();
      n.id = 'g-node-' + i.toString();
      n.memoryId = 'm' + (i + 1).toString();
      n.x = positions[i][0];
      n.y = positions[i][1];
      nodes.push(n);
    }
    return nodes;
  }

  static buildTreeNodes(): MemoryTreeNode {
    const root = new MemoryTreeNode();
    root.id = 'root';
    root.title = '记忆花园';
    root.type = 'root';
    root.parentId = '';
    const mkNode = (id: string, title: string, type: string, parentId: string): MemoryTreeNode => {
      const n = new MemoryTreeNode();
      n.id = id;
      n.title = title;
      n.type = type;
      n.parentId = parentId;
      return n;
    };
    const life = mkNode('g-life', '生活', 'group', 'root');
    const study = mkNode('g-study', '学习成长', 'group', 'root');
    const interest = mkNode('g-interest', '兴趣', 'group', 'root');
    const goal = mkNode('g-goal', '目标', 'group', 'root');
    const special = mkNode('g-special', '重要回忆', 'group', 'root');
    life.children.push(mkNode('m1', '晨间散步习惯', 'memory', 'g-life'));
    life.children.push(mkNode('m6', '咖啡店窗边座位', 'memory', 'g-life'));
    study.children.push(mkNode('m2', 'HDS 设计规范初稿', 'memory', 'g-study'));
    interest.children.push(mkNode('m3', '重读设计中的设计', 'memory', 'g-interest'));
    interest.children.push(mkNode('m7', '万物生灵合集', 'memory', 'g-interest'));
    goal.children.push(mkNode('m5', '年末12篇漫画', 'memory', 'g-goal'));
    special.children.push(mkNode('m4', '记忆花园第一株花', 'memory', 'g-special'));
    special.children.push(mkNode('m8', '遇见默默', 'memory', 'g-special'));
    root.children.push(life, study, interest, goal, special);
    return root;
  }
}