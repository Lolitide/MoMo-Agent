/*
 * ============================================================================
 * 文件名：pages/B_TodayMemory_Enhanced.ets
 * ============================================================================
 * 【用途】增强版「今日状态」页面：集成真实 AI 生成功能
 * 【新增功能】
 *   - 支持调用 AIServiceCloud 生成真实每日总结
 *   - 菜单新增「生成总结」按钮
 *   - 显示生成状态（生成中/成功/失败）
 * ============================================================================
 */
import { HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { AppRouter, RouteName } from '../router/AppRouter';
import { EventRepository } from '../repository/Repositories';
import { DailyMemory, EventItem, InsightItem, PageState } from '../model/Models';
import { DateUtil } from '../utils/DateUtil';
import { Theme } from '../utils/Theme';
import { PromptUtil } from '../utils/PromptUtil';
import { EventTimeline } from '../components/EventTimeline';
import { DayBottomBar } from '../components/DayBottomBar';
import { CorrectionSheetContent, FeedbackSheetContent } from '../components/Sheets';
import { LoadingState, EmptyState, ErrorState } from '../components/StateViews';
import { MiniCalendar } from '../components/MiniCalendar';

@Component
export struct B_TodayMemory_Enhanced {
  @State pageState: PageState = PageState.LOADING;
  @State daily: DailyMemory = new DailyMemory();
  @State scrollBlur: boolean = false;
  @State sheetOpen: boolean = false;
  @State sheetMode: number = -1;
  @State calendarOpen: boolean = false;
  @State eventsH: number = 290;
  @State selectedDate: Date = new Date();
  @State isGenerating: boolean = false; // 新增：是否正在生成
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

  /**
   * 生成真实每日总结
   */
  private async generateRealSummary(): Promise<void> {
    if (this.isGenerating) {
      PromptUtil.toast('正在生成中，请稍候');
      return;
    }

    this.isGenerating = true;
    PromptUtil.toast('开始生成每日总结...');

    try {
      // 准备事件数据
      const events = this.daily.events.map(e => ({
        time: e.time,
        content: e.title,
        mood: '平静'
      }));

      // 调用 AI 服务生成总结
      const summary = await EventRepository.get().generateDailySummary(events, '平静');

      // 更新 UI
      this.daily.summary = summary;
      PromptUtil.toast('✅ 总结生成成功');
    } catch (err) {
      const error = err as Error;
      PromptUtil.toast(`❌ 生成失败: ${error.message}`);
    } finally {
      this.isGenerating = false;
    }
  }

  // 事件区拖拽逻辑（保持原有）
  private onPanStart(): void {
    this.panBase = this.eventsH;
  }

  private onPanUpdate(offsetY: number): void {
    const next = this.panBase + offsetY;
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

  private openCorrection(): void {
    if (this.sheetOpen) {
      return;
    }
    this.sheetMode = 0;
    this.sheetOpen = true;
  }

  private openFeedback(): void {
    if (this.sheetOpen) {
      return;
    }
    this.sheetMode = 1;
    this.sheetOpen = true;
  }

  @Builder
  sheetBuilder() {
    if (this.sheetMode !== 1) {
      CorrectionSheetContent({
        onCancel: () => {
          this.sheetOpen = false;
        },
        onSubmit: (text: string) => {
          this.sheetOpen = false;
          PromptUtil.toast('已记下你的纠正');
        }
      })
    } else {
      FeedbackSheetContent({
        onCancel: () => {
          this.sheetOpen = false;
        },
        onSubmit: (text: string) => {
          this.sheetOpen = false;
          PromptUtil.toast('已收到你的反馈');
        }
      })
    }
  }

  @Builder
  summaryBlock() {
    Column({ space: 8 }) {
      Row() {
        Text('今日小结')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.PRIMARY)
        Blank()
        if (this.isGenerating) {
          Text('生成中...')
            .fontSize(12)
            .fontColor(Theme.BRAND)
        }
      }
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

      Column({ space: 5 }) {
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
        Text('上下拖动调整事件区域大小')
          .fontSize(10)
          .fontColor(Theme.TERTIARY)
          .opacity(0.85)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
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

      Grid() {
        ForEach(this.daily.insights, (item: InsightItem) => {
          GridItem() {
            Column({ space: 5 }) {
              Text(item.title)
                .fontSize(12)
                .fontColor(Theme.TERTIARY)
                .width('100%')
              Text(item.content)
                .fontSize(13)
                .fontColor(Theme.SECONDARY)
                .width('100%')
            }
            .width('100%')
            .padding(12)
            .borderRadius(Theme.RADIUS_SMALL)
            .backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.LINE })
          }
        }, (item: InsightItem) => item.id)
      }
      .columnsTemplate('1fr 1fr')
      .rowsGap(10)
      .columnsGap(10)
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
            text: '记忆整理失败了',
            onRetry: () => {
              this.retry();
            }
          })
        } else {
          Scroll(this.scroller) {
            Column({ space: 12 }) {
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
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.BG)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .bindSheet($$this.sheetOpen, this.sheetBuilder(), {
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        dragBar: true,
        backgroundColor: Theme.SHEET_BG,
        showInSubWindow: false
      })
      .bindSheet($$this.calendarOpen, this.calendarBuilder(), {
        detents: [SheetSize.MEDIUM],
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
      scrollEffect: {
        type: ScrollEffectType.BLUR,
        threshold: 8,
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
            {
              content: {
                label: '生成总结',
                icon: $r('sys.symbol.sparkles'),
                isEnabled: !this.isGenerating,
                action: () => {
                  this.generateRealSummary();
                }
              }
            },
            { content: { label: '刷新', icon: $r('sys.symbol.arrow_clockwise'), isEnabled: true, action: () => { this.retry(); } } },
            { content: { label: '模拟失败', icon: $r('sys.symbol.xmark_circle'), isEnabled: true, action: () => { this.pageState = PageState.ERROR; } } },
            { content: { label: '关于默默', icon: $r('sys.symbol.star'), isEnabled: true, action: () => { AppRouter.push(RouteName.ABOUT); } } }
          ]
        }
      },
      avoidLayoutSafeArea: true
    })
    .hideBackButton(false)
    .backgroundColor(Theme.BG)
  }

  @Builder
  calendarBuilder() {
    Column({ space: 12 }) {
      Text('选择日期')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.PRIMARY)
        .width('100%')
        .padding({ left: 20, right: 20, top: 12 })

      MiniCalendar({
        selectedDate: $selectedDate,
        onSelect: (date: Date) => {
          this.selectedDate = date;
          this.calendarOpen = false;
          PromptUtil.toast(`已选择 ${DateUtil.formatDot(date)}（Mock 数据）`);
        }
      })

      Blank().height(20)
    }
    .width('100%')
  }
}
