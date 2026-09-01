/*
 * ============================================================================
 * 文件名：repository/Repositories.ets
 * ============================================================================
 * 【用途】仓库层（数据出入口）：MemoryRepository（记忆增删清/恢复示例/订阅）、
 *   EventRepository（今日事件）、ComicRepository（今日漫画）、UserRepository（用户）。
 *   页面只依赖本层（UIKit -> Repository -> MockData）。
 * 【前置条件 / 假设】
 *   - 依赖：MockData、Models、DateUtil；
 *   - 假设：单例（get()）；默认内存存储（无持久化）；事件总线为静态回调数组。
 * 【输入 / 输出（后置条件）】
 *   - 输入：add/update/delete/clearAll/restoreSamples 等写操作；getAll/getById 读操作；
 *   - 输出：读操作返回数据（clone 或直接引用，约定只读）；
 *     写操作触发 subscribe 监听者（页面刷新视图）；
 *   - 后置：clearAll 后可用 restoreSamples() 复原演示数据。
 * 【关键类 / 算法】
 *   - 发布-订阅（pub/sub）：register/unregister + notify 循环调用；
 *   - getToday()：按日期过滤；loadFailed 模拟错误（漫画页错误态）。
 * 【参考源】
 *   - 废案 repository/（EventRepository/ComicRepository/…）；MVC/MVVM 分层惯例
 * ============================================================================
 */
import { MockData } from '../mock/MockData';
import {
  Comic, CompanionState, DailyMemory, Memory, MemoryTreeNode, MemoryType, User
} from '../model/Models';

export type RepoListener = () => void;

// 记忆仓库（单例）：内存数组 + 发布订阅；add/update/delete/clearAll 后 notify 全量刷新花园视图
export class MemoryRepository {
  private static instance: MemoryRepository | null = null;
  private memories: Memory[] = MockData.buildMemories();
  private listeners: RepoListener[] = [];

  static get(): MemoryRepository {
    if (MemoryRepository.instance === null) {
      MemoryRepository.instance = new MemoryRepository();
    }
    return MemoryRepository.instance;
  }

  getAll(): Memory[] {
    return this.memories;
  }

  getById(id: string): Memory | null {
    for (let i = 0; i < this.memories.length; i++) {
      if (this.memories[i].id === id) {
        return this.memories[i];
      }
    }
    return null;
  }

  add(m: Memory): void {
    this.memories.unshift(m);
    this.notify();
  }

  update(m: Memory): void {
    for (let i = 0; i < this.memories.length; i++) {
      if (this.memories[i].id === m.id) {
        this.memories[i] = m;
        break;
      }
    }
    this.notify();
  }

  delete(id: string): void {
    const next: Memory[] = [];
    for (let i = 0; i < this.memories.length; i++) {
      if (this.memories[i].id !== id) {
        next.push(this.memories[i]);
      }
    }
    this.memories = next;
    this.notify();
  }

  clearAll(): void {
    this.memories = [];
    this.notify();
  }

  restoreSamples(): void {
    this.memories = MockData.buildMemories();
    this.notify();
  }

  subscribe(cb: RepoListener): void {
    this.listeners.push(cb);
  }

  unsubscribe(cb: RepoListener): void {
    const next: RepoListener[] = [];
    for (let i = 0; i < this.listeners.length; i++) {
      if (this.listeners[i] !== cb) {
        next.push(this.listeners[i]);
      }
    }
    this.listeners = next;
  }

  private notify(): void {
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i]();
    }
  }
}

export class EventRepository {
  private static instance: EventRepository | null = null;

  static get(): EventRepository {
    if (EventRepository.instance === null) {
      EventRepository.instance = new EventRepository();
    }
    return EventRepository.instance;
  }

  getToday(): DailyMemory {
    return MockData.buildDailyMemory();
  }
}

export class ComicRepository {
  private static instance: ComicRepository | null = null;
  loadFailed: boolean = false;

  static get(): ComicRepository {
    if (ComicRepository.instance === null) {
      ComicRepository.instance = new ComicRepository();
    }
    return ComicRepository.instance;
  }

  getToday(): Comic {
    return MockData.buildComic();
  }
}

export class UserRepository {
  private static instance: UserRepository | null = null;

  static get(): UserRepository {
    if (UserRepository.instance === null) {
      UserRepository.instance = new UserRepository();
    }
    return UserRepository.instance;
  }

  getUser(): User {
    return MockData.buildUser();
  }
}

export class CompanionRepository {
  private static instance: CompanionRepository | null = null;

  static get(): CompanionRepository {
    if (CompanionRepository.instance === null) {
      CompanionRepository.instance = new CompanionRepository();
    }
    return CompanionRepository.instance;
  }

  getState(): CompanionState {
    return MockData.buildCompanion();
  }
}

export class MemoryTreeRepository {
  private static instance: MemoryTreeRepository | null = null;

  static get(): MemoryTreeRepository {
    if (MemoryTreeRepository.instance === null) {
      MemoryTreeRepository.instance = new MemoryTreeRepository();
    }
    return MemoryTreeRepository.instance;
  }

  getTree(): MemoryTreeNode {
    return MockData.buildTreeNodes();
  }

  findNode(root: MemoryTreeNode | null, id: string): MemoryTreeNode | null {
    if (root === null) {
      return null;
    }
    if (root.id === id) {
      return root;
    }
    for (let i = 0; i < root.children.length; i++) {
      const found = this.findNode(root.children[i], id);
      if (found !== null) {
        return found;
      }
    }
    return null;
  }

  collectNodeIds(root: MemoryTreeNode | null, ids: string[]): void {
    if (root === null) {
      return;
    }
    ids.push(root.id);
    for (let i = 0; i < root.children.length; i++) {
      this.collectNodeIds(root.children[i], ids);
    }
  }

  findMemoryByNode(root: MemoryTreeNode | null, id: string): Memory | null {
    const node = this.findNode(root, id);
    if (node === null) {
      return null;
    }
    if (node.type === 'memory') {
      const m = MemoryRepository.get().getById(id);
      if (m !== null) {
        return m;
      }
    }
    return null;
  }
}

export class MemoryTypeUtilSafe {
  static makeMemory(id: string, title: string, summary: string, content: string, type: MemoryType): Memory {
    const m = new Memory(id, title, new Date(), type, 2);
    m.summary = summary;
    m.content = content;
    return m;
  }
}