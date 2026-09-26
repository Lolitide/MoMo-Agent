# Momo 并行开发协作板

## 当前执行目标：真实后端可交付调试版（覆盖下方原排期）

用户于 2026-09-26 明确：交付后必须能调用已部署后端并取得真实返回，**不能用本地 Mock/stub 结果充当验收**。本轮不追求正式上线级别的账户、权限、配额与密钥治理；保留已有安全实现即可，不让这些扩展任务阻塞真实链路。下方旧排期和 T1–T4 审查记录仅作背景，以本节为当前验收标准。

最短交付路径：

1. T0：游客能稳定进入应用，同时保留登录选择界面。
2. T1/T2：把现有六个云函数实际部署到交付使用的 AGC 项目，配置可用的 DeepSeek/Ark 密钥、模型和共享文件；至少分别从真实云端验证总结、聊天、记忆纠正、漫画脚本、图片生成与状态查询，记录函数版本及脱敏结果。只有本地单元测试不算完成。
3. T5：游客路径直接调用上述真实云函数；移除 CloudDB 用户档案/客户端配额对 AI 调用的硬阻断。以 `success`/错误码判定结果，失败就显示真实错误或重试入口，不能悄悄回退为 Mock 成功。图片生成成功后显示真实返回的图片；可做本地缓存，但缓存不能替代后端返回。日记/漫画的云端持久化若不是本次验收要求，可暂缓；若验收要求跨设备看到记录，则必须另完成 CloudDB 联调，不能声称本地缓存就是后端。
4. T4/T6：用交付对象实际会使用的安装方式与设备运行应用，走完整真实链路：游客进入 → 总结 → 漫画脚本 → 图片生成/显示，并抽测聊天与纠正。保存脱敏请求 ID、函数版本、测试时间和错误结果。若交付的是可安装 HAP，仍需完成有效签名；模拟器接受 unsigned HAP 不能替代这一项。

可暂缓：CloudDB 多设备同步、游客升级迁移、离线冲突、完整配额/权限体系、T7 仓库治理。不要再花时间把安全加固当成本轮主线，但也不要把 Mock 结果称为真实后端。2026-09-26 已取得六个函数的真实 AGC 部署/调用证据；这仍不等于应用端端到端验收。

给 T5 窗口的新指令（替代下方旧 T5 指令）：

```text
当前目标是 Momo 真实后端可交付调试版。先读 /Users/kaylnlu/Kalyn/Momo/PROJECT_COORDINATION.md 顶部当前执行目标并检查 git status。保持游客登录和登录选择界面，包名 com.example.momo。使游客能调用已部署的六个云函数；重点跑通总结→漫画脚本→图片生成/真实图片显示，并验证聊天、记忆纠正。绕过 CloudDB 档案和客户端配额对 AI 调用的硬阻断，但不要用 Mock/stub 伪装成功。所有失败按云函数 success/error 显示可见状态；图片成功直接使用真实 imageUrl，必要时缓存。按原 T5 文件归属工作，跨 T3 文件先协调。构建后在交付环境做真实云端冒烟测试，更新 T5 进度区，写明函数版本、结果与阻塞；本地单元测试不能代替真实联调。不要提交或推送。
```

更新时间：2026-09-26。所有窗口共用同一工作区 `/Users/kaylnlu/Kalyn/Momo`，不需要互相复制代码。应用包名统一为 `com.example.momo`；不要再使用旧包名。本轮先完成实现和验证，不提交、不推送、不创建 PR。

## 当前事实与优先顺序

- 已完成：登录页跳转目标从不存在的 `pages/Index` 改为 `pages/MainPage`，本地 debug HAP 构建通过。应用 `AppScope/app.json5`、现有签名 Profile 已是 `com.example.momo`；文字文档中的旧包名已统一。
- 正在别的窗口处理：游客登录和登录选择界面。保持「默认可游客进入，同时保留选择界面」；本板其他任务不得重做登录流程。
- 当前状态：六个云函数已在目标 AGC 项目部署并分别取得真实成功返回；T5 已接线，首页/漫画页无真实结果时不再冒充静态漫画。客户端最新源码可构建，但最新 HAP 尚未完成匹配签名和设备端整链路验收。工作区已有更早的 AGC debug Profile 签名包，不能代表当前最新源码。
- 当前优先级以顶部“真实后端可交付调试版”为准：最新源码签名与 T6 设备端真实验收优先；T3 的高级同步和 T7 暂缓。
- “代码实现完成”不等于“云端部署成功”。需要 AGC 权限、服务开通、密钥或真机时，记录为外部阻塞，绝不填写假成功。

## 协作规则（每个窗口都遵守）

1. 开始前读本文件、`git status --short` 和所负责文件。工作区已有大量未提交改动，保留现有修改，不覆盖、不重置。每个任务只修改自己的“写入范围”；跨范围接口需求先写在本任务进度区，并通知用户/其他窗口。
2. 所有窗口只更新下方自己任务的“进度区”，更新前重新读取该区，使用精确补丁。不要改别人的任务描述或进度；不要把真实 API Key、证书密码、令牌、完整 `agconnect-services.json` 内容写入文档或日志。
3. 接口名、请求/响应字段、错误语义的变更，先在自己的进度区写清楚。T5 集成窗口以这些记录为准；T1 负责 `cloud-functions/functions.json` 总清单，T2 只向 T1 提出其条目需求，避免同时改同一文件。
4. 完成时在本任务进度区写：状态（未开始/进行中/待联调/阻塞/完成）、改动文件、验证命令与结果、真实环境仍需什么、给下游的接口信息。若被阻塞，写明已尝试的安全检查与所需输入。
5. 不要替其他窗口顺手修代码。发现问题写在自己的进度区；若需要改共享文件，先交给该文件的任务负责人。全部窗口不提交、不推送、不删除证书或用户文件。

## 任务看板

| ID | 任务 | 当前状态 | 写入范围（其他窗口只读） | 依赖 |
| --- | --- | --- | --- | --- |
| T0 | 游客登录与选择界面 | 进行中，已有窗口负责 | `entry/src/main/ets/service/auth/`、`LoginPage.ets`、`EntryAbility.ets`、登录相关页面 | 无 |
| T1 | LLM 云函数与函数清单 | 已部署且 AGC 真实调用成功 | `cloud-functions/llm-*.js`、`cloud-functions/functions.json`、`cloud-functions/README.md`、仅该目录内的测试 | 设备端整链路仍待 T6 |
| T2 | 图片生成与状态查询后端 | 已部署且 AGC 真实调用成功 | `cloud-functions/image-*.js`、仅该目录内的图片测试 | 设备端图片展示仍待 T6 |
| T3 | 云数据/存储/游客安全边界 | 本地部分完成，高级同步暂缓 | `objecttypes.json`、`CloudDBModels.ets`、`CloudDBService.ets`、`CloudStorageService.ets`、`DataSyncService.ets`、对应测试 | 本轮真实 AI 返回不依赖 CloudDB |
| T4 | 包名、AGC 配置与签名可安装性 | 已有旧版 AGC debug 签名包；最新源码待重签/验收 | `AppScope/app.json5`、`build-profile.json5`、`entry/build-profile.json5`、`entry/src/main/resources/rawfile/agconnect-services.json`（仅重新下载/替换，不手改密钥）、签名相关文档 | 最新源码可安装交付仍需有效签名 |
| T5 | 客户端 AI/漫画集成 | 本地构建完成，待设备端验收 | `AIServiceCloud.ets`、`CloudFunctionService.ets`、`CloudServiceManager.ets`、`Repositories.ets`、漫画/记忆页面、对应测试 | 最新签名包，T0 游客流程 |
| T6 | 端到端验证与缺陷归档 | 未开始 | 新建测试/验收记录文档；原则上不直接改功能代码 | T0–T5 基本完成 |
| T7 | 仓库卫生与交付 | 暂缓 | `.gitignore`、文档、密钥轮换/历史处理方案；提交/PR 须另获用户指令 | T6 后 |

当前工作区有未提交改动（含 T0/T3/T5 范围）；任务负责人必须在原改动上增量工作，不能假设文件是干净的。`backend/` 为空；这不代表必须新建第二套 HTTP 后端，现阶段主路径是 Cloud Foundation Kit + `cloud-functions/`。如果发现主路径不可行，先报告证据，不自行切换架构。

## 可直接复制到其他窗口的任务

### T0（已有窗口，不要重复开）

```text
你负责 Momo 的游客登录与登录选择界面。先读 /Users/kaylnlu/Kalyn/Momo/PROJECT_COORDINATION.md 中 T0 区，包名统一 com.example.momo。保持游客可进入且保留选择界面，不要删除其他登录选项。登录页跳转 MainPage 的修正已完成，请在现有未提交改动上继续。只改 T0 写入范围；说明游客身份是否具备真实云端认证凭据，给 T3/T5 清楚的接口约定。完成后更新该文档 T0 进度区。不要提交或推送。
```

### T1（可立即开窗口）

```text
你负责 Momo 的 LLM 云函数后端。先读 /Users/kaylnlu/Kalyn/Momo/PROJECT_COORDINATION.md 和 git status，包名统一 com.example.momo，只改 T1 写入范围。以 entry/src/main/ets/service/cloud/CloudFunctionService.ets 的调用为契约，补齐 llm-chat、llm-memory-correction，核查并修好 llm-daily-summary、llm-comic-script 的输入校验、真实上游调用、失败语义、超时和安全边界。不要相信客户端任意 userId 能证明身份；无认证时明确限制云端个人数据操作。你独占 cloud-functions/functions.json，需把 T2 报告的 image-get-status 条目合入总清单，并让 README 与实际环境变量一致。增加可运行的本地契约/错误测试；无密钥时不要伪称真实云端已通。完成后更新本文件 T1 进度区，写出请求/响应字段、测试结果和部署阻塞。不要碰 T0/T2/T3/T5 文件，不提交不推送。
```

### T2（可立即开窗口）

```text
你负责 Momo 的图片云函数后端。先读 /Users/kaylnlu/Kalyn/Momo/PROJECT_COORDINATION.md 和 git status，包名统一 com.example.momo，只改 T2 写入范围。核查 image-generate.js 与 AIServiceCloud.ets 的生成→状态轮询协议，补齐 image-get-status.js，确保 taskId、status、imageUrl、错误状态、超时有真实一致的语义；不要返回“成功 + 假 taskId”造成无意义轮询。弄清上游即梦/Ark 的同步或异步模式并据此实现，缺少凭据时可做本地 mock 测试但生产路径必须显式报错。图片不应默认泄露私人内容；检查上传/URL 权限。不要编辑 functions.json，所需清单条目和环境变量写到本文件 T2 进度区交给 T1。增加本地测试，更新进度区和给 T5 的字段契约。不提交不推送。
```

### T3（可立即开窗口）

```text
你负责 Momo 的云数据库、存储和游客数据安全边界。先读 /Users/kaylnlu/Kalyn/Momo/PROJECT_COORDINATION.md 和 git status，包名统一 com.example.momo，只改 T3 写入范围。核对 objecttypes.json、CloudDBModels/CloudDBService/DataSyncService/CloudStorageService 的 schema、CRUD、冲突/离线同步、桶名和权限。重点证明游客身份是否满足 Creator 权限；若没有真实云身份，采用安全的本地游客数据策略并明确后续迁移/升级路径，不要把 ACL 改成 World 写入或只凭客户端 userId 隔离用户。保留已有未提交改动。增加可运行的本地测试或最小验证；真云端受 AGC/凭据阻塞则如实记录。跨 T0/T5 的接口请求写在本文件 T3 进度区，不直接改对方文件。不提交不推送。
```

### T4（可立即开窗口）

```text
你负责 Momo 的包名、AGC 客户端配置与签名可安装性。先读 /Users/kaylnlu/Kalyn/Momo/PROJECT_COORDINATION.md 和 git status，只改 T4 写入范围。目标包名固定 com.example.momo。核对 AppScope bundleName、签名 Profile、AGC 配置所选客户端；现有 agconnect-services.json 可能含历史应用条目，不能手改其中密钥字段，需通过 AGC 正确下载匹配 com.example.momo 的配置。检查 build-profile.json5 的空 signingConfigs，配置安全可复现的本地签名方式，避免提交密码/私钥。分别验证能构建和能安装/启动；无设备或材料时准确写明阻塞。不要安装/删除其他包名应用，不要输出敏感内容全文。更新本文件 T4 进度区，不提交不推送。
```

### T5（建议等 T1–T3 写明接口后开）

```text
你负责 Momo 的客户端 AI/漫画链路集成。先读 /Users/kaylnlu/Kalyn/Momo/PROJECT_COORDINATION.md 及 T1–T3 进度区和 git status，包名统一 com.example.momo，只改 T5 写入范围。把六个云函数的调用与真实请求/响应和错误状态对齐；漫画生成后使用实际图片 URL/本地缓存而不是静态 comic_1，占位图只在明确的失败或尚未生成状态使用。保证重复点击、重试、超时、离线和游客路径状态正确，不丢已有数据。不要自行修改登录、云函数或云 DB 实现，接口不符先记录并通知负责人。增加必要测试并完成本地构建；更新本文件 T5 进度区。不要提交不推送。
```

### T6（最后开）

```text
你负责 Momo 端到端验收，不承担其他任务的功能代码。先读 /Users/kaylnlu/Kalyn/Momo/PROJECT_COORDINATION.md 全部进度和 git status，包名统一 com.example.momo。检查完整游客流程、日记/记忆保存与重启同步、LLM 总结/聊天/修正、漫画脚本/图片生成与展示、异常/离线、权限隔离、签名安装启动。运行可用的构建和测试；区分本地 mock、已部署云端、真机验证三个层级，不将前者写成后者。创建简短验收记录，按 T0–T5 归属列出缺陷并更新本文件 T6 进度区。不要替其他窗口直接改代码，不提交不推送。
```

### T7（暂不开）

```text
你负责 Momo 的仓库卫生和最终交付，须在用户明确同意后启动。先读 /Users/kaylnlu/Kalyn/Momo/PROJECT_COORDINATION.md。检查证书、签名文件和 AGC 配置的追踪/忽略状态及泄露风险，拟定轮换和历史处理方案；核对文档与实际能力、构建产物和测试结论。不得擅自删除证书、改写 Git 历史、提交、推送或创建 PR。先更新本文件 T7 进度区说明建议和风险，待用户授权后再做不可逆操作。
```

## 各窗口进度区

### T0 进度

状态：进行中（由已有窗口维护）。

### T1 进度

状态：待联调（本地实现与契约测试完成；尚未部署 AGC、未使用真实 DeepSeek 密钥、未验证真实调用身份）。

改动文件：

- `cloud-functions/llm-common.js`：统一 DeepSeek `/chat/completions` 调用、45 秒默认上游超时、1 MiB 响应上限、HTTP/结束原因错误映射、usage 字段转换和安全日志。
- `cloud-functions/llm-chat.js`、`cloud-functions/llm-memory-correction.js`：补齐客户端已调用但原来缺失的两个函数。
- `cloud-functions/llm-daily-summary.js`、`cloud-functions/llm-comic-script.js`：补齐输入数量/长度限制、配置缺失错误、真实上游调用失败语义；漫画启用 JSON 输出并严格校验 5 个连续分镜。
- `cloud-functions/functions.json`、`cloud-functions/README.md`：登记四个 LLM 函数，并按 T2 最终报告合入 `image-get-status` 及两项图片函数的完整环境变量、共享文件和资源要求；记录部署要求、身份边界及请求/响应契约。
- `cloud-functions/tests/llm-contract.test.js`：新增不访问真实上游的契约和错误测试，并校验六个客户端函数的总清单。

验证：

- `jq . cloud-functions/functions.json`：通过。
- `node --check cloud-functions/llm-*.js` 与测试文件：通过（本机 Node.js v24.19.0；代码仅使用 Node.js 18 支持的语法/API）。
- `node --test cloud-functions/tests/*.test.js cloud-functions/image-functions.test.js`：21/21 通过，其中 T1 测试 11/11、T2 图片测试 10/10；T1 总清单用例同时核对 T2 报告的图片资源与环境变量。
- `git diff --check -- cloud-functions`：通过。
- 本机 `DEEPSEEK_API_KEY` 未配置，所以未执行真实 DeepSeek 请求，也未声称云端可用。

给 T5 的 LLM 契约：

- `llm-daily-summary` 请求 `{ userId, events: string[], mood }`；`events` 1-50 项。成功 `{ success:true, content, usage? }`。
- `llm-chat` 请求 `{ userId, message, context?: Array<{role:'user'|'assistant',content}> }`；拒绝客户端 `system` 角色。成功同上。
- `llm-comic-script` 请求 `{ userId, summary, events?: string[] }`；成功 `{ success:true, theme, panels }`，`panels` 恰好 5 项且 `index` 为 0-4。
- `llm-memory-correction` 请求 `{ userId, originalSummary, userCorrection }`；成功同每日总结。
- 四个函数失败统一为 `{ success:false, error:{ code, message, retryable } }`；T5 不应把失败对象强转为成功响应，应按 `retryable` 决定重试提示。完整长度限制和错误码见 `cloud-functions/README.md`。

安全边界与真实环境待办：客户端 `userId` 只做兼容字段，不证明身份、不发送给 DeepSeek，也不授权任何个人数据读写。四个 LLM 函数保持无状态；必须等 T0 给出真实认证身份约定，并在 AGC 配置调用访问控制、配额/告警、`DEEPSEEK_API_KEY` 后做部署和真机联调。每个 LLM 部署包需同时包含入口文件和 `llm-common.js`。

T2 清单合并：已按 T2 进度区最终报告完成。`image-generate` 为 Node.js 18、1024 MB、120 秒，登记 `ARK_API_KEY`、`ARK_IMAGE_MODEL`、`ARK_IMAGE_URL_HOST_SUFFIXES`、`IMAGE_TASK_SECRET` 及可选超时/TTL；新增 `image-get-status`（Node.js 18、256 MB、10 秒、`IMAGE_TASK_SECRET`）。两个图片部署包都需包含 `image-task-token.js` 并使用完全相同的共享密钥。

### T2 进度

状态：待联调（图片生成/状态查询代码与本地契约测试完成；未部署，未使用真实 Ark 凭据调用）。

- 改动文件：`cloud-functions/image-generate.js`、`image-get-status.js`、`image-task-token.js`、`image-functions.test.js`。未修改 T1 独占的 `functions.json`/`README.md`，也未修改 T5 客户端文件。
- 上游模式：方舟官方 `POST /api/v3/images/generations` 在默认非流式模式中等待图片生成完成并直接返回 `data[].url`，不是可用任务 ID 再轮询的异步接口；URL 官方说明在生成后 24 小时内有效。现实现不再伪造上游任务：成功后生成 AES-256-GCM 加密、带 15 分钟默认 TTL 的无状态回执作为 `taskId`；`image-get-status` 校验/解密该回执并返回已经完成的同一 URL，不向 Ark 做无意义轮询。回执是短期 bearer credential，不得写日志或跨用户分享。
- 生成请求仍为 `{ userId, prompt, style?, size? }`；`userId` 只做兼容输入和长度校验，不能证明身份。成功响应为 `{ success:true, taskId, status:'success', imageUrl, taskExpiresAt }`。失败响应为 `{ success:false, status:'failed', errorCode, error, retryable }`，失败时不返回假 `taskId`。
- 状态请求为 `{ taskId }`。有效回执响应 `{ success:true, taskId, status:'success', progress:100, imageUrl, taskExpiresAt }`；无效、被篡改、过期或缺配置时响应 `{ success:false, taskId, status:'failed', errorCode, error, retryable:false }`。错误码包括 `INVALID_ARGUMENT`、`CONFIGURATION_ERROR`、`UPSTREAM_TIMEOUT`、`UPSTREAM_NETWORK_ERROR`、`UPSTREAM_HTTP_ERROR`、`UPSTREAM_RESPONSE_ERROR`、`INVALID_TASK_ID`、`TASK_EXPIRED`、`INTERNAL_ERROR`。
- 给 T5：生成成功已经有最终 `imageUrl`，应直接使用，不必轮询；为兼容现有 `AIServiceCloud.waitForImage`，状态函数会立即返回相同 URL。必须先检查 `success/status`，失败对象没有 `taskId`，不得继续轮询。Ark 上游默认超时 50 秒、可配范围 5-55 秒，低于客户端现有 60 秒云函数超时，保证后端先返回结构化失败；若 T5 延长客户端图片调用超时，服务端上限也必须成对评估，避免客户端先断开后上游仍计费。Ark URL 是短期外部 HTTPS bearer URL，应立即用普通 HTTPS 流程下载到应用缓存或经可信后端转存到用户私有桶；不能把它冒充 `momo-images` 私有桶 URL。`taskExpiresAt` 是状态回执失效时间，不是 Ark URL 的 24 小时失效时间。
- URL/隐私边界：不记录 prompt、完整 userId、图片 URL 或 taskId；仅接受 HTTPS、公共地址且域名匹配 `ARK_IMAGE_URL_HOST_SUFFIXES` 的上游 URL；任务回执加密并防篡改；上游错误详情不原样返回。图片提示词与结果仍会传给 Ark，且函数代码无法从客户端 `userId` 推导真实身份；部署时必须用 AGC 调用权限限制、可信身份、配额和告警防止越权与费用滥用。
- 给 T1 的 `functions.json` 要求：保留 `image-generate`（`image-generate.handler`、Node.js 18、1024 MB、120 秒），环境变量改为 `ARK_API_KEY`、`ARK_IMAGE_MODEL`、`ARK_IMAGE_URL_HOST_SUFFIXES`、`IMAGE_TASK_SECRET`，可选 `ARK_IMAGE_TIMEOUT_MS`、`IMAGE_TASK_TTL_MS`；新增 `image-get-status`（`image-get-status.handler`、Node.js 18、建议 256 MB、10 秒），环境变量 `IMAGE_TASK_SECRET`。两个函数必须配置完全相同、至少 32 字符的 `IMAGE_TASK_SECRET`，部署包都要包含 `image-task-token.js`。`ARK_IMAGE_MODEL` 不再使用代码内可能过期的默认模型；`ARK_IMAGE_URL_HOST_SUFFIXES` 应按真实响应域名最小化配置（官方示例域名可从 `volces.com` 起步验证）。
- 验证：`node --check` 三个实现文件通过；`node --test cloud-functions/image-functions.test.js` 10/10 通过，覆盖同步成功、缺配置/参数、超时、429 重试语义、不安全 URL、回执篡改/过期、缺状态密钥和超长输入；`git diff --check` 通过。测试只使用本地 stub，没有消耗 Ark 配额。
- 真实联调所需：有效 `ARK_API_KEY`、当前账号可用的 `ARK_IMAGE_MODEL`/推理接入点、两个已部署函数及共享密钥、实际生成 URL 域名确认、AGC 鉴权与调用配额；随后用真实图片验证 24 小时 URL、客户端及时下载/私有存储和真机展示。完成这些前不能声明云端链路已通。

### T3 进度

状态：待联调（本地安全边界与契约检查已完成；真实 Cloud Foundation 身份、AGC schema/桶权限和真机仍阻塞）。

- 改动文件：`entry/src/main/ets/service/cloud/CloudDBService.ets`、`CloudStorageService.ets`、`DataSyncService.ets`、`tests/t3_contract_test.mjs`；保留并复核了工作区已有的 `CloudDBModels.ets` Cloud Foundation 模型改动。`objecttypes.json` 无需放宽权限或改字段。
- Schema/ACL：五个客户端模型与 `objecttypes.json` 字段、单主键一致；`World`、`Authenticated` 均无权限，`Creator`/`Administrator` 才有 Read/Upsert/Delete。严禁为游客改成 World 写入。官方端侧文档要求部署后存在 `AppScope/resources/rawfile/schema.json`，当前仓库没有该生成文件，须在 AGC 部署 `MomoDataZone` 后由工具下载，不能手工伪造。
- 游客策略：当前 `DeviceAuthProvider` 只生成本地 userId 和 mock token，`HuaweiAccountProvider` 也尚未注册 Cloud Foundation AuthProvider；两者均不能证明 Creator 身份。`DataSyncService.initialize()` 因此默认 `LOCAL_ONLY`，把记忆按本地用户隔离保存到应用沙箱 Preferences，不初始化云同步；损坏快照不覆盖。只有认证链路确认后才能调用 `activateVerifiedCloudSync(context, verifiedUserId)`。游客升级后须经 UI 明确同意再调用 `migrateGuestMemoriesAfterConsent`；云端同 ID 记录保留、不盲目覆盖，游客快照不自动删除。
- DB 契约：所有 CRUD 先要求 `bindVerifiedUser(userId)`，再校验对象/查询 userId 与当前身份一致；查询失败抛错，不再伪装为 null/空数组；日志不输出完整用户/记录 ID。`getComicImages` 新签名为 `(userId, recordId)`。客户端配额仍不是可信的并发计费边界，T1 必须在云函数/可信服务端另做配额与身份校验。
- Storage 契约：桶名仍为 `momo-images`，仅允许 `comics/<verifiedUserId>/...`；上传源必须在 `context.cacheDir`，下载缓存写到 `image_cache/`，传输任务等待 completed/failed 后才返回；拒绝非当前私有桶 URL、目录穿越和跨用户路径。外部图片生成 URL 不能冒充本桶 URL，T5 需用普通 HTTPS 下载流程或先经可信后端写入私有桶。AGC 侧桶 ACL 不在仓库内，必须真环境确认它同样按认证用户隔离，客户端检查不能替代云端规则。
- 冲突/离线结论：游客离线数据可本地持续保存；首次升级迁移采用“云端同 ID 优先”。当前 Cloud DB 端侧 API 没有条件 upsert，已登录后的跨设备并发仍是最后写入生效，且 Repository 没有持久化离线写队列；未把它伪称为已解决。若首版要求跨设备编辑/离线补传，T5 需增加版本字段与可信云函数条件写入/队列后再联调。
- 验证：`node tests/t3_contract_test.mjs` 通过（schema、ACL、所有权守卫、游客本地模式、迁移不覆盖契约）。使用 `DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk .../hvigorw ... assembleHap --no-daemon` 已进入 ArkTS 编译，T3 文件无编译错误；最新全量构建的编译汇总仍有 2 个错误，显示的阻断点是 T3 范围外新文件 `Garden3DDemo_Standalone.ets:249`（Only UI component syntax can be written here），未修改该文件。
- 真实联调所需：T0 明确提供“已注册 Cloud Foundation AuthProvider/可取得真实访问凭据”的身份能力（不能只给 userId 或 mock token）；AGC 开通并部署 `MomoDataZone`、导入 schema、创建 `momo-images`、配置 Creator/存储权限；使用匹配 `com.example.momo` 的配置、已注册调试凭据/签名和真机验证。完成这些前只能声明本地验证，不能声明云端成功。

### T4 进度

状态：阻塞（包名/AGC 客户端核对、unsigned 构建安装启动和安全签名方案已完成；缺少 AGC 签发的有效应用证书与 `.p7b` Profile，当前并行源码也出现 T4 范围外编译错误，尚不能验证 signed HAP）。

改动文件：

- `build-profile.json5`：保留空 `signingConfigs` 作为安全仓库默认值，并注明不得在共享配置中保存密码、私钥或本机路径。
- `SIGNING_SETUP.md`：改为基于真实检查结果的签名/AGC/安装验收说明，区分 unsigned 模拟器验证与可信签名验证。
- `DEVECO_SIGNING_STEPS.md`、`entry/signatures/README.md`：去除“签名已就绪/只差运行”的错误暗示，统一指向关联注册应用自动签名流程，并标明现有材料不构成有效签名链。
- `PROJECT_COORDINATION.md`：仅更新本 T4 进度区。
- 未改 `AppScope/app.json5`、`entry/build-profile.json5`、`agconnect-services.json`：现有目标包名和 AGC 顶层所选客户端均已是 `com.example.momo`；AGC 文件含历史应用条目，但按规范未手改任何密钥或条目。

验证与结果：

- 安全解析 AGC 配置：顶层 `client.package_name`、`app_info.package_name` 均为 `com.example.momo`；`appInfos` 另含旧应用条目。只核对结构和包名，未输出或改写密钥字段。
- 签名材料审计：`entry/signatures/` 无 `.p7b`；`Momo.cer` 是 Huawei CBG Root CA 根证书，不是本应用证书。`sign/` 是本地自建 CA/自签材料且只有 Profile JSON，不能替代 AGC 签发的应用证书/Profile。
- 2026-09-26 15:47 使用 DevEco 内置 JDK、SDK、Hvigor 6.26.4 执行 debug `assembleHap`：成功；日志提示 `No signingConfig found for product default`，产物为 `entry-default-unsigned.hap`。
- 使用已连接的 Pura X View 设备执行 `hdc install entry-default-unsigned.hap`：成功；执行 `aa start -a EntryAbility -b com.example.momo -m entry`：成功；`bm dump` 显示 `appSignType: none`。这只证明模拟器接受 unsigned 包，不是 signed HAP 验收。
- 设备连接与 UDID 读取：可用，后续可用于生成调试 Profile；未把 UDID 写入文档。
- 文档修改后的复测已通过 Hvigor 配置、资源等阶段，但在 `entry/src/main/ets/pages/Garden3DDemo_Standalone.ets` 的 245、277、341 行因泛型推断/`unknown`、非 UI 语法和缺少 `cube` 资源而失败。该文件于本轮并行出现且不在 T4 写入范围，未越界修改；此前成功的 unsigned HAP 不能作为当前源码候选。
- `git diff --check`（T4 文档与 `build-profile.json5`）：通过。

真实环境仍需：

1. 在 DevEco `Project Structure > Signing Configs` 中使用有权访问 AGC 应用 `com.example.momo` 的团队，启用 HarmonyOS 自动签名并关联注册应用，取得相互匹配的本机 `.p12`、AGC 应用证书 `.cer` 和绑定该包名/调试设备的 `.p7b`。
2. 由对应功能任务修复上述并行 ArkTS 编译错误后，重新构建并用 `hap-sign-tool verify-app` 核对证书链、Profile 包名，再安装 signed HAP；设备 `appSignType` 必须不再为 `none`。
3. 在具备真实华为账号环境的设备上验证 Account Kit。当前未声称真机、签名包或华为账号登录已通过。

安全/交付提醒：仓库已经追踪 `sign/` 下的历史 `.p12`，`entry/signatures/` 也尚未被忽略；本轮未删除、移动或提交这些文件。忽略规则、历史泄露审计与密钥轮换交给 T7，在用户另行授权后处理。

给下游：应用标识继续固定为 `com.example.momo`；没有客户端接口变更。T5/T6 不得把当前 unsigned 模拟器成功写成签名、Account Kit 或 AGC 真环境通过。

### T5 进度

状态：真实云函数已部署并通过 AGC 云端冒烟测试；客户端 ArkTS 构建通过。尚未完成应用端对 AGC 的真机/模拟器端到端调用验收，签名包仍由 T4 处理。

- 2026-09-26 已在 AGC 项目 `MoMo`（项目 ID `101653523865100350`、应用 ID `6917617207632124463`）更新 `llm-daily-summary`、`llm-comic-script`、`image-generate`，创建 `llm-chat`、`llm-memory-correction`、`image-get-status`，共 6 个函数。每个 ZIP 都包含入口和对应共享模块；新建函数使用事件调用。现有 DeepSeek/Ark 密钥只在同项目函数环境变量中复用，没有写入仓库。
- AGC 测试入口的真实请求结果：每日总结、漫画脚本、聊天、记忆修正均返回 `success:true`；图片生成调用 Ark 成功并返回 `success:true` 与真实 `imageUrl`；状态函数使用该真实回执返回相同图片 URL 与 `success:true`，对无效 taskId 返回预期的 `INVALID_TASK_ID`。客户端主路径直接使用图片生成返回的 URL、不依赖状态轮询。
- 客户端主路径已改为显式触发真实云函数：今日记忆菜单可生成真实总结、修正弹窗可提交真实纠正；每日漫画菜单可生成真实 5 格脚本并并行生成 5 张真实图片 URL。失败会显示错误，不再伪装为 Mock 成功。游客认证仍是本地身份，云数据库/云存储未作为 AI 调用前置条件；目前生成结果仅在本次进程内缓存，外部图片 URL 有有效期。
- 16:44 进一步移除了首页漫画卡片和今日漫画页首次打开时的静态漫画冒充：无真实生成结果时显示“云端漫画尚未生成”，并提供生成/前往今日状态入口；真实结果仍从进程缓存展示。纠正总结后同步更新仓库缓存，后续漫画使用修正后的文本。
- 验证：`node --test` 22/22 通过；DevEco 内置 SDK/JDK + Hvigor `assembleHap --no-daemon` 构建成功。当前产物仍是 `entry-default-unsigned.hap`，不代表可提交的已签名安装包。尚未宣称应用端云函数调用和 5 张漫画在设备上完整展示成功。
- 剩余最短路径：T4 完成与最新源码匹配的有效签名；在设备上用游客模式打开今日记忆并点“生成云端总结”，随后打开每日漫画点“生成云端漫画”，确认 5 张图片显示。最新 unsigned HAP 在已有模拟器上安装报 `install sign info inconsistent`；尝试 `hdc uninstall -k com.example.momo` 保留数据后仍不能安装 unsigned，随后已安装回工作区现有 `MoMo-PuraXView-debug-signed.hap`。该 signed 文件早于最新客户端改动，`verify-app` 成功，提取的 Profile 由 `app_gallery` 签发且绑定 `com.example.momo`/当前 App ID，安装成功；但设备 `bm dump` 仍报告 `appSignType:none`，需 T4 核对原因，不能把它算作最终签名验收。模拟器当前由另一配置窗口测试登录，T5 未继续抢占设备。若 AGC SDK 调用失败，记录设备日志中的函数名和错误码后针对性修复。长期持久化、云数据库 ACL、配额与密钥治理暂不作为本次快速交付阻断项。

### T6 进度

状态：进行中；云函数层真实冒烟测试通过，设备端最新包的游客→总结→漫画整链路尚未验收，不能标记完成。

- 2026-09-26 设备端漫画生成报 `401:205525007:verify signature failed`。已核对当前安装的 `com.example.momo` 指纹为 `15:DB:57:F7:BD:62:85:07:EE:1E:5D:D7:D9:1D:94:C6:FD:A9:C1:7D:50:21:42:90:55:C8:9C:70:C5:09:46:16`，与现有 signed HAP 的开发证书指纹相同；AGC 项目设置中原有的两个指纹均不是这个值（其中 `MomoDebug` 为另一个调试证书）。用户确认后，已将该指纹添加到 AGC 的 `com.example.momo` 应用设置，刷新页面后仍可见。初步判定旧报错为端侧签名未登记导致网关拒绝；仍须用当前已安装包重试云函数调用并核验日志，再对最新源码制作签名包。尚未宣称完整端到端验收通过。

- 云端证据（AGC 中国默认区域，2026-09-26）：`image-generate` 最后修改 16:20:15、`llm-daily-summary` 16:20:51、`llm-comic-script` 16:21:24、`llm-memory-correction` 16:23:52、`llm-chat` 16:24:45、`image-get-status` 16:25:34；六个测试分别得到 `success:true`（状态查询使用真实图片回执），未把本地 stub 当验收。
- 本地证据：最新源码 `assembleHap` 成功，`node --test` 22/22，通过 `git diff --check`。最新 `entry-default-unsigned.hap` 仅供编译检查，不是有效交付签名包。
- 待实测：使用最新源码的 AGC 签名包安装/启动；游客进入；今日状态点“生成云端总结”并看到新内容；每日漫画点“生成云端漫画”并看到 5 张真实图片；修正/聊天各抽测一次；记录设备日志中的云函数名、失败码和时间。当前共享模拟器正被另一配置窗口测试登录，本窗口不抢占。之前设备日志的华为账号 `1001502002 The application is not authorized` 只涉及华为账号入口，不能推断游客云函数失败或成功。

### T7 进度

状态：暂缓。
