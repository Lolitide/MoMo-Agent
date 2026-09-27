/*
 * ============================================================================
 * 文件名：pages/AuthTestPage.ets
 * ============================================================================
 * 【用途】认证功能测试页面 - 用于测试华为账号登录和设备ID登录
 * 【功能】
 *   - 显示当前登录状态和用户信息
 *   - 测试华为账号登录
 *   - 测试设备ID登录
 *   - 测试登出功能
 *   - 显示详细的日志信息
 * ============================================================================
 */
import { AuthService } from '../service/auth';
import { User } from '../service/auth';
import { Logger } from '../utils/Logger';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct AuthTestPage {
  private static readonly TAG = 'AuthTestPage';

  @State loginStatus: string = '检查中...';
  @State isLoggedIn: boolean = false;
  @State userName: string = '未登录';
  @State userId: string = '';
  @State userAvatar: string = '';
  @State providerName: string = '';
  @State isLoading: boolean = false;
  @State logMessages: string[] = [];

  private authService: AuthService = AuthService.get();
  private maxLogs: number = 10;

  aboutToAppear(): void {
    Logger.info(AuthTestPage.TAG, '测试页面加载');
    this.checkLoginStatus();
  }

  /**
   * 添加日志
   */
  addLog(message: string): void {
    const timestamp = new Date().toLocaleTimeString();
    this.logMessages.unshift(`[${timestamp}] ${message}`);
    if (this.logMessages.length > this.maxLogs) {
      this.logMessages = this.logMessages.slice(0, this.maxLogs);
    }
  }

  /**
   * 检查登录状态
   */
  async checkLoginStatus(): Promise<void> {
    try {
      this.addLog('检查登录状态...');
      this.isLoggedIn = await this.authService.isLoggedIn();
      this.providerName = this.authService.getProviderName();

      if (this.isLoggedIn) {
        const user = await this.authService.getCurrentUser();
        if (user) {
          this.updateUserInfo(user);
          this.loginStatus = '✅ 已登录';
          this.addLog(`已登录: ${user.nickname}`);
        } else {
          this.loginStatus = '❌ 未登录';
          this.addLog('未找到用户信息');
        }
      } else {
        this.loginStatus = '❌ 未登录';
        this.userName = '未登录';
        this.userId = '';
        this.userAvatar = '';
        this.addLog('用户未登录');
      }
    } catch (error) {
      Logger.error(AuthTestPage.TAG, `检查登录状态失败: ${error}`);
      this.loginStatus = '❌ 检查失败';
      this.addLog(`错误: ${error}`);
    }
  }

  /**
   * 更新用户信息显示
   */
  updateUserInfo(user: User): void {
    this.userName = user.nickname || '未设置昵称';
    this.userId = user.userId.substring(0, 16) + '...';
    this.userAvatar = user.avatar || '';
  }

  /**
   * 华为账号登录
   */
  async handleHuaweiLogin(): Promise<void> {
    if (this.isLoading) {
      return;
    }

    this.isLoading = true;
    this.addLog('开始华为账号登录...');

    try {
      // 切换到华为账号提供商
      const context = getContext(this) as common.UIAbilityContext;
      this.authService.useHuaweiAccount(context);
      this.providerName = this.authService.getProviderName();
      this.addLog(`切换到: ${this.providerName}`);

      // 执行登录
      const user = await this.authService.login();

      this.isLoggedIn = true;
      this.loginStatus = '✅ 登录成功';
      this.updateUserInfo(user);
      this.addLog(`登录成功: ${user.nickname}`);

      Logger.info(AuthTestPage.TAG, `华为账号登录成功: ${user.userId}`);
    } catch (error) {
      Logger.error(AuthTestPage.TAG, `华为账号登录失败: ${error}`);
      this.loginStatus = '❌ 登录失败';
      this.addLog(`登录失败: ${error}`);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 设备ID登录
   */
  async handleDeviceLogin(): Promise<void> {
    if (this.isLoading) {
      return;
    }

    this.isLoading = true;
    this.addLog('开始设备ID登录...');

    try {
      // 使用默认的DeviceAuthProvider
      const user = await this.authService.login();

      this.isLoggedIn = true;
      this.loginStatus = '✅ 登录成功';
      this.updateUserInfo(user);
      this.providerName = this.authService.getProviderName();
      this.addLog(`登录成功: ${user.nickname}`);

      Logger.info(AuthTestPage.TAG, `设备ID登录成功: ${user.userId}`);
    } catch (error) {
      Logger.error(AuthTestPage.TAG, `设备ID登录失败: ${error}`);
      this.loginStatus = '❌ 登录失败';
      this.addLog(`登录失败: ${error}`);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 登出
   */
  async handleLogout(): Promise<void> {
    if (this.isLoading) {
      return;
    }

    this.isLoading = true;
    this.addLog('开始登出...');

    try {
      await this.authService.logout();

      this.isLoggedIn = false;
      this.loginStatus = '❌ 未登录';
      this.userName = '未登录';
      this.userId = '';
      this.userAvatar = '';
      this.addLog('登出成功');

      Logger.info(AuthTestPage.TAG, '登出成功');
    } catch (error) {
      Logger.error(AuthTestPage.TAG, `登出失败: ${error}`);
      this.addLog(`登出失败: ${error}`);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 获取Token测试
   */
  async handleGetToken(): Promise<void> {
    if (this.isLoading) {
      return;
    }

    this.addLog('获取访问Token...');

    try {
      const token = await this.authService.getAccessToken();
      const shortToken = token.substring(0, 20) + '...';
      this.addLog(`Token: ${shortToken}`);
      Logger.info(AuthTestPage.TAG, `获取Token成功: ${shortToken}`);
    } catch (error) {
      Logger.error(AuthTestPage.TAG, `获取Token失败: ${error}`);
      this.addLog(`获取Token失败: ${error}`);
    }
  }

  /**
   * 清空日志
   */
  clearLogs(): void {
    this.logMessages = [];
    this.addLog('日志已清空');
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('认证功能测试')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E2A22')
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#F5F7F6')

      Scroll() {
        Column() {
          // 状态卡片
          Column() {
            Text('当前状态')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 12 })

            Row() {
              Text('登录状态：')
                .fontSize(14)
                .fontColor('#666')
              Text(this.loginStatus)
                .fontSize(14)
                .fontColor('#1E2A22')
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .margin({ bottom: 8 })

            Row() {
              Text('认证方式：')
                .fontSize(14)
                .fontColor('#666')
              Text(this.providerName || '未设置')
                .fontSize(14)
                .fontColor('#1E2A22')
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .margin({ bottom: 8 })

            if (this.isLoggedIn) {
              Divider()
                .margin({ top: 8, bottom: 8 })

              Row() {
                Text('用户昵称：')
                  .fontSize(14)
                  .fontColor('#666')
                Text(this.userName)
                  .fontSize(14)
                  .fontColor('#1E2A22')
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ bottom: 8 })

              Row() {
                Text('用户ID：')
                  .fontSize(14)
                  .fontColor('#666')
                Text(this.userId)
                  .fontSize(12)
                  .fontColor('#1E2A22')
                  .fontFamily('monospace')
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
            }
          }
          .width('90%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .shadow({ radius: 4, color: '#10000000' })
          .margin({ top: 16, bottom: 16 })

          // 操作按钮区域
          Column() {
            Text('操作')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 12 })

            Button('华为账号登录', { type: ButtonType.Normal })
              .width('100%')
              .height(44)
              .fontSize(15)
              .fontColor('#FFFFFF')
              .backgroundColor('#C62F38')
              .borderRadius(8)
              .margin({ bottom: 10 })
              .enabled(!this.isLoading && !this.isLoggedIn)
              .opacity((!this.isLoading && !this.isLoggedIn) ? 1.0 : 0.5)
              .onClick(() => this.handleHuaweiLogin())

            Button('设备ID登录', { type: ButtonType.Normal })
              .width('100%')
              .height(44)
              .fontSize(15)
              .fontColor('#1E2A22')
              .backgroundColor('#E8ECE9')
              .borderRadius(8)
              .margin({ bottom: 10 })
              .enabled(!this.isLoading && !this.isLoggedIn)
              .opacity((!this.isLoading && !this.isLoggedIn) ? 1.0 : 0.5)
              .onClick(() => this.handleDeviceLogin())

            Button('获取Token', { type: ButtonType.Normal })
              .width('100%')
              .height(44)
              .fontSize(15)
              .fontColor('#1E2A22')
              .backgroundColor('#E8ECE9')
              .borderRadius(8)
              .margin({ bottom: 10 })
              .enabled(!this.isLoading && this.isLoggedIn)
              .opacity((!this.isLoading && this.isLoggedIn) ? 1.0 : 0.5)
              .onClick(() => this.handleGetToken())

            Button('登出', { type: ButtonType.Normal })
              .width('100%')
              .height(44)
              .fontSize(15)
              .fontColor('#C62F38')
              .backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#C62F38' })
              .borderRadius(8)
              .margin({ bottom: 10 })
              .enabled(!this.isLoading && this.isLoggedIn)
              .opacity((!this.isLoading && this.isLoggedIn) ? 1.0 : 0.5)
              .onClick(() => this.handleLogout())

            Button('刷新状态', { type: ButtonType.Normal })
              .width('100%')
              .height(44)
              .fontSize(15)
              .fontColor('#1E2A22')
              .backgroundColor('#F5F7F6')
              .borderRadius(8)
              .enabled(!this.isLoading)
              .opacity(!this.isLoading ? 1.0 : 0.5)
              .onClick(() => this.checkLoginStatus())
          }
          .width('90%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .shadow({ radius: 4, color: '#10000000' })
          .margin({ bottom: 16 })

          // 日志区域
          Column() {
            Row() {
              Text('操作日志')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)

              Text('清空')
                .fontSize(14)
                .fontColor('#C62F38')
                .onClick(() => this.clearLogs())
            }
            .width('100%')
            .margin({ bottom: 12 })

            if (this.logMessages.length === 0) {
              Text('暂无日志')
                .fontSize(14)
                .fontColor('#999')
                .margin({ top: 20, bottom: 20 })
            } else {
              Column() {
                ForEach(this.logMessages, (log: string, index: number) => {
                  Text(log)
                    .fontSize(12)
                    .fontColor('#666')
                    .fontFamily('monospace')
                    .width('100%')
                    .padding({ top: 4, bottom: 4 })
                    .border({
                      width: { bottom: index < this.logMessages.length - 1 ? 0.5 : 0 },
                      color: '#E8ECE9'
                    })
                }, (log: string, index: number) => `${index}_${log}`)
              }
              .width('100%')
            }
          }
          .width('90%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .shadow({ radius: 4, color: '#10000000' })
          .margin({ bottom: 20 })

        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)

    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F0F2F1')
  }
}
