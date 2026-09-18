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
import cloudStorage from '@hms.core.cloudStorage';
import { BusinessError } from '@kit.BasicServicesKit';
import fs from '@ohos.file.fs';

export class CloudStorageService {
  private static readonly TAG = 'CloudStorageService';
  private static instance: CloudStorageService | null = null;

  private storageManagement?: cloudStorage.StorageManagement;
  private isInitialized: boolean = false;

  // 存储桶配置
  private static readonly DEFAULT_BUCKET = 'momo-images';
  private static readonly IMAGE_FOLDER = 'comics';
  private static readonly CACHE_DIR = '/data/storage/el2/base/haps/entry/files/image_cache';

  private constructor() {}

  static get(): CloudStorageService {
    if (CloudStorageService.instance === null) {
      CloudStorageService.instance = new CloudStorageService();
    }
    return CloudStorageService.instance;
  }

  /**
   * 初始化云存储
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      Logger.info(CloudStorageService.TAG, '云存储已初始化');
      return;
    }

    try {
      Logger.info(CloudStorageService.TAG, '初始化云存储...');

      // 获取StorageManagement实例
      this.storageManagement = cloudStorage.getStorageManagement();

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
      const dirExists = fs.accessSync(CloudStorageService.CACHE_DIR);
      if (!dirExists) {
        fs.mkdirSync(CloudStorageService.CACHE_DIR);
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
    if (!this.isInitialized || !this.storageManagement) {
      throw new Error('云存储未初始化，请先调用initialize()');
    }
  }

  /**
   * 上传图片
   * @param localPath 本地文件路径
   * @param remotePath 云存储路径（相对于存储桶根目录）
   * @returns 云存储URL
   */
  async uploadImage(localPath: string, remotePath: string): Promise<string> {
    this.ensureInitialized();

    try {
      Logger.info(CloudStorageService.TAG, `上传图片: ${localPath} -> ${remotePath}`);

      // 构造完整的云存储路径
      const fullPath = `${CloudStorageService.IMAGE_FOLDER}/${remotePath}`;

      // 获取StorageReference
      const storageRef = this.storageManagement!.getStorageReference(
        CloudStorageService.DEFAULT_BUCKET,
        fullPath
      );

      // 读取本地文件
      const file = fs.openSync(localPath, fs.OpenMode.READ_ONLY);
      const fileSize = fs.statSync(localPath).size;
      const buffer = new ArrayBuffer(fileSize);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);

      // 上传文件
      const uploadTask = storageRef.putData(buffer, {
        contentType: 'image/png'
      });

      // 监听上传进度
      uploadTask.on('state_changed', (snapshot: cloudStorage.UploadTaskSnapshot) => {
        const progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        Logger.info(CloudStorageService.TAG, `上传进度: ${progress.toFixed(2)}%`);
      });

      // 等待上传完成
      await uploadTask;

      // 获取下载URL
      const downloadUrl = await storageRef.getDownloadURL();

      Logger.info(CloudStorageService.TAG, `上传成功: ${downloadUrl}`);
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
    this.ensureInitialized();

    const localPath = `${CloudStorageService.CACHE_DIR}/${filename}`;

    try {
      // 检查缓存是否存在
      if (fs.accessSync(localPath)) {
        Logger.info(CloudStorageService.TAG, `使用缓存图片: ${localPath}`);
        return localPath;
      }

      Logger.info(CloudStorageService.TAG, `下载图片: ${url}`);

      // 从URL提取路径
      const remotePath = this.extractPathFromUrl(url);
      const storageRef = this.storageManagement!.getStorageReference(
        CloudStorageService.DEFAULT_BUCKET,
        remotePath
      );

      // 下载文件
      const downloadTask = storageRef.getFile(localPath);

      // 监听下载进度
      downloadTask.on('state_changed', (snapshot: cloudStorage.DownloadTaskSnapshot) => {
        const progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        Logger.info(CloudStorageService.TAG, `下载进度: ${progress.toFixed(2)}%`);
      });

      // 等待下载完成
      await downloadTask;

      Logger.info(CloudStorageService.TAG, `下载成功: ${localPath}`);
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
    this.ensureInitialized();

    try {
      const fullPath = `${CloudStorageService.IMAGE_FOLDER}/${remotePath}`;
      const storageRef = this.storageManagement!.getStorageReference(
        CloudStorageService.DEFAULT_BUCKET,
        fullPath
      );

      await storageRef.delete();
      Logger.info(CloudStorageService.TAG, `删除成功: ${remotePath}`);
    } catch (err) {
      const error = err as BusinessError;
      Logger.error(CloudStorageService.TAG, `删除失败: ${error.message}`);
      throw error;
    }
  }

  /**
   * 清理本地缓存
   */
  async clearCache(): Promise<void> {
    try {
      const files = fs.listFileSync(CloudStorageService.CACHE_DIR);

      for (const file of files) {
        const filePath = `${CloudStorageService.CACHE_DIR}/${file}`;
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
    try {
      const files = fs.listFileSync(CloudStorageService.CACHE_DIR);
      let totalSize = 0;

      for (const file of files) {
        const filePath = `${CloudStorageService.CACHE_DIR}/${file}`;
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
  private extractPathFromUrl(url: string): string {
    // 简化实现：从URL中提取路径部分
    // 实际URL格式：https://cloudStorage-xxx.xxx.com/bucket/path/to/file
    const parts = url.split('/');
    const bucketIndex = parts.indexOf(CloudStorageService.DEFAULT_BUCKET);

    if (bucketIndex !== -1 && bucketIndex < parts.length - 1) {
      return parts.slice(bucketIndex + 1).join('/');
    }

    return url;
  }
}
