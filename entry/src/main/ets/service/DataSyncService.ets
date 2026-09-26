/*
 * ============================================================================
 * 文件名：service/DataSyncService.ets
 * ============================================================================
 * 【用途】数据同步服务 - 统一管理本地仓库与云端数据库的同步
 * 【功能】
 *   - 初始化云端同步
 *   - 为各个 Repository 启用云端持久化
 *   - 提供统一的同步状态管理
 * ============================================================================
 */
import { Logger } from '../utils/Logger';
import { MemoryRepository, EventRepository } from '../repository/Repositories';
import { AuthService } from './auth/AuthService';
import { CloudServiceManager } from './cloud/CloudServiceManager';

export class DataSyncService {
  private static readonly TAG = 'DataSyncService';
  private static instance: DataSyncService | null = null;

  private authService: AuthService;
  private cloudManager: CloudServiceManager;
  private isInitialized: boolean = false;
  private isSyncEnabled: boolean = false;

  private constructor() {
    this.authService = AuthService.get();
    this.cloudManager = CloudServiceManager.get();
  }

  static get(): DataSyncService {
    if (DataSyncService.instance === null) {
      DataSyncService.instance = new DataSyncService();
    }
    return DataSyncService.instance;
  }

  /**
   * 初始化数据同步服务
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      Logger.info(DataSyncService.TAG, '数据同步服务已初始化');
      return;
    }

    try {
      Logger.info(DataSyncService.TAG, '开始初始化数据同步服务...');

      // 1. 初始化认证服务
      await this.authService.initialize();

      // 2. 检查用户登录状态
      const user = await this.authService.getCurrentUser();
      if (!user) {
        Logger.warn(DataSyncService.TAG, '用户未登录，跳过云端同步');
        this.isInitialized = true;
        return;
      }

      // 3. 初始化云服务
      await this.cloudManager.initialize();

      // 4. 为各个 Repository 启用云端同步
      await this.enableRepositorySync(user.userId);

      this.isSyncEnabled = true;
      this.isInitialized = true;
      Logger.info(DataSyncService.TAG, '✅ 数据同步服务初始化成功');
    } catch (err) {
      Logger.error(DataSyncService.TAG, `❌ 初始化失败: ${err}`);
      this.isInitialized = true; // 标记为已初始化，但同步未启用
    }
  }

  /**
   * 为各个 Repository 启用云端同步
   */
  private async enableRepositorySync(userId: string): Promise<void> {
    try {
      // 启用 MemoryRepository 云端同步
      const memoryRepo = MemoryRepository.get();
      await memoryRepo.enableCloudSync(userId);
      Logger.info(DataSyncService.TAG, '✅ MemoryRepository 云端同步已启用');

      // 启用 EventRepository 云端同步
      const eventRepo = EventRepository.get();
      await eventRepo.enableCloudSync(userId);
      Logger.info(DataSyncService.TAG, '✅ EventRepository 云端同步已启用');
    } catch (err) {
      Logger.error(DataSyncService.TAG, `启用 Repository 同步失败: ${err}`);
      throw err;
    }
  }

  /**
   * 检查同步是否已启用
   */
  isSyncActive(): boolean {
    return this.isSyncEnabled;
  }

  /**
   * 手动触发全量同步
   */
  async syncAll(): Promise<void> {
    if (!this.isSyncEnabled) {
      Logger.warn(DataSyncService.TAG, '云端同步未启用');
      return;
    }

    try {
      Logger.info(DataSyncService.TAG, '开始全量同步...');

      const user = await this.authService.getCurrentUser();
      if (!user) {
        throw new Error('用户未登录');
      }

      // 重新加载记忆数据
      const memoryRepo = MemoryRepository.get();
      await memoryRepo.enableCloudSync(user.userId);

      Logger.info(DataSyncService.TAG, '✅ 全量同步完成');
    } catch (err) {
      Logger.error(DataSyncService.TAG, `全量同步失败: ${err}`);
      throw err;
    }
  }

  /**
   * 获取当前用户ID
   */
  async getCurrentUserId(): Promise<string | null> {
    const user = await this.authService.getCurrentUser();
    return user ? user.userId : null;
  }
}
