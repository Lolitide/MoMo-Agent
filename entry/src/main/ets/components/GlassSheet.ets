/*
 * ============================================================================
 * 文件名：components/GlassSheet.ets
 * ============================================================================
 * 【用途】玻璃质感底部浮窗容器：全屏半透明遮罩 + 底部圆角面板（模糊+描边+阴影），
 *   内部以 @BuilderParam content 承载业务内容；遮罩点击/关闭回调 onDismiss。
 * 【前置条件 / 假设】
 *   - 依赖：DeviceUtil（状态栏高度，用于全屏避让）；Theme（玻璃色板）；
 *   - 用法：调用方以 if(show) 挂载时显示（挂载即显示，卸载即关闭，禁用过渡动画避免拦截手势）；
 *   - 假设：show 为 true 时才渲染；仅一个内容 Builder。
 * 【输入 / 输出（后置条件）】
 *   - 输入：show、heightRatio(占屏比例)、content、onDismiss；
 *   - 输出：遮罩点击 -> onDismiss()；浮窗内容由调用方渲染。
 * 【关键类 / 算法】
 *   - 玻璃效果 = backgroundBlurStyle(COMPONENT_ULTRA_THICK) + 半透明底 + 白描边 + 大半径阴影；
 *   - 全屏遮罩仅“遮罩层”参与点击（子内容照常）。
 * 【参考源】
 *   - iBest-UI 液态玻璃（GlassMaterial）设计语言；ArkUI backgroundBlurStyle 文档
 * ============================================================================
 */
import { Theme } from '../utils/Theme';

@Component
// 玻璃底部浮窗：全屏遮罩点击 -> onDismiss；面板用组件级模糊+描边+阴影还原“液态玻璃”
export struct GlassSheet {
  @Prop show: boolean = false;
  @Prop heightRatio: number = 0.72;
  onDismiss: () => void = () => {};
  @BuilderParam content: () => void = this.emptyContent;
  @BuilderParam footer: () => void = this.emptyContent;

  @Builder
  emptyContent() {
    Column() {
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.show) {
        // 点击空白区域关闭
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0)')
          .onClick(() => {
            this.onDismiss();
          })

        // 底部浮窗
        Column() {
          // 拖动把手
          Column() {
            Row().width(44).height(5).borderRadius(3).backgroundColor('#C8D6CC')
          }
          .width('100%')
          .height(26)
          .justifyContent(FlexAlign.Center)

          // 内容区域
          Column() {
            this.content()
            this.footer()
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 22, right: 22, top: 2 })
        }
        .width('100%')
        .height(this.heightRatio * 100 + '%')
        .borderRadius({ topLeft: 30, topRight: 30 })
        .backgroundColor(Theme.GLASS)
        .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
        .border({ width: 1, color: 'rgba(255,255,255,0.7)' })
        .shadow({ radius: 40, color: 'rgba(26,48,32,0.25)', offsetY: -6 })
        .clip(true)
        .gesture(
          PanGesture({ direction: PanDirection.Vertical, distance: 6 })
            .onActionUpdate((event: GestureEvent) => {
              if (event.offsetY > 0) {
                this.onDismiss();
              }
            })
        )
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0)')
  }
}