/*
 * ============================================================================
 * 文件名：service/DemoModeService.ets
 * ============================================================================
 * 【用途】演示模式的唯一开关与事务协调者。
 *   开启时把 Memory / Event / Comic 三个仓库切到「演示内存区」，并暂停游客数据落盘；
 *   关闭时按逆序逐层还原，演示期间产生的任何数据一律丢弃。
 *   另提供「演示记忆条数」设置（设置页滑杆）：只改内存里的演示种子数量，
 *   用于现场放大/缩小记忆花园，观察记忆很多时的形态。
 *
 * 【设计原则（三条硬约束）】
 *   1. 零持久化：本文件绝不读写 Preferences、绝不落盘。演示数据只活在内存里，
 *      因此 App 冷启动时演示模式必然处于关闭状态——这就是「不长期保存」的实现方式。
 *   2. 零联网：本文件绝不调用云函数／云数据库。演示模式的开启与关闭是纯本地操作，
 *      现场断网也能用。
 *   3. 全量回滚：enable() 任何一步失败，已切换的仓库按逆序还原，开关保持关闭，
 *      绝不留下「一半演示态、一半真实态」的中间状态。
 *
 * 【前置条件 / 假设】
 *   - 依赖：Repositories（Memory/Event/Comic）、DataSyncService；
 *   - 假设：单例、单线程 UI 语义（与 CompanionService 的订阅模式一致）；
 *   - 假设：页面通过 subscribe() 获取变更通知；进入/退出只广播一次。
 *
 * 【输入 / 输出（后置条件）】
 *   - 输入：enable() / disable() / isDemo() / subscribe() / unsubscribe()；
 *   - 输出：演示态切换 + 一次 notify 广播；
 *   - 后置：disable() 后三个仓库恢复为 enable() 之前的数据引用与云端开关状态。
 *
 * 【关键类 / 算法】
 *   - 事务式切换 + 逆序回滚（见 enable/disable 的 try/catch）；
 *   - 单一广播点：先切换完所有仓库，再置 active 并 notify，避免 UI 读到半状态。
 *
 * 【参考源】
 *   - service/Services.ets 的 CompanionService（单例 + 订阅 + notify 惯例）
 *   - MVP与复赛材料清单.md §4.2 第 7 项「演示模式」
 * ============================================================================
 */
import { Logger } from '../utils/Logger';
import { StateListener } from './Services';
import { MemoryRepository, EventRepository, ComicRepository } from '../repository/Repositories';
import { DataSyncService } from './DataSyncService';
import { DemoMockData } from '../mock/DemoMockData';

export class DemoModeService {
  private static readonly TAG = 'DemoModeService';
  private static instance: DemoModeService | null = null;

  private active: boolean = false;
  private listeners: StateListener[] = [];

  static get(): DemoModeService {
    if (DemoModeService.instance === null) {
      DemoModeService.instance = new DemoModeService();
    }
    return DemoModeService.instance;
  }

  isDemo(): boolean {
    return this.active;
  }

  subscribe(cb: StateListener): void {
    this.listeners.push(cb);
  }

  unsubscribe(cb: StateListener): void {
    const next: StateListener[] = [];
    for (let i = 0; i < this.listeners.length; i++) {
      if (this.listeners[i] !== cb) {
        next.push(this.listeners[i]);
      }
    }
    this.listeners = next;
  }

  /**
   * 进入演示模式。幂等：已处于演示态时直接返回。
   * 失败时逆序回滚并抛出，调用方（设置页）据此把开关恢复为关闭。
   */
  async enable(): Promise<void> {
    if (this.active) {
      return;
    }

    const memoryRepo = MemoryRepository.get();
    const eventRepo = EventRepository.get();
    const comicRepo = ComicRepository.get();

    try {
      // 1. 记忆：先快照真实数组，再灌入 14 条演示种子
      memoryRepo.activateDemo();
      // 2. 今日状态：切到演示 L1（7 事件 / 9 洞察）
      eventRepo.activateDemo();
      // 3. 今日漫画：把预制漫画同时填入 generatedComic / generatedScript，
      //    这样首页卡片、今日漫画页、漫画查看器三条路径都能拿到占位图
      comicRepo.activateDemo();
      // 4. 兜底：暂停游客数据落盘（第二道保险，第一道在 MemoryRepository 内部）
      DataSyncService.get().suspendGuestPersistence();

      this.active = true;
      this.notify();
      Logger.info(DemoModeService.TAG, '演示模式已开启（内存隔离，不落盘、不联网）');
    } catch (err) {
      // 逆序回滚：后切换的先还原，保证回到 enable() 之前的状态
      try {
        DataSyncService.get().resumeGuestPersistence();
        comicRepo.deactivateDemo();
        eventRepo.deactivateDemo();
        memoryRepo.deactivateDemo();
      } catch (rollbackErr) {
        Logger.error(DemoModeService.TAG, `演示模式回滚失败: ${rollbackErr}`);
      }
      this.active = false;
      Logger.error(DemoModeService.TAG, `演示模式开启失败: ${err}`);
      throw new Error(`演示模式开启失败: ${err}`);
    }
  }

  /**
   * 退出演示模式。幂等。
   * 先还原全部仓库，再统一置 active=false 并广播一次，避免页面读到半状态。
   */
  async disable(): Promise<void> {
    if (!this.active) {
      return;
    }

    const memoryRepo = MemoryRepository.get();
    const eventRepo = EventRepository.get();
    const comicRepo = ComicRepository.get();

    try {
      DataSyncService.get().resumeGuestPersistence();
      comicRepo.deactivateDemo();
      eventRepo.deactivateDemo();
      memoryRepo.deactivateDemo();
    } catch (err) {
      // 退出路径尽力而为：即使某个仓库还原异常，也要把 active 复位，
      // 否则开关会永久卡在演示态而无法关闭。
      Logger.error(DemoModeService.TAG, `退出演示模式时还原数据失败: ${err}`);
    }

    this.active = false;
    this.notify();
    Logger.info(DemoModeService.TAG, '已退出演示模式，演示数据已全部丢弃');
  }

  /** 演示数据条数（设置页展示用，避免页面直接依赖 mock 层） */
  demoMemoryCount(): number {
    return MemoryRepository.get().isDemo() ? MemoryRepository.get().getAll().length : 0;
  }

  // ==================== 演示条数设置 ====================

  /** 条数下限（透传 mock 层约束，设置页滑杆直接用） */
  static minDemoMemoryCount(): number {
    return DemoMockData.MIN_COUNT;
  }

  /** 条数上限 */
  static maxDemoMemoryCount(): number {
    return DemoMockData.MAX_COUNT;
  }

  /** 当前设置的演示条数（非演示态也保留，便于下次开启直接生效） */
  demoMemoryTarget(): number {
    return DemoMockData.getTargetCount();
  }

  /**
   * 设置演示记忆条数：夹到 [MIN_COUNT, MAX_COUNT] 后写回 mock 层，
   * 若当前正处于演示态，立刻重建演示记忆并广播一次，花园随即按新条数重排。
   *
   * 【为什么不落盘】条数本身也属于演示设置：冷启动回到默认值，
   * 与「演示数据不长期保存」的约定一致（本文件依旧零 Preferences 读写）。
   */
  setDemoMemoryCount(n: number): number {
    const v: number = DemoMockData.setTargetCount(n);
    MemoryRepository.get().refreshDemoData();
    this.notify();
    return v;
  }

  private notify(): void {
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i]();
    }
  }
}
