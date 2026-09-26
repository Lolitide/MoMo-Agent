# 部署检查清单

## ✅ 已完成的功能

### 1. 数据持久化
- ✅ L2 长期记忆持久化（本地 + 云端）
- ✅ L1 每日记录持久化（本地 + 云端）
- ✅ 自动云端同步机制
- ✅ 三级数据降级策略（云端 → 系统数据 → Mock）

### 2. 云服务集成
- ✅ 华为账号登录
- ✅ 云数据库服务（CloudDB）
- ✅ 云函数集成（LLM 总结、漫画脚本、图片生成）
- ✅ 用户配额管理

### 3. 核心功能
- ✅ 记忆花园（长期记忆管理）
- ✅ 今日回忆（每日事件记录）
- ✅ AI 每日总结
- ✅ 漫画生成（脚本 + 图片）

## 📋 部署前准备

### 1. 华为云控制台配置

#### 1.1 云数据库表更新
```bash
# 登录华为云控制台
# AGConnect → 云数据库 → 对象类型
# 导入 objecttypes.json 文件
```

**需要更新的表**：
- `UserProfile` - 用户配置
- `DailyRecord` - 每日记录
- `ComicImage` - 漫画图片
- `UserFeedback` - 用户反馈
- `LongTermMemory` - **新增**长期记忆表

#### 1.2 云函数部署
确保以下云函数已部署：
- `llm-daily-summary` - LLM 每日总结
- `llm-comic-script` - LLM 漫画脚本生成
- `image-generate` - 图片生成

#### 1.3 配置文件检查
- ✅ `entry/src/main/resources/rawfile/agconnect-services.json` - AGC 配置
- ✅ `AppScope/app.json5` - 应用配置
- ✅ `build-profile.json5` - 构建配置
- ✅ 签名文件：`sign/momo_debug.p12`

### 2. 权限配置

#### 2.1 云数据库权限
所有表的权限配置（已在 objecttypes.json 中定义）：
- World: 无权限
- Authenticated: 无权限
- Creator: Read, Upsert, Delete
- Administrator: Read, Upsert, Delete

#### 2.2 应用权限
已在 `module.json5` 中配置：
- `ohos.permission.INTERNET` - 网络访问
- `ohos.permission.GET_NETWORK_INFO` - 网络状态
- 其他必需权限...

### 3. 数据库索引

#### LongTermMemory 索引
- `idx_longtermemory_user_date`: (userId, dateTimestamp) - 用户日期查询
- `idx_longtermemory_type`: (type) - 类型查询
- `idx_longtermemory_updatedAt`: (updatedAt) - 同步更新

#### DailyRecord 索引
- `idx_dailyrecord_user_date`: (userId, date) - 用户日期查询
- `idx_dailyrecord_updatedAt`: (updatedAt) - 同步更新

## 🚀 部署步骤

### 步骤 1：构建应用
```bash
# 在 DevEco Studio 中
# Build → Build Hap(s)/APP(s) → Build APP(s)
```

### 步骤 2：签名配置
- 确保 `sign/momo_debug.p12` 文件存在
- 检查 `build-profile.json5` 中的签名配置

### 步骤 3：云服务验证
1. 登录华为云控制台
2. AGConnect → 概览 → 查看应用状态
3. 云数据库 → 对象类型 → 导入 `objecttypes.json`
4. 云函数 → 查看函数列表 → 确认 3 个函数已部署

### 步骤 4：测试流程

#### 4.1 登录测试
1. 启动应用
2. 使用华为账号登录
3. 验证用户信息加载

#### 4.2 数据同步测试
1. 添加记忆 → 检查云数据库是否有记录
2. 重启应用 → 验证数据从云端恢复
3. 添加今日事件 → 验证保存到云端

#### 4.3 AI 功能测试
1. 点击"生成今日总结" → 验证 LLM 调用
2. 点击"生成漫画" → 验证漫画脚本生成
3. 等待图片生成 → 验证图片下载

#### 4.4 离线测试
1. 关闭网络 → 添加记忆（应该保存到本地）
2. 打开网络 → 验证数据同步到云端

### 步骤 5：发布

#### 5.1 测试版本
- Build → Build APP(s) → 选择 debug 配置
- 安装到测试设备进行验证

#### 5.2 正式版本
- 切换到 release 配置
- 使用正式签名证书
- Build → Build APP(s)
- 上传到华为应用市场

## 🔍 验证要点

### 数据持久化验证
- [ ] 登录后添加记忆，重启应用数据恢复
- [ ] 云数据库中能看到 LongTermMemory 记录
- [ ] 云数据库中能看到 DailyRecord 记录
- [ ] 未登录时数据仅保存在本地
- [ ] 离线操作，联网后自动同步

### 云服务验证
- [ ] 华为账号登录成功
- [ ] LLM 每日总结功能正常
- [ ] 漫画脚本生成功能正常
- [ ] 图片生成功能正常
- [ ] 配额管理功能正常

### UI/UX 验证
- [ ] 记忆花园显示正常
- [ ] 今日回忆显示正常
- [ ] 漫画展示页面正常
- [ ] 加载状态提示清晰
- [ ] 错误提示友好

## 📊 监控指标

### 性能指标
- 应用启动时间 < 3秒
- 数据同步时间 < 2秒
- LLM 响应时间 < 10秒
- 图片生成时间 < 30秒

### 成功率指标
- 登录成功率 > 95%
- 数据同步成功率 > 99%
- 云函数调用成功率 > 95%

## ⚠️ 已知限制

1. **配额限制**
   - 每日 LLM 调用次数有限（在 UserProfile 中配置）
   - 每日图片生成次数有限

2. **网络依赖**
   - 云服务功能需要网络连接
   - 离线模式功能有限

3. **首次使用**
   - 需要用户手动登录华为账号
   - 首次同步可能较慢

## 🐛 故障排查

### 问题 1：数据同步失败
**症状**：添加记忆后云端没有数据  
**排查**：
1. 检查网络连接
2. 检查华为账号登录状态
3. 查看 DevEco Studio 日志中的错误信息
4. 检查云数据库权限配置

### 问题 2：LLM 调用失败
**症状**：点击"生成总结"没有反应  
**排查**：
1. 检查云函数是否部署
2. 检查用户配额是否用完
3. 查看云函数日志
4. 检查 API Key 配置

### 问题 3：应用启动慢
**症状**：启动时间超过 5 秒  
**排查**：
1. 检查是否在等待云服务初始化
2. 查看日志中的耗时操作
3. 考虑优化数据加载策略

## 📚 相关文档

- `数据持久化完成总结.md` - 数据持久化功能说明
- `DATA_PERSISTENCE_README.md` - 详细实现文档
- `AI_INTEGRATION_SUMMARY.md` - AI 功能集成说明
- `华为云服务配置指南.md` - 云服务配置步骤

## 🎯 下次迭代计划

1. **冲突解决机制**
   - 多设备同时修改的数据冲突处理
   - 版本控制和时间戳比较

2. **离线队列**
   - 离线操作队列
   - 联网后批量同步

3. **本地持久化**
   - relationalStore 支持
   - 完全离线也能使用

4. **性能优化**
   - 数据压缩
   - 分页加载优化
   - 缓存策略

---

**准备交付**：✅ 核心功能已完成，可以开始部署测试  
**更新时间**：2026-09-26
