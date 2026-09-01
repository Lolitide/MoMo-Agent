/*
 * ============================================================================
 * 文件名：components/Sheets.ets
 * ============================================================================
 * 【用途】三个业务浮窗内容组件（配合 GlassSheet/bindSheet 使用）：
 *   AddSheetContent（“记一笔”，说给默默/撤回重做/记下以前/默默记下）、
 *   CorrectionSheetContent（纠正默默的理解，文本区+批量纠正/重新生成）、
 *   FeedbackSheetContent（1-5 星反馈+留言+默默回应）。
 * 【前置条件 / 假设】
 *   - 依赖：Theme、PromptUtil、MoMoAvatar、MoMoState；
 *   - 假设：内容组件只维护自身表单状态（text/rating），决策权交给上层回调。
 * 【输入 / 输出（后置条件）】
 *   - 输入：用户输入文本/评分/点击按钮；
 *   - 输出：Add -> onDone(text)/onDismiss；纠正 -> onApply(text)/onDismiss；
 *     反馈 -> onSubmit(score,msg)/onDismiss。
 * 【关键类 / 算法】
 *   - form 状态驱动：文字校验（空文本拦截 Toast）；评分点星逻辑（再次点击取消）。
 * 【参考源】
 *   - MoMo_DOC/UI 参考图（记录浮窗/纠正/反馈）；iBest-UI 输入区样式
 * ============================================================================
 */
import { Theme } from '../utils/Theme';
import { PromptUtil } from '../utils/PromptUtil';
import { MoMoAvatar } from './MoMoAvatar';
import { MoMoState } from '../model/Models';

@Component
// “记一笔”表单：voiceOn 控制语音胶囊高亮；文本为空则拦截“默默记下”并提示
export struct AddSheetContent {
  @Prop userName: string = '酪酪肽';
  onDismiss: () => void = () => {};
  onDone: (kind: string) => void = (kind: string) => {};
  @State text: string = '';
  @State voiceOn: boolean = true;

  build() {
    Column() {
      // 标题行：标题 + 单个关闭按钮（×）
      Row() {
        Text('今天想说点啥？')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_MAIN)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 8 })

      // 输入卡片：文本区 + 底部内嵌操作行（说给默默 / 撤销重做单胶囊）
      Column() {
        TextArea({
          text: this.text,
          placeholder: this.userName + ', 记录下此刻的感受吧...'
        })
          .fontSize(12)
          .fontColor(Theme.TEXT_MAIN)
          .height(200)
          .backgroundColor('rgba(0,0,0,0)')
          .padding({ left: 6, right: 6, top: 2 })
          .onChange((v: string) => {
            this.text = v;
          })

        Row() {
          // 说给默默：语音胶囊
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.mic')).fontSize(15)
              .fontColor([this.voiceOn ? '#3E6B4B' : Theme.TEXT_TERTIARY])
            Text('说给默默')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.voiceOn ? '#3E6B4B' : Theme.TEXT_TERTIARY)
          }
          .height(40)
          .padding({ left: 16, right: 16 })
          .borderRadius(20)
          .backgroundColor(this.voiceOn ? 'rgba(151,255,171,0.30)' : '#F2F4F1')
          .onClick(() => {
            this.voiceOn = !this.voiceOn;
            PromptUtil.toast(this.voiceOn ? '默默在听…' : '已取消说话');
          })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })

          // 撤销 / 重做：单枚胶囊（整组一体，符合设计稿）
          Row({ space: 14 }) {
            SymbolGlyph($r('sys.symbol.arrow_counterclockwise')).fontSize(16).fontColor([Theme.TEXT_SUB])
              .onClick(() => {
                PromptUtil.toast('已撤回上一步输入');
              })
            SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(16).fontColor([Theme.TEXT_SUB])
              .onClick(() => {
                PromptUtil.toast('已重做下一步输入');
              })
          }
          .height(40)
          .width(96)
          .borderRadius(20)
          .backgroundColor('rgba(0,0,0,0.04)')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 10 })
      }
      .width('90%')
      .padding(16)
      .borderRadius(24)
      .backgroundColor('#FFFFFF')
      .border({ width: 1, color: Theme.CARD_BORDER })
      .shadow({ radius: 14, color: 'rgba(38,61,42,0.05)', offsetY: 4 })
      .margin({ left: 18, right: 18, top: 16 })

      // 底部主操作：记下以前（橙）/ 默默记下（绿）
      Row({ space: 14 }) {
        Button() {
          Text('记下以前')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#5C4A2E')
        }
        .backgroundColor(Theme.ACCENT_ORANGE)
        .height(54)
        .layoutWeight(1)
        .borderRadius(20)
        .onClick(() => {
          PromptUtil.toast('「记下以前」将在后续版本接入（Mock）');
        })

        Button() {
          Text('默默记下')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1E3A26')
        }
        .backgroundColor(Theme.ACCENT_GREEN)
        .height(54)
        .layoutWeight(1)
        .borderRadius(20)
        .onClick(() => {
          if (this.text.trim().length === 0) {
            PromptUtil.toast('先对默默说点什么吧');
            return;
          }
          this.onDone(this.text);
        })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 26 })
    }
    .width('100%')
  }
}

@Component
export struct CorrectionSheetContent {
  @Prop originalText: string = '默默认为你今天的心情总体平稳，但下午可能有些疲惫。';
  onDismiss: () => void = () => {};
  onApply: (text: string) => void = (text: string) => {};
  @State text: string = '';

  build() {
    Column() {
      // 标题行：图标 + 标题 + 单个 ×
      Row() {
        Column() {
          Stack() {
            Column().width(40).height(40).borderRadius(999).backgroundColor('rgba(151,255,171,0.25)')
            SymbolGlyph($r('sys.symbol.doc_rectify')).fontSize(20).fontColor([Theme.BRAND_DEEP])
          }
        }
        .width(40)
        .height(40)
        Text('纠正')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_MAIN)
          .layoutWeight(1)
          .margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 8 })

      // 默默原来的理解
      Column({ space: 8 }) {
        Text('默默原来的理解')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_MAIN)
          .width('100%')
        Column() {
          Text(this.originalText)
            .fontSize(14)
            .fontColor(Theme.TEXT_SUB)
            .lineHeight(22)
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .borderRadius(20)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: Theme.CARD_BORDER })
      }
      .width('100%')
      .padding({ left: 22, right: 22 })
      .margin({ top: 14 })

      // 你的真实想法
      Column({ space: 8 }) {
        Text('你的真实想法')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_MAIN)
          .width('100%')
        Column() {
          TextArea({
            text: this.text,
            placeholder: '把真实的理解写在这里……'
          })
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .height(150)
            .backgroundColor('rgba(0,0,0,0)')
            .padding({ left: 4, right: 4, top: 2 })
            .onChange((v: string) => {
              this.text = v;
            })
        }
        .width('100%')
        .padding(16)
        .borderRadius(20)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: Theme.CARD_BORDER })
      }
      .width('100%')
      .padding({ left: 22, right: 22 })
      .margin({ top: 12 })

      // 底部按钮（与添加页一致：54 高、20 圆角、两侧留白）
      Row({ space: 14 }) {
        Button() {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.checkmark_square')).fontSize(17).fontColor(['#1E3A26'])
            Text('批量纠正').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#1E3A26')
          }
        }
        .backgroundColor(Theme.ACCENT_GREEN)
        .height(54)
        .layoutWeight(1)
        .borderRadius(20)
        .onClick(() => {
          this.onApply(this.text);
        })

        Button() {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(17).fontColor(['#FFFFFF'])
            Text('重新生成').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
          }
        }
        .backgroundColor('#2C9C4E')
        .height(54)
        .layoutWeight(1)
        .borderRadius(20)
        .onClick(() => {
          PromptUtil.toast('已重新生成（Mock），观点未变化');
        })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 26 })
    }
    .width('100%')
  }
}

@Component
export struct FeedbackSheetContent {
  onDismiss: () => void = () => {};
  onSubmit: (score: number, msg: string) => void = (score: number, msg: string) => {};
  @State score: number = 0;
  @State msg: string = '';

  build() {
    Column() {
      // 标题行：图标 + 标题 + 单个 ×
      Row() {
        Column() {
          Stack() {
            Column().width(40).height(40).borderRadius(999).backgroundColor('rgba(255,203,105,0.22)')
            SymbolGlyph($r('sys.symbol.star')).fontSize(20).fontColor(['#E8A33D'])
          }
        }
        .width(40)
        .height(40)
        Text('反馈')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_MAIN)
          .layoutWeight(1)
          .margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 8 })

      // 打分
      Column({ space: 8 }) {
        Text('为默默的理解打分')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_MAIN)
          .width('100%')
        Row({ space: 12 }) {
          ForEach([1, 2, 3, 4, 5], (n: number) => {
            SymbolGlyph(this.score >= n ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
              .fontSize(34)
              .fontColor([this.score >= n ? '#F5B23C' : '#D8E0D9'])
              .onClick(() => {
                if (this.score === n) {
                  this.score = 0;
                } else {
                  this.score = n;
                }
              })
          }, (n: number) => n.toString())
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 8, bottom: 10 })
      }
      .width('100%')
      .padding({ left: 22, right: 22 })
      .margin({ top: 14 })

      // 留言
      Column({ space: 8 }) {
        Text('留言（可选）')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_MAIN)
          .width('100%')
        Column() {
          TextArea({
            text: this.msg,
            placeholder: '还想对默默说什么？'
          })
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .height(110)
            .backgroundColor('rgba(0,0,0,0)')
            .padding({ left: 4, right: 4, top: 2 })
            .onChange((v: string) => {
              this.msg = v;
            })
        }
        .width('100%')
        .padding(16)
        .borderRadius(20)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: Theme.CARD_BORDER })
      }
      .width('100%')
      .padding({ left: 22, right: 22 })
      .margin({ top: 12 })

      // 提交：默默形象 + 主按钮
      Row({ space: 14 }) {
        Column() {
          MoMoAvatar({ avatarSize: 64, state: MoMoState.HAPPY })
        }
        .width(64)
        .height(64)
        .borderRadius(32)
        .backgroundColor('rgba(151,255,171,0.18)')
        .justifyContent(FlexAlign.Center)

        Button() {
          Text('默默记住了')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1E3A26')
        }
        .backgroundColor(Theme.ACCENT_GREEN)
        .height(54)
        .layoutWeight(1)
        .borderRadius(20)
        .onClick(() => {
          if (this.score === 0) {
            PromptUtil.toast('先给默默点一颗星吧');
            return;
          }
          this.onSubmit(this.score, this.msg);
        })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 26 })
    }
    .width('100%')
  }
}
