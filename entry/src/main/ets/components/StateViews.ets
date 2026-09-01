/*
 * ============================================================================
 * 文件名：components/StateViews.ets
 * ============================================================================
 * 【用途】页面状态占位组件集：LoadingState（加载中（默默+文案））、
 *   EmptyState（空态+图标+可选副文案）、ErrorState（错误+重试按钮 onRetry）。
 * 【前置条件 / 假设】
 *   - 依赖：MoMoAvatar、Theme、MoMoState；由页面按 PageState 分支渲染；
 *   - 假设：占满父容器居中展示。
 * 【输入 / 输出（后置条件）】
 *   - 输入：text/icon/onRetry 等；
 *   - 输出：渲染占位视图；点击重试 -> onRetry。
 * 【关键类 / 算法】
 *   - 三占位组件均以 Column 垂直居中 + 呼吸淡入动画（Loading）。
 * 【参考源】
 *   - 通用 UX 空态/错误态设计；ArkUI Blank/button 示例
 * ============================================================================
 */
import { Theme } from '../utils/Theme';

@Component
export struct LoadingState {
  @Prop text: string = '默默正在整理……';

  build() {
    Column({ space: 12 }) {
      LoadingProgress().width(40).height(40).color(Theme.BRAND_DEEP)
      Text(this.text).fontSize(Theme.FONT_BODY).fontColor(Theme.SECONDARY)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.BG)
  }
}

@Component
export struct EmptyState {
  @Prop text: string = '这里还没有内容';
  @Prop icon: Resource = $r('sys.symbol.leaf');

  build() {
    Column({ space: 12 }) {
      Stack() {
        Column().width(84).height(84).borderRadius(999).backgroundColor(Theme.BRAND_BG)
        SymbolGlyph(this.icon).fontSize(38).fontColor([Theme.BRAND_DEEP])
      }
      Text(this.text).fontSize(Theme.FONT_BODY).fontColor(Theme.SECONDARY)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ bottom: 60 })
    .backgroundColor(Theme.BG)
  }
}

@Component
export struct ErrorState {
  @Prop text: string = '默默好像走神了，稍后再试';
  onRetry: () => void = () => {};

  build() {
    Column({ space: 14 }) {
      Stack() {
        Column().width(84).height(84).borderRadius(999).backgroundColor('#FDECEC')
        SymbolGlyph($r('sys.symbol.xmark_circle')).fontSize(36).fontColor([Theme.DANGER])
      }
      Text(this.text).fontSize(Theme.FONT_BODY).fontColor(Theme.SECONDARY)
      Button('重新加载')
        .fontSize(Theme.FONT_SM)
        .fontColor('#FFFFFF')
        .backgroundColor(Theme.BRAND_DEEP)
        .height(36)
        .borderRadius(18)
        .padding({ left: 18, right: 18 })
        .onClick(() => {
          this.onRetry();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ bottom: 60 })
    .backgroundColor(Theme.BG)
  }
}