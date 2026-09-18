/*
 * ============================================================================
 * 文件名：service/ai/AIService.ets
 * ============================================================================
 * 【用途】AI服务统一入口（重构版 - 云服务架构）
 * 【功能】
 *   - 统一管理LLM服务和文生图服务
 *   - 云服务模式 + Mock降级
 *   - 依赖AuthService进行用户认证
 * 【架构】
 *   AIService (统一入口)
 *     ├─ LLMService (对话服务)
 *     ├─ ImageGenService (文生图服务)
 *     ├─ AuthService (用户认证)
 *     └─ CloudBackendService (云服务后端)
 * ============================================================================
 */
import { LLMService } from './LLMService';
import { ImageGenService } from './ImageGenService';
import { AuthService } from '../auth/AuthService';
import { CloudBackendService } from '../backend/CloudBackendService';
import { Logger } from '../../utils/Logger';
import { EventItem } from '../../model/Models';

interface ComicScene {
  index: number;
  title: string;
  description: string;
  emotion: string;
}

interface ComicScriptData {
  title: string;
  scenes: ComicScene[];
}

export class AIService {
  private static readonly TAG = 'AIService';
  private static instance: AIService | null = null;

  private llmService: LLMService;
  private imageGenService: ImageGenService;
  private authService: AuthService;
  private cloudService: CloudBackendService;
  private isInitialized: boolean = false;

  private constructor() {
    this.llmService = LLMService.get();
    this.imageGenService = ImageGenService.get();
    this.authService = AuthService.get();
    this.cloudService = CloudBackendService.get();
  }

  static get(): AIService {
    if (AIService.instance === null) {
      AIService.instance = new AIService();
    }
    return AIService.instance;
  }

  /**
   * 初始化AI服务
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      Logger.info(AIService.TAG, 'AI服务已初始化');
      return;
    }

    Logger.info(AIService.TAG, '开始初始化AI服务（云服务架构）...');

    try {
      // 1. 初始化认证服务
      await this.authService.initialize();
      Logger.info(AIService.TAG, `用户认证完成: ${this.authService.getProviderName()}`);

      // 2. 检查用户登录状态
      const isLoggedIn = await this.authService.isLoggedIn();
      if (!isLoggedIn) {
        throw new Error('用户未登录');
      }

      // 3. 获取当前用户
      const user = await this.authService.getCurrentUser();
      Logger.info(AIService.TAG, `当前用户: ${user?.userId || '未知'}`);

      // 4. 检查运行模式
      const isMockMode = this.cloudService.isMockMode();
      Logger.info(AIService.TAG, `运行模式: ${isMockMode ? 'Mock (离线)' : '云服务 (在线)'}`);

      this.isInitialized = true;
      Logger.info(AIService.TAG, 'AI服务初始化完成');
    } catch (error) {
      Logger.error(AIService.TAG, `初始化失败: ${error}`);
      // 即使失败也标记为已初始化，使用Mock模式
      this.isInitialized = true;
    }
  }

  /**
   * 获取当前运行模式
   */
  getProviderName(): string {
    return this.cloudService.isMockMode() ? 'Mock (离线模式)' : '云服务 (在线模式)';
  }

  /**
   * 是否为离线模式
   */
  isOfflineMode(): boolean {
    return this.cloudService.isMockMode();
  }

  /**
   * 生成每日总结
   * @param events 今日事件列表
   * @param context 额外上下文（可选）
   */
  async generateDailySummary(events: EventItem[], context?: string): Promise<string> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    return await this.llmService.generateDailySummary(events, context);
  }

  /**
   * 生成漫画分镜脚本
   * @param dailySummary 每日总结
   * @param events 今日事件
   */
  async generateComicScript(dailySummary: string, events: EventItem[]): Promise<string> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    return await this.llmService.generateComicScript(dailySummary, events);
  }

  /**
   * 处理用户反馈并生成记忆更新指令
   * @param memoryId 记忆ID
   * @param memoryContent 当前记忆内容
   * @param userFeedback 用户反馈
   */
  async processMemoryCorrection(
    memoryId: string,
    memoryContent: string,
    userFeedback: string
  ): Promise<string> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    return await this.llmService.processMemoryCorrection(memoryId, memoryContent, userFeedback);
  }

  /**
   * 生成图像（单张）
   * @param prompt 图像描述
   * @param style 风格（可选）
   */
  async generateImage(prompt: string, style?: string): Promise<string> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    return await this.imageGenService.generateImage(prompt, style);
  }

  /**
   * 生成漫画分镜图像
   * @param comicScript 漫画脚本（JSON字符串）
   */
  async generateComicImages(comicScript: string): Promise<string[]> {
    if (!this.isInitialized) {
      await this.initialize();
    }

    try {
      const script: ComicScriptData = JSON.parse(comicScript);
      const panels = script.scenes || [];

      const panelsWithImages = await this.imageGenService.generateComicPanels(panels);

      return panelsWithImages.map(p => p.imageUrl || '');
    } catch (err) {
      Logger.error(AIService.TAG, `生成漫画图像失败: ${err}`);
      throw new Error(`生成漫画图像失败: ${err}`);
    }
  }
}
