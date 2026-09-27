/*
 * ============================================================================
 * 文件名：entryability/EntryAbility_WithHuaweiLogin.ets
 * ============================================================================
 * 【用途】示例：集成华为账号登录的EntryAbility
 * 【说明】这是一个示例文件，展示如何在应用启动时配置华为账号登录
 * 【使用方法】
 *   1. 将此文件内容复制到 EntryAbility.ets
 *   2. 或者参考此文件修改现有的 EntryAbility.ets
 * ============================================================================
 */
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { AppRouter } from '../router/AppRouter';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AuthService } from '../service/auth';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private authService: AuthService = AuthService.get();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      const raw = JSON.stringify(want.parameters ?? {});
      const m = raw.match(/"autoNav":"([^"]+)"/);
      if (m !== null && m.length > 1) {
        AppRouter.autoNav = m[1];
      }
    } catch (e) {
      AppRouter.autoNav = '';
    }
    hilog.info(DOMAIN, 'MoMo', 'Ability onCreate autoNav=' + AppRouter.autoNav);

    // 【新增】初始化华为账号登录
    this.initializeAuth();
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'MoMo', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 【选项1】加载登录页面作为首页
    // windowStage.loadContent('pages/LoginPage', (err) => {

    // 【选项2】加载测试页面
    windowStage.loadContent('pages/B_AITest_V2', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'MoMo', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'MoMo', 'Succeeded in loading the content.');
      this.setImmersiveWindow();
    });
  }

  /**
   * 【新增】初始化认证服务
   */
  private async initializeAuth(): Promise<void> {
    try {
      hilog.info(DOMAIN, 'MoMo', '开始初始化认证服务...');

      // 配置使用华为账号登录
      this.authService.useHuaweiAccount(this.context);

      // 尝试自动登录（静默登录）
      await this.authService.initialize();

      // 检查登录状态
      const isLoggedIn = await this.authService.isLoggedIn();
      if (isLoggedIn) {
        const user = await this.authService.getCurrentUser();
        hilog.info(DOMAIN, 'MoMo', `用户已登录: ${user?.nickname}`);
      } else {
        hilog.info(DOMAIN, 'MoMo', '用户未登录，需要手动登录');
      }

    } catch (error) {
      hilog.error(DOMAIN, 'MoMo', `认证初始化失败: ${error}`);
      // 初始化失败不影响应用启动，用户可以稍后手动登录
    }
  }

  /** 设置沉浸式窗口：布局扩展到系统安全区之外，状态栏/底部横条区域改为透明（由页面背景接管） */
  private setImmersiveWindow(): void {
    try {
      const win = window.getLastWindow(this.context);
      win.then((w: window.Window) => {
        w.setWindowLayoutFullScreen(true);
        w.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          navigationBarColor: '#00000000',
          statusBarContentColor: '#1E2A22',
          navigationBarContentColor: '#1E2A22'
        });
        hilog.info(DOMAIN, 'MoMo', 'Immersive window configured');
      }).catch((e: Error) => {
        hilog.warn(DOMAIN, 'MoMo', 'setImmersiveWindow failed: ' + e.message);
      });
    } catch (e) {
      hilog.warn(DOMAIN, 'MoMo', 'setImmersiveWindow exception');
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'MoMo', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'MoMo', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'MoMo', 'Ability onBackground');
  }
}
