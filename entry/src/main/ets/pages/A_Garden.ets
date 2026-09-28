/*
 * ============================================================================
 * 文件名：pages/A_Garden.ets
 * ============================================================================
 * 【用途】一级 Tab「记忆花园」：以三种视图展示记忆——
 *   BUBBLE（气泡花园：按记忆类型分簇、花瓣式蜂巢排布，默认视图）、OUTLINE（记忆大纲列表）、
 *   TREE（MemoryTreeGraph 记忆树），以及模式菜单(ModeMenu)、编辑浮窗、缩放浮钮（树模式 ±）。
 * 【前置条件 / 假设】
 *   - 依赖：MemoryRepository(订阅制)、GardenController（被 MainPage HDS 菜单调用）、
 *     ShellState.gardenScroller（滚动绑定）、BubbleLayoutUtil（气泡布局算法）；
 *   - 假设：详情面板/工具栏被“全屏容器”包裹时用 hitTestBehavior 放行点击；
 *     编辑浮窗与菜单浮窗均为“打开时挂载”，关闭不渲染。
 * 【输入 / 输出（后置条件）】
 *   - 输入：HDS 菜单按钮（搜索/更多）、模式菜单选择、气泡/列表点击、编辑提交、
 *     缩放按钮、拖动收起详情；
 *   - 输出：视图切换（switchMode）、选中记忆详情面板（selectMemory/closeDetail）、
 *     树缩放(treeZoom)、编辑写回 MemoryRepository、气泡布局重算(bubbleLayout)。
 * 【关键类 / 算法】
 *   - A_Garden：视图分发（mode 枚举 -> bubbleView/outlineView/treeView）；
 *   - gardenHeader：三种视图共用的玻璃卡头部（标题 + 计数 + 类型图例）；
 *   - BubbleLayoutUtil：分簇与落位；MemoryBubble：单个气泡；MemoryTreeGraph：树绘制；
 *   - detailH：详情面板高度（拖动收起，吸附 196/372 等档位）。
 * 【参考源】
 *   - HarmonyLearn（知识图谱/树的绘制思路）；Examples/ArkUISample；
 *     MoMo_DOC/UI 参考图（花园首页稿）
 * ============================================================================
 */
import { MemoryRepository } from '../repository/Repositories';
import { GardenController } from '../service/Services';
import { AppRouter, RouteName } from '../router/AppRouter';
import {
  GardenMode, Memory, MemoryTreeNode, MemoryType, MemoryTypeUtil, PageState
} from '../model/Models';
import { DateUtil } from '../utils/DateUtil';
import { Theme } from '../utils/Theme';
import { PromptUtil } from '../utils/PromptUtil';
import { DeviceUtil } from '../utils/DeviceUtil';
import { BubbleLayoutUtil, BubbleLayoutResult, BubbleSlot, FlowerCore } from '../utils/BubbleLayout';
import { ShellState } from '../service/Services';
import { ModeMenu } from '../components/ModeMenu';
import { MemoryBubble } from '../components/MemoryBubble';
import { MemoryTreeGraph } from '../components/MemoryTreeGraph';
import { GlassSheet } from '../components/GlassSheet';
import { LoadingState, EmptyState } from '../components/StateViews';

// 编辑快照：记录“某一条记忆”编辑前/后状态（用于按记忆隔离的撤销/重做）
interface EditSnapshot {
  id: string;
  title: string;
  tags: string[];
  summary: string;
  label: string;
}

// 滚动模式下的顶部渐隐：内容越往上越模糊，最后"化"进头部玻璃卡与标题栏，
// 而不是被切出一条生硬直边（用户在截图里指出过这条硬边）。
//
// 【为什么止点要按布局的头部预留高度算，而不是拍一个比例】
//   硬边其实有两处：① 标题栏下沿（内容直接滑到标题文字底下）；② 头部玻璃卡的下沿
//   （不透明卡片的直线边缘把圆点切成两半）。渐隐区必须**正好覆盖头部那一段**：
//     - 止点 = TOP_INSET / 屏高（≈0.28）：偏移为 0 时第一排节点最低在 TOP_INSET 处，
//       所以首屏内容永远落在模糊区之外、保持清晰；
//     - 中段止点取 0.86×止点（≈卡片下沿 196vp 处）并保留 70% 模糊：圆点刚从卡片下沿
//       露出来时是"糊着"的，往下 30vp 内迅速变清晰 —— 视觉上就是"从卡片里化出来"。
const TOP_FADE_BLUR: number = 24;
/** 卡片下沿处的模糊强度（相对 TOP_FADE_BLUR 的比例）：越高，硬边越不明显 */
const TOP_FADE_EDGE_RATIO: number = 0.7;

// 气泡渲染项：把「记忆数据」与「布局槽位」绑定在一起。
// 存在的意义是让 ForEach 遍历一个已经对齐好的数组，而不是在渲染过程中查仓库。
// keygen 是预先算好的稳定 key：ArkTS 的 ForEach keyGenerator 只允许引用参数本身，
// 不能写 this.xxx 或复杂表达式，所以 key 必须在构造时算好存成字段。
//
// 【key 里绝对不能带选中态】这是性能与闪烁的根因：
// 若 key 随选中态变化，点任意一颗气泡都会让**所有**气泡的 key 失效，
// ArkUI 会销毁并重建全部组件 → 重建时 entered=false 先渲染成透明再淡入，
// 视觉上就是「两颗按钮一起闪」+ 明显延迟。选中态改由 @Prop selected 透传即可。
class BubbleItem {
  memory: Memory;
  slot: BubbleSlot;
  keygen: string;

  constructor(memory: Memory, slot: BubbleSlot) {
    this.memory = memory;
    this.slot = slot;
    this.keygen = memory.id;
  }
}

@Component
export struct A_Garden {
  @State pageState: PageState = PageState.LOADING;
  @State mode: GardenMode = GardenMode.BUBBLE;
  @State memories: Memory[] = [];
  @State selectedMemory: Memory | null = null;
  @State detailH: number = 196;
  @State menuOpen: boolean = false;
  @State searchOpen: boolean = false;
  @State searchText: string = '';
  @State detailOpen: boolean = false;
  @State editorMode: boolean = false;
  // 撤销/重做：按记忆 id 隔离（内存表 + 当前记忆的 @State 副本用于刷新 UI）
  private undoMaps: Map<string, EditSnapshot[]> = new Map();
  private redoMaps: Map<string, EditSnapshot[]> = new Map();
  @State undoStack: EditSnapshot[] = [];
  @State redoStack: EditSnapshot[] = [];
  @State treeZoom: number = 1;
  // ===== 气泡花园 =====
  // bubbleLayout 由 BubbleLayoutUtil 计算（分簇 + 落位 + 焦点缩放），
  // 在记忆变化/切回气泡模式时重算；Viewport 尺寸来自 onAreaChange。
  @State bubbleLayout: BubbleLayoutResult = new BubbleLayoutResult();
  // 已与数据对齐的渲染列表：在 recomputeBubbleLayout() 里一次算好，
  // 避免在 ForEach 内反复查仓库（既低效，又依赖非响应式数据导致刷新不确定）
  @State bubbleItems: BubbleItem[] = [];
  // 溢出小圆点单独成一个数组，**不要**在 ForEach 里写 if：ArkUI 的 ForEach 一旦在
  // item 生成函数里带条件分支，键不变时连分支里的属性都不会重算 —— 实测表现为
  // 「切换演示条数后，某个小圆点还停在上一个条数的位置上，另一些位置则整颗消失」。
  // 拆成独立数组后，键里再带上坐标，几何一变就必然重建。
  @State bubbleMinis: BubbleSlot[] = [];
  // 当前选中记忆的 id 副本：ForEach 的 keyGenerator 只能访问参数，
  // 用它把选中态拼进 key，保证选中变化时该气泡重建（焦点环/日期不会滞留）
  @State bubbleSelectedId: string = '';
  @State viewportW: number = 360;
  @State viewportH: number = 780;
  @State editTitle: string = '';
  @State editTags: string = '';
  @State editSummary: string = '';
  private repo: MemoryRepository = MemoryRepository.get();
  private repoListener: () => void = () => {
  };
  private panBase: number = 196;
  // 气泡视图自己按 contentHeight 决定要不要滚动（记忆多时用局部 Scroll），
  // 但 MainPage 仍把这个 Scroller 交给 HdsNavigation.bindToScrollable 做标题栏渐变模糊，
  // 因此保留引用以免破坏标题栏效果。
  private gardenScroller: Scroller = ShellState.gardenScroller;
  private outlineScroller: Scroller = ShellState.gardenOutlineScroller;

  // 生命周期：注册仓库监听（记忆变化重载）、HDS 菜单桥（搜索/更多/收起详情）、
  // 400ms 后读取初始记忆并默认选中 m4 打开详情面板
  aboutToAppear(): void {
    if (GardenController.modeOverride >= 0) {
      this.mode = GardenController.modeOverride as GardenMode;
      GardenController.modeOverride = -1;
    }
    this.repoListener = () => {
      this.memories = this.repo.getAll();
      this.recomputeBubbleLayout();
      if (this.selectedMemory !== null) {
        const found = this.repo.getById(this.selectedMemory.id);
        if (found === null) {
          this.selectedMemory = null;
          this.detailH = 196;
        }
      }
    };
    this.repo.subscribe(this.repoListener);
    GardenController.closeDetail = () => {
      this.selectedMemory = null;
      this.detailH = 196;
    };
    GardenController.openSearch = () => {
      // 搜索改为独立子页 B_Search（HdsNavigation 压栈）；返回后按 pendingFocus 聚焦
      AppRouter.push(RouteName.SEARCH);
    };
    GardenController.openMenu = () => {
      // 打开模式菜单前先收起节点详情系统浮层（模态浮层会挡住标题栏，导致无法切换模式）
      this.detailOpen = false;
      this.menuOpen = true;
    };
    GardenController.switchTo = (m: number) => {
      this.switchMode(m as GardenMode);
    };
    GardenController.gardenMode = this.mode;
    AppStorage.setOrCreate('gardenMode', this.mode);
    GardenController.zoomIn = () => {
      this.treeZoom = Math.min(2.4, this.treeZoom + 0.15);
    };
    GardenController.zoomOut = () => {
      this.treeZoom = Math.max(0.5, this.treeZoom - 0.15);
    };
    setTimeout(() => {
      this.memories = this.repo.getAll();
      // 布局的纵向锚点按屏高比例计算，必须先拿到真实尺寸再算
      DeviceUtil.initFromUi(this.getUIContext());
      this.recomputeBubbleLayout();
      this.pageState = PageState.SUCCESS;
      if (GardenController.pendingFocusId !== '') {
        // 从搜索页返回：按进入搜索前的视图模式聚焦
        const target = this.repo.getById(GardenController.pendingFocusId);
        GardenController.pendingFocusId = '';
        if (target !== null) {
          if (this.mode === GardenMode.OUTLINE) {
            // 大纲模式：选中该记忆并滚动到条目所在位置（行高约 196vp）
            this.selectMemory(target);
            const idx = this.sortedMemories().findIndex((mm: Memory) => mm.id === target.id);
            if (idx >= 0) {
              setTimeout(() => {
                this.outlineScroller.scrollTo({
                  xOffset: 0,
                  yOffset: Math.max(idx * 196 - 200, 0),
                  animation: { duration: 320, curve: Curve.EaseOut }
                });
              }, 200);
            }
          } else {
            // 从搜索页返回：选中该记忆（带选中环 + 详情浮层），记忆树模式同样以浮层呈现详情
            this.selectMemory(target);
          }
        }
      } else {
        // 默认高亮 m4（演示态那条「重要回忆」）。演示条数被调小后 m4 可能不在花园里，
        // 此时退化为高亮最新的一条，保证首屏总有焦点（否则看起来像「什么都没选中」）。
        let first: Memory | null = this.repo.getById('m4');
        if (first === null) {
          const all: Memory[] = this.sortedMemories();
          first = all.length > 0 ? all[0] : null;
        }
        if (first !== null) {
          // 首屏不自动弹详情浮层：气泡花园的下半屏会被浮层遮住，先让用户看到完整花簇。
          // 仅高亮默认节点，点任意气泡/花心再打开详情。
          this.selectedMemory = first;
          this.detailOpen = false;
          this.recomputeBubbleLayout();
        }
      }
    }, 400);
  }

  aboutToDisappear(): void {
    this.repo.unsubscribe(this.repoListener);
    GardenController.closeDetail = () => {
    };
    GardenController.openSearch = () => {
    };
    GardenController.openMenu = () => {
    };
  }

  private sel(): Memory {
    return this.selectedMemory as Memory;
  }

  /**
   * 重算气泡布局。
   * 【重要】这里直接读 MemoryRepository，而不是读 this.memories：
   * 页面可能先于 repoListener 的 setState 完成渲染（例如刚在设置页开了演示模式就切到花园），
   * 此时 this.memories 仍是旧数组，会出现「花瓣是新的、花心计数是旧的」的数据不同步
   * （真机实测过）。以仓库为唯一数据源即可消除这个竞态，同时顺带把 this.memories 校正回来。
   * 输入顺序用日期倒序，使每朵花内部按「最新的花瓣先出现」绽放，且与大纲模式一致。
   *
   * 【只在数据/尺寸变化时调用】选中态变化不要走这里——那会重算布局并让 ForEach 重建全部气泡。
   * 选中态请看 syncBubbleSelection()。
   */
  private recomputeBubbleLayout(): void {
    const list = this.repo.getAll().slice();
    list.sort((a: Memory, b: Memory) => {
      if (a.date === b.date) {
        return 0;
      }
      return a.date < b.date ? 1 : -1;
    });
    this.memories = list;
    // 布局同时依赖屏宽与屏高：直径由可用矩形自适应反解，目标是 4 簇全部装进一屏
    this.bubbleLayout = BubbleLayoutUtil.layout(list, this.viewportW, this.viewportH);
    const items: BubbleItem[] = [];
    const minis: BubbleSlot[] = [];
    for (let i = 0; i < this.bubbleLayout.slots.length; i++) {
      const slot = this.bubbleLayout.slots[i];
      if (slot.mini) {
        minis.push(slot);
        continue;
      }
      const m = this.repo.getById(slot.memoryId);
      if (m !== null) {
        items.push(new BubbleItem(m, slot));
      }
    }
    this.bubbleItems = items;
    this.bubbleMinis = minis;
    this.syncBubbleSelection();
  }

  /**
   * 只同步选中态：不重算布局、不重建气泡。
   * 气泡的选中描边由 @Prop selected 透传更新（约 160ms 的平滑过渡），
   * 因此点击是"就地更新"而不是"整片重建"——这是消除点击延迟与闪烁的关键。
   */
  private syncBubbleSelection(): void {
    this.bubbleSelectedId = this.selectedMemory !== null ? this.selectedMemory.id : '';
  }

  private countOf(type: MemoryType): number {
    let count = 0;
    for (let i = 0; i < this.memories.length; i++) {
      if (this.memories[i].type === type) {
        count++;
      }
    }
    return count;
  }

  // 选中记忆：打开详情面板（detailH 吸附高度）+ 更新编辑浮窗数据源
  private selectMemory(m: Memory): void {
    this.selectedMemory = m;
    // 只同步选中态，**不重算布局、不重建气泡**：否则点一颗会牵连重建全部，
    // 表现为点击延迟 + 两颗一起闪烁（真机实测）
    this.syncBubbleSelection();
    // 同步编辑表单：编辑视图继承当前节点信息
    this.editTitle = m.title;
    this.editTags = m.tags.join('，');
    this.editSummary = m.summary;
    // 撤销/重做仅针对当前记忆（从按 id 隔离的栈加载）
    this.undoStack = this.undoMaps.get(m.id) ?? [];
    this.redoStack = this.redoMaps.get(m.id) ?? [];
    // 打开“节点详情”系统浮层（查看模式）；下拖/点遮罩退出时 bindSheet 系统动画下移出屏
    this.editorMode = false;
    this.detailOpen = true;
  }

  // 收起详情面板（空白处点击/再次点击节点/下拉把手/取消编辑时调用）
  private closeDetail(): void {
    this.selectedMemory = null;
    this.syncBubbleSelection();
    this.detailOpen = false;
  }

  // 视图切换入口（花园/大纲/树）：同步 mode 与记忆加载状态（树模式需要构建树数据）
  private switchMode(m: GardenMode): void {
    this.menuOpen = false;
    this.mode = m;
    GardenController.gardenMode = m;
    AppStorage.setOrCreate('gardenMode', m);
    this.selectedMemory = null;
    this.detailH = 196;
    this.detailOpen = false;
    // 切回气泡视图时按当前尺寸重算，保证从其它视图返回后位置一致
    if (m === GardenMode.BUBBLE || m === GardenMode.GARDEN) {
      this.recomputeBubbleLayout();
    }
  }

  private sortedMemories(): Memory[] {
    const arr = this.memories.slice();
    arr.sort((a: Memory, b: Memory) => {
      if (a.date === b.date) {
        return 0;
      }
      return a.date < b.date ? 1 : -1;
    });
    return arr;
  }

  private buildTree(): MemoryTreeNode {
    const root = new MemoryTreeNode();
    root.id = 'root';
    root.title = '记忆花园';
    root.type = 'root';
    // 与气泡花园的分簇保持一致：4 类。「重要回忆」是标签而非类型，因此不单独成组，
    // 这类记忆会按其真实类型（现为「目标」）归入对应分组。
    const gNames: string[] = ['生活', '学习', '目标', '兴趣'];
    const gKeys: MemoryType[] = [MemoryType.LIFE, MemoryType.STUDY, MemoryType.GOAL, MemoryType.INTEREST];
    const groups: MemoryTreeNode[] = [];
    for (let g = 0; g < gKeys.length; g++) {
      const group = new MemoryTreeNode();
      group.id = 'group-' + g.toString();
      group.title = gNames[g];
      group.type = 'group';
      group.parentId = 'root';
      for (let i = 0; i < this.memories.length; i++) {
        if (this.memories[i].type === gKeys[g]) {
          const mn = new MemoryTreeNode();
          mn.id = this.memories[i].id;
          mn.title = this.memories[i].title;
          mn.type = 'memory';
          mn.parentId = group.id;
          group.children.push(mn);
        }
      }
      groups.push(group);
    }
    root.children = groups;
    return root;
  }

  private filtered(): Memory[] {
    const q = this.searchText.trim().toLowerCase();
    const out: Memory[] = [];
    for (let i = 0; i < this.memories.length; i++) {
      const m = this.memories[i];
      const hay = (m.title + ' ' + m.summary + ' ' + m.date + ' ' + m.tags.join(' ') + ' ' + m.content).toLowerCase();
      if (q === '' || hay.includes(q)) {
        out.push(m);
      }
    }
    return out;
  }

  private openDeleteConfirm(): void {
    if (this.selectedMemory === null) {
      return;
    }
    AlertDialog.show({
      title: '删除记忆',
      message: '确定删除「' + this.selectedMemory.title + '」吗？花园、大纲、记忆树会同步更新。',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#E5533D',
        action: () => {
          if (this.selectedMemory === null) {
            return;
          }
          const title = this.selectedMemory.title;
          this.repo.delete(this.selectedMemory.id);
          this.selectedMemory = null;
          this.detailH = 196;
          PromptUtil.toast('已删除「' + title + '」');
        }
      }
    });
  }

  /**
   * 三种视图共用的玻璃卡头部：标题 + 记忆总数 + 五类图例。
   * 从旧 gardenView 中原样抽出，保证改版后头部视觉与大纲/树视图一致。
   */
  @Builder
  gardenHeader() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('记忆花园')
            .fontSize(Theme.fontSize(12))
            .fontColor('#5F7A63')
            .fontWeight(FontWeight.Medium)
          Text('正在生长的生活片段')
            .fontSize(Theme.fontSize(20))
            .fontWeight(FontWeight.Bold)
            .fontColor('#1D3424')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 1 }) {
          Text(this.memories.length.toString())
            .fontSize(Theme.fontSize(24))
            .fontWeight(FontWeight.Bold)
            .fontColor('#2C8750')
          Text('片记忆')
            .fontSize(Theme.fontSize(10))
            .fontColor('#6F8272')
        }
        .width(54)
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')

      Row({ space: 3 }) {
        // 只列 4 种类型：「重要回忆」是标签而非类型（已并入目标簇），不再单独成项
        ForEach([
          MemoryType.LIFE, MemoryType.STUDY, MemoryType.GOAL, MemoryType.INTEREST
        ], (type: MemoryType) => {
          Row({ space: 5 }) {
            Column()
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor(MemoryTypeUtil.colorOf(type))
            Text(MemoryTypeUtil.nameOf(type) + ' ' + this.countOf(type).toString())
              .fontSize(Theme.fontSize(10))
              .fontColor('#66776A')
          }
          .padding({ left: 6, right: 6, top: 5, bottom: 5 })
          .backgroundColor('rgba(255,255,255,0.52)')
          .borderRadius(12)
        }, (type: MemoryType) => type.toString())
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
    }
    .width('88%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .position({ x: '6%', y: 92 })
    .borderRadius(24)
    .backgroundColor('rgba(250,255,249,0.82)')
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: 'rgba(255,255,255,0.82)' })
    .shadow({ radius: 22, color: 'rgba(47,84,54,0.12)', offsetY: 7 })
  }

  /**
   * 气泡花园：按 4 种记忆类型分簇，每簇是一朵「生长中的花」。
   * 花心与主圆显示图标 + 简短日期；数量溢出时用同色小实心圆点补位。
   * 布局由 BubbleLayoutUtil 计算：contentHeight=0 时正好一屏放下（不滚动），
   * 记忆变多、一屏放不下时布局会给出内容高度，这里才套 Scroll 让花园向下生长。
   */
  @Builder
  bubbleView() {
    Stack({ alignContent: Alignment.Top }) {
      Image($r('app.media.garden_bg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(0.96)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 【要不要滚动由布局决定】记忆少时 4 簇自适应排进一屏：contentHeight=0，
      // 内容高度 == 视口高度，Scroll 滚不动，观感与「纯 Stack」完全一致；
      // 某簇超过一圈（6 个）后包络从 2 个列距变 4 个列距、2 列放不下，
      // 布局退化为单列并给出 contentHeight>0，此时才真正可滚动。
      //
      // 【顶部为什么不用硬裁】早先为了不让花压到标题文字，把 Scroll 从头部下沿裁掉，
      // 结果是上滑时圆点被切出一条生硬的直边（用户截图指出）。现在改成：
      // 滚动区铺满整屏，靠 linearGradientBlur 让内容越靠上越模糊、自然消失在标题栏里。
      // 头部玻璃卡本身是不透明的，会盖住它下方的内容，所以真正需要"渐隐"的只有标题栏那一条。
      // 真机实测教训：固定直径 + 一簇一行时 4 簇纵向叠加远超可用高度，
      // 表现为「必须滚动 + 圆圈被裁 + 气泡压到下一簇花心」——所以直径必须由布局反解。
      if (this.bubbleLayout.contentHeight > 0) {
        Scroll() {
          this.bubbleField(this.bubbleLayout.contentHeight)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        // 关掉回弹：内容刚好一屏时也不会因为过滚动抖一下
        .edgeEffect(EdgeEffect.None)
        // fractionStops 的每一项是 [模糊强度, 位置]，位置按屏高归一化：
        // 顶部全模糊 → 卡片下沿附近仍保留 70% → 头部预留高度处完全不模糊
        .linearGradientBlur(TOP_FADE_BLUR, {
          fractionStops: [
            [1.0, 0.0],
            [TOP_FADE_EDGE_RATIO, BubbleLayoutUtil.topInset() / this.viewportH * 0.86],
            [0.0, BubbleLayoutUtil.topInset() / this.viewportH]
          ],
          direction: GradientDirection.Bottom
        })
      } else {
        this.bubbleField(this.viewportH)
      }

      this.gardenHeader()

      if (this.memories.length === 0) {
        EmptyState({
          text: '花园还是空的，点击右下角 + 种下第一颗记忆种子',
          icon: $r('sys.symbol.flower')
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 花园的「花田」本体：花心点 + 记忆主圆 + 溢出小圆点。
   * 抽成 @Builder 是因为它要么直接放在 Stack 里（一屏放下），要么放进 Scroll 里，
   * 两种容器必须渲染完全相同的内容 —— 否则早就踩过的「节点被裁/位置漂移」会重演。
   * 坐标一律用**屏幕坐标**（布局的 originY 已含头部下沿），因此两种容器都是铺满整屏、
   * 原点在屏幕左上，不需要任何偏移换算。
   */
  @Builder
  bubbleField(h: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      // 花心：很小的实心圆点（**不承载记忆**，因此不会盖住任何圆的内容）。
      // 位置在簇正中，记忆圆环绕它排布。
      ForEach(this.bubbleLayout.cores, (c: FlowerCore) => {
        Column()
          .width(c.d)
          .height(c.d)
          .borderRadius(Theme.RADIUS_PILL)
          .backgroundColor(MemoryTypeUtil.colorOf(c.type))
          .position({ x: c.x - c.d / 2, y: c.y - c.d / 2 })
          .zIndex(1)
      // key 含类型与坐标：避免簇变化时 ArkUI 复用旧组件（真机实测过位置冻结）
      }, (c: FlowerCore) => 'c|' + c.type.toString()
        + '|' + c.x.toFixed(1) + ',' + c.y.toFixed(1))

      // 小圆点：同色实心，纯装饰（表示"还有更多同类记忆"，不承载具体内容）。
      // 用独立数组 + 带坐标的 key：条数一变，坐标变、key 变、组件必然重建。
      ForEach(this.bubbleMinis, (s: BubbleSlot) => {
        Column()
          .width(s.d)
          .height(s.d)
          .borderRadius(Theme.RADIUS_PILL)
          .backgroundColor(MemoryTypeUtil.colorOf(s.type))
          .opacity(0.88)
          .position({ x: s.x - s.d / 2, y: s.y - s.d / 2 })
          .zIndex(1)
      }, (s: BubbleSlot) => 'm|' + s.type.toString()
        + '|' + s.x.toFixed(1) + ',' + s.y.toFixed(1) + ',' + s.d.toFixed(1))

      // 主圆：图标 + 简短日期，可点击进详情
      ForEach(this.bubbleItems, (item: BubbleItem) => {
        MemoryBubble({
          memory: item.memory,
          d: item.slot.d,
          selected: this.selectedMemory !== null && this.selectedMemory.id === item.memory.id,
          onPick: (mm: Memory) => {
            this.selectMemory(mm);
          }
        })
          .position({ x: item.slot.x - item.slot.d / 2, y: item.slot.y - item.slot.d / 2 })
          .zIndex(this.selectedMemory !== null && this.selectedMemory.id === item.memory.id ? 5 : 2)
      }, (item: BubbleItem) => item.keygen)
    }
    .width('100%')
    .height(h)
  }

  @Builder
  outlineView() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll(this.outlineScroller) {
        Column({ space: 0 }) {
          // 顶部为 HDS 标题栏预留：单行(Mini)标题栏 56vp + 与首张卡片的间距。
          // 注意 Scroll 设了 expandSafeArea，内容坐标原点在屏幕顶端，故 114vp 正好让卡片落在标题文字下方。
          Blank().height(114)
          ForEach(this.sortedMemories(), (m: Memory) => {
            Row() {
              // 时间轴列：连续线（上下各延伸 14vp 与相邻条目衔接）+ 节点对准卡片中部
              Column() {
                Row()
                  .width(2)
                  .height(Math.max(this.outlineItemH(m), 60) + 28)
                  .backgroundColor(this.selectedMemory !== null && this.selectedMemory.id === m.id
                    ? 'rgba(95,199,126,0.5)' : '#DCE9DF')
                  .margin({ top: -14 })
                Row()
                  .width(12)
                  .height(12)
                  .borderRadius(6)
                  .backgroundColor(this.selectedMemory !== null && this.selectedMemory.id === m.id
                    ? '#5FC77E' : '#B9DCC4')
                  .position({ y: Math.max(this.outlineItemH(m), 60) / 2 - 6 })
              }
              .width(40)
              .height(Math.max(this.outlineItemH(m), 60))
              .alignItems(HorizontalAlign.Center)

              // 卡片：高度随内容（标题最多 2 行、摘要 2 行、标签 1 行）
              Column({ space: 8 }) {
                Row() {
                  Text(m.date)
                    .fontSize(Theme.fontSize(14))
                    .fontWeight(this.selectedMemory !== null && this.selectedMemory.id === m.id
                      ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor(this.selectedMemory !== null && this.selectedMemory.id === m.id
                      ? '#3FA55F' : Theme.SECONDARY)
                  Blank()
                  // 与花园气泡同色系：浅底用 bubbleBgOf（主色与白 86% 混合），
                  // 文字用 iconColorOf（主色压暗），保证同一个 base 派生出的明度关系一致。
                  // 注意不要写成 colorOf + '22'：ArkUI 的 8 位十六进制是 #AARRGGBB，
                  // 拼在尾巴上的两字符会被当成蓝色通道、同时把色值当成 alpha。
                  Text(MemoryTypeUtil.nameOf(m.type))
                    .fontSize(Theme.fontSize(10))
                    .fontColor(MemoryTypeUtil.iconColorOf(m.type))
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .backgroundColor(MemoryTypeUtil.bubbleBgOf(m.type))
                    .borderRadius(9)
                }
                .width('100%')

                Text(m.title)
                  .fontSize(Theme.fontSize(15))
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Theme.PRIMARY)
                  .width('100%')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(m.summary)
                  .fontSize(Theme.fontSize(13))
                  .fontColor(Theme.SECONDARY)
                  .width('100%')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Row({ space: 6 }) {
                  ForEach(m.tags.slice(0, 3), (t: string) => {
                    Text(t)
                      .fontSize(Theme.fontSize(10))
                      .fontColor(Theme.TERTIARY)
                      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                      .backgroundColor('#F0F5F1')
                      .borderRadius(9)
                  }, (t: string) => t)
                }
                .width('100%')
              }
              .layoutWeight(1)
              .padding(14)
              .borderRadius(16)
              .backgroundColor(this.selectedMemory !== null && this.selectedMemory.id === m.id
                ? 'rgba(151,255,171,0.22)' : '#FFFFFF')
              .border({
                width: this.selectedMemory !== null && this.selectedMemory.id === m.id ? 1.4 : 1,
                color: this.selectedMemory !== null && this.selectedMemory.id === m.id ? '#6FDC92' : Theme.LINE
              })
              .onClick(() => {
                this.selectMemory(m);
              })
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            .padding({ right: 20 })
            .margin({ bottom: 14 })
          }, (m: Memory) => m.id)
          // 底部只留出悬浮 Tab 栏的高度（栏本身 56vp + 下边距 28vp + 渐变光罩 ≈ 120vp）
          Blank().height(120)
        }
        .width('100%')
        .padding({ left: 20 })
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 顶部渐变模糊改由 HDS 标题栏承担：本页的 outlineScroller 已通过 ShellState 交给
      // HdsNavigation.bindToScrollable，滚动时系统会绘制「沉浸渐变模糊」层（标题栏 + 32vp 过渡），
      // 这里不再自绘遮罩，避免两层叠加以外的样式偏差。
    }
    .width('100%')
    .height('100%')
  }

  // 估算大纲卡片高度（标题/摘要按字符数折行）：用于时间轴连接线高度
  private outlineItemH(m: Memory): number {
    const titleLines = m.title.length > 26 ? 2 : 1;
    const sumLines = m.summary.length > 42 ? 2 : 1;
    return 62 + titleLines * 21 + sumLines * 19 + 24;
  }

  // 记忆树模式不再在标题栏下额外加模糊带：全屏画布直接透出，标题栏只保留 MainPage 的那个
  // HDS 系统标题栏本身（与首页/设置/大纲一致）。
  @Builder
  treeView() {
    Stack({ alignContent: Alignment.Top }) {
      MemoryTreeGraph({
        root: this.buildTree(),
        selectedId: this.selectedMemory !== null ? this.selectedMemory.id : '',
        zoom: this.treeZoom,
        onSelect: (nodeId: string) => {
          if (nodeId.startsWith('group-') || nodeId === 'root') {
            const lst = this.sortedMemories();
            if (lst.length > 0) {
              this.selectMemory(lst[0]);
            }
            return;
          }
          const m = this.repo.getById(nodeId);
          if (m !== null) {
            this.selectMemory(m);
          }
        }
      })
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      if (this.memories.length === 0) {
        EmptyState({
          text: '种下记忆后，这里会长出一棵记忆树',
          icon: $r('sys.symbol.leaf')
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  // 节点详情视图（位于系统浮层内，查看模式）
  @Builder
  sheetViewContent() {
    Column() {
      // 标题独占一行，留足空间；日期与标签并列在第二行
      Text(this.sel().title)
        .fontSize(Theme.fontSize(20))
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_MAIN)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row() {
        Text(this.sel().date)
          .fontSize(Theme.fontSize(12))
          .fontColor(Theme.TEXT_TERTIARY)
        Blank()
        Row({ space: 6 }) {
          ForEach(this.sel().tags.slice(0, 2), (t: string) => {
            Text(t)
              .fontSize(Theme.fontSize(11))
              .fontColor(Theme.SECONDARY)
              .padding({ left: 10, right: 10, top: 3, bottom: 3 })
              .backgroundColor('#EFF5F0')
              .borderRadius(11)
          }, (t: string) => t)
        }
      }
      .width('100%')
      .margin({ top: 6 })
      .padding({ right: 66 })

      Divider().color(Theme.LINE).strokeWidth(0.6).margin({ top: 14 })

      Text(this.sel().summary)
        .fontSize(Theme.fontSize(14))
        .fontColor(Theme.TEXT_SUB)
        .width('100%')
        .margin({ top: 12 })

      Text(this.sel().content)
        .fontSize(Theme.fontSize(13))
        .fontColor(Theme.TEXT_TERTIARY)
        .lineHeight(20)
        .width('100%')
        .margin({ top: 8 })
        .maxLines(6)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // 小工具栏：编辑 / 删除 / 撤销 / 重做（等宽对齐居中，含点击反馈）
      Row() {
        Column() {
          SymbolGlyph($r('sys.symbol.pencil_line')).fontSize(Theme.fontSize(20)).fontColor(['#3E6B4B'])
        }
        .width('25%')
        .height(44)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
            this.editorMode = true;
          });
        })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })

        Column() {
          SymbolGlyph($r('sys.symbol.trash')).fontSize(Theme.fontSize(20)).fontColor(['#C4573F'])
        }
        .width('25%')
        .height(44)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.openDeleteConfirm();
        })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })

        Column() {
          SymbolGlyph($r('sys.symbol.arrow_counterclockwise')).fontSize(Theme.fontSize(20))
            .fontColor(this.undoStack.length > 0 ? ['#3E6B4B'] : ['#C9D6CC'])
        }
        .width('25%')
        .height(44)
        .justifyContent(FlexAlign.Center)
        .opacity(this.undoStack.length > 0 ? 1 : 0.55)
        .onClick(() => {
          if (this.selectedMemory === null || this.undoStack.length === 0) {
            PromptUtil.toast('当前记忆没有可以撤销的操作');
            return;
          }
          const m = this.selectedMemory;
          const snap = this.undoStack[this.undoStack.length - 1];
          if (snap.id !== m.id) {
            PromptUtil.toast('当前记忆没有可以撤销的操作');
            return;
          }
          // 当前状态存入重做栈
          const cur: EditSnapshot = {
            id: m.id,
            title: m.title,
            tags: m.tags.slice(),
            summary: m.summary,
            label: snap.label
          };
          m.title = snap.title;
          m.tags = snap.tags.slice();
          m.summary = snap.summary;
          this.repo.update(m);
          this.undoMaps.set(m.id, this.undoStack.slice(0, this.undoStack.length - 1));
          this.redoMaps.set(m.id, this.redoStack.concat([cur]));
          this.undoStack = this.undoMaps.get(m.id) ?? [];
          this.redoStack = this.redoMaps.get(m.id) ?? [];
          // 实时刷新：选中引用 + 表单 + 视口
          const fresh = this.repo.getById(m.id);
          this.selectedMemory = fresh !== null ? fresh : m;
          this.editTitle = this.selectedMemory.title;
          this.editTags = this.selectedMemory.tags.join('，');
          this.editSummary = this.selectedMemory.summary;
          PromptUtil.toast('已撤销：' + snap.label);
        })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })

        Column() {
          SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(Theme.fontSize(20))
            .fontColor(this.redoStack.length > 0 ? ['#3E6B4B'] : ['#C9D6CC'])
        }
        .width('25%')
        .height(44)
        .justifyContent(FlexAlign.Center)
        .opacity(this.redoStack.length > 0 ? 1 : 0.55)
        .onClick(() => {
          if (this.selectedMemory === null || this.redoStack.length === 0) {
            PromptUtil.toast('当前记忆没有可以重做的操作');
            return;
          }
          const m = this.selectedMemory;
          const snap = this.redoStack[this.redoStack.length - 1];
          if (snap.id !== m.id) {
            PromptUtil.toast('当前记忆没有可以重做的操作');
            return;
          }
          const cur: EditSnapshot = {
            id: m.id,
            title: m.title,
            tags: m.tags.slice(),
            summary: m.summary,
            label: snap.label
          };
          m.title = snap.title;
          m.tags = snap.tags.slice();
          m.summary = snap.summary;
          this.repo.update(m);
          this.redoMaps.set(m.id, this.redoStack.slice(0, this.redoStack.length - 1));
          this.undoMaps.set(m.id, this.undoStack.concat([cur]));
          this.undoStack = this.undoMaps.get(m.id) ?? [];
          this.redoStack = this.redoMaps.get(m.id) ?? [];
          const fresh = this.repo.getById(m.id);
          this.selectedMemory = fresh !== null ? fresh : m;
          this.editTitle = this.selectedMemory.title;
          this.editTags = this.selectedMemory.tags.join('，');
          this.editSummary = this.selectedMemory.summary;
          PromptUtil.toast('已重做：' + snap.label);
        })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      }
      .width('100%')
      .margin({ top: 16 })
      .borderRadius(18)
      .backgroundColor('#FFFFFF')
      .border({ width: 1, color: Theme.CARD_BORDER })
      .shadow({ radius: 10, color: 'rgba(38,61,42,0.05)', offsetY: 2 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 24 })
  }

  // 节点详情系统浮层：查看 / 编辑两种内容（同一浮层内切换，少一层浮窗）
  // 查看 / 编辑 切换带过渡动画（Opacity + 位移动画，220ms）
  @Builder
  memorySheetBuilder() {
    if (this.editorMode) {
      Column() {
        this.editSheetContent()
      }
      .width('100%')
      .transition(
        TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseOut })
          .combine(TransitionEffect.translate({ y: 26 }))
      )
    } else {
      Column() {
        this.sheetViewContent()
      }
      .width('100%')
      .transition(
        TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseOut })
          .combine(TransitionEffect.translate({ y: -12 }))
      )
    }
  }

  @Builder
  searchOverlay() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        TextInput({ placeholder: '搜索记忆…', text: this.searchText })
          .fontSize(Theme.fontSize(15))
          .height(44)
          .borderRadius(23)
          .backgroundColor('rgba(255,255,255,0.95)')
          .padding({ left: 18, right: 18 })
          .layoutWeight(1)
          .onChange((v: string) => {
            this.searchText = v;
          })
        Column() {
          Stack() {
            Column().width(36).height(36).borderRadius(999).backgroundColor('rgba(255,255,255,0.95)')
            SymbolGlyph($r('sys.symbol.xmark')).fontSize(Theme.fontSize(16)).fontColor([Theme.SECONDARY])
          }
        }
        .width(36)
        .height(36)
        .onClick(() => {
          this.searchOpen = false;
          this.searchText = '';
        })
      }
      .width('96%')

      Column() {
        if (this.filtered().length === 0) {
          Text('没有找到相关记忆')
            .fontSize(Theme.fontSize(13))
            .fontColor(Theme.TERTIARY)
            .margin({ top: 30, bottom: 30 })
        } else {
          Scroll() {
            Column() {
              ForEach(this.filtered(), (m: Memory) => {
                Row({ space: 10 }) {
                  Column({ space: 4 }) {
                    Text(m.title)
                      .fontSize(Theme.fontSize(14))
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Theme.PRIMARY)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(m.date + ' · ' + MemoryTypeUtil.nameOf(m.type))
                      .fontSize(Theme.fontSize(11))
                      .fontColor(Theme.TERTIARY)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(Theme.fontSize(14)).fontColor([Theme.TERTIARY])
                }
                .width('100%')
                .height(56)
                .padding({ left: 16, right: 16 })
                .borderRadius(14)
                .backgroundColor(Theme.CARD)
                .margin({ bottom: 8 })
                .onClick(() => {
                  this.selectMemory(m);
                  this.searchOpen = false;
                  this.searchText = '';
                })
              }, (m: Memory) => m.id)
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .height(360)
        }
      }
      .width('96%')
      .borderRadius(20)
      .backgroundColor('rgba(252,254,251,0.97)')
      .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
      .border({ width: 1, color: 'rgba(255,255,255,0.85)' })
      .shadow({ radius: 26, color: 'rgba(26,48,32,0.16)', offsetY: 6 })
      .clip(true)
    }
    .width('100%')
    .margin({ top: DeviceUtil.statusBarH + 120 })
  }

  // 编辑浮窗内容（字段由 selectMemory/工具栏预填，继承选中节点信息）
  @Builder
  editSheetContent() {
    Column({ space: 12 }) {
      // 编辑模式仅用“取消”退出；不另设右上角关闭按钮（浮层由系统关闭泡/拖拽关闭）
      Row() {
        Text('编辑记忆')
          .fontSize(Theme.fontSize(19))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8 })

      Column({ space: 6 }) {
        Text('记忆标题')
          .fontSize(Theme.fontSize(12))
          .fontColor(Theme.TEXT_TERTIARY)
          .width('100%')
        TextInput({ text: this.editTitle, placeholder: '默认沿用当前节点标题' })
          .fontSize(Theme.fontSize(15))
          .focusable(true)
          .backgroundColor('#FFFFFF')
          .borderRadius(14)
          .border({ width: 1, color: Theme.CARD_BORDER })
          .height(46)
          .padding({ left: 14, right: 14 })
          .onChange((v: string) => {
            this.editTitle = v;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 10 })
      Column({ space: 6 }) {
        Text('标签（逗号分隔）')
          .fontSize(Theme.fontSize(12))
          .fontColor(Theme.TEXT_TERTIARY)
          .width('100%')
        TextInput({ text: this.editTags, placeholder: '如：目标，漫画' })
          .fontSize(Theme.fontSize(14))
          .focusable(true)
          .backgroundColor('#FFFFFF')
          .borderRadius(14)
          .border({ width: 1, color: Theme.CARD_BORDER })
          .height(40)
          .padding({ left: 14, right: 14 })
          .onChange((v: string) => {
            this.editTags = v;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 10 })
      Column({ space: 6 }) {
        Text('记忆摘要')
          .fontSize(Theme.fontSize(12))
          .fontColor(Theme.TEXT_TERTIARY)
          .width('100%')
        TextArea({ text: this.editSummary, placeholder: '默认沿用当前节点摘要' })
          .fontSize(Theme.fontSize(14))
          .focusable(true)
          .backgroundColor('#FFFFFF')
          .borderRadius(14)
          .border({ width: 1, color: Theme.CARD_BORDER })
          .height(84)
          .padding(12)
          .onChange((v: string) => {
            this.editSummary = v;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 10 })

      Row({ space: 14 }) {
        Button('保存')
          .fontSize(Theme.fontSize(15))
          .fontWeight(FontWeight.Medium)
          .fontColor('#1E3A26')
          .backgroundColor(Theme.ACCENT_GREEN)
          .height(46)
          .layoutWeight(1)
          .borderRadius(17)
          .onClick(() => {
            if (this.selectedMemory === null) {
              return;
            }
            const m = this.selectedMemory;
            // 编辑前快照（存入该记忆自己的撤销栈，保证撤销/重做只在当前记忆生效）
            const snap: EditSnapshot = {
              id: m.id,
              title: m.title,
              tags: m.tags.slice(),
              summary: m.summary,
              label: '编辑「' + m.title + '」'
            };
            if (this.editTitle.trim() !== '') {
              m.title = this.editTitle.trim();
            }
            const tags: string[] = [];
            const parts = this.editTags.split('，');
            for (let i = 0; i < parts.length; i++) {
              const t = parts[i].trim();
              if (t !== '') {
                tags.push(t);
              }
            }
            m.tags = tags;
            m.summary = this.editSummary.trim();
            this.repo.update(m);
            // 刷新选中引用与表单（实时刷新）
            const fresh = this.repo.getById(m.id);
            this.selectedMemory = fresh !== null ? fresh : m;
            this.editTitle = this.selectedMemory.title;
            this.editTags = this.selectedMemory.tags.join('，');
            this.editSummary = this.selectedMemory.summary;
            this.undoMaps.set(m.id, this.undoStack.concat([snap]));
            this.redoMaps.set(m.id, []);
            this.undoStack = this.undoMaps.get(m.id) ?? [];
            this.redoStack = [];
            animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
              this.editorMode = false;
            });
            PromptUtil.toast('已保存修改');
          })
        Button('取消')
          .fontSize(Theme.fontSize(15))
          .fontColor(Theme.SECONDARY)
          .backgroundColor('#EEF3EE')
          .height(50)
          .layoutWeight(1)
          .borderRadius(17)
          .onClick(() => {
            this.editorMode = false;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12 })
    }
    .width('100%')
    .padding({ top: 4, bottom: 10 })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.pageState === PageState.LOADING) {
        LoadingState({ text: '默默正在布置花园……' })
      } else if (this.pageState === PageState.EMPTY) {
        EmptyState({ text: '花园空空如也', icon: $r('sys.symbol.flower') })
      } else {
        // 气泡花园为默认视图；GARDEN 数值仅由旧调试入口传入，一并渲染气泡视图，
        // 避免出现「已删除的视图分支」导致白屏
        if (this.mode === GardenMode.OUTLINE) {
          this.outlineView()
        } else if (this.mode === GardenMode.TREE) {
          this.treeView()
        } else {
          this.bubbleView()
        }
      }

      // 模式菜单（打开时挂载）
      if (this.menuOpen) {
        ModeMenu({
          visible: true,
          mode: this.mode,
          onSelect: (m: GardenMode) => {
            this.switchMode(m);
          }
        })
      }

      // 搜索浮窗
      if (this.searchOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(246,251,246,0.72)')
          .onClick(() => {
            this.searchOpen = false;
          })
        this.searchOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
    // 气泡布局的纵向锚点按屏高比例计算，需在拿到真实尺寸后重算一次
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const w = Number(newValue.width);
      const h = Number(newValue.height);
      if (w > 0 && h > 0 && (Math.abs(w - this.viewportW) > 1 || Math.abs(h - this.viewportH) > 1)) {
        this.viewportW = w;
        this.viewportH = h;
        this.recomputeBubbleLayout();
      }
    })
    // 节点详情系统浮层（常驻模态）：下拖/点遮罩/操作完成时由 bindSheet 系统动画下移出屏
    .bindSheet($$this.detailOpen, this.memorySheetBuilder(), {
      // 查看约 1/3 屏；点击编辑 -> 浮层升至屏幕 50%（状态驱动高度）
      height: this.editorMode ? 640 : 380,
      dragBar: true,
      backgroundColor: Theme.SHEET_BG,
      showInSubWindow: false
    })
  }
}
