/*
 * ============================================================================
 * 文件名：service/cloud/CloudServiceManager.ets
 * ============================================================================
 * 【用途】华为云服务统一管理器
 * 【功能】
 *   - 统一初始化所有云服务
 *   - 统一错误处理
 *   - 服务状态管理
 * ============================================================================
 */
import { Logger } from '../../utils/Logger';
import { CloudDBService } from './CloudDBService';
import { CloudStorageService } from './CloudStorageService';
import { CloudFunctionService } from './CloudFunctionService';

export class CloudServiceManager {
  private static readonly TAG = 'CloudServiceManager';
  private static instance: CloudServiceManager | null = null;

  private cloudDB: CloudDBService;
  private cloudStorage: CloudStorageService;
  private cloudFunction: CloudFunctionService;

  private isInitialized: boolean = false;
  private initializationError: string | null = null;

  private constructor() {
    this.cloudDB = CloudDBService.get();
    this.cloudStorage = CloudStorageService.get();
    this.cloudFunction = CloudFunctionService.get();
  }

  static get(): CloudServiceManager {
    if (CloudServiceManager.instance === null) {
      CloudServiceManager.instance = new CloudServiceManager();
    }
    return CloudServiceManager.instance;
  }

  /**
   * 初始化所有云服务
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      Logger.info(CloudServiceManager.TAG, '云服务已初始化');
      return;
    }

    Logger.info(CloudServiceManager.TAG, '开始初始化华为云服务...');

    try {
      // 并行初始化所有服务
      await Promise.all([
        this.cloudDB.initialize(),
        this.cloudStorage.initialize(),
        this.cloudFunction.initialize()
      ]);

      this.isInitialized = true;
      Logger.info(CloudServiceManager.TAG, '✅ 华为云服务初始化成功');
    } catch (err) {
      this.initializationError = `${err}`;
      Logger.error(CloudServiceManager.TAG, `❌ 初始化失败: ${this.initializationError}`);
      throw new Error(`云服务初始化失败: ${this.initializationError}`);
    }
  }

  /**
   * 检查是否已初始化
   */
  isReady(): boolean {
    return this.isInitialized && this.initializationError === null;
  }

  /**
   * 获取初始化错误
   */
  getInitializationError(): string | null {
    return this.initializationError;
  }

  /**
   * 获取云数据库服务
   */
  getCloudDB(): CloudDBService {
    return this.cloudDB;
  }

  /**
   * 获取云存储服务
   */
  getCloudStorage(): CloudStorageService {
    return this.cloudStorage;
  }

  /**
   * 获取云函数服务
   */
  getCloudFunction(): CloudFunctionService {
    return this.cloudFunction;
  }

  /**
   * 关闭所有云服务
   */
  async shutdown(): Promise<void> {
    Logger.info(CloudServiceManager.TAG, '关闭云服务...');

    try {
      await this.cloudDB.close();
      this.isInitialized = false;
      Logger.info(CloudServiceManager.TAG, '云服务已关闭');
    } catch (err) {
      Logger.error(CloudServiceManager.TAG, `关闭失败: ${err}`);
    }
  }
}
