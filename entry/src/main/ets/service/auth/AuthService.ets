/*
 * ============================================================================
 * 文件名：service/auth/AuthService.ets
 * ============================================================================
 * 【用途】认证服务统一入口
 * 【功能】
 *   - 管理认证提供商（DeviceAuth / AccountKit）
 *   - 统一的登录/登出接口
 *   - Token管理和自动刷新
 * ============================================================================
 */
import { AuthProvider } from './AuthProvider';
import { DeviceAuthProvider } from './DeviceAuthProvider';
import { HuaweiAccountProvider } from './HuaweiAccountProvider';
import { User, LoginResponse } from './AuthModels';
import { TokenManager } from './TokenManager';
import { Logger } from '../../utils/Logger';
import { common } from '@kit.AbilityKit';

export class AuthService {
  private static readonly TAG = 'AuthService';
  private static instance: AuthService | null = null;

  private provider: AuthProvider;
  private tokenManager: TokenManager;
  private isInitialized: boolean = false;

  private constructor() {
    // 默认使用设备ID认证（可通过switchProvider切换为华为账号）
    this.provider = new DeviceAuthProvider();
    this.tokenManager = TokenManager.get();
  }

  /**
   * 使用华为账号初始化（推荐在应用启动时调用）
   */
  useHuaweiAccount(context: common.UIAbilityContext): void {
    const huaweiProvider = new HuaweiAccountProvider(context);
    this.switchProvider(huaweiProvider);
  }

  static get(): AuthService {
    if (AuthService.instance === null) {
      AuthService.instance = new AuthService();
    }
    return AuthService.instance;
  }

  /**
   * 初始化认证服务
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      Logger.info(AuthService.TAG, '认证服务已初始化');
      return;
    }

    Logger.info(AuthService.TAG, `初始化认证服务: ${this.provider.getName()}`);

    try {
      // 检查是否已登录
      const isLoggedIn = await this.provider.isLoggedIn();

      if (isLoggedIn) {
        // 已登录，加载用户信息和Token
        const user = await this.provider.getCurrentUser();
        const token = await this.tokenManager.loadToken();

        if (user && token) {
          Logger.info(AuthService.TAG, `用户已登录: ${user.userId}`);
        } else {
          // Token丢失，重新登录
          Logger.warn(AuthService.TAG, 'Token丢失，重新登录');
          await this.login();
        }
      } else {
        // 未登录，自动登录
        Logger.info(AuthService.TAG, '用户未登录，自动登录');
        await this.login();
      }

      this.isInitialized = true;
      Logger.info(AuthService.TAG, '认证服务初始化完成');
    } catch (err) {
      Logger.error(AuthService.TAG, `初始化失败: ${err}`);
      throw new Error(`初始化失败: ${err}`);
    }
  }

  /**
   * 登录
   */
  async login(): Promise<User> {
    Logger.info(AuthService.TAG, '开始登录...');

    try {
      const response: LoginResponse = await this.provider.login();

      // 保存Token
      await this.tokenManager.saveToken(response.token);

      Logger.info(AuthService.TAG, `登录成功: ${response.user.userId}`);
      return response.user;
    } catch (err) {
      Logger.error(AuthService.TAG, `登录失败: ${err}`);
      throw new Error(`登录失败: ${err}`);
    }
  }

  /**
   * 登出
   */
  async logout(): Promise<void> {
    Logger.info(AuthService.TAG, '开始登出...');

    try {
      await this.provider.logout();
      await this.tokenManager.clearToken();
      Logger.info(AuthService.TAG, '登出成功');
    } catch (error) {
      Logger.error(AuthService.TAG, `登出失败: ${error}`);
      throw new Error(`登出失败: ${error}`);
    }
  }

  /**
   * 获取当前用户
   */
  async getCurrentUser(): Promise<User | null> {
    return await this.provider.getCurrentUser();
  }

  /**
   * 检查是否已登录
   */
  async isLoggedIn(): Promise<boolean> {
    return await this.provider.isLoggedIn();
  }

  /**
   * 获取有效的访问Token
   */
  async getAccessToken(): Promise<string> {
    return await this.tokenManager.getValidAccessToken();
  }

  /**
   * 切换认证提供商（预留接口）
   */
  switchProvider(provider: AuthProvider): void {
    Logger.info(AuthService.TAG, `切换认证提供商: ${provider.getName()}`);
    this.provider = provider;
    this.isInitialized = false;
  }

  /**
   * 获取当前提供商名称
   */
  getProviderName(): string {
    return this.provider.getName();
  }
}
