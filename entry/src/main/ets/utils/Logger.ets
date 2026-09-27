/*
 * ============================================================================
 * 文件名：utils/Logger.ets
 * ============================================================================
 * 【用途】统一的日志工具类，封装 hilog 接口
 * ============================================================================
 */
import hilog from '@ohos.hilog';

export class Logger {
  private static readonly DOMAIN = 0x0000; // 应用域ID

  static info(tag: string, message: string): void {
    hilog.info(Logger.DOMAIN, tag, `%{public}s`, message);
  }

  static warn(tag: string, message: string): void {
    hilog.warn(Logger.DOMAIN, tag, `%{public}s`, message);
  }

  static error(tag: string, message: string): void {
    hilog.error(Logger.DOMAIN, tag, `%{public}s`, message);
  }

  static debug(tag: string, message: string): void {
    hilog.debug(Logger.DOMAIN, tag, `%{public}s`, message);
  }
}
