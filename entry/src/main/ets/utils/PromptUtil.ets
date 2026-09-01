/*
 * ============================================================================
 * 文件名：utils/PromptUtil.ets
 * ============================================================================
 * 【用途】Prompt 工具单例：封装 Toast（提示气泡）统一入口。
 * 【前置条件 / 假设】
 *   - 假设：应用为单窗口；Toast 文案不宜过长（<= 2 行）；
 *   - 依赖：@kit.ArkUI (promptAction)。
 * 【输入 / 输出（后置条件）】
 *   - 输入：message、可选 duration；
 *   - 输出：系统 Toast 弹出；无返回值。
 * 【关键类 / 算法】
 *   - 静态方法透传 promptAction.showToast（同步等待窗口上下文）。
 * 【参考源】
 *   - HarmonyOS promptAction 官方文档
 * ============================================================================
 */
import { promptAction } from '@kit.ArkUI';

export class PromptUtil {
  static toast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 1800 });
  }
}