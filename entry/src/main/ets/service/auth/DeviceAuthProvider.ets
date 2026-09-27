/*
 * ============================================================================
 * 文件名：service/auth/DeviceAuthProvider.ets
 * ============================================================================
 * 【用途】设备ID认证提供商（匿名登录）
 * 【特点】
 *   - 基于设备唯一标识自动注册
 *   - 无需用户输入任何信息
 *   - 适合快速开发和测试
 * ============================================================================
 */
import { AuthProvider } from './AuthProvider';
import { User, LoginResponse, DeviceRegisterRequest } from './AuthModels';
import { Logger } from '../../utils/Logger';
import deviceInfo from '@ohos.deviceInfo';
import preferences from '@ohos.data.preferences';

export class DeviceAuthProvider extends AuthProvider {
  private static readonly TAG = 'DeviceAuthProvider';
  private static readonly PREFS_NAME = 'auth_device';
  private static readonly KEY_USER_ID = 'userId';
  private static readonly KEY_DEVICE_ID = 'deviceId';

  private cachedUser: User | null = null;

  getName(): string {
    return '设备ID登录';
  }

  /**
   * 登录（自动注册）
   */
  async login(): Promise<LoginResponse> {
    Logger.info(DeviceAuthProvider.TAG, '开始设备ID登录...');

    try {
      // 1. 获取或生成设备ID
      const deviceId = await this.getOrCreateDeviceId();
      Logger.info(DeviceAuthProvider.TAG, `设备ID: ${deviceId.substring(0, 8)}...`);

      // 2. 检查本地是否已有用户信息
      let userId = await this.getStoredUserId();

      if (!userId) {
        // 3. 首次登录，生成新用户ID
        userId = this.generateUserId(deviceId);
        await this.saveUserId(userId, deviceId);
        Logger.info(DeviceAuthProvider.TAG, '新用户注册成功');
      } else {
        Logger.info(DeviceAuthProvider.TAG, '用户已存在，直接登录');
      }

      // 4. 构建用户信息
      const user: User = {
        userId: userId,
        deviceId: deviceId,
        nickname: `用户${userId.substring(0, 6)}`,
        createdAt: new Date().toISOString()
      };

      this.cachedUser = user;

      // 5. 构建登录响应（Mock Token，实际应该从后端获取）
      const loginResponse: LoginResponse = {
        user: user,
        token: {
          accessToken: this.generateMockToken(userId),
          refreshToken: this.generateMockToken(userId, true),
          expiresIn: 1800, // 30分钟
          tokenType: 'Bearer'
        }
      };

      Logger.info(DeviceAuthProvider.TAG, '登录成功');
      return loginResponse;

    } catch (error) {
      Logger.error(DeviceAuthProvider.TAG, `登录失败: ${error}`);
      throw new Error(`设备ID登录失败: ${error}`);
    }
  }

  /**
   * 登出
   */
  async logout(): Promise<void> {
    Logger.info(DeviceAuthProvider.TAG, '登出');
    this.cachedUser = null;
    // 注意：不删除本地存储的userId，下次启动可以继续使用
  }

  /**
   * 获取当前用户
   */
  async getCurrentUser(): Promise<User | null> {
    if (this.cachedUser) {
      return this.cachedUser;
    }

    const userId = await this.getStoredUserId();
    if (!userId) {
      return null;
    }

    const deviceId = await this.getOrCreateDeviceId();
    this.cachedUser = {
      userId: userId,
      deviceId: deviceId,
      nickname: `用户${userId.substring(0, 6)}`,
      createdAt: new Date().toISOString()
    };

    return this.cachedUser;
  }

  /**
   * 检查是否已登录
   */
  async isLoggedIn(): Promise<boolean> {
    const userId = await this.getStoredUserId();
    return userId !== null;
  }

  /**
   * 获取或创建设备ID
   */
  private async getOrCreateDeviceId(): Promise<string> {
    try {
      // 1. 尝试从Preferences读取
      const context = getContext(this);
      const prefs = await preferences.getPreferences(context, DeviceAuthProvider.PREFS_NAME);
      let deviceId = await prefs.get(DeviceAuthProvider.KEY_DEVICE_ID, '') as string;

      if (deviceId) {
        return deviceId;
      }

      // 2. 尝试使用系统设备信息
      const udid = deviceInfo.udid; // 设备唯一标识
      if (udid) {
        deviceId = udid;
      } else {
        // 3. 生成随机UUID作为设备ID
        deviceId = this.generateUUID();
      }

      // 4. 保存到Preferences
      await prefs.put(DeviceAuthProvider.KEY_DEVICE_ID, deviceId);
      await prefs.flush();

      return deviceId;
    } catch (error) {
      Logger.error(DeviceAuthProvider.TAG, `获取设备ID失败: ${error}`);
      // 降级方案：生成随机UUID
      return this.generateUUID();
    }
  }

  /**
   * 获取本地存储的用户ID
   */
  private async getStoredUserId(): Promise<string | null> {
    try {
      const context = getContext(this);
      const prefs = await preferences.getPreferences(context, DeviceAuthProvider.PREFS_NAME);
      const userId = await prefs.get(DeviceAuthProvider.KEY_USER_ID, '') as string;
      return userId || null;
    } catch (error) {
      Logger.error(DeviceAuthProvider.TAG, `读取用户ID失败: ${error}`);
      return null;
    }
  }

  /**
   * 保存用户ID
   */
  private async saveUserId(userId: string, deviceId: string): Promise<void> {
    try {
      const context = getContext(this);
      const prefs = await preferences.getPreferences(context, DeviceAuthProvider.PREFS_NAME);
      await prefs.put(DeviceAuthProvider.KEY_USER_ID, userId);
      await prefs.put(DeviceAuthProvider.KEY_DEVICE_ID, deviceId);
      await prefs.flush();
    } catch (error) {
      Logger.error(DeviceAuthProvider.TAG, `保存用户ID失败: ${error}`);
      throw new Error(`保存用户ID失败: ${error}`);
    }
  }

  /**
   * 生成用户ID（基于设备ID）
   */
  private generateUserId(deviceId: string): string {
    // 使用设备ID的hash作为用户ID
    const hash = this.simpleHash(deviceId);
    return `u_${hash}_${Date.now()}`;
  }

  /**
   * 生成Mock Token（实际应该从后端获取）
   */
  private generateMockToken(userId: string, isRefresh: boolean = false): string {
    const prefix = isRefresh ? 'rt' : 'at';
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(2, 10);
    return `${prefix}_${userId.substring(0, 8)}_${timestamp}_${random}`;
  }

  /**
   * 生成UUID
   */
  private generateUUID(): string {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
      const r = Math.random() * 16 | 0;
      const v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  /**
   * 简单hash函数
   */
  private simpleHash(str: string): string {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32bit integer
    }
    return Math.abs(hash).toString(36).substring(0, 8);
  }
}
