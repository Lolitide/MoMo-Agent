/*
 * ============================================================================
 * 文件名：pages/OnboardingProfilePage.ets
 * ============================================================================
 * 【用途】「默默的陪伴档案」三步设置，作为 HDS 子页面（HdsNavDestination）：
 *   - 第 1 步 陪伴语气（安静 / 温柔 / 元气）+ 每种语气对应的 AI 输出样例文本；
 *   - 第 2 步 互动节奏（少打扰 / 适度提醒）；
 *   - 第 3 步 每日漫画风格 + 关注主题；
 *   - 底部按钮统一胶囊形：第 1 步「继续」，第 2/3 步「上一个 / 下一个」。
 * 【前置条件 / 假设】
 *   - 依赖：HdsNavDestination(UIDesignKit)、UserRepository、OnboardingService、Theme；
 *   - 由调用方压入各自 NavPathStack：LoginPage（首次体验，isFirstRun=true）或
 *     MainPage（设置页「陪伴档案」编辑，isFirstRun=false）；
 *   - 假设标题栏承担状态栏避让，页面内容不需要任何顶部绝对占位；
 *     NavPathStack 存在时 HDS 自动给出返回键。
 * 【输入 / 输出（后置条件）】
 *   - 输入：选项点击、上一个 / 下一个 / 返回；
 *   - 输出：最后一步保存 PersonalityProfile 到 UserRepository（profileCompleted=true）；
 *     首次体验回调 onNext（进入教程页）/ 编辑态回调 onFinish（返回设置页）。
 * 【关键类 / 算法】
 *   - currentStep：按 this.step 分支渲染三步内容；
 *   - toneSampleOf：语气 -> 样例文本（帮助用户理解语气差异）；
 *   - optionList：通用选项卡（选中态描边 + 勾选圆点）。
 * 【参考源】
 *   - Examples/hdsNavigation Examples.md；pages/B_About.ets（HdsNavDestination 用法）
 * ============================================================================
 */
import { HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { PersonalityProfile } from '../model/Models';
import { UserRepository } from '../repository/Repositories';
import { Theme } from '../utils/Theme';
import { PromptUtil } from '../utils/PromptUtil';

@Component
export struct OnboardingProfilePage {
  // true：首次体验流程（最后一步 -> 教程页）；false：设置页进入的编辑态（最后一步 -> 返回）
  @Prop isFirstRun: boolean = false;
  onNext: () => void = () => {
  };
  onFinish: () => void = () => {
  };

  @State step: number = 0;
  @State tone: string = '温柔';
  @State pace: string = '少打扰';
  @State comicStyle: string = '清新日常';
  @State focusTopic: string = '生活';
  @State saving: boolean = false;
  // 语气样例卡：一次只展示一条，随上面的语气按钮切换
  @State sampleTone: string = '温柔';
  @State sampleBlur: number = 0;
  @State sampleOpacity: number = 1;

  private tones: string[] = ['安静', '温柔', '元气'];
  private paces: string[] = ['少打扰', '适度提醒'];
  private styles: string[] = ['清新日常', '暖色手账', '轻松夸张'];
  private topics: string[] = ['学习', '生活', '兴趣', '目标'];
  private stepDots: number[] = [0, 1, 2];

  // 语气 -> 默默的真实输出样例（让用户在选之前就听到差别）
  private toneSampleOf(tone: string): string {
    if (tone === '安静') {
      return '「今天的三件事都记好了。不用急着说给谁听，我在就行。」';
    }
    if (tone === '元气') {
      return '「今天全部完成啦！三件事都进花园了，明天接着冲！」';
    }
    return '「我把今天的事都收好了。你有点累，记得早点休息。」';
  }

  // 切换样例语气：先模糊淡出，换掉文本后再模糊淡入
  private switchSample(next: string): void {
    if (next === this.sampleTone) {
      return;
    }
    animateTo({
      duration: 160,
      curve: Curve.EaseIn,
      onFinish: () => {
        this.sampleTone = next;
        animateTo({
          duration: 300,
          curve: Curve.Friction
        }, () => {
          this.sampleBlur = 0;
          this.sampleOpacity = 1;
        });
      }
    }, () => {
      this.sampleBlur = 14;
      this.sampleOpacity = 0;
    });
  }

  private selectOption(kind: number, value: string): void {
    if (kind === 0) {
      this.tone = value;
      // 样例文本跟着语气切换（模糊过渡）
      this.switchSample(value);
    } else if (kind === 1) {
      this.pace = value;
    } else if (kind === 2) {
      this.comicStyle = value;
    } else {
      this.focusTopic = value;
    }
  }

  private isSelected(kind: number, value: string): boolean {
    if (kind === 0) {
      return this.tone === value;
    } else if (kind === 1) {
      return this.pace === value;
    } else if (kind === 2) {
      return this.comicStyle === value;
    }
    return this.focusTopic === value;
  }

  // 底部主按钮文案：第 1 步「继续」；第 2/3 步「下一个」；编辑态最后一步「完成」
  private forwardLabel(): string {
    if (this.step === 0) {
      return '继续';
    }
    if (this.step === 2 && !this.isFirstRun) {
      return '完成';
    }
    return '下一个';
  }

  aboutToAppear(): void {
    UserRepository.get().load().then((user) => {
      if (user.profileCompleted) {
        this.tone = user.profile.tone;
        this.pace = user.profile.pace;
        this.comicStyle = user.profile.comicStyle;
        this.focusTopic = user.profile.focusTopics.length > 0 ? user.profile.focusTopics[0] : '生活';
        // 样例卡直接落在已保存的语气上（不做动画）
        this.sampleTone = this.tone;
      }
    });
  }

  private goForward(): void {
    if (this.step < 2) {
      this.step += 1;
      return;
    }
    this.finish();
  }

  private async finish(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    try {
      const profile = new PersonalityProfile();
      profile.tone = this.tone;
      profile.pace = this.pace;
      profile.comicStyle = this.comicStyle;
      profile.focusTopics = [this.focusTopic];
      profile.version = 1;
      await UserRepository.get().saveProfile(profile);
      // 区分两种出口：首次体验继续去教程页；编辑态保存后回设置页
      if (this.isFirstRun) {
        this.onNext();
      } else {
        PromptUtil.toast('陪伴档案已更新');
        this.onFinish();
      }
    } catch (err) {
      PromptUtil.toast('档案保存失败，请重试');
    } finally {
      this.saving = false;
    }
  }

  @Builder
  optionList(items: string[], kind: number) {
    Column({ space: 12 }) {
      ForEach(items, (item: string) => {
        Button() {
          Row({ space: 12 }) {
            Stack() {
              Column().width(22).height(22).borderRadius(11)
                .backgroundColor(this.isSelected(kind, item) ? Theme.BRAND_DEEP : '#EEF3EE')
              if (this.isSelected(kind, item)) {
                SymbolGlyph($r('sys.symbol.checkmark')).fontSize(Theme.fontSize(14)).fontColor(['#FFFFFF'])
              }
            }
            .width(22)
            .height(22)
            Text(item)
              .fontSize(Theme.fontSize(16))
              .fontColor(Theme.PRIMARY)
              .layoutWeight(1)
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
        }
        .type(ButtonType.Normal)
        .width('100%')
        .height(58)
        .padding({ left: 16, right: 16 })
        .borderRadius(18)
        .backgroundColor(this.isSelected(kind, item) ? '#E9F7EC' : Theme.CARD)
        .border({ width: 1, color: this.isSelected(kind, item) ? Theme.BRAND_DEEP : Theme.LINE })
        .hitTestBehavior(HitTestMode.Default)
        .onClick(() => this.selectOption(kind, item))
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
      }, (item: string) => item)
    }
    .width('100%')
  }

  // 第 1 步底部：只显示当前语气对应的 AI 输出样例，随上面的语气按钮切换（模糊过渡）
  @Builder
  toneSample() {
    Column({ space: 10 }) {
      Text('默默会这样和你说话')
        .fontSize(Theme.fontSize(14))
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.PRIMARY)
        .width('100%')
        .margin({ top: 4 })

      Column({ space: 8 }) {
        Row() {
          Text(this.sampleTone)
            .fontSize(Theme.fontSize(12))
            .fontColor('#FFFFFF')
            .padding({ left: 10, right: 10, top: 3, bottom: 3 })
            .borderRadius(11)
            .backgroundColor(Theme.BRAND_DEEP)
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)

        // 固定两行高度：换文本时卡片高度不跳动
        Text(this.toneSampleOf(this.sampleTone))
          .fontSize(Theme.fontSize(14))
          .fontColor(Theme.PRIMARY)
          .lineHeight(23)
          .height(46)
          .maxLines(2)
          .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .borderRadius(18)
      .backgroundColor('#E9F7EC')
      .border({ width: 1, color: Theme.BRAND_DEEP })
      // 切换语气的模糊过渡：blur 拉高 + 淡出 -> 换文本 -> 去模糊淡入
      .blur(this.sampleBlur)
      .opacity(this.sampleOpacity)
    }
    .width('100%')
  }

  @Builder
  currentStep() {
    if (this.step === 0) {
      Column({ space: 16 }) {
        Text('你希望默默怎么陪你？').fontSize(Theme.fontSize(25)).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
        Text('先选一种陪伴语气，之后也可以在设置里修改。').fontSize(Theme.fontSize(14)).fontColor(Theme.SECONDARY)
        this.optionList(this.tones, 0)
        this.toneSample()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    } else if (this.step === 1) {
      Column({ space: 16 }) {
        Text('保持怎样的互动节奏？').fontSize(Theme.fontSize(25)).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
        Text('默默会按这个节奏提醒你，也会影响每日总结的语气。').fontSize(Theme.fontSize(14)).fontColor(Theme.SECONDARY)
        this.optionList(this.paces, 1)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    } else {
      Column({ space: 16 }) {
        Text('你喜欢哪种每日漫画？').fontSize(Theme.fontSize(25)).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
        Text('选择一个画面风格，再告诉默默今天更关注什么。').fontSize(Theme.fontSize(14)).fontColor(Theme.SECONDARY)
        this.optionList(this.styles, 2)
        Text('关注主题').fontSize(Theme.fontSize(14)).fontWeight(FontWeight.Medium).fontColor(Theme.PRIMARY).margin({ top: 8 })
        Row({ space: 8 }) {
          ForEach(this.topics, (topic: string) => {
            Button(topic, { type: ButtonType.Normal })
              .fontSize(Theme.fontSize(13)).fontColor(topic === this.focusTopic ? '#FFFFFF' : Theme.SECONDARY)
              .padding({ left: 14, right: 14, top: 9, bottom: 9 }).borderRadius(Theme.RADIUS_PILL)
              .backgroundColor(topic === this.focusTopic ? Theme.BRAND_DEEP : '#EEF3EE')
              .hitTestBehavior(HitTestMode.Default)
              .onClick(() => this.selectOption(3, topic))
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
          }, (topic: string) => topic)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  // 步骤进度：三段进度条 + 第几步
  @Builder
  progressRow() {
    Row({ space: 12 }) {
      Row({ space: 6 }) {
        ForEach(this.stepDots, (i: number) => {
          Row()
            .height(6)
            .layoutWeight(1)
            .borderRadius(3)
            .backgroundColor(i <= this.step ? Theme.BRAND_DEEP : '#E4EDE4')
        }, (i: number) => 'seg' + i)
      }
      .layoutWeight(1)

      Text(`${this.step + 1} / 3`)
        .fontSize(Theme.fontSize(12))
        .fontColor(Theme.TERTIARY)
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 8, bottom: 4 })
  }

  // 底部操作条：胶囊按钮（第 2/3 步为「上一个 / 下一个」）
  @Builder
  bottomBar() {
    Row({ space: 12 }) {
      if (this.step > 0) {
        Button('上一个', { type: ButtonType.Normal })
          .height(52)
          .layoutWeight(1)
          .fontSize(Theme.fontSize(16))
          .fontColor(Theme.PRIMARY)
          .backgroundColor('#EEF3EE')
          .borderRadius(Theme.RADIUS_PILL)
          .onClick(() => {
            this.step -= 1;
          })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
      }
      Button(this.forwardLabel(), { type: ButtonType.Normal })
        .height(52)
        .layoutWeight(1)
        .fontSize(Theme.fontSize(16))
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor(Theme.BRAND_DEEP)
        .borderRadius(Theme.RADIUS_PILL)
        .enabled(!this.saving)
        .opacity(this.saving ? 0.6 : 1.0)
        .onClick(() => {
          this.goForward();
        })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 12, bottom: 28 })
  }

  build() {
    HdsNavDestination() {
      Column() {
        // 顶部占位：HDS 标题栏悬浮在内容之上（avoidLayoutSafeArea），
        // 内容若不留出状态栏 + 标题栏高度会被压在标题栏下面。取 100vp 与 B_About 一致。
        Row().width('100%').height(100)
        this.progressRow()

        Scroll() {
          Column() {
            this.currentStep()
            Row().width('100%').height(20)
          }
          .width('100%')
          .padding({ left: 22, right: 22, top: 12 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.TopStart)

        this.bottomBar()
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
          mainTitle: '默默的陪伴档案'
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
