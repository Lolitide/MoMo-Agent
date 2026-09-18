/*
 * ============================================================================
 * 文件名：pages/LoginPage.ets
 * ============================================================================
 * 【用途】登录页面 - 支持华为账号登录
 * 【功能】
 *   - 展示华为账号登录按钮
 *   - 处理登录流程和状态
 *   - 登录成功后跳转到主页
 * ============================================================================
 */
import { AuthService } from '../service/auth';
import { Logger } from '../utils/Logger';
import router from '@ohos.router';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct LoginPage {
  private static readonly TAG = 'LoginPage';

  @State loginStatus: string = '等待登录';
  @State isLogging: boolean = false;
  @State userInfo: string = '';

  private authService: AuthService = AuthService.get();

  aboutToAppear(): void {
    Logger.info(LoginPage.TAG, '登录页面加载');
    this.checkLoginStatus();
  }

  /**
   * 检查登录状态
   */
  async checkLoginStatus(): Promise<void> {
    try {
      const isLoggedIn = await this.authService.isLoggedIn();
      if (isLoggedIn) {
        const user = await this.authService.getCurrentUser();
        if (user) {
          this.loginStatus = '已登录';
          this.userInfo = `用户: ${user.nickname}\nID: ${user.userId}`;
          Logger.info(LoginPage.TAG, `用户已登录: ${user.userId}`);
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

      // 延迟跳转到主页
      setTimeout(() => {
        this.navigateToHome();
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
   * 设备ID登录（匿名登录）
   */
  async handleDeviceLogin(): Promise<void> {
    if (this.isLogging) {
      return;
    }

    this.isLogging = true;
    this.loginStatus = '正在登录...';

    try {
      Logger.info(LoginPage.TAG, '开始设备ID登录');

      // 使用默认的设备ID提供商
      const user = await this.authService.login();

      this.loginStatus = '登录成功！';
      this.userInfo = `欢迎，${user.nickname}！\nID: ${user.userId}`;
      Logger.info(LoginPage.TAG, `登录成功: ${user.userId}`);

      // 延迟跳转到主页
      setTimeout(() => {
        this.navigateToHome();
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
   * 跳转到主页
   */
  navigateToHome(): void {
    try {
      router.pushUrl({
        url: 'pages/Index'
      });
    } catch (error) {
      Logger.error(LoginPage.TAG, `页面跳转失败: ${error}`);
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('MoMo')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E2A22')
      }
      .width('100%')
      .height(60)
      .padding({ left: 20, right: 20 })
      .justifyContent(FlexAlign.Center)

      // 主内容区域
      Column() {
        // Logo区域
        Text('🌸')
          .fontSize(80)
          .margin({ top: 60, bottom: 20 })

        Text('欢迎使用 MoMo')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1E2A22')
          .margin({ bottom: 10 })

        Text('您的智能情感陪伴助手')
          .fontSize(14)
          .fontColor('#8B9D91')
          .margin({ bottom: 40 })

        // 登录状态显示
        Column() {
          Text(this.loginStatus)
            .fontSize(16)
            .fontColor('#1E2A22')
            .margin({ bottom: 10 })

          if (this.userInfo) {
            Text(this.userInfo)
              .fontSize(14)
              .fontColor('#8B9D91')
              .textAlign(TextAlign.Center)
              .width('100%')
          }
        }
        .width('90%')
        .padding(20)
        .backgroundColor('#F5F7F6')
        .borderRadius(12)
        .margin({ bottom: 30 })

        // 华为账号登录按钮
        Button('华为账号登录', { type: ButtonType.Normal })
          .width('80%')
          .height(50)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .backgroundColor('#C62F38')
          .borderRadius(25)
          .margin({ bottom: 15 })
          .enabled(!this.isLogging)
          .opacity(this.isLogging ? 0.6 : 1.0)
          .onClick(() => {
            this.handleHuaweiLogin();
          })

        // 设备ID登录按钮（匿名登录）
        Button('游客登录', { type: ButtonType.Normal })
          .width('80%')
          .height(50)
          .fontSize(16)
          .fontColor('#1E2A22')
          .backgroundColor('#E8ECE9')
          .borderRadius(25)
          .margin({ bottom: 15 })
          .enabled(!this.isLogging)
          .opacity(this.isLogging ? 0.6 : 1.0)
          .onClick(() => {
            this.handleDeviceLogin();
          })

        // 登出按钮（已登录时显示）
        if (this.loginStatus === '已登录') {
          Button('登出', { type: ButtonType.Normal })
            .width('80%')
            .height(50)
            .fontSize(16)
            .fontColor('#C62F38')
            .backgroundColor('#FFFFFF')
            .border({ width: 1, color: '#C62F38' })
            .borderRadius(25)
            .margin({ top: 20 })
            .onClick(() => {
              this.handleLogout();
            })
        }

        // 提示文字
        Text('首次使用建议使用华为账号登录')
          .fontSize(12)
          .fontColor('#B4BEB8')
          .margin({ top: 30 })

      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      // 底部版权信息
      Text('© 2024 MoMo Team')
        .fontSize(12)
        .fontColor('#B4BEB8')
        .margin({ bottom: 20 })

    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
