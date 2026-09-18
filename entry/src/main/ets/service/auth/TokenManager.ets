/*
 * ============================================================================
 * 文件名：service/auth/TokenManager.ets
 * ============================================================================
 * 【用途】Token管理器，负责Token的存储、过期检查和自动刷新
 * ============================================================================
 */
import { AuthToken, RefreshTokenRequest, RefreshTokenResponse } from './AuthModels';
import { Logger } from '../../utils/Logger';
import preferences from '@ohos.data.preferences';

export class TokenManager {
  private static readonly TAG = 'TokenManager';
  private static instance: TokenManager | null = null;
  private static readonly PREFS_NAME = 'auth_tokens';
  private static readonly KEY_ACCESS_TOKEN = 'accessToken';
  private static readonly KEY_REFRESH_TOKEN = 'refreshToken';
  private static readonly KEY_EXPIRES_AT = 'expiresAt';

  private cachedToken: AuthToken | null = null;
  private expiresAt: number = 0; // 过期时间戳（毫秒）

  static get(): TokenManager {
    if (TokenManager.instance === null) {
      TokenManager.instance = new TokenManager();
    }
    return TokenManager.instance;
  }

  /**
   * 保存Token
   */
  async saveToken(token: AuthToken): Promise<void> {
    try {
      this.cachedToken = token;
      this.expiresAt = Date.now() + (token.expiresIn * 1000);

      const context = getContext(this);
      const prefs = await preferences.getPreferences(context, TokenManager.PREFS_NAME);

      await prefs.put(TokenManager.KEY_ACCESS_TOKEN, token.accessToken);
      await prefs.put(TokenManager.KEY_REFRESH_TOKEN, token.refreshToken);
      await prefs.put(TokenManager.KEY_EXPIRES_AT, this.expiresAt);
      await prefs.flush();

      Logger.info(TokenManager.TAG, `Token已保存，过期时间: ${new Date(this.expiresAt).toLocaleString()}`);
    } catch (error) {
      Logger.error(TokenManager.TAG, `保存Token失败: ${error}`);
      throw new Error(`保存Token失败: ${error}`);
    }
  }

  /**
   * 加载Token
   */
  async loadToken(): Promise<AuthToken | null> {
    try {
      const context = getContext(this);
      const prefs = await preferences.getPreferences(context, TokenManager.PREFS_NAME);

      const accessToken = await prefs.get(TokenManager.KEY_ACCESS_TOKEN, '') as string;
      const refreshToken = await prefs.get(TokenManager.KEY_REFRESH_TOKEN, '') as string;
      this.expiresAt = await prefs.get(TokenManager.KEY_EXPIRES_AT, 0) as number;

      if (!accessToken || !refreshToken) {
        Logger.warn(TokenManager.TAG, 'Token不存在');
        return null;
      }

      const expiresIn = Math.floor((this.expiresAt - Date.now()) / 1000);

      this.cachedToken = {
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: expiresIn > 0 ? expiresIn : 0,
        tokenType: 'Bearer'
      };

      Logger.info(TokenManager.TAG, `Token已加载，剩余有效期: ${expiresIn}秒`);
      return this.cachedToken;
    } catch (error) {
      Logger.error(TokenManager.TAG, `加载Token失败: ${error}`);
      return null;
    }
  }

  /**
   * 清除Token
   */
  async clearToken(): Promise<void> {
    try {
      this.cachedToken = null;
      this.expiresAt = 0;

      const context = getContext(this);
      await preferences.deletePreferences(context, TokenManager.PREFS_NAME);
      Logger.info(TokenManager.TAG, 'Token已清除');
    } catch (error) {
      Logger.error(TokenManager.TAG, `清除Token失败: ${error}`);
    }
  }

  /**
   * 获取有效的访问Token（自动刷新）
   */
  async getValidAccessToken(): Promise<string> {
    // 检查缓存
    if (!this.cachedToken) {
      this.cachedToken = await this.loadToken();
    }

    if (!this.cachedToken) {
      throw new Error('Token不存在，请先登录');
    }

    // 检查是否即将过期（提前5分钟刷新）
    const now = Date.now();
    const bufferTime = 5 * 60 * 1000; // 5分钟

    if (now + bufferTime >= this.expiresAt) {
      Logger.info(TokenManager.TAG, 'Token即将过期，开始刷新...');
      await this.refreshAccessToken();
    }

    return this.cachedToken!.accessToken;
  }

  /**
   * 刷新访问Token
   */
  async refreshAccessToken(): Promise<void> {
    if (!this.cachedToken) {
      throw new Error('没有可用的RefreshToken');
    }

    try {
      Logger.info(TokenManager.TAG, '刷新Token...');

      // TODO: 调用后端API刷新Token
      // const request: RefreshTokenRequest = {
      //   refreshToken: this.cachedToken.refreshToken
      // };
      // const response = await CloudBackendService.refreshToken(request);

      // Mock实现：重新生成Token
      const newAccessToken = this.generateMockToken('refreshed');
      const newExpiresIn = 1800; // 30分钟

      const newToken: AuthToken = {
        accessToken: newAccessToken,
        refreshToken: this.cachedToken.refreshToken,
        expiresIn: newExpiresIn,
        tokenType: 'Bearer'
      };

      await this.saveToken(newToken);
      Logger.info(TokenManager.TAG, 'Token刷新成功');
    } catch (error) {
      Logger.error(TokenManager.TAG, `刷新Token失败: ${error}`);
      throw new Error('Token刷新失败，请重新登录');
    }
  }

  /**
   * 检查Token是否过期
   */
  isTokenExpired(): boolean {
    return Date.now() >= this.expiresAt;
  }

  /**
   * 获取Token剩余有效期（秒）
   */
  getRemainingTime(): number {
    const remaining = Math.floor((this.expiresAt - Date.now()) / 1000);
    return remaining > 0 ? remaining : 0;
  }

  /**
   * 生成Mock Token
   */
  private generateMockToken(prefix: string): string {
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(2, 10);
    return `${prefix}_${timestamp}_${random}`;
  }
}
