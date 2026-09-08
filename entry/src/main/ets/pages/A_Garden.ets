/*
 * ============================================================================
 * 文件名：pages/A_Garden.ets
 * ============================================================================
 * 【用途】一级 Tab「记忆花园」：以三种视图展示记忆——
 *   GARDEN（花园场景 + 节点标记 + 详情浮窗）、OUTLINE（记忆大纲列表）、
 *   TREE（MemoryTreeGraph 记忆树），以及搜索浮窗、模式菜单(ModeMenu)、编辑浮窗、
 *   缩放浮钮（树模式 ±）。
 * 【前置条件 / 假设】
 *   - 依赖：MemoryRepository(订阅制)、GardenController（被 MainPage HDS 菜单调用）、
 *     ShellState.gardenScroller（滚动绑定）、MockData 默认记忆；
 *   - 假设：详情面板/工具栏被“全屏容器”包裹时用 hitTestBehavior 放行点击；
 *     编辑浮窗与搜索/菜单浮窗均为“打开时挂载”，关闭不渲染。
 * 【输入 / 输出（后置条件）】
 *   - 输入：HDS 菜单按钮（搜索/更多）、模式菜单选择、节点/列表点击、搜索关键字、
 *     编辑提交、缩放按钮、拖动收起详情；
 *   - 输出：视图切换（switchMode）、选中记忆详情面板（selectMemory/closeDetail）、
 *     树缩放(treeZoom)、编辑写回 MemoryRepository、搜索过滤(filtered)。
 * 【关键类 / 算法】
 *   - A_Garden：视图分发（mode 枚举 -> gardenView/outlineView/treeView）；
 *   - GardenNodeMarker：节点标记列；MemoryTreeGraph：树绘制；TreeLayout：树布局算法；
 *   - detailH：详情面板高度（拖动收起，吸附 196/372 等档位）。
 * 【参考源】
 *   - HarmonyLearn（知识图谱/树的绘制思路）；Examples/ArkUISample；
 *     MoMo_DOC/UI 参考图（花园首页稿）
 * ============================================================================
 */
import { MemoryRepository } from '../repository/Repositories';
import { GardenController } from '../service/Services';
import { AppRouter, RouteName } from '../router/AppRouter';
import { MockData } from '../mock/MockData';
import {
  GardenMode, GardenNodeItem, Memory, MemoryTreeNode, MemoryType, MemoryTypeUtil, PageState
} from '../model/Models';
import { DateUtil } from '../utils/DateUtil';
import { Theme } from '../utils/Theme';
import { PromptUtil } from '../utils/PromptUtil';
import { DeviceUtil } from '../utils/DeviceUtil';
import { ShellState } from '../service/Services';
import { ModeMenu } from '../components/ModeMenu';
import { GardenNodeMarker } from '../components/GardenNodeMarker';
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

@Component
export struct A_Garden {
  @State pageState: PageState = PageState.LOADING;
  @State mode: GardenMode = GardenMode.GARDEN;
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
  @State outlineScroll: number = 0;
  @State editTitle: string = '';
  @State editTags: string = '';
  @State editSummary: string = '';
  private repo: MemoryRepository = MemoryRepository.get();
  private nodes: GardenNodeItem[] = MockData.buildGardenNodes();
  private repoListener: () => void = () => {
  };
  private panBase: number = 196;
  private gardenScroller: Scroller = ShellState.gardenScroller;
  private outlineScroller: Scroller = new Scroller();

  // 生命周期：注册仓库监听（记忆变化重载）、HDS 菜单桥（搜索/更多/收起详情）、
  // 400ms 后读取初始记忆并默认选中 m4 打开详情面板
  aboutToAppear(): void {
    if (GardenController.modeOverride >= 0) {
      this.mode = GardenController.modeOverride as GardenMode;
      GardenController.modeOverride = -1;
    }
    this.repoListener = () => {
      this.memories = this.repo.getAll();
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
            // 花园模式：选中节点（带选中环+详情浮层）；记忆树模式：高亮该节点
            this.selectMemory(target);
          }
        }
      } else {
        const first = this.repo.getById('m4');
        if (first !== null) {
          if (this.mode === GardenMode.GARDEN) {
            // 花园模式：默认选中并打开节点详情（系统浮层，查看模式）
            this.selectMemory(first);
          } else {
            // 大纲/记忆树：仅高亮首个节点，不弹浮层
            this.selectedMemory = first;
            this.detailOpen = false;
          }
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

  private nodePosOf(mem: Memory): GardenNodeItem {
    for (let i = 0; i < this.nodes.length; i++) {
      if (this.nodes[i].memoryId === mem.id) {
        return this.nodes[i];
      }
    }
    let h1 = 0;
    let h2 = 0;
    for (let i = 0; i < mem.id.length; i++) {
      h1 = (h1 * 31 + mem.id.charCodeAt(i)) % 997;
      h2 = (h2 * 43 + mem.id.charCodeAt(i)) % 991;
    }
    const n = new GardenNodeItem();
    n.id = 'auto-' + mem.id;
    n.memoryId = mem.id;
    n.x = 12 + (h1 % 60);
    n.y = 32 + (h2 % 30);
    return n;
  }

  // 选中记忆：打开详情面板（detailH 吸附高度）+ 更新编辑浮窗数据源
  private selectMemory(m: Memory): void {
    this.selectedMemory = m;
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
    const gNames: string[] = ['生活', '学习', '兴趣', '目标', '重要回忆'];
    const gKeys: MemoryType[] = [MemoryType.LIFE, MemoryType.STUDY, MemoryType.INTEREST, MemoryType.GOAL, MemoryType.IMPORTANT];
    const groups: MemoryTreeNode[] = [];
    for (let g = 0; g < 5; g++) {
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

  @Builder
  gardenView() {
    Stack({ alignContent: Alignment.Top }) {
      Image($r('app.media.garden_bg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(0.96)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      ForEach(this.memories, (m: Memory) => {
        Column() {
          GardenNodeMarker({
            memory: m,
            selected: this.selectedMemory !== null && this.selectedMemory.id === m.id,
            onTap: (mm: Memory) => {
              this.selectMemory(mm);
            }
          })
        }
        .position({
          x: this.nodePosOf(m).x + '%',
          y: this.nodePosOf(m).y + '%'
        })
        .translate({ x: -38, y: -30 })
      }, (m: Memory) => m.id)

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

  @Builder
  outlineView() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll(this.outlineScroller) {
        Column({ space: 0 }) {
          Blank().height(132)
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
                    .fontSize(14)
                    .fontWeight(this.selectedMemory !== null && this.selectedMemory.id === m.id
                      ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor(this.selectedMemory !== null && this.selectedMemory.id === m.id
                      ? '#3FA55F' : Theme.SECONDARY)
                  Blank()
                  Text(MemoryTypeUtil.nameOf(m.type))
                    .fontSize(10)
                    .fontColor(MemoryTypeUtil.colorOf(m.type))
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .backgroundColor(MemoryTypeUtil.colorOf(m.type) + '22')
                    .borderRadius(9)
                }
                .width('100%')

                Text(m.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Theme.PRIMARY)
                  .width('100%')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(m.summary)
                  .fontSize(13)
                  .fontColor(Theme.SECONDARY)
                  .width('100%')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Row({ space: 6 }) {
                  ForEach(m.tags.slice(0, 3), (t: string) => {
                    Text(t)
                      .fontSize(10)
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
          Blank().height(240)
        }
        .width('100%')
        .padding({ left: 20 })
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onScroll((offset: number) => {
        this.outlineScroll = offset;
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 沉浸式标题遮罩：滚动时顶部渐变模糊（参考沉浸标题栏动态模糊做法）
      Column() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
          .backgroundColor('rgba(247,250,244,0.82)')
        Column()
          .width('100%')
          .height(22)
          .linearGradient({
            angle: 180,
            colors: [['#D2F7FAF4', 0], ['#00F7FAF4', 1]]
          })
          .position({ y: 148 })
      }
      .width('100%')
      .height(170)
      .opacity(this.outlineScroll > 12 ? 1 : 0)
      .animation({ duration: 200, curve: Curve.EaseOut })
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
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_MAIN)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row() {
        Text(this.sel().date)
          .fontSize(12)
          .fontColor(Theme.TEXT_TERTIARY)
        Blank()
        Row({ space: 6 }) {
          ForEach(this.sel().tags.slice(0, 2), (t: string) => {
            Text(t)
              .fontSize(11)
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
        .fontSize(14)
        .fontColor(Theme.TEXT_SUB)
        .width('100%')
        .margin({ top: 12 })

      Text(this.sel().content)
        .fontSize(13)
        .fontColor(Theme.TEXT_TERTIARY)
        .lineHeight(20)
        .width('100%')
        .margin({ top: 8 })
        .maxLines(6)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // 小工具栏：编辑 / 删除 / 撤销 / 重做（等宽对齐居中，含点击反馈）
      Row() {
        Column() {
          SymbolGlyph($r('sys.symbol.pencil_line')).fontSize(20).fontColor(['#3E6B4B'])
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
          SymbolGlyph($r('sys.symbol.trash')).fontSize(20).fontColor(['#C4573F'])
        }
        .width('25%')
        .height(44)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.openDeleteConfirm();
        })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })

        Column() {
          SymbolGlyph($r('sys.symbol.arrow_counterclockwise')).fontSize(20)
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
          SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(20)
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
          .fontSize(15)
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
            SymbolGlyph($r('sys.symbol.xmark')).fontSize(16).fontColor([Theme.SECONDARY])
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
            .fontSize(13)
            .fontColor(Theme.TERTIARY)
            .margin({ top: 30, bottom: 30 })
        } else {
          Scroll() {
            Column() {
              ForEach(this.filtered(), (m: Memory) => {
                Row({ space: 10 }) {
                  Column({ space: 4 }) {
                    Text(m.title)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Theme.PRIMARY)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(m.date + ' · ' + MemoryTypeUtil.nameOf(m.type))
                      .fontSize(11)
                      .fontColor(Theme.TERTIARY)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([Theme.TERTIARY])
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
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8 })

      Column({ space: 6 }) {
        Text('记忆标题')
          .fontSize(12)
          .fontColor(Theme.TEXT_TERTIARY)
          .width('100%')
        TextInput({ text: this.editTitle, placeholder: '默认沿用当前节点标题' })
          .fontSize(15)
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
          .fontSize(12)
          .fontColor(Theme.TEXT_TERTIARY)
          .width('100%')
        TextInput({ text: this.editTags, placeholder: '如：目标，漫画' })
          .fontSize(14)
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
          .fontSize(12)
          .fontColor(Theme.TEXT_TERTIARY)
          .width('100%')
        TextArea({ text: this.editSummary, placeholder: '默认沿用当前节点摘要' })
          .fontSize(14)
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
          .fontSize(15)
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
          .fontSize(15)
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
        if (this.mode === GardenMode.GARDEN) {
          this.gardenView()
        } else if (this.mode === GardenMode.OUTLINE) {
          this.outlineView()
        } else {
          this.treeView()
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