/*
 * ============================================================================
 * 文件名：service/cloud/index.ets
 * ============================================================================
 * 【用途】云服务模块统一导出
 * ============================================================================
 */

// 云服务管理器
export { CloudServiceManager } from './CloudServiceManager';

// 数据模型
export { UserProfile, DailyRecord, ComicImage, UserFeedback } from './CloudDBModels';
export type { DailyEvent } from './CloudDBModels';

// 服务类
export { CloudDBService } from './CloudDBService';
export { CloudStorageService } from './CloudStorageService';
export { CloudFunctionService } from './CloudFunctionService';

// 类型定义
export type {
  LLMRequest,
  LLMResponse,
  ComicScriptResponse,
  ComicPanel,
  MemoryCorrectionRequest,
  ChatRequest,
  ChatMessage,
  ImageGenerationRequest,
  ImageGenerationResponse,
  ImageStatusResponse
} from './CloudFunctionService';
