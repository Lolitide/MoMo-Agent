/*
 * ============================================================================
 * 文件名：pages/B_TodayMemory.ets
 * ============================================================================
 * 【用途】二级页「今日状态」（HdsNavDestination 导航子页）：
 *   今日总结卡 + 今日事件时间线（可拖动收起）+ 默默的理解（两列网格），
 *   底部固定栏（纠正/日期/反馈），日历浮窗与纠正/反馈浮窗（bindSheet 系统浮层）。
 * 【前置条件 / 假设】
 *   - 依赖：HdsNavDestination(系统返回+标题栏沉浸)、EventRepository.getToday()、
 *     EventTimeline/MiniCalendar/StateViews/Sheets 组件；
 *   - 假设：pageState 默认 LOADING，400ms 后 Mock 加载完成（先加载态后内容）；
 *     事件区高度吸附 0/190/380 三档。
 * 【输入 / 输出（后置条件）】
 *   - 输入：返回/菜单按钮（刷新/模拟失败/关于）、拖动事件区把手、日历选择、
 *     纠正/反馈提交；菜单“模拟失败”可复现错误态并支持重试；
 *   - 输出：页面状态机（LOADING/SUCCESS/EMPTY/ERROR）、selectedDate 切换、
 *     浮窗开合（correctionOpen/feedbackOpen/calendarOpen）。
 * 【关键类 / 算法】
 *   - onPanStart/onPanUpdate/onPanEnd：事件区高度拖动 + 就近吸附（最小距离算法）；
 *   - summaryBlock/eventsBlock/insightsBlock：三区块 @Builder。
 * 【参考源】
 *   - Examples/hdsNavigation Examples.md（HdsNavDestination titleBar 参数）
 *   - ibest-ui 底部卡片栏样式；MoMo_DOC/UI 参考图（今日状态页）
 * ============================================================================
 */
import { HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { AppRouter, RouteName } from '../router/AppRouter';
import { EventRepository } from '../repository/Repositories';
import { DailyMemory, InsightItem, PageState } from '../model/Models';
import { DateUtil } from '../utils/DateUtil';
import { Theme } from '../utils/Theme';
import { PromptUtil } from '../utils/PromptUtil';
import { EventTimeline } from '../components/EventTimeline';
import { DayBottomBar } from '../components/DayBottomBar';
import { CorrectionSheetContent, FeedbackSheetContent } from '../components/Sheets';
import { LoadingState, EmptyState, ErrorState } from '../components/StateViews';
import { MiniCalendar } from '../components/MiniCalendar';

@Component
export struct B_TodayMemory {
  @State pageState: PageState = PageState.LOADING;
  @State daily: DailyMemory = new DailyMemory();
  @State scrollBlur: boolean = false;
  // 单一浮层状态：sheetMode 0=纠正 1=反馈
  @State sheetOpen: boolean = false;
  @State sheetMode: number = -1;
  @State calendarOpen: boolean = false;
  @State eventsH: number = 290;
  @State selectedDate: Date = new Date();
  private scroller: Scroller = new Scroller();
  private panBase: number = 290;

  aboutToAppear(): void {
    setTimeout(() => {
      this.daily = EventRepository.get().getToday();
      this.pageState = PageState.SUCCESS;
    }, 400);
  }

  private retry(): void {
    this.pageState = PageState.LOADING;
    setTimeout(() => {
      this.daily = EventRepository.get().getToday();
      this.pageState = PageState.SUCCESS;
    }, 400);
  }

  // 事件区拖拽：起点记录基高，update 线性增减，end 就近吸附到 0/190/380 三档
  private onPanStart(): void {
    this.panBase = this.eventsH;
  }

  private onPanUpdate(offsetY: number): void {
    const next = this.panBase - offsetY;
    this.eventsH = Math.min(Math.max(next, 0), 400);
  }

  private onPanEnd(): void {
    const targets: number[] = [0, 190, 380];
    let best = 0;
    let bestDist = 99999;
    for (let i = 0; i < targets.length; i++) {
      const dist = Math.abs(targets[i] - this.eventsH);
      if (dist < bestDist) {
        bestDist = dist;
        best = targets[i];
      }
    }
    animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
      this.eventsH = best;
    });
  }


  // 打开纠正浮层
  private openCorrection(): void {
    if (this.sheetOpen) {
      return;
    }
    this.sheetMode = 0;
    this.sheetOpen = true;
  }

  // 打开反馈浮层
  private openFeedback(): void {
    if (this.sheetOpen) {
      return;
    }
    this.sheetMode = 1;
    this.sheetOpen = true;
  }

  // 单一系统浮层：按 sheetMode 切换纠正/反馈内容（避免多 bindSheet 冲突）
  @Builder
  sheetBuilder() {
    if (this.sheetMode !== 1) {
      CorrectionSheetContent({
        originalText: '默默认为你今天的心情总体平稳，但下午可能有些疲惫。',
        onDismiss: () => {
          this.sheetOpen = false;
        },
        onApply: (text: string) => {
          this.sheetOpen = false;
          PromptUtil.toast('已提交纠正「' + (text.length > 14 ? text.slice(0, 14) + '…' : text) + '」');
        }
      })
    } else if (this.sheetMode === 1) {
      FeedbackSheetContent({
        onDismiss: () => {
          this.sheetOpen = false;
        },
        onSubmit: (score: number, msg: string) => {
          this.sheetOpen = false;
          PromptUtil.toast('已收到 ' + score.toString() + ' 星反馈，默默记住啦');
        }
      })
    }
  }

  @Builder
  summaryBlock() {
    Column({ space: 8 }) {
      Text('今日总结')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.PRIMARY)
        .width('100%')
      Text(this.daily.summary)
        .fontSize(14)
        .fontColor(Theme.SECONDARY)
        .lineHeight(23)
        .width('100%')
    }
    .width('100%')
    .padding(18)
    .borderRadius(Theme.RADIUS_CARD)
    .backgroundColor(Theme.CARD)
    .border({ width: 1, color: Theme.LINE })
  }

  @Builder
  eventsBlock() {
    Column({ space: 6 }) {
      Text('今日事件')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.PRIMARY)
        .width('100%')
        .padding({ left: 2 })

      Column() {
        Scroll() {
          Column({ space: 2 }) {
            EventTimeline({ events: this.daily.events })
          }
          .width('100%')
          .padding({ left: 10, right: 12, top: 4, bottom: 10 })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height(this.eventsH)
      .clip(true)

      Row()
        .width(56)
        .height(5)
        .borderRadius(3)
        .backgroundColor('#C4D3C8')
        .shadow({ radius: 4, color: 'rgba(60,90,66,0.10)', offsetY: 1 })
        .gesture(
          PanGesture({ direction: PanDirection.Vertical, distance: 4 })
            .onActionStart(() => {
              this.onPanStart();
            })
            .onActionUpdate((event: GestureEvent) => {
              this.onPanUpdate(event.offsetY);
            })
            .onActionEnd(() => {
              this.onPanEnd();
            })
        )
        .margin({ top: 4, bottom: 4 })
    }
    .width('100%')
  }

  @Builder
  insightsBlock() {
    Column({ space: 8 }) {
      Text('默默的理解')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.PRIMARY)
        .width('100%')
        .padding({ left: 2 })
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(this.daily.insights, (ins: InsightItem) => {
          Column({ space: 6 }) {
            Text(ins.title)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.PRIMARY)
              .width('100%')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(ins.content)
              .fontSize(12)
              .fontColor(Theme.SECONDARY)
              .lineHeight(18)
              .width('100%')
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('47.6%')
          .height(112)
          .padding(14)
          .borderRadius(18)
          .backgroundColor(Theme.CARD)
          .border({ width: 1, color: Theme.LINE })
          .margin({ bottom: 12 })
        }, (ins: InsightItem) => ins.id)
      }
      .width('100%')
    }
    .width('100%')
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        if (this.pageState === PageState.LOADING) {
          LoadingState({ text: '默默正在整理今天的记忆……' })
        } else if (this.pageState === PageState.ERROR) {
          ErrorState({
            text: '今日状态加载失败，请检查网络后再试',
            onRetry: () => {
              this.retry();
            }
          })
        } else if (this.pageState === PageState.EMPTY) {
          EmptyState({ text: '今天默默还没有观察到什么' })
        } else {
          Scroll(this.scroller) {
            Column({ space: 14 }) {
              Blank().height(100)
              this.summaryBlock()
              this.eventsBlock()
              this.insightsBlock()
              Blank().height(120)
            }
            .width('100%')
            .padding({ left: 20, right: 20 })
          }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .onScroll((offset: number) => {
            this.scrollBlur = offset > 12;
          })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

          Column() {
            DayBottomBar({
              date: this.selectedDate,
              onCorrect: () => {
                this.openCorrection();
              },
              onFeedback: () => {
                this.openFeedback();
              },
              onDate: () => {
                this.calendarOpen = true;
              }
            })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.End)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
          .hitTestBehavior(HitTestMode.Transparent)
        }

        // 日历浮窗
        if (this.calendarOpen) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0,0,0,0)')
            .onClick(() => {
              this.calendarOpen = false;
            })
          Column() {
            Blank().layoutWeight(1)
            MiniCalendar({
              selectedKey: DateUtil.dateKey(this.selectedDate),
              onPick: (d: Date) => {
                this.selectedDate = d;
                this.calendarOpen = false;
                PromptUtil.toast('已切换至 ' + DateUtil.formatDot(d) + '（Mock 数据）');
              },
              onClose: () => {
                this.calendarOpen = false;
              }
            })
            Blank().height(108)
          }
          .width('100%')
          .height('100%')
          .alignItems(HorizontalAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.BG)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      // 系统底部浮层（bindSheet 挂在目的地内层 Stack 上；官方示例亦绑定任意组件）
      .bindSheet($$this.sheetOpen, this.sheetBuilder(), {
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        dragBar: true,
        backgroundColor: Theme.SHEET_BG,
        showInSubWindow: false
      })
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
            backIconStyle: { backgroundColor: 'rgba(255,255,255,0.92)', iconColor: '#1E2A22' },
            menuStyle: { backgroundColor: 'rgba(255,255,255,0.92)', iconColor: '#1E2A22' }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: 'rgba(247,250,244,0.88)'
          },
          contentStyle: {
            titleStyle: { mainTitleColor: '#1E2A22' },
            backIconStyle: { backgroundColor: 'rgba(255,255,255,0.92)', iconColor: '#1E2A22' },
            menuStyle: { backgroundColor: 'rgba(255,255,255,0.92)', iconColor: '#1E2A22' }
          }
        }
      },
      content: {
        title: {
          mainTitle: '今日状态'
        },
        menu: {
          value: [
            { content: { label: '刷新', icon: $r('sys.symbol.arrow_clockwise'), isEnabled: true, action: () => { PromptUtil.toast('已刷新（Mock 数据未变化）'); } } },
            { content: { label: '模拟失败', icon: $r('sys.symbol.xmark_circle'), isEnabled: true, action: () => { this.pageState = PageState.ERROR; } } },
            { content: { label: '关于默默', icon: $r('sys.symbol.star'), isEnabled: true, action: () => { AppRouter.push(RouteName.ABOUT); } } }
          ]
        }
      },
      avoidLayoutSafeArea: true
    })
    .hideBackButton(false)
    .backgroundColor(Theme.BG)
    // 纠正 / 反馈：系统底部浮层（同添加页）
    
    
  }
}