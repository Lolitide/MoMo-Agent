import router from '@ohos.router';
import { PersonalityProfile } from '../model/Models';
import { UserRepository } from '../repository/Repositories';
import { OnboardingService } from '../service/OnboardingService';
import { Theme } from '../utils/Theme';
import { PromptUtil } from '../utils/PromptUtil';

@Entry
@Component
struct OnboardingProfilePage {
  @State step: number = 0;
  @State tone: string = '温柔';
  @State pace: string = '少打扰';
  @State comicStyle: string = '清新日常';
  @State focusTopic: string = '生活';
  @State saving: boolean = false;
  @State isEditing: boolean = false;

  private tones: string[] = ['安静', '温柔', '元气'];
  private paces: string[] = ['少打扰', '适度提醒'];
  private styles: string[] = ['清新日常', '暖色手账', '轻松夸张'];
  private topics: string[] = ['学习', '生活', '兴趣', '目标'];

  private selectOption(kind: number, value: string): void {
    if (kind === 0) {
      this.tone = value;
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

  aboutToAppear(): void {
    UserRepository.get().load().then((user) => {
      if (user.profileCompleted) {
        this.isEditing = true;
        this.tone = user.profile.tone;
        this.pace = user.profile.pace;
        this.comicStyle = user.profile.comicStyle;
        this.focusTopic = user.profile.focusTopics.length > 0 ? user.profile.focusTopics[0] : '生活';
      }
    });
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
      const userId = await OnboardingService.get().getCurrentUserId();
      if (!this.isEditing) {
        await OnboardingService.get().resetGuide(userId);
      }
      router.pushUrl({ url: 'pages/MainPage' });
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
        .borderRadius(16)
        .backgroundColor(this.isSelected(kind, item) ? '#E9F7EC' : Theme.CARD)
        .border({ width: 1, color: this.isSelected(kind, item) ? Theme.BRAND_DEEP : Theme.LINE })
        .hitTestBehavior(HitTestMode.Default)
        .onClick(() => this.selectOption(kind, item))
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
      }, (item: string) => item)
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
      }
    } else if (this.step === 1) {
      Column({ space: 16 }) {
        Text('保持怎样的互动节奏？').fontSize(Theme.fontSize(25)).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
        Text('默默会按这个节奏提醒你，也会影响每日总结的语气。').fontSize(Theme.fontSize(14)).fontColor(Theme.SECONDARY)
        this.optionList(this.paces, 1)
      }
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
              .padding({ left: 14, right: 14, top: 9, bottom: 9 }).borderRadius(18)
              .backgroundColor(topic === this.focusTopic ? Theme.BRAND_DEEP : '#EEF3EE')
              .hitTestBehavior(HitTestMode.Default)
              .onClick(() => this.selectOption(3, topic))
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
          }, (topic: string) => topic)
        }
      }
    }
  }

  build() {
    Column() {
      Row() {
        Text('默默的陪伴档案').fontSize(Theme.fontSize(18)).fontWeight(FontWeight.Medium).fontColor(Theme.PRIMARY).layoutWeight(1)
        Text(`${this.step + 1}/3`).fontSize(Theme.fontSize(13)).fontColor(Theme.TERTIARY)
      }
      .width('100%').padding({ left: 22, right: 22, top: 22, bottom: 16 })

      Column() {
        this.currentStep()
      }
      .width('100%').layoutWeight(1).padding({ left: 22, right: 22, top: 28 })
      .alignItems(HorizontalAlign.Start)

      Row({ space: 12 }) {
        if (this.step > 0) {
          Button('返回').height(50).layoutWeight(1).backgroundColor('#EEF3EE').fontColor(Theme.PRIMARY)
            .onClick(() => { this.step -= 1; })
        }
        Button(this.step === 2 ? '完成档案' : '继续').height(50).layoutWeight(1)
          .backgroundColor(Theme.BRAND_DEEP).fontColor('#FFFFFF').enabled(!this.saving)
          .onClick(() => {
            if (this.step < 2) {
              this.step += 1;
            } else {
              this.finish();
            }
          })
      }
      .width('100%').padding({ left: 22, right: 22, top: 12, bottom: 28 })
    }
    .width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
