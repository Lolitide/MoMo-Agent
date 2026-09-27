/*
 * ============================================================================
 * 文件名：service/ai/AIConfigManager.ets
 * ============================================================================
 * 【用途】AI配置管理，负责加载和保存配置
 * 【配置来源】
 *   1. rawfile/ai_config.json（开发配置，不入库）
 *   2. Preferences持久化存储（用户修改的配置）
 * ============================================================================
 */
import { AIConfig, DEFAULT_AI_CONFIG } from './AIModels';
import { Logger } from '../../utils/Logger';
import preferences from '@ohos.data.preferences';
import { resourceManager } from '@kit.LocalizationKit';

export class AIConfigManager {
  private static readonly TAG = 'AIConfigManager';
  private static readonly PREFS_NAME = 'ai_config';

  /**
   * 加载配置
   * 优先级：Preferences > rawfile > 默认配置
   */
  static async loadConfig(): Promise<AIConfig> {
    try {
      // 1. 尝试从Preferences加载
      const prefsConfig = await AIConfigManager.loadFromPreferences();
      if (prefsConfig && prefsConfig.apiKey) {
        Logger.info(AIConfigManager.TAG, '从Preferences加载配置');
        return prefsConfig;
      }

      // 2. 尝试从rawfile加载
      const rawfileConfig = await AIConfigManager.loadFromRawfile();
      if (rawfileConfig && rawfileConfig.apiKey) {
        Logger.info(AIConfigManager.TAG, '从rawfile加载配置');
        return rawfileConfig;
      }

      // 3. 使用默认配置
      Logger.info(AIConfigManager.TAG, '使用默认配置（Mock模式）');
      return DEFAULT_AI_CONFIG;
    } catch (error) {
      Logger.error(AIConfigManager.TAG, `加载配置失败: ${error}`);
      return DEFAULT_AI_CONFIG;
    }
  }

  /**
   * 保存配置到Preferences
   */
  static async saveConfig(config: AIConfig): Promise<void> {
    try {
      const context = getContext(this);
      const prefs = await preferences.getPreferences(context, AIConfigManager.PREFS_NAME);

      await prefs.put('provider', config.provider);
      await prefs.put('apiKey', config.apiKey);
      await prefs.put('baseUrl', config.baseUrl);
      await prefs.put('model', config.model);
      await prefs.put('timeout', config.timeout ?? 30000);
      await prefs.put('retry', config.retry ?? 3);

      await prefs.flush();
      Logger.info(AIConfigManager.TAG, '配置保存成功');
    } catch (error) {
      Logger.error(AIConfigManager.TAG, `保存配置失败: ${error}`);
      throw error;
    }
  }

  /**
   * 从Preferences加载配置
   */
  private static async loadFromPreferences(): Promise<AIConfig | null> {
    try {
      const context = getContext(this);
      const prefs = await preferences.getPreferences(context, AIConfigManager.PREFS_NAME);

      const provider = await prefs.get('provider', '') as string;
      if (!provider) {
        return null;
      }

      const config: AIConfig = {
        provider: provider as AIConfig['provider'],
        apiKey: await prefs.get('apiKey', '') as string,
        baseUrl: await prefs.get('baseUrl', '') as string,
        model: await prefs.get('model', 'deepseek-chat') as string,
        timeout: await prefs.get('timeout', 30000) as number,
        retry: await prefs.get('retry', 3) as number
      };

      return config;
    } catch (error) {
      Logger.warn(AIConfigManager.TAG, `从Preferences加载失败: ${error}`);
      return null;
    }
  }

  /**
   * 从rawfile加载配置
   */
  private static async loadFromRawfile(): Promise<AIConfig | null> {
    try {
      const context = getContext(this);
      const mgr: resourceManager.ResourceManager = context.resourceManager;

      const fileData = await mgr.getRawFileContent('ai_config.json');
      const decoder = new util.TextDecoder('utf-8');
      const configText = decoder.decodeWithStream(fileData);

      const config = JSON.parse(configText) as AIConfig;
      Logger.info(AIConfigManager.TAG, `rawfile配置: provider=${config.provider}`);

      return config;
    } catch (error) {
      Logger.warn(AIConfigManager.TAG, `从rawfile加载失败: ${error}`);
      return null;
    }
  }

  /**
   * 清除配置
   */
  static async clearConfig(): Promise<void> {
    try {
      const context = getContext(this);
      await preferences.deletePreferences(context, AIConfigManager.PREFS_NAME);
      Logger.info(AIConfigManager.TAG, '配置已清除');
    } catch (error) {
      Logger.error(AIConfigManager.TAG, `清除配置失败: ${error}`);
    }
  }
}
