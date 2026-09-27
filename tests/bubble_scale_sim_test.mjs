/*
 * ============================================================================
 * 文件名：tests/bubble_scale_sim_test.mjs
 * ============================================================================
 * 【用途】记忆花园「条数放大」的数值仿真测试。
 *   把 utils/BubbleLayout.ets 的几何算法在 Node 里逐行复刻一遍，用**真实演示分布**
 *   （4 个类型簇的条数）跑一遍，断言几何上不会出现：
 *     1. 同一簇内两个节点重叠（主圆之间、主圆与小圆点之间、小圆点之间）；
 *     2. 节点横向超出屏幕（clampInside 被触发意味着已经贴边，会看起来被裁）；
 *     3. 一屏模式下内容高度超过可用高度（会被头部卡或 Tab 栏遮住）；
 *     4. 滚动模式下 contentHeight 覆盖不到最低的那个节点（滚到底还看不到）。
 *   为什么要复刻而不是直接跑 ArkTS：ArkTS 只能在设备/模拟器上跑，而这个测试要能在
 *   改完常量后 1 秒内给出「这个条数下布局是否还成立」的答案。复刻的代价是可能与源文件
 *   漂移，因此开头先做一遍**常量一致性校验**：把源码里的常量读出来比对，漂移就报错。
 *
 * 【前置条件 / 假设】
 *   - 假设：仓库根目录即本文件所在目录的上一级；
 *   - 假设：屏宽屏高取真机实测值 377×816 vp（1320×2856 px @3.5）。
 *
 * 【输入 / 输出（后置条件）】
 *   - 输入：entry/src/main/ets/utils/BubbleLayout.ets（读常量）+ 本文件内的分布表；
 *   - 输出：全部通过时打印一行成功信息；任一失败时抛 AssertionError 并以非 0 退出。
 * ============================================================================
 */
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const testDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(testDir, '..');
const source = await readFile(path.join(root, 'entry/src/main/ets/utils/BubbleLayout.ets'), 'utf8');

// ---------------------------------------------------------------------------
// 0. 常量一致性：源码里的数值必须与仿真一致，否则本测试的结论无意义
// ---------------------------------------------------------------------------
const constOf = (name) => {
  const m = source.match(new RegExp(`private static readonly ${name}: number = ([0-9.]+);`));
  assert.ok(m, `无法从源码读出常量 ${name}`);
  return Number(m[1]);
};

const K = {
  EDGE_PAD: constOf('EDGE_PAD'),
  TOP_INSET: constOf('TOP_INSET'),
  BOTTOM_RESERVE: constOf('BOTTOM_RESERVE'),
  MAX_D: constOf('MAX_D'),
  MIN_D: constOf('MIN_D'),
  GAP: constOf('GAP'),
  CELL_GAP_X: constOf('CELL_GAP_X'),
  CELL_GAP_Y: constOf('CELL_GAP_Y'),
  CELL_SLACK: constOf('CELL_SLACK'),
  RING_SLOTS: constOf('RING_SLOTS'),
  CORE_RATIO: constOf('CORE_RATIO'),
  OUTER_RADIUS: constOf('OUTER_RADIUS'),
  OUTER_COUNT: constOf('OUTER_COUNT'),
  MINI_RATIO: constOf('MINI_RATIO')
};

// ---------------------------------------------------------------------------
// 1. 算法复刻（与 BubbleLayoutUtil.layout 一一对应）
// ---------------------------------------------------------------------------
const ringUnitX = (i) => Math.cos(2 * Math.PI * i / K.RING_SLOTS);
const ringUnitY = (i) => Math.sin(2 * Math.PI * i / K.RING_SLOTS);

const outerRadiusOf = (count) => {
  if (count <= K.RING_SLOTS) return 0;
  return K.OUTER_RADIUS + Math.ceil((count - K.RING_SLOTS) / K.OUTER_COUNT) - 1;
};
const colsAcrossOf = (count) => {
  let span = 0;
  for (let i = 0; i < Math.min(count, K.RING_SLOTS); i++) span = Math.max(span, Math.abs(ringUnitX(i)));
  return 2 * Math.max(span, outerRadiusOf(count));
};
const rowsAcrossOf = (count) => {
  let span = 0;
  for (let i = 0; i < Math.min(count, K.RING_SLOTS); i++) span = Math.max(span, Math.abs(ringUnitY(i)));
  return 2 * Math.max(span, outerRadiusOf(count));
};

const solveD = (gCols, gRows, colsAcross, rowsAcross, availW, availH) => {
  const coefW = gCols * (colsAcross + 1);
  const budgetW = availW - (gCols - 1) * K.CELL_GAP_X - gCols * (colsAcross * K.GAP + K.CELL_SLACK);
  let d = budgetW / coefW;
  if (availH > 0) {
    const coefH = gRows * (rowsAcross + 1);
    const budgetH = availH - (gRows - 1) * K.CELL_GAP_Y - gRows * (rowsAcross * K.GAP + K.CELL_SLACK);
    d = Math.min(d, budgetH / coefH);
  }
  return d;
};

/** 复刻 layout()：返回 {contentHeight, d, scroll, cores, slots} */
const layout = (counts, viewportW, viewportH) => {
  const groups = counts.filter((c) => c > 0);
  assert.ok(groups.length > 0, '至少要有内容');
  const maxNodeCount = Math.max(...groups);
  const colsAcross = colsAcrossOf(maxNodeCount);
  const rowsAcross = rowsAcrossOf(maxNodeCount);

  const availW = viewportW - 2 * K.EDGE_PAD;
  const availH = viewportH - K.BOTTOM_RESERVE - K.TOP_INSET;
  const n = groups.length;
  const colsOne = n <= 1 ? 1 : 2;
  const dOne = solveD(colsOne, Math.ceil(n / colsOne), colsAcross, rowsAcross, availW, availH);

  let gCols = colsOne;
  let gRows = Math.ceil(n / colsOne);
  let d = dOne;
  let scroll = false;
  if (dOne < K.MIN_D) {
    const dTwo = solveD(2, Math.ceil(n / 2), colsAcross, rowsAcross, availW, 0);
    if (n > 1 && dTwo >= K.MIN_D) {
      gCols = 2; gRows = Math.ceil(n / 2); d = dTwo;
    } else {
      gCols = 1; gRows = n; d = solveD(1, n, colsAcross, rowsAcross, availW, 0);
    }
    scroll = true;
  }
  d = Math.max(Math.min(d, K.MAX_D), K.MIN_D);

  const pitch = d + K.GAP;
  const coreD = Math.max(5, d * K.CORE_RATIO);
  const miniD = Math.max(10, d * K.MINI_RATIO);
  const colW = colsAcross * pitch + d + K.CELL_SLACK;

  const rowH = new Array(gRows).fill(0);
  for (let k = 0; k < groups.length; k++) {
    const r = Math.floor(k / gCols);
    rowH[r] = Math.max(rowH[r], rowsAcrossOf(groups[k]) * pitch + d + K.CELL_SLACK);
  }
  const rowTop = [];
  let acc = 0;
  for (let r = 0; r < gRows; r++) {
    rowTop.push(acc);
    acc += rowH[r] + K.CELL_GAP_Y;
  }
  const bandW = gCols * colW + (gCols - 1) * K.CELL_GAP_X;
  const bandH = acc - K.CELL_GAP_Y;
  const originX = (viewportW - bandW) * 0.5;
  const originY = scroll ? K.TOP_INSET : K.TOP_INSET + Math.max(0, (availH - bandH) * 0.5);
  const contentHeight = scroll ? K.TOP_INSET + bandH + K.BOTTOM_RESERVE : 0;

  const clampInside = (v, radius) => {
    const lo = radius + K.EDGE_PAD;
    const hi = viewportW - radius - K.EDGE_PAD;
    if (hi < lo) return viewportW * 0.5;
    return Math.min(Math.max(v, lo), hi);
  };

  const cores = [];
  const slots = [];
  for (let k = 0; k < groups.length; k++) {
    const count = groups[k];
    const cx = originX + (k % gCols) * (colW + K.CELL_GAP_X) + colW * 0.5;
    const cy = originY + rowTop[Math.floor(k / gCols)] + rowH[Math.floor(k / gCols)] * 0.5;
    cores.push({ cluster: k, x: cx, y: cy, d: coreD });
    for (let i = 0; i < count; i++) {
      const isMini = i >= K.RING_SLOTS;
      const nodeD = isMini ? miniD : d;
      let ux;
      let uy;
      if (!isMini) {
        ux = ringUnitX(i); uy = ringUnitY(i);
      } else {
        const k2 = i - K.RING_SLOTS;
        const band = Math.floor(k2 / K.OUTER_COUNT);
        const bandStart = K.RING_SLOTS + band * K.OUTER_COUNT;
        const bandSize = Math.min(K.OUTER_COUNT, count - bandStart);
        const idx = k2 - band * K.OUTER_COUNT;
        const ang = 2 * Math.PI * idx / bandSize;
        const r = K.OUTER_RADIUS + band;
        ux = r * Math.cos(ang); uy = r * Math.sin(ang);
      }
      slots.push({
        cluster: k, mini: isMini, d: nodeD,
        x: clampInside(cx + ux * pitch, nodeD / 2),
        y: cy + uy * pitch,
        rawX: cx + ux * pitch
      });
    }
  }
  return { contentHeight, d, scroll, gCols, gRows, cores, slots, bandW, bandH, miniD };
};

// ---------------------------------------------------------------------------
// 2. 真实演示分布（按 DemoMockData 的种子与 extend/trim 规则算出）
//    顺序固定为 TYPE_ORDER = 生活 / 学习 / 目标 / 兴趣
// ---------------------------------------------------------------------------
const DISTRIBUTIONS = [
  { count: 4, groups: [1, 1, 1, 1], note: '下限：四种类型各一条' },
  { count: 8, groups: [3, 1, 3, 1], note: 'trim 后仍覆盖四种类型' },
  { count: 14, groups: [5, 3, 4, 2], note: '默认（手工种子全量）' },
  { count: 16, groups: [6, 4, 4, 2], note: '生活簇刚好排满一圈' },
  { count: 19, groups: [7, 4, 5, 3], note: '出现第一个外圈小圆点' },
  { count: 25, groups: [8, 6, 6, 5], note: '' },
  { count: 30, groups: [9, 7, 8, 6], note: '' },
  { count: 40, groups: [12, 10, 10, 8], note: '' },
  { count: 50, groups: [14, 12, 13, 11], note: '' },
  { count: 60, groups: [17, 15, 15, 13], note: '上限' }
];

const VIEW_W = 377;
const VIEW_H = 816;

// 复刻 A_Garden 的验收口径
const MIN_GAP = 2; // 相邻节点之间至少要留的视觉间隙（vp）

let oneScreen = 0;
let scrolling = 0;
const report = [];

for (const { count, groups, note } of DISTRIBUTIONS) {
  assert.equal(groups.reduce((a, b) => a + b, 0), count, `${count} 条的分布表自身不自洽`);
  const r = layout(groups, VIEW_W, VIEW_H);
  const tag = `${String(count).padStart(2)} 条`;

  // 2.1 同簇内两两不重叠（跨簇由 cell 分隔，另测）
  for (let a = 0; a < r.slots.length; a++) {
    for (let b = a + 1; b < r.slots.length; b++) {
      const sa = r.slots[a];
      const sb = r.slots[b];
      if (sa.cluster !== sb.cluster) continue;
      const dist = Math.hypot(sa.x - sb.x, sa.y - sb.y);
      const need = (sa.d + sb.d) / 2 + MIN_GAP;
      assert.ok(dist >= need - 0.001,
        `${tag}：同簇两个节点挨在一起（中心距 ${dist.toFixed(1)} < 需 ${need.toFixed(1)}）`
        + `@(${sa.x.toFixed(0)},${sa.y.toFixed(0)}) 与 (${sb.x.toFixed(0)},${sb.y.toFixed(0)})`);
    }
  }

  // 2.1b 跨簇也不许重叠。
  // 单列滚动时行高按「每簇自己的包络」算，一旦某簇的包络算小了（比如漏算外圈小圆点的
  // 纵向分力），上下两朵花就会压在一起 —— 这是条数放大后最容易出现的观感问题，
  // 必须由数值护栏兜住，不能靠看截图发现。
  for (let a = 0; a < r.slots.length; a++) {
    for (let b = a + 1; b < r.slots.length; b++) {
      const sa = r.slots[a];
      const sb = r.slots[b];
      if (sa.cluster === sb.cluster) continue;
      const dist = Math.hypot(sa.x - sb.x, sa.y - sb.y);
      const need = (sa.d + sb.d) / 2 + MIN_GAP;
      assert.ok(dist >= need - 0.001,
        `${tag}：相邻两簇的节点压在一起（中心距 ${dist.toFixed(1)} < 需 ${need.toFixed(1)}）`
        + `@(${sa.x.toFixed(0)},${sa.y.toFixed(0)}) 与 (${sb.x.toFixed(0)},${sb.y.toFixed(0)})`);
    }
  }

  // 2.2 节点必须完整落在屏内（clamp 不应被触发）
  for (const s of r.slots) {
    assert.ok(Math.abs(s.rawX - s.x) < 0.001,
      `${tag}：有节点横向越界被 clamp 拉回（raw ${s.rawX.toFixed(1)} → ${s.x.toFixed(1)}），会被看成被裁`);
    assert.ok(s.x - s.d / 2 >= K.EDGE_PAD - 0.001 && s.x + s.d / 2 <= VIEW_W - K.EDGE_PAD + 0.001,
      `${tag}：节点横向超出安全边距`);
  }
  // 花心也必须在屏内
  for (const c of r.cores) {
    assert.ok(c.x - c.d / 2 >= 0 && c.x + c.d / 2 <= VIEW_W, `${tag}：花心横向越界`);
    assert.ok(c.y - c.d / 2 >= K.TOP_INSET, `${tag}：花心被头部卡遮住`);
  }

  // 2.3 高度：一屏模式不得超高；滚动模式的 contentHeight 必须覆盖最后一个节点
  let maxBottom = 0;
  let minTop = Infinity;
  for (const s of r.slots) {
    maxBottom = Math.max(maxBottom, s.y + s.d / 2);
    minTop = Math.min(minTop, s.y - s.d / 2);
  }
  assert.ok(minTop >= K.TOP_INSET - 0.001,
    `${tag}：最高节点顶到 y=${minTop.toFixed(1)}，被头部玻璃卡遮住（下限 ${K.TOP_INSET}）`);

  if (r.scroll) {
    scrolling++;
    assert.ok(r.contentHeight > 0, `${tag}：滚动模式必须给出内容高度`);
    assert.ok(r.contentHeight >= maxBottom + K.BOTTOM_RESERVE - K.CELL_GAP_Y,
      `${tag}：内容高度 ${r.contentHeight.toFixed(0)} 盖不住最低节点 ${maxBottom.toFixed(0)}，滚到底仍看不全`);
    assert.ok(r.contentHeight > VIEW_H,
      `${tag}：被判为滚动模式，但内容高度 ${r.contentHeight.toFixed(0)} 并没有超过一屏 ${VIEW_H}`);
  } else {
    oneScreen++;
    assert.equal(r.contentHeight, 0, `${tag}：一屏模式必须返回 contentHeight=0`);
    assert.ok(maxBottom <= VIEW_H - K.BOTTOM_RESERVE + 0.001,
      `${tag}：一屏模式的最低节点 ${maxBottom.toFixed(0)} 压到悬浮 Tab 栏（预留 ${K.BOTTOM_RESERVE}）`);
    assert.ok(r.gCols === 2 || groups.length === 1, `${tag}：一屏模式下 4 簇应排成 2 列`);
  }

  report.push(`${tag} 分布[${groups.join('/')}] ${r.scroll ? '滚动' : '一屏'}`
    + ` 列×行=${r.gCols}×${r.gRows} 直径Ø${r.d.toFixed(1)} 小点Ø${r.miniD.toFixed(1)}`
    + ` 高度${r.scroll ? r.contentHeight.toFixed(0) : VIEW_H}`
    + (note ? `  ← ${note}` : ''));
}

// ---------------------------------------------------------------------------
// 3. 模式切换的边界：一圈排满（6 个）仍是一屏；出现第 7 个才转为滚动
// ---------------------------------------------------------------------------
assert.equal(layout([6, 6, 6, 6], VIEW_W, VIEW_H).scroll, false,
  '每簇 6 个（正好一圈）时仍应一屏放下');
assert.equal(layout([7, 6, 6, 6], VIEW_W, VIEW_H).scroll, true,
  '某一簇出现第 7 个（外圈小圆点）时包络变宽，应转为滚动：否则会被压到重叠');
assert.equal(layout([6, 6, 6, 6], VIEW_W, VIEW_H).slots.filter((s) => s.mini).length, 0,
  '每簇 6 个时不应有小圆点');
assert.equal(layout([7, 6, 6, 6], VIEW_W, VIEW_H).slots.filter((s) => s.mini).length, 1,
  '第 7 个应恰好产生 1 个小圆点');

// 容量：每簇 18 = 6（环）+ 12（外圈第一圈）；第 19 个必须自动开到第二圈而不是叠在第一圈
const overflow = layout([19], VIEW_W, VIEW_H);
const minis = overflow.slots.filter((s) => s.mini);
const pitch = overflow.d + K.GAP;
const focus = overflow.cores[0];
const radii = minis.map((s) => Math.hypot(s.x - focus.x, s.y - focus.y) / pitch);
assert.equal(minis.length, 13, '19 条应产生 13 个外圈小圆点');
assert.equal(radii.filter((v) => Math.abs(v - 2) < 0.01).length, 12,
  '外圈第一圈（半径 2 个列距）最多 12 个');
assert.equal(radii.filter((v) => Math.abs(v - 3) < 0.01).length, 1,
  '第 13 个溢出小圆点必须开到半径 3 个列距的第二圈，否则会叠在第一圈上');
// 只有一朵花时整屏都归它用，所以 19 条仍能一屏放下（说明「要不要滚动」取决于
// 4 簇的总包络，而不是单簇条数的绝对值）
assert.equal(overflow.scroll, false, '单簇时整屏只放一朵花，19 条也应一屏放下');
for (const s of overflow.slots) {
  assert.ok(s.x - s.d / 2 >= K.EDGE_PAD - 0.001 && s.x + s.d / 2 <= VIEW_W - K.EDGE_PAD + 0.001,
    '单簇 19 条时仍有节点横向越界');
}

// 空输入与单簇
assert.equal(layout([1], VIEW_W, VIEW_H).scroll, false, '只有一条记忆时不应滚动');
assert.equal(layout([1], VIEW_W, VIEW_H).slots.length, 1, '只有一条记忆时应只有一个节点');
assert.equal(layout([1], VIEW_W, VIEW_H).slots[0].mini, false, '唯一的一条不能被画成装饰小圆点');

console.log('记忆花园放大仿真通过：4~60 条共 ' + DISTRIBUTIONS.length + ' 组分布，'
  + oneScreen + ' 组一屏放下、' + scrolling + ' 组转为向下生长，均无重叠 / 越界 / 遮挡。');
for (const line of report) {
  console.log('  ' + line);
}
