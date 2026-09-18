# AI服务使用说明

## 概述

默默的AI服务基于模块化设计，支持多种LLM提供商，并提供完善的降级机制。

## 架构

```
AIService (统一入口)
├── LLMProvider (抽象层)
│   ├── DeepSeekProvider (DeepSeek API)
│   ├── OpenAIProvider (预留，未实现)
│   └── MockProvider (离线Mock)
├── HttpClient (网络请求)
├── AIConfigManager (配置管理)
└── Logger (日志工具)
```

## 快速开始

### 1. 配置API Key（可选）

如果要使用真实AI能力，需要配置DeepSeek API Key：

```bash
# 编辑配置文件
vi entry/src/main/resources/rawfile/ai_config.json
```

```json
{
  "provider": "deepseek",
  "apiKey": "sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "baseUrl": "https://api.deepseek.com/v1",
  "model": "deepseek-chat",
  "timeout": 30000,
  "retry": 3
}
```

**获取API Key**：
1. 访问 https://platform.deepseek.com
2. 注册并登录
3. 在"API Keys"页面创建新密钥
4. 复制密钥到配置文件

**注意**：ai_config.json已加入.gitignore，不会提交到Git仓库。

### 2. 使用Mock模式（无需配置）

如果不配置API Key，系统会自动使用Mock模式，提供预设的演示数据。

### 3. 在代码中使用

```typescript
import { AIService } from '../service/ai/AIService';
import { EventItem } from '../model/Models';

// 初始化（只需一次，通常在应用启动时）
const aiService = AIService.get();
await aiService.initialize();

// 生成每日总结
const events: EventItem[] = [...];
const summary = await aiService.generateDailySummary(events);

// 生成漫画脚本
const comicScript = await aiService.generateComicScript(summary, events);

// 处理记忆纠正
const correction = await aiService.processMemoryCorrection(
  memoryId,
  memoryContent,
  userFeedback
);

// 检查运行模式
const isOffline = aiService.isOfflineMode(); // true表示Mock模式
const providerName = aiService.getProviderName(); // "DeepSeek" 或 "Mock (离线模式)"
```

## API说明

### AIService.generateDailySummary()

生成每日总结，包含摘要、情绪、主题和洞察。

**参数**：
- `events: EventItem[]` - 今日事件列表
- `context?: string` - 额外上下文（可选）

**返回**：JSON字符串
```json
{
  "summary": "今日总结文本",
  "emotion": "整体情绪",
  "theme": "今日主题",
  "insights": [
    {"title": "洞察标题", "content": "洞察内容"}
  ]
}
```

### AIService.generateComicScript()

生成漫画分镜脚本。

**参数**：
- `dailySummary: string` - 每日总结
- `events: EventItem[]` - 今日事件列表

**返回**：JSON字符串
```json
{
  "title": "漫画标题",
  "scenes": [
    {
      "index": 1,
      "title": "场景标题",
      "description": "场景描述",
      "emotion": "情绪标签"
    }
  ]
}
```

### AIService.processMemoryCorrection()

处理用户对记忆的纠正反馈。

**参数**：
- `memoryId: string` - 记忆ID
- `memoryContent: string` - 当前记忆内容
- `userFeedback: string` - 用户反馈

**返回**：JSON字符串
```json
{
  "action": "update_memory",
  "memoryId": "m2",
  "updates": {
    "title": "新标题",
    "importance": 5,
    "tags": ["标签1", "标签2"]
  },
  "reasoning": "推理说明"
}
```

## 测试

项目包含AI能力测试页面：`entry/src/main/ets/pages/B_AITest.ets`

可以测试：
- 每日总结生成
- 漫画脚本生成
- 记忆纠正处理

## 降级机制

系统具备完善的降级策略：

1. **DeepSeek API可用** → 使用真实AI能力
2. **API Key未配置** → 自动降级到Mock模式
3. **网络不可用** → 自动降级到Mock模式
4. **API调用失败** → 重试3次后降级到Mock模式

## 费用说明

DeepSeek API费用（截至2026年9月）：
- 输入：¥1/百万tokens
- 输出：¥2/百万tokens

预估成本：
- 每日总结：约0.001元/次
- 漫画脚本：约0.002元/次
- 记忆纠正：约0.0008元/次

**日均使用成本**：< ¥0.01元（每天生成一次总结和漫画）

## 故障排查

### 问题1：提示"网络请求失败"

**原因**：网络权限未授予或网络不可用

**解决**：
1. 检查 `module.json5` 是否包含网络权限
2. 确认设备已连接网络
3. 检查防火墙是否拦截

### 问题2：DeepSeek API返回401错误

**原因**：API Key无效或已过期

**解决**：
1. 检查 `ai_config.json` 中的apiKey是否正确
2. 访问DeepSeek平台确认Key是否有效
3. 检查Key是否有足够的余额

### 问题3：响应速度慢

**原因**：网络延迟或API负载高

**解决**：
1. 检查网络连接质量
2. 适当增加 `timeout` 配置
3. 考虑使用Mock模式进行演示

## 未来扩展

- [ ] 支持OpenAI API
- [ ] 支持流式响应（SSE）
- [ ] 支持华为盘古大模型
- [ ] 支持本地模型（ONNX）
- [ ] 增加缓存机制减少API调用
- [ ] 支持批量请求

## 技术参考

- [DeepSeek API文档](https://platform.deepseek.com/api-docs/)
- [HarmonyOS网络请求](https://developer.huawei.com/)
- [@ohos.net.http API](https://developer.huawei.com/)
