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
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'MoMo', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/MainPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'MoMo', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'MoMo', 'Succeeded in loading the content.');
    });
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