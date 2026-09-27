/*
 * ============================================================================
 * 文件名：service/cloud/CloudStorageService.ets
 * ============================================================================
 * 【用途】华为云存储服务封装
 * 【功能】
 *   - 上传漫画图片
 *   - 下载图片
 *   - 获取图片URL
 *   - 缓存管理
 * 【官方文档】https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/agc-cloudstorage-introduction-0000001700281149-V5
 * ============================================================================
 */
import { Logger } from '../../utils/Logger';
import { cloudStorage } from '@kit.CloudFoundationKit';
import { BusinessError, request } from '@kit.BasicServicesKit';
import fs from '@ohos.file.fs';

export class CloudStorageService {
  private static readonly TAG = 'CloudStorageService';
  private static instance: CloudStorageService | null = null;

  private storageBucket: cloudStorage.StorageBucket | null = null;
  private context: Context | null = null;
  private isInitialized: boolean = false;
  private verifiedUserId: string | null = null;

  // 存储桶配置
  private static readonly DEFAULT_BUCKET = 'momo-images';
  private static readonly IMAGE_FOLDER = 'comics';
  private static readonly TRANSFER_TIMEOUT_MS = 120000;
  private cacheDir: string = '';

  private constructor() {}

  static get(): CloudStorageService {
    if (CloudStorageService.instance === null) {
      CloudStorageService.instance = new CloudStorageService();
    }
    return CloudStorageService.instance;
  }

  /** 仅允许绑定已经由 Cloud Foundation 认证链路确认的用户。 */
  bindVerifiedUser(userId: string): void {
    this.validatePathSegment(userId, 'userId');
    this.verifiedUserId = userId;
  }

  clearVerifiedUser(): void {
    this.verifiedUserId = null;
  }

  /**
   * 初始化云存储
   */
  async initialize(context?: Context): Promise<void> {
    if (!context) {
      throw new Error('云存储初始化失败：缺少 Ability Context');
    }
    this.context = context;
    this.cacheDir = `${context.cacheDir}/image_cache`;
    if (this.isInitialized) {
      Logger.info(CloudStorageService.TAG, '云存储已初始化');
      return;
    }

    try {
      Logger.info(CloudStorageService.TAG, '初始化云存储...');

      this.storageBucket = cloudStorage.bucket(CloudStorageService.DEFAULT_BUCKET);

      // 创建缓存目录
      await this.ensureCacheDir();

      this.isInitialized = true;
      Logger.info(CloudStorageService.TAG, '云存储初始化成功');
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudStorageService.TAG, `初始化失败: ${error.message}`);
      throw new Error(`云存储初始化失败: ${error.message}`);
    }
  }

  /**
   * 确保缓存目录存在
   */
  private async ensureCacheDir(): Promise<void> {
    try {
      const dirExists = fs.accessSync(this.cacheDir);
      if (!dirExists) {
        fs.mkdirSync(this.cacheDir);
        Logger.info(CloudStorageService.TAG, '缓存目录创建成功');
      }
    } catch (err) {
      Logger.warn(CloudStorageService.TAG, `创建缓存目录失败: ${err}`);
    }
  }

  /**
   * 确保已初始化
   */
  private ensureInitialized(): void {
    if (!this.isInitialized || !this.storageBucket) {
      throw new Error('云存储未初始化，请先调用initialize()');
    }
    if (!this.context) {
      throw new Error('云存储缺少 Ability Context');
    }
  }

  private ensureVerifiedOwner(userId?: string): string {
    this.ensureInitialized();
    if (!this.verifiedUserId) {
      throw new Error('云存储拒绝访问：尚未绑定可验证的 Cloud Foundation 用户身份');
    }
    if (userId && userId !== this.verifiedUserId) {
      throw new Error('云存储拒绝访问：路径用户与当前云身份不一致');
    }
    return this.verifiedUserId;
  }

  private validatePathSegment(value: string, fieldName: string): void {
    if (!value || value.length > 200 || !/^[A-Za-z0-9._-]+$/.test(value) ||
      value === '.' || value === '..') {
      throw new Error(`${fieldName} 含有不安全字符`);
    }
  }

  private validateOwnedRemotePath(remotePath: string): string {
    const owner = this.ensureVerifiedOwner();
    if (!remotePath || remotePath.startsWith('/') || remotePath.includes('\\') ||
      remotePath.includes('//') || remotePath.includes('../') || remotePath.includes('/..')) {
      throw new Error('云存储路径无效');
    }
    const expectedPrefix = `${owner}/`;
    if (!remotePath.startsWith(expectedPrefix)) {
      throw new Error('云存储拒绝访问：路径不属于当前用户');
    }
    const segments = remotePath.split('/');
    for (let i = 0; i < segments.length; i++) {
      this.validatePathSegment(segments[i], '云存储路径');
    }
    return `${CloudStorageService.IMAGE_FOLDER}/${remotePath}`;
  }

  /** Cloud Storage API 的 localPath 以 context.cacheDir 为根目录。 */
  private toCacheRelativePath(localPath: string): string {
    if (!this.context) {
      throw new Error('缺少 Ability Context');
    }
    const cachePrefix = `${this.context.cacheDir}/`;
    let relativePath = localPath;
    if (localPath.startsWith(cachePrefix)) {
      relativePath = localPath.substring(cachePrefix.length);
    }
    if (!relativePath || relativePath.startsWith('/') || relativePath.includes('\\') ||
      /[\u0000-\u001f\u007f]/.test(relativePath)) {
      throw new Error('本地文件必须位于应用 cacheDir 内');
    }
    const segments = relativePath.split('/');
    for (let i = 0; i < segments.length; i++) {
      if (!segments[i] || segments[i] === '.' || segments[i] === '..') {
        throw new Error('本地文件路径无效');
      }
    }
    return relativePath;
  }

  private async runTransfer(task: request.agent.Task, operation: string): Promise<void> {
    await new Promise<void>((resolve, reject) => {
      let finished = false;
      const timeoutId = setTimeout(() => {
        if (!finished) {
          finished = true;
          reject(new Error(`${operation}任务超时`));
        }
      }, CloudStorageService.TRANSFER_TIMEOUT_MS);
      task.on('completed', (_progress: request.agent.Progress) => {
        if (!finished) {
          finished = true;
          clearTimeout(timeoutId);
          resolve();
        }
      });
      task.on('failed', (progress: request.agent.Progress) => {
        if (!finished) {
          finished = true;
          clearTimeout(timeoutId);
          reject(new Error(`${operation}任务失败，状态: ${progress.state}`));
        }
      });
      task.start().catch((err: BusinessError) => {
        if (!finished) {
          finished = true;
          clearTimeout(timeoutId);
          reject(new Error(`${operation}任务启动失败: ${err.code} - ${err.message}`));
        }
      });
    });
  }

  /**
   * 上传图片
   * @param localPath 本地文件路径
   * @param remotePath 云存储路径（相对于存储桶根目录）
   * @returns 云存储URL
   */
  async uploadImage(localPath: string, remotePath: string): Promise<string> {
    this.ensureVerifiedOwner();

    try {
      Logger.info(CloudStorageService.TAG, '开始上传图片');

      // 构造完整的云存储路径
      const fullPath = this.validateOwnedRemotePath(remotePath);

      const parameters: cloudStorage.UploadParams = {
        localPath: this.toCacheRelativePath(localPath),
        cloudPath: fullPath
      };
      const task = await this.storageBucket!.uploadFile(this.context!, parameters);
      await this.runTransfer(task, '上传');

      // 获取下载URL
      const downloadUrl = await this.storageBucket!.getDownloadURL(fullPath);

      Logger.info(CloudStorageService.TAG, '图片上传成功');
      return downloadUrl;
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudStorageService.TAG, `上传失败: ${error.message}`);
      throw new Error(`图片上传失败: ${error.message}`);
    }
  }

  /**
   * 下载图片到本地缓存
   * @param url 云存储URL
   * @param filename 本地文件名
   * @returns 本地文件路径
   */
  async downloadImage(url: string, filename: string): Promise<string> {
    this.ensureVerifiedOwner();
    this.validatePathSegment(filename, '缓存文件名');

    const localPath = `${this.cacheDir}/${filename}`;

    try {
      // 检查缓存是否存在
      if (fs.accessSync(localPath)) {
        Logger.info(CloudStorageService.TAG, '使用已缓存图片');
        return localPath;
      }

      Logger.info(CloudStorageService.TAG, '开始下载图片');

      // 从URL提取路径
      const remotePath = this.extractOwnedPathFromUrl(url);
      const parameters: cloudStorage.DownloadParams = {
        localPath: `image_cache/${filename}`,
        cloudPath: remotePath,
        overwrite: true
      };
      const task = await this.storageBucket!.downloadFile(this.context!, parameters);
      await this.runTransfer(task, '下载');

      Logger.info(CloudStorageService.TAG, '图片下载成功');
      return localPath;
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudStorageService.TAG, `下载失败: ${error.message}`);
      throw new Error(`图片下载失败: ${error.message}`);
    }
  }

  /**
   * 批量上传图片
   * @param images 图片路径数组
   * @param userId 用户ID
   * @param recordId 记录ID
   * @returns 云存储URL数组
   */
  async uploadComicImages(images: string[], userId: string, recordId: string): Promise<string[]> {
    this.ensureVerifiedOwner(userId);
    this.validatePathSegment(recordId, 'recordId');
    const urls: string[] = [];

    for (let i = 0; i < images.length; i++) {
      const localPath = images[i];
      const remotePath = `${userId}/${recordId}/panel_${i}.png`;

      try {
        const url = await this.uploadImage(localPath, remotePath);
        urls.push(url);
      } catch (err) {
        Logger.error(CloudStorageService.TAG, `上传第${i}张失败: ${err}`);
        urls.push(''); // 失败时推入空字符串
      }
    }

    return urls;
  }

  /**
   * 批量下载图片
   * @param urls URL数组
   * @param recordId 记录ID
   * @returns 本地路径数组
   */
  async downloadComicImages(urls: string[], recordId: string): Promise<string[]> {
    this.ensureVerifiedOwner();
    this.validatePathSegment(recordId, 'recordId');
    const paths: string[] = [];

    for (let i = 0; i < urls.length; i++) {
      const url = urls[i];
      if (!url) {
        paths.push('');
        continue;
      }

      const filename = `${recordId}_panel_${i}.png`;

      try {
        const localPath = await this.downloadImage(url, filename);
        paths.push(localPath);
      } catch (err) {
        Logger.error(CloudStorageService.TAG, `下载第${i}张失败: ${err}`);
        paths.push('');
      }
    }

    return paths;
  }

  /**
   * 删除云存储文件
   * @param remotePath 云存储路径
   */
  async deleteFile(remotePath: string): Promise<void> {
    this.ensureVerifiedOwner();

    try {
      const fullPath = this.validateOwnedRemotePath(remotePath);
      await this.storageBucket!.deleteFile(fullPath);
      Logger.info(CloudStorageService.TAG, '云存储文件删除成功');
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudStorageService.TAG, `删除失败: ${error.message}`);
      const newError = new Error(String(error)); return Promise.reject(newError);
    }
  }

  /**
   * 清理本地缓存
   */
  async clearCache(): Promise<void> {
    this.ensureInitialized();
    try {
      const files = fs.listFileSync(this.cacheDir);

      for (const file of files) {
        const filePath = `${this.cacheDir}/${file}`;
        fs.unlinkSync(filePath);
      }

      Logger.info(CloudStorageService.TAG, `清理缓存成功，删除${files.length}个文件`);
    } catch (err) {
      Logger.error(CloudStorageService.TAG, `清理缓存失败: ${err}`);
    }
  }

  /**
   * 获取缓存大小
   */
  async getCacheSize(): Promise<number> {
    this.ensureInitialized();
    try {
      const files = fs.listFileSync(this.cacheDir);
      let totalSize = 0;

      for (const file of files) {
        const filePath = `${this.cacheDir}/${file}`;
        const stat = fs.statSync(filePath);
        totalSize += stat.size;
      }

      return totalSize;
    } catch (err) {
      Logger.error(CloudStorageService.TAG, `获取缓存大小失败: ${err}`);
      return 0;
    }
  }

  /**
   * 从URL提取路径
   */
  private extractOwnedPathFromUrl(url: string): string {
    const marker = `/${CloudStorageService.DEFAULT_BUCKET}/`;
    const markerIndex = url.indexOf(marker);
    if (!url.startsWith('https://') || markerIndex < 0) {
      throw new Error('下载地址不是当前私有存储桶 URL');
    }
    let cloudPath = url.substring(markerIndex + marker.length);
    const queryIndex = cloudPath.indexOf('?');
    if (queryIndex >= 0) {
      cloudPath = cloudPath.substring(0, queryIndex);
    }
    const fragmentIndex = cloudPath.indexOf('#');
    if (fragmentIndex >= 0) {
      cloudPath = cloudPath.substring(0, fragmentIndex);
    }
    if (!cloudPath.startsWith(`${CloudStorageService.IMAGE_FOLDER}/`)) {
      throw new Error('下载地址不属于漫画私有目录');
    }
    const remotePath = cloudPath.substring(CloudStorageService.IMAGE_FOLDER.length + 1);
    return this.validateOwnedRemotePath(remotePath);
  }
}
