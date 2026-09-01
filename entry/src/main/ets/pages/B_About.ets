/*
 * ============================================================================
 * 文件名：pages/B_About.ets
 * ============================================================================
 * 【用途】二级页「关于默默」（HdsNavDestination）：项目介绍、开发者信息、
 *   使用的组件与技术、参考与致谢列表（外部链接为 Mock）。
 * 【前置条件 / 假设】
 *   - 依赖：HdsNavDestination（返回 + 沉浸标题）、MoMoAvatar、Theme；
 *   - 假设：全部为静态展示文本；链接点击仅 Toast（本轮不做外部跳转）。
 * 【输入 / 输出（后置条件）】
 *   - 输入：返回、点击参考条目；
 *   - 输出：滚动页面；Toast 提示（Mock）。
 * 【关键类 / 算法】
 *   - B_About：展示组件；section/refRow 为两枚 @Builder（信息卡/参考条目）。
 * 【参考源】
 *   - 本仓库 Examples(ArkUISample / ihbest-ui / HarmonyLearn) / Web_proj(grok-icon-study-web)
 * ============================================================================
 */
import { HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { Theme } from '../utils/Theme';
import { PromptUtil } from '../utils/PromptUtil';
import { MoMoAvatar } from '../components/MoMoAvatar';
import { MoMoState } from '../model/Models';

@Component
export struct B_About {
  @Builder
  section(title: string, body: string) {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.PRIMARY)
        .width('100%')
      Text(body)
        .fontSize(13)
        .fontColor(Theme.SECONDARY)
        .lineHeight(22)
        .width('100%')
        .padding(16)
        .borderRadius(18)
        .backgroundColor(Theme.CARD)
        .border({ width: 1, color: Theme.LINE })
    }
    .width('100%')
  }

  @Builder
  refRow(title: string, desc: string) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.PRIMARY)
        Text(desc)
          .fontSize(11)
          .fontColor(Theme.TERTIARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([Theme.TERTIARY])
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .borderRadius(14)
    .backgroundColor(Theme.CARD)
    .border({ width: 1, color: Theme.LINE })
    .margin({ bottom: 10 })
    .onClick(() => {
      PromptUtil.toast('外部链接本轮仅作展示（Mock）');
    })
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        Scroll() {
          Column({ space: 18 }) {
            Blank().height(28)
            Column({ space: 12 }) {
              Column() {
                MoMoAvatar({ avatarSize: 132, state: MoMoState.IDLE })
              }
              .width(150)
              .height(150)
              .borderRadius(75)
              .backgroundColor('rgba(151,255,171,0.22)')
              .justifyContent(FlexAlign.Center)
              .shadow({ radius: 26, color: 'rgba(98,217,127,0.35)', offsetY: 8 })

              Text('默默')
                .fontSize(26)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.PRIMARY)
              Text('MoMo · 会观察、会画画、会记住你的桌宠')
                .fontSize(12)
                .fontColor(Theme.TERTIARY)
              Row({ space: 8 }) {
                Text('v1.0.0')
                  .fontSize(11)
                  .fontColor('#FFFFFF')
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .borderRadius(11)
                  .backgroundColor(Theme.BRAND_DEEP)
                Text('第一轮 Mock UI')
                  .fontSize(11)
                  .fontColor(Theme.TERTIARY)
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .borderRadius(11)
                  .backgroundColor('#EFF5F0')
              }
            }
            .width('100%')
            .padding({ top: 24, bottom: 16 })

            this.section('项目介绍',
              '「默默」是一只基于 HarmonyOS 的 AI 桌宠：观察 -> 理解 -> 表达 -> 用户反馈 -> 纠正 -> 积累 -> 再次观察。' +
              '默默会在用户授权范围内阅读日历、待办、备忘录等（本轮为 Mock），通过漫画、动作与低频互动表达陪伴，并通过长期记忆逐渐理解用户。')

            this.section('开发者信息',
              '产品与设计：MoMo 项目组' + String.fromCharCode(10) + '开发：HarmonyOS / ArkUI 工程团队' + String.fromCharCode(10) + '版本：1.0.0（第一轮 UI 工程迭代）')

            this.section('使用的组件与技术',
              'HarmonyOS NEXT · ArkUI · ArkTS' + String.fromCharCode(10) + '沉浸式标题栏与滚动渐变模糊（HdsNavigation / 标准 ArkUI 组合实现）' + String.fromCharCode(10) +
              'Canvas 程序化软体角色动画 · 定制玻璃质感浮窗与底部导航' + String.fromCharCode(10) + 'Mock Repository 架构：UI -> Repository -> Mock Data')

            Column({ space: 10 }) {
              Text('参考与致谢')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.PRIMARY)
                .width('100%')
              this.refRow('grok-icon-study-web（角色动画参考）',
                'spring 驱动的 39 状态软体角色引擎学习项目 · MIT License')
              this.refRow('HarmonyOS ArkUISample（官方样例）',
                'Navigation / Canvas / ArkUI 组件样例')
              this.refRow('HarmonyLearn（知识图谱绘制参考）',
                '本项目中记忆树模式的图谱绘制思路来源')
              this.refRow('ibest-ui / 液态玻璃设计语言',
                '浮窗与日历等交互样式的设计参考')
            }
            .width('100%')

            Text('默默参考了 grok-icon-study 开源项目的角色动画思路，本应用与 xAI / Grok 无任何关联。')
              .fontSize(10)
              .fontColor(Theme.TERTIARY)
              .lineHeight(17)
              .width('100%')
              .padding({ top: 4 })

            Blank().height(60)
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
          mainTitle: '关于默默'
        }
      }
    })
    .hideBackButton(false)
    .backgroundColor(Theme.BG)
  }
}