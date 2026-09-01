/*
 * ============================================================================
 * 文件名：pages/A_Home.ets
 * ============================================================================
 * 【用途】一级 Tab「首页」：打招呼话语 + 默默软体角色（MoMoAvatar，随滚动缩放）
 *   + 「今日状态」卡片（时间线摘要 + 跳转）+ 「今日漫画」卡片（横滑封面 + 跳转）。
 * 【前置条件 / 假设】
 *   - 依赖：EventRepository.getToday() / ComicRepository.getToday() 提供 Mock 数据；
 *     CompanionService 提供默默状态与订阅（StateListener）；ShellState.homeScroller
 *     与 HDS 标题栏滚动效果绑定；
 *   - 假设：首页不再自带标题栏（由 MainPage 的 HDS 标题栏承担）；
 *     不设全屏覆盖层，避免吞掉滚动/点击手势。
 * 【输入 / 输出（后置条件）】
 *   - 输入：用户滚动（onScroll -> 缩放默默）、点击卡片 chevron、Tab 切换进出（生命周期）；
 *   - 输出：滚动时 heroH/avSize 收缩动画、状态订阅更新；
 *     点击跳转 -> AppRouter.push(今日状态/今日漫画) 压栈。
 * 【关键类 / 算法】
 *   - A_Home：页面组件；summaryCard/comicCard 为 @Builder 卡片；
 *   - onScroll：线性插值 t=clamp(offset/300,0,1)，带动 hero 高度与默默缩放（简单的 1D 映射）。
 * 【参考源】
 *   - MoMo_DOC/ui 参考图（首页版式）；grok-icon-study-web（角色表现）
 * ============================================================================
 */
import { AppRouter, RouteName } from '../router/AppRouter';
import { CompanionService, StateListener, ShellState } from '../service/Services';
import { EventRepository, ComicRepository } from '../repository/Repositories';
import { EventItem, MoMoState } from '../model/Models';
import { Theme } from '../utils/Theme';
import { PromptUtil } from '../utils/PromptUtil';
import { MoMoAvatar } from '../components/MoMoAvatar';

@Component
export struct A_Home {
  @State momoState: MoMoState = MoMoState.IDLE;
  @State momoT: number = 0;
  @State heroH: number = 340;
  @State avSize: number = 300;
  @State events: EventItem[] = [];
  @State comicImages: Resource[] = [];
  private scroller: Scroller = ShellState.homeScroller;
  private onStateChange: StateListener = () => {
  };

  aboutToAppear(): void {
    const daily = EventRepository.get().getToday();
    this.events = daily.events;
    const comic = ComicRepository.get().getToday();
    const imgs: Resource[] = [];
    for (let i = 0; i < comic.pages.length; i++) {
      imgs.push(comic.pages[i].image);
    }
    this.comicImages = imgs;
    this.momoState = CompanionService.get().getState();
    this.onStateChange = () => {
      this.momoState = CompanionService.get().getState();
    };
    CompanionService.get().subscribe(this.onStateChange);
  }

  aboutToDisappear(): void {
    CompanionService.get().unsubscribe(this.onStateChange);
  }

  private onScroll(offset: number): void {
    const t = Math.min(Math.max(offset / 300, 0), 1);
    this.momoT = t;
    this.heroH = 340 - t * 210;
    this.avSize = 300 - t * 120;
  }

  @Builder
  summaryCard() {
    Column({ space: 12 }) {
      Row() {
        Text('今日状态')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 4 })

      Row({ space: 10 }) {
        Column({ space: 8 }) {
          Scroll() {
            Column({ space: 8 }) {
              ForEach(this.events, (ev: EventItem) => {
                Row({ space: 8 }) {
                  Row()
                    .width(6)
                    .height(6)
                    .borderRadius(3)
                    .backgroundColor('#8CCCA0')
                  Text(ev.time)
                    .fontSize(11)
                    .fontColor(Theme.TERTIARY)
                    .width(38)
                  Text(ev.title)
                    .fontSize(13)
                    .fontColor(Theme.SECONDARY)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')
              }, (ev: EventItem) => ev.id)
            }
            .width('100%')
          }
          .width('100%')
          .height(122)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .align(Alignment.Top)
        }
        .layoutWeight(1)

        Column() {
          Stack() {
            Column().width(34).height(34).borderRadius(999).backgroundColor('#F0F7F1')
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(17).fontColor([Theme.BRAND_DEEP])
          }
        }
        .width(34)
        .height(34)
        .onClick(() => {
          PromptUtil.toast('打开今日状态');
          AppRouter.push(RouteName.TODAY_MEMORY);
        })
      }
      .width('100%')
      .padding(16)
      .borderRadius(Theme.RADIUS_CARD)
      .backgroundColor(Theme.CARD)
      .border({ width: 1, color: Theme.LINE })
      .shadow({ radius: 16, color: 'rgba(38,61,42,0.06)', offsetY: 4 })
    }
    .width('100%')
  }

  @Builder
  comicCard() {
    Column({ space: 12 }) {
      Row() {
        Text('今日漫画')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 4 })

      Row({ space: 10 }) {
        Scroll() {
          Row({ space: 10 }) {
            ForEach(this.comicImages, (img: Resource, index: number) => {
              Column() {
                Image(img)
                  .width(116)
                  .height(150)
                  .borderRadius(18)
                  .objectFit(ImageFit.Cover)
                Text((index + 1).toString())
                  .fontSize(9)
                  .fontColor(Theme.TERTIARY)
                  .margin({ top: 3 })
              }
            }, (img: Resource) => img.toString())
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .layoutWeight(1)

        Column() {
          Stack() {
            Column().width(34).height(34).borderRadius(999).backgroundColor('#F0F7F1')
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(17).fontColor([Theme.BRAND_DEEP])
          }
        }
        .width(34)
        .height(34)
        .onClick(() => {
          AppRouter.push(RouteName.DAILY_COMIC);
        })
      }
      .width('100%')
      .padding(16)
      .borderRadius(Theme.RADIUS_CARD)
      .backgroundColor(Theme.CARD)
      .border({ width: 1, color: Theme.LINE })
      .shadow({ radius: 16, color: 'rgba(38,61,42,0.06)', offsetY: 4 })
    }
    .width('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll(this.scroller) {
        Column() {
          Column() {
            MoMoAvatar({
              avatarSize: this.avSize,
              state: this.momoState
            })
          }
          .width('100%')
          .height(this.heroH)
          .padding({ top: 46 })
          .justifyContent(FlexAlign.Center)
          .linearGradient({
            angle: 180,
            colors: [['rgba(247,250,244,0.95)', 0], ['rgba(247,250,244,0.85)', 0.7], ['rgba(247,250,244,0.0)', 1]]
          })
          .borderRadius({ bottomLeft: 28, bottomRight: 28 })
          .clip(true)

          this.summaryCard()
          Blank().height(18)
          this.comicCard()
          Blank().height(200)
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onScroll((offset: number) => {
        this.onScroll(offset);
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}