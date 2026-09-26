# 数据持久化实现说明

## 概述

已完成 L1（每日记录）和 L2（长期记忆）的数据持久化功能，支持本地内存 + 云端数据库的混合存储方案。

## 实现的功能

### 1. L2 长期记忆持久化

#### 云数据库模型
- **文件**: `entry/src/main/ets/service/cloud/CloudDBModels.ets`
- **模型**: `LongTermMemory`
- **字段**:
  - `memoryId`: 记忆ID（主键）
  - `userId`: 用户ID
  - `title`: 标题
  - `date`: 日期（YYYY-MM-DD）
  - `dateTimestamp`: 时间戳（用于排序）
  - `summary`: 摘要
  - `content`: 内容
  - `type`: 类型（0=日常，1=重要事件，2=灵感/想法，3=学习/成长）
  - `importance`: 重要性（1-5）
  - `tags`: 标签（JSON数组）
  - `sourceEvents`: 来源事件（JSON数组）
  - `relatedMemoryIds`: 关联记忆ID（JSON数组）
  - `createdAt`: 创建时间
  - `updatedAt`: 更新时间

#### CloudDBService 新增方法
- **文件**: `entry/src/main/ets/service/cloud/CloudDBService.ets`
- **方法**:
  - `upsertMemory(memory: LongTermMemory)`: 保存/更新记忆
  - `getMemory(userId: string, memoryId: string)`: 获取指定记忆
  - `getUserMemories(userId: string, limit: number, offset: number)`: 获取用户的所有记忆（分页）
  - `getMemoriesByType(userId: string, type: number, limit: number)`: 按类型获取记忆
  - `deleteMemory(memory: LongTermMemory)`: 删除记忆
  - `deleteMemories(memories: LongTermMemory[])`: 批量删除记忆

#### MemoryRepository 增强
- **文件**: `entry/src/main/ets/repository/Repositories.ets`
- **新增功能**:
  - `enableCloudSync(userId: string)`: 启用云端同步
  - `loadFromCloud()`: 从云端加载记忆
  - `syncToCloud(memory: Memory)`: 同步记忆到云端
  - `deleteFromCloud(memoryId: string)`: 从云端删除记忆
  - 自动在 add/update/delete 操作时同步到云端

### 2. L1 每日记录持久化

#### EventRepository 增强
- **文件**: `entry/src/main/ets/repository/Repositories.ets`
- **新增功能**:
  - `enableCloudSync(userId: string)`: 启用云端同步
  - `getToday()`: 优先从云端加载今日记录，降级到系统数据/Mock
  - `saveTodayEvents(events: any[], mood?: string)`: 保存今日事件到云端
  - `getHistorySummaries(limit: number)`: 从云端获取历史总结记录

### 3. 数据同步服务

#### DataSyncService
- **文件**: `entry/src/main/ets/service/DataSyncService.ets`
- **功能**:
  - 统一管理所有 Repository 的云端同步初始化
  - 检查用户登录状态
  - 为 MemoryRepository 和 EventRepository 启用云端同步
  - 提供手动全量同步功能
- **方法**:
  - `initialize()`: 初始化数据同步服务
  - `isSyncActive()`: 检查同步是否已启用
  - `syncAll()`: 手动触发全量同步
  - `getCurrentUserId()`: 获取当前用户ID

### 4. 应用启动集成

#### EntryAbility
- **文件**: `entry/src/main/ets/entryability/EntryAbility.ets`
- **修改**:
  - 在 `onCreate` 中添加 `initializeDataSync()` 调用
  - 异步初始化，不阻塞应用启动
  - 初始化失败降级到本地存储

### 5. 云数据库表定义

#### objecttypes.json
- **文件**: `objecttypes.json`
- **新增表**: `LongTermMemory`
- **索引**:
  - `idx_longtermemory_user_date`: (userId, dateTimestamp) - 用于按日期查询
  - `idx_longtermemory_type`: (type) - 用于按类型查询
  - `idx_longtermemory_updatedAt`: (updatedAt) - 用于同步
- **权限**: Creator 和 Administrator 可读写删除

## 数据流

### 写入流程
1. 用户操作（添加/更新/删除记忆）
2. Repository 更新本地内存数据
3. 自动同步到云端数据库（如果已启用）
4. 触发 UI 更新（通过订阅机制）

### 读取流程
1. 应用启动时初始化 DataSyncService
2. 检查用户登录状态
3. 如果已登录，从云端加载数据到本地 Repository
4. UI 从 Repository 读取数据展示

### 降级策略
- 云端同步失败 → 继续使用本地数据
- 用户未登录 → 仅使用本地数据
- 网络错误 → 数据缓存在本地，下次同步时上传

## 使用示例

### 初始化（自动完成）
```typescript
// 在 EntryAbility.onCreate 中自动调用
DataSyncService.get().initialize();
```

### 添加记忆
```typescript
const memoryRepo = MemoryRepository.get();

const memory = new Memory(
  'memory_001',
  '今天学会了 TypeScript',
  new Date(),
  MemoryType.LEARNING,
  3
);

memoryRepo.add(memory); // 自动同步到云端
```

### 获取记忆
```typescript
const memoryRepo = MemoryRepository.get();

// 获取所有记忆（已从云端加载）
const memories = memoryRepo.getAll();

// 获取指定记忆
const memory = memoryRepo.getById('memory_001');
```

### 保存每日事件
```typescript
const eventRepo = EventRepository.get();

const events = [
  { time: '09:00', title: '早餐', description: '吃了煎蛋' },
  { time: '10:00', title: '工作', description: '写代码' }
];

await eventRepo.saveTodayEvents(events, '开心');
```

### 获取今日记录
```typescript
const eventRepo = EventRepository.get();

// 优先从云端加载
const daily = await eventRepo.getToday();
console.log(daily.events);
```

## 测试建议

1. **登录后测试**
   - 添加记忆 → 检查云端数据库
   - 重启应用 → 验证数据是否从云端恢复

2. **未登录测试**
   - 添加记忆 → 仅保存在本地
   - 登录后 → 数据应该同步到云端

3. **离线测试**
   - 关闭网络 → 添加记忆
   - 恢复网络 → 验证数据是否同步

4. **多设备测试**
   - 设备A添加记忆
   - 设备B登录同一账号 → 验证数据同步

## 注意事项

1. **隐私安全**
   - 用户数据仅在登录后同步
   - 云端数据有权限控制（Creator 权限）

2. **性能优化**
   - 分页加载记忆（默认100条）
   - 按需加载历史记录

3. **错误处理**
   - 所有云端操作都有 try-catch
   - 失败时不影响本地操作

4. **数据一致性**
   - 以云端数据为准
   - 本地作为缓存

## 下一步优化

1. **冲突解决**
   - 实现多设备同时修改的冲突检测
   - 添加版本号或时间戳比较

2. **离线队列**
   - 离线时将操作加入队列
   - 联网后自动同步

3. **增量同步**
   - 仅同步变更的数据
   - 减少网络流量

4. **本地持久化**
   - 添加 relationalStore 支持
   - 彻底离线也能使用

5. **数据压缩**
   - 压缩大字段（content、events等）
   - 减少存储空间
