/*
 * ============================================================================
 * 文件名：pages/LoginPage.ets
 * ============================================================================
 * 【用途】App 入口页（@Entry）兼「首次体验」流程容器：
 *   - HdsNavigation 主页面 = 登录页（默默形象 / 华为账号登录 / 游客登录 / 版权）；
 *   - navDestination 子页面 = 陪伴档案（三步选择）-> 使用教程（见 pagesMap）；
 *   - 出口唯一：档案已完成直接进主页；未完成则 档案 -> 教程 -> 主页。
 * 【前置条件 / 假设】
 *   - 依赖：HdsNavigation(UIDesignKit)、HdsNavigationTitleMode、AuthService、
 *     UserRepository、OnboardingProfilePage / OnboardingTutorialPage（HDS 子页面）；
 *   - 假设：EntryAbility 以本页为启动页（main_pages.json）；本页独占自己的
 *     NavPathStack，与 MainPage 的 AppRouter.stack 互不干扰；
 *   - 标题栏由 HDS 组件负责状态栏避让，页面内容不再手写顶部占位。
 * 【输入 / 输出（后置条件）】
 *   - 输入：华为账号登录 / 游客登录 / 登出 / 子页面回调（onNext / onFinish）；
 *   - 输出：登录态经 AuthService 落库；流程结束用 replaceUrl 切到 MainPage，
 *     保证返回键不会退回登录/设置流程。
 * 【关键类 / 算法】
 *   - checkLoginStatus：先消费「重新体验首次打卡」标记（consumeForceLogin），
 *     再判断已有登录态；已登录直接走 navigateAfterLogin；
 *   - navigateAfterLogin：isProfileCompleted 决定去 MainPage 还是档案子页面；
 *   - pagesMap：navDestination 路由表（子页面用 HdsNavDestination 自带返回键）。
 * 【参考源】
 *   - Examples/hdsNavigation Examples.md（HDS 标题栏参数）；pages/B_About.ets
 * ============================================================================
 */
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { AuthService } from '../service/auth';
import { Logger } from '../utils/Logger';
import router from '@ohos.router';
import { common } from '@kit.AbilityKit';
import { UserRepository } from '../repository/Repositories';
import { OnboardingService } from '../service/OnboardingService';
import { RouteName, RouteParam } from '../router/AppRouter';
import { MoMoState } from '../model/Models';
import { MoMoAvatar } from '../components/MoMoAvatar';
import { Theme } from '../utils/Theme';
import { OnboardingProfilePage } from './OnboardingProfilePage';
import { OnboardingTutorialPage } from './OnboardingTutorialPage';

@Entry
@Component
struct LoginPage {
  private static readonly TAG = 'LoginPage';

  @State loginStatus: string = '等待登录';
  @State isLogging: boolean = false;
  @State userInfo: string = '';

  private authService: AuthService = AuthService.get();
  private stack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    Logger.info(LoginPage.TAG, '登录页面加载');
    this.checkLoginStatus();
  }

  /**
   * 检查登录状态
   */
  async checkLoginStatus(): Promise<void> {
    try {
      const forceLogin = await OnboardingService.get().consumeForceLogin();
      if (forceLogin) {
        this.loginStatus = '请重新登录以开始首次体验';
        this.userInfo = '';
        return;
      }
      const isLoggedIn = await this.authService.isLoggedIn();
      if (isLoggedIn) {
        const user = await this.authService.getCurrentUser();
        if (user) {
          this.loginStatus = '已登录';
          this.userInfo = `用户: ${user.nickname}\nID: ${user.userId}`;
          Logger.info(LoginPage.TAG, `用户已登录: ${user.userId}`);
          setTimeout(() => {
            this.navigateAfterLogin();
          }, 400);
        }
      } else {
        this.loginStatus = '未登录';
        this.userInfo = '';
      }
    } catch (error) {
      Logger.error(LoginPage.TAG, `检查登录状态失败: ${error}`);
      this.loginStatus = '检查状态失败';
    }
  }

  /**
   * 华为账号登录
   */
  async handleHuaweiLogin(): Promise<void> {
    if (this.isLogging) {
      return;
    }

    this.isLogging = true;
    this.loginStatus = '正在登录...';

    try {
      Logger.info(LoginPage.TAG, '开始华为账号登录');

      // 切换到华为账号提供商
      const context = getContext(this) as common.UIAbilityContext;
      this.authService.useHuaweiAccount(context);

      // 执行登录
      const user = await this.authService.login();

      this.loginStatus = '登录成功！';
      this.userInfo = `欢迎，${user.nickname}！\nID: ${user.userId}`;
      Logger.info(LoginPage.TAG, `登录成功: ${user.userId}`);

      // 登录后先检查本地档案，未完成时进入三步选择页
      setTimeout(() => {
        this.navigateAfterLogin();
      }, 1500);

    } catch (error) {
      Logger.error(LoginPage.TAG, `登录失败: ${error}`);
      this.loginStatus = `登录失败: ${error}`;
      this.userInfo = '';
    } finally {
      this.isLogging = false;
    }
  }

  /**
   * 设备ID登录（游客登录）
   */
  async handleDeviceLogin(): Promise<void> {
    if (this.isLogging) {
      return;
    }

    this.isLogging = true;
    this.loginStatus = '正在登录...';

    try {
      Logger.info(LoginPage.TAG, '开始游客登录');

      // 使用默认的设备ID提供商
      const user = await this.authService.login();

      this.loginStatus = '登录成功！';
      this.userInfo = `欢迎，${user.nickname}！\nID: ${user.userId}`;
      Logger.info(LoginPage.TAG, `登录成功: ${user.userId}`);

      // 延迟进入下一步
      setTimeout(() => {
        this.navigateAfterLogin();
      }, 900);

    } catch (error) {
      Logger.error(LoginPage.TAG, `登录失败: ${error}`);
      this.loginStatus = `登录失败: ${error}`;
      this.userInfo = '';
    } finally {
      this.isLogging = false;
    }
  }

  /**
   * 登出
   */
  async handleLogout(): Promise<void> {
    try {
      Logger.info(LoginPage.TAG, '开始登出');
      await this.authService.logout();
      this.loginStatus = '已登出';
      this.userInfo = '';
      Logger.info(LoginPage.TAG, '登出成功');
    } catch (error) {
      Logger.error(LoginPage.TAG, `登出失败: ${error}`);
      this.loginStatus = `登出失败: ${error}`;
    }
  }

  /**
   * 登录后分流：档案已完成进主页，否则进入陪伴档案流程
   */
  async navigateAfterLogin(): Promise<void> {
    try {
      const completed = await UserRepository.get().isProfileCompleted();
      if (completed) {
        router.replaceUrl({ url: 'pages/MainPage' });
      } else {
        this.stack.pushPathByName(RouteName.ONBOARDING_PROFILE, RouteParam.NONE);
      }
    } catch (error) {
      Logger.error(LoginPage.TAG, `档案状态检查失败: ${error}`);
      this.stack.pushPathByName(RouteName.ONBOARDING_PROFILE, RouteParam.NONE);
    }
  }

  // 档案三步保存完成 -> 进入教程页（首次体验的最后一步）
  private openTutorial(): void {
    this.stack.pushPathByName(RouteName.ONBOARDING_TUTORIAL, RouteParam.NONE);
  }

  // 教程看完 -> 结束整个首次体验流程，直接换页到主页（返回键不再回到此处）
  private finishOnboarding(): void {
    router.replaceUrl({ url: 'pages/MainPage' });
  }

  // 路由表：HdsNavigation 通过 navDestination 实例化首次体验的子页面
  @Builder
  pagesMap(name: string) {
    if (name === RouteName.ONBOARDING_PROFILE) {
      OnboardingProfilePage({
        isFirstRun: true,
        onNext: () => {
          this.openTutorial();
        },
        onFinish: () => {
          this.finishOnboarding();
        }
      })
    } else if (name === RouteName.ONBOARDING_TUTORIAL) {
      OnboardingTutorialPage({
        onFinish: () => {
          this.finishOnboarding();
        }
      })
    }
  }

  // 登录按钮：胶囊形（高度 52 -> 圆角取半高以上，HDS 风格统一）
  @Builder
  loginButton(label: string, filled: boolean, enabledState: boolean, action: () => void) {
    Button(label, { type: ButtonType.Normal })
      .width('100%')
      .height(52)
      .fontSize(Theme.fontSize(16))
      .fontWeight(FontWeight.Medium)
      .fontColor(filled ? '#FFFFFF' : Theme.PRIMARY)
      .backgroundColor(filled ? '#C62F38' : '#E8ECE9')
      .borderRadius(Theme.RADIUS_PILL)
      .enabled(enabledState)
      .opacity(enabledState ? 1.0 : 0.6)
      .onClick(action)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
  }

  build() {
    HdsNavigation(this.stack) {
      Column() {
        // 主内容区：默默形象 + 欢迎语 + 登录方式
        Column() {
          // 角色形象：直接用默默本体（Canvas 角色），替代原先的花 emoji
          Column() {
            MoMoAvatar({ avatarSize: 176, state: MoMoState.IDLE, interactive: true })
          }
          .width(200)
          .height(200)
          .borderRadius(100)
          .backgroundColor('rgba(151,255,171,0.22)')
          .justifyContent(FlexAlign.Center)
          .shadow({ radius: 30, color: 'rgba(98,217,127,0.32)', offsetY: 10 })

          Text('欢迎使用 MoMo')
            .fontSize(Theme.fontSize(26))
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.PRIMARY)
            .margin({ top: 22 })

          Text('您的智能情感陪伴助手')
            .fontSize(Theme.fontSize(14))
            .fontColor(Theme.TERTIARY)
            .margin({ top: 8 })

          // 登录状态
          Column({ space: 6 }) {
            Text(this.loginStatus)
              .fontSize(Theme.fontSize(15))
              .fontColor(Theme.SECONDARY)
            if (this.userInfo) {
              Text(this.userInfo)
                .fontSize(Theme.fontSize(12))
                .fontColor(Theme.TERTIARY)
                .textAlign(TextAlign.Center)
                .width('100%')
            }
          }
          .width('100%')
          .padding({ top: 14, bottom: 14, left: 18, right: 18 })
          .backgroundColor('#F2F7F1')
          .borderRadius(20)
          .margin({ top: 26 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)

        // 登录方式
        Column({ space: 14 }) {
          this.loginButton('华为账号登录', true, !this.isLogging, () => {
            this.handleHuaweiLogin();
          })
          this.loginButton('游客登录', false, !this.isLogging, () => {
            this.handleDeviceLogin();
          })
          if (this.loginStatus === '已登录') {
            Button('登出', { type: ButtonType.Normal })
              .width('100%')
              .height(52)
              .fontSize(Theme.fontSize(16))
              .fontColor('#C62F38')
              .backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#C62F38' })
              .borderRadius(Theme.RADIUS_PILL)
              .onClick(() => {
                this.handleLogout();
              })
          }
          Text('首次使用建议使用华为账号登录')
            .fontSize(Theme.fontSize(12))
            .fontColor(Theme.DISABLED)
        }
        .width('100%')
        .padding({ left: 30, right: 30 })

        // 版权
        Text('© 2026 MoMo Team')
          .fontSize(Theme.fontSize(12))
          .fontColor(Theme.DISABLED)
          .margin({ top: 26, bottom: 18 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 0, right: 0 })
      .backgroundColor(Theme.BG)
    }
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .navDestination(this.pagesMap)
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
            titleStyle: { mainTitleColor: '#1E2A22' }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: 'rgba(247,250,244,0.88)'
          },
          contentStyle: {
            titleStyle: { mainTitleColor: '#1E2A22' }
          }
        }
      },
      content: {
        title: {
          mainTitle: 'MoMo'
        }
      },
      avoidLayoutSafeArea: true
    })
    // 一级页面：不显示返回键（HDS Mini 单行样式默认带返回图标）
    .hideBackButton(true)
    .systemBarStyle(
      { statusBarContentColor: '#1E2A22' },
      { statusBarContentColor: '#1E2A22' }
    )
    .backgroundColor(Theme.BG)
  }
}
