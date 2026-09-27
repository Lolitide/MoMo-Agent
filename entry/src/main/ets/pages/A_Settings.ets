/*
 * ============================================================================
 * 文件名：pages/A_Settings.ets
 * ============================================================================
 * 【用途】一级 Tab「设置」：偏好与低打扰、演示模式（开关 + 重置 + 隔离说明）、
 *   隐私与安全性（日历/待办/备忘录/相机权限开关）、记忆内容管理（清空/恢复示例）、
 *   关于入口（跳 B_About）；设置状态由 SettingsService 持久化。
 * 【前置条件 / 假设】
 *   - 依赖：SettingsService、SettingRows 组件、TabController、DemoModeService、
 *     MemoryRepository（清空/恢复示例数据）、ShellState.settingsScroller；
 *   - 假设：权限开关记录用户偏好，系统权限由对应能力接入时再申请；
 *   - 假设：演示模式的真实数据隔离由仓库层保证，本页只负责开关与提示。
 * 【输入 / 输出（后置条件）】
 *   - 输入：开关点击、行点击、AlertDialog 确认；
 *   - 输出：@State 同步 + 写入 SettingsService；清空/恢复数据仓库；
 *     演示模式开关经 DemoModeService.enable()/disable() 生效；跳转花园/关于。
 * 【关键类 / 算法】
 *   - A_Settings：设置页组件；clearAll：AlertDialog 二次确认后 MemoryRepository.clearAll()；
 *   - demoSection：演示模式区块（开关 / 演示记忆条数 / 重置演示数据 / 身份与联网状态只读说明）。
 *   - demoCountRow + applyDemoCount：条数滑杆。拖动只改本地 @State，松手（SliderChangeMode.End/Click）
 *     才写回 DemoModeService 并重建演示记忆 —— 否则每移动一格都会全量重排整座花园并卡顿。
 * 【参考源】
 *   - MoMo_DOC/UI 参考图（设置页）；iBest-UI 设置行样式
 * ============================================================================
 */
import { AppRouter, RouteName } from '../router/AppRouter';
import router from '@ohos.router';
import { MemoryRepository, UserRepository } from '../repository/Repositories';
import { SettingsService, TabController, ShellState, StateListener } from '../service/Services';
import { DemoModeService } from '../service/DemoModeService';
import { Theme } from '../utils/Theme';
import { PromptUtil } from '../utils/PromptUtil';
import { SettingSwitchRow, SettingNavRow } from '../components/SettingRows';
import { OnboardingService } from '../service/OnboardingService';

@Component
export struct A_Settings {
  private settings: SettingsService = SettingsService.get();
  @State readCal: boolean = true;
  @State readTodo: boolean = true;
  @State readMemo: boolean = false;
  @State camera: boolean = false;
  @State lowInterrupt: boolean = true;
  // 演示模式：开关状态 + 演示数据条数（用于在设置页直接说明「有几条演示内容」）
  @State isDemo: boolean = false;
  @State demoCount: number = 0;
  // 演示记忆条数（滑杆值）：拖动时只改它，松手才落到 DemoModeService
  @State demoMemoryTarget: number = 14;
  private demoListener: StateListener = () => {
  };
  private scroller: Scroller = ShellState.settingsScroller;

  aboutToAppear(): void {
    this.readCal = this.settings.readCalendar;
    this.readTodo = this.settings.readTodo;
    this.readMemo = this.settings.readMemo;
    this.camera = this.settings.cameraAccess;
    this.lowInterrupt = this.settings.lowInterrupt;

    this.isDemo = DemoModeService.get().isDemo();
    this.demoCount = DemoModeService.get().demoMemoryCount();
    this.demoMemoryTarget = DemoModeService.get().demoMemoryTarget();
    this.demoListener = () => {
      this.isDemo = DemoModeService.get().isDemo();
      this.demoCount = DemoModeService.get().demoMemoryCount();
      this.demoMemoryTarget = DemoModeService.get().demoMemoryTarget();
    };
    DemoModeService.get().subscribe(this.demoListener);
  }

  aboutToDisappear(): void {
    DemoModeService.get().unsubscribe(this.demoListener);
  }

  // 打开演示模式：先二次确认（现场演示时误触的代价是被清掉的演示数据，值得一问）
  private requestEnableDemo(): void {
    AlertDialog.show({
      title: '开启演示模式',
      message: '演示模式会载入一套预置的演示内容（记忆花园、今日状态、今日漫画）。\n'
        + '演示数据只存在于内存：不会保存，退出演示模式时全部清除，你已有的数据不会被修改。',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '开启',
        fontColor: '#33C56E',
        action: () => {
          this.enableDemo();
        }
      }
    });
  }

  private enableDemo(): void {
    DemoModeService.get().enable().then(() => {
      PromptUtil.toast('演示模式已开启，共 ' + DemoModeService.get().demoMemoryCount().toString() + ' 条演示记忆');
    }).catch((err: Error) => {
      PromptUtil.toast('演示模式开启失败，已恢复原状态');
      console.error(`开启演示模式失败: ${err.message}`);
    });
  }

  private disableDemo(): void {
    DemoModeService.get().disable().then(() => {
      PromptUtil.toast('已退出演示模式，演示数据已清除');
    }).catch((err: Error) => {
      console.error(`退出演示模式失败: ${err.message}`);
    });
  }

  // 重置演示内容：仅在演示态暴露（等价于把演示种子重新灌一遍）
  private resetDemo(): void {
    MemoryRepository.get().restoreSamples();
    PromptUtil.toast('演示数据已重置为初始 ' + DemoModeService.get().demoMemoryCount().toString() + ' 条');
  }

  @Builder
  demoCountRow() {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.list_bullet')).fontSize(Theme.fontSize(22))
          .fontColor([Theme.BRAND_DEEP])
        Column({ space: 2 }) {
          Text('演示记忆条数')
            .fontSize(Theme.fontSize(16))
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.PRIMARY)
          Text('拖到更多条数，看记忆花园变满时的样子')
            .fontSize(Theme.fontSize(11))
            .fontColor(Theme.TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(this.demoMemoryTarget.toString() + ' 条')
          .fontSize(Theme.fontSize(12))
          .fontColor(Theme.BRAND_DEEP)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(14)
          .backgroundColor('#ECFBEF')
      }
      .width('100%')

      // 拖动过程只改这一个数字（不重建仓库），松手才真正重排花园 ——
      // 否则每移动一格都要全量重算布局，现场会明显卡顿。
      Row({ space: 10 }) {
        Text(DemoModeService.minDemoMemoryCount().toString())
          .fontSize(Theme.fontSize(11))
          .fontColor(Theme.TERTIARY)
        Slider({
          value: this.demoMemoryTarget,
          min: DemoModeService.minDemoMemoryCount(),
          max: DemoModeService.maxDemoMemoryCount(),
          step: 1,
          style: SliderStyle.OutSet
        })
          .layoutWeight(1)
          .selectedColor(Theme.BRAND_DEEP)
          .trackColor(Theme.LINE)
          .blockColor(Theme.BRAND_DEEP)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.demoMemoryTarget = Math.round(value);
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              this.applyDemoCount();
            }
          })
        Text(DemoModeService.maxDemoMemoryCount().toString())
          .fontSize(Theme.fontSize(11))
          .fontColor(Theme.TERTIARY)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 12, bottom: 12 })
    .alignItems(HorizontalAlign.Start)
  }

  /** 松手后生效：写回设置并立即重建演示记忆，花园随即按新条数重排 */
  private applyDemoCount(): void {
    const applied: number = DemoModeService.get().setDemoMemoryCount(this.demoMemoryTarget);
    this.demoMemoryTarget = applied;
    PromptUtil.toast('演示记忆已改为 ' + applied.toString() + ' 条');
  }

  @Builder
  demoSection() {
    Column({ space: 10 }) {
      Text('演示模式')
        .fontSize(Theme.fontSize(14))
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.PRIMARY)
        .width('100%')
        .padding({ left: 4 })
      Column({ space: 0 }) {
        SettingSwitchRow({
          icon: $r('sys.symbol.play_circle'),
          title: '演示模式',
          desc: this.isDemo
            ? ('已载入 ' + this.demoCount.toString() + ' 条演示记忆 · 退出后立即清除')
            : '展示预置演示内容，不影响你的真实数据',
          isOn: this.isDemo,
          onChange: (on: boolean) => {
            if (on) {
              this.requestEnableDemo();
            } else {
              this.disableDemo();
            }
          }
        })
        if (this.isDemo) {
          Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 52, right: 18 })
          this.demoCountRow()
          Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 52, right: 18 })
          SettingNavRow({
            icon: $r('sys.symbol.arrow_clockwise'),
            title: '重置演示数据',
            desc: '回到初始的演示内容',
            onTap: () => {
              this.resetDemo();
            }
          })
        }
        Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 52, right: 18 })
        // 只读状态说明：让「游客身份也能用 AI」这件事在演示现场一眼可见
        Row({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.info_circle')).fontSize(Theme.fontSize(22))
            .fontColor([Theme.BRAND_DEEP])
          Column({ space: 2 }) {
            Text('当前身份：游客（数据仅存本机）')
              .fontSize(Theme.fontSize(14))
              .fontColor(Theme.PRIMARY)
            Text('AI 联网能力可用 · 演示数据不落盘、不上云')
              .fontSize(Theme.fontSize(11))
              .fontColor(Theme.TERTIARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height(64)
        .padding({ left: 18, right: 18 })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .borderRadius(Theme.RADIUS_CARD)
      .backgroundColor(Theme.CARD)
      .border({ width: 1, color: Theme.LINE })
      .clip(true)
    }
  }

  private clearAll(): void {
    AlertDialog.show({
      title: '清除记忆数据',
      message: '将清除花园、大纲、记忆树中的全部记忆，此操作不可恢复。',
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
          PromptUtil.toast('已清空记忆数据');
        }
      }
    });
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll(this.scroller) {
        Column({ space: 18 }) {
          // 顶部为 HDS 标题栏预留：单行(Mini)标题栏 56vp + 与内容间距（原为强调型 112vp 时的 170vp，同步减少 56vp）
          Blank().height(114)

          // ============ 偏好设置 ============
          Column({ space: 10 }) {
            Text('偏好设置')
              .fontSize(Theme.fontSize(14))
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.PRIMARY)
              .width('100%')
              .padding({ left: 4 })
            Column({ space: 0 }) {
              SettingSwitchRow({
                icon: $r('sys.symbol.leaf'),
                title: '低打扰模式',

                isOn: this.lowInterrupt,
                onChange: (on: boolean) => {
                  this.lowInterrupt = on;
                  this.settings.lowInterrupt = on;
                  PromptUtil.toast('低打扰模式已' + (on ? '开启' : '关闭'));
                }
              })
            }
            .width('100%')
            .borderRadius(Theme.RADIUS_CARD)
            .backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.LINE })
            .clip(true)
          }

          // ============ 演示模式 ============
          this.demoSection()

          // ============ 隐私与安全性 ============
          Column({ space: 10 }) {
            Text('隐私与安全性')
              .fontSize(Theme.fontSize(14))
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.PRIMARY)
              .width('100%')
              .padding({ left: 4 })
            Column({ space: 0 }) {
              SettingSwitchRow({
                icon: $r('sys.symbol.calendar'),
                title: '读取日历',

                isOn: this.readCal,
                onChange: (on: boolean) => {
                  this.readCal = on;
                  this.settings.readCalendar = on;
                  PromptUtil.toast('日历权限已' + (on ? '开启' : '关闭'));
                },
                onTap: () => {
                  PromptUtil.toast('日历读取将在授权后启用');
                }
              })
              Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 52, right: 18 })
              SettingSwitchRow({
                icon: $r('sys.symbol.list_bullet'),
                title: '读取待办',

                isOn: this.readTodo,
                onChange: (on: boolean) => {
                  this.readTodo = on;
                  this.settings.readTodo = on;
                  PromptUtil.toast('待办权限已' + (on ? '开启' : '关闭'));
                }
              })
              Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 52, right: 18 })
              SettingSwitchRow({
                icon: $r('sys.symbol.doc_text'),
                title: '读取备忘录',

                isOn: this.readMemo,
                onChange: (on: boolean) => {
                  this.readMemo = on;
                  this.settings.readMemo = on;
                  PromptUtil.toast('备忘录权限已' + (on ? '开启' : '关闭'));
                }
              })
              Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 52, right: 18 })
              SettingSwitchRow({
                icon: $r('sys.symbol.camera'),
                title: '相机使用',

                isOn: this.camera,
                onChange: (on: boolean) => {
                  this.camera = on;
                  this.settings.cameraAccess = on;
                  PromptUtil.toast('相机权限已' + (on ? '开启' : '关闭'));
                },
                onTap: () => {
                  PromptUtil.toast('相机功能将在授权后启用');
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
              .fontSize(Theme.fontSize(14))
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.PRIMARY)
              .width('100%')
              .padding({ left: 4 })
            Column({ space: 0 }) {
              SettingNavRow({
                icon: $r('sys.symbol.flower'),
                title: '管理记忆与花园',

                onTap: () => {
                  TabController.switch(1);
                }
              })
              Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 52, right: 18 })
              SettingNavRow({
                icon: $r('sys.symbol.ohos_trash'),
                iconStyle: 'danger',
                title: '清除记忆数据',

                onTap: () => {
                  this.clearAll();
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
              .fontSize(Theme.fontSize(14))
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
              Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 52, right: 18 })
              SettingNavRow({
                icon: $r('sys.symbol.star_fill'),
                title: '陪伴档案',
                desc: '调整语气、节奏和漫画风格',
                onTap: () => {
                  router.pushUrl({ url: 'pages/OnboardingProfilePage' });
                }
              })
              Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 52, right: 18 })
              SettingNavRow({
                icon: $r('sys.symbol.arrow_clockwise'),
                title: '重新体验首次打卡',
                desc: '退出登录，从登录和档案设置重新开始',
                onTap: () => {
                  OnboardingService.get().getCurrentUserId().then((userId) => {
                    OnboardingService.get().restartFirstExperience(userId).then(() => {
                      UserRepository.get().clearCachedProfile();
                      PromptUtil.toast('已重置首次体验，即将返回登录');
                      setTimeout(() => {
                        router.pushUrl({ url: 'pages/LoginPage' });
                      }, 350);
                    });
                  });
                }
              })
              Divider().color(Theme.LINE).strokeWidth(0.6).margin({ left: 52, right: 18 })
              Row({ space: 12 }) {
                  SymbolGlyph($r('sys.symbol.star')).fontSize(Theme.fontSize(22)).fontColor([Theme.BRAND_DEEP])
                Column({ space: 2 }) {
                  Text('当前版本')
                    .fontSize(Theme.fontSize(16))
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.PRIMARY)
                  Text('MoMo 2.0')
                    .fontSize(Theme.fontSize(11))
                    .fontColor(Theme.TERTIARY)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .height(64)
              .padding({ left: 18, right: 18 })
            }
            .width('100%')
            .borderRadius(Theme.RADIUS_CARD)
            .backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.LINE })
            .clip(true)
          }

          Blank().height(140)
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
