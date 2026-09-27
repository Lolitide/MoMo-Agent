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
import { Memory, MemoryType } from '../model/Models';
import { AuthService } from './auth/AuthService';
import { CloudServiceManager } from './cloud/CloudServiceManager';
import { LongTermMemory } from './cloud/CloudDBModels';
import preferences from '@ohos.data.preferences';

export enum DataSyncMode {
  LOCAL_ONLY = 'local_only',
  VERIFIED_CLOUD = 'verified_cloud'
}

export interface DataSyncStatus {
  mode: DataSyncMode;
  provider: string;
  reason: string;
  cloudEnabled: boolean;
}

interface StoredGuestMemory {
  id: string;
  title: string;
  dateTimestamp: number;
  type: number;
  importance: number;
  tags: string[];
  summary: string;
  content: string;
  sourceEvents: string[];
  relatedMemoryIds: string[];
}

interface GuestMemorySnapshot {
  version: number;
  userId: string;
  updatedAt: number;
  memories: StoredGuestMemory[];
}

export interface GuestMigrationResult {
  migrated: number;
  skippedExisting: number;
  failed: number;
}

export class DataSyncService {
  private static readonly TAG = 'DataSyncService';
  private static instance: DataSyncService | null = null;

  private authService: AuthService;
  private cloudManager: CloudServiceManager;
  private isInitialized: boolean = false;
  private isSyncEnabled: boolean = false;
  private mode: DataSyncMode = DataSyncMode.LOCAL_ONLY;
  private providerName: string = '';
  private statusReason: string = '尚未初始化';
  private localContext: Context | null = null;
  private localUserId: string = '';
  private verifiedCloudUserId: string = '';
  private guestListener: (() => void) | null = null;
  private guestPersistPending: boolean = false;
  private guestPersistDirty: boolean = false;

  private static readonly GUEST_PREFS = 'momo_guest_data_v1';

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
  async initialize(context?: Context): Promise<void> {
    if (this.isInitialized) {
      Logger.info(DataSyncService.TAG, '数据同步服务已初始化');
      return;
    }

    try {
      Logger.info(DataSyncService.TAG, '开始初始化数据同步服务...');

      // 1. 初始化认证服务
      await this.authService.initialize();

      // 2. 当前 DeviceAuth/HuaweiAccountProvider 都没有向 Cloud Foundation
      // 注册可验证的 AuthProvider。它们返回的客户端 userId 或 mock token 不能
      // 满足 Creator ACL，因此默认只启用应用沙箱内的本地游客存储。
      const user = await this.authService.getCurrentUser();
      if (!user) {
        this.statusReason = '没有本地用户，云同步保持关闭';
        Logger.warn(DataSyncService.TAG, this.statusReason);
        this.isInitialized = true;
        return;
      }

      if (!context) {
        throw new Error('本地游客数据初始化需要 Ability Context');
      }
      this.providerName = this.authService.getProviderName();
      await this.enableLocalGuestPersistence(context, user.userId);
      this.mode = DataSyncMode.LOCAL_ONLY;
      this.isSyncEnabled = false;
      this.statusReason = `当前 ${this.providerName} 未提供 Cloud Foundation 可验证凭据，数据仅保存在本机`;
      this.isInitialized = true;
      Logger.warn(DataSyncService.TAG, this.statusReason);
    } catch (err) {
      Logger.error(DataSyncService.TAG, `❌ 初始化失败: ${err}`);
      this.statusReason = `本地数据服务初始化失败: ${err}`;
      this.isInitialized = true; // 标记为已初始化，但同步未启用
    }
  }

  /**
   * 仅供完成 Cloud Foundation AuthProvider 配置并拿到真实云身份后调用。
   * 此方法不会自动上传游客数据；迁移必须另行取得用户同意。
   */
  async activateVerifiedCloudSync(context: Context, verifiedUserId: string): Promise<void> {
    if (!verifiedUserId) {
      throw new Error('可验证云用户 ID 不能为空');
    }
    try {
      await this.cloudManager.initialize(context);
      this.cloudManager.getCloudDB().bindVerifiedUser(verifiedUserId);
      this.cloudManager.getCloudStorage().bindVerifiedUser(verifiedUserId);

      // 保留游客快照，但停止监听；否则云端初次加载会反向覆盖待迁移的游客快照。
      this.detachGuestListener();
      await this.enableRepositorySync(verifiedUserId);
      this.verifiedCloudUserId = verifiedUserId;
      this.mode = DataSyncMode.VERIFIED_CLOUD;
      this.isSyncEnabled = true;
      this.statusReason = '已启用 Creator ACL 保护的云同步';
      Logger.info(DataSyncService.TAG, this.statusReason);
    } catch (err) {
      this.cloudManager.getCloudDB().clearVerifiedUser();
      this.cloudManager.getCloudStorage().clearVerifiedUser();
      this.verifiedCloudUserId = '';
      this.mode = DataSyncMode.LOCAL_ONLY;
      this.isSyncEnabled = false;
      this.statusReason = `云同步启用失败，继续使用本地数据: ${err}`;
      if (this.localContext && this.localUserId) {
        await this.enableLocalGuestPersistence(this.localContext, this.localUserId);
      }
      throw new Error(this.statusReason);
    }
  }

  /**
   * 在 UI 已明确取得用户迁移同意后调用。遇到同 ID 云记录时保留云端版本，
   * 不做无条件覆盖；游客快照不会自动删除，便于失败恢复。
   */
  async migrateGuestMemoriesAfterConsent(sourceGuestUserId: string,
    verifiedUserId: string): Promise<GuestMigrationResult> {
    if (this.mode !== DataSyncMode.VERIFIED_CLOUD || !this.localContext) {
      throw new Error('必须先启用可验证云身份，才能迁移游客数据');
    }
    const snapshot = await this.loadGuestSnapshot(this.localContext, sourceGuestUserId);
    const result: GuestMigrationResult = { migrated: 0, skippedExisting: 0, failed: 0 };
    if (!snapshot) {
      return result;
    }

    const cloudDB = this.cloudManager.getCloudDB();
    for (let i = 0; i < snapshot.memories.length; i++) {
      const stored = snapshot.memories[i];
      try {
        const existing = await cloudDB.getMemory(verifiedUserId, stored.id);
        if (existing) {
          result.skippedExisting++;
          continue;
        }
        const cloudMemory = this.storedMemoryToCloud(stored, verifiedUserId);
        await cloudDB.upsertMemory(cloudMemory);
        result.migrated++;
      } catch (err) {
        result.failed++;
        Logger.error(DataSyncService.TAG, `迁移游客记忆失败: ${stored.id}, ${err}`);
      }
    }
    return result;
  }

  private async enableLocalGuestPersistence(context: Context, userId: string): Promise<void> {
    this.detachGuestListener();
    this.localContext = context;
    this.localUserId = userId;

    const snapshot = await this.loadGuestSnapshot(context, userId);
    const memoryRepo = MemoryRepository.get();
    if (snapshot) {
      memoryRepo.clearAll();
      for (let i = 0; i < snapshot.memories.length; i++) {
        memoryRepo.add(this.storedMemoryToMemory(snapshot.memories[i]));
      }
      Logger.info(DataSyncService.TAG, `已恢复 ${snapshot.memories.length} 条本地游客记忆`);
    }

    this.guestListener = () => {
      this.scheduleGuestPersist();
    };
    memoryRepo.subscribe(this.guestListener);
  }

  private detachGuestListener(): void {
    if (this.guestListener) {
      MemoryRepository.get().unsubscribe(this.guestListener);
      this.guestListener = null;
    }
  }

  private scheduleGuestPersist(): void {
    this.guestPersistDirty = true;
    if (this.guestPersistPending) {
      return;
    }
    this.persistGuestLoop().catch((err: Error) => {
      Logger.error(DataSyncService.TAG, `保存本地游客数据失败: ${err.message}`);
    });
  }

  private async persistGuestLoop(): Promise<void> {
    this.guestPersistPending = true;
    try {
      while (this.guestPersistDirty) {
        this.guestPersistDirty = false;
        if (!this.localContext || !this.localUserId) {
          return;
        }
        const snapshot = this.buildGuestSnapshot(this.localUserId);
        const prefs = await preferences.getPreferences(this.localContext, DataSyncService.GUEST_PREFS);
        await prefs.put(this.guestStorageKey(this.localUserId), JSON.stringify(snapshot));
        await prefs.flush();
      }
    } finally {
      this.guestPersistPending = false;
    }
  }

  private buildGuestSnapshot(userId: string): GuestMemorySnapshot {
    const memories = MemoryRepository.get().getAll();
    const stored: StoredGuestMemory[] = [];
    for (let i = 0; i < memories.length; i++) {
      const memory = memories[i];
      stored.push({
        id: memory.id,
        title: memory.title,
        dateTimestamp: memory.dateObj.getTime(),
        type: memory.type,
        importance: memory.importance,
        tags: memory.tags,
        summary: memory.summary,
        content: memory.content,
        sourceEvents: memory.sourceEvents,
        relatedMemoryIds: memory.relatedMemoryIds
      });
    }
    return { version: 1, userId: userId, updatedAt: Date.now(), memories: stored };
  }

  private async loadGuestSnapshot(context: Context, userId: string): Promise<GuestMemorySnapshot | null> {
    const prefs = await preferences.getPreferences(context, DataSyncService.GUEST_PREFS);
    const raw = await prefs.get(this.guestStorageKey(userId), '') as string;
    if (!raw) {
      return null;
    }
    try {
      const snapshot = JSON.parse(raw) as GuestMemorySnapshot;
      if (snapshot.version !== 1 || snapshot.userId !== userId || !snapshot.memories) {
        throw new Error('游客数据版本或所有者不匹配');
      }
      return snapshot;
    } catch (err) {
      throw new Error(`本地游客数据损坏，已保留原文件且未覆盖: ${err}`);
    }
  }

  private guestStorageKey(userId: string): string {
    let hash = 2166136261;
    for (let i = 0; i < userId.length; i++) {
      hash ^= userId.charCodeAt(i);
      hash = Math.imul(hash, 16777619);
    }
    return `memories_${(hash >>> 0).toString(16)}`;
  }

  private storedMemoryToMemory(stored: StoredGuestMemory): Memory {
    const memory = new Memory(stored.id, stored.title, new Date(stored.dateTimestamp),
      stored.type as MemoryType, stored.importance);
    memory.tags = stored.tags;
    memory.summary = stored.summary;
    memory.content = stored.content;
    memory.sourceEvents = stored.sourceEvents;
    memory.relatedMemoryIds = stored.relatedMemoryIds;
    return memory;
  }

  private storedMemoryToCloud(stored: StoredGuestMemory, userId: string): LongTermMemory {
    const memory = new LongTermMemory(userId, stored.id);
    memory.title = stored.title;
    memory.dateTimestamp = stored.dateTimestamp;
    memory.date = this.storedMemoryToMemory(stored).date;
    memory.type = stored.type;
    memory.importance = stored.importance;
    memory.tags = JSON.stringify(stored.tags);
    memory.summary = stored.summary;
    memory.content = stored.content;
    memory.sourceEvents = JSON.stringify(stored.sourceEvents);
    memory.relatedMemoryIds = JSON.stringify(stored.relatedMemoryIds);
    return memory;
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
      return Promise.reject(new Error(`启用 Repository 同步失败: ${err}`));
    }
  }

  /**
   * 检查同步是否已启用
   */
  isSyncActive(): boolean {
    return this.isSyncEnabled;
  }

  getStatus(): DataSyncStatus {
    return {
      mode: this.mode,
      provider: this.providerName,
      reason: this.statusReason,
      cloudEnabled: this.isSyncEnabled
    };
  }

  /**
   * 手动触发全量同步
   */
  async syncAll(): Promise<void> {
    if (!this.isSyncEnabled) {
      Logger.warn(DataSyncService.TAG, `云端同步未启用: ${this.statusReason}`);
      return;
    }

    try {
      Logger.info(DataSyncService.TAG, '开始全量同步...');

      if (!this.verifiedCloudUserId) {
        throw new Error('缺少已验证云身份');
      }

      // 重新加载记忆数据
      const memoryRepo = MemoryRepository.get();
      await memoryRepo.enableCloudSync(this.verifiedCloudUserId);

      Logger.info(DataSyncService.TAG, '✅ 全量同步完成');
    } catch (err) {
      Logger.error(DataSyncService.TAG, `全量同步失败: ${err}`);
      return Promise.reject(new Error(`全量同步失败: ${err}`));
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
