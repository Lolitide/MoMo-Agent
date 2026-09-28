/*
 * ============================================================================
 * 文件名：pages/A_Home.ets
 * ============================================================================
 * 【用途】一级 Tab「首页」：打招呼话语 + 默默软体角色（MoMoAvatar，随滚动缩放）
 *   + 「今日状态」卡片（时间线摘要 + 跳转）+ 「今日漫画」卡片（横滑封面 + 跳转）。
 * 【前置条件 / 假设】
 *   - 依赖：EventRepository.getToday() / ComicRepository.getGeneratedToday()；
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
import { DemoModeService } from '../service/DemoModeService';
import { EventItem, MoMoState } from '../model/Models';
import { Theme } from '../utils/Theme';
import { MoMoAvatar } from '../components/MoMoAvatar';

@Component
export struct A_Home {
  @State momoState: MoMoState = MoMoState.IDLE;
  @State momoT: number = 0;
  @State heroH: number = 340;
  @State avSize: number = 300;
  @State events: EventItem[] = [];
  @State comicImages: ResourceStr[] = [];
  /** 演示态：漫画用的是 comic_demo_1..4 这组横版图，缩略图要换比例并改用 Contain */
  @State isDemo: boolean = false;
  private scroller: Scroller = ShellState.homeScroller;
  /** 取数序号：作废「比演示模式切换还晚回来」的旧异步回调（见 loadToday） */
  private loadSeq: number = 0;
  private onStateChange: StateListener = () => {
  };
  private onDemoChange: StateListener = () => {
  };

  aboutToAppear(): void {
    this.loadToday();

    this.onDemoChange = () => {
      // 演示模式开关会整体换掉 事件/漫画/记忆 三个仓库的数据，
      // 本页在切 Tab 时不会重建，所以必须订阅一次广播，否则会一直停在切换前的旧内容。
      this.loadToday();
    };
    DemoModeService.get().subscribe(this.onDemoChange);

    this.momoState = CompanionService.get().getState();
    this.onStateChange = () => {
      this.momoState = CompanionService.get().getState();
    };
    CompanionService.get().subscribe(this.onStateChange);
  }

  /**
   * 读取「今日状态 + 今日漫画」。
   * 抽成方法是为了让首次进入与演示模式切换广播走同一段取数逻辑，
   * 避免两条路径各写一遍、日后改一处漏一处。
   */
  private loadToday(): void {
    // getToday() 是异步的：启动时那次读取（要等系统日历/待办）可能比「开启演示模式」
    // 还晚回来，把演示数据又覆盖回真实数据。用序号作废过期的那次回调。
    this.loadSeq++;
    const seq: number = this.loadSeq;

    // 异步加载今日事件（支持系统数据）
    EventRepository.get().getToday().then((daily) => {
      if (seq !== this.loadSeq) {
        return;
      }
      this.events = daily.events;
    }).catch((err: Error) => {
      console.error(`加载今日事件失败: ${err.message}`);
      if (seq === this.loadSeq) {
        this.events = [];
      }
    });

    const comic = ComicRepository.get().getGeneratedToday();
    const imgs: ResourceStr[] = [];
    if (comic) {
      for (let i = 0; i < comic.pages.length; i++) {
        imgs.push(comic.pages[i].image);
      }
    }
    this.comicImages = imgs;
    this.isDemo = DemoModeService.get().isDemo();
  }

  aboutToDisappear(): void {
    CompanionService.get().unsubscribe(this.onStateChange);
    DemoModeService.get().unsubscribe(this.onDemoChange);
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
          .fontSize(Theme.fontSize(17))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 4 })

      Row({ space: 0 }) {
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
                    .fontSize(Theme.fontSize(11))
                    .fontColor(Theme.TERTIARY)
                    .width(38)
                  Text(ev.title)
                    .fontSize(Theme.fontSize(13))
                    .fontColor(Theme.SECONDARY)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')
                // key 必须带上内容：普通数据与演示数据的 id 都是 e1、e2……，
                // 只用 id 作 key 时 ArkUI 会复用旧组件、把上一次的文本留在屏幕上
                // （切换演示模式后前 5 条仍是真实数据，就是这个原因）。
              }, (ev: EventItem) => `${ev.id}-${ev.time}-${ev.title}`)
            }
            .width('100%')
          }
          .width('100%')
          .height(100)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .align(Alignment.Top)
        }
        .layoutWeight(1)

        Column() {
          Stack() {
            Column().width(20).height(100)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(Theme.fontSize(40)).fontColor(['#B261D77E'])
          }
        }
        .width(20)
        .height(100)
        .onClick(() => {
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
          .fontSize(Theme.fontSize(17))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 4 })

      Row({ space: 10 }) {
        if (this.comicImages.length === 0) {
          Text('云端漫画尚未生成，点击右侧进入')
            .fontSize(Theme.fontSize(13))
            .fontColor(Theme.SECONDARY)
            .layoutWeight(1)
        } else {
          Scroll() {
            Row({ space: 10 }) {
              ForEach(this.comicImages, (img: ResourceStr, index: number) => {
                Column() {
                  Image(img)
                    // 演示态是横版分镜：换成 3:2 的缩略框 + Contain，否则竖框 Cover 会把台词裁掉
                    .width(this.isDemo ? 150 : 116)
                    .height(this.isDemo ? 100 : 150)
                    .borderRadius(18)
                    .objectFit(this.isDemo ? ImageFit.Contain : ImageFit.Cover)
                  Text((index + 1).toString())
                    .fontSize(Theme.fontSize(9))
                    .fontColor(Theme.TERTIARY)
                    .margin({ top: 3 })
                }
              }, (img: ResourceStr) => img.toString())
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .layoutWeight(1)
        }

        Column() {
          Stack() {
            Column().width(20).height(100)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(Theme.fontSize(40)).fontColor(['#B261D77E'])
          }
        }
        .width(20)
        .height(100)
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
              state: this.momoState,
              interactive: true
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
