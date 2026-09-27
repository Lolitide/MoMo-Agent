/*
 * ============================================================================
 * 文件名：service/backend/index.ets
 * ============================================================================
 * 【用途】后端服务模块统一导出
 * ============================================================================
 */
export { CloudBackendService } from './CloudBackendService';
export { CloudHttpClient } from './CloudHttpClient';
export { CloudConfig, DEFAULT_CLOUD_CONFIG } from './CloudConfig';
export * from './CloudBackendService'; // 导出所有请求/响应类型
