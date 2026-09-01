/*
 * ============================================================================
 * 文件名：components/DayBottomBar.ets
 * ============================================================================
 * 【用途】二级页固定底部操作栏（今日状态/今日漫画共用）：渐变分隔线 +
 *   纠正（描边药丸）/日期圆钮（日+星期）/反馈（★药丸），带玻璃模糊背景。
 * 【前置条件 / 假设】
 *   - 依赖：Theme、DateUtil；Date 可选（默认今天）；
 *   - 假设：始终吸附页面底部（父容器 zIndex 置顶）。
 * 【输入 / 输出（后置条件）】
 *   - 输入：点击纠正/日期/反馈；
 *   - 输出：onCorrect()/onDate()/onFeedback() 回调。
 * 【关键类 / 算法】
 *   - 底部渐变线：横向 linearGradient 两端透明；背景 blurMask + backdropBlur(20)。
 * 【参考源】
 *   - ibest-ui 底部栏样式；MoMo_DOC/UI 参考图（二级页底部栏）
 * ============================================================================
 */
import { Theme } from '../utils/Theme';
import { DateUtil } from '../utils/DateUtil';

@Component
export struct DayBottomBar {
  @Prop date: Date = new Date();
  onCorrect: () => void = () => {};
  onFeedback: () => void = () => {};
  onDate: () => void = () => {};

  build() {
    Column() {
      Row()
        .width('100%')
        .height(1)
        .linearGradient({
          angle: 90,
          colors: [['#00E9E8E3', 0], ['#E9E8E3', 0.5], ['#00E9E8E3', 1]]
        })
      Row() {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.pencil_line'))
            .fontSize(16)
            .fontColor([Theme.TEXT_MAIN])
          Text('纠正')
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 18, right: 18, top: 12, bottom: 12 })
        .borderRadius(26)
        .backgroundColor(Theme.CARD)
        .border({ width: 1.5, color: Theme.TEXT_MAIN })
        .onClick(() => {
          this.onCorrect();
        })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })

        Column() {
          Text(DateUtil.dayOfMonth(this.date).toString())
            .fontSize(18)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
          Text(DateUtil.weekday(this.date))
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .width(54)
        .height(54)
        .borderRadius(27)
        .backgroundColor(Theme.CARD)
        .border({ width: 1.5, color: Theme.CARD_BORDER })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          this.onDate();
        })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })

        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.star_fill'))
            .fontSize(16)
            .fontColor([Theme.WARM])
          Text('反馈')
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 18, right: 18, top: 12, bottom: 12 })
        .borderRadius(26)
        .backgroundColor(Theme.CARD)
        .border({ width: 1.5, color: Theme.TEXT_MAIN })
        .onClick(() => {
          this.onFeedback();
        })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 12, bottom: 20 })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .backgroundColor(Theme.BLUR_MASK)
    .backdropBlur(20)
    .zIndex(10)
  }
}