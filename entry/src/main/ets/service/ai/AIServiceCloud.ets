/*
 * ============================================================================
 * 文件名：service/ai/AIServiceCloud.ets
 * ============================================================================
 * 【用途】基于华为云服务的AI服务（新版）
 * 【功能】
 *   - 使用华为云函数调用DeepSeek和即梦AI
 *   - 使用华为云数据库存储数据
 *   - 使用华为云存储管理图片
 *   - 配额管理
 * 【架构】
 *   AIServiceCloud
 *     ├─ CloudServiceManager (华为云服务管理器)
 *     ├─ AuthService (认证服务)
 *     └─ Mock降级支持
 * ============================================================================
 */
import { Logger } from '../../utils/Logger';
import { CloudServiceManager } from '../cloud/CloudServiceManager';
import { AuthService } from '../auth/AuthService';
import { UserProfile, DailyRecord, ComicImage } from '../cloud/CloudDBModels';
import {
  LLMRequest,
  ComicPanel,
  ImageGenerationRequest,
  MemoryCorrectionRequest
} from '../cloud/CloudFunctionService';
import { EventItem, PersonalityProfile } from '../../model/Models';
import { ComicPromptBuilder } from './ComicPromptBuilder';

export class AIServiceCloud {
  private static readonly TAG = 'AIServiceCloud';
  private static instance: AIServiceCloud | null = null;

  private cloudManager: CloudServiceManager;
  private authService: AuthService;
  private isInitialized: boolean = false;

  private constructor() {
    this.cloudManager = CloudServiceManager.get();
    this.authService = AuthService.get();
  }

  static get(): AIServiceCloud {
    if (AIServiceCloud.instance === null) {
      AIServiceCloud.instance = new AIServiceCloud();
    }
    return AIServiceCloud.instance;
  }

  /**
   * 初始化服务
   */
  async initialize(context?: Context): Promise<void> {
    if (this.isInitialized) {
      Logger.info(AIServiceCloud.TAG, 'AI云服务已初始化');
      return;
    }

    Logger.info(AIServiceCloud.TAG, '开始初始化AI云服务...');

    try {
      // 1. 初始化认证服务
      await this.authService.initialize();
      Logger.info(AIServiceCloud.TAG, '✅ 用户认证完成');

      // 游客没有 CloudDB Creator 身份；真实 AI 只依赖云函数，不以档案/配额阻断调用。
      await this.cloudManager.getCloudFunction().initialize();

      this.isInitialized = true;
      Logger.info(AIServiceCloud.TAG, '🎉 AI云服务初始化成功');
    } catch (err) {
      Logger.error(AIServiceCloud.TAG, `❌ 初始化失败: ${err}`);
      const error = new Error(`AI云服务初始化失败: ${err}`);
      return Promise.reject(error);
    }
  }

  /**
   * 确保用户信息存在
   */
  private async ensureUserProfile(): Promise<void> {
    const user = await this.authService.getCurrentUser();
    if (!user) {
      const error = new Error('未找到当前用户');
      return Promise.reject(error);
    }

    const cloudDB = this.cloudManager.getCloudDB();
    let profile = await cloudDB.getUser(user.userId);

    if (!profile) {
      profile = new UserProfile(user.userId);
      profile.username = user.nickname || '用户';
      profile.email = '';
      profile.avatar = '';

      await cloudDB.upsertUser(profile);
      Logger.info(AIServiceCloud.TAG, `创建用户信息: ${user.userId}`);
    }
  }

  /**
   * 获取当前用户ID
   */
  private async getCurrentUserId(): Promise<string> {
    const user = await this.authService.getCurrentUser();
    if (!user) {
      const error = new Error('用户未登录');
      return Promise.reject(error);
    }
    return user.userId;
  }

  // ==================== 每日总结 ====================

  /**
   * 生成每日总结
   */
  async generateDailySummary(events: EventItem[], mood?: string): Promise<string> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    const userId = await this.getCurrentUserId();
    const cloudFunction = this.cloudManager.getCloudFunction();

    try {
      const request: LLMRequest = {
        userId: userId,
        events: events.map(e => `${e.time} ${e.content}`),
        mood: mood || '平静'
      };

      const response = await cloudFunction.generateDailySummary(request);
      Logger.info(AIServiceCloud.TAG, '✅ 每日总结生成成功');
      return response.content;
    } catch (err) {
      Logger.error(AIServiceCloud.TAG, `生成总结失败: ${err}`);
      const error = new Error(`生成总结失败: ${err}`);
      return Promise.reject(error);
    }
  }

  /**
   * 获取历史总结
   */
  async getHistorySummaries(limit: number = 30): Promise<DailyRecord[]> {
    const userId = await this.getCurrentUserId();
    const cloudDB = this.cloudManager.getCloudDB();
    return await cloudDB.getUserRecords(userId, limit);
  }

  // ==================== 漫画生成 ====================

  /**
   * 生成漫画脚本
   */
  async generateComicScript(summary: string, events: EventItem[], profile?: PersonalityProfile): Promise<ComicPanel[]> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    const userId = await this.getCurrentUserId();
    const cloudFunction = this.cloudManager.getCloudFunction();

    try {
      const request: LLMRequest = {
        userId: userId,
        summary: summary,
        events: events.map(e => `${e.time} ${e.content}`),
        style: ComicPromptBuilder.fromProfile(profile)
      };

      const response = await cloudFunction.generateComicScript(request);
      const panels = response.panels;

      Logger.info(AIServiceCloud.TAG, `✅ 漫画脚本生成成功，共${panels.length}个分镜`);
      return panels;
    } catch (err) {
      Logger.error(AIServiceCloud.TAG, `生成脚本失败: ${err}`);
      const error = new Error(`生成脚本失败: ${err}`);
      return Promise.reject(error);
    }
  }

  /**
   * 生成漫画图片
   */
  async generateComicImages(panels: ComicPanel[]): Promise<string[]> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    const userId = await this.getCurrentUserId();
    const cloudFunction = this.cloudManager.getCloudFunction();

    try {
      const responses = await cloudFunction.generateComicImages(userId, panels);
      const imageUrls: string[] = responses.map((response) => response.imageUrl!);

      Logger.info(AIServiceCloud.TAG, `✅ 漫画图片全部生成完成`);
      return imageUrls;
    } catch (err) {
      Logger.error(AIServiceCloud.TAG, `生成图片失败: ${err}`);
      const error = new Error(`生成图片失败: ${err}`);
      return Promise.reject(error);
    }
  }

  /**
   * 下载漫画图片到本地
   */
  async downloadComicImages(imageUrls: string[]): Promise<string[]> {
    const cloudStorage = this.cloudManager.getCloudStorage();
    const userId = await this.getCurrentUserId();
    const today = this.getToday();
    const recordId = `${userId}_${today}`;

    return await cloudStorage.downloadComicImages(imageUrls, recordId);
  }

  // ==================== 记忆纠正 ====================

  /**
   * 处理记忆纠正
   */
  async processMemoryCorrection(
    originalSummary: string,
    userCorrection: string
  ): Promise<string> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    const userId = await this.getCurrentUserId();
    const cloudFunction = this.cloudManager.getCloudFunction();

    try {
      const request: MemoryCorrectionRequest = {
        userId: userId,
        originalSummary: originalSummary,
        userCorrection: userCorrection
      };

      const response = await cloudFunction.processMemoryCorrection(request);
      Logger.info(AIServiceCloud.TAG, '✅ 记忆纠正完成');
      return response.content;
    } catch (err) {
      Logger.error(AIServiceCloud.TAG, `纠正失败: ${err}`);
      const error = new Error(`纠正失败: ${err}`);
      return Promise.reject(error);
    }
  }

  // ==================== 配额查询 ====================

  /**
   * 获取用户配额信息
   */
  async getUserQuota(): Promise<QuotaInfo> {
    const userId = await this.getCurrentUserId();
    const cloudDB = this.cloudManager.getCloudDB();

    const user = await cloudDB.checkAndResetQuota(userId);

    if (!user) {
      const error = new Error('未找到用户信息');
      return Promise.reject(error);
    }

    return {
      llmDaily: user.llmQuotaDaily,
      llmUsed: user.llmQuotaUsed,
      llmRemaining: user.llmQuotaDaily - user.llmQuotaUsed,
      imageDaily: user.imageQuotaDaily,
      imageUsed: user.imageQuotaUsed,
      imageRemaining: user.imageQuotaDaily - user.imageQuotaUsed,
      lastReset: new Date(user.lastQuotaReset).toLocaleString()
    };
  }

  // ==================== 工具函数 ====================

  /**
   * 获取今天的日期（YYYY-MM-DD）
   */
  private getToday(): string {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
}

/**
 * 配额信息
 */
export interface QuotaInfo {
  llmDaily: number;
  llmUsed: number;
  llmRemaining: number;
  imageDaily: number;
  imageUsed: number;
  imageRemaining: number;
  lastReset: string;
}
