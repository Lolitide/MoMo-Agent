/*
 * ============================================================================
 * 文件名：service/backend/CloudBackendService.ets
 * ============================================================================
 * 【用途】云服务后端API封装
 * 【功能】
 *   - 统一管理所有后端API调用
 *   - 自动处理Token
 *   - Mock模式降级
 * ============================================================================
 */
import { CloudHttpClient } from './CloudHttpClient';
import { CloudConfig, DEFAULT_CLOUD_CONFIG } from './CloudConfig';
import { Logger } from '../../utils/Logger';
import { EventItem } from '../../model/Models';

/**
 * LLM相关请求/响应
 */
export interface DailySummaryRequest {
  events: EventItem[];
  context?: string;
}

interface InsightItem {
  title: string;
  content: string;
}

export interface DailySummaryResponse {
  summary: string;
  emotion: string;
  theme: string;
  insights: InsightItem[];
}

interface ComicScene {
  index: number;
  title: string;
  description: string;
  emotion: string;
}

export interface ComicScriptRequest {
  dailySummary: string;
  events: EventItem[];
}

export interface ComicScriptResponse {
  title: string;
  scenes: ComicScene[];
}

export interface MemoryCorrectionRequest {
  memoryId: string;
  memoryContent: string;
  userFeedback: string;
}

export interface MemoryCorrectionResponse {
  action: string;
  memoryId: string;
  updates: object;
  reasoning: string;
}

/**
 * 文生图相关请求/响应
 */
export interface ImageGenerateRequest {
  prompt: string;
  style?: string;
  size?: string;
}

export interface ImageGenerateResponse {
  taskId: string;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  imageUrl?: string;
  estimatedTime?: number; // 预计完成时间（秒）
}

export interface ImageStatusResponse {
  taskId: string;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  imageUrl?: string;
  progress?: number; // 0-100
}

/**
 * 云服务后端服务类
 */
export class CloudBackendService {
  private static readonly TAG = 'CloudBackendService';
  private static instance: CloudBackendService | null = null;

  private config: CloudConfig = DEFAULT_CLOUD_CONFIG;

  static get(): CloudBackendService {
    if (CloudBackendService.instance === null) {
      CloudBackendService.instance = new CloudBackendService();
    }
    return CloudBackendService.instance;
  }

  /**
   * 设置配置
   */
  setConfig(config: CloudConfig): void {
    this.config = config;
    Logger.info(CloudBackendService.TAG, `配置已更新: ${config.baseUrl}`);
  }

  /**
   * 检查是否为Mock模式
   */
  isMockMode(): boolean {
    return this.config.enableMockMode;
  }

  // ==================== LLM API ====================

  /**
   * 生成每日总结
   */
  async generateDailySummary(request: DailySummaryRequest): Promise<DailySummaryResponse> {
    Logger.info(CloudBackendService.TAG, '请求生成每日总结');

    try {
      const response = await CloudHttpClient.post<DailySummaryResponse>(
        `${this.config.baseUrl}/api/llm/daily-summary`,
        request
      );

      return response.data;
    } catch (error) {
      Logger.error(CloudBackendService.TAG, `生成每日总结失败: ${error}`);
      throw new Error(`生成每日总结失败: ${error}`);
    }
  }

  /**
   * 生成漫画脚本
   */
  async generateComicScript(request: ComicScriptRequest): Promise<ComicScriptResponse> {
    Logger.info(CloudBackendService.TAG, '请求生成漫画脚本');

    try {
      const response = await CloudHttpClient.post<ComicScriptResponse>(
        `${this.config.baseUrl}/api/llm/comic-script`,
        request
      );

      return response.data;
    } catch (error) {
      Logger.error(CloudBackendService.TAG, `生成漫画脚本失败: ${error}`);
      throw new Error(`生成漫画脚本失败: ${error}`);
    }
  }

  /**
   * 处理记忆纠正
   */
  async processMemoryCorrection(request: MemoryCorrectionRequest): Promise<MemoryCorrectionResponse> {
    Logger.info(CloudBackendService.TAG, '请求处理记忆纠正');

    try {
      const response = await CloudHttpClient.post<MemoryCorrectionResponse>(
        `${this.config.baseUrl}/api/llm/memory-correction`,
        request
      );

      return response.data;
    } catch (error) {
      Logger.error(CloudBackendService.TAG, `处理记忆纠正失败: ${error}`);
      throw new Error(`处理记忆纠正失败: ${error}`);
    }
  }

  // ==================== 文生图 API ====================

  /**
   * 生成图像
   */
  async generateImage(request: ImageGenerateRequest): Promise<ImageGenerateResponse> {
    Logger.info(CloudBackendService.TAG, `请求生成图像: ${request.prompt}`);

    try {
      const response = await CloudHttpClient.post<ImageGenerateResponse>(
        `${this.config.baseUrl}/api/image/generate`,
        request
      );

      return response.data;
    } catch (error) {
      Logger.error(CloudBackendService.TAG, `生成图像失败: ${error}`);
      throw new Error(`生成图像失败: ${error}`);
    }
  }

  /**
   * 查询图像生成状态
   */
  async getImageStatus(taskId: string): Promise<ImageStatusResponse> {
    Logger.info(CloudBackendService.TAG, `查询图像状态: ${taskId}`);

    try {
      const response = await CloudHttpClient.get<ImageStatusResponse>(
        `${this.config.baseUrl}/api/image/status/${taskId}`
      );

      return response.data;
    } catch (error) {
      Logger.error(CloudBackendService.TAG, `查询图像状态失败: ${error}`);
      throw new Error(`查询图像状态失败: ${error}`);
    }
  }

  /**
   * 轮询等待图像生成完成
   */
  async waitForImage(taskId: string, maxWaitTime: number = 60000): Promise<string> {
    Logger.info(CloudBackendService.TAG, `等待图像生成完成: ${taskId}`);

    const startTime = Date.now();
    const pollInterval = 2000; // 2秒轮询一次

    while (Date.now() - startTime < maxWaitTime) {
      const status = await this.getImageStatus(taskId);

      if (status.status === 'completed' && status.imageUrl) {
        Logger.info(CloudBackendService.TAG, '图像生成完成');
        return status.imageUrl;
      }

      if (status.status === 'failed') {
        throw new Error('图像生成失败');
      }

      // 等待后继续轮询
      await this.delay(pollInterval);
    }

    throw new Error('图像生成超时');
  }

  /**
   * 延迟工具函数
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
