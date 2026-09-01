/*
 * ============================================================================
 * 文件名：components/MoMoCard.ets
 * ============================================================================
 * 【用途】通用卡片容器组件：圆角/内边距/背景可配，@BuilderParam content 承载内容，
 *   用于首页卡片与二级页信息卡（今日总结/默默寄语等）。
 * 【前置条件 / 假设】
 *   - 依赖：Theme（默认 CARD 背景与圆角）；radius/innerPadding/bgColor 可选覆盖；
 *   - 假设：作为纯容器，不处理点击（点击由调用方在容器外层加 onClick）。
 * 【输入 / 输出（后置条件）】
 *   - 输入：内容 Builder + 样式参数；
 *   - 输出：渲染一张卡片（无副作用）。
 * 【关键类 / 算法】
 *   - 简单 Column 容器 + border/padding 组合。
 * 【参考源】
 *   - MoMo_DOC/UI 参考图（卡片网格）
 * ============================================================================
 */
import { Theme } from '../utils/Theme';

@Component
export struct MoMoCard {
  @Prop radius: number = 24;
  @Prop innerPadding: number = 16;
  @Prop bgColor: ResourceColor = Theme.CARD;
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
    Column() {
    }
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .borderRadius(this.radius)
    .backgroundColor(this.bgColor)
    .border({ width: 1, color: Theme.CARD_BORDER })
    .padding(this.innerPadding)
  }
}