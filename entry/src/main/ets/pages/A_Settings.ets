/*
 * ============================================================================
 * 文件名：pages/A_Settings.ets
 * ============================================================================
 * 【用途】一级 Tab「设置」：外观与个性化（主题色/深色模式/字体大小/低打扰）、
 *   隐私与安全性（日历/待办/备忘录/相机权限开关）、记忆内容管理（清空/恢复示例）、
 *   关于入口（跳 B_About）。全部为 Mock 交互（Toast 反馈）。
 * 【前置条件 / 假设】
 *   - 依赖：SettingsService（本地 Mock 设置项）、SettingRows 组件、TabController、
 *     MemoryRepository（清空/恢复示例数据）、ShellState.settingsScroller；
 *   - 假设：本轮不申请真实权限，仅切换 UI 状态并 Toast。
 * 【输入 / 输出（后置条件）】
 *   - 输入：开关点击、主题色/字号选择、行点击、AlertDialog 确认；
 *   - 输出：@State 同步 + 写入 SettingsService；清空/恢复数据仓库；跳转花园/关于。
 * 【关键类 / 算法】
 *   - A_Settings：设置页组件；clearAll：AlertDialog 二次确认后 MemoryRepository.clearAll()。
 * 【参考源】
 *   - MoMo_DOC/UI 参考图（设置页）；iBest-UI 设置行样式
 * ============================================================================
 */
import { AppRouter, RouteName } from '../router/AppRouter';
import { MemoryRepository } from '../repository/Repositories';
import { SettingsService, TabController, ShellState } from '../service/Services';
import { Theme } from '../utils/Theme';
import { PromptUtil } from '../utils/PromptUtil';
import { SettingSwitchRow, SettingNavRow } from '../components/SettingRows';

@Component
export struct A_Settings {
  private settings: SettingsService = SettingsService.get();
  @State darkOn: boolean = false;
  @State largeFont: boolean = false;
  @State readCal: boolean = true;
  @State readTodo: boolean = true;
  @State readMemo: boolean = false;
  @State camera: boolean = false;
  @State lowInterrupt: boolean = true;
  @State themeIdx: number = 0;
  private scroller: Scroller = ShellState.settingsScroller;
  private themeColors: string[] = ['#97FFAB', '#9AC8FF', '#FFC98A'];
  private themeNames: string[] = ['默绿', '晴空', '暖阳'];

  aboutToAppear(): void {
    this.darkOn = this.settings.darkMode;
    this.largeFont = this.settings.largeFont;
    this.readCal = this.settings.readCalendar;
    this.readTodo = this.settings.readTodo;
    this.readMemo = this.settings.readMemo;
    this.camera = this.settings.cameraAccess;
    this.lowInterrupt = this.settings.lowInterrupt;
  }

  private clearAll(): void {
    AlertDialog.show({
      title: '清除记忆数据',
      message: '将清除花园、大纲、记忆树中的全部 Mock 记忆，此操作不可恢复。',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '清除',
        fontColor: '#E5533D',
        action: () => {
          MemoryRepository.get().clearAll();
          PromptUtil.toast('已清空记忆数据（Mock）');
        }
      }
    });
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll(this.scroller) {
        Column({ space: 18 }) {
          Blank().height(118)

          // ============ 外观与个性化 ============
          Column({ space: 10 }) {
            Text('外观与个性化')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.PRIMARY)
              .width('100%')
              .padding({ left: 4 })
            Column({ space: 0 }) {
              Row({ space: 10 }) {
                Stack() {
                  Column().width(38).height(38).borderRadius(999).backgroundColor('#EDF6EF')
                  SymbolGlyph($r('sys.symbol.paintpalette')).fontSize(18).fontColor([Theme.BRAND_DEEP])
                }
                Column({ space: 2 }) {
                  Text('主题色')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.PRIMARY)
                  Text('选择默默的主色调')
                    .fontSize(11)
                    .fontColor(Theme.TERTIARY)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Row({ space: 8 }) {
                  ForEach(this.themeColors, (c: string, i: number) => {
                    Column() {
                      Stack() {
                        Column().width(24).height(24).borderRadius(999).backgroundColor(c)
                        if (this.themeIdx === i) {
                          Column().width(24).height(24).borderRadius(999)
                            .backgroundColor('rgba(0,0,0,0)')
                            .border({ width: 2, color: Theme.PRIMARY })
                          SymbolGlyph($r('sys.symbol.checkmark')).fontSize(12).fontColor(['#23402B'])
                        }
                      }
                    }
                    .width(24)
                    .height(24)
                    .onClick(() => {
                      this.themeIdx = i;
                      this.settings.themeColor = c;
                      PromptUtil.toast('主题色已切换为「' + this.themeNames[i] + '」（Mock）');
                    })
                  }, (c: string) => c)
                }
              }
              .width('100%')
              .height(62)
              .padding({ left: 14, right: 14 })
              Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 64, right: 14 })
              SettingSwitchRow({
                icon: $r('sys.symbol.moon_z'),
                title: '深色模式',
                desc: '让默默在晚上也舒服一点',
                isOn: this.darkOn,
                onChange: (on: boolean) => {
                  this.darkOn = on;
                  this.settings.darkMode = on;
                  PromptUtil.toast('深色模式状态已更新（Mock）');
                }
              })
              Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 64, right: 14 })
              Row({ space: 12 }) {
                Stack() {
                  Column().width(38).height(38).borderRadius(999).backgroundColor('#EDF6EF')
                  SymbolGlyph($r('sys.symbol.text_and_t')).fontSize(18).fontColor([Theme.BRAND_DEEP])
                }
                Column({ space: 2 }) {
                  Text('字体大小')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.PRIMARY)
                  Text('标准 / 大一号')
                    .fontSize(11)
                    .fontColor(Theme.TERTIARY)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Row({ space: 6 }) {
                  Text('标准')
                    .fontSize(12)
                    .fontColor(this.largeFont ? Theme.TERTIARY : '#FFFFFF')
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .borderRadius(13)
                    .backgroundColor(this.largeFont ? '#EEF3EE' : Theme.BRAND_DEEP)
                    .onClick(() => {
                      this.largeFont = false;
                      this.settings.largeFont = false;
                      PromptUtil.toast('字号已切换为标准（Mock）');
                    })
                  Text('大')
                    .fontSize(12)
                    .fontColor(this.largeFont ? '#FFFFFF' : Theme.TERTIARY)
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .borderRadius(13)
                    .backgroundColor(this.largeFont ? Theme.BRAND_DEEP : '#EEF3EE')
                    .onClick(() => {
                      this.largeFont = true;
                      this.settings.largeFont = true;
                      PromptUtil.toast('字号已切换为大（Mock）');
                    })
                }
              }
              .width('100%')
              .height(62)
              .padding({ left: 14, right: 14 })
              Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 64, right: 14 })
              SettingSwitchRow({
                icon: $r('sys.symbol.leaf'),
                title: '低打扰模式',
                desc: '减少默默主动弹出的频率',
                isOn: this.lowInterrupt,
                onChange: (on: boolean) => {
                  this.lowInterrupt = on;
                  this.settings.lowInterrupt = on;
                  PromptUtil.toast('低打扰模式已' + (on ? '开启' : '关闭') + '（Mock）');
                }
              })
            }
            .width('100%')
            .borderRadius(Theme.RADIUS_CARD)
            .backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.LINE })
            .clip(true)
          }

          // ============ 隐私与安全性 ============
          Column({ space: 10 }) {
            Text('隐私与安全性')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.PRIMARY)
              .width('100%')
              .padding({ left: 4 })
            Column({ space: 0 }) {
              SettingSwitchRow({
                icon: $r('sys.symbol.calendar'),
                title: '读取日历',
                desc: '默默可观察你的日程安排',
                isOn: this.readCal,
                onChange: (on: boolean) => {
                  this.readCal = on;
                  this.settings.readCalendar = on;
                  PromptUtil.toast('日历权限已' + (on ? '开启' : '关闭') + '（Mock）');
                },
                onTap: () => {
                  PromptUtil.toast('日历数据本轮为 Mock，不会真正读取');
                }
              })
              Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 64, right: 14 })
              SettingSwitchRow({
                icon: $r('sys.symbol.list_bullet'),
                title: '读取待办',
                desc: '把待办记进花园',
                isOn: this.readTodo,
                onChange: (on: boolean) => {
                  this.readTodo = on;
                  this.settings.readTodo = on;
                  PromptUtil.toast('待办权限已' + (on ? '开启' : '关闭') + '（Mock）');
                }
              })
              Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 64, right: 14 })
              SettingSwitchRow({
                icon: $r('sys.symbol.doc_text'),
                title: '读取备忘录',
                desc: '随时记录一闪而过的念头',
                isOn: this.readMemo,
                onChange: (on: boolean) => {
                  this.readMemo = on;
                  this.settings.readMemo = on;
                  PromptUtil.toast('备忘录权限已' + (on ? '开启' : '关闭') + '（Mock）');
                }
              })
              Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 64, right: 14 })
              SettingSwitchRow({
                icon: $r('sys.symbol.camera'),
                title: '相机使用',
                desc: '让默默拍下你的今日天空',
                isOn: this.camera,
                onChange: (on: boolean) => {
                  this.camera = on;
                  this.settings.cameraAccess = on;
                  PromptUtil.toast('相机权限已' + (on ? '开启' : '关闭') + '（Mock）');
                },
                onTap: () => {
                  PromptUtil.toast('相机数据本轮为 Mock，不会真正调用');
                }
              })
            }
            .width('100%')
            .borderRadius(Theme.RADIUS_CARD)
            .backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.LINE })
            .clip(true)
          }

          // ============ 记忆内容管理 ============
          Column({ space: 10 }) {
            Text('记忆内容管理')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.PRIMARY)
              .width('100%')
              .padding({ left: 4 })
            Column({ space: 0 }) {
              SettingNavRow({
                icon: $r('sys.symbol.flower'),
                title: '管理记忆与花园',
                desc: '查看、编辑、删除全部记忆',
                onTap: () => {
                  TabController.switch(1);
                }
              })
              Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 64, right: 14 })
              SettingNavRow({
                icon: $r('sys.symbol.picture'),
                title: '存储占用',
                desc: '已使用 32.4 MB / 500 MB',
                trailing: '清理',
                onTap: () => {
                  PromptUtil.toast('已释放 1.2 MB（Mock）');
                }
              })
              Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 64, right: 14 })
              SettingNavRow({
                icon: $r('sys.symbol.ohos_trash'),
                iconStyle: 'danger',
                title: '清除记忆数据',
                desc: '清空全部 Mock 记忆',
                onTap: () => {
                  this.clearAll();
                }
              })
              Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 64, right: 14 })
              SettingNavRow({
                icon: $r('sys.symbol.arrow_clockwise'),
                title: '恢复示例数据',
                desc: '重新载入默默准备的样例记忆',
                onTap: () => {
                  MemoryRepository.get().restoreSamples();
                  PromptUtil.toast('已恢复示例数据');
                }
              })
            }
            .width('100%')
            .borderRadius(Theme.RADIUS_CARD)
            .backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.LINE })
            .clip(true)
          }

          // ============ 关于 ============
          Column({ space: 10 }) {
            Text('关于')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.PRIMARY)
              .width('100%')
              .padding({ left: 4 })
            Column({ space: 0 }) {
              SettingNavRow({
                icon: $r('sys.symbol.heart'),
                title: '关于默默',
                desc: '项目信息 · 开发者 · 参考内容',
                onTap: () => {
                  AppRouter.push(RouteName.ABOUT);
                }
              })
              Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 64, right: 14 })
              Row({ space: 12 }) {
                Stack() {
                  Column().width(38).height(38).borderRadius(999).backgroundColor('#EDF6EF')
                  SymbolGlyph($r('sys.symbol.star')).fontSize(18).fontColor([Theme.BRAND_DEEP])
                }
                Column({ space: 2 }) {
                  Text('当前版本')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.PRIMARY)
                  Text('MoMo 1.0.0 · 第一轮 Mock UI')
                    .fontSize(11)
                    .fontColor(Theme.TERTIARY)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .height(62)
              .padding({ left: 14, right: 14 })
            }
            .width('100%')
            .borderRadius(Theme.RADIUS_CARD)
            .backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.LINE })
            .clip(true)
          }

          Blank().height(260)
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
}