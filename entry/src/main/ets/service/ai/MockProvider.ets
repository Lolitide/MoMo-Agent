/*
 * ============================================================================
 * 文件名：service/ai/MockProvider.ets
 * ============================================================================
 * 【用途】Mock LLM提供商，用于离线演示和测试
 * 【功能】
 *   - 根据用户输入关键词返回预设响应
 *   - 支持每日总结、漫画分镜、记忆纠正等场景
 *   - 模拟真实API的响应延迟
 * ============================================================================
 */
import { LLMProvider } from './LLMProvider';
import { ChatMessage, LLMRequest, LLMResponse, AIConfig } from './AIModels';
import { Logger } from '../../utils/Logger';
import {
  DailySummary,
  ComicScript,
  CorrectionResponse,
  MemoryResponse
} from './MockProviderModels';

export class MockProvider extends LLMProvider {
  private static readonly TAG = 'MockProvider';
  private static readonly MOCK_DELAY = 800; // 模拟延迟（毫秒）

  constructor(config: AIConfig) {
    super(config);
  }

  getName(): string {
    return 'Mock (离线模式)';
  }

  async chat(request: LLMRequest): Promise<LLMResponse> {
    Logger.info(MockProvider.TAG, `Mock响应请求，消息数: ${request.messages.length}`);

    // 模拟网络延迟
    await this.delay(MockProvider.MOCK_DELAY);

    const lastMessage = request.messages[request.messages.length - 1];
    const userInput = lastMessage.content.toLowerCase();

    // 根据关键词匹配预设响应
    let mockContent = '';

    if (this.contains(userInput, ['总结', '今天', '每日', 'summary', 'daily'])) {
      mockContent = this.getMockDailySummary();
    } else if (this.contains(userInput, ['漫画', '分镜', 'comic', 'storyboard'])) {
      mockContent = this.getMockComicScript();
    } else if (this.contains(userInput, ['纠正', '修改', '更新', 'correct', 'update'])) {
      mockContent = this.getMockCorrectionResponse();
    } else if (this.contains(userInput, ['记忆', '档案', 'memory', 'archive'])) {
      mockContent = this.getMockMemoryResponse();
    } else {
      // 默认响应
      mockContent = '我是默默的Mock模式。当前处于离线演示状态，真实AI能力需要配置API Key后启用。';
    }

    Logger.info(MockProvider.TAG, `返回Mock响应: ${mockContent.length}字符`);

    return {
      content: mockContent,
      finishReason: 'stop',
      usage: {
        promptTokens: 100,
        completionTokens: 200,
        totalTokens: 300
      }
    };
  }

  async testConnection(): Promise<boolean> {
    Logger.info(MockProvider.TAG, 'Mock模式无需测试连接');
    return true;
  }

  /**
   * 检查输入是否包含关键词
   */
  private contains(input: string, keywords: string[]): boolean {
    return keywords.some(keyword => input.includes(keyword));
  }

  /**
   * Mock每日总结
   */
  private getMockDailySummary(): string {
    const summary: DailySummary = {
      summary: '今天是充实的一天。上午专注完成了设计方案，下午与团队评审交流，晚上看了会儿漫画放松心情。',
      emotion: '平静而满足',
      theme: '工作与休息的平衡',
      insights: [
        {
          title: '工作节奏',
          content: '上午的专注时间效率很高，适合做需要深度思考的工作'
        },
        {
          title: '社交互动',
          content: '与设计同学的评审讨论很有收获，团队协作让想法更完善'
        },
        {
          title: '兴趣爱好',
          content: '晚上的漫画时间是很好的放松方式，帮助切换状态'
        }
      ]
    };
    return JSON.stringify(summary, null, 2);
  }

  /**
   * Mock漫画分镜脚本
   */
  private getMockComicScript(): string {
    const script: ComicScript = {
      title: '默默的一天',
      scenes: [
        {
          index: 1,
          title: '清晨',
          description: '阳光透过窗帘，默默坐在窗台上，看着用户起床开始新的一天',
          emotion: 'peaceful'
        },
        {
          index: 2,
          title: '专注时刻',
          description: '用户在电脑前工作，默默安静地待在旁边，偶尔歪头看看屏幕',
          emotion: 'curious'
        },
        {
          index: 3,
          title: '午后讨论',
          description: '视频会议中，默默在一旁听着，做出思考的表情',
          emotion: 'thinking'
        },
        {
          index: 4,
          title: '放松时光',
          description: '晚上，用户翻看漫画书，默默也凑过来一起看',
          emotion: 'happy'
        },
        {
          index: 5,
          title: '晚安',
          description: '夜深了，默默蜷缩在桌角，陪着用户记录今天的小确幸',
          emotion: 'sleepy'
        }
      ]
    };
    return JSON.stringify(script, null, 2);
  }

  /**
   * Mock纠正响应
   */
  private getMockCorrectionResponse(): string {
    const correction: CorrectionResponse = {
      action: 'update_memory',
      memoryId: 'm2',
      updates: {
        title: '完成HDS设计规范初稿',
        importance: 5,
        tags: ['设计', '文档', '成长', '里程碑']
      },
      reasoning: '根据你的反馈，这个记忆的重要程度应该提升，并增加"里程碑"标签，因为这是一个阶段性的重要成果。'
    };
    return JSON.stringify(correction, null, 2);
  }

  /**
   * Mock记忆响应
   */
  private getMockMemoryResponse(): string {
    const memory: MemoryResponse = {
      memoryType: 'STUDY',
      importance: 4,
      tags: ['设计', '成长', '文档'],
      summary: '完成了一个重要的设计规范文档，这对个人成长和团队都很有价值。',
      relatedMemories: ['m1', 'm3']
    };
    return JSON.stringify(memory, null, 2);
  }

  /**
   * 延迟工具函数
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
