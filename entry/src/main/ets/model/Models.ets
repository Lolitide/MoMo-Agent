/*
 * ============================================================================
 * 文件名：model/Models.ets
 * ============================================================================
 * 【用途】领域模型定义：Memory（记忆）、MemoryType/MemoryTypeUtil（类型枚举与
 *   展示工具）、MemoryTreeNode/GardenNodeItem（花园/树节点）、EventItem（事件）、
 *   DailyMemory/InsightItem（今日状态）、Comic/ComicPage（漫画）、MoMoState（默默状态）、
 *   GardenMode（花园模式）、PageState（页面加载态）、User（用户）。
 * 【前置条件 / 假设】
 *   - 纯数据类/枚举：不含 UI 逻辑；枚举值被 UI 与仓库共同引用；
 *   - 假设：Memory.id 全局唯一（Mock 以 "mN" 编号）；MoMoState 8 态与 MoMoAvatar 对应。
 * 【输入 / 输出（后置条件）】
 *   - 输入：仓库/页面构造实例；输出：可序列化的数据对象；
 *   - 后置：工厂方法（如 MemoryTypeUtil.nameOf/iconOf）只读，无副作用。
 * 【关键类 / 算法】
 *   - MemoryTypeUtil：type <-> 中文名/图标映射表（生活/工作/兴趣/纪念日/备忘录…）；
 *   - DailyMemory.new()：默认空摘要/空数组，避免 UI 判空分支。
 * 【参考源】
 *   - 废案 model/（Comic/DailyMemory/GardenModel/User 等）；需求文档字段表
 * ============================================================================
 */
import { DateUtil } from '../utils/DateUtil';

// 默默状态枚举：IDLE(闲)/THINKING(想)/CURIOUS(好奇)/HAPPY(开心)/LISTENING(听)/
// SLEEPY(困)/HUNGRY(饿)/SAD(低落) —— MoMoAvatar 按此绘制表情
export enum MoMoState {
  IDLE = 0,
  CURIOUS = 1,
  HAPPY = 2,
  THINKING = 3,
  LISTENING = 4,
  SLEEPING = 5
}

export enum MemoryType {
  LIFE = 0,
  STUDY = 1,
  INTEREST = 2,
  GOAL = 3,
  IMPORTANT = 4
}

export enum GardenMode {
  GARDEN = 0,
  OUTLINE = 1,
  TREE = 2
}

export enum PageState {
  LOADING = 0,
  SUCCESS = 1,
  EMPTY = 2,
  ERROR = 3
}

export class CompanionState {
  state: MoMoState = MoMoState.IDLE;
  mood: string = '安静陪伴';
  description: string = '默默在安静地陪着你';
}

export class User {
  name: string = '酪酪肽';
  signature: string = '今天也要好好生活呀';
}

export class EventItem {
  id: string = '';
  title: string = '';
  time: string = '';
  category: string = 'life';
  description: string = '';

  constructor(id: string, title: string, time: string, category: string, description: string) {
    this.id = id;
    this.title = title;
    this.time = time;
    this.category = category;
    this.description = description;
  }
}

export class InsightItem {
  id: string = '';
  title: string = '';
  content: string = '';
}

export class DailyMemory {
  date: string = '';
  summary: string = '';
  events: EventItem[] = [];
  insights: InsightItem[] = [];
}

export class ComicPage {
  index: number = 0;
  title: string = '';
  image: Resource = $r('app.media.comic_1');
}

export class Comic {
  id: string = '';
  date: string = '';
  title: string = '';
  message: string = '';
  pages: ComicPage[] = [];
}

export class Memory {
  id: string = '';
  title: string = '';
  date: string = '';
  dateObj: Date = new Date();
  tags: string[] = [];
  summary: string = '';
  content: string = '';
  type: MemoryType = MemoryType.LIFE;
  importance: number = 2;
  sourceEvents: string[] = [];
  relatedMemoryIds: string[] = [];

  constructor(id: string, title: string, dateObj: Date, type: MemoryType, importance: number) {
    this.id = id;
    this.title = title;
    this.dateObj = dateObj;
    this.date = DateUtil.formatDot(dateObj);
    this.type = type;
    this.importance = importance;
  }

  typeName(): string {
    return MemoryTypeUtil.nameOf(this.type);
  }
}

// 记忆类型工具：枚举值 <-> 中文名/图标 映射（纯静态查表，UI 与仓库共用）
export class MemoryTypeUtil {
  static nameOf(t: MemoryType): string {
    if (t === MemoryType.STUDY) {
      return '学习';
    } else if (t === MemoryType.INTEREST) {
      return '兴趣';
    } else if (t === MemoryType.GOAL) {
      return '目标';
    } else if (t === MemoryType.IMPORTANT) {
      return '重要回忆';
    }
    return '生活';
  }

  static colorOf(t: MemoryType): string {
    if (t === MemoryType.STUDY) {
      return '#7FB8FF';
    } else if (t === MemoryType.INTEREST) {
      return '#C7A6FF';
    } else if (t === MemoryType.GOAL) {
      return '#FFBB77';
    } else if (t === MemoryType.IMPORTANT) {
      return '#FF9FAB';
    }
    return '#7EDD93';
  }
}

export class MemoryTreeNode {
  id: string = '';
  title: string = '';
  type: string = '';
  parentId: string = '';
  children: MemoryTreeNode[] = [];
  relatedMemoryIds: string[] = [];
}

export class GardenNodeItem {
  id: string = '';
  memoryId: string = '';
  x: number = 0;
  y: number = 0;
}

export class GardenState {
  currentMode: GardenMode = GardenMode.GARDEN;
  pageState: PageState = PageState.SUCCESS;
  selectedMemory: Memory | null = null;
  isDetailVisible: boolean = false;
  isEditing: boolean = false;
  isCreating: boolean = false;
}

export class UndoItem {
  label: string = '';
  time: string = '';
}