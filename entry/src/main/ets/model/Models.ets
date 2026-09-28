/*
 * ============================================================================
 * 文件名：model/Models.ets
 * ============================================================================
 * 【用途】领域模型定义：Memory（记忆）、MemoryType/MemoryTypeUtil（类型枚举与
 *   展示工具）、MemoryTreeNode（记忆树节点）、EventItem（事件）、
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
  // 【仅用于兼容历史持久化数据】旧的「重要回忆」类型。
  // 新约定下「重要回忆」只是一个**标签**（见 Models 顶部的说明），不再作为类型使用：
  //   - 新数据一律写入四类之一，并以 `importance >= GOAL_IMPORTANT_IMPORTANCE` + 标签表达重要性；
  //   - 旧数据在读取时由 DataSyncService 迁移为 GOAL 并补上「重要回忆」标签。
  IMPORTANT = 4
}

/** 重要回忆的约定：importance 达到该值且带「重要回忆」标签 */
export const IMPORTANT_MEMORY_TAG: string = '重要回忆';
export const GOAL_IMPORTANT_IMPORTANCE: number = 5;

// 花园视图模式。
// 注意：枚举值与 AppStorage('gardenMode') / GardenController.gardenMode / modeOverride 是
// 数值传递的，新增值只能追加在末尾，不得改动既有数值，否则 HDS 菜单高亮与 autoNav 会错位。
export enum GardenMode {
  // 旧「花园地图」模式：节点锚点式排布已被气泡花园取代，仅保留数值以兼容既有调试入口
  GARDEN = 0,
  OUTLINE = 1,
  TREE = 2,
  // 气泡花园：按记忆类型分簇、花瓣式蜂巢排布（当前默认视图）
  BUBBLE = 3
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
  userId: string = '';
  name: string = 'MoMo';
  signature: string = '今天也要好好生活呀';
  avatar: string = '';
  profile: PersonalityProfile = new PersonalityProfile();
  profileCompleted: boolean = false;
  profileVersion: number = 1;
}

export class PersonalityProfile {
  tone: string = '温柔';
  pace: string = '少打扰';
  comicStyle: string = '清新日常';
  focusTopics: string[] = ['生活'];
  version: number = 1;
}

export class EventItem {
  id: string = '';
  title: string = '';
  time: string = '';
  category: string = 'life';
  description: string = '';
  content: string = '';

  constructor(id: string, title: string, time: string, category: string, description: string) {
    this.id = id;
    this.title = title;
    this.time = time;
    this.category = category;
    this.description = description;
    this.content = description;
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
  image: ResourceStr = $r('app.media.comic_1');
}

export class Comic {
  id: string = '';
  date: string = '';
  title: string = '';
  message: string = '';
  pages: ComicPage[] = [];
  profileVersion: number = 0;
  styleKey: string = '';
  sourceDate: string = '';
  generationStatus: string = 'empty';
  imageUrl: string = '';
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

// 记忆类型工具：枚举值 <-> 中文名/配色 映射（纯静态查表 + 派生，UI 与仓库共用）
//
// 【配色约定（气泡花园的语义色板）】
//   生活 = 橙   学习 = 蓝   目标 = 红   兴趣 = 绿
// 只维护一个 base 主色，其余两档按固定规则派生，保证四类颜色的对比度关系一致：
//   base -> 中饱和主色：图例圆点、小圆点花瓣、花心
//   deep -> 把 base 往深里压（×0.68）：主圆内的图标色
//   soft -> 把 base 往浅里提（与白色混合 86%）：主圆的底色
// 这样 base 与 soft 的明度差、deep 与 soft 的明度差都是恒定的，改色只需改 base。
export class MemoryTypeUtil {
  /** base 主色在派生时与白色/黑色混合的比例 */
  private static readonly SOFT_MIX: number = 0.86;
  private static readonly DEEP_MIX: number = 0.68;

  static nameOf(t: MemoryType): string {
    if (t === MemoryType.STUDY) {
      return '学习';
    } else if (t === MemoryType.INTEREST) {
      return '兴趣';
    } else if (t === MemoryType.GOAL) {
      return '目标';
    } else if (t === MemoryType.IMPORTANT) {
      // 兼容历史数据：迁移前的旧类型仍能正确显示名称
      return '重要回忆';
    }
    return '生活';
  }

  /** base 主色：图例圆点、小圆点花瓣、花心 */
  static colorOf(t: MemoryType): string {
    if (t === MemoryType.STUDY) {
      return '#3E86E0';   // 蓝
    } else if (t === MemoryType.INTEREST) {
      return '#2FA26A';   // 绿
    } else if (t === MemoryType.GOAL || t === MemoryType.IMPORTANT) {
      return '#E25C5C';   // 红（重要回忆已并入目标，共用红色）
    }
    return '#E98A32';     // 橙（生活）
  }

  /** 深色图标色：把 base 往深里压，与 soft 底圆拉开明度差 */
  static iconColorOf(t: MemoryType): string {
    return MemoryTypeUtil.shade(MemoryTypeUtil.colorOf(t), MemoryTypeUtil.DEEP_MIX);
  }

  /** 浅色底圆：把 base 与白色混合 */
  static bubbleBgOf(t: MemoryType): string {
    return MemoryTypeUtil.tint(MemoryTypeUtil.colorOf(t), MemoryTypeUtil.SOFT_MIX);
  }

  /** 描边色：比主色淡一些但比底圆深，用于区分相邻气泡的边界 */
  static borderOf(t: MemoryType): string {
    return MemoryTypeUtil.shade(MemoryTypeUtil.colorOf(t), 0.86);
  }

  /** 与白色混合（ratio 为白色的占比，0~1） */
  private static tint(hex: string, ratio: number): string {
    const v: number[] = MemoryTypeUtil.parse(hex);
    const out: string = MemoryTypeUtil.mix(v, [255, 255, 255], ratio);
    return out;
  }

  /** 压暗（ratio 为保留原色的比例，0~1） */
  private static shade(hex: string, ratio: number): string {
    const v: number[] = MemoryTypeUtil.parse(hex);
    const out: string = MemoryTypeUtil.mix(v, [0, 0, 0], 1 - ratio);
    return out;
  }

  private static mix(a: number[], b: number[], ratioB: number): string {
    const r: number = Math.round(a[0] * (1 - ratioB) + b[0] * ratioB);
    const g: number = Math.round(a[1] * (1 - ratioB) + b[1] * ratioB);
    const bl: number = Math.round(a[2] * (1 - ratioB) + b[2] * ratioB);
    return '#' + MemoryTypeUtil.hex2(r) + MemoryTypeUtil.hex2(g) + MemoryTypeUtil.hex2(bl);
  }

  private static hex2(n: number): string {
    const clamped: number = Math.min(Math.max(n, 0), 255);
    return clamped < 16 ? '0' + clamped.toString(16) : clamped.toString(16);
  }

  /** 解析 "#RRGGBB" -> [r, g, b]；格式异常时返回中性灰，避免崩溃 */
  private static parse(hex: string): number[] {
    if (hex.length === 7 && hex.charAt(0) === '#') {
      const r: number = parseInt(hex.substring(1, 3), 16);
      const g: number = parseInt(hex.substring(3, 5), 16);
      const b: number = parseInt(hex.substring(5, 7), 16);
      if (!Number.isNaN(r) && !Number.isNaN(g) && !Number.isNaN(b)) {
        return [r, g, b];
      }
    }
    return [128, 128, 128];
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

export class GardenState {
  currentMode: GardenMode = GardenMode.BUBBLE;
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
