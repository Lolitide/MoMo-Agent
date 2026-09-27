/*
 * ============================================================================
 * 文件名：utils/BubbleLayout.ets
 * ============================================================================
 * 【用途】「气泡花园」布局算法：把记忆按 **4 种类型** 分簇，每簇画成一朵
 *   「记忆之花」——**一个很小的花心点在正中，代表记忆的圆圈均匀地环绕它一圈**；
 *   数量超过一圈能放下的个数时，多出来的用同色小实心圆点排到外圈。
 *   4 簇全部装进一屏（不滚动、不裁切、不遮挡）。
 *
 * 【布局模型：中心点 + 均匀环位 + 自适应直径】
 *   1) 全局：可用矩形切成 gCols × gRows 个 cell，每簇占一个 cell；4 簇取 2×2。
 *   2) 簇内：花心点固定在 cell 正中；记忆节点沿**半径 1 个列距**的圆均匀分布
 *      （每 60° 一个位，最多 6 个），因此每个节点到花心的距离都相等、看起来是朵花。
 *   3) 直径由可用矩形反解，保证「一屏放下 4 簇」。
 *
 * 【为什么记忆节点不能放在花心位置（真机实测）】
 *   早期把「花心标记点」与「承载记忆的圆」都放在 (0,0)，两者完全重叠：
 *   实心点盖住了圆的图标与日期。现在花心只是一个很小的点，**所有承载内容的圆都在环上**。
 *
 * 【为什么环位必须等弧长（数值实测踩了两次）】
 *   环上相邻两点的**弦长**决定列距下限：
 *     - 半径 1、每 60° 均匀分布 → 弦长 = 1.0P  →  列距下限 = 直径 + 间隙；
 *     - 若用六角格的 6 个邻位（(1,0)、(0.5,0.866)…）→ 最近邻只有 0.518P，
 *       比 1.0P 小一半，圆会叠得很厉害。
 *   因此环位由 `cos/sin(60°×i)` 现算，不手写表格——手写表正是前几轮反复出错的地方。
 *
 * 【前置条件 / 假设】
 *   - 纯函数工具：无状态、无 IO、无副作用；输出为 vp 坐标，原点在屏幕左上；
 *   - 输入 memories 需已按期望顺序（建议日期倒序）排好，本工具不再排序；
 *   - 假设：只画 4 种类型（生活/学习/目标/兴趣）。「重要回忆」是**标签**而非类型
 *     （见 Models.ets 的 IMPORTANT_MEMORY_TAG），因此不在 TYPE_ORDER 里。
 *
 * 【输入 / 输出（后置条件）】
 *   - 输入：memories、viewportW、viewportH（vp）；
 *   - 输出：BubbleLayoutResult { cores, slots[] }；不输出内容高度（不滚动）；
 *   - 后置：mini=false 的 slot 与入参记忆一一对应（按 memoryId 关联）；
 *     mini=true 的是外圈装饰小圆点（memoryId 为空，不可点）；cores 是花心点。
 *
 * 【参考源】
 *   - 用户提供的两张手绘草图（中心点 + 环绕的圆 + 外圈小点）
 * ============================================================================
 */
import { Memory, MemoryType } from '../model/Models';

/** 花心：一朵花的中心标记（很小的实心点，不承载记忆） */
export class FlowerCore {
  type: MemoryType = MemoryType.LIFE;
  x: number = 0;
  y: number = 0;
  d: number = 0;

  constructor(type: MemoryType, x: number, y: number, d: number) {
    this.type = type;
    this.x = x;
    this.y = y;
    this.d = d;
  }
}

/** 一个记忆节点（或外圈装饰小圆点） */
export class BubbleSlot {
  /** 对应的记忆 id；小圆点为空字符串 */
  memoryId: string = '';
  type: MemoryType = MemoryType.LIFE;
  x: number = 0;
  y: number = 0;
  d: number = 0;
  /** true = 外圈装饰小实心圆点（数量溢出时使用），不可点击 */
  mini: boolean = false;
  /** 簇内序号，用于入场错峰绽放 */
  order: number = 0;

  constructor(memoryId: string, type: MemoryType, x: number, y: number, d: number,
    mini: boolean, order: number) {
    this.memoryId = memoryId;
    this.type = type;
    this.x = x;
    this.y = y;
    this.d = d;
    this.mini = mini;
    this.order = order;
  }
}

export class BubbleLayoutResult {
  cores: FlowerCore[] = [];
  slots: BubbleSlot[] = [];
}

export class BubbleLayoutUtil {
  // ===== 可调常量 =====
  /** 左右安全边距 */
  private static readonly EDGE_PAD: number = 8;
  /** 可用区域顶部：头部玻璃卡下沿 + 一点空隙，保证第一排不被遮挡 */
  private static readonly TOP_INSET: number = 228;
  /** 底部为悬浮 Tab 栏预留的高度 */
  private static readonly BOTTOM_RESERVE: number = 124;
  /** 直径上限（节点很少时不至于大得夸张） */
  private static readonly MAX_D: number = 64;
  /**
   * 直径下限。
   * 这是一个**真实的取舍点**：一簇要环绕成一圈，包络至少 2 个列距宽；
   * 4 簇用 2×2 网格时宽高预算都被吃满，反解出的直径约 Ø46。
   * 想更大就只能减少每簇节点数（放弃"环绕"的完整感）或放弃"一屏放下"。
   */
  private static readonly MIN_D: number = 40;
  /** 相邻圆之间保留的间隙 */
  private static readonly GAP: number = 8;
  /** 同一行内相邻 cell 的簇间留白 */
  private static readonly CELL_GAP_X: number = 6;
  /** 相邻两行 cell 之间的留白 */
  private static readonly CELL_GAP_Y: number = 6;
  /**
   * cell 的额外安全余量。
   * 【数值实测教训】若 cell 宽度恰好等于簇包络，最外侧节点会被 `clampInside`
   * 推回零点几个 vp，反而贴到相邻节点上（实测 −0.3vp）。cell 略宽即可让 clamp 永不触发。
   */
  private static readonly CELL_SLACK: number = 6;
  /** 环上最多放几个记忆节点（每 60° 一个，正好一圈） */
  private static readonly RING_SLOTS: number = 6;
  /** 花心点直径 = 主圆直径 × 此比例（保持是"很小的点"） */
  private static readonly CORE_RATIO: number = 0.16;
  /** 外圈小圆点所在半径（单位：列距） */
  private static readonly OUTER_RADIUS: number = 2;
  /** 外圈小圆点个数 */
  private static readonly OUTER_COUNT: number = 12;
  /** 小圆点直径 = 主圆直径 × 此比例 */
  private static readonly MINI_RATIO: number = 0.30;

  /** 只按这 4 种类型分簇；「重要回忆」是标签，不是类型 */
  private static readonly TYPE_ORDER: MemoryType[] = [
    MemoryType.LIFE, MemoryType.STUDY, MemoryType.GOAL, MemoryType.INTEREST
  ];

  /**
   * 主入口：分簇 + 自适应网格 + 环绕式落位。
   * 空簇不产生花心（不画没有内容的空花）。
   */
  static layout(memories: Memory[], viewportW: number, viewportH: number): BubbleLayoutResult {
    const result = new BubbleLayoutResult();

    // 1. 按类型分簇（保持入参数组内的相对顺序，即日期倒序）
    const groups: Memory[][] = [];
    for (let t = 0; t < BubbleLayoutUtil.TYPE_ORDER.length; t++) {
      const list: Memory[] = [];
      for (let i = 0; i < memories.length; i++) {
        if (memories[i].type === BubbleLayoutUtil.TYPE_ORDER[t]) {
          list.push(memories[i]);
        }
      }
      if (list.length > 0) {
        groups.push(list);
      }
    }
    if (groups.length === 0) {
      return result;
    }

    // 2. 自适应网格：可用矩形切成 gCols × gRows，每簇占一个 cell
    const availW: number = viewportW - 2 * BubbleLayoutUtil.EDGE_PAD;
    const availH: number = viewportH - BubbleLayoutUtil.BOTTOM_RESERVE - BubbleLayoutUtil.TOP_INSET;
    const n: number = groups.length;
    const gCols: number = n <= 1 ? 1 : 2;
    const gRows: number = Math.ceil(n / gCols);

    // 3. 包络：环上节点横跨 ±1 个列距、纵跨 ±0.866 个列距；
    //    有外圈小圆点时按 OUTER_RADIUS 计算
    let maxNodeCount: number = 1;
    for (let k = 0; k < groups.length; k++) {
      maxNodeCount = Math.max(maxNodeCount, groups[k].length);
    }
    const ringCount: number = Math.min(maxNodeCount, BubbleLayoutUtil.RING_SLOTS);
    let colSpan: number = 0;
    let rowSpan: number = 0;
    for (let i = 0; i < ringCount; i++) {
      colSpan = Math.max(colSpan, Math.abs(BubbleLayoutUtil.ringUnitX(i)));
      rowSpan = Math.max(rowSpan, Math.abs(BubbleLayoutUtil.ringUnitY(i)));
    }
    if (maxNodeCount > BubbleLayoutUtil.RING_SLOTS) {
      colSpan = Math.max(colSpan, BubbleLayoutUtil.OUTER_RADIUS);
      rowSpan = Math.max(rowSpan, BubbleLayoutUtil.OUTER_RADIUS);
    }
    const colsAcross: number = 2 * colSpan;
    const rowsAcross: number = 2 * rowSpan;

    // 4. 反解直径：环上相邻弦长为 1.0 个列距，因此列距下限 = 直径 + 间隙
    const coefW: number = gCols * (colsAcross + 1);
    const coefH: number = gRows * (rowsAcross + 1);
    const budgetW: number = availW - (gCols - 1) * BubbleLayoutUtil.CELL_GAP_X
      - gCols * (colsAcross * BubbleLayoutUtil.GAP + BubbleLayoutUtil.CELL_SLACK);
    const budgetH: number = availH - (gRows - 1) * BubbleLayoutUtil.CELL_GAP_Y
      - gRows * (rowsAcross * BubbleLayoutUtil.GAP + BubbleLayoutUtil.CELL_SLACK);
    let d: number = Math.min(budgetW / coefW, budgetH / coefH);
    d = Math.min(d, BubbleLayoutUtil.MAX_D);
    d = Math.max(d, BubbleLayoutUtil.MIN_D);

    const pitch: number = d + BubbleLayoutUtil.GAP;
    const coreD: number = Math.max(5, d * BubbleLayoutUtil.CORE_RATIO);
    const miniD: number = Math.max(10, d * BubbleLayoutUtil.MINI_RATIO);

    const cellW: number = colsAcross * pitch + d + BubbleLayoutUtil.CELL_SLACK;
    const cellH: number = rowsAcross * pitch + d + BubbleLayoutUtil.CELL_SLACK;
    const bandW: number = gCols * cellW + (gCols - 1) * BubbleLayoutUtil.CELL_GAP_X;
    const bandH: number = gRows * cellH + (gRows - 1) * BubbleLayoutUtil.CELL_GAP_Y;
    const originX: number = (viewportW - bandW) * 0.5;
    const originY: number = BubbleLayoutUtil.TOP_INSET + Math.max(0, (availH - bandH) * 0.5);

    let order: number = 0;

    // 5. 逐簇落位
    for (let k = 0; k < groups.length; k++) {
      const group: Memory[] = groups[k];
      const type: MemoryType = group[0].type;
      const gx: number = k % gCols;
      const gy: number = Math.floor(k / gCols);
      const cx: number = originX + gx * (cellW + BubbleLayoutUtil.CELL_GAP_X) + cellW * 0.5;
      const cy: number = originY + gy * (cellH + BubbleLayoutUtil.CELL_GAP_Y) + cellH * 0.5;

      // 花心：很小的实心点，**不承载记忆**，因此不会盖住任何圆的内容
      result.cores.push(new FlowerCore(type, cx, cy, coreD));

      for (let i = 0; i < group.length; i++) {
        const isMini: boolean = i >= BubbleLayoutUtil.RING_SLOTS;
        const nodeD: number = isMini ? miniD : d;
        let ux: number = 0;
        let uy: number = 0;
        if (!isMini) {
          // 环位：等弧长（每 60°），弦长 = 1.0 个列距
          ux = BubbleLayoutUtil.ringUnitX(i);
          uy = BubbleLayoutUtil.ringUnitY(i);
        } else {
          // 外圈小圆点：半径 OUTER_RADIUS，均匀分布
          const m: number = (i - BubbleLayoutUtil.RING_SLOTS) % BubbleLayoutUtil.OUTER_COUNT;
          const ang: number = 2 * Math.PI * m / BubbleLayoutUtil.OUTER_COUNT;
          ux = BubbleLayoutUtil.OUTER_RADIUS * Math.cos(ang);
          uy = BubbleLayoutUtil.OUTER_RADIUS * Math.sin(ang);
        }
        const x: number = BubbleLayoutUtil.clampInside(cx + ux * pitch, nodeD / 2, viewportW);
        const y: number = cy + uy * pitch;

        result.slots.push(new BubbleSlot(
          isMini ? '' : group[i].id,
          type,
          x,
          y,
          nodeD,
          isMini,
          order
        ));
        order++;
      }
    }

    return result;
  }

  /** 第 i 个环位的横向单位偏移（等弧长：每 60° 一个位） */
  private static ringUnitX(i: number): number {
    return Math.cos(2 * Math.PI * i / BubbleLayoutUtil.RING_SLOTS);
  }

  /** 第 i 个环位的纵向单位偏移 */
  private static ringUnitY(i: number): number {
    return Math.sin(2 * Math.PI * i / BubbleLayoutUtil.RING_SLOTS);
  }

  /** 把 x 钳制到屏幕内（按元素自身半径），保证任何取值都不会把节点推出屏外 */
  private static clampInside(v: number, radius: number, viewportW: number): number {
    const lo: number = radius + BubbleLayoutUtil.EDGE_PAD;
    const hi: number = viewportW - radius - BubbleLayoutUtil.EDGE_PAD;
    if (hi < lo) {
      return viewportW * 0.5;
    }
    return Math.min(Math.max(v, lo), hi);
  }
}
