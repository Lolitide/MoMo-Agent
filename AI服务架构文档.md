# 默默 Mo Mo - AI服务架构文档

> 第一周D1完成 - AIService接口设计与LLM接入

---

## 📦 新增文件结构

```
entry/src/main/ets/
├── service/ai/                          # AI服务模块（新增）
│   ├── AIService.ets                   # AI服务统一入口（主类）
│   ├── AIConfigManager.ets             # 配置管理（Preferences + rawfile）
│   ├── AIModels.ets                    # 数据模型定义
│   ├── LLMProvider.ets                 # LLM提供商抽象基类
│   ├── DeepSeekProvider.ets            # DeepSeek API实现
│   ├── MockProvider.ets                # Mock提供商（离线演示）
│   ├── HttpClient.ets                  # HTTP网络请求封装
│   ├── index.ets                       # 模块统一导出
│   └── README.md                       # 使用说明文档
├── utils/
│   └── Logger.ets                      # 日志工具（新增）
└── pages/
    └── B_AITest.ets                    # AI能力测试页面（新增）

entry/src/main/resources/
└── rawfile/
    └── ai_config.json                   # AI配置文件（新增，不入库）

entry/src/main/
├── module.json5                         # 更新：添加网络权限
└── resources/base/element/
    └── string.json                      # 更新：添加权限说明文案
```

---

## 🔧 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| 网络请求 | @ohos.net.http | HarmonyOS原生网络API |
| 数据存储 | @ohos.data.preferences | 配置持久化 |
| 日志 | @ohos.hilog | HarmonyOS原生日志API |
| LLM服务商 | DeepSeek API | 兼容OpenAI格式，性价比高 |
| 降级方案 | MockProvider | 离线演示，无需配置 |

---

## 🎯 核心类说明

### 1. AIService（服务入口）

**职责**：
- 管理LLM提供商实例
- 提供场景化的AI能力接口
- 自动降级和错误处理

**主要方法**：
```typescript
// 初始化（应用启动时调用一次）
async initialize(): Promise<void>

// 生成每日总结
async generateDailySummary(events: EventItem[], context?: string): Promise<string>

// 生成漫画分镜脚本
async generateComicScript(dailySummary: string, events: EventItem[]): Promise<string>

// 处理记忆纠正
async processMemoryCorrection(memoryId: string, memoryContent: string, userFeedback: string): Promise<string>

// 通用对话接口
async chat(messages: ChatMessage[], options?: Partial<LLMRequest>): Promise<LLMResponse>

// 获取当前状态
getProviderName(): string
isOfflineMode(): boolean
```

### 2. LLMProvider（抽象基类）

**职责**：定义LLM提供商的统一接口

**主要方法**：
```typescript
abstract chat(request: LLMRequest): Promise<LLMResponse>
abstract testConnection(): Promise<boolean>
abstract getName(): string
```

### 3. DeepSeekProvider（DeepSeek实现）

**特点**：
- 兼容OpenAI API格式
- 支持超时、重试
- 详细的Token使用日志

### 4. MockProvider（Mock实现）

**特点**：
- 根据关键词匹配预设响应
- 模拟网络延迟
- 支持所有场景（每日总结、漫画、纠正）

### 5. HttpClient（网络请求）

**特点**：
- 基于 @ohos.net.http 封装
- 支持超时控制（默认30秒）
- 支持自动重试（默认3次）
- JSON自动序列化/反序列化
- 4xx错误不重试

### 6. AIConfigManager（配置管理）

**配置优先级**：
1. Preferences（用户修改的配置）
2. rawfile/ai_config.json（开发配置）
3. DEFAULT_AI_CONFIG（默认配置）

---

## 🔄 工作流程

### 初始化流程

```
应用启动
    ↓
AIService.get().initialize()
    ↓
AIConfigManager.loadConfig()
    ↓
    ├─ 从Preferences加载 ✓
    │  └─ apiKey存在 → 选择DeepSeekProvider
    ├─ 从rawfile加载 ✓
    │  └─ apiKey存在 → 选择DeepSeekProvider
    └─ 使用默认配置
       └─ 选择MockProvider
    ↓
testConnection()（仅DeepSeek）
    ↓
    ├─ 连接成功 → 使用DeepSeek
    └─ 连接失败 → 降级到Mock
    ↓
初始化完成
```

### 每日总结生成流程

```
用户触发生成
    ↓
AIService.generateDailySummary(events)
    ↓
构建System Prompt + User Prompt
    ↓
provider.chat(request)
    ↓
    ├─ DeepSeek模式
    │  └─ HttpClient.post()
    │     └─ 发送到DeepSeek API
    │        ├─ 成功 → 返回JSON结果
    │        └─ 失败 → 重试3次
    │
    └─ Mock模式
       └─ 关键词匹配
          └─ 返回预设JSON
    ↓
返回结果字符串（JSON格式）
    ↓
页面解析并展示
```

---

## 📊 数据模型

### ChatMessage

```typescript
interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}
```

### LLMRequest

```typescript
interface LLMRequest {
  messages: ChatMessage[];
  temperature?: number;    // 0-2，默认0.7
  max_tokens?: number;     // 默认2000
  top_p?: number;          // 默认0.9
  stream?: boolean;        // 默认false
}
```

### LLMResponse

```typescript
interface LLMResponse {
  content: string;
  finishReason: string;
  usage?: {
    promptTokens: number;
    completionTokens: number;
    totalTokens: number;
  };
}
```

### AIConfig

```typescript
interface AIConfig {
  provider: 'deepseek' | 'openai' | 'mock';
  apiKey: string;
  baseUrl: string;
  model: string;
  timeout?: number;
  retry?: number;
}
```

---

## 🔐 安全性

1. **API Key保护**：
   - ai_config.json 加入 .gitignore
   - 配置文件不提交到Git仓库
   - 使用Preferences存储用户配置

2. **网络安全**：
   - 仅使用HTTPS
   - 请求头包含Authorization
   - 超时保护防止长时间挂起

3. **错误处理**：
   - 所有网络请求都有try-catch
   - 失败自动降级到Mock模式
   - 详细的错误日志

---

## 🧪 测试方法

### 方法1：使用测试页面

1. 运行应用
2. 导航到 `B_AITest` 页面
3. 点击测试按钮验证各项功能

### 方法2：在现有页面集成

```typescript
import { AIService } from '../service/ai';

// 在页面初始化时
async aboutToAppear() {
  const aiService = AIService.get();
  await aiService.initialize();
  console.log('当前提供商:', aiService.getProviderName());
}

// 使用AI能力
async generateSummary() {
  const aiService = AIService.get();
  const events = this.getTodayEvents(); // 获取今日事件
  const result = await aiService.generateDailySummary(events);
  const summary = JSON.parse(result);
  console.log('今日总结:', summary.summary);
}
```

---

## 💰 成本预估

### DeepSeek API定价（2026年9月）

| 类型 | 价格 |
|------|------|
| 输入Token | ¥1/百万tokens |
| 输出Token | ¥2/百万tokens |

### 单次调用成本

| 场景 | 输入Token | 输出Token | 成本 |
|------|-----------|-----------|------|
| 每日总结 | ~500 | ~300 | ~¥0.001 |
| 漫画脚本 | ~600 | ~500 | ~¥0.002 |
| 记忆纠正 | ~400 | ~200 | ~¥0.0008 |

**日均成本**：< ¥0.01元（每天生成一次总结和漫画）

**月成本**：< ¥0.3元

---

## 🚀 后续优化方向

### 短期（本周内）

- [ ] 集成到今日状态页（D2-D3）
- [ ] 集成到今日漫画页（D4）
- [ ] 集成到记忆花园（D5）

### 中期（下周）

- [ ] 添加缓存机制（减少重复调用）
- [ ] 支持流式响应（SSE）
- [ ] 批量请求优化

### 长期（后续迭代）

- [ ] 支持OpenAI API
- [ ] 支持华为盘古大模型
- [ ] 支持本地模型（ONNX）
- [ ] 向量数据库集成（RAG）

---

## 📚 参考资源

### 官方文档
- [DeepSeek API文档](https://platform.deepseek.com/api-docs/)
- [HarmonyOS网络请求](https://developer.huawei.com/)
- [@ohos.net.http API](https://developer.huawei.com/)

### 社区案例
- [HarmonyOS NEXT 实战：DeepSeek API构建流式对话助手](https://cloud.tencent.com/developer/article/2723064)
- [OpenHarmony axios封装](https://devpress.csdn.net/v1/article/detail/162883670)
- [ArkTS网络连接管理使用指南](https://cloud.tencent.com/developer/article/2601960)

---

## ✅ D1完成总结

**完成时间**：2026-09-18  
**完成度**：100%  
**代码量**：约1700行（含文档）  
**测试状态**：待真机验证  
**下一步**：D2 - Observation Agent实现
