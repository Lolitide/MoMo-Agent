/*
 * ============================================================================
 * 文件名：service/auth/AuthProvider.ets
 * ============================================================================
 * 【用途】认证提供商抽象接口
 * ============================================================================
 */
import { User, LoginResponse } from './AuthModels';

/**
 * 认证提供商抽象基类
 */
export abstract class AuthProvider {
  /**
   * 登录/注册
   */
  abstract login(): Promise<LoginResponse>;

  /**
   * 登出
   */
  abstract logout(): Promise<void>;

  /**
   * 获取当前用户
   */
  abstract getCurrentUser(): Promise<User | null>;

  /**
   * 检查是否已登录
   */
  abstract isLoggedIn(): Promise<boolean>;

  /**
   * 获取提供商名称
   */
  abstract getName(): string;
}
