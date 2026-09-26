/*
 * ============================================================================
 * 文件名：entryability/EntryAbility.ets
 * ============================================================================
 * 【用途】Ability 入口：onCreate/onWindowStageCreate 阶段加载 MainPage，
 *   解析启动参数 want.parameters.autoNav（开发调试自动跳转，格式 "autoNav":"值"），
 *   设置窗口全屏沉浸（无标题栏）后加载页面。
 * 【前置条件 / 假设】
 *   - 依赖：@kit.AbilityKit/@kit.ArkUI、AppRouter、Services；
 *   - 假设：单 WindowStage 手机场景；autoNav 仅在开发（--ps autoNav xxx）时使用。
 * 【输入 / 输出（后置条件）】
 *   - 输入：want 参数（autoNav 字符串）；
 *   - 输出：窗口加载 MainPage；autoNav 写入 AppRouter.autoNav（MainPage 消费后清空）；
 *   - 后置：窗口去标题栏 + 全屏布局（LayoutFullScreen）。
 * 【关键类 / 算法】
 *   - regex 提取参数：/\"autoNav\":\"([^"]+)\"/
 * 【参考源】
 *   - DevEco 模板 EntryAbility；AbilityKit 文档
 * ============================================================================
 */
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { AppRouter } from '../router/AppRouter';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AIServiceCloud } from '../service/ai/AIServiceCloud';
import { EventRepository } from '../repository/Repositories';
import { DataSyncService } from '../service/DataSyncService';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
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

    // 初始化数据同步服务（异步，不阻塞启动）
    this.initializeDataSync();

    // 初始化 AI 云服务（异步，不阻塞启动）
    this.initializeAIService();

    // 初始化系统数据服务（异步，不阻塞启动）
    this.initializeSystemDataService();
  }

  /**
   * 初始化数据同步服务
   */
  private initializeDataSync(): void {
    DataSyncService.get().initialize(this.context)
      .then(() => {
        hilog.info(DOMAIN, 'MoMo', '数据同步服务初始化成功');
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, 'MoMo', `数据同步服务初始化失败: ${err.message}`);
        // 初始化失败不影响应用启动，降级到本地存储
      });
  }

  /**
   * 初始化 AI 云服务
   */
  private initializeAIService(): void {
    AIServiceCloud.get().initialize(this.context)
      .then(() => {
        hilog.info(DOMAIN, 'MoMo', 'AI云服务初始化成功');
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, 'MoMo', `AI云服务初始化失败: ${err.message}`);
        // 初始化失败不影响应用启动，后续调用会降级到 Mock
      });
  }

  /**
   * 初始化系统数据服务
   */
  private initializeSystemDataService(): void {
    EventRepository.get().initSystemData(this.context)
      .then(() => {
        hilog.info(DOMAIN, 'MoMo', '系统数据服务初始化成功');
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, 'MoMo', `系统数据服务初始化失败: ${err.message}`);
        // 初始化失败不影响应用启动，后续调用会降级到 Mock
      });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'MoMo', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 加载登录页面
    windowStage.loadContent('pages/LoginPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'MoMo', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'MoMo', 'Succeeded in loading the content.');
      // 官方沉浸式配置：全屏布局 + 状态栏/导航栏透明（详见《HarmonyOS 沉浸式窗口》文档）
      this.setImmersiveWindow();
    });
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
