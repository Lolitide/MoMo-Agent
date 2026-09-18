/*
 * ============================================================================
 * 文件名：service/cloud/CloudFunctionService.ets
 * ============================================================================
 * 【用途】华为云函数服务封装
 * 【功能】
 *   - 调用LLM云函数（DeepSeek）
 *   - 调用文生图云函数（即梦AI）
 *   - 异步任务管理
 * 【官方文档】https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/agc-cloudfunction-introduction-0000001700361373-V5
 * ============================================================================
 */
import { Logger } from '../../utils/Logger';
import cloudFunction from '@hms.core.cloudFunction';
import { BusinessError } from '@kit.BasicServicesKit';

export class CloudFunctionService {
  private static readonly TAG = 'CloudFunctionService';
  private static instance: CloudFunctionService | null = null;

  private functionClient?: cloudFunction.FunctionClient;
  private isInitialized: boolean = false;

  // 云函数名称
  private static readonly FUNCTION_LLM_CHAT = 'llm-chat';
  private static readonly FUNCTION_LLM_SUMMARY = 'llm-daily-summary';
  private static readonly FUNCTION_LLM_COMIC_SCRIPT = 'llm-comic-script';
  private static readonly FUNCTION_LLM_CORRECTION = 'llm-memory-correction';
  private static readonly FUNCTION_IMAGE_GENERATE = 'image-generate';
  private static readonly FUNCTION_IMAGE_STATUS = 'image-get-status';

  private constructor() {}

  static get(): CloudFunctionService {
    if (CloudFunctionService.instance === null) {
      CloudFunctionService.instance = new CloudFunctionService();
    }
    return CloudFunctionService.instance;
  }

  /**
   * 初始化云函数服务
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      Logger.info(CloudFunctionService.TAG, '云函数已初始化');
      return;
    }

    try {
      Logger.info(CloudFunctionService.TAG, '初始化云函数...');

      // 获取FunctionClient实例
      this.functionClient = cloudFunction.getFunctionClient();

      this.isInitialized = true;
      Logger.info(CloudFunctionService.TAG, '云函数初始化成功');
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudFunctionService.TAG, `初始化失败: ${error.message}`);
      throw new Error(`云函数初始化失败: ${error.message}`);
    }
  }

  /**
   * 确保已初始化
   */
  private ensureInitialized(): void {
    if (!this.isInitialized || !this.functionClient) {
      throw new Error('云函数未初始化，请先调用initialize()');
    }
  }

  /**
   * 调用云函数
   */
  private async callFunction(functionName: string, params: Record<string, Object>): Promise<CloudFunctionResponse> {
    this.ensureInitialized();

    try {
      Logger.info(CloudFunctionService.TAG, `调用云函数: ${functionName}`);

      const request: cloudFunction.FunctionRequest = {
        functionName: functionName,
        parameters: params,
        timeout: 60000 // 60秒超时
      };

      const result = await this.functionClient!.call(request);

      Logger.info(CloudFunctionService.TAG, `云函数返回: ${JSON.stringify(result).substring(0, 100)}`);

      return {
        success: result.code === 0,
        data: result.result,
        error: result.code !== 0 ? result.message : undefined
      };
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudFunctionService.TAG, `调用失败: ${error.message}`);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // ==================== LLM服务 ====================

  /**
   * 生成每日总结
   */
  async generateDailySummary(request: LLMRequest): Promise<LLMResponse> {
    const response = await this.callFunction(CloudFunctionService.FUNCTION_LLM_SUMMARY, {
      userId: request.userId,
      events: request.events,
      mood: request.mood || '平静'
    });

    if (!response.success) {
      throw new Error(response.error || '生成总结失败');
    }

    return response.data as LLMResponse;
  }

  /**
   * 生成漫画脚本
   */
  async generateComicScript(request: LLMRequest): Promise<ComicScriptResponse> {
    const response = await this.callFunction(CloudFunctionService.FUNCTION_LLM_COMIC_SCRIPT, {
      userId: request.userId,
      summary: request.summary,
      events: request.events
    });

    if (!response.success) {
      throw new Error(response.error || '生成漫画脚本失败');
    }

    return response.data as ComicScriptResponse;
  }

  /**
   * 处理记忆纠正
   */
  async processMemoryCorrection(request: MemoryCorrectionRequest): Promise<LLMResponse> {
    const response = await this.callFunction(CloudFunctionService.FUNCTION_LLM_CORRECTION, {
      userId: request.userId,
      originalSummary: request.originalSummary,
      userCorrection: request.userCorrection
    });

    if (!response.success) {
      throw new Error(response.error || '处理纠正失败');
    }

    return response.data as LLMResponse;
  }

  /**
   * 通用对话
   */
  async chat(request: ChatRequest): Promise<LLMResponse> {
    const response = await this.callFunction(CloudFunctionService.FUNCTION_LLM_CHAT, {
      userId: request.userId,
      message: request.message,
      context: request.context || []
    });

    if (!response.success) {
      throw new Error(response.error || '对话失败');
    }

    return response.data as LLMResponse;
  }

  // ==================== 文生图服务 ====================

  /**
   * 生成图片（异步）
   */
  async generateImage(request: ImageGenerationRequest): Promise<ImageGenerationResponse> {
    const response = await this.callFunction(CloudFunctionService.FUNCTION_IMAGE_GENERATE, {
      userId: request.userId,
      prompt: request.prompt,
      style: request.style || 'anime',
      size: request.size || '1024x1024'
    });

    if (!response.success) {
      throw new Error(response.error || '生成图片失败');
    }

    return response.data as ImageGenerationResponse;
  }

  /**
   * 查询图片生成状态
   */
  async getImageStatus(taskId: string): Promise<ImageStatusResponse> {
    const response = await this.callFunction(CloudFunctionService.FUNCTION_IMAGE_STATUS, {
      taskId: taskId
    });

    if (!response.success) {
      throw new Error(response.error || '查询状态失败');
    }

    return response.data as ImageStatusResponse;
  }

  /**
   * 批量生成漫画图片
   */
  async generateComicImages(userId: string, panels: ComicPanel[]): Promise<ImageGenerationResponse[]> {
    const tasks: Promise<ImageGenerationResponse>[] = [];

    for (const panel of panels) {
      const request: ImageGenerationRequest = {
        userId: userId,
        prompt: panel.prompt,
        style: 'comic',
        size: '1024x1024'
      };

      tasks.push(this.generateImage(request));
    }

    return await Promise.all(tasks);
  }

  /**
   * 轮询等待图片生成完成
   */
  async waitForImage(taskId: string, maxWaitTime: number = 60000): Promise<string> {
    const startTime = Date.now();
    const pollInterval = 2000; // 2秒轮询一次

    while (Date.now() - startTime < maxWaitTime) {
      const status = await this.getImageStatus(taskId);

      if (status.status === 'success' && status.imageUrl) {
        Logger.info(CloudFunctionService.TAG, `图片生成成功: ${status.imageUrl}`);
        return status.imageUrl;
      }

      if (status.status === 'failed') {
        throw new Error(status.error || '图片生成失败');
      }

      // 等待后继续轮询
      await this.sleep(pollInterval);
    }

    throw new Error('图片生成超时');
  }

  /**
   * 休眠函数
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

// ==================== 接口定义 ====================

/**
 * 云函数响应基类
 */
interface CloudFunctionResponse {
  success: boolean;
  data?: any;
  error?: string;
}

/**
 * LLM请求
 */
export interface LLMRequest {
  userId: string;
  events?: string[];
  mood?: string;
  summary?: string;
}

/**
 * LLM响应
 */
export interface LLMResponse {
  content: string;
  usage?: {
    promptTokens: number;
    completionTokens: number;
    totalTokens: number;
  };
}

/**
 * 漫画脚本响应
 */
export interface ComicScriptResponse {
  panels: ComicPanel[];
  theme: string;
}

/**
 * 漫画分镜
 */
export interface ComicPanel {
  index: number;
  description: string;
  prompt: string;
  dialogue?: string;
}

/**
 * 记忆纠正请求
 */
export interface MemoryCorrectionRequest {
  userId: string;
  originalSummary: string;
  userCorrection: string;
}

/**
 * 对话请求
 */
export interface ChatRequest {
  userId: string;
  message: string;
  context?: ChatMessage[];
}

/**
 * 对话消息
 */
export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

/**
 * 图片生成请求
 */
export interface ImageGenerationRequest {
  userId: string;
  prompt: string;
  style?: string;
  size?: string;
}

/**
 * 图片生成响应
 */
export interface ImageGenerationResponse {
  taskId: string;
  status: 'pending' | 'generating' | 'success' | 'failed';
  imageUrl?: string;
  error?: string;
}

/**
 * 图片状态响应
 */
export interface ImageStatusResponse {
  taskId: string;
  status: 'pending' | 'generating' | 'success' | 'failed';
  progress?: number;
  imageUrl?: string;
  error?: string;
}
