/*
 * ============================================================================
 * 文件名：pages/MainPage.ets
 * ============================================================================
 * 【用途】App 唯一入口（@Entry）页面，即“应用外壳”：
 *   - 用 HdsNavigation(HDS 导航容器) + HdsTabs(HDS 底部 Tab) 组装三级结构：
 *     一级 Tab（首页 A_Home / 花园 A_Garden / 设置 A_Settings）
 *       + 二级页（今日状态 / 今日漫画 / 关于默默，经 pagesMap 路由）
 *   - 提供沉浸式标题栏（滚动渐变模糊）+ 系统菜单按钮（首页：换状态/去花园/关于；
 *     花园：搜索/更多），以及底部悬浮导航栏与“分离的加号(miniBar)”。
 *   - 全局“记一笔”浮窗（GlassSheet，挂载即显示）与对应回调（写入 Mock 记忆仓库）。
 * 【前置条件 / 假设】
 *   - 依赖：AppRouter(NavPathStack 路由栈)、各 Repository/Mock 数据已就绪、
 *     Services 中 TabController/HomeController/GardenController/ShellState 为静态控制器；
 *   - 运行环境：HarmonyOS NEXT，SDK API 22+（HDS 为 6.1.0(23) 特性，低版本会降级警告）；
 *   - 假设用户昵称可由 UserRepository 读取（Mock 数据），HDS 运行时可用。
 * 【输入 / 输出（后置条件）】
 *   - 输入：启动参数 want.parameters.autoNav（如 "B_TodayMemory"/"garden-tree"/"add"，
 *     仅开发调试用）；用户点击（Tab、菜单、加号、卡片）；
 *   - 输出：渲染完整外壳；Tab 切换、路由压栈（AppRouter.push）、
 *     记忆写入（MemoryRepository.add）、默默状态切换（CompanionService.setState）。
 * 【关键类 / 算法】
 *   - MainPage：壳组件（持有 tabsCtrl：HdsTabsController、tab 状态、addOpen 浮窗状态）；
  // 路由表：HdsNavigation 通过 navDestination(this.pagesMap) 按路由名实例化二级页
 *   - MiniBarNode：全局 @Builder —— HdsTabs.miniBar 的“+”按钮（CustomBuilder 需无 this，
 *     故用全局函数 + // (removed) 静态跳板）；
 *   - pagesMap：navDestination 路由表（name -> 目标页面组件）。
 * 【参考源】
 *   - Examples/hdsNavigation Examples.md（HDS 标题栏/菜单/滚动模糊参数）
 *   - Examples/ihbest-ui 的 BasePage.ets（HdsNavDestination 封装思路）
import { HdsNavigation, HdsNavigationTitleMode, HdsTabs, HdsTabsController, hdsMaterial, ScrollEffectType, HdsNavigationMenuContentOptions } from '@kit.UIDesignKit';
 * ============================================================================
 */
import { HdsNavigation, HdsNavigationTitleMode, HdsTabs, HdsTabsController, hdsMaterial, ScrollEffectType, HdsNavigationMenuContentOptions } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { AppRouter, RouteName } from '../router/AppRouter';
import { GardenController, CompanionService, TabController, HomeController, ShellState } from '../service/Services';
import { UserRepository, MemoryRepository } from '../repository/Repositories';
import { Memory, MemoryType, MoMoState, GardenMode } from '../model/Models';
import { AddSheetContent } from '../components/Sheets';
import { PromptUtil } from '../utils/PromptUtil';
import { Theme } from '../utils/Theme';
import { DateUtil } from '../utils/DateUtil';
import { A_Home } from './A_Home';
import { A_Garden } from './A_Garden';
import { A_Settings } from './A_Settings';
import { B_TodayMemory } from './B_TodayMemory';
import { B_DailyComic } from './B_DailyComic';
import { B_About } from './B_About';
import { B_Search } from './B_Search';
import { B_ComicViewer } from './B_ComicViewer';

@Entry
@Component
struct MainPage {

  @State tab: number = 0;
  @State addOpen: boolean = false;
  @State userName: string = '酪酪肽';
  // 响应式花园模式（AppStorage 驱动，菜单随模式实时刷新）
  @StorageLink('gardenMode') gardenMode: number = 0;
  private tabsCtrl: HdsTabsController = new HdsTabsController();
  private hi: string = '你好';

  // 生命周期：初始化昵称/问候语、绑定 TabController/HomeController 桥、消费调试参数 autoNav（页面跳转或切 Tab）
  aboutToAppear(): void {
    this.userName = UserRepository.get().getUser().name;
    this.hi = DateUtil.greeting(new Date().getHours()) + '，' + this.userName;
    TabController.switch = (index: number) => {
      this.tabsCtrl.changeIndex(index);
    };
    HomeController.cycleState = () => {
      CompanionService.get().cycle();
      PromptUtil.toast('默默切换了一个新状态');
    };
    if (AppRouter.autoNav !== '') {
      setTimeout(() => {
        const nav = AppRouter.autoNav;
        AppRouter.autoNav = '';
        if (nav === 'B_TodayMemory') {
          AppRouter.push(RouteName.TODAY_MEMORY);
        } else if (nav === 'B_DailyComic') {
          AppRouter.push(RouteName.DAILY_COMIC);
        } else if (nav === 'B_About') {
          AppRouter.push(RouteName.ABOUT);
        } else if (nav === 'garden-search') {
          AppRouter.push(RouteName.SEARCH);
        } else if (nav === 'garden-outline') {
          TabController.switch(1);
          GardenController.modeOverride = GardenMode.OUTLINE;
        } else if (nav === 'garden-tree') {
          TabController.switch(1);
          GardenController.modeOverride = GardenMode.TREE;
        } else if (nav === 'garden-garden') {
          TabController.switch(1);
          GardenController.modeOverride = GardenMode.GARDEN;
        } else if (nav === 'add') {
          this.openAdd();
        }
      }, 900);
    }
  }

  // 打开“记一笔”浮窗：花园 Tab 先收起详情；首页同时把默默切到倾听态（LISTENING）
  private openAdd(): void {
    if (this.tab === 1) {
      GardenController.closeDetail();
    }
    if (this.tab === 0) {
      CompanionService.get().setState(MoMoState.LISTENING);
    }
    this.addOpen = true;
  }

  private closeAdd(): void {
    this.addOpen = false;
    if (this.tab === 0) {
      CompanionService.get().setState(MoMoState.IDLE);
    }
  }

  private onAddDone(text: string): void {
    const snapshot = text.length > 18 ? text.slice(0, 18) + '…' : text;
    if (this.tab === 1) {
      const m = new Memory('m-' + Date.now().toString(), snapshot, new Date(), MemoryType.LIFE, 2);
      m.summary = text;
      m.tags = ['新记忆', '口述'];
      MemoryRepository.get().add(m);
      PromptUtil.toast('默默把这条记忆种进了花园');
    } else {
      PromptUtil.toast('默默已记下（Mock），快去花园看看吧');
    }
    this.closeAdd();
  }

  private currentTitle(): string {
    if (this.tab === 0) {
      return this.hi;
    } else if (this.tab === 1) {
      return '记忆花园';
    }
    return '设置';
  }

  // 标题栏系统菜单（列表型）：首页 3 项（换状态/去花园/关于），花园 2 项（搜索/更多），设置无
  // 标题栏系统菜单（列表型）：首页 3 项（换状态/去花园/关于），花园 2 项（搜索/更多），设置无
  private currentMenu(): HdsNavigationMenuContentOptions | undefined {
    if (this.tab === 0) {
      return {
        value: [
          { content: { label: '换状态', icon: $r('sys.symbol.arrow_clockwise'), isEnabled: true, action: () => { HomeController.cycleState(); } } },
          { content: { label: '去花园', icon: $r('sys.symbol.leaf'), isEnabled: true, action: () => { TabController.switch(1); } } },
          { content: { label: '关于默默', icon: $r('sys.symbol.star'), isEnabled: true, action: () => { AppRouter.push(RouteName.ABOUT); } } }
        ]
      };
    } else if (this.tab === 1) {
      // 记忆树模式：系统菜单改为 [搜索, −, ＋, 花园, 大纲]（± 右对齐系统按钮，缩放树）
      if (this.gardenMode === GardenMode.TREE) {
        return {
          // 记忆树模式：HDS 系统 ± 按钮（右对齐），并保留花园/大纲出口（搜索在其他模式可达）
          value: [
            { content: { label: '缩小', icon: $r('sys.symbol.minus'), isEnabled: true, action: () => { GardenController.zoomOut(); } } },
            { content: { label: '放大', icon: $r('sys.symbol.plus'), isEnabled: true, action: () => { GardenController.zoomIn(); } } },
            { content: { label: '花园模式', icon: $r('sys.symbol.house'), isEnabled: true, action: () => { GardenController.switchTo(GardenMode.GARDEN); } } },
            { content: { label: '大纲模式', icon: $r('sys.symbol.star'), isEnabled: true, action: () => { GardenController.switchTo(GardenMode.OUTLINE); } } }
          ]
        };
      }
      return {
        value: [
          { content: { label: '搜索记忆', icon: $r('sys.symbol.magnifyingglass'), isEnabled: true, action: () => { GardenController.openSearch(); } } },
          { content: { label: '花园模式', icon: $r('sys.symbol.house'), isEnabled: true, action: () => { GardenController.switchTo(GardenMode.GARDEN); } } },
          { content: { label: '大纲模式', icon: $r('sys.symbol.star'), isEnabled: true, action: () => { GardenController.switchTo(GardenMode.OUTLINE); } } },
          { content: { label: '记忆树', icon: $r('sys.symbol.leaf'), isEnabled: true, action: () => { GardenController.switchTo(GardenMode.TREE); } } }
        ]
      };
    }
    return undefined;
  }

  @Builder
  addSheetContent() {
    AddSheetContent({
      userName: this.userName,
      onDismiss: () => {
        this.closeAdd();
      },
      onDone: (text: string) => {
        this.onAddDone(text);
      }
    })
  }

  // 路由表：HdsNavigation 通过 navDestination(this.pagesMap) 按路由名实例化二级页
  @Builder
  pagesMap(name: string) {
    if (name === 'B_TodayMemory') {
      B_TodayMemory()
    } else if (name === 'B_DailyComic') {
      B_DailyComic()
    } else if (name === 'B_About') {
      B_About()
    } else if (name === 'B_Search') {
      B_Search()
    } else if (name === 'C_ComicViewer') {
      B_ComicViewer()
    }
  }

  @Builder
  tabBuilder(index: number) {
    Column() {
      SymbolGlyph(this.tabIcon(index))
        .fontSize(24)
        .fontColor([this.tab === index ? '#97FFAB' : '#9A9B94'])
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 6, bottom: 6 })
  }

  private tabIcon(index: number): Resource {
    if (index === 0) {
      return $r('sys.symbol.house');
    } else if (index === 1) {
      return $r('sys.symbol.leaf');
    }
    return $r('sys.symbol.gearshape');
  }

  // 分离加号（miniBar）：与导航栏一致样式（白色半透明 + 细边框 + 主色图标），仅作为按钮
  @Builder
  miniBarBuilder() {
    Stack() {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(24)
        .fontColor(['#6FDF8E'])
    }
    .width(56)
    .height(56)
    .borderRadius(28)
    .backgroundColor('#F2FFFFFF')
    .backdropBlur(20)
    .border({ width: 1, color: Theme.CARD_BORDER })
    .shadow({ radius: 14, color: '#22000000', offsetX: 0, offsetY: 4 })
    .onClick(() => {
      this.openAdd();
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
  }

  build() {
    Column() {
      HdsNavigation(AppRouter.stack) {
        HdsTabs({ controller: this.tabsCtrl }) {
          TabContent() {
            A_Home()
          }
          .tabBar(this.tabBuilder(0))

          TabContent() {
            A_Garden()
          }
          .tabBar(this.tabBuilder(1))

          TabContent() {
            A_Settings()
          }
          .tabBar(this.tabBuilder(2))
        }
        .width('100%')
        .height('100%')
        .scrollable(false)
        .barPosition(BarPosition.End)
        .barOverlap(true)
        .vertical(false)
        .barBackgroundBlurStyle(BlurStyle.Thin)
        // 悬浮光感：底部大边距 + 全宽渐变光罩(#66F1F3F5/92) + 系统沉浸材质(IMMERSIVE/ADAPTIVE)
        .barFloatingStyle({
          barBottomMargin: 28,
          gradientMask: { maskColor: '#66F1F3F5', maskHeight: 92 },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          },
          miniBar: {
            miniBarBuilder: (): void => this.miniBarBuilder(),
            enableMiniBarClip: true
          }
        })
        .animationDuration(0)
        .onChange((index: number) => {
          this.tab = index;
          if (index === 0) {
            CompanionService.get().setState(MoMoState.IDLE);
          } else {
            CompanionService.get().setState(MoMoState.CURIOUS);
          }
        })
      }
      .mode(NavigationMode.Stack)
      // 首页/记忆花园/设置 三个一级页共用同一个 HDS 标题栏，标题位置固定：
      // 华为《标题栏》视觉规范：默认单行高度 56vp、强调型 112vp；FREE 为动态布局
      // （随手势滑动缩小高度），MINI / FULL 均为固定样式。
      // 这里用 MINI（单行标题栏）：标题与右侧菜单图标同一水平线、垂直居中对齐，
      // 不随页面滚动位移，也不使用任何绝对像素定位。
      .titleMode(HdsNavigationTitleMode.MINI)
      .navDestination(this.pagesMap)
      .titleBar({
        padding: {
          start: LengthMetrics.vp(16),
          end: LengthMetrics.vp(16)
        },
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
            blurEffectiveStartOffset: LengthMetrics.vp(12),
            blurEffectiveEndOffset: LengthMetrics.vp(56)
          },
          originalStyle: {
            backgroundStyle: {
              backgroundColor: 'rgba(247,250,244,0.0)'
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: '#1E2A22'
              },
              menuStyle: {
                backgroundColor: 'rgba(255,255,255,0.92)',
                iconColor: '#1E2A22'
              },
              backIconStyle: {
                backgroundColor: 'rgba(255,255,255,0.92)',
                iconColor: '#1E2A22'
              }
            }
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: 'rgba(247,250,244,0.88)',
              // 加重标题栏模糊量：HDS 仅在 GRADIENT_BLUR / IMMERSIVE_GRADIENT_BLUR 下生效，范围 0~128
              blurRadius: 128,
              // 模糊层的下边缘 = 标题栏高度 + maskExtraHeight（默认 32vp）。
              // 调到 112vp：内容还没压到标题栏、只是靠近时就已经开始渐模糊。
              maskExtraHeight: 112
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: '#1E2A22'
              },
              menuStyle: {
                backgroundColor: 'rgba(255,255,255,0.92)',
                iconColor: '#1E2A22'
              },
              backIconStyle: {
                backgroundColor: 'rgba(255,255,255,0.92)',
                iconColor: '#1E2A22'
              }
            }
          }
        },
        content: {
          title: {
            mainTitle: this.currentTitle()
          },
          menu: this.currentMenu()
        },
        avoidLayoutSafeArea: true
      })
      // 一级页：Mini 单行样式默认会带出返回图标，按规范在一级页隐藏（见《标题栏》视觉规范）
      .hideBackButton(true)
      .systemBarStyle(
        { statusBarContentColor: '#1E2A22' },
        { statusBarContentColor: '#1E2A22' }
      )
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      // 绑定三个一级页的滚动器：HDS 标题栏据此驱动「沉浸渐变模糊」（标题栏下方渐变实时模糊）
      .bindToScrollable([ShellState.homeScroller, ShellState.gardenScroller, ShellState.gardenOutlineScroller,
        ShellState.settingsScroller])
      // 系统底部浮层（bindSheet）：自带拖拽关闭条；加号点击 -> addOpen=true 即从底部上浮
      .bindSheet($$this.addOpen, this.addSheetContent, {
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        dragBar: true,
        backgroundColor: Theme.SHEET_BG,
        showInSubWindow: false
      })
    }
    .width('100%')
    .height('100%')
  }
}