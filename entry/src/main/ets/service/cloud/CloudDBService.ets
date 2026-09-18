/*
 * ============================================================================
 * 文件名：service/cloud/CloudDBService.ets
 * ============================================================================
 * 【用途】华为云数据库服务封装
 * 【功能】
 *   - 用户数据CRUD
 *   - 每日记录管理
 *   - 配额管理
 *   - 数据同步
 * 【官方文档】https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/agc-clouddb-introduction-0000001700120869-V5
 * ============================================================================
 */
import { Logger } from '../../utils/Logger';
import { UserProfile, DailyRecord, ComicImage, UserFeedback } from './CloudDBModels';
import cloudDatabase from '@hms.core.cloudDatabase';
import { BusinessError } from '@kit.BasicServicesKit';

export class CloudDBService {
  private static readonly TAG = 'CloudDBService';
  private static instance: CloudDBService | null = null;

  private agConnectInstance?: cloudDatabase.AGConnectCloudDB;
  private cloudDBZone?: cloudDatabase.CloudDBZone;
  private isInitialized: boolean = false;

  // 云数据库配置
  private static readonly ZONE_NAME = 'MomoDataZone';
  private static readonly OBJECT_TYPE_INFO_MAP: Map<string, cloudDatabase.ObjectTypeInfo> = new Map();

  private constructor() {
    // 初始化对象类型映射
    CloudDBService.initObjectTypeInfoMap();
  }

  static get(): CloudDBService {
    if (CloudDBService.instance === null) {
      CloudDBService.instance = new CloudDBService();
    }
    return CloudDBService.instance;
  }

  /**
   * 初始化对象类型信息
   */
  private static initObjectTypeInfoMap(): void {
    // UserProfile
    this.OBJECT_TYPE_INFO_MAP.set('UserProfile', {
      name: 'UserProfile',
      primaryKey: 'userId'
    });

    // DailyRecord
    this.OBJECT_TYPE_INFO_MAP.set('DailyRecord', {
      name: 'DailyRecord',
      primaryKey: 'recordId'
    });

    // ComicImage
    this.OBJECT_TYPE_INFO_MAP.set('ComicImage', {
      name: 'ComicImage',
      primaryKey: 'imageId'
    });

    // UserFeedback
    this.OBJECT_TYPE_INFO_MAP.SET('UserFeedback', {
      name: 'UserFeedback',
      primaryKey: 'feedbackId'
    });
  }

  /**
   * 初始化云数据库
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      Logger.info(CloudDBService.TAG, '云数据库已初始化');
      return;
    }

    try {
      Logger.info(CloudDBService.TAG, '初始化云数据库...');

      // 1. 获取AGConnectCloudDB实例
      this.agConnectInstance = cloudDatabase.AGConnectCloudDB.getInstance();

      // 2. 创建对象类型
      await this.agConnectInstance.createObjectType(CloudDBService.OBJECT_TYPE_INFO_MAP);

      // 3. 打开云数据库Zone
      const zoneConfig: cloudDatabase.CloudDBZoneConfig = {
        zoneName: CloudDBService.ZONE_NAME,
        syncProperty: cloudDatabase.SyncProperty.CLOUDDBZONE_CLOUD_CACHE,
        capacity: 100 * 1024 * 1024 // 100MB
      };

      this.cloudDBZone = await this.agConnectInstance.openCloudDBZone(zoneConfig);

      this.isInitialized = true;
      Logger.info(CloudDBService.TAG, '云数据库初始化成功');
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `初始化失败: ${error.code} - ${error.message}`);
      throw new Error(`云数据库初始化失败: ${error.message}`);
    }
  }

  /**
   * 确保已初始化
   */
  private ensureInitialized(): void {
    if (!this.isInitialized || !this.cloudDBZone) {
      throw new Error('云数据库未初始化，请先调用initialize()');
    }
  }

  // ==================== 用户管理 ====================

  /**
   * 创建或更新用户
   */
  async upsertUser(user: UserProfile): Promise<void> {
    this.ensureInitialized();

    try {
      user.updatedAt = Date.now();
      await this.cloudDBZone!.executeUpsert(user);
      Logger.info(CloudDBService.TAG, `用户保存成功: ${user.userId}`);
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `保存用户失败: ${error.message}`);
      throw error;
    }
  }

  /**
   * 获取用户信息
   */
  async getUser(userId: string): Promise<UserProfile | null> {
    this.ensureInitialized();

    try {
      const query = cloudDatabase.CloudDBZoneQuery.where(UserProfile);
      query.equalTo('userId', userId);

      const snapshot = await this.cloudDBZone!.executeQuery(query);
      const results = snapshot.getSnapshotObjects();

      return results.length > 0 ? results[0] as UserProfile : null;
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `获取用户失败: ${error.message}`);
      return null;
    }
  }

  /**
   * 检查并重置每日配额
   */
  async checkAndResetQuota(userId: string): Promise<UserProfile | null> {
    const user = await this.getUser(userId);
    if (!user) return null;

    const now = Date.now();
    const lastReset = user.lastQuotaReset;
    const oneDay = 24 * 60 * 60 * 1000;

    // 如果距离上次重置超过24小时，重置配额
    if (now - lastReset >= oneDay) {
      user.llmQuotaUsed = 0;
      user.imageQuotaUsed = 0;
      user.lastQuotaReset = now;
      await this.upsertUser(user);
      Logger.info(CloudDBService.TAG, `用户配额已重置: ${userId}`);
    }

    return user;
  }

  /**
   * 消耗LLM配额
   */
  async consumeLLMQuota(userId: string, amount: number = 1): Promise<boolean> {
    const user = await this.checkAndResetQuota(userId);
    if (!user) return false;

    if (user.llmQuotaUsed + amount > user.llmQuotaDaily) {
      Logger.warn(CloudDBService.TAG, `LLM配额不足: ${user.llmQuotaUsed}/${user.llmQuotaDaily}`);
      return false;
    }

    user.llmQuotaUsed += amount;
    await this.upsertUser(user);
    return true;
  }

  /**
   * 消耗文生图配额
   */
  async consumeImageQuota(userId: string, amount: number = 1): Promise<boolean> {
    const user = await this.checkAndResetQuota(userId);
    if (!user) return false;

    if (user.imageQuotaUsed + amount > user.imageQuotaDaily) {
      Logger.warn(CloudDBService.TAG, `文生图配额不足: ${user.imageQuotaUsed}/${user.imageQuotaDaily}`);
      return false;
    }

    user.imageQuotaUsed += amount;
    await this.upsertUser(user);
    return true;
  }

  // ==================== 每日记录管理 ====================

  /**
   * 保存每日记录
   */
  async upsertDailyRecord(record: DailyRecord): Promise<void> {
    this.ensureInitialized();

    try {
      record.updatedAt = Date.now();
      await this.cloudDBZone!.executeUpsert(record);
      Logger.info(CloudDBService.TAG, `每日记录保存成功: ${record.recordId}`);
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `保存记录失败: ${error.message}`);
      throw error;
    }
  }

  /**
   * 获取指定日期的记录
   */
  async getDailyRecord(userId: string, date: string): Promise<DailyRecord | null> {
    this.ensureInitialized();

    try {
      const recordId = `${userId}_${date}`;
      const query = cloudDatabase.CloudDBZoneQuery.where(DailyRecord);
      query.equalTo('recordId', recordId);

      const snapshot = await this.cloudDBZone!.executeQuery(query);
      const results = snapshot.getSnapshotObjects();

      return results.length > 0 ? results[0] as DailyRecord : null;
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `获取记录失败: ${error.message}`);
      return null;
    }
  }

  /**
   * 获取用户的所有记录（分页）
   */
  async getUserRecords(userId: string, limit: number = 30, offset: number = 0): Promise<DailyRecord[]> {
    this.ensureInitialized();

    try {
      const query = cloudDatabase.CloudDBZoneQuery.where(DailyRecord);
      query.equalTo('userId', userId)
        .orderByDesc('date')
        .limit(limit, offset);

      const snapshot = await this.cloudDBZone!.executeQuery(query);
      return snapshot.getSnapshotObjects() as DailyRecord[];
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `获取记录列表失败: ${error.message}`);
      return [];
    }
  }

  // ==================== 漫画图片管理 ====================

  /**
   * 保存漫画图片记录
   */
  async upsertComicImage(image: ComicImage): Promise<void> {
    this.ensureInitialized();

    try {
      await this.cloudDBZone!.executeUpsert(image);
      Logger.info(CloudDBService.TAG, `漫画图片保存成功: ${image.imageId}`);
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `保存图片失败: ${error.message}`);
      throw error;
    }
  }

  /**
   * 获取记录的所有漫画图片
   */
  async getComicImages(recordId: string): Promise<ComicImage[]> {
    this.ensureInitialized();

    try {
      const query = cloudDatabase.CloudDBZoneQuery.where(ComicImage);
      query.equalTo('recordId', recordId)
        .orderByAsc('panelIndex');

      const snapshot = await this.cloudDBZone!.executeQuery(query);
      return snapshot.getSnapshotObjects() as ComicImage[];
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `获取图片列表失败: ${error.message}`);
      return [];
    }
  }

  // ==================== 反馈管理 ====================

  /**
   * 提交用户反馈
   */
  async submitFeedback(feedback: UserFeedback): Promise<void> {
    this.ensureInitialized();

    try {
      await this.cloudDBZone!.executeUpsert(feedback);
      Logger.info(CloudDBService.TAG, `反馈提交成功: ${feedback.feedbackId}`);
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `提交反馈失败: ${error.message}`);
      throw error;
    }
  }

  // ==================== 清理 ====================

  /**
   * 关闭云数据库
   */
  async close(): Promise<void> {
    if (this.cloudDBZone && this.agConnectInstance) {
      try {
        await this.agConnectInstance.closeCloudDBZone(this.cloudDBZone);
        this.isInitialized = false;
        Logger.info(CloudDBService.TAG, '云数据库已关闭');
      } catch (err) {
        Logger.error(CloudDBService.TAG, `关闭失败: ${err}`);
      }
    }
  }
}
