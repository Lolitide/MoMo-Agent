/*
 * ============================================================================
 * 文件名：utils/BubbleLayout.ets
 * ============================================================================
 * 【用途】「气泡花园」布局算法：把记忆按 **4 种类型** 分簇，每簇画成一朵
 *   「记忆之花」——**一个很小的花心点在正中，代表记忆的圆圈均匀地环绕它一圈**；
 *   数量超过一圈能放下的个数时，多出来的用同色小实心圆点排到外圈。
 *   记忆少时 4 簇全部装进一屏（不滚动）；记忆多到一屏装不下时，输出内容高度，
 *   由页面套一层 Scroll 让花园**向下生长**（详见 layout() 的两种排布模式）。
 *
 * 【布局模型：中心点 + 均匀环位 + 自适应直径】
 *   1) 全局：可用矩形切成 gCols × gRows 个 cell，每簇占一个 cell；4 簇优先取 2×2。
 *   2) 簇内：花心点固定在 cell 正中；记忆节点沿**半径 1 个列距**的圆均匀分布
 *      （每 60° 一个位，最多 6 个），因此每个节点到花心的距离都相等、看起来是朵花。
 *   3) 直径由可用矩形反解，保证「能一屏放下就一屏放下」。
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
 *   - 输出：BubbleLayoutResult { cores, slots[], contentHeight }；contentHeight=0 表示
 *     一屏放下（调用方不要套 Scroll），>0 表示需要滚动的内容高度；
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
  /**
   * 内容总高度（vp）。
   *   0  = 一屏放得下，调用方**不要**套 Scroll（保持原来的「不滚动、不裁切」观感）；
   *   >0 = 一屏放不下，调用方需要把这一层放进 Scroll，并把内容高度设为该值。
   * 之所以由布局算法给出，是因为「要不要滚动」取决于分簇与包络，页面不该自己猜。
   */
  contentHeight: number = 0;
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
  /** 外圈小圆点所在半径（单位：列距；第 band 圈为 OUTER_RADIUS + band） */
  private static readonly OUTER_RADIUS: number = 2;
  /** 外圈每一圈最多放几个小圆点（放满自动再往外开一圈） */
  private static readonly OUTER_COUNT: number = 12;
  /** 小圆点直径 = 主圆直径 × 此比例 */
  private static readonly MINI_RATIO: number = 0.30;

  /** 只按这 4 种类型分簇；「重要回忆」是标签，不是类型 */
  private static readonly TYPE_ORDER: MemoryType[] = [
    MemoryType.LIFE, MemoryType.STUDY, MemoryType.GOAL, MemoryType.INTEREST
  ];

  /**
   * 可用区顶部（= 头部玻璃卡下沿）。
   * 滚动模式下页面要**从这一条线开始裁剪**，否则花会滑到标题栏底下、和标题文字叠在一起。
   */
  static topInset(): number {
    return BubbleLayoutUtil.TOP_INSET;
  }

  /**
   * 主入口：分簇 + 自适应网格 + 环绕式落位。
   * 空簇不产生花心（不画没有内容的空花）。
   *
   * 【两种排布模式（由内容量自动选择）】
   *   A. 一屏模式：4 簇切成 2×2，直径由可用矩形反解 —— 记忆不多时保持原有观感，
   *      不滚动、不裁切。
   *   B. 滚动模式：某簇的记忆超过一圈（6 个）时，外圈会多出一圈小圆点，包络从
   *      2 个列距变成 4 个列距，2 列已经放不下 → 退化为**单列纵向排布 + 页面滚动**。
   *      此时每个列距可以取到最大直径上限，圆圈反而更大、更好点。
   * 这样「记忆变多」表现为花园往下生长，而不是把圆挤小或挤出屏外。
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

    // 2. 包络：环上节点横跨 ±1 个列距、纵跨 ±0.866 个列距；
    //    有外圈小圆点时按最外圈半径计算（详见 OUTER_RADIUS 的说明）。
    //    反解直径要用**内容最多的那一簇**的包络，保证所有簇都放得下。
    let maxNodeCount: number = 1;
    for (let k = 0; k < groups.length; k++) {
      maxNodeCount = Math.max(maxNodeCount, groups[k].length);
    }
    const colsAcross: number = BubbleLayoutUtil.colsAcrossOf(maxNodeCount);
    const rowsAcross: number = BubbleLayoutUtil.rowsAcrossOf(maxNodeCount);

    // 3. 自适应网格：先试「一屏放下」，放不下再退到单列滚动
    const availW: number = viewportW - 2 * BubbleLayoutUtil.EDGE_PAD;
    const availH: number = viewportH - BubbleLayoutUtil.BOTTOM_RESERVE - BubbleLayoutUtil.TOP_INSET;
    const n: number = groups.length;
    const colsOneScreen: number = n <= 1 ? 1 : 2;
    const dOneScreen: number = BubbleLayoutUtil.solveD(colsOneScreen, Math.ceil(n / colsOneScreen),
      colsAcross, rowsAcross, availW, availH);

    let gCols: number = colsOneScreen;
    let gRows: number = Math.ceil(n / colsOneScreen);
    let d: number = dOneScreen;
    let scroll: boolean = false;
    if (dOneScreen < BubbleLayoutUtil.MIN_D) {
      // 4. 一屏放不下：允许滚动。先试 2 列（滚动距离短），列宽不够再退 1 列（圆更大）
      const dTwoCols: number = BubbleLayoutUtil.solveD(2, Math.ceil(n / 2),
        colsAcross, rowsAcross, availW, 0);
      if (n > 1 && dTwoCols >= BubbleLayoutUtil.MIN_D) {
        gCols = 2;
        gRows = Math.ceil(n / 2);
        d = dTwoCols;
      } else {
        gCols = 1;
        gRows = n;
        d = BubbleLayoutUtil.solveD(1, n, colsAcross, rowsAcross, availW, 0);
      }
      scroll = true;
    }
    d = Math.min(d, BubbleLayoutUtil.MAX_D);
    d = Math.max(d, BubbleLayoutUtil.MIN_D);

    const pitch: number = d + BubbleLayoutUtil.GAP;
    const coreD: number = Math.max(5, d * BubbleLayoutUtil.CORE_RATIO);
    const miniD: number = Math.max(10, d * BubbleLayoutUtil.MINI_RATIO);

    const cellW: number = colsAcross * pitch + d + BubbleLayoutUtil.CELL_SLACK;

    // 3b. 网格几何：**列宽统一、行高取该行内最大值**。
    //   反解 d 时用的是最大包络，但真正占位要按每簇自己的包络算：
    //   只有 3 个圆的簇若也按 17 个圆的包络占 4 个列距高，单列排布时会空出一大片。
    const colW: number = cellW;
    const rowH: number[] = [];
    for (let r = 0; r < gRows; r++) {
      rowH.push(0);
    }
    for (let k = 0; k < groups.length; k++) {
      const r: number = Math.floor(k / gCols);
      // 与 colW 同构：本簇自己的纵向包络 × 列距 + 直径 + 余量
      const h: number = BubbleLayoutUtil.rowsAcrossOf(groups[k].length) * pitch + d
        + BubbleLayoutUtil.CELL_SLACK;
      rowH[r] = Math.max(rowH[r], h);
    }
    const rowTop: number[] = [];
    let acc: number = 0;
    for (let r = 0; r < gRows; r++) {
      rowTop.push(acc);
      acc += rowH[r] + BubbleLayoutUtil.CELL_GAP_Y;
    }
    const bandW: number = gCols * colW + (gCols - 1) * BubbleLayoutUtil.CELL_GAP_X;
    const bandH: number = acc - BubbleLayoutUtil.CELL_GAP_Y;
    const originX: number = (viewportW - bandW) * 0.5;
    // 一屏模式把整块花园在可用高度里居中；滚动模式从头部卡下方开始往下生长
    const originY: number = scroll
      ? BubbleLayoutUtil.TOP_INSET
      : BubbleLayoutUtil.TOP_INSET + Math.max(0, (availH - bandH) * 0.5);
    result.contentHeight = scroll
      ? BubbleLayoutUtil.TOP_INSET + bandH + BubbleLayoutUtil.BOTTOM_RESERVE : 0;

    let order: number = 0;

    // 5. 逐簇落位
    for (let k = 0; k < groups.length; k++) {
      const group: Memory[] = groups[k];
      const type: MemoryType = group[0].type;
      const gx: number = k % gCols;
      const gy: number = Math.floor(k / gCols);
      const cx: number = originX + gx * (colW + BubbleLayoutUtil.CELL_GAP_X) + colW * 0.5;
      const cy: number = originY + rowTop[gy] + rowH[gy] * 0.5;

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
          // 外圈小圆点：第 band 圈半径 = OUTER_RADIUS + band，圈内按**实际个数**均分整圈，
          // 因此最后一圈没排满时也不会挤在一侧
          const k2: number = i - BubbleLayoutUtil.RING_SLOTS;
          const band: number = Math.floor(k2 / BubbleLayoutUtil.OUTER_COUNT);
          const bandStart: number = BubbleLayoutUtil.RING_SLOTS + band * BubbleLayoutUtil.OUTER_COUNT;
          const bandSize: number = Math.min(BubbleLayoutUtil.OUTER_COUNT, group.length - bandStart);
          const idx: number = k2 - band * BubbleLayoutUtil.OUTER_COUNT;
          const ang: number = 2 * Math.PI * idx / bandSize;
          const r: number = BubbleLayoutUtil.OUTER_RADIUS + band;
          ux = r * Math.cos(ang);
          uy = r * Math.sin(ang);
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

  /**
   * 反解直径：列距下限 = 直径 + 间隙，故
   *   可用宽 = gCols × [(包络列数)×列距 + 直径 + SLACK] + 簇间留白
   * availH <= 0 表示**不限制高度**（滚动模式：高度由内容决定，向下生长）。
   * 返回的是未夹到 [MIN_D, MAX_D] 的原始解 —— 调用方要用它来判断「这个网格是否可行」。
   */
  private static solveD(gCols: number, gRows: number, colsAcross: number, rowsAcross: number,
    availW: number, availH: number): number {
    const coefW: number = gCols * (colsAcross + 1);
    const budgetW: number = availW - (gCols - 1) * BubbleLayoutUtil.CELL_GAP_X
      - gCols * (colsAcross * BubbleLayoutUtil.GAP + BubbleLayoutUtil.CELL_SLACK);
    let d: number = budgetW / coefW;
    if (availH > 0) {
      const coefH: number = gRows * (rowsAcross + 1);
      const budgetH: number = availH - (gRows - 1) * BubbleLayoutUtil.CELL_GAP_Y
        - gRows * (rowsAcross * BubbleLayoutUtil.GAP + BubbleLayoutUtil.CELL_SLACK);
      d = Math.min(d, budgetH / coefH);
    }
    return d;
  }

  /** 第 i 个环位的横向单位偏移（等弧长：每 60° 一个位） */
  private static ringUnitX(i: number): number {
    return Math.cos(2 * Math.PI * i / BubbleLayoutUtil.RING_SLOTS);
  }

  /** 第 i 个环位的纵向单位偏移 */
  private static ringUnitY(i: number): number {
    return Math.sin(2 * Math.PI * i / BubbleLayoutUtil.RING_SLOTS);
  }

  /**
   * 一簇（count 条记忆）的**横向包络宽度**，单位是「列距」：
   * 等于最外侧节点偏离花心的横向距离 × 2。
   * 环上取 |cos(60°×i)| 的最大值；有外圈小圆点时取最外圈半径。
   * 【数值教训】solveD 里的 `gCols*(colsAcross+1)` 假设 colsAcross 是**全宽**；
   * 曾经误传了半宽（没 ×2），导致外圈小圆点被放到屏幕外（实测 x = −23）。
   */
  private static colsAcrossOf(count: number): number {
    const ringCount: number = Math.min(count, BubbleLayoutUtil.RING_SLOTS);
    let span: number = 0;
    for (let i = 0; i < ringCount; i++) {
      span = Math.max(span, Math.abs(BubbleLayoutUtil.ringUnitX(i)));
    }
    return 2 * Math.max(span, BubbleLayoutUtil.outerRadiusOf(count));
  }

  /** 一簇的纵向包络高度（同上，用 |sin|） */
  private static rowsAcrossOf(count: number): number {
    const ringCount: number = Math.min(count, BubbleLayoutUtil.RING_SLOTS);
    let span: number = 0;
    for (let i = 0; i < ringCount; i++) {
      span = Math.max(span, Math.abs(BubbleLayoutUtil.ringUnitY(i)));
    }
    return 2 * Math.max(span, BubbleLayoutUtil.outerRadiusOf(count));
  }

  /** 外圈小圆点占用的最大半径（列距倍数）；没有溢出时为 0（不影响包络） */
  private static outerRadiusOf(count: number): number {
    if (count <= BubbleLayoutUtil.RING_SLOTS) {
      return 0;
    }
    const bands: number = Math.ceil((count - BubbleLayoutUtil.RING_SLOTS) / BubbleLayoutUtil.OUTER_COUNT);
    return BubbleLayoutUtil.OUTER_RADIUS + bands - 1;
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
