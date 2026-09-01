/*
 * ============================================================================
 * 文件名：components/AppTitleBar.ets
 * ============================================================================
 * 【用途】自绘沉浸式标题栏（备用组件）：返回键 + 大字标题 + 右上活动区（菜单/其他），
 *   支持滚动模糊玻璃效果。当前各页面已改用 HDS 系统标题栏，本组件保留备用。
 * 【前置条件 / 假设】
 *   - 依赖：DeviceUtil（状态栏高度）、Theme；生命周期内调用 DeviceUtil.initFromUi；
 *   - 假设：作为页面顶部第一层（Stack 顶层）使用。
 * 【输入 / 输出（后置条件）】
 *   - 输入：title、showBack、blurred、onBack、extra 区域；
 *   - 输出：标题栏渲染；返回/菜单回调。
 * 【关键类 / 算法】
 *   - 双语（中文/英文短标签）Title；模糊层 opacity 由 blurred 控制。
 * 【参考源】
 *   - 原轮次自定义实现；对照 HDS HdsNavigationTitleBar（后续替换）
 * ============================================================================
 */
import { Theme } from '../utils/Theme';
import { DeviceUtil } from '../utils/DeviceUtil';

@Component
export struct AppTitleBar {
  @Prop title: string = '';
  @Prop showBack: boolean = false;
  @Prop isBlurred: boolean = false;
  @Prop showSearch: boolean = false;
  @Prop leftExtraShow: boolean = false;
  @Prop menus: Resource[] = [];
  onBack: () => void = () => {};
  onMenu: () => void = () => {};
  onSearch: () => void = () => {};
  @BuilderParam leftExtra: () => void = this.emptyExtra;

  private statusH: number = 38;

  @Builder
  emptyExtra() {
    Row() {
    }
  }

  aboutToAppear(): void {
    DeviceUtil.initFromUi(this.getUIContext());
    this.statusH = DeviceUtil.statusBarH;
  }

  build() {
    Column() {
      Stack() {
        // blur layer
        Column()
          .width('100%')
          .height('100%')
          .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
          .backgroundColor('rgba(250,252,249,0.35)')
          .opacity(this.isBlurred ? 0.94 : 0)
          .animation({ duration: 220, curve: Curve.EaseOut })
        // content
        Row() {
          if (this.showBack) {
            Stack() {
              Column().width(38).height(38).borderRadius(999).backgroundColor('rgba(255,255,255,0.9)')
                .shadow({ radius: 8, color: 'rgba(40,60,46,0.10)', offsetY: 2 })
              SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(20).fontColor([Theme.PRIMARY])
            }
            .onClick(() => {
              this.onBack();
            })
            .margin({ left: 12 })
          } else {
            if (this.leftExtraShow) {
              this.leftExtra();
            } else {
              Blank().width(12)
            }
          }
          Text(this.title)
            .fontSize(Theme.FONT_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.PRIMARY)
            .margin({ left: 16 })
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.showSearch) {
            Column() {
              Stack() {
                Column().width(38).height(38).borderRadius(999).backgroundColor('rgba(255,255,255,0.9)')
                  .shadow({ radius: 8, color: 'rgba(40,60,46,0.10)', offsetY: 2 })
                SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(19).fontColor([Theme.PRIMARY])
              }
            }
            .width(38)
            .height(38)
            .onClick(() => {
              this.onSearch();
            })
            .margin({ right: 10 })
          }
          if (this.menus.length > 0) {
            Stack() {
              Column().width(38).height(38).borderRadius(999).backgroundColor('rgba(255,255,255,0.9)')
                .shadow({ radius: 8, color: 'rgba(40,60,46,0.10)', offsetY: 2 })
              SymbolGlyph(this.menus[0]).fontSize(19).fontColor([Theme.PRIMARY])
            }
            .onClick(() => {
              this.onMenu();
            })
            .margin({ right: 12 })
          } else {
            Blank().width(12)
          }
        }
        .width('100%')
        .height(56)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(this.statusH + 56)
    }
    .width('100%')
  }
}