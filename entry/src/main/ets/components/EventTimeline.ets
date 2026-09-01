/*
 * ============================================================================
 * 文件名：components/EventTimeline.ets
 * ============================================================================
 * 【用途】事件时间线组件：垂直时间轴，每个事件 = 图标胶囊（心情/文档/音乐等）
 *   + 时间标签 + 标题 + 分类标签（生活/工作/兴趣），用于“今日事件”区块。
 * 【前置条件 / 假设】
 *   - 依赖：EventItem（模型）、MemoryTypeUtil（图标/分类映射）、Theme；
 *   - 假设：期望在可滚动容器内使用（高度由父级控制）。
 * 【输入 / 输出（后置条件）】
 *   - 输入：events 列表；
 *   - 输出：渲染时间轴；无业务副作用。
 * 【关键类 / 算法】
 *   - ForEach 线性列表 + 左侧虚线/实线连接（Canvas-free，用 Row/Divider 样式模拟）。
 * 【参考源】
 *   - iBest-UI 时间线样式；Examples/ArkUISample List 示例
 * ============================================================================
 */
import { EventItem } from '../model/Models';
import { Theme } from '../utils/Theme';

interface CatIcon {
  id: string;
  icon: Resource;
}

@Component
export struct EventTimeline {
  @Prop events: EventItem[] = [];

  private catIcons: CatIcon[] = [
    { id: 'work', icon: $r('sys.symbol.doc_text') },
    { id: 'life', icon: $r('sys.symbol.heart') },
    { id: 'interest', icon: $r('sys.symbol.music') }
  ];

  private iconOf(cat: string): Resource {
    for (let i = 0; i < this.catIcons.length; i++) {
      if (this.catIcons[i].id === cat) {
        return this.catIcons[i].icon;
      }
    }
    return $r('sys.symbol.clock');
  }

  build() {
    Column() {
      ForEach(this.events, (ev: EventItem, index: number) => {
        Row() {
          Column() {
            // line upper
            Row().width(2).height(16).backgroundColor('#D6E6DA')
            // dot
            Stack() {
              Column().width(36).height(36).borderRadius(999).backgroundColor('#FFFFFF')
                .shadow({ radius: 6, color: 'rgba(71,110,80,0.12)', offsetY: 1 })
              SymbolGlyph(this.iconOf(ev.category)).fontSize(16).fontColor(['#4C9A62'])
            }
            // line lower
            Row().width(2).height(16)
              .backgroundColor(index === this.events.length - 1 ? 'rgba(0,0,0,0)' : '#D6E6DA')
          }
          .width(52)
          .alignItems(HorizontalAlign.Center)

          Column({ space: 3 }) {
            Row() {
              Text(ev.time).fontSize(11).fontColor(Theme.TERTIARY)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .backgroundColor('#F0F7F1')
                .borderRadius(8)
              Blank()
              Text(ev.category === 'work' ? '工作' : (ev.category === 'interest' ? '兴趣' : '生活'))
                .fontSize(10).fontColor(Theme.TERTIARY)
            }
            .width('100%')
            Text(ev.title)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.PRIMARY)
              .width('100%')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(ev.description)
              .fontSize(12)
              .fontColor(Theme.SECONDARY)
              .width('100%')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .border({ width: 1, color: Theme.LINE })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .margin({ bottom: 4 })
      }, (ev: EventItem) => ev.id)
    }
    .width('100%')
  }
}