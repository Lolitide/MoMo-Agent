/*
 * ============================================================================
 * 文件名：pages/OnboardingTutorialPage.ets
 * ============================================================================
 * 【用途】首次体验流程的最后一页：左右滑动浏览三张使用教程图，看完后结束引导。
 *   内容主体 = Swiper（一屏一张整屏教程图）+ 自绘指示点 + 胶囊按钮「开始使用默默」。
 * 【前置条件 / 假设】
 *   - 依赖：HdsNavDestination(UIDesignKit)、Theme、
 *     resources/base/media/tutorial_1.png ~ tutorial_3.png（设计侧产出的整屏教程图）；
 *   - 由 LoginPage 压入 NavPathStack，作为 OnboardingProfilePage 的下一页；
 *   - 教程图按 ImageFit.Contain 适配任意宽高比，不裁切；
 *   - 假设标题栏承担状态栏避让，页面内容顶部留 100vp 占位（与 B_About 一致）。
 * 【输入 / 输出（后置条件）】
 *   - 输入：左右滑动切页、按钮点击；
 *   - 输出：回调 onFinish()（由 LoginPage 执行 router.replaceUrl('pages/MainPage')，
 *     用户不会通过返回键回到引导流程）。
 * 【关键类 / 算法】
 *   - tutorialPages：三张教程图的资源数组；
 *   - page：当前页下标，Swiper onChange 回写，用于点亮指示点；
 *   - 指示点自绘（Swiper .indicator(false)），选中项拉长成胶囊，与项目其它页面一致。
 * 【参考源】
 *   - pages/B_DailyComic.ets（Swiper + 自绘指示点）；Examples/hdsNavigation Examples.md
 * ============================================================================
 */
import { HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { Theme } from '../utils/Theme';

@Component
export struct OnboardingTutorialPage {
  onFinish: () => void = () => {
  };

  @State page: number = 0;
  private tutorialPages: Resource[] = [
    $r('app.media.tutorial_1'),
    $r('app.media.tutorial_2'),
    $r('app.media.tutorial_3')
  ];
  private pageDots: number[] = [0, 1, 2];

  // 底部指示点：选中项拉长成胶囊；点一下也能直接跳到那一页
  @Builder
  dots() {
    Row() {
      ForEach(this.pageDots, (i: number) => {
        Row() {
          Row()
            .width(i === this.page ? 18 : 6)
            .height(6)
            .borderRadius(3)
            .backgroundColor(i === this.page ? Theme.BRAND_DEEP : '#D5E2D7')
            .animation({ duration: 200, curve: Curve.EaseOut })
        }
        .width(34)
        .height(30)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.page = i;
        })
      }, (i: number) => 'dot' + i)
    }
    .height(28)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    HdsNavDestination() {
      Column() {
        // 顶部占位：HDS 标题栏悬浮在内容之上（avoidLayoutSafeArea），
        // 内容若不留出状态栏 + 标题栏高度会被压在标题栏下面。取 100vp 与 B_About 一致。
        Row().width('100%').height(100)

        Swiper() {
          ForEach(this.tutorialPages, (item: Resource, index: number) => {
            Image(item)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .borderRadius(Theme.RADIUS_CARD)
          }, (item: Resource, index: number) => 'tutorial' + index)
        }
        .layoutWeight(1)
        .index(this.page)
        .loop(false)
        .indicator(false)
        .duration(300)
        .curve(Curve.EaseInOut)
        .itemSpace(12)
        .onChange((index: number) => {
          this.page = index;
        })

        this.dots()

        Row() {
          Button('开始使用默默', { type: ButtonType.Normal })
            .height(52)
            .layoutWeight(1)
            .fontSize(Theme.fontSize(16))
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor(Theme.BRAND_DEEP)
            .borderRadius(Theme.RADIUS_PILL)
            .onClick(() => {
              this.onFinish();
            })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 12, bottom: 28 })
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
          mainTitle: '使用教程'
        }
      },
      avoidLayoutSafeArea: true
    })
    .systemBarStyle(
      { statusBarContentColor: '#1E2A22' },
      { statusBarContentColor: '#1E2A22' }
    )
    .backgroundColor(Theme.BG)
  }
}
