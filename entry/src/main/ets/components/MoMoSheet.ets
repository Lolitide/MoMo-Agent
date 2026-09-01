/*
 * ============================================================================
 * 文件名：components/MoMoSheet.ets
 * ============================================================================
 * 【用途】底部浮窗内容容器（配合 bindSheet 使用）：大标题+副标题+内容 Builder，
 *   顶部左右圆角 32 + 页面底色。与 GlassSheet 的区别：本组件不含遮罩/挂载逻辑，
 *   直接作为 bindSheet 的内容。
 * 【前置条件 / 假设】
 *   - 依赖：Theme；由调用方通过 .bindSheet(...) 提供系统拖拽条与动画；
 *   - 假设：内容高度自适应；用于编辑/确认类浮窗。
 * 【输入 / 输出（后置条件）】
 *   - 输入：title/subtitle/content、onClose；
 *   - 输出：渲染内容；onClose 由调用方（关闭按钮）触发。
 * 【关键类 / 算法】
 *   - 顶部 32 圆角 + SHEET_BG 底 + padding(20/28) 排版。
 * 【参考源】
 *   - 废案 E:\Program_File\HMOS_proj\MoMo components/MoMoSheet.ets
 * ============================================================================
 */
import { Theme } from '../utils/Theme';

@Component
export struct MoMoSheet {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  onClose: () => void = () => {};
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
    Column() {
    }
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 6 }) {
          Text(this.title)
            .fontSize(24)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
          if (this.subtitle.length > 0) {
            Text(this.subtitle)
              .fontSize(14)
              .fontColor(Theme.TEXT_SUB)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      this.content()
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 10, bottom: 28 })
    .backgroundColor(Theme.SHEET_BG)
    .borderRadius({ topLeft: 32, topRight: 32 })
  }
}