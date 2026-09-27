/*
 * ============================================================================
 * 文件名：service/auth/AccountKitAuthProvider.ets
 * ============================================================================
 * 【用途】华为Account Kit认证提供商
 * 【功能】
 *   - 华为账号一键登录
 *   - 获取用户信息（OpenID、昵称、头像）
 *   - Token自动管理
 * 【官方文档】https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/account-kit-overview-0000001774279725-V5
 * ============================================================================
 */
import { AuthProvider } from './AuthProvider';
import { User, LoginResponse, AuthToken } from './AuthModels';
import { Logger } from '../../utils/Logger';
import { authentication } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class AccountKitAuthProvider implements AuthProvider {
  private static readonly TAG = 'AccountKitAuthProvider';
  private static readonly STORAGE_KEY_USER = 'huawei_account_user';
  private currentUser: User | null = null;

  getName(): string {
    return 'HuaweiAccountKit';
  }

  /**
   * 华为账号登录
   */
  async login(): Promise<LoginResponse> {
    Logger.info(AccountKitAuthProvider.TAG, '开始华为账号登录...');

    try {
      // 1. 构造登录请求
      const request = new authentication.HuaweiIDProvider.AuthorizationRequest();
      request.scopes = [
        authentication.HuaweiIDProvider.AuthorizationScope.OPENID,
        authentication.HuaweiIDProvider.AuthorizationScope.PROFILE
      ];
      request.forceLogin = false; // 不强制登录，有缓存直接返回
      request.state = this.generateState();

      // 2. 执行登录
      const controller = new authentication.HuaweiIDProvider.AuthorizationController();
      const authCode = await controller.executeRequest(request);

      Logger.info(AccountKitAuthProvider.TAG, '华为账号登录成功，获取授权码');

      // 3. 用授权码换取用户信息
      const huaweiUser = await this.getUserInfo(authCode);

      // 4. 构造内部User对象
      const user: User = {
        userId: huaweiUser.openID,
        username: huaweiUser.displayName || `用户${huaweiUser.openID.substring(0, 6)}`,
        email: huaweiUser.email || '',
        avatar: huaweiUser.avatarUrl || '',
        createdAt: new Date().toISOString(),
        provider: 'huawei_account'
      };

      // 5. 生成Token（实际应从你的后端获取，这里暂时Mock）
      const token: AuthToken = {
        accessToken: authCode.authorizationCode, // 临时用授权码
        refreshToken: authCode.authorizationCode,
        expiresIn: 1800,
        tokenType: 'Bearer'
      };

      // 6. 保存用户信息
      this.currentUser = user;
      await this.saveUserToStorage(user);

      Logger.info(AccountKitAuthProvider.TAG, `登录成功: ${user.username}`);

      return { user, token };
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(AccountKitAuthProvider.TAG, `登录失败: ${error.code} - ${error.message}`);
      throw new Error(`华为账号登录失败: ${error.message}`);
    }
  }

  /**
   * 获取用户信息
   */
  private async getUserInfo(authCode: authentication.HuaweiIDProvider.AuthorizationResult): Promise<HuaweiUserInfo> {
    try {
      const request = new authentication.HuaweiIDProvider.GetUserInfoRequest();
      request.accessToken = authCode.authorizationCode;

      const controller = new authentication.HuaweiIDProvider.GetUserInfoController();
      const userInfo = await controller.executeRequest(request);

      return {
        openID: userInfo.openID,
        displayName: userInfo.displayName,
        email: userInfo.email,
        avatarUrl: userInfo.avatarUrl
      };
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(AccountKitAuthProvider.TAG, `获取用户信息失败: ${error.message}`);
      throw error;
    }
  }

  /**
   * 登出
   */
  async logout(): Promise<void> {
    Logger.info(AccountKitAuthProvider.TAG, '开始登出...');

    try {
      const controller = new authentication.HuaweiIDProvider.CancellationController();
      await controller.executeRequest();

      this.currentUser = null;
      await this.clearUserFromStorage();

      Logger.info(AccountKitAuthProvider.TAG, '登出成功');
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(AccountKitAuthProvider.TAG, `登出失败: ${error.message}`);
      throw error;
    }
  }

  /**
   * 获取当前用户
   */
  async getCurrentUser(): Promise<User | null> {
    if (this.currentUser) {
      return this.currentUser;
    }

    // 从存储加载
    return await this.loadUserFromStorage();
  }

  /**
   * 检查是否已登录
   */
  async isLoggedIn(): Promise<boolean> {
    const user = await this.getCurrentUser();
    return user !== null;
  }

  /**
   * 生成state参数（防止CSRF攻击）
   */
  private generateState(): string {
    return `state_${Date.now()}_${Math.random().toString(36).substring(2, 15)}`;
  }

  /**
   * 保存用户信息到本地
   */
  private async saveUserToStorage(user: User): Promise<void> {
    // TODO: 使用Preferences保存
    // 暂时存储在内存中
    this.currentUser = user;
  }

  /**
   * 从本地加载用户信息
   */
  private async loadUserFromStorage(): Promise<User | null> {
    // TODO: 从Preferences加载
    return this.currentUser;
  }

  /**
   * 清除本地用户信息
   */
  private async clearUserFromStorage(): Promise<void> {
    // TODO: 清除Preferences
    this.currentUser = null;
  }
}

/**
 * 华为用户信息接口
 */
interface HuaweiUserInfo {
  openID: string;
  displayName?: string;
  email?: string;
  avatarUrl?: string;
}
