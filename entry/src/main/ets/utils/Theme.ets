/*
 * ============================================================================
 * 文件名：utils/Theme.ets
 * ============================================================================
 * 【用途】全局设计令牌（Design Token）：配色、圆角、字体变量 + Metrics 尺寸常量。
 *   所有页面/组件统一引用，保证“品牌绿 #97FFAB / 玻璃白 / 深绿文字”一致。
 * 【前置条件 / 假设】
 *   - 纯常量类：无状态；resourceId 由 @ohos 资源管理；
 *   - 假设：浅色主题为主，深色模式仅 UI 开关（Mock）。
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
  static readonly BG: string = '#F7FAF4';
  static readonly BG_DEEP: string = '#F0F6EC';
  static readonly CARD: string = '#FFFFFF';
  static readonly CARD_SOFT: string = '#FDFEFB';
  static readonly PRIMARY: string = '#1E2A22';
  static readonly SECONDARY: string = '#5F6F63';
  static readonly TERTIARY: string = '#93A396';
  static readonly DISABLED: string = '#C7D2C9';
  static readonly BRAND: string = '#97FFAB';
  static readonly BRAND_DEEP: string = '#62D97F';
  static readonly BRAND_BG: string = '#ECFBEF';
  static readonly ACCENT_ORANGE: string = '#F6B26B';
  static readonly ACCENT_GREEN: string = '#8FE39B';
  static readonly DANGER: string = '#E5533D';
  static readonly LINE: string = '#E9EFE9';
  static readonly GLASS: string = '#F5FAF4';
  static readonly BLUR_GLASS: string = 'rgba(250,252,248,0.92)';
  static readonly SHADOW: string = 'rgba(38,61,42,0.14)';
  static readonly TEXT_MAIN: string = '#191A17';
  static readonly TEXT_SUB: string = '#5B5C57';
  static readonly TEXT_TERTIARY: string = '#9A9B94';
  static readonly CARD_BORDER: string = '#E9E8E3';
  static readonly SHEET_BG: string = '#F2FFF4';
  static readonly WARM: string = '#F5C97B';
  static readonly WARM_BG: string = '#FFF3DF';
  static readonly BLUR_MASK: string = '#CCFFFFFF';

  static readonly RADIUS_CARD: number = 24;
  static readonly RADIUS_SM: number = 14;
  static readonly RADIUS_PILL: number = 999;
  static readonly FONT_TITLE: number = 30;
  static readonly FONT_H1: number = 22;
  static readonly FONT_H2: number = 17;
  static readonly FONT_BODY: number = 15;
  static readonly FONT_SM: number = 13;
  static readonly FONT_XS: number = 11;
}

export class Metrics {
  static readonly PAGE_PADDING: number = 20;
  static readonly CARD_RADIUS: number = 24;
  static readonly SHEET_RADIUS: number = 32;
  static readonly SECTION_GAP: number = 18;
}