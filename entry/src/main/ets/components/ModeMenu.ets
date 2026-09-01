/*
 * ============================================================================
 * 文件名：components/ModeMenu.ets
 * ============================================================================
 * 【用途】花园视图模式菜单浮层：打开时挂载的弹层，包含三枚视图切换项
 *   （花园/大纲/树）与一行说明；选中回调 onSelect(GardenMode)。
 * 【前置条件 / 假设】
 *   - 依赖：GardenMode（模型枚举）、Theme；visible 为 true 时才渲染；
 *   - 假设：小弹层置于屏幕上半部，非底部 Sheet。
 * 【输入 / 输出（后置条件）】
 *   - 输入：mode(当前模式用于高亮)、点击模式项；
 *   - 输出：onSelect(mode) 回调；样式高亮切换。
 * 【关键类 / 算法】
 *   - 3 枚 Row/Column 选项 + 图标 + 说明行；选中态用主色胶囊。
 * 【参考源】
 *   - MoMo_DOC/UI 参考图（花园模式切换）；ArkUI bindMenu 样式参考
 * ============================================================================
 */
import { GardenMode } from '../model/Models';
import { Theme } from '../utils/Theme';
import { DeviceUtil } from '../utils/DeviceUtil';

@Component
export struct ModeMenu {
  @Prop visible: boolean = false;
  @Prop mode: GardenMode = GardenMode.GARDEN;
  onSelect: (mode: GardenMode) => void = (mode: GardenMode) => {};
  private statusH: number = 38;

  aboutToAppear(): void {
    DeviceUtil.initFromUi(this.getUIContext());
    this.statusH = DeviceUtil.statusBarH;
  }

  @Builder
  menuRow(title: string, m: GardenMode) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontWeight(this.mode === m ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.mode === m ? Theme.BRAND_DEEP : Theme.PRIMARY)
        .layoutWeight(1)
      if (this.mode === m) {
        SymbolGlyph($r('sys.symbol.checkmark')).fontSize(16).fontColor([Theme.BRAND_DEEP])
      }
    }
    .width('100%')
    .height(46)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.onSelect(m);
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      if (this.visible) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0)')
          .onClick(() => {
            this.onSelect(this.mode);
          })

        Column() {
          this.menuRow('花园模式', GardenMode.GARDEN)
          Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 16, right: 16 })
          this.menuRow('大纲模式', GardenMode.OUTLINE)
          Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 16, right: 16 })
          this.menuRow('记忆树', GardenMode.TREE)
        }
        .width(172)
        .borderRadius(18)
        .backgroundColor('rgba(252,254,251,0.97)')
        .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
        .border({ width: 1, color: 'rgba(255,255,255,0.85)' })
        .shadow({ radius: 26, color: 'rgba(26,48,32,0.18)', offsetY: 6 })
        .padding({ top: 6, bottom: 6 })
        .margin({ top: this.statusH + 62, right: 14 })
        .transition(TransitionEffect.opacity(0).combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
          .animation({ duration: 180, curve: Curve.EaseOut }))
      }
    }
    .width('100%')
    .height('100%')
  }
}