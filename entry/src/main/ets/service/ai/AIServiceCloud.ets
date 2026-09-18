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
import { EventItem } from '../../model/Models';

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
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      Logger.info(AIServiceCloud.TAG, 'AI云服务已初始化');
      return;
    }

    Logger.info(AIServiceCloud.TAG, '开始初始化AI云服务...');

    try {
      // 1. 初始化认证服务
      await this.authService.initialize();
      Logger.info(AIServiceCloud.TAG, '✅ 用户认证完成');

      // 2. 初始化华为云服务
      await this.cloudManager.initialize();
      Logger.info(AIServiceCloud.TAG, '✅ 华为云服务初始化完成');

      // 3. 创建或加载用户信息
      await this.ensureUserProfile();

      this.isInitialized = true;
      Logger.info(AIServiceCloud.TAG, '🎉 AI云服务初始化成功');
    } catch (err) {
      Logger.error(AIServiceCloud.TAG, `❌ 初始化失败: ${err}`);
      throw new Error(`AI云服务初始化失败: ${err}`);
    }
  }

  /**
   * 确保用户信息存在
   */
  private async ensureUserProfile(): Promise<void> {
    const user = await this.authService.getCurrentUser();
    if (!user) {
      throw new Error('未找到当前用户');
    }

    const cloudDB = this.cloudManager.getCloudDB();
    let profile = await cloudDB.getUser(user.userId);

    if (!profile) {
      // 首次登录，创建用户信息
      profile = new UserProfile(user.userId);
      profile.username = user.username;
      profile.email = user.email || '';
      profile.avatar = user.avatar || '';

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
      throw new Error('用户未登录');
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
    const cloudDB = this.cloudManager.getCloudDB();
    const cloudFunction = this.cloudManager.getCloudFunction();

    try {
      // 1. 检查配额
      const hasQuota = await cloudDB.consumeLLMQuota(userId, 1);
      if (!hasQuota) {
        throw new Error('LLM配额不足，请明天再试');
      }

      // 2. 调用云函数生成总结
      const request: LLMRequest = {
        userId: userId,
        events: events.map(e => `${e.time} ${e.content}`),
        mood: mood || '平静'
      };

      const response = await cloudFunction.generateDailySummary(request);
      const summary = response.content;

      // 3. 保存到数据库
      const today = this.getToday();
      const record = await cloudDB.getDailyRecord(userId, today);

      if (record) {
        record.summary = summary;
        record.mood = mood || '平静';
        record.setEvents(events);
        await cloudDB.upsertDailyRecord(record);
      } else {
        const newRecord = new DailyRecord(userId, today);
        newRecord.summary = summary;
        newRecord.mood = mood || '平静';
        newRecord.setEvents(events);
        await cloudDB.upsertDailyRecord(newRecord);
      }

      Logger.info(AIServiceCloud.TAG, '✅ 每日总结生成成功');
      return summary;
    } catch (err) {
      Logger.error(AIServiceCloud.TAG, `生成总结失败: ${err}`);
      throw err;
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
  async generateComicScript(summary: string, events: EventItem[]): Promise<ComicPanel[]> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    const userId = await this.getCurrentUserId();
    const cloudDB = this.cloudManager.getCloudDB();
    const cloudFunction = this.cloudManager.getCloudFunction();

    try {
      // 1. 检查配额
      const hasQuota = await cloudDB.consumeLLMQuota(userId, 1);
      if (!hasQuota) {
        throw new Error('LLM配额不足');
      }

      // 2. 调用云函数生成脚本
      const request: LLMRequest = {
        userId: userId,
        summary: summary,
        events: events.map(e => `${e.time} ${e.content}`)
      };

      const response = await cloudFunction.generateComicScript(request);
      const panels = response.panels;

      // 3. 保存脚本到数据库
      const today = this.getToday();
      const record = await cloudDB.getDailyRecord(userId, today);

      if (record) {
        record.comicScript = JSON.stringify(panels);
        await cloudDB.upsertDailyRecord(record);
      }

      Logger.info(AIServiceCloud.TAG, `✅ 漫画脚本生成成功，共${panels.length}个分镜`);
      return panels;
    } catch (err) {
      Logger.error(AIServiceCloud.TAG, `生成脚本失败: ${err}`);
      throw err;
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
    const cloudDB = this.cloudManager.getCloudDB();
    const cloudFunction = this.cloudManager.getCloudFunction();
    const cloudStorage = this.cloudManager.getCloudStorage();

    try {
      // 1. 检查配额
      const hasQuota = await cloudDB.consumeImageQuota(userId, panels.length);
      if (!hasQuota) {
        throw new Error('文生图配额不足');
      }

      // 2. 批量生成图片（异步）
      const imageUrls: string[] = [];
      const today = this.getToday();
      const recordId = `${userId}_${today}`;

      for (let i = 0; i < panels.length; i++) {
        const panel = panels[i];

        // 创建图片记录
        const comicImage = new ComicImage(userId, recordId, i);
        comicImage.prompt = panel.prompt;
        comicImage.status = 'generating';

        // 调用云函数生成图片
        const request: ImageGenerationRequest = {
          userId: userId,
          prompt: panel.prompt,
          style: 'comic',
          size: '1024x1024'
        };

        const response = await cloudFunction.generateImage(request);
        comicImage.taskId = response.taskId;

        // 等待生成完成
        const imageUrl = await cloudFunction.waitForImage(response.taskId, 60000);

        comicImage.imageUrl = imageUrl;
        comicImage.status = 'success';
        comicImage.completedAt = Date.now();

        await cloudDB.upsertComicImage(comicImage);
        imageUrls.push(imageUrl);

        Logger.info(AIServiceCloud.TAG, `✅ 分镜${i + 1}生成完成`);
      }

      // 3. 更新记录
      const record = await cloudDB.getDailyRecord(userId, today);
      if (record) {
        record.setComicImages(imageUrls);
        await cloudDB.upsertDailyRecord(record);
      }

      Logger.info(AIServiceCloud.TAG, `✅ 漫画图片全部生成完成`);
      return imageUrls;
    } catch (err) {
      Logger.error(AIServiceCloud.TAG, `生成图片失败: ${err}`);
      throw err;
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
    const cloudDB = this.cloudManager.getCloudDB();
    const cloudFunction = this.cloudManager.getCloudFunction();

    try {
      // 1. 检查配额
      const hasQuota = await cloudDB.consumeLLMQuota(userId, 1);
      if (!hasQuota) {
        throw new Error('LLM配额不足');
      }

      // 2. 调用云函数处理纠正
      const request: MemoryCorrectionRequest = {
        userId: userId,
        originalSummary: originalSummary,
        userCorrection: userCorrection
      };

      const response = await cloudFunction.processMemoryCorrection(request);
      const correctedSummary = response.content;

      // 3. 更新数据库
      const today = this.getToday();
      const record = await cloudDB.getDailyRecord(userId, today);

      if (record) {
        record.summary = correctedSummary;
        await cloudDB.upsertDailyRecord(record);
      }

      Logger.info(AIServiceCloud.TAG, '✅ 记忆纠正完成');
      return correctedSummary;
    } catch (err) {
      Logger.error(AIServiceCloud.TAG, `纠正失败: ${err}`);
      throw err;
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
      throw new Error('未找到用户信息');
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
