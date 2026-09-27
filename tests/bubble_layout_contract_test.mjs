/*
 * ============================================================================
 * 文件名：tests/bubble_layout_contract_test.mjs
 * ============================================================================
 * 【用途】气泡花园的静态契约测试（与 t3_contract_test.mjs 同风格：只读源码做断言，
 *   不依赖 ArkTS 运行时，任意装有 Node 的机器都能跑）。
 *   守护 5 件事：
 *     1. 布局是「4 类分簇 + 手写蜂窝偏移表」的确定性算法，尺寸集中在一处常量区；
 *     2. 蜂窝间距必须按【最大直径 MAIN_D】校验，且簇间只按 y 分隔（不重叠的结构化保证）；
 *     3. 主圆是纯圆且圆内只有「图标 + 日期」，小圆点是不可点的纯装饰；
 *     4. 「重要回忆」已从类型降级为标签：只画 4 类，且旧数据有迁移路径；
 *     5. 旧的花园地图实现（GardenNodeMarker / nodePosOf / GardenNodeItem / 坐标表）零残留。
 *
 * 【前置条件 / 假设】
 *   - 假设：仓库根目录即本文件所在目录的上一级；
 *   - 假设：断言基于源码文本结构；重命名文件/方法需同步更新本测试。
 *
 * 【输入 / 输出（后置条件）】
 *   - 输入：entry/src/main/ets 下的若干源文件；
 *   - 输出：全部通过时打印一行成功信息；任一失败时抛 AssertionError 并以非 0 退出。
 * ============================================================================
 */
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const testDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(testDir, '..');

const read = async (relativePath) => readFile(path.join(root, relativePath), 'utf8');

const [bubbleLayout, memoryBubble, garden, models, modeMenu, mainPage, mockData, demoMockData, syncSource] =
  await Promise.all([
    read('entry/src/main/ets/utils/BubbleLayout.ets'),
    read('entry/src/main/ets/components/MemoryBubble.ets'),
    read('entry/src/main/ets/pages/A_Garden.ets'),
    read('entry/src/main/ets/model/Models.ets'),
    read('entry/src/main/ets/components/ModeMenu.ets'),
    read('entry/src/main/ets/pages/MainPage.ets'),
    read('entry/src/main/ets/mock/MockData.ets'),
    read('entry/src/main/ets/mock/DemoMockData.ets'),
    read('entry/src/main/ets/service/DataSyncService.ets')
  ]);

const stripLineComments = (text) =>
  text.split('\n').filter((line) => !line.trim().startsWith('*') && !line.trim().startsWith('//')).join('\n');

// ---------------------------------------------------------------------------
// 1. 布局工具：入口签名与关键常量
// ---------------------------------------------------------------------------
assert.match(bubbleLayout, /export class BubbleLayoutUtil/, 'BubbleLayoutUtil 缺失');
assert.match(bubbleLayout, /static layout\(memories: Memory\[\], viewportW: number, viewportH: number\): BubbleLayoutResult/,
  'layout() 签名变化：自适应直径要同时用屏宽与屏高反解，目标是把 4 簇装进一屏');
assert.match(bubbleLayout, /export class BubbleSlot/, 'BubbleSlot 缺失');
assert.match(bubbleLayout, /export class FlowerCore/, 'FlowerCore 缺失');
assert.match(bubbleLayout, /export class BubbleLayoutResult/, 'BubbleLayoutResult 缺失');
// 【核心契约 0】内容高度语义：「一屏放下」与「向下生长」由布局单向决定，页面不自己猜
//   contentHeight = 0  → 一屏放下，页面不要套 Scroll（记忆少时保持原有观感）
//   contentHeight > 0  → 需要滚动，页面据此套 Scroll
assert.match(bubbleLayout, /contentHeight: number = 0;/,
  'BubbleLayoutResult 缺少 contentHeight（0=一屏放下，>0=需要滚动的内容高度）');
assert.match(bubbleLayout, /result\.contentHeight = scroll/,
  'contentHeight 未由排布模式推导出来');
assert.match(bubbleLayout, /private static solveD\(gCols: number, gRows: number/,
  '缺少 solveD()：直径反解必须集中在一处，否则两种模式的预算会各算一遍而互相矛盾');
assert.match(bubbleLayout, /if \(dOneScreen < BubbleLayoutUtil\.MIN_D\) \{/,
  '一屏放不下（反解直径低于下限）时应退化为滚动模式，而不是把圆挤到叠在一起');
assert.match(bubbleLayout, /availH <= 0 表示|availH: number, availH: number\): number/,
  'solveD 缺少「不限制高度」的滚动模式入口');

for (const constant of ['EDGE_PAD', 'TOP_INSET', 'BOTTOM_RESERVE', 'MAX_D', 'MIN_D', 'GAP',
  'CELL_GAP_X', 'CELL_GAP_Y', 'CELL_SLACK', 'RING_SLOTS', 'CORE_RATIO', 'OUTER_RADIUS',
  'OUTER_COUNT', 'MINI_RATIO']) {
  assert.match(bubbleLayout, new RegExp(`private static readonly ${constant}: number =`),
    `布局常量 ${constant} 未集中在常量区定义`);
}

// 【核心契约 1】花心只是"很小的点"，承载记忆的圆全部在环上
// （真机实测：把花心点与记忆圆都放在 (0,0) 会完全重叠，实心点盖住圆的图标与日期）
assert.match(bubbleLayout, /CORE_RATIO: number = 0\.16/,
  '花心必须是很小的点（CORE_RATIO ≈ 0.16），不能与记忆圆同尺寸');
assert.match(bubbleLayout, /result\.cores\.push\(new FlowerCore\(type, cx, cy, coreD\)\);/,
  '花心点应固定在簇中心');
assert.match(bubbleLayout, /const x: number = BubbleLayoutUtil\.clampInside\(cx \+ ux \* pitch/,
  '记忆节点未以花心为原点按环位偏移落位：不构成"环绕"');

// 【核心契约 2】环位必须等弧长（每 60°），弦长 = 1.0 个列距
// 数值实测踩过：用六角格 6 邻位时最近邻只有 0.518P，圆会叠得很厉害
assert.match(bubbleLayout, /RING_SLOTS: number = 6/, 'RING_SLOTS 应为 6（每 60° 一个位）');
assert.match(bubbleLayout, /return Math\.cos\(2 \* Math\.PI \* i \/ BubbleLayoutUtil\.RING_SLOTS\);/,
  '环位横向偏移必须用 cos(60°×i) 现算，不能手写表格（手写表是前几轮反复出错的根源）');
assert.match(bubbleLayout, /return Math\.sin\(2 \* Math\.PI \* i \/ BubbleLayoutUtil\.RING_SLOTS\);/,
  '环位纵向偏移必须用 sin(60°×i) 现算');

// 【核心契约 2b】溢出的小圆点必须能自动再往外开一圈
// 每簇上限 6（环）+ 12（外圈第一圈）= 18 条；超过时必须开第二圈，
// 否则 (i - RING_SLOTS) % OUTER_COUNT 会把多出来的点叠在同一圈上（互相盖住）
assert.match(bubbleLayout, /const band: number = Math\.floor\(k2 \/ BubbleLayoutUtil\.OUTER_COUNT\);/,
  '外圈小圆点未按圈分组：条数超过 18 时会叠在同一圈上');
assert.match(bubbleLayout, /const r: number = BubbleLayoutUtil\.OUTER_RADIUS \+ band;/,
  '第 band 圈的半径应为 OUTER_RADIUS + band');

// 【核心契约 3】直径必须自适应，不能写死
assert.match(bubbleLayout, /let d: number = budgetW \/ coefW;/,
  '直径未由可用宽度反解');
assert.match(bubbleLayout, /d = Math\.min\(d, budgetH \/ coefH\);/,
  '一屏模式下直径必须同时受可用高度约束');
assert.match(bubbleLayout, /d = Math\.max\(d, BubbleLayoutUtil\.MIN_D\)/,
  '缺少直径下限');
assert.match(bubbleLayout, /d = Math\.min\(d, BubbleLayoutUtil\.MAX_D\)/,
  '缺少直径上限');

// ---------------------------------------------------------------------------
// 2. 「重要回忆」是标签而非类型
// ---------------------------------------------------------------------------
const typeOrderBlock = bubbleLayout.match(/TYPE_ORDER: MemoryType\[\] = \[([\s\S]*?)\];/)[1];
for (const t of ['LIFE', 'STUDY', 'GOAL', 'INTEREST']) {
  assert.ok(typeOrderBlock.includes(`MemoryType.${t}`), `TYPE_ORDER 缺少 ${t}`);
}
assert.ok(!typeOrderBlock.includes('IMPORTANT'),
  'TYPE_ORDER 仍包含 IMPORTANT：「重要回忆」应是标签而不是类型，否则会多出一个簇');
assert.equal((typeOrderBlock.match(/MemoryType\./g) || []).length, 4,
  'TYPE_ORDER 必须恰好 4 类（4 个标签圆圈）');

assert.match(models, /export const IMPORTANT_MEMORY_TAG: string = '重要回忆';/,
  'Models 缺少 IMPORTANT_MEMORY_TAG 常量');
assert.match(models, /export const GOAL_IMPORTANT_IMPORTANCE: number = 5;/,
  'Models 缺少 GOAL_IMPORTANT_IMPORTANCE 常量');
assert.match(models, /IMPORTANT = 4\s*\n\}/,
  'MemoryType.IMPORTANT 必须保留（旧数据用它），只是不再作为新类型使用');

// 旧数据迁移：类型归到目标 + 补「重要回忆」标签
assert.match(syncSource, /private static migrateType\(storedType: number\): MemoryType/,
  'DataSyncService 缺少类型迁移：旧 IMPORTANT 数据会不属于任何一簇而消失');
assert.match(syncSource, /if \(storedType === MemoryType\.IMPORTANT\) \{\s*return MemoryType\.GOAL;/,
  '迁移规则应为 IMPORTANT -> GOAL');
assert.match(syncSource, /private static migrateTags\(storedType: number, tags: string\[\]\): string\[\]/,
  'DataSyncService 缺少标签迁移：旧数据不会补上「重要回忆」标签');
assert.match(syncSource, /memory\.type = DataSyncService\.migrateType\(stored\.type\);/,
  'storedMemoryToCloud 未走类型迁移：迁移后的数据回写云端仍是旧类型');

// ---------------------------------------------------------------------------
// 3. 主圆：纯圆 + 圆内只有图标与日期 + 修掉方形阴影
// ---------------------------------------------------------------------------
assert.match(memoryBubble, /export struct MemoryBubble/, 'MemoryBubble 缺失');
assert.doesNotMatch(memoryBubble, /\.position\(/,
  'MemoryBubble 不应自定位：位置由父级按 BubbleLayoutUtil 结果绝对定位');

const bubbleCode = stripLineComments(memoryBubble);
assert.doesNotMatch(bubbleCode, /textOverflow|\.width\(108\)/,
  'MemoryBubble 出现了标签式排版特征（旧标记宽 110vp 的问题可能回归）');

// 圆内唯一一处 Text（日期）；且必须用派生色而非硬编码色值
const textCount = (memoryBubble.match(/^ *Text\(/gm) || []).length;
assert.equal(textCount, 1, `MemoryBubble 圆内只应有一处 Text（日期），实际 ${textCount} 处`);
assert.match(memoryBubble, /MemoryTypeUtil\.bubbleBgOf\(this\.memory\.type\)/,
  '底圆未使用派生的浅色 bubbleBgOf：图标与底色的对比度无法保证');
assert.match(memoryBubble, /MemoryTypeUtil\.iconColorOf\(this\.memory\.type\)/,
  '图标未使用派生的深色 iconColorOf：对比度无法保证');

// 点击性能与闪烁：key 不能带选中态、气泡不能有透明度动画、选中不能重算布局
// 【真机实测】key 带选中态 → 点一颗会让全部气泡 key 失效 → ArkUI 重建所有组件 →
// 入场透明度动画重放，表现为"两颗一起闪" + 明显延迟。
const itemClass = garden.match(/class BubbleItem \{([\s\S]*?)\n\}/)[1];
assert.ok(!/selectedId|sel \+/.test(itemClass),
  'BubbleItem.keygen 不能带选中态：否则点任意一颗都会重建全部气泡（闪烁 + 延迟）');
assert.match(itemClass, /this\.keygen = memory\.id;/,
  'BubbleItem 的 key 应只由 memory.id 构成');
assert.ok(!/\.opacity\(this\.entered/.test(memoryBubble),
  'MemoryBubble 不能有入场透明度动画：组件重建时会先透明再淡入，造成闪烁');
assert.ok(!/aboutToAppear\(\): void \{\s*\n\s*setTimeout/.test(memoryBubble),
  'MemoryBubble 不应挂 setTimeout：每颗气泡一个定时器会拖慢点击响应');
assert.match(garden, /private syncBubbleSelection\(\): void \{/,
  '缺少 syncBubbleSelection()：选中态应只更新 @Prop，不重算布局');
const selectBlock = garden.match(/private selectMemory\(m: Memory\): void \{([\s\S]*?)\n  \}/)[1];
assert.match(selectBlock, /this\.syncBubbleSelection\(\);/,
  'selectMemory() 未走 syncBubbleSelection()');
assert.ok(!/recomputeBubbleLayout\(\)/.test(selectBlock),
  'selectMemory() 不能重算布局：每次点击都跑整轮布局会让交互变慢');

// 方形裁切/方形阴影：不能依赖 .shadow()，也不能有超出圆的层
// 【真机实测两轮】ArkUI 的 shadow 与 border 都按**外接矩形**绘制、不跟随 borderRadius：
//   - 直接给圆加 .shadow() → 四角出现方形阴影；
//   - 外面套 clip(true) → 圆的直线段处仍会透出矩形栅格的边；
//   - 改用两层半透明同心圆模拟柔光 → 叠出脏色描边。
// 最终方案：完全不用 shadow，只保留「浅色底圆 + 干净描边」（Apple Watch 图标本身就是扁平的）。
const bubbleCodeForPaint = stripLineComments(memoryBubble);
assert.ok(!/\.shadow\(/.test(bubbleCodeForPaint),
  'MemoryBubble 又用了 .shadow()：它按外接矩形绘制，会在圆外留下方形边或脏色描边');
assert.match(memoryBubble, /MemoryTypeUtil\.borderOf\(this\.memory\.type\)/,
  '描边未使用派生的 borderOf 颜色');
assert.match(memoryBubble, /\.width\(this\.d \* 0\.88\)/,
  '圆内内容未留余量：内容触到圆边会显得被裁');
// 所有可见层都必须是圆：不得出现非圆角矩形尺寸（高度/宽度应成对相等）
const sizePairs = (memoryBubble.match(/\.width\(this\.d[^)]*\)\s*\n\s*\.height\(this\.d[^)]*\)/g) || []).length;
assert.ok(sizePairs >= 1, '底圆必须是 width/height 相等的正方形 + borderRadius(圆)');

// 按压/入场三态仍由 animateTo 曲线驱动，不引入自维护定时器
assert.match(memoryBubble, /TouchType\.Down/, 'MemoryBubble 缺少按压反馈');
assert.doesNotMatch(memoryBubble, /setInterval/,
  'MemoryBubble 引入了自维护定时器：本项目统一用 animateTo 触发式动效');

// ---------------------------------------------------------------------------
// 4. 页面接线：4 个标签、小圆点装饰、自由滚动
// ---------------------------------------------------------------------------
assert.match(garden, /bubbleView\(\)/, 'A_Garden 缺少 bubbleView()');
assert.match(garden, /gardenHeader\(\)/, 'A_Garden 缺少共用的 gardenHeader()');
assert.match(garden, /this\.repo\.getAll\(\)\.slice\(\)/,
  'bubbleView 未直接从仓库取数：先于 repoListener 渲染时会读到过期的 this.memories');
assert.match(garden, /BubbleLayoutUtil\.layout\(list, this\.viewportW, this\.viewportH\)/,
  '布局未用仓库快照 list、或未同时传入屏宽屏高');
assert.match(garden, /MemoryBubble\(\{/, 'A_Garden 未使用 MemoryBubble 组件');
assert.match(garden, /onAreaChange/, 'A_Garden 缺少 onAreaChange：未拿到真实尺寸就计算布局会导致错位');
// 气泡区：记忆少时不滚动（内容高度==视口，Scroll 滚不动），
// 记忆多到一屏放不下时由布局给出内容高度，才允许滚动。
// 【为什么必须由布局决定】固定直径 + 一簇一行时 4 簇远超一屏，表现为
// 「必须滚动 + 圆圈被裁 + 气泡压到下一簇花心」；反过来在记忆很少时套 Scroll，
// 又会出现过滚动回弹把圆晃出屏幕。两个分支必须渲染同一份花田。
const bubbleStart = garden.indexOf('bubbleView() {');
const bubbleEnd = garden.indexOf('outlineView() {', bubbleStart);
assert.ok(bubbleStart >= 0 && bubbleEnd > bubbleStart, 'bubbleView() 段落无法定位');
const bubbleViewBlock = garden.slice(bubbleStart, bubbleEnd);
assert.match(garden, /bubbleField\(h: number\) \{/,
  '花田未抽成 @Builder bubbleField()：Scroll 内外的渲染内容会不一致');
// 顶部不能再用「从头部下沿硬裁」：用户截图指出那条直边很生硬，
// 现在改为整屏滚动 + linearGradientBlur 让内容化进标题栏与玻璃卡。
assert.match(bubbleViewBlock, /\.linearGradientBlur\(TOP_FADE_BLUR, \{/,
  '滚动区缺少顶部线性渐变模糊：内容会在标题栏/玻璃卡下沿被切出硬边');
assert.match(bubbleViewBlock, /direction: GradientDirection\.Bottom/,
  '渐变模糊方向必须是自上而下');
assert.match(bubbleViewBlock, /\[0\.0, BubbleLayoutUtil\.topInset\(\) \/ this\.viewportH\]/,
  '渐隐止点必须跟着布局的头部预留高度走，否则要么首屏内容被糊、要么卡片下沿仍露硬边');
assert.ok(!/\.padding\(\{ top: BubbleLayoutUtil\.topInset\(\) \}\)/.test(bubbleViewBlock),
  '又用 padding 把滚动区裁到头部下沿了：这就是那条硬边的来源');
assert.equal((bubbleViewBlock.match(/this\.bubbleField\(/g) || []).length, 2,
  'bubbleView 的两个分支应各渲染一次 bubbleField()');
const countGuard = bubbleViewBlock.indexOf('if (this.bubbleLayout.contentHeight > 0) {');
const scrollCall = bubbleViewBlock.indexOf('Scroll() {');
assert.ok(countGuard >= 0, 'bubbleView 缺少 contentHeight>0 的判断：记忆多时会退回到「圆圈被裁」');
assert.ok(scrollCall > countGuard,
  'Scroll 未被 contentHeight>0 包住：记忆少时也会出现不必要的滚动与回弹');
assert.match(bubbleViewBlock, /\.edgeEffect\(EdgeEffect\.None\)/,
  '滚动容器未关闭回弹：内容刚好一屏时会抖一下');

// 头部只列 4 种类型
const headerBlock = garden.match(/gardenHeader\(\) \{([\s\S]*?)\n  \}/)[1];
assert.ok(!headerBlock.includes('MemoryType.IMPORTANT'),
  'gardenHeader 图例仍包含「重要回忆」：应只有 4 项');
assert.equal((headerBlock.match(/MemoryType\.[A-Z]+/g) || []).length, 4,
  'gardenHeader 图例必须恰好 4 种类型');

// 花心只画成纯色小圆点（不写文字与数字，也不承载记忆）；小圆点走同一颜色且不可点
assert.match(garden, /ForEach\(this\.bubbleLayout\.cores/,
  '未渲染花心点（cores）');
assert.match(garden, /\.width\(c\.d\)\s*\n\s*\.height\(c\.d\)/,
  '花心点应按布局给出的 coreD 尺寸绘制（很小的点）');

// 【真机实测坑：ForEach 的 item 生成函数里不能写 if】
// 小圆点曾经写成 ForEach(bubbleLayout.slots) { if (s.mini) { ... } } 且 key 不含坐标。
// 结果：切换演示条数后，键不变的那颗小圆点**连分支里的 .position() 都不重算**，
// 停在上一个条数的位置上；同时本该出现的新位置又缺一颗（实测 24→37 条时多一颗在
// 旧位置、少一颗在新位置）。现在拆成独立数组 + 带坐标的 key，两者都是必需的。
assert.match(garden, /@State bubbleMinis: BubbleSlot\[\] = \[\];/,
  '缺少 bubbleMinis：小圆点必须走独立数组，不能在 ForEach 里用 if 分支');
assert.match(garden, /ForEach\(this\.bubbleMinis, \(s: BubbleSlot\) => \{/,
  '小圆点未走独立数组渲染');
const miniForEach = garden.match(/ForEach\(this\.bubbleMinis[\s\S]*?\n      \}, \(s: BubbleSlot\) => ([^\n]*(?:\n[^\n]*){0,2})/);
assert.ok(miniForEach, '小圆点的 ForEach 段落无法定位');
assert.ok(!/if \(s\.mini\)/.test(miniForEach[0]),
  '小圆点的 ForEach 里又出现了 if 分支：键不变时分支内的属性不会重算');
assert.match(miniForEach[1], /s\.x\.toFixed\(1\)/,
  '小圆点的 key 必须带坐标：否则布局一变（条数变化）位置会留在旧值');
assert.match(miniForEach[1], /s\.y\.toFixed\(1\)/,
  '小圆点的 key 必须带坐标（y）');

for (const gone of ['gardenView\\(', 'nodePosOf', 'GardenNodeItem', 'GardenNodeMarker', 'bubbleContentH']) {
  assert.doesNotMatch(stripLineComments(garden), new RegExp(gone),
    `A_Garden 仍残留旧实现: ${gone}`);
}
assert.doesNotMatch(mockData, /GardenNodeItem|buildGardenNodes|MemoryType\.IMPORTANT/,
  'MockData 仍引用已废弃的花园节点类型或 IMPORTANT 类型');
assert.doesNotMatch(demoMockData, /GardenNodeItem|buildGardenNodes|MemoryType\.IMPORTANT/,
  'DemoMockData 仍引用已废弃的花园节点类型或 IMPORTANT 类型');

// ---------------------------------------------------------------------------
// 5. 配色：只维护一个 base，其余两档派生；四类语义色符合约定
// ---------------------------------------------------------------------------
assert.match(models, /static iconColorOf\(t: MemoryType\): string/,
  '缺少 iconColorOf：图标色应派生而非硬编码');
assert.match(models, /static bubbleBgOf\(t: MemoryType\): string/,
  '缺少 bubbleBgOf：底圆色应派生而非硬编码');
assert.match(models, /private static tint\(hex: string, ratio: number\): string/,
  '缺少 tint 派生函数');
assert.match(models, /private static shade\(hex: string, ratio: number\): string/,
  '缺少 shade 派生函数');
// 生活=橙 学习=蓝 目标=红 兴趣=绿
assert.match(models, /'#E98A32';     \/\/ 橙（生活）/,
  '生活的主色应为橙');
assert.match(models, /'#3E86E0';   \/\/ 蓝/,
  '学习的主色应为蓝');
assert.match(models, /'#2FA26A';   \/\/ 绿/,
  '兴趣的主色应为绿');
assert.match(models, /'#E25C5C';   \/\/ 红/,
  '目标的主色应为红');

// ---------------------------------------------------------------------------
// 6. 枚举与入口
// ---------------------------------------------------------------------------
const gardenEnumStart = models.indexOf('export enum GardenMode {');
const gardenEnumBody = models.slice(gardenEnumStart, models.indexOf('}', gardenEnumStart));
assert.match(gardenEnumBody, /GARDEN = 0,/, 'GardenMode.GARDEN 数值被改动：会破坏 AppStorage 兼容');
assert.match(gardenEnumBody, /OUTLINE = 1,/, 'GardenMode.OUTLINE 数值被改动');
assert.match(gardenEnumBody, /TREE = 2,/, 'GardenMode.TREE 数值被改动');
assert.match(gardenEnumBody, /BUBBLE = 3/, 'GardenMode.BUBBLE 未定义或数值不是 3');

assert.match(modeMenu, /气泡花园/, 'ModeMenu 未提供气泡花园入口');
assert.match(modeMenu, /GardenMode\.BUBBLE/, 'ModeMenu 未指向 GardenMode.BUBBLE');
assert.match(mainPage, /气泡花园/, 'MainPage 标题栏菜单未提供气泡花园入口');
assert.match(mainPage, /switchTo\(GardenMode\.BUBBLE\)/, 'MainPage 未提供切回气泡花园的动作');

console.log('气泡花园契约检查通过：4 类分簇、蜂窝偏移表、纯圆主圆、小圆点装饰、标签化重要回忆、配色派生均符合约定。');
