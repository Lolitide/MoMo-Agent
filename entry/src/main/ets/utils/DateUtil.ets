/*
 * ============================================================================
 * 文件名：utils/DateUtil.ets
 * ============================================================================
 * 【用途】日期工具集合：问候语、日期键/格式、星期/天数/偏移、日历单元格生成。
 * 【前置条件 / 假设】
 *   - 纯函数：无状态、无 IO；输入 Date/number，输出 string/number；
 *   - 假设：dayOfMonth/weekday 用于底部日期圆钮；dateKey 形如 "2026-11-28"。
 * 【输入 / 输出（后置条件）】
 *   - 输入：Date、月/年、小时数等；输出：问候语/补零字符串/数字数组；
 *   - 后置：调用方不再修改 Date 参数（只读取）。
 * 【关键类 / 算法】
 *   - greeting(hour)：分段问候（早安/午安/下午好/晚上好）；
 *   - pad：补零；firstWeekday/daysInMonth：日历网格计算。
 * 【参考源】
 *   - 废案 common/DateUtil.ets；ArkTS Date 标准库文档
 * ============================================================================
 */
export class DateUtil {
  static pad(n: number): string {
    return n < 10 ? '0' + n.toString() : n.toString();
  }

  static formatDot(d: Date): string {
    return d.getFullYear().toString() + '.' + DateUtil.pad(d.getMonth() + 1) + '.' + DateUtil.pad(d.getDate());
  }

  static formatSlash(d: Date): string {
    return d.getFullYear().toString() + '/' + DateUtil.pad(d.getMonth() + 1) + '/' + DateUtil.pad(d.getDate());
  }

  static dayOfMonth(d: Date): number {
    return d.getDate();
  }

  static weekday(d: Date): string {
    const names: string[] = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    return names[d.getDay()];
  }

  static dateKey(d: Date): string {
    return d.getFullYear().toString() + '-' + DateUtil.pad(d.getMonth() + 1) + '-' + DateUtil.pad(d.getDate());
  }

  static sameDay(a: Date, b: Date): boolean {
    return DateUtil.dateKey(a) === DateUtil.dateKey(b);
  }

  static greeting(hour: number): string {
    if (hour >= 5 && hour < 11) {
      return '早上好';
    } else if (hour >= 11 && hour < 14) {
      return '中午好';
    } else if (hour >= 14 && hour < 18) {
      return '下午好';
    }
    return '晚上好';
  }

  static daysInMonth(year: number, month: number): number {
    return new Date(year, month + 1, 0).getDate();
  }

  static firstWeekday(year: number, month: number): number {
    return new Date(year, month, 1).getDay();
  }
}