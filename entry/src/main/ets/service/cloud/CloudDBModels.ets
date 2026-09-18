/*
 * ============================================================================
 * 文件名：service/cloud/CloudDBModels.ets
 * ============================================================================
 * 【用途】华为云数据库数据模型定义
 * 【功能】
 *   - 用户信息模型
 *   - 每日记录模型
 *   - 漫画数据模型
 * 【官方文档】https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/agc-clouddb-introduction-0000001700120869-V5
 * ============================================================================
 */

/**
 * 用户表（UserProfile）
 */
export class UserProfile {
  userId: string = '';           // 主键：用户ID（华为OpenID）
  username: string = '';         // 用户昵称
  avatar: string = '';           // 头像URL
  email: string = '';            // 邮箱
  phone: string = '';            // 手机号
  createdAt: number = 0;         // 创建时间（时间戳）
  updatedAt: number = 0;         // 更新时间

  // 配额相关
  llmQuotaDaily: number = 20;    // LLM每日配额
  llmQuotaUsed: number = 0;      // LLM已用配额
  imageQuotaDaily: number = 5;   // 文生图每日配额
  imageQuotaUsed: number = 0;    // 文生图已用配额
  lastQuotaReset: number = 0;    // 上次配额重置时间

  constructor(userId?: string) {
    if (userId) {
      this.userId = userId;
      this.createdAt = Date.now();
      this.updatedAt = Date.now();
      this.lastQuotaReset = Date.now();
    }
  }
}

/**
 * 每日记录表（DailyRecord）
 */
export class DailyRecord {
  recordId: string = '';         // 主键：记录ID
  userId: string = '';           // 外键：用户ID
  date: string = '';             // 日期（YYYY-MM-DD）
  mood: string = '';             // 心情（开心/平静/焦虑等）

  // 事件数据
  events: string = '[]';         // JSON字符串：事件列表

  // AI生成内容
  summary: string = '';          // 每日总结
  comicScript: string = '';      // 漫画脚本（JSON）
  comicImages: string = '[]';    // 漫画图片URL列表（JSON）

  createdAt: number = 0;         // 创建时间
  updatedAt: number = 0;         // 更新时间

  constructor(userId?: string, date?: string) {
    if (userId && date) {
      this.recordId = `${userId}_${date}`;
      this.userId = userId;
      this.date = date;
      this.createdAt = Date.now();
      this.updatedAt = Date.now();
    }
  }

  /**
   * 获取事件列表
   */
  getEvents(): DailyEvent[] {
    try {
      return JSON.parse(this.events) as DailyEvent[];
    } catch {
      return [];
    }
  }

  /**
   * 设置事件列表
   */
  setEvents(events: DailyEvent[]): void {
    this.events = JSON.stringify(events);
    this.updatedAt = Date.now();
  }

  /**
   * 获取漫画图片列表
   */
  getComicImages(): string[] {
    try {
      return JSON.parse(this.comicImages) as string[];
    } catch {
      return [];
    }
  }

  /**
   * 设置漫画图片列表
   */
  setComicImages(images: string[]): void {
    this.comicImages = JSON.stringify(images);
    this.updatedAt = Date.now();
  }
}

/**
 * 每日事件
 */
export interface DailyEvent {
  time: string;        // 时间（HH:mm）
  content: string;     // 事件内容
  mood?: string;       // 心情
}

/**
 * 漫画图片表（ComicImage）
 */
export class ComicImage {
  imageId: string = '';          // 主键：图片ID
  userId: string = '';           // 用户ID
  recordId: string = '';         // 关联的记录ID
  panelIndex: number = 0;        // 分镜索引（0-4）

  prompt: string = '';           // 生成提示词
  imageUrl: string = '';         // 图片URL（云存储路径）
  localPath: string = '';        // 本地缓存路径

  status: string = 'pending';    // 状态：pending/generating/success/failed
  taskId: string = '';           // 异步任务ID

  createdAt: number = 0;         // 创建时间
  completedAt: number = 0;       // 完成时间

  constructor(userId?: string, recordId?: string, panelIndex?: number) {
    if (userId && recordId !== undefined && panelIndex !== undefined) {
      this.imageId = `${recordId}_${panelIndex}`;
      this.userId = userId;
      this.recordId = recordId;
      this.panelIndex = panelIndex;
      this.createdAt = Date.now();
    }
  }
}

/**
 * 用户反馈表（UserFeedback）
 */
export class UserFeedback {
  feedbackId: string = '';       // 主键
  userId: string = '';           // 用户ID
  type: string = '';             // 类型：bug/suggestion/other
  content: string = '';          // 反馈内容
  contact: string = '';          // 联系方式
  status: string = 'pending';    // 状态：pending/processing/resolved
  createdAt: number = 0;         // 创建时间

  constructor(userId?: string) {
    if (userId) {
      this.feedbackId = `feedback_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
      this.userId = userId;
      this.createdAt = Date.now();
    }
  }
}
