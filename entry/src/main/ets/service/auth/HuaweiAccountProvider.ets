/*
 * ============================================================================
 * 文件名：service/auth/HuaweiAccountProvider.ets
 * ============================================================================
 * 【用途】华为账号认证提供商 - 真实实现
 * 【功能】
 *   - 使用华为 Account Kit 实现真实的账号登录
 *   - 获取华为账号的用户信息和授权码
 *   - 支持登录和授权
 * ============================================================================
 */
import { AuthProvider } from './AuthProvider';
import { User, LoginResponse } from './AuthModels';
import { Logger } from '../../utils/Logger';
import { common } from '@kit.AbilityKit';
import { authentication } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import preferences from '@ohos.data.preferences';

export class HuaweiAccountProvider extends AuthProvider {
  private static readonly TAG = 'HuaweiAccountProvider';
  private static readonly PREFS_NAME = 'auth_huawei';
  private static readonly KEY_USER_ID = 'userId';
  private static readonly KEY_NICKNAME = 'nickname';
  private static readonly KEY_AVATAR = 'avatar';
  private static readonly KEY_OPEN_ID = 'openId';

  private cachedUser: User | null = null;
  private context: common.UIAbilityContext | null = null;

  constructor(context?: common.UIAbilityContext) {
    super();
    if (context) {
      this.context = context;
    }
  }

  getName(): string {
    return '华为账号登录';
  }

  /**
   * 设置Context（必须在登录前调用）
   */
  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /**
   * 登录 - 拉起华为账号授权页面
   */
  async login(): Promise<LoginResponse> {
    Logger.info(HuaweiAccountProvider.TAG, '开始华为账号登录...');

    if (!this.context) {
      throw new Error('Context未设置，请先调用setContext()');
    }

    try {
      // 1. 创建华为账号Provider
      const provider: authentication.HuaweiIDProvider = new authentication.HuaweiIDProvider();

      // 2. 创建登录请求（先登录获取基本ID）
      const loginRequest: authentication.LoginWithHuaweiIDRequest = provider.createLoginWithHuaweiIDRequest();
      loginRequest.forceLogin = true; // 强制显示登录页面

      // 3. 创建认证控制器
      const controller: authentication.AuthenticationController =
        new authentication.AuthenticationController(this.context);

      // 4. 执行登录请求
      Logger.info(HuaweiAccountProvider.TAG, '拉起华为账号登录页面...');
      const loginResponse: authentication.LoginWithHuaweiIDResponse =
        await controller.executeRequest(loginRequest) as authentication.LoginWithHuaweiIDResponse;

      // 5. 获取登录凭证
      const loginCredential: authentication.LoginWithHuaweiIDCredential | undefined = loginResponse.data;

      if (!loginCredential) {
        throw new Error('登录失败：未获取到凭证');
      }

      Logger.info(HuaweiAccountProvider.TAG, '华为账号登录成功，获取用户详细信息...');

      // 6. 使用授权请求获取用户详细信息（昵称、头像等）
      const authRequest: authentication.AuthorizationWithHuaweiIDRequest =
        provider.createAuthorizationWithHuaweiIDRequest();

      // 设置需要的权限范围
      authRequest.scopes = ['profile']; // profile包含昵称和头像
      authRequest.forceAuthorization = false; // 已登录则不再显示授权页面

      const authResponse: authentication.AuthorizationWithHuaweiIDResponse =
        await controller.executeRequest(authRequest) as authentication.AuthorizationWithHuaweiIDResponse;

      const authCredential: authentication.AuthorizationWithHuaweiIDCredential | undefined = authResponse.data;

      // 7. 构建用户信息
      const user: User = this.parseUserInfo(loginCredential, authCredential);

      // 8. 保存用户信息到本地
      await this.saveUserInfo(user, loginCredential);

      this.cachedUser = user;

      // 9. 构建登录响应
      const loginResponseData: LoginResponse = {
        user: user,
        token: {
          accessToken: loginCredential.authorizationCode || this.generateMockToken(user.userId),
          refreshToken: this.generateMockToken(user.userId, true),
          expiresIn: 1800,
          tokenType: 'Bearer'
        }
      };

      Logger.info(HuaweiAccountProvider.TAG, `登录成功: ${user.nickname}`);
      return loginResponseData;

    } catch (error) {
      const err = error as BusinessError;
      Logger.error(HuaweiAccountProvider.TAG, `登录失败: ${err.code} - ${err.message}`);

      // 处理用户取消登录
      if (err.code === 1001500006) {
        throw new Error('用户取消登录');
      }

      throw new Error(`华为账号登录失败: ${err.message}`);
    }
  }

  /**
   * 解析用户信息
   */
  private parseUserInfo(
    loginCredential: authentication.LoginWithHuaweiIDCredential,
    authCredential?: authentication.AuthorizationWithHuaweiIDCredential
  ): User {
    const openId = loginCredential.openID || '';
    const unionId = loginCredential.unionID || '';

    // 从授权凭证中获取昵称和头像（如果有）
    const displayName = authCredential?.nickName || `华为用户${openId.substring(0, 6)}`;
    const avatarUrl = authCredential?.avatarUri || '';

    const user: User = {
      userId: unionId || openId, // 优先使用 unionId
      deviceId: openId,
      nickname: displayName,
      avatar: avatarUrl,
      createdAt: new Date().toISOString()
    };

    return user;
  }

  /**
   * 登出
   */
  async logout(): Promise<void> {
    Logger.info(HuaweiAccountProvider.TAG, '开始登出...');

    try {
      if (!this.context) {
        throw new Error('Context未设置');
      }

      // 创建Provider和Controller
      const provider: authentication.HuaweiIDProvider = new authentication.HuaweiIDProvider();
      const controller: authentication.AuthenticationController =
        new authentication.AuthenticationController(this.context);

      // 创建取消授权请求
      const cancelRequest: authentication.CancelAuthorizationRequest =
        provider.createCancelAuthorizationRequest();

      // 执行取消授权
      await controller.executeRequest(cancelRequest);

      // 清除本地缓存
      await this.clearUserInfo();
      this.cachedUser = null;

      Logger.info(HuaweiAccountProvider.TAG, '登出成功');
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(HuaweiAccountProvider.TAG, `登出失败: ${err.code} - ${err.message}`);
      // 即使登出失败，也清除本地缓存
      await this.clearUserInfo();
      this.cachedUser = null;
    }
  }

  /**
   * 获取当前用户
   */
  async getCurrentUser(): Promise<User | null> {
    if (this.cachedUser) {
      return this.cachedUser;
    }

    // 从本地存储读取
    const storedUser = await this.loadUserInfo();
    if (storedUser) {
      this.cachedUser = storedUser;
      return storedUser;
    }

    return null;
  }

  /**
   * 检查是否已登录
   */
  async isLoggedIn(): Promise<boolean> {
    try {
      const user = await this.getCurrentUser();
      return user !== null;
    } catch (error) {
      Logger.error(HuaweiAccountProvider.TAG, `检查登录状态失败: ${error}`);
      return false;
    }
  }

  /**
   * 保存用户信息到本地
   */
  private async saveUserInfo(user: User, credential: authentication.LoginWithHuaweiIDCredential): Promise<void> {
    try {
      if (!this.context) {
        throw new Error('Context未设置');
      }

      const prefs = await preferences.getPreferences(this.context, HuaweiAccountProvider.PREFS_NAME);
      await prefs.put(HuaweiAccountProvider.KEY_USER_ID, user.userId);
      await prefs.put(HuaweiAccountProvider.KEY_NICKNAME, user.nickname || '');
      await prefs.put(HuaweiAccountProvider.KEY_AVATAR, user.avatar || '');
      await prefs.put(HuaweiAccountProvider.KEY_OPEN_ID, user.deviceId || '');

      // 保存授权码（可选）
      if (credential.authorizationCode) {
        await prefs.put('authorizationCode', credential.authorizationCode);
      }

      await prefs.flush();
      Logger.info(HuaweiAccountProvider.TAG, '用户信息已保存');
    } catch (error) {
      Logger.error(HuaweiAccountProvider.TAG, `保存用户信息失败: ${error}`);
    }
  }

  /**
   * 从本地加载用户信息
   */
  private async loadUserInfo(): Promise<User | null> {
    try {
      if (!this.context) {
        return null;
      }

      const prefs = await preferences.getPreferences(this.context, HuaweiAccountProvider.PREFS_NAME);
      const userId = await prefs.get(HuaweiAccountProvider.KEY_USER_ID, '') as string;

      if (!userId) {
        return null;
      }

      const nickname = await prefs.get(HuaweiAccountProvider.KEY_NICKNAME, '') as string;
      const avatar = await prefs.get(HuaweiAccountProvider.KEY_AVATAR, '') as string;
      const openId = await prefs.get(HuaweiAccountProvider.KEY_OPEN_ID, '') as string;

      return {
        userId: userId,
        deviceId: openId,
        nickname: nickname,
        avatar: avatar,
        createdAt: new Date().toISOString()
      };
    } catch (error) {
      Logger.error(HuaweiAccountProvider.TAG, `加载用户信息失败: ${error}`);
      return null;
    }
  }

  /**
   * 清除本地用户信息
   */
  private async clearUserInfo(): Promise<void> {
    try {
      if (!this.context) {
        return;
      }

      const prefs = await preferences.getPreferences(this.context, HuaweiAccountProvider.PREFS_NAME);
      await prefs.clear();
      await prefs.flush();
      Logger.info(HuaweiAccountProvider.TAG, '用户信息已清除');
    } catch (error) {
      Logger.error(HuaweiAccountProvider.TAG, `清除用户信息失败: ${error}`);
    }
  }

  /**
   * 生成Mock Token（临时使用，实际应该使用授权码换取后端token）
   */
  private generateMockToken(userId: string, isRefresh: boolean = false): string {
    const prefix = isRefresh ? 'rt' : 'at';
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(2, 10);
    return `${prefix}_${userId.substring(0, 8)}_${timestamp}_${random}`;
  }
}
