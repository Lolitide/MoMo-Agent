/*
 * ============================================================================
 * 文件名：service/ai/DeepSeekProvider.ets
 * ============================================================================
 * 【用途】DeepSeek LLM服务提供商实现（兼容OpenAI API格式）
 * 【API文档】https://platform.deepseek.com/api-docs/
 * ============================================================================
 */
import { LLMProvider } from './LLMProvider';
import { ChatMessage, LLMRequest, LLMResponse, AIConfig } from './AIModels';
import { HttpClient } from './HttpClient';
import { Logger } from '../../utils/Logger';

interface DeepSeekApiResponse {
  id: string;
  object: string;
  created: number;
  model: string;
  choices: Array<{
    index: number;
    message: {
      role: string;
      content: string;
    };
    finish_reason: string;
  }>;
  usage: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
}

export class DeepSeekProvider extends LLMProvider {
  private static readonly TAG = 'DeepSeekProvider';

  constructor(config: AIConfig) {
    super(config);
  }

  getName(): string {
    return 'DeepSeek';
  }

  async chat(request: LLMRequest): Promise<LLMResponse> {
    const {
      messages,
      temperature = 0.7,
      max_tokens = 2000,
      top_p = 0.9,
      stream = false
    } = request;

    // 构建请求体（OpenAI格式）
    const requestBody = {
      model: this.config.model,
      messages: messages,
      temperature: temperature,
      max_tokens: max_tokens,
      top_p: top_p,
      stream: stream
    };

    Logger.info(DeepSeekProvider.TAG, `发送请求到 ${this.config.baseUrl}`);
    Logger.debug(DeepSeekProvider.TAG, `消息数量: ${messages.length}`);

    try {
      const response = await HttpClient.post<DeepSeekApiResponse>(
        `${this.config.baseUrl}/chat/completions`,
        requestBody,
        {
          'Authorization': `Bearer ${this.config.apiKey}`,
          'Content-Type': 'application/json'
        }
      );

      if (!response.data || !response.data.choices || response.data.choices.length === 0) {
        throw new Error('DeepSeek API返回数据格式错误');
      }

      const choice = response.data.choices[0];
      const usage = response.data.usage;

      Logger.info(DeepSeekProvider.TAG,
        `生成成功: ${choice.message.content.length}字符, ` +
        `Token用量: ${usage.total_tokens} (输入${usage.prompt_tokens} + 输出${usage.completion_tokens})`
      );

      return {
        content: choice.message.content,
        finishReason: choice.finish_reason,
        usage: {
          promptTokens: usage.prompt_tokens,
          completionTokens: usage.completion_tokens,
          totalTokens: usage.total_tokens
        }
      };
    } catch (error) {
      Logger.error(DeepSeekProvider.TAG, `请求失败: ${error}`);
      throw new Error(`DeepSeek API调用失败: ${error}`);
    }
  }

  async testConnection(): Promise<boolean> {
    try {
      Logger.info(DeepSeekProvider.TAG, '测试连接...');

      const testRequest: LLMRequest = {
        messages: [
          { role: 'user', content: 'Hello' }
        ],
        max_tokens: 10
      };

      await this.chat(testRequest);
      Logger.info(DeepSeekProvider.TAG, '连接测试成功');
      return true;
    } catch (error) {
      Logger.error(DeepSeekProvider.TAG, `连接测试失败: ${error}`);
      return false;
    }
  }
}
