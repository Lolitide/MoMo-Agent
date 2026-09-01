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
 *     故用全局函数 + MainPage.openAddStatic 静态跳板）；
 *   - pagesMap：navDestination 路由表（name -> 目标页面组件）。
 * 【参考源】
 *   - Examples/hdsNavigation Examples.md（HDS 标题栏/菜单/滚动模糊参数）
 *   - Examples/ihbest-ui 的 BasePage.ets（HdsNavDestination 封装思路）
 *   - SDK 声明：@kit.UIDesignKit（HdsNavigation/HdsTabs/ScrollEffectType）、@kit.ArkUI
 * ============================================================================
 */
import { HdsNavigation, HdsNavigationTitleMode, HdsTabs, HdsTabsController, HdsBarLayoutMode, ScrollEffectType, HdsNavigationMenuContentOptions } from '@kit.UIDesignKit';
import { LengthMetrics, ComponentContent } from '@kit.ArkUI';
import { AppRouter, RouteName } from '../router/AppRouter';
import { GardenController, CompanionService, TabController, HomeController, ShellState } from '../service/Services';
import { UserRepository, MemoryRepository } from '../repository/Repositories';
import { Memory, MemoryType, MoMoState, GardenMode } from '../model/Models';
import { GlassSheet } from '../components/GlassSheet';
import { AddSheetContent } from '../components/Sheets';
import { PromptUtil } from '../utils/PromptUtil';
import { DateUtil } from '../utils/DateUtil';
import { A_Home } from './A_Home';
import { A_Garden } from './A_Garden';
import { A_Settings } from './A_Settings';
import { B_TodayMemory } from './B_TodayMemory';
import { B_DailyComic } from './B_DailyComic';
import { B_About } from './B_About';

// 全局 MiniBar 构建函数（HdsTabs.miniBar 的 CustomBuilder）
@Builder
function MiniBarNode() {
  Column() {
    SymbolGlyph($r('sys.symbol.plus')).fontSize(24).fontColor(['#1E2A22'])
  }
  .width(52)
  .height(52)
  .borderRadius(26)
  .backgroundColor('rgba(250,252,249,0.92)')
  .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
  .border({ width: 1, color: 'rgba(255,255,255,0.92)' })
  .shadow({ radius: 22, color: 'rgba(26,48,32,0.18)', offsetY: 6 })
  .justifyContent(FlexAlign.Center)
  .onClick(() => {
    MainPage.openAddStatic();
  })
}

@Entry
@Component
struct MainPage {
  static openAddStatic: () => void = () => {
  };
  @State tab: number = 0;
  @State addOpen: boolean = false;
  @State userName: string = '酪酪肽';
  private tabsCtrl: HdsTabsController = new HdsTabsController();
  private hi: string = '你好';
  private miniBarContent: ComponentContent<Object> | null = null;

  // 生命周期：注册加号静态跳板、创建 miniBar 的 ComponentContent、初始化昵称/问候语、
  // 绑定 TabController/HomeController 桥、消费调试参数 autoNav（页面跳转或切 Tab）
  // 生命周期：注册加号静态跳板、创建 miniBar 的 ComponentContent、初始化昵称/问候语、
  // 绑定 TabController/HomeController 桥、消费调试参数 autoNav（页面跳转或切 Tab）
  aboutToAppear(): void {
    MainPage.openAddStatic = () => {
      this.openAdd();
    };
    try {
      this.miniBarContent = new ComponentContent(this.getUIContext(), wrapBuilder(MiniBarNode)) as ComponentContent<Object>;
    } catch (e) {
      this.miniBarContent = null;
    }
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
      return {
        value: [
          { content: { label: '搜索记忆', icon: $r('sys.symbol.magnifyingglass'), isEnabled: true, action: () => { GardenController.openSearch(); } } },
          { content: { label: '更多', icon: $r('sys.symbol.ellipsis_message_1'), isEnabled: true, action: () => { GardenController.openMenu(); } } }
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
    }
  }

  @Builder
  tabItem(icon: Resource, selIcon: Resource, label: string, index: number) {
    Column({ space: 2 }) {
      SymbolGlyph(this.tab === index ? selIcon : icon)
        .fontSize(24)
        .fontColor([this.tab === index ? '#3E6B4B' : '#8CA089'])
      Text(label)
        .fontSize(10)
        .fontColor(this.tab === index ? '#3E6B4B' : '#9BAC9F')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      HdsNavigation(AppRouter.stack) {
        HdsTabs({ controller: this.tabsCtrl }) {
          TabContent() {
            A_Home()
          }
          .tabBar(this.tabItem($r('sys.symbol.house'), $r('sys.symbol.house_fill'), '首页', 0))

          TabContent() {
            A_Garden()
          }
          .tabBar(this.tabItem($r('sys.symbol.leaf'), $r('sys.symbol.leaf_fill'), '花园', 1))

          TabContent() {
            A_Settings()
          }
          .tabBar(this.tabItem($r('sys.symbol.gearshape'), $r('sys.symbol.gearshape_fill'), '设置', 2))
        }
        .barPosition(BarPosition.End)
        .scrollable(true)
        .animationDuration(260)
        .barMode(BarMode.Fixed)
        .barHeight(64)
        .barOverlap(true)
        .barBackgroundColor('rgba(250,252,249,0.0)')
        .barFloatingStyle({
          barWidth: { smallWidth: 250, mediumWidth: 280, largeWidth: 320 },
          barSideMargin: 20,
          barBottomMargin: 8,
          gradientMask: { maskColor: 'rgba(247,250,244,0.96)', maskHeight: 64 },
          lightColor: '#97FFAB',
          systemMaterialEffect: { materialType: 100, materialLevel: 10 },
          barOpacity: 1,
          miniBar: {
            miniBarBuilder: this.miniBarContent ?? MiniBarNode,
            barLayoutMode: HdsBarLayoutMode.HORIZONTAL
          },
          adaptToHandedness: false
        })
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
      .titleMode(HdsNavigationTitleMode.FREE)
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
              backgroundColor: 'rgba(247,250,244,0.88)'
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
        }
      })
      .systemBarStyle(
        { statusBarContentColor: '#1E2A22' },
        { statusBarContentColor: '#1E2A22' }
      )
      .bindToScrollable([ShellState.homeScroller, ShellState.gardenScroller, ShellState.settingsScroller])

      // 浮窗“挂载即显示”原则：关闭时不渲染任何层，避免残留全屏层拦截滚动/点击
      if (this.addOpen) {
        GlassSheet({
          show: true,
          heightRatio: 0.76,
          onDismiss: () => {
            this.closeAdd();
          },
          content: this.addSheetContent
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}