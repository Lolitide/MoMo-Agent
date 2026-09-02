import { HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { AppRouter, RouteName } from '../router/AppRouter';
import { GardenController } from '../service/Services';
import { MemoryRepository } from '../repository/Repositories';
import { Memory, MemoryTypeUtil } from '../model/Models';
import { Theme } from '../utils/Theme';

const FILTERS: string[] = ['全局', '标题', '摘要', '标签', '日期'];
const EMPTY_HINT: string = '啊嘞？默默不记得有这个…';

@Component
export struct B_Search {
  @State keyword: string = '';
  @State filterIdx: number = 0;

  /** 结果集：未输入时按时间倒序列出全部；输入后按当前筛选方式实时匹配 */
  private results(): Memory[] {
    const all = MemoryRepository.get().getAll();
    const arr: Memory[] = [];
    for (let i = 0; i < all.length; i++) {
      if (this.match(all[i], this.keyword)) {
        arr.push(all[i]);
      }
    }
    arr.sort((a: Memory, b: Memory) => {
      return b.date.localeCompare(a.date);
    });
    return arr;
  }

  private match(m: Memory, kw: string): boolean {
    if (kw.trim() === '') {
      return true;
    }
    const k = kw.trim().toLowerCase();
    const title = m.title.toLowerCase();
    const summary = m.summary.toLowerCase();
    const tags = m.tags.join('，').toLowerCase();
    if (this.filterIdx === 1) {
      return title.includes(k);
    }
    if (this.filterIdx === 2) {
      return summary.includes(k);
    }
    if (this.filterIdx === 3) {
      return tags.includes(k);
    }
    if (this.filterIdx === 4) {
      return m.date.includes(kw.trim());
    }
    // 全局：标题 + 摘要 + 标签
    return title.includes(k) || summary.includes(k) || tags.includes(k);
  }

  private openItem(m: Memory): void {
    // 记录待聚焦记忆，返回花园后由 A_Garden 消费并展开对应模式下的详情
    GardenController.pendingFocusId = m.id;
    AppRouter.back();
  }

  @Builder
  resultItem(m: Memory) {
    Row({ space: 10 }) {
      Column({ space: 4 }) {
        Text(m.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(m.date + ' · ' + MemoryTypeUtil.nameOf(m.type))
          .fontSize(11)
          .fontColor(Theme.TERTIARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([Theme.TERTIARY])
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .borderRadius(14)
    .backgroundColor(Theme.CARD)
    .border({ width: 1, color: Theme.LINE })
    .margin({ bottom: 8 })
    .onClick(() => {
      this.openItem(m);
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        Column() {
          // 搜索框 + 右侧“筛选”按钮（同一行，筛选按钮位于框外最右）
          Row({ space: 10 }) {
            TextInput({
              placeholder: '翻翻我的记忆本…',
              text: this.keyword
            })
              .fontSize(15)
              .height(46)
              .borderRadius(23)
              .backgroundColor('#FFFFFF')
              .padding({ left: 18, right: 18 })
              .layoutWeight(1)
              .border({ width: 1, color: Theme.LINE })
              .onChange((v: string) => {
                this.keyword = v;
              })

            Column() {
              Row({ space: 5 }) {
                SymbolGlyph($r('sys.symbol.arrow_down_right_and_arrow_up_left')).fontSize(14)
                  .fontColor([this.filterIdx === 0 ? '#3E6B4B' : '#FFFFFF'])
                Text(FILTERS[this.filterIdx])
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.filterIdx === 0 ? '#3E6B4B' : '#FFFFFF')
              }
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
            }
            .height(46)
            .padding({ left: 16, right: 16 })
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .borderRadius(23)
            .backgroundColor(this.filterIdx === 0 ? '#EFF5F0' : '#3E6B4B')
            .border({ width: 1, color: this.filterIdx === 0 ? Theme.LINE : '#3E6B4B' })
            .bindMenu([
              { value: '全局', action: (): void => { this.filterIdx = 0; } },
              { value: '标题', action: (): void => { this.filterIdx = 1; } },
              { value: '摘要', action: (): void => { this.filterIdx = 2; } },
              { value: '标签', action: (): void => { this.filterIdx = 3; } },
              { value: '日期', action: (): void => { this.filterIdx = 4; } }
            ])
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
          .margin({ top: 104 })

          // 结果区
          Column() {
            if (this.results().length === 0) {
              Column({ space: 10 }) {
                SymbolGlyph($r('sys.symbol.hourglass')).fontSize(34).fontColor([Theme.TERTIARY])
                Text(EMPTY_HINT)
                  .fontSize(14)
                  .fontColor(Theme.SECONDARY)
                Text('换个关键词或筛选方式试试吧')
                  .fontSize(11)
                  .fontColor(Theme.TERTIARY)
              }
              .width('100%')
              .padding({ top: 70 })
              .alignItems(HorizontalAlign.Center)
            } else {
              Scroll() {
                Column() {
                  ForEach(this.results(), (m: Memory) => {
                    this.resultItem(m)
                  }, (m: Memory) => m.id)
                  Blank().height(30)
                }
                .width('100%')
                .padding({ left: 20, right: 20, top: 16 })
              }
              .width('100%')
              .height('100%')
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
              .align(Alignment.Top)
            }
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.BG)
    }
    .titleBar({
      padding: {
        start: LengthMetrics.vp(16),
        end: LengthMetrics.vp(16)
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(10),
          blurEffectiveEndOffset: LengthMetrics.vp(48)
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: 'rgba(247,250,244,0.0)'
          },
          contentStyle: {
            titleStyle: { mainTitleColor: '#1E2A22' },
            backIconStyle: { backgroundColor: 'rgba(255,255,255,0.92)', iconColor: '#1E2A22' }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: 'rgba(247,250,244,0.88)'
          },
          contentStyle: {
            titleStyle: { mainTitleColor: '#1E2A22' },
            backIconStyle: { backgroundColor: 'rgba(255,255,255,0.92)', iconColor: '#1E2A22' }
          }
        }
      },
      content: {
        title: {
          mainTitle: '搜索记忆'
        }
      },
      avoidLayoutSafeArea: true
    })
    .hideBackButton(false)
    .backgroundColor(Theme.BG)
  }
}