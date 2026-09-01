/*
 * ============================================================================
 * 文件名：pages/B_DailyComic.ets
 * ============================================================================
 * 【用途】二级页「今日漫画」（HdsNavDestination 导航子页）：
 *   漫画标题 + Swiper 漫画翻页（1.22 展示比例）+ 指示点 + 默默寄语；
 *   点击进入全屏看图（捏合缩放/拖拽/双击），底部固定栏（纠正/日期/反馈）。
 * 【前置条件 / 假设】
 *   - 依赖：HdsNavDestination、ComicRepository.getToday()（Mock 图集 comic_1..5）、
 *     DayBottomBar、Sheets、StateViews；loadFailed 可模拟失败态；
 *   - 假设：全屏查看层为自定义覆盖层（非系统一个窗口），极简手势交互。
 * 【输入 / 输出（后置条件）】
 *   - 输入：Swiper 滑动、点击图片、捏合/拖拽/双击、菜单（重新生成/模拟失败/关于）、
 *     纠正/反馈提交、返回；
 *   - 输出：current 页码、viewerOpen/viewerScale/viewerTx/Ty 手势状态、
 *     pageState（LOADING/ERROR/SUCCESS）。
 * 【关键类 / 算法】
 *   - GestureGroup(Exclusive) 组合 PinchGesture/PanGesture/TapGesture 实现看板手势；
 *   - resetViewer：animateTo 回弹复位（scale=1, 位移清零）。
 * 【参考源】
 *   - Examples/ArkUISample（Swiper/手势）；MoMo_DOC/占位图片（漫画占位素材）
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
import { GlassSheet } from '../components/GlassSheet';
import { CorrectionSheetContent, FeedbackSheetContent } from '../components/Sheets';
import { LoadingState, ErrorState } from '../components/StateViews';
import { MoMoAvatar } from '../components/MoMoAvatar';

@Component
export struct B_DailyComic {
  @State pageState: PageState = PageState.LOADING;
  @State comic: Comic = new Comic();
  @State current: number = 0;
  @State scrollBlur: boolean = false;
  @State correctionOpen: boolean = false;
  @State feedbackOpen: boolean = false;
  @State viewerOpen: boolean = false;
  @State viewerScale: number = 1;
  @State viewerTx: number = 0;
  @State viewerTy: number = 0;
  private scroller: Scroller = new Scroller();
  private pinchStart: number = 1;
  private panStartX: number = 0;
  private panStartY: number = 0;

  aboutToAppear(): void {
    setTimeout(() => {
      this.load();
    }, 400);
  }

  // 加载今日漫画：先检查“模拟失败”标志（菜单可触发），成功则取图集并复位页码
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

  private resetViewer(): void {
    animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.viewerScale = 1;
      this.viewerTx = 0;
      this.viewerTy = 0;
    });
  }

  @Builder
  correctionContent() {
    CorrectionSheetContent({
      originalText: '默默把今天画成了一只下午打盹的小猫，因为你的专注时段之后有那么一点点疲惫。',
      onDismiss: () => {
        this.correctionOpen = false;
      },
      onApply: (text: string) => {
        this.correctionOpen = false;
        PromptUtil.toast('已提交纠正「' + (text.length > 14 ? text.slice(0, 14) + '…' : text) + '」');
      }
    })
  }

  @Builder
  feedbackContent() {
    FeedbackSheetContent({
      onDismiss: () => {
        this.feedbackOpen = false;
      },
      onSubmit: (score: number, msg: string) => {
        this.feedbackOpen = false;
        PromptUtil.toast('已收到 ' + score.toString() + ' 星反馈，默默画得更好');
      }
    })
  }

  @Builder
  comicSwiper() {
    Swiper() {
      ForEach(this.comic.pages, (p: ComicPage) => {
        Column() {
          Image(p.image)
            .width('100%')
            .height('100%')
            .borderRadius(26)
            .objectFit(ImageFit.Cover)
        }
        .width('100%')
        .height('100%')
        .onClick(() => {
          this.viewerOpen = true;
          this.resetViewer();
        })
      }, (p: ComicPage) => p.index.toString())
    }
    .width('100%')
    .height(500)
    .itemSpace(14)
    .displayCount(1.22)
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
    .margin({ top: 16 })
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
          LoadingState({ text: '默默正在绘制今天的漫画……' })
        } else if (this.pageState === PageState.ERROR) {
          this.errorBody()
        } else {
          Scroll(this.scroller) {
            Column({ space: 12 }) {
              Blank().height(28)
              Text('漫画标题')
                .fontSize(12)
                .fontColor(Theme.TERTIARY)
                .width('100%')
              Text(this.comic.title)
                .fontSize(19)
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
              .margin({ top: 8 })

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
                this.correctionOpen = true;
              },
              onFeedback: () => {
                this.feedbackOpen = true;
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

        // 全屏查看
        if (this.viewerOpen) {
          Stack({ alignContent: Alignment.Center }) {
            Image(this.comic.pages[this.current].image)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .scale({
                x: this.viewerScale,
                y: this.viewerScale,
                centerX: 0.5,
                centerY: 0.5
              })
              .translate({ x: this.viewerTx, y: this.viewerTy })
              .gesture(
                GestureGroup(GestureMode.Exclusive,
                  PinchGesture({ fingers: 2, distance: 2 })
                    .onActionStart(() => {
                      this.pinchStart = this.viewerScale;
                    })
                    .onActionUpdate((event: GestureEvent) => {
                      this.viewerScale = Math.min(Math.max(this.pinchStart * event.scale, 0.6), 4);
                    }),
                  PanGesture({ fingers: 1, direction: PanDirection.All, distance: 3 })
                    .onActionStart(() => {
                      this.panStartX = this.viewerTx;
                      this.panStartY = this.viewerTy;
                    })
                    .onActionUpdate((event: GestureEvent) => {
                      this.viewerTx = this.panStartX + event.offsetX;
                      this.viewerTy = this.panStartY + event.offsetY;
                    }),
                  TapGesture({ count: 2 })
                    .onAction(() => {
                      if (this.viewerScale > 1.05) {
                        this.resetViewer();
                      } else {
                        animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
                          this.viewerScale = 2;
                        });
                      }
                    })
                )
              )
              .onClick(() => {
                this.viewerOpen = false;
                this.resetViewer();
              })
          }
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(12,16,13,0.96)')

          Row() {
            Column() {
              Stack() {
                Column().width(36).height(36).borderRadius(999).backgroundColor('rgba(255,255,255,0.25)')
                SymbolGlyph($r('sys.symbol.xmark')).fontSize(18).fontColor(['#FFFFFF'])
              }
            }
            .width(36)
            .height(36)
            .onClick(() => {
              this.viewerOpen = false;
              this.resetViewer();
            })
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 14 })
          .justifyContent(FlexAlign.End)
          .align(Alignment.Top)

          Text((this.current + 1).toString() + ' / ' + this.comic.pages.length.toString())
            .fontSize(12)
            .fontColor('rgba(255,255,255,0.85)')
            .backgroundColor('rgba(0,0,0,0.35)')
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .borderRadius(12)
            .align(Alignment.Bottom)
            .margin({ bottom: 24 })
        }

        // 纠正 / 反馈 浮窗
        if (this.correctionOpen) {
          GlassSheet({
            show: true,
            heightRatio: 0.86,
            onDismiss: () => {
              this.correctionOpen = false;
            },
            content: this.correctionContent
          })
        }
        if (this.feedbackOpen) {
          GlassSheet({
            show: true,
            heightRatio: 0.72,
            onDismiss: () => {
              this.feedbackOpen = false;
            },
            content: this.feedbackContent
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.BG)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
            { content: { label: '重新生成', icon: $r('sys.symbol.arrow_clockwise'), isEnabled: true, action: () => { PromptUtil.toast('已重新生成（Mock），此次画面与上次一致'); } } },
            { content: { label: '模拟失败', icon: $r('sys.symbol.xmark_circle'), isEnabled: true, action: () => { ComicRepository.get().loadFailed = true; this.pageState = PageState.ERROR; } } },
            { content: { label: '关于默默', icon: $r('sys.symbol.star'), isEnabled: true, action: () => { AppRouter.push(RouteName.ABOUT); } } }
          ]
        }
      }
    })
    .hideBackButton(false)
    .backgroundColor(Theme.BG)
  }
}