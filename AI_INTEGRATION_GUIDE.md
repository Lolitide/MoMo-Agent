# AI 服务集成完成指南

## 已完成的工作

### 1. EntryAbility 初始化
✅ 在应用启动时初始化 AI 云服务
- 文件：`entry/src/main/ets/entryability/EntryAbility.ets`
- 修改：添加了 `initializeAIService()` 方法
- 功能：异步初始化 `AIServiceCloud`，失败不影响启动

### 2. Repository 层增强

#### EventRepository
✅ 新增方法：
- `generateDailySummary(events, mood)` - 调用 AI 生成每日总结
- `getHistorySummaries(limit)` - 获取历史总结记录
- 降级策略：AI 服务失败时返回 Mock 数据

#### ComicRepository
✅ 新增方法：
- `generateTodayComic(summary, events)` - 生成完整漫画（脚本 + 图片）
- `generateComicScript(summary, events)` - 仅生成漫画脚本
- 降级策略：AI 服务失败时返回 Mock 数据

### 3. 增强版页面

#### B_TodayMemory_Enhanced.ets
✅ 新功能：
- 菜单新增「生成总结」按钮（sparkles 图标）
- 调用 `EventRepository.generateDailySummary()`
- 显示生成状态（生成中/成功/失败）
- Toast 提示用户生成进度

#### B_DailyComic_Enhanced.ets
✅ 新功能：
- 菜单新增「生成漫画」按钮（photo_on_rectangle 图标）
- 调用 `ComicRepository.generateTodayComic()`
- 显示生成状态（生成中/成功/失败）
- Loading 文案动态显示

---

## 接下来的步骤

### 第 1 步：测试 AI 服务初始化

1. **检查云函数配置**
```bash
# 查看云函数配置
cat cloud-functions/functions.json

# 确认 DeepSeek API Key 是否配置
grep -r "DEEPSEEK_API_KEY" cloud-functions/
```

2. **测试华为账号登录**
- 启动应用
- 查看日志：`AI云服务初始化成功` 或失败信息
- 确认用户已登录

### 第 2 步：替换原有页面（可选）

如果测试通过，可以用增强版替换原版：
```bash
# 备份原版
mv entry/src/main/ets/pages/B_TodayMemory.ets entry/src/main/ets/pages/B_TodayMemory_Old.ets
mv entry/src/main/ets/pages/B_DailyComic.ets entry/src/main/ets/pages/B_DailyComic_Old.ets

# 使用增强版
mv entry/src/main/ets/pages/B_TodayMemory_Enhanced.ets entry/src/main/ets/pages/B_TodayMemory.ets
mv entry/src/main/ets/pages/B_DailyComic_Enhanced.ets entry/src/main/ets/pages/B_DailyComic.ets
```

或者在路由配置中切换到增强版：
```typescript
// 修改 router/AppRouter.ets
import { B_TodayMemory_Enhanced } from '../pages/B_TodayMemory_Enhanced';
import { B_DailyComic_Enhanced } from '../pages/B_DailyComic_Enhanced';
```

### 第 3 步：真机测试完整流程

1. **今日状态页**
   - 进入「今日状态」页面
   - 点击右上角菜单「生成总结」
   - 观察 Loading 状态
   - 确认总结是否生成成功
   - 检查 Toast 提示

2. **今日漫画页**
   - 进入「今日漫画」页面
   - 点击右上角菜单「生成漫画」
   - 观察 Loading 状态（可能需要 30-60 秒）
   - 确认漫画是否生成成功
   - 检查图片是否正常显示

### 第 4 步：处理可能的问题

#### 问题 1：AI 服务初始化失败
**排查**：
- 检查华为账号是否登录成功
- 查看 `CloudServiceManager` 初始化日志
- 确认云函数部署状态

**解决**：
- 应用会自动降级到 Mock 数据
- 不影响基础功能使用

#### 问题 2：生成总结/漫画失败
**可能原因**：
- API Key 未配置或无效
- 配额不足
- 网络问题
- 云函数调用失败

**解决**：
- 检查 `CloudDBService` 配额管理
- 查看云函数日志
- 确认 DeepSeek API 和即梦 AI 服务可用

#### 问题 3：漫画图片无法显示
**原因**：
- 本地图片路径转换未实现
- `Resource` 类型转换问题

**解决**：
- 当前版本使用占位图
- 需要实现 `CloudStorageService.downloadComicImages()` 返回的本地路径转换为 `Resource`

---

## 架构说明

### 数据流向

```
用户点击「生成总结」
    ↓
B_TodayMemory_Enhanced.generateRealSummary()
    ↓
EventRepository.generateDailySummary(events, mood)
    ↓
AIServiceCloud.generateDailySummary(events, mood)
    ↓
CloudServiceManager.getCloudFunction()
    ↓
CloudFunctionService.generateDailySummary(request)
    ↓
云函数 llm-daily-summary.js
    ↓
DeepSeek API
    ↓
返回生成的总结
    ↓
CloudDBService.upsertDailyRecord(record)
    ↓
更新页面 UI
```

### 降级策略

每一层都有降级方案：
1. **AI 服务层**：失败返回错误，Repository 捕获
2. **Repository 层**：捕获错误，返回 Mock 数据
3. **页面层**：显示生成失败 Toast，保持原有数据

---

## 待完成的工作

### 优先级 2：数据持久化
- [ ] 实现本地 `relationalStore` 数据库
- [ ] L2 长期记忆落库
- [ ] L1 每日记录落库
- [ ] 重启后数据恢复

### 优先级 3：系统数据接入
- [ ] 申请日历权限
- [ ] 读取日历事件
- [ ] 申请待办权限
- [ ] 读取待办事项
- [ ] 申请备忘录权限
- [ ] 读取备忘录内容

### 优先级 4：完善 AI 功能
- [ ] 实现漫画图片本地缓存
- [ ] 实现 `Resource` 类型转换
- [ ] 添加生成进度回调
- [ ] 支持取消生成
- [ ] 配额管理 UI

---

## 测试清单

- [ ] 应用启动，AI 服务初始化成功
- [ ] 华为账号登录成功
- [ ] 进入今日状态页，点击「生成总结」
- [ ] 总结生成成功，UI 更新
- [ ] 进入今日漫画页，点击「生成漫画」
- [ ] 漫画生成成功，图片显示
- [ ] 配额检查正常（每日限额）
- [ ] 网络断开时降级到 Mock 数据
- [ ] 生成失败时 Toast 提示正确

---

## 已知限制

1. **漫画图片显示**：当前使用占位图，需要实现本地路径 → Resource 转换
2. **事件数据**：当前使用 Mock 数据，需要接入真实系统数据
3. **配额管理**：仅在后端检查，前端 UI 未展示
4. **生成进度**：仅显示 Loading，无具体进度（如：生成第 3/5 张图片）
5. **错误处理**：错误信息不够详细，需要细化

---

## 文件清单

### 修改的文件
- `entry/src/main/ets/entryability/EntryAbility.ets` - 添加 AI 服务初始化
- `entry/src/main/ets/repository/Repositories.ets` - EventRepository 和 ComicRepository 增强

### 新增的文件
- `entry/src/main/ets/pages/B_TodayMemory_Enhanced.ets` - 增强版今日状态页
- `entry/src/main/ets/pages/B_DailyComic_Enhanced.ets` - 增强版今日漫画页
- `AI_INTEGRATION_GUIDE.md` - 本文档

### 已有的服务层（无需修改）
- `entry/src/main/ets/service/ai/AIServiceCloud.ets` - AI 服务封装
- `entry/src/main/ets/service/cloud/CloudDBService.ets` - 云数据库服务
- `entry/src/main/ets/service/cloud/CloudFunctionService.ets` - 云函数服务
- `entry/src/main/ets/service/cloud/CloudStorageService.ets` - 云存储服务
- `entry/src/main/ets/service/auth/AuthService.ets` - 认证服务
- `cloud-functions/llm-daily-summary.js` - 每日总结云函数
- `cloud-functions/llm-comic-script.js` - 漫画脚本云函数
- `cloud-functions/image-generate.js` - 图片生成云函数
