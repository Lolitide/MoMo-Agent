/*
 * ============================================================================
 * 文件名：service/auth/AuthModels.ets
 * ============================================================================
 * 【用途】认证相关的数据模型定义
 * ============================================================================
 */

/**
 * 用户信息
 */
export interface User {
  userId: string;
  deviceId?: string;
  nickname?: string;
  avatar?: string;
  createdAt?: string;
}

/**
 * 认证Token
 */
export interface AuthToken {
  accessToken: string;      // 短期token（30分钟）
  refreshToken: string;     // 长期token（30天）
  expiresIn: number;        // 过期时间（秒）
  tokenType: string;        // Bearer
}

/**
 * 登录响应
 */
export interface LoginResponse {
  user: User;
  token: AuthToken;
}

/**
 * 设备注册请求
 */
export interface DeviceRegisterRequest {
  deviceId: string;
  deviceModel: string;
  osVersion: string;
  appVersion: string;
}

/**
 * Token刷新请求
 */
export interface RefreshTokenRequest {
  refreshToken: string;
}

/**
 * Token刷新响应
 */
export interface RefreshTokenResponse {
  accessToken: string;
  expiresIn: number;
}
