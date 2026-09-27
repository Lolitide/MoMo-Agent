/*
 * ============================================================================
 * 文件名：service/ai/ImageGenService.ets
 * ============================================================================
 * 【用途】文生图服务（即梦AI）
 * 【架构】优先云服务 → 降级Mock
 * ============================================================================
 */
import { CloudBackendService, ImageGenerateRequest } from '../backend/CloudBackendService';
import { Logger } from '../../utils/Logger';

export interface ComicPanel {
  index: number;
  title: string;
  description: string;
  imageUrl?: string;
}

export class ImageGenService {
  private static readonly TAG = 'ImageGenService';
  private static instance: ImageGenService | null = null;

  private cloudService: CloudBackendService;

  private constructor() {
    this.cloudService = CloudBackendService.get();
  }

  static get(): ImageGenService {
    if (ImageGenService.instance === null) {
      ImageGenService.instance = new ImageGenService();
    }
    return ImageGenService.instance;
  }

  /**
   * 生成单张图像
   */
  async generateImage(prompt: string, style?: string): Promise<string> {
    Logger.info(ImageGenService.TAG, `生成图像: ${prompt}`);

    try {
      // 检查是否为Mock模式
      if (this.cloudService.isMockMode()) {
        Logger.info(ImageGenService.TAG, '使用Mock模式，返回占位图');
        return this.getMockImageUrl();
      }

      // 调用云服务
      const request: ImageGenerateRequest = {
        prompt: prompt,
        style: style || 'cartoon',
        size: '1024x1024'
      };

      const response = await this.cloudService.generateImage(request);

      // 如果是异步任务，等待完成
      if (response.status === 'pending' || response.status === 'processing') {
        Logger.info(ImageGenService.TAG, `任务ID: ${response.taskId}，等待生成完成...`);
        const imageUrl = await this.cloudService.waitForImage(response.taskId);
        return imageUrl;
      }

      // 同步返回
      if (response.imageUrl) {
        return response.imageUrl;
      }

      throw new Error('图像URL为空');

    } catch (error) {
      Logger.error(ImageGenService.TAG, `生成图像失败: ${error}，降级到Mock`);
      return this.getMockImageUrl();
    }
  }

  /**
   * 批量生成漫画分镜
   */
  async generateComicPanels(panels: ComicPanel[]): Promise<ComicPanel[]> {
    Logger.info(ImageGenService.TAG, `批量生成漫画分镜，数量: ${panels.length}`);

    const results: ComicPanel[] = [];

    for (let panel of panels) {
      try {
        const prompt = this.buildComicPrompt(panel);
        const imageUrl = await this.generateImage(prompt, 'cartoon');

        const result: ComicPanel = {
          index: panel.index,
          title: panel.title,
          description: panel.description,
          imageUrl: imageUrl
        };
        results.push(result);

        Logger.info(ImageGenService.TAG, `分镜 ${panel.index} 生成成功`);
      } catch (error) {
        Logger.error(ImageGenService.TAG, `分镜 ${panel.index} 生成失败: ${error}`);

        // 失败则使用占位图
        const result: ComicPanel = {
          index: panel.index,
          title: panel.title,
          description: panel.description,
          imageUrl: this.getMockImageUrl()
        };
        results.push(result);
      }
    }

    return results;
  }

  /**
   * 构建漫画专用prompt
   */
  private buildComicPrompt(panel: ComicPanel): string {
    return `${panel.description}，卡通风格，温暖色调，简洁构图，适合漫画分镜，${panel.title}`;
  }

  /**
   * 获取Mock图像URL（占位图）
   */
  private getMockImageUrl(): string {
    // 返回本地资源或占位图服务
    const mockImages = [
      'app.media.comic_1',
      'app.media.comic_2',
      'app.media.comic_3',
      'app.media.comic_4',
      'app.media.comic_5'
    ];

    const randomIndex = Math.floor(Math.random() * mockImages.length);
    return mockImages[randomIndex];
  }

  /**
   * 检查是否为Mock模式
   */
  isMockMode(): boolean {
    return this.cloudService.isMockMode();
  }
}
