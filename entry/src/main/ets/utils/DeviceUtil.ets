/*
 * ============================================================================
 * 文件名：utils/DeviceUtil.ets
 * ============================================================================
 * 【用途】设备/窗口工具：读取状态栏高度与安全区（avoidArea），
 *   供自绘标题栏/浮窗做沉浸避让（API 26 无 getWindowAvoidArea 时的兼容路径）。
 * 【前置条件 / 假设】
 *   - 依赖：@kit.ArkUI（window/UIContext）；默认假设状态栏高 39vp（失败兜底）；
 *   - 假设：在页面 aboutToAppear 后调用 initFromUi 再读取。
 * 【输入 / 输出（后置条件）】
 *   - 输入：UIContext；
 *   - 输出：静态 statusBarH（vp）；副作用：仅缓存值。
 * 【关键类 / 算法】
 *   - window.getLastWindow(ctx) + getWindowAvoidArea(TYPE_SYSTEM) 取 top 高度；
 *   - 兼容写法：先 try UIContext 路径，失败再走 window 全局 API。
 * 【参考源】
 *   - HarmonyOS Window 避让区官方文档（avoidArea）；API 差异勘误记录于会话
 * ============================================================================
 */
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

export class DeviceUtil {
  // 默认 39vp（兜底）；initFromUi 后按窗口状态栏避开区域更新（API 26 无 getWindowAvoidArea，走 window 兼容路径）
  static statusBarH: number = 39;
  static bottomBarH: number = 16;
  private static loaded: boolean = false;

  static init(ctx: common.Context): void {
    if (DeviceUtil.loaded) {
      return;
    }
    DeviceUtil.loaded = true;
    window.getLastWindow(ctx).then((win: window.Window) => {
      try {
        const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        DeviceUtil.statusBarH = px2vp(area.topRect.height);
        DeviceUtil.bottomBarH = px2vp(area.bottomRect.height);
      } catch (e) {
        console.error('MoMo avoid area fail');
      }
    }).catch(() => {
      console.error('MoMo getLastWindow fail');
    });
  }

  static initFromUi(ui: UIContext): void {
    const ctx = ui.getHostContext() as common.Context;
    if (ctx !== undefined && ctx !== null) {
      DeviceUtil.init(ctx);
    }
  }
}