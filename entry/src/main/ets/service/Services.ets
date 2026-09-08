/*
 * ============================================================================
 * 文件名：service/Services.ets
 * ============================================================================
 * 【用途】应用服务层（全局控制器/状态）：CompanionService（默默状态机与订阅）、
 *   HomeController（首页“换状态”动作）、GardenController（花园搜索/更多/关闭详情等
 *   由 HDS 菜单调用的动作桥），TabController（Tab 切换桥）、ShellState（三个共享 Scroller，
 *   供 HDS 标题栏 bindToScrollable）。
 * 【前置条件 / 假设】
 *   - 依赖：Models、Repositories、DateUtil、PromptUtil；
 *   - 假设：静态桥接函数在页面 aboutToAppear 赋值（Controller.* = fn），aboutToDisappear 清空；
 *     单例（get()）。
 * 【输入 / 输出（后置条件）】
 *   - 输入：cycle/state 设置、菜单点击（openSearch/openMenu/closeDetail）、switch(index)；
 *   - 输出：状态通知订阅者（页面刷新）；Tab 索引切换（HdsTabsController.changeIndex）；
 *   - 后置：切换首页/花园 Tab 时默默状态自动设为 IDLE/CURIOUS。
 * 【关键类 / 算法】
 *   - MoMoState 循环：IDLE->THINKING->HAPPY->…->IDLE（循环取模）；
 *   - 静态跳板模式：解决“HDS 菜单 action 无法直接引用页面实例”的问题。
 * 【参考源】
 *   - 废案 CompanionState 模型；Android/HarmonyOS Controller 层惯例
 * ============================================================================
 */
import { MoMoState } from '../model/Models';

export type StateListener = () => void;

// 默默状态机服务：持有当前 MoMoState 与订阅者列表；cycle() 循环切换（取模8），
// setState() 广播给页面（首页/花园据此刷新动画状态）
export class CompanionService {
  private static instance: CompanionService | null = null;
  private current: MoMoState = MoMoState.IDLE;
  private listeners: StateListener[] = [];

  static get(): CompanionService {
    if (CompanionService.instance === null) {
      CompanionService.instance = new CompanionService();
    }
    return CompanionService.instance;
  }

  getState(): MoMoState {
    return this.current;
  }

  setState(s: MoMoState): void {
    if (this.current !== s) {
      this.current = s;
      for (let i = 0; i < this.listeners.length; i++) {
        this.listeners[i]();
      }
    }
  }

  cycle(): void {
    const next: MoMoState[] = [MoMoState.IDLE, MoMoState.CURIOUS, MoMoState.HAPPY, MoMoState.THINKING];
    const idx = Math.floor(Math.random() * next.length);
    this.setState(next[idx]);
  }

  subscribe(cb: StateListener): void {
    this.listeners.push(cb);
  }

  unsubscribe(cb: StateListener): void {
    const next: StateListener[] = [];
    for (let i = 0; i < this.listeners.length; i++) {
      if (this.listeners[i] !== cb) {
        next.push(this.listeners[i]);
      }
    }
    this.listeners = next;
  }
}

// 供一级页面请求切换底部导航
export class TabController {
  static switch: (index: number) => void = (index: number) => {
  };
}

// 供 MainPage 通知 Garden 面板收起（新增记忆前）
export class GardenController {
  static closeDetail: () => void = () => {
  };
  static openSearch: () => void = () => {
  };
  static openMenu: () => void = () => {
  };
  static modeOverride: number = -1;
  static pendingFocusId: string = '';
  static switchTo: (m: number) => void = (m: number) => {};
  static gardenMode: number = -1;
  static zoomIn: () => void = () => {};
  static zoomOut: () => void = () => {};
}

// 首页动作入口（由 HdsNavigation 系统按钮触发）
export class HomeController {
  static cycleState: () => void = () => {
  };
}

// 外壳共享的滚动器（HdsNavigation 滚动模糊绑定）
export class ShellState {
  static homeScroller: Scroller = new Scroller();
  static gardenScroller: Scroller = new Scroller();
  static settingsScroller: Scroller = new Scroller();
}

export class SettingsService {
  private static instance: SettingsService | null = null;
  darkMode: boolean = false;
  largeFont: boolean = false;
  themeColor: string = '#97FFAB';
  readCalendar: boolean = true;
  readTodo: boolean = true;
  readMemo: boolean = false;
  cameraAccess: boolean = false;
  lowInterrupt: boolean = true;

  static get(): SettingsService {
    if (SettingsService.instance === null) {
      SettingsService.instance = new SettingsService();
    }
    return SettingsService.instance;
  }
}