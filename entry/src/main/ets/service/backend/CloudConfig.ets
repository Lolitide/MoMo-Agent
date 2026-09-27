/*
 * ============================================================================
 * 文件名：service/backend/CloudConfig.ets
 * ============================================================================
 * 【用途】云服务配置管理
 * ============================================================================
 */

export interface CloudConfig {
  baseUrl: string;              // 云服务API地址
  enableMockMode: boolean;      // 是否启用Mock模式
  timeout: number;              // 请求超时时间（毫秒）
  retry: number;                // 重试次数
}

export const DEFAULT_CLOUD_CONFIG: CloudConfig = {
  baseUrl: 'https://api.momo.example.com',
  enableMockMode: true,  // 开发阶段默认开启Mock
  timeout: 30000,
  retry: 3
};
