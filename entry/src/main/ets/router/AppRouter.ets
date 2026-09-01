/*
 * ============================================================================
 * 文件名：router/AppRouter.ets
 * ============================================================================
 * 【用途】路由工具：全局 NavPathStack（AppRouter.stack）供 HdsNavigation 使用，
 *   push(name)/back()/clear() 封装压栈/出栈；Enum 路由名（RouteName）与
 *   RouteParam（空参数哨兵）；autoNav 为开发调试用自动跳转标记。
 * 【前置条件 / 假设】
 *   - 依赖：@kit.ArkUI（NavPathStack）；页面名与 pagesMap/navDestination 一致；
 *   - 假设：单栈应用；NONE 参数用 EmptyParam 占位（避免 undefined 语义）。
 * 【输入 / 输出（后置条件）】
 *   - 输入：push(name,param?)/back()/clear()；
 *   - 输出：栈变化；后置：push 后栈顶为目标页，back 后回到上一页。
 * 【关键类 / 算法】
 *   - pushPathByName + 参数串联（lastParam）；autoNav 由 EntryAbility 解析参数后写入。
 * 【参考源】
 *   - Examples/ArkUISample（Navigation 路由）；DevEco Navigation 文档
 * ============================================================================
 */
export class RouteName {
  static readonly TODAY_MEMORY: string = 'B_TodayMemory';
  static readonly DAILY_COMIC: string = 'B_DailyComic';
  static readonly ABOUT: string = 'B_About';
}

class EmptyParam {
  marker: boolean = true;
}

export class RouteParam {
  static readonly NONE: object = new EmptyParam();
}

export class AppRouter {
  static stack: NavPathStack = new NavPathStack();
  static lastParam: object = RouteParam.NONE;
  static autoNav: string = '';

  static push(name: string, param?: object): void {
    AppRouter.lastParam = param ?? RouteParam.NONE;
    AppRouter.stack.pushPathByName(name, AppRouter.lastParam);
  }

  static back(): void {
    AppRouter.stack.pop();
  }

  static clear(): void {
    AppRouter.stack.clear();
  }
}