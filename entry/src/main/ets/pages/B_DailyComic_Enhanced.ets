/*
 * ============================================================================
 * 文件名：pages/B_DailyComic_Enhanced.ets
 * ============================================================================
 * 【用途】增强版「今日漫画」页面：集成真实 AI 生成功能
 * 【新增功能】
 *   - 支持调用 AIServiceCloud 生成真实漫画
 *   - 菜单新增「生成漫画」按钮
 *   - 显示生成状态（生成中/成功/失败）
 * ============================================================================
 */
import { HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { AppRouter, RouteName } from '../router/AppRouter';
import { ComicRepository } from '../repository/Repositories';
import { Comic, ComicPage, PageState, MoMoState } from '../model/Models';
import { Theme } from '../utils/Theme';
import { PromptUtil } from '../utils/PromptUtil';
import { DayBottomBar } from '../components/DayBottomBar';
import { CorrectionSheetContent, FeedbackSheetContent } from '../components/Sheets';
import { LoadingState, ErrorState } from '../components/StateViews';
import { MoMoAvatar } from '../components/MoMoAvatar';

@Component
export struct B_DailyComic_Enhanced {
  @State pageState: PageState = PageState.LOADING;
  @State comic: Comic = new Comic();
  @State current: number = 0;
  @State scrollBlur: boolean = false;
  @State sheetOpen: boolean = false;
  @State sheetMode: number = -1;
  @State viewerScale: number = 1;
  @State viewerTx: number = 0;
  @State viewerTy: number = 0;
  @State isGenerating: boolean = false; // 新增：是否正在生成
  private scroller: Scroller = new Scroller();
  private pinchStart: number = 1;
  private panStartX: number = 0;
  private panStartY: number = 0;

  aboutToAppear(): void {
    setTimeout(() => {
      this.load();
    }, 400);
  }

  private load(): void {
    if (ComicRepository.get().loadFailed) {
      this.pageState = PageState.ERROR;
      return;
    }
    this.comic = ComicRepository.get().getToday();
    this.current = 0;
    this.pageState = PageState.SUCCESS;
  }

  private retry(): void {
    this.pageState = PageState.LOADING;
    setTimeout(() => {
      this.load();
    }, 500);
  }

  /**
   * 生成真实漫画
   */
  private async generateRealComic(): Promise<void> {
    if (this.isGenerating) {
      PromptUtil.toast('正在生成中，请稍候');
      return;
    }

    this.isGenerating = true;
    this.pageState = PageState.LOADING;
    PromptUtil.toast('开始生成今日漫画...');

    try {
      // 获取今日总结和事件（这里使用 Mock 数据，实际应该从 EventRepository 获取）
      const summary = '今天过得很充实，完成了设计规范文档，和同事讨论了新功能';
      const events = [
        { time: '09:00', content: '写设计规范', mood: '专注' },
        { time: '14:00', content: '团队讨论', mood: '愉快' },
        { time: '19:00', content: '看漫画放松', mood: '轻松' }
      ];

      // 调用 AI 服务生成漫画
      const comic = await ComicRepository.get().generateTodayComic(summary, events);

      // 更新 UI
      this.comic = comic;
      this.current = 0;
      this.pageState = PageState.SUCCESS;
      PromptUtil.toast('✅ 漫画生成成功');
    } catch (err) {
      const error = err as Error;
      this.pageState = PageState.ERROR;
      PromptUtil.toast(`❌ 生成失败: ${error.message}`);
    } finally {
      this.isGenerating = false;
    }
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
  comicSwiper() {
    Swiper() {
      ForEach(this.comic.pages, (p: ComicPage) => {
        Image(p.image)
          .width('100%')
          .aspectRatio(1.22)
          .borderRadius(Theme.RADIUS_CARD)
          .backgroundColor('#F4F6F3')
          .onClick(() => {
            // 点击进入全屏查看
          })
      }, (p: ComicPage) => p.index.toString())
    }
    .width('100%')
    .height('auto')
    .indicator(false)
    .loop(false)
    .onChange((index: number) => {
      this.current = index;
    })
  }

  @Builder
  dots() {
    Row({ space: 8 }) {
      ForEach(this.comic.pages, (p: ComicPage) => {
        Row()
          .width(this.current === p.index ? 8 : 7)
          .height(this.current === p.index ? 8 : 7)
          .borderRadius(4)
          .backgroundColor(this.current === p.index ? '#4C6852' : '#C9D6CC')
          .animation({ duration: 180, curve: Curve.EaseOut })
      }, (p: ComicPage) => p.index.toString())
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ top: 10 })
  }

  @Builder
  errorBody() {
    Column({ space: 18 }) {
      MoMoAvatar({ avatarSize: 150, state: MoMoState.THINKING })
      Text('默默还在画，请稍后再试')
        .fontSize(15)
        .fontColor(Theme.SECONDARY)
      Text('（这是 Mock 错误状态演示，可在右上角菜单恢复）')
        .fontSize(11)
        .fontColor(Theme.TERTIARY)
      Button('重新加载')
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor(Theme.BRAND_DEEP)
        .height(40)
        .borderRadius(20)
        .padding({ left: 22, right: 22 })
        .onClick(() => {
          ComicRepository.get().loadFailed = false;
          this.retry();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        if (this.pageState === PageState.LOADING) {
          LoadingState({ text: this.isGenerating ? '默默正在绘制今天的漫画……' : '加载中……' })
        } else if (this.pageState === PageState.ERROR) {
          this.errorBody()
        } else {
          Scroll(this.scroller) {
            Column({ space: 12 }) {
              Blank().height(100)
              Text('今日一页')
                .fontSize(12)
                .fontColor(Theme.TERTIARY)
                .width('100%')
              Text(this.comic.title)
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.PRIMARY)
                .width('100%')
              this.comicSwiper()
              this.dots()
              Column({ space: 8 }) {
                Text('默默寄语')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Theme.PRIMARY)
                  .width('100%')
                Text(this.comic.message)
                  .fontSize(14)
                  .fontColor(Theme.SECONDARY)
                  .lineHeight(22)
                  .width('100%')
              }
              .width('100%')
              .padding(18)
              .borderRadius(Theme.RADIUS_CARD)
              .backgroundColor(Theme.CARD)
              .border({ width: 1, color: Theme.LINE })

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
                PromptUtil.toast('今日漫画仅支持查看当天（Mock）');
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
          mainTitle: '今日漫画'
        },
        menu: {
          value: [
            {
              content: {
                label: '生成漫画',
                icon: $r('sys.symbol.photo_on_rectangle'),
                isEnabled: !this.isGenerating,
                action: () => {
                  this.generateRealComic();
                }
              }
            },
            { content: { label: '重新生成', icon: $r('sys.symbol.arrow_clockwise'), isEnabled: !this.isGenerating, action: () => { this.generateRealComic(); } } },
            { content: { label: '模拟失败', icon: $r('sys.symbol.xmark_circle'), isEnabled: true, action: () => { ComicRepository.get().loadFailed = true; this.pageState = PageState.ERROR; } } },
            { content: { label: '关于默默', icon: $r('sys.symbol.star'), isEnabled: true, action: () => { AppRouter.push(RouteName.ABOUT); } } }
          ]
        }
      },
      avoidLayoutSafeArea: true
    })
    .hideBackButton(false)
    .backgroundColor(Theme.BG)
  }
}
