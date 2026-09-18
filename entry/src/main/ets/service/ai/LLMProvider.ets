/*
 * ============================================================================
 * 文件名：service/ai/LLMProvider.ets
 * ============================================================================
 * 【用途】LLM提供商抽象接口，支持多种LLM服务商
 * ============================================================================
 */
import { ChatMessage, LLMRequest, LLMResponse, AIConfig } from './AIModels';

/**
 * LLM提供商抽象基类
 */
export abstract class LLMProvider {
  protected config: AIConfig;

  constructor(config: AIConfig) {
    this.config = config;
  }

  /**
   * 发送聊天请求
   */
  abstract chat(request: LLMRequest): Promise<LLMResponse>;

  /**
   * 测试连接
   */
  abstract testConnection(): Promise<boolean>;

  /**
   * 获取提供商名称
   */
  abstract getName(): string;
}
