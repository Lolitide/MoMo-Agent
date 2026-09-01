/*
 * ============================================================================
 * 文件名：components/ImmersiveTitleBar.ets
 * ============================================================================
 * 【用途】自绘沉浸式子页标题栏（当前子页实际使用）：状态栏高度 + 58vp 栏，
 *   返回圆钮 + 大字标题 + 右上“···”圆钮（bindMenu 系统弹出菜单），
 *   isBlurred 控制毛玻璃背景（滚动模糊）。
 * 【前置条件 / 假设】
 *   - 依赖：DeviceUtil（initFromUi 取状态栏高度）、Theme；
 *   - 假设：作为页面 Stack 顶层覆盖在 Scroll 之上，内容顶部需留 132vp。
 * 【输入 / 输出（后置条件）】
 *   - 输入：title/showBack/isBlurred/menus(ImmersionMenu[]{value,action})/onBack；
 *   - 输出：渲染标题栏；返回/菜单回调。
 * 【关键类 / 算法】
 *   - 模糊层：backgroundBlurStyle(COMPONENT_ULTRA_THICK)+半透明底，opacity 随 isBlurred 变化
 *     并配 220ms 动画；菜单用系统 bindMenu（无自定义弹层，点击更稳）。
 * 【参考源】
 *   - 废案 BasePage menuBuilder；arkts bindMenu 文档
 * ============================================================================
 */
import { DeviceUtil } from '../utils/DeviceUtil';
import { Theme } from '../utils/Theme';

export interface ImmersionMenu {
  value: string;
  action: () => void;
}

@Component
export struct ImmersiveTitleBar {
  @Prop title: string = '';
  @Prop showBack: boolean = true;
  @Prop isBlurred: boolean = false;
  @Prop menus: ImmersionMenu[] = [];
  onBack: () => void = () => {};
  private statusH: number = 39;

  aboutToAppear(): void {
    DeviceUtil.initFromUi(this.getUIContext());
    this.statusH = DeviceUtil.statusBarH;
  }

  build() {
    Column() {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
          .backgroundColor('rgba(250,252,249,0.35)')
          .opacity(this.isBlurred ? 0.94 : 0)
          .animation({ duration: 220, curve: Curve.EaseOut })

        Row() {
          if (this.showBack) {
            Column() {
              Stack() {
                SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(20).fontColor([Theme.TEXT_MAIN])
              }
            }
            .width(40)
            .height(40)
            .borderRadius(20)
            .backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.CARD_BORDER })
            .onClick(() => {
              this.onBack();
            })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          } else {
            Blank()
          }

          Text(this.title)
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_MAIN)
            .margin({ left: 14 })
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.menus.length > 0) {
            Column() {
              Stack() {
                SymbolGlyph($r('sys.symbol.ellipsis_circle')).fontSize(18).fontColor([Theme.TEXT_MAIN])
              }
            }
            .width(40)
            .height(40)
            .borderRadius(20)
            .backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.CARD_BORDER })
            .bindMenu(this.menus)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          } else {
            Blank()
          }
        }
        .width('100%')
        .height(58)
        .padding({ left: 18, right: 18 })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(this.statusH + 58)
    }
    .width('100%')
  }
}