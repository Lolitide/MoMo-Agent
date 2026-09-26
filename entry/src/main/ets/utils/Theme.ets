/*
 * ============================================================================
 * 文件名：utils/Theme.ets
 * ============================================================================
 * 【用途】全局设计令牌（Design Token）：配色、圆角、字体变量 + Metrics 尺寸常量。
 *   所有页面/组件统一引用，保证“品牌绿 #97FFAB / 玻璃白 / 深绿文字”一致。
 * 【前置条件 / 假设】
 *   - 纯常量类：无状态；resourceId 由 @ohos 资源管理；
 *   - 假设：应用使用固定浅色正式主题。
 * 【输入 / 输出（后置条件）】
 *   - 无输入；输出为静态常量（编译期确定）。
 * 【关键类 / 算法】
 *   - Theme（颜色/圆角/阴影）、Metrics（页边距/卡圆角/浮窗圆角/分段间距）。
 * 【参考源】
 *   - MoMo_DOC 设计稿（配色）；iBest-UI 液态玻璃色板；
 *   - 废案 common/Theme.ets（TEXT_MAIN/SHEET_BG 等来源）
 * ============================================================================
 */
export class Theme {
  static BG: string = '#F7FAF4';
  static BG_DEEP: string = '#F0F6EC';
  static CARD: string = '#FFFFFF';
  static CARD_SOFT: string = '#FDFEFB';
  static PRIMARY: string = '#1E2A22';
  static SECONDARY: string = '#5F6F63';
  static TERTIARY: string = '#93A396';
  static DISABLED: string = '#C7D2C9';
  static BRAND: string = '#97FFAB';
  static BRAND_DEEP: string = '#62D97F';
  static BRAND_BG: string = '#ECFBEF';
  static ACCENT_ORANGE: string = '#F6B26B';
  static ACCENT_GREEN: string = '#8FE39B';
  static DANGER: string = '#E5533D';
  static LINE: string = '#E9EFE9';
  static GLASS: string = '#F5FAF4';
  static BLUR_GLASS: string = 'rgba(250,252,248,0.92)';
  static SHADOW: string = 'rgba(38,61,42,0.14)';
  static TEXT_MAIN: string = '#191A17';
  static TEXT_SUB: string = '#5B5C57';
  static TEXT_TERTIARY: string = '#9A9B94';
  static CARD_BORDER: string = '#E9E8E3';
  static SHEET_BG: string = '#F2FFF4';
  static WARM: string = '#F5C97B';
  static WARM_BG: string = '#FFF3DF';
  static BLUR_MASK: string = '#CCFFFFFF';

  static readonly RADIUS_CARD: number = 24;
  static readonly RADIUS_SM: number = 14;
  static readonly RADIUS_PILL: number = 999;
  static FONT_TITLE: number = 30;
  static FONT_H1: number = 22;
  static FONT_H2: number = 17;
  static FONT_BODY: number = 15;
  static FONT_SM: number = 13;
  static FONT_XS: number = 11;

  static fontSize(base: number): number {
    return base;
  }
}

export class Metrics {
  static readonly PAGE_PADDING: number = 20;
  static readonly CARD_RADIUS: number = 24;
  static readonly SHEET_RADIUS: number = 32;
  static readonly SECTION_GAP: number = 18;
}
