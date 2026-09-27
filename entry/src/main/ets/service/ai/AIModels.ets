/*
 * ============================================================================
 * 文件名：service/ai/AIModels.ets
 * ============================================================================
 * 【用途】AI服务相关的数据模型定义
 * ============================================================================
 */

/**
 * LLM对话消息
 */
export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

/**
 * LLM请求参数
 */
export interface LLMRequest {
  messages: ChatMessage[];
  temperature?: number;    // 0-2，越高越随机，默认0.7
  max_tokens?: number;     // 最大生成token数，默认2000
  top_p?: number;          // 核采样，默认0.9
  stream?: boolean;        // 是否流式返回，默认false
}

/**
 * LLM响应
 */
export interface LLMResponse {
  content: string;         // 生成的文本内容
  finishReason: string;    // 结束原因：stop/length/...
  usage?: TokenUsage;
}

/**
 * Token使用情况
 */
export interface TokenUsage {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
}

/**
 * AI配置
 */
export interface AIConfig {
  provider: 'deepseek' | 'openai' | 'mock';
  apiKey: string;
  baseUrl: string;
  model: string;
  timeout?: number;
  retry?: number;
}

/**
 * 默认配置
 */
export const DEFAULT_AI_CONFIG: AIConfig = {
  provider: 'mock',
  apiKey: '',
  baseUrl: '',
  model: 'deepseek-chat',
  timeout: 30000,
  retry: 3
};
