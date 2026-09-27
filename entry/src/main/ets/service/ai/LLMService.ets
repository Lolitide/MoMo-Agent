/*
 * ============================================================================
 * 文件名：service/ai/LLMService.ets
 * ============================================================================
 * 【用途】LLM服务（对话、总结、纠正）
 * 【架构】优先云服务 → 降级Mock
 * ============================================================================
 */
import { CloudBackendService, DailySummaryRequest, ComicScriptRequest, MemoryCorrectionRequest } from '../backend/CloudBackendService';
import { MockProvider } from './MockProvider';
import { EventItem } from '../../model/Models';
import { Logger } from '../../utils/Logger';
import { ChatMessage, LLMRequest } from './AIModels';

export class LLMService {
  private static readonly TAG = 'LLMService';
  private static instance: LLMService | null = null;

  private cloudService: CloudBackendService;
  private mockProvider: MockProvider;

  private constructor() {
    this.cloudService = CloudBackendService.get();
    this.mockProvider = new MockProvider({ provider: 'mock', apiKey: '', baseUrl: '', model: '' });
  }

  static get(): LLMService {
    if (LLMService.instance === null) {
      LLMService.instance = new LLMService();
    }
    return LLMService.instance;
  }

  /**
   * 生成每日总结
   */
  async generateDailySummary(events: EventItem[], context?: string): Promise<string> {
    Logger.info(LLMService.TAG, `生成每日总结，事件数: ${events.length}`);

    try {
      // 检查是否为Mock模式
      if (this.cloudService.isMockMode()) {
        Logger.info(LLMService.TAG, '使用Mock模式');
        const mockRequest: LLMRequest = {
          messages: [
            { role: 'system', content: '生成每日总结' },
            { role: 'user', content: `事件: ${JSON.stringify(events)}` }
          ]
        };
        const response = await this.mockProvider.chat(mockRequest);
        return response.content;
      }

      // 调用云服务
      const request: DailySummaryRequest = {
        events: events,
        context: context
      };

      const response = await this.cloudService.generateDailySummary(request);

      // 转换为JSON字符串返回（保持与原AIService兼容）
      return JSON.stringify(response, null, 2);

    } catch (error) {
      Logger.error(LLMService.TAG, `生成每日总结失败: ${error}，降级到Mock`);

      // 降级到Mock
      const mockRequest: LLMRequest = {
        messages: [
          { role: 'system', content: '生成每日总结' },
          { role: 'user', content: `事件: ${JSON.stringify(events)}` }
        ]
      };
      const response = await this.mockProvider.chat(mockRequest);
      return response.content;
    }
  }

  /**
   * 生成漫画脚本
   */
  async generateComicScript(dailySummary: string, events: EventItem[]): Promise<string> {
    Logger.info(LLMService.TAG, '生成漫画脚本');

    try {
      // 检查是否为Mock模式
      if (this.cloudService.isMockMode()) {
        Logger.info(LLMService.TAG, '使用Mock模式');
        const mockRequest: LLMRequest = {
          messages: [
            { role: 'system', content: '生成漫画脚本' },
            { role: 'user', content: dailySummary }
          ]
        };
        const response = await this.mockProvider.chat(mockRequest);
        return response.content;
      }

      // 调用云服务
      const request: ComicScriptRequest = {
        dailySummary: dailySummary,
        events: events
      };

      const response = await this.cloudService.generateComicScript(request);
      return JSON.stringify(response, null, 2);

    } catch (error) {
      Logger.error(LLMService.TAG, `生成漫画脚本失败: ${error}，降级到Mock`);

      // 降级到Mock
      const mockRequest: LLMRequest = {
        messages: [
          { role: 'system', content: '生成漫画脚本' },
          { role: 'user', content: dailySummary }
        ]
      };
      const response = await this.mockProvider.chat(mockRequest);
      return response.content;
    }
  }

  /**
   * 处理记忆纠正
   */
  async processMemoryCorrection(memoryId: string, memoryContent: string, userFeedback: string): Promise<string> {
    Logger.info(LLMService.TAG, `处理记忆纠正: ${memoryId}`);

    try {
      // 检查是否为Mock模式
      if (this.cloudService.isMockMode()) {
        Logger.info(LLMService.TAG, '使用Mock模式');
        const mockRequest: LLMRequest = {
          messages: [
            { role: 'system', content: '处理记忆纠正' },
            { role: 'user', content: userFeedback }
          ]
        };
        const response = await this.mockProvider.chat(mockRequest);
        return response.content;
      }

      // 调用云服务
      const request: MemoryCorrectionRequest = {
        memoryId: memoryId,
        memoryContent: memoryContent,
        userFeedback: userFeedback
      };

      const response = await this.cloudService.processMemoryCorrection(request);
      return JSON.stringify(response, null, 2);

    } catch (error) {
      Logger.error(LLMService.TAG, `处理记忆纠正失败: ${error}，降级到Mock`);

      // 降级到Mock
      const mockRequest: LLMRequest = {
        messages: [
          { role: 'system', content: '处理记忆纠正' },
          { role: 'user', content: userFeedback }
        ]
      };
      const response = await this.mockProvider.chat(mockRequest);
      return response.content;
    }
  }
}
