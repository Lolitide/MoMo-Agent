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
import { cloudFunction } from '@kit.CloudFoundationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ComicStylePayload } from '../ai/ComicPromptBuilder';

export class CloudFunctionService {
  private static readonly TAG = 'CloudFunctionService';
  private static instance: CloudFunctionService | null = null;

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
    if (!this.isInitialized) {
      throw new Error('云函数未初始化，请先调用initialize()');
    }
  }

  /**
   * 调用云函数
   */
  private async callFunction(functionName: string, data: Object): Promise<string> {
    this.ensureInitialized();

    try {
      Logger.info(CloudFunctionService.TAG, `调用云函数: ${functionName}`);

      const request: cloudFunction.FunctionParams = {
        name: functionName,
        data: data,
        timeout: 60000 // 60秒超时
      };

      const result = await cloudFunction.call(request);

      Logger.info(CloudFunctionService.TAG, `云函数 ${functionName} 已返回`);
      if (typeof result.result === 'string') {
        return result.result;
      }
      return JSON.stringify(result.result);
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudFunctionService.TAG, `调用失败: ${error.message}`);
      return Promise.reject(new Error(`云函数调用失败: ${error.message}`));
    }
  }

  // ==================== LLM服务 ====================

  /**
   * 生成每日总结
   */
  async generateDailySummary(request: LLMRequest): Promise<LLMResponse> {
    const params: SummaryFunctionParams = {
      userId: request.userId,
      events: request.events || [],
      mood: request.mood || '平静'
    };
    const response = await this.callFunction(CloudFunctionService.FUNCTION_LLM_SUMMARY, params);
    return this.requireLLMSuccess(JSON.parse(response) as LLMResponse);
  }

  /**
   * 生成漫画脚本
   */
  async generateComicScript(request: LLMRequest): Promise<ComicScriptResponse> {
    const params: ComicScriptFunctionParams = {
      userId: request.userId,
      summary: request.summary || '',
      events: request.events || [],
      style: request.style
    };
    const response = await this.callFunction(CloudFunctionService.FUNCTION_LLM_COMIC_SCRIPT, params);
    const result = JSON.parse(response) as ComicScriptResponse;
    if (result.success !== true || !result.panels || result.panels.length === 0) {
      throw new Error(result.error?.message || '漫画脚本生成失败');
    }
    return result;
  }

  /**
   * 处理记忆纠正
   */
  async processMemoryCorrection(request: MemoryCorrectionRequest): Promise<LLMResponse> {
    const params: CorrectionFunctionParams = {
      userId: request.userId,
      originalSummary: request.originalSummary,
      userCorrection: request.userCorrection
    };
    const response = await this.callFunction(CloudFunctionService.FUNCTION_LLM_CORRECTION, params);
    return this.requireLLMSuccess(JSON.parse(response) as LLMResponse);
  }

  /**
   * 通用对话
   */
  async chat(request: ChatRequest): Promise<LLMResponse> {
    const params: ChatFunctionParams = {
      userId: request.userId,
      message: request.message,
      context: request.context || []
    };
    const response = await this.callFunction(CloudFunctionService.FUNCTION_LLM_CHAT, params);
    return this.requireLLMSuccess(JSON.parse(response) as LLMResponse);
  }

  // ==================== 文生图服务 ====================

  /**
   * 生成图片（异步）
   */
  async generateImage(request: ImageGenerationRequest): Promise<ImageGenerationResponse> {
    const params: ImageFunctionParams = {
      userId: request.userId,
      prompt: request.prompt,
      style: request.style || 'anime',
      size: request.size || '1024x1024',
      useCharacterReference: request.useCharacterReference === true
    };
    const response = await this.callFunction(CloudFunctionService.FUNCTION_IMAGE_GENERATE, params);
    const result = JSON.parse(response) as ImageGenerationResponse;
    if (result.success !== true || result.status !== 'success' || !result.imageUrl) {
      throw new Error(result.error || '图片生成失败');
    }
    return result;
  }

  /**
   * 查询图片生成状态
   */
  async getImageStatus(taskId: string): Promise<ImageStatusResponse> {
    const params: ImageStatusFunctionParams = {
      taskId: taskId
    };
    const response = await this.callFunction(CloudFunctionService.FUNCTION_IMAGE_STATUS, params);
    const result = JSON.parse(response) as ImageStatusResponse;
    if (result.success !== true && result.status === 'failed') {
      throw new Error(result.error || '图片状态查询失败');
    }
    return result;
  }

  private requireLLMSuccess(result: LLMResponse): LLMResponse {
    if (result.success !== true || !result.content) {
      throw new Error(result.error?.message || '云函数未返回有效内容');
    }
    return result;
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
        size: '1024x1024',
        useCharacterReference: true  // 默认启用角色参考
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

interface SummaryFunctionParams {
  userId: string;
  events: string[];
  mood: string;
}

interface ComicScriptFunctionParams {
  userId: string;
  summary: string;
  events: string[];
  style?: ComicStylePayload;
}

interface CorrectionFunctionParams {
  userId: string;
  originalSummary: string;
  userCorrection: string;
}

interface ChatFunctionParams {
  userId: string;
  message: string;
  context: ChatMessage[];
}

interface ImageFunctionParams {
  userId: string;
  prompt: string;
  style: string;
  size: string;
  useCharacterReference: boolean;
}

interface ImageStatusFunctionParams {
  taskId: string;
}

/**
 * LLM请求
 */
export interface LLMRequest {
  userId: string;
  events?: string[];
  mood?: string;
  summary?: string;
  style?: ComicStylePayload;
}

/**
 * LLM响应
 */
export interface LLMResponse {
  success: boolean;
  content: string;
  usage?: TokenUsage;
  error?: FunctionErrorInfo;
}

export interface FunctionErrorInfo {
  code: string;
  message: string;
  retryable: boolean;
}

export interface TokenUsage {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
}

/**
 * 漫画脚本响应
 */
export interface ComicScriptResponse {
  success: boolean;
  panels: ComicPanel[];
  theme: string;
  error?: FunctionErrorInfo;
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
  useCharacterReference?: boolean;
}

/**
 * 图片生成响应
 */
export interface ImageGenerationResponse {
  success: boolean;
  taskId: string;
  status: 'pending' | 'generating' | 'success' | 'failed';
  imageUrl?: string;
  error?: string;
}

/**
 * 图片状态响应
 */
export interface ImageStatusResponse {
  success: boolean;
  taskId: string;
  status: 'pending' | 'generating' | 'success' | 'failed';
  progress?: number;
  imageUrl?: string;
  error?: string;
}
