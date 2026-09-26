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
import { UserProfile, DailyRecord, ComicImage, UserFeedback, LongTermMemory } from './CloudDBModels';
import { cloudDatabase } from '@kit.CloudFoundationKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class CloudDBService {
  private static readonly TAG = 'CloudDBService';
  private static instance: CloudDBService | null = null;

  private cloudDBZone: cloudDatabase.DatabaseZone | null = null;
  private isInitialized: boolean = false;
  // 这里只保存已经由 Cloud Foundation 认证链路确认过的用户 ID。
  // 客户端传入的 userId 只做纵深校验，真正的隔离仍由云端 Creator ACL 完成。
  private verifiedUserId: string | null = null;

  // 云数据库配置
  private static readonly ZONE_NAME = 'MomoDataZone';
  private constructor() {}

  static get(): CloudDBService {
    if (CloudDBService.instance === null) {
      CloudDBService.instance = new CloudDBService();
    }
    return CloudDBService.instance;
  }

  /**
   * 绑定已经完成 Cloud Foundation 认证的用户。
   * 设备游客 ID、mock token 和任意客户端字符串都不能调用方自行视为已验证身份。
   */
  bindVerifiedUser(userId: string): void {
    this.validateIdentifier(userId, 'userId');
    this.verifiedUserId = userId;
    Logger.info(CloudDBService.TAG, '已绑定可验证云身份');
  }

  clearVerifiedUser(): void {
    this.verifiedUserId = null;
  }

  private validateIdentifier(value: string, fieldName: string): void {
    if (!value || value.length > 200 || /[\u0000-\u001f\u007f]/.test(value)) {
      throw new Error(`${fieldName} 无效`);
    }
  }

  private validateDate(date: string): void {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      throw new Error('date 必须使用 YYYY-MM-DD 格式');
    }
  }

  private normalizeLegacyDate(date: string): string {
    if (/^\d{4}\.\d{2}\.\d{2}$/.test(date)) {
      return date.replace(/\./g, '-');
    }
    return date;
  }

  private validatePagination(limit: number, offset: number = 0): void {
    if (!Number.isInteger(limit) || limit <= 0 || limit > 200 ||
      !Number.isInteger(offset) || offset < 0) {
      throw new Error('分页参数无效');
    }
  }

  private ensureVerifiedOwner(userId: string): void {
    this.ensureInitialized();
    this.validateIdentifier(userId, 'userId');
    if (!this.verifiedUserId) {
      throw new Error('云数据库拒绝访问：尚未绑定可验证的 Cloud Foundation 用户身份');
    }
    if (this.verifiedUserId !== userId) {
      throw new Error('云数据库拒绝访问：数据 userId 与当前云身份不一致');
    }
  }

  private operationError(operation: string, err: Object): Error {
    const error = err as BusinessError;
    const code = error.code ? `${error.code}` : 'unknown';
    const message = error.message ? error.message : `${err}`;
    return new Error(`${operation}失败 (${code}): ${message}`);
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

      this.cloudDBZone = cloudDatabase.zone(CloudDBService.ZONE_NAME);

      this.isInitialized = true;
      Logger.info(CloudDBService.TAG, '云数据库初始化成功');
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `初始化失败: ${error.code} - ${error.message}`);
      const newError = new Error(`云数据库初始化失败: ${error.message}`);
      return Promise.reject(newError);
    }
  }

  /**
   * 确保已初始化
   */
  private ensureInitialized(): void {
    if (!this.isInitialized || !this.cloudDBZone) {
      throw new Error('云数据库未初始化，请先调用 initialize()');
    }
  }

  // ==================== 用户管理 ====================

  /**
   * 创建或更新用户
   */
  async upsertUser(user: UserProfile): Promise<void> {
    this.ensureVerifiedOwner(user.userId);

    try {
      user.updatedAt = Date.now();
      await this.cloudDBZone!.upsert(user);
      Logger.info(CloudDBService.TAG, '用户保存成功');
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `保存用户失败: ${error.message}`);
      throw this.operationError('保存用户', error);
    }
  }

  /**
   * 获取用户信息
   */
  async getUser(userId: string): Promise<UserProfile | null> {
    this.ensureVerifiedOwner(userId);

    try {
      const query = new cloudDatabase.DatabaseQuery(UserProfile);
      query.equalTo('userId', userId);

      const results = await this.cloudDBZone!.query(query);

      return results.length > 0 ? results[0] as UserProfile : null;
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `获取用户失败: ${error.message}`);
      throw this.operationError('获取用户', error);
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
      Logger.info(CloudDBService.TAG, '用户配额已重置');
    }

    return user;
  }

  /**
   * 消耗LLM配额
   */
  async consumeLLMQuota(userId: string, amount: number = 1): Promise<boolean> {
    if (!Number.isInteger(amount) || amount <= 0) {
      throw new Error('LLM 配额消耗量必须是正整数');
    }
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
    if (!Number.isInteger(amount) || amount <= 0) {
      throw new Error('图片配额消耗量必须是正整数');
    }
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
    this.ensureVerifiedOwner(record.userId);
    this.validateIdentifier(record.recordId, 'recordId');
    this.validateDate(record.date);
    if (record.recordId !== `${record.userId}_${record.date}`) {
      throw new Error('每日记录拒绝保存：recordId 与 userId/date 不一致');
    }

    try {
      record.updatedAt = Date.now();
      await this.cloudDBZone!.upsert(record);
      Logger.info(CloudDBService.TAG, '每日记录保存成功');
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `保存记录失败: ${error.message}`);
      throw this.operationError('保存记录', error);
    }
  }

  /**
   * 获取指定日期的记录
   */
  async getDailyRecord(userId: string, date: string): Promise<DailyRecord | null> {
    this.ensureVerifiedOwner(userId);
    this.validateDate(date);

    try {
      const recordId = `${userId}_${date}`;
      const query = new cloudDatabase.DatabaseQuery(DailyRecord);
      query.equalTo('recordId', recordId).equalTo('userId', userId);

      const results = await this.cloudDBZone!.query(query);

      return results.length > 0 ? results[0] as DailyRecord : null;
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `获取记录失败: ${error.message}`);
      throw this.operationError('获取记录', error);
    }
  }

  /**
   * 获取用户的所有记录（分页）
   */
  async getUserRecords(userId: string, limit: number = 30, offset: number = 0): Promise<DailyRecord[]> {
    this.ensureVerifiedOwner(userId);
    this.validatePagination(limit, offset);

    try {
      const query = new cloudDatabase.DatabaseQuery(DailyRecord);
      query.equalTo('userId', userId)
        .orderByDesc('date')
        .limit(limit, offset);

      return await this.cloudDBZone!.query(query);
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `获取记录列表失败: ${error.message}`);
      throw this.operationError('获取记录列表', error);
    }
  }

  // ==================== 漫画图片管理 ====================

  /**
   * 保存漫画图片记录
   */
  async upsertComicImage(image: ComicImage): Promise<void> {
    this.ensureVerifiedOwner(image.userId);
    this.validateIdentifier(image.imageId, 'imageId');
    this.validateIdentifier(image.recordId, 'recordId');
    if (!Number.isInteger(image.panelIndex) || image.panelIndex < 0) {
      throw new Error('panelIndex 无效');
    }
    if (image.imageId !== `${image.recordId}_${image.panelIndex}` ||
      !image.recordId.startsWith(`${image.userId}_`)) {
      throw new Error('漫画图片拒绝保存：主键或记录所有者不一致');
    }

    try {
      await this.cloudDBZone!.upsert(image);
      Logger.info(CloudDBService.TAG, '漫画图片保存成功');
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `保存图片失败: ${error.message}`);
      throw this.operationError('保存图片', error);
    }
  }

  /**
   * 获取记录的所有漫画图片
   */
  async getComicImages(userId: string, recordId: string): Promise<ComicImage[]> {
    this.ensureVerifiedOwner(userId);
    this.validateIdentifier(recordId, 'recordId');
    if (!recordId.startsWith(`${userId}_`)) {
      throw new Error('漫画图片拒绝查询：recordId 不属于当前用户');
    }

    try {
      const query = new cloudDatabase.DatabaseQuery(ComicImage);
      query.equalTo('recordId', recordId)
        .equalTo('userId', userId)
        .orderByAsc('panelIndex');

      return await this.cloudDBZone!.query(query);
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `获取图片列表失败: ${error.message}`);
      throw this.operationError('获取图片列表', error);
    }
  }

  // ==================== 反馈管理 ====================

  /**
   * 提交用户反馈
   */
  async submitFeedback(feedback: UserFeedback): Promise<void> {
    this.ensureVerifiedOwner(feedback.userId);
    this.validateIdentifier(feedback.feedbackId, 'feedbackId');
    if (!feedback.type || !feedback.content) {
      throw new Error('反馈类型和内容不能为空');
    }

    try {
      await this.cloudDBZone!.upsert(feedback);
      Logger.info(CloudDBService.TAG, '反馈提交成功');
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `提交反馈失败: ${error.message}`);
      throw this.operationError('提交反馈', error);
    }
  }

  // ==================== 长期记忆管理 ====================

  /**
   * 保存长期记忆
   */
  async upsertMemory(memory: LongTermMemory): Promise<void> {
    this.ensureVerifiedOwner(memory.userId);
    this.validateIdentifier(memory.memoryId, 'memoryId');
    memory.date = this.normalizeLegacyDate(memory.date);
    this.validateDate(memory.date);
    if (!memory.title || memory.dateTimestamp <= 0 || !Number.isInteger(memory.type) ||
      memory.type < 0 || memory.type > 4 || !Number.isInteger(memory.importance) ||
      memory.importance < 1 || memory.importance > 5) {
      throw new Error('记忆必填字段或取值范围无效');
    }

    try {
      memory.updatedAt = Date.now();
      await this.cloudDBZone!.upsert(memory);
      Logger.info(CloudDBService.TAG, '记忆保存成功');
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `保存记忆失败: ${error.message}`);
      throw this.operationError('保存记忆', error);
    }
  }

  /**
   * 获取指定记忆
   */
  async getMemory(userId: string, memoryId: string): Promise<LongTermMemory | null> {
    this.ensureVerifiedOwner(userId);
    this.validateIdentifier(memoryId, 'memoryId');

    try {
      const query = new cloudDatabase.DatabaseQuery(LongTermMemory);
      query.equalTo('memoryId', memoryId).equalTo('userId', userId);

      const results = await this.cloudDBZone!.query(query);

      return results.length > 0 ? results[0] as LongTermMemory : null;
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `获取记忆失败: ${error.message}`);
      throw this.operationError('获取记忆', error);
    }
  }

  /**
   * 获取用户的所有记忆（分页）
   */
  async getUserMemories(userId: string, limit: number = 100, offset: number = 0): Promise<LongTermMemory[]> {
    this.ensureVerifiedOwner(userId);
    this.validatePagination(limit, offset);

    try {
      const query = new cloudDatabase.DatabaseQuery(LongTermMemory);
      query.equalTo('userId', userId)
        .orderByDesc('dateTimestamp')
        .limit(limit, offset);

      return await this.cloudDBZone!.query(query);
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `获取记忆列表失败: ${error.message}`);
      throw this.operationError('获取记忆列表', error);
    }
  }

  /**
   * 按类型获取记忆
   */
  async getMemoriesByType(userId: string, type: number, limit: number = 50): Promise<LongTermMemory[]> {
    this.ensureVerifiedOwner(userId);
    this.validatePagination(limit);
    if (!Number.isInteger(type) || type < 0 || type > 4) {
      throw new Error('记忆类型无效');
    }

    try {
      const query = new cloudDatabase.DatabaseQuery(LongTermMemory);
      query.equalTo('userId', userId)
        .equalTo('type', type)
        .orderByDesc('dateTimestamp')
        .limit(limit);

      return await this.cloudDBZone!.query(query);
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `获取分类记忆失败: ${error.message}`);
      throw this.operationError('获取分类记忆', error);
    }
  }

  /**
   * 删除记忆
   */
  async deleteMemory(memory: LongTermMemory): Promise<void> {
    this.ensureVerifiedOwner(memory.userId);
    this.validateIdentifier(memory.memoryId, 'memoryId');

    try {
      await this.cloudDBZone!.delete(memory);
      Logger.info(CloudDBService.TAG, '记忆删除成功');
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `删除记忆失败: ${error.message}`);
      throw this.operationError('删除记忆', error);
    }
  }

  /**
   * 批量删除记忆
   */
  async deleteMemories(memories: LongTermMemory[]): Promise<void> {
    this.ensureInitialized();
    if (memories.length === 0) {
      return;
    }
    for (let i = 0; i < memories.length; i++) {
      this.ensureVerifiedOwner(memories[i].userId);
    }

    try {
      await this.cloudDBZone!.delete(memories);
      Logger.info(CloudDBService.TAG, `批量删除记忆成功，共${memories.length}条`);
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudDBService.TAG, `批量删除记忆失败: ${error.message}`);
      throw this.operationError('批量删除记忆', error);
    }
  }

  // ==================== 清理 ====================

  /**
   * 关闭云数据库
   */
  async close(): Promise<void> {
    this.cloudDBZone = null;
    this.isInitialized = false;
    this.verifiedUserId = null;
    Logger.info(CloudDBService.TAG, '云数据库已关闭');
  }
}
