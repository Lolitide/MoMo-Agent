/*
 * ============================================================================
 * 文件名：components/DotMenu.ets
 * ============================================================================
 * 【用途】“···”悬浮菜单弹层（通用）：一个锚点按钮 + 打开时挂载的菜单面板，
 *   含若干 item（图标+文字+onTap）；当前页面集成改为 HDS 系统菜单后，
 *   本组件保留为备用样式（未被页面引用）。
 * 【前置条件 / 假设】
 *   - 依赖：Theme、DeviceUtil（顶部安全区）；visible 才渲染；
 *   - 假设：单列竖排菜单，最多 5 项。
 * 【输入 / 输出（后置条件）】
 *   - 输入：visible、items、点击条目；
 *   - 输出：onSelect(index) 回调；点击遮罩关闭。
 * 【关键类 / 算法】
 *   - 遮罩(半透明) + 锚点定位的 Column 面板；条目为 ForEach 渲染。
 * 【参考源】
 *   - ArkUI bindMenu / Menu 组件文档（替代方案）
 * ============================================================================
 */
import { Theme } from '../utils/Theme';
import { DeviceUtil } from '../utils/DeviceUtil';

export interface MenuItemModel {
  id: string;
  label: string;
  icon?: Resource;
}

@Component
export struct DotMenu {
  @Prop visible: boolean = false;
  @Prop items: MenuItemModel[] = [];
  onSelect: (id: string) => void = (id: string) => {};
  onClose: () => void = () => {};
  private statusH: number = 38;

  aboutToAppear(): void {
    DeviceUtil.initFromUi(this.getUIContext());
    this.statusH = DeviceUtil.statusBarH;
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      if (this.visible) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0)')
          .onClick(() => {
            this.onClose();
          })

        Column({ space: 2 }) {
          ForEach(this.items, (item: MenuItemModel) => {
            Row({ space: 10 }) {
              if (item.icon !== undefined) {
                SymbolGlyph(item.icon).fontSize(17).fontColor([Theme.SECONDARY])
              }
              Text(item.label)
                .fontSize(14)
                .fontColor(Theme.PRIMARY)
                .layoutWeight(1)
            }
            .width('100%')
            .height(44)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              this.onSelect(item.id);
            })
          }, (item: MenuItemModel) => item.id)
        }
        .width(186)
        .borderRadius(18)
        .backgroundColor('rgba(252,254,251,0.97)')
        .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
        .border({ width: 1, color: 'rgba(255,255,255,0.85)' })
        .shadow({ radius: 26, color: 'rgba(26,48,32,0.18)', offsetY: 6 })
        .padding({ top: 8, bottom: 8 })
        .margin({ top: this.statusH + 62, right: 14 })
        .transition(TransitionEffect.opacity(0).combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
          .animation({ duration: 180, curve: Curve.EaseOut }))
      }
    }
    .width('100%')
    .height('100%')
  }
}