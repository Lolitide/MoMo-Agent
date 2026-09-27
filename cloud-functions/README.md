# Momo 云函数

本目录保存客户端 `CloudFunctionService.ets` 调用的云函数实现与仓库级函数清单。`functions.json` 用于核对函数名、入口、资源和环境变量；部署时仍需在 AppGallery Connect 控制台逐项确认配置，不能把本地清单存在当作已部署成功。

## 当前函数

| 函数名 | 入口 | 用途 | 状态 |
| --- | --- | --- | --- |
| `llm-daily-summary` | `llm-daily-summary.handler` | 根据事件和心情生成每日总结 | 本地契约测试通过，未做真实云端联调 |
| `llm-chat` | `llm-chat.handler` | 带有限上下文的对话 | 本地契约测试通过，未做真实云端联调 |
| `llm-comic-script` | `llm-comic-script.handler` | 生成并校验 5 格漫画脚本 | 本地契约测试通过，未做真实云端联调 |
| `llm-memory-correction` | `llm-memory-correction.handler` | 按用户纠正重写总结 | 本地契约测试通过，未做真实云端联调 |
| `image-generate` | `image-generate.handler` | 调用 Ark 同步生成图片并签发短期回执 | 本地契约测试通过，未做真实云端联调 |
| `image-get-status` | `image-get-status.handler` | 解析图片生成完成回执 | 本地契约测试通过，未做真实云端联调 |

图片函数的实现和契约由 T2 维护；本 README 和 `functions.json` 已按 T2 进度区报告的最终清单条目合并。

## LLM 部署配置

四个 `llm-*` 入口都依赖同目录的 `llm-common.js`。创建部署压缩包时必须同时包含目标入口文件和 `llm-common.js`，不能只上传单个入口文件。

运行时：Node.js 18；建议函数超时 60 秒。环境变量：

| 变量 | 必填 | 说明 |
| --- | --- | --- |
| `DEEPSEEK_API_KEY` | 是 | 仅配置在云端环境变量中，不写入仓库或客户端 |
| `DEEPSEEK_MODEL` | 否 | 默认 `deepseek-flash` |
| `DEEPSEEK_TIMEOUT_MS` | 否 | 默认 `45000`，允许 `1000` 到 `55000`；必须小于函数 60 秒超时 |

实现调用 DeepSeek `POST https://api.deepseek.com/chat/completions`，非流式请求，关闭 thinking。漫画脚本请求启用 JSON 输出，但仍会在函数端校验主题、5 个连续分镜、字段类型和长度。上游 API Key、原始错误体和用户内容不会写入正常日志。

## 图片函数部署配置

`image-generate` 使用 Node.js 18、1024 MB、120 秒；`image-get-status` 使用 Node.js 18、256 MB、10 秒。两个部署包都必须包含 `image-task-token.js`，并配置完全相同、至少 32 字符的 `IMAGE_TASK_SECRET`。

`image-generate` 环境变量：

| 变量 | 必填 | 说明 |
| --- | --- | --- |
| `ARK_API_KEY` | 是 | Ark 服务端密钥，只配置在云端 |
| `ARK_IMAGE_MODEL` | 是 | 当前账号可用的模型或推理接入点，不使用代码内默认值 |
| `ARK_IMAGE_URL_HOST_SUFFIXES` | 是 | 逗号分隔的最小域名后缀白名单；按真实响应域名确认 |
| `IMAGE_TASK_SECRET` | 是 | 至少 32 字符；必须与 `image-get-status` 完全一致 |
| `ARK_IMAGE_TIMEOUT_MS` | 否 | 默认 50000，允许 5000-55000 毫秒 |
| `IMAGE_TASK_TTL_MS` | 否 | 回执有效期，默认 15 分钟；允许 1 分钟到 23 小时 |

图片生成请求为 `{ userId, prompt, style?, size?, useCharacterReference? }`。漫画主流程默认将
`useCharacterReference` 设为 `true`，云函数会从同目录的 `character-config.json` 读取
`character.protagonistImageUrl`（主角图）和 `character.referenceImageUrl`（场景参考图），并以 Ark
`image` 字段传给图生图接口。开启该字段但没有至少一张有效 HTTPS 图片时，函数会返回
`CONFIGURATION_ERROR`，不会伪装成文生图成功。

`image-get-status` 只需要同一 `IMAGE_TASK_SECRET`。Ark 非流式生成成功时已经返回最终 URL，因此 `taskId` 是本后端签发的短期加密回执，不是 Ark 异步任务 ID；状态函数只校验回执并返回同一 URL，不对 Ark 做无意义轮询。完整图片请求/响应、隐私边界和 T5 对接说明见 `PROJECT_COORDINATION.md` 的 T2 进度区。

## 身份与个人数据边界

请求中的 `userId` 来自客户端，只作为必填的兼容/关联字段校验。四个 LLM 函数不会把它当作已认证身份，不会据此读取、写入或授权任何个人数据库/存储数据，也不会把它发送给 DeepSeek。

这些函数是无状态文本转换接口。云端部署前仍必须在 AGC 侧配置调用访问控制、配额和监控；T0 提供真实认证身份约定前，不能宣称已经完成按用户隔离或抗滥用的真实云端验收。不要用放宽数据库 ACL 或信任任意客户端 `userId` 的方式绕过这个限制。

## 请求与响应契约

公共约束：请求必须是 JSON 对象；`userId` 为 1-256 字符；所有文本会去除首尾空白并做长度限制。成功响应的 `success` 为 `true`。失败响应统一为：

```json
{
  "success": false,
  "error": {
    "code": "INVALID_ARGUMENT",
    "message": "可安全展示的错误信息",
    "retryable": false
  }
}
```

常见错误码：

| 错误码 | 可重试 | 含义 |
| --- | --- | --- |
| `INVALID_ARGUMENT` | 否 | 请求字段、类型、数量或长度错误 |
| `CONFIGURATION_ERROR` | 否 | 云端缺少/错误配置环境变量 |
| `UPSTREAM_AUTH_ERROR` / `UPSTREAM_PAYMENT_REQUIRED` | 否 | 上游密钥或额度需要运维处理 |
| `UPSTREAM_RATE_LIMITED` / `UPSTREAM_TIMEOUT` / `UPSTREAM_UNAVAILABLE` | 是 | 上游限流、超时或临时不可用 |
| `UPSTREAM_TRUNCATED` / `UPSTREAM_INVALID_RESPONSE` | 是 | 上游输出被截断或结构不符合契约 |
| `UPSTREAM_CONTENT_FILTERED` / `UPSTREAM_REJECTED` | 否 | 上游内容策略或参数拒绝 |

### `llm-daily-summary`

请求：

```json
{
  "userId": "client-correlation-id",
  "events": ["完成了一个功能", "跑步三公里"],
  "mood": "开心"
}
```

`events` 必须有 1-50 项；单项最多 500 字，总计最多 8000 字。`mood` 可省略，默认“平静”，最多 64 字。

成功响应：

```json
{
  "success": true,
  "content": "今天的总结……",
  "usage": {
    "promptTokens": 120,
    "completionTokens": 80,
    "totalTokens": 200
  }
}
```

`usage` 在上游未返回可解析统计时可省略。

### `llm-chat`

请求：

```json
{
  "userId": "client-correlation-id",
  "message": "今天有点累",
  "context": [
    { "role": "assistant", "content": "发生什么了？" },
    { "role": "user", "content": "工作很多。" }
  ]
}
```

`message` 最多 4000 字。`context` 可省略，最多 20 项、总计最多 12000 字；只允许 `user` 和 `assistant`，客户端不能注入 `system` 消息。成功响应与 `llm-daily-summary` 相同。

### `llm-comic-script`

请求：

```json
{
  "userId": "client-correlation-id",
  "summary": "今天完成了重要功能，也出去跑了步。",
  "events": ["完成功能", "跑步三公里"]
}
```

`summary` 必填、最多 8000 字；`events` 可省略，数量和长度限制同每日总结。

成功响应：

```json
{
  "success": true,
  "theme": "充实的一天",
  "panels": [
    {
      "index": 0,
      "description": "清晨开始工作",
      "prompt": "A cute character starting work, anime style, warm colors",
      "dialogue": "开始吧！"
    }
  ]
}
```

实际 `panels` 始终恰好 5 项，`index` 为 0-4。上例只展示单项字段形状。

### `llm-memory-correction`

请求：

```json
{
  "userId": "client-correlation-id",
  "originalSummary": "今天跑了五公里。",
  "userCorrection": "实际是三公里。"
}
```

`originalSummary` 最多 8000 字，`userCorrection` 最多 4000 字。成功响应与 `llm-daily-summary` 相同。

## 本地验证

本地测试不会访问 DeepSeek，也不需要真实密钥：

```bash
node --check cloud-functions/llm-common.js
node --check cloud-functions/llm-daily-summary.js
node --check cloud-functions/llm-chat.js
node --check cloud-functions/llm-comic-script.js
node --check cloud-functions/llm-memory-correction.js
node --test cloud-functions/tests/*.test.js
```

测试覆盖输入边界、缺少密钥、成功契约、usage 字段转换、漫画结构、客户端 system 角色拒绝、当前 DeepSeek 路径及 429 可重试语义。它不证明 API Key 有效、AGC 云函数已部署、访问控制已启用或客户端到云端链路可用。

## 真实环境验收清单

1. 在 AGC 为每个函数配置相同的运行时、超时和所需环境变量；部署包包含共享文件。
2. 启用平台侧身份/访问控制、调用配额和告警，不使用客户端 `userId` 代替认证。
3. 分别调用四个 LLM 函数的成功、无效输入、上游限流和超时路径，确认日志不包含密钥或完整私人文本。
4. 用 `CloudFunctionService.ets` 做真机/模拟器联调；T5 需识别 `success:false`，并按 `error.retryable` 决定是否提示重试。
5. 记录实际函数版本、区域、调用身份、测试时间和脱敏结果；完成前状态只能写“待联调”。
