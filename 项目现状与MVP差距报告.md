# 默默 MoMo · 项目现状与 MVP 差距报告

> 报告日期：2026-09-27
> 对应本轮变更：新增演示模式、归档根目录过程报告；随后追加「记忆花园改版为气泡花园」（见第 10 节）
> 对照基准：`MVP与复赛材料清单.md`（v2.0，2026-09）
> 结论口径：所有「已完成」均给出**代码位置级证据**；无法用本机验证的一律标注「未验证」，不做推断。

---

## 0. 一句话结论

演示模式已落地并可离线运行（设置页开关、内存隔离、退出即清除），游客态无需登录即可调用真实云端 AI；与 MVP 清单相比，**AI 生成链路已真实打通，但「纠正 → 长期记忆 → 花园」的闭环、系统数据权限流程、Agent 抽象三层仍是主要缺口**。演示现场可完整走通「记一笔 → 生成总结 → 生成漫画」，但**不能说**「纠正后花园与档案随之变化」。

---

## 1. 演示模式：设计、实现与验收

### 1.1 目标与达成

| 你的要求 | 落地方式 | 状态 |
| --- | --- | --- |
| 仅在演示模式下展示 mock 数据 | 6 个仓库全部提供 `activateDemo()/deactivateDemo()`，只在 `DemoModeService.isDemo()` 为真时读演示数据 | ✅ |
| 数据更利于演示 | 14 条长期记忆（跨 14 天）、7 条今日事件、9 条「默默的理解」、5 页漫画 + 5 段分镜、预置档案与状态 | ✅ |
| 游客模式下可用 AI 等联网功能 | `AIServiceCloud` 不要求登录（云函数把 `userId` 当关联字段）；本轮补齐降级与提示 | ✅ |
| 演示数据不长期保存、是分离的 | 纯内存态：不写 Preferences、不写云端；退出即丢弃，进入前数据原样还原 | ✅ |

### 1.2 三层数据隔离

```text
┌──────────────────────────────────────────────────────────────┐
│ 演示内存区（DemoModeService 管理，仅存在于进程内存）            │
│   MemoryRepository.memories      = DemoMockData.buildMemories()│
│   EventRepository.cachedDaily    = DemoMockData.buildDailyMemory()│
│   ComicRepository.generatedComic = DemoMockData.buildComic()   │
│   UserRepository.cachedUser      = DemoMockData.buildUser()    │
│   ↑ 不进 Preferences、不进 CloudDB、冷启动不恢复                │
└──────────────────────────────────────────────────────────────┘
              ↑ activateDemo() 快照 / deactivateDemo() 还原
┌──────────────────────────────────────────────────────────────┐
│ 游客本机区（真实数据，键名 momo_guest_data_v1）                 │
│   演示期间被快照挂起，退出后原样恢复；演示期间零写入             │
└──────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────┐
│ 云端区（CloudDB / CloudStorage）                               │
│   游客无 Creator 身份 → 默认不启用（t3 契约锁定）；演示态不触碰  │
└──────────────────────────────────────────────────────────────┘
```

### 1.3 进入 / 退出时序

`DemoModeService.enable()`（任一步失败即逆序回滚，开关保持关闭）：

1. `MemoryRepository.activateDemo()` —— 快照真实数组引用，`userId=''`、`isCloudEnabled=false`，灌入演示种子
2. `EventRepository.activateDemo()` —— 快照当日缓存与云开关，改用预制 L1
3. `ComicRepository.activateDemo()` —— 快照真实生成结果，预制漫画同时填入 `generatedComic` 与 `generatedScript`
4. `DataSyncService.suspendGuestPersistence()` —— 第二道保险
5. `active = true` → 单次 `notify()` 广播

`DemoModeService.disable()`：逆序还原全部仓库 → `active = false` → 单次广播（先还原后广播，页面不会读到半状态）。

### 1.4 AI 降级矩阵

| 场景 | 演示模式（默认关闭演示时） | 演示模式（点「演示·生成总结/漫画」） | 普通模式 |
| --- | --- | --- | --- |
| 今日总结 | 秒回预制文案，不联网 | 调云端；失败 → 预制文案 + toast | 调云端；失败 → toast + 预制文案 |
| 今日漫画 | 秒回预制 5 页 | 调云端；失败 → 预制漫画 + toast | 调云端；失败 → toast + 预制漫画 |
| 记忆纠正 | 秒回预制纠正结果 | 同总结 | 调云端；失败 → toast + 预制结果 |
| 反馈提交 | 预制确认文案 | 同左 | 原文案 |

**关键约定**：降级一定伴随 toast 提示，绝不静默伪装成功——这是 `tests/demo_ai_contract_test.mjs` 的断言之一。

### 1.5 现场操作脚本

**3 分钟版**：登录页 →「游客登录」→ 档案三步（或直接完成）→ 首页看默默与今日卡片 → 设置页开「演示模式」（二次确认）→ 记忆花园三模式（花园/大纲/树）→ 今日状态（7 事件 + 9 洞察）→ 今日漫画（5 页）→ 点「演示·生成漫画」证明游客也能调真实 AI → 退出演示模式，指出数据已清除。

**5 分钟版**：在 3 分钟版基础上追加——「+」记一笔新事件 → 进花园看到新节点 → 今日状态点「演示·生成总结」→ 漫画页点「演示·生成漫画」→ 纠正浮层提交一条纠正 → 退出演示模式，强调真实数据未被污染。

### 1.6 人工验收用例（**需真机，本机无法替代**）

| # | 场景 | 预期 | 验证状态 |
| --- | --- | --- | --- |
| 1 | 游客登录 → 设置 → 开演示模式 | 2 秒内生效；首页/花园/大纲/树/搜索/今日状态/漫画全部有数据 | ⏳ 待真机 |
| 2 | 演示态下「+」记一笔 | 花园新增节点；生成总结秒回且无网络错误 | ⏳ 待真机 |
| 3 | 演示态下点「演示·生成漫画」 | 有网：真实云端漫画；无网：保留演示漫画 + toast，无错误页 | ⏳ 待真机 |
| 4 | 退出演示模式 | 花园/今日状态/漫画立即回到进入前数据；演示期间新增项消失 | ⏳ 待真机 |
| 5 | 退出后杀进程重启 | 真实数据完好；演示模式为关闭态 | ⏳ 待真机 |
| 6 | 全程不开演示模式 | 与改动前逐屏一致（回归） | ⏳ 待真机 |
| 7 | 演示态下改档案/开关 | `momo_onboarding_v1`、`ai_config` 无写入 | ⏳ 待真机 |
| 8 | 游客态（非演示）调真实 AI | 与改动前一致，仍可调用 | ⏳ 待真机 |

> 静态契约已覆盖 1/3/4/5/7 的**结构性前提**（零持久化、零上云、守卫齐全），但交互结果必须在真机确认。

---

## 2. 可验证的现状（代码位置级证据）

| 事实 | 证据 |
| --- | --- |
| 游客入口存在 | `pages/LoginPage.ets:249`「游客登录」→ `handleDeviceLogin()` |
| 游客身份是设备 ID，无云身份 | `service/auth/DeviceAuthProvider.ets:193` `u_${hash}_${Date.now()}` |
| 游客数据默认只存本机 | `service/DataSyncService.ets:120-125` 走 `enableLocalGuestPersistence` + `LOCAL_ONLY` |
| 游客快照键名与哈希 | `service/DataSyncService.ets:76` `momo_guest_data_v1`；键 `memories_<fnv1a>` |
| AI 不要求登录 | `service/ai/AIServiceCloud.ets:54-77` 只调 `authService.initialize()` 与云函数 `initialize()`，无 `isLoggedIn` 前置 |
| 云函数不把 userId 当鉴权 | `cloud-functions/llm-common.js:69-73`「untrusted correlation field」 |
| 六个云函数名与客户端常量一致 | `service/cloud/CloudFunctionService.ets:25-30` ↔ `cloud-functions/*.js` 的 `exports.handler`（由 `tests/demo_ai_contract_test.mjs` 锁定） |
| 「默默的理解」是硬编码，不经 LLM | `mock/MockData.ets:53-62`、`mock/DemoMockData.ets:110-120`；`insights` 无任何生成路径 |
| 今日漫画页只显示真生成结果 | `pages/B_DailyComic.ets:67` `getGeneratedToday() \|\| new Comic()` |
| L2 记忆有本机持久化 | `service/DataSyncService.ets:241-257` 写 `momo_guest_data_v1` |
| L1 每日总结**无**本机持久化 | 仅 `EventRepository.cachedDailyMemory` 内存缓存；云路径依赖 CloudDB（默认关闭） |
| 花园编辑改的是 title/tags/summary | `pages/A_Garden.ets:977,987-988`；未触碰 `content` |
| 冷启动必回真实态 | `pages/MainPage.ets` `aboutToAppear` 调 `DemoModeService.disable()`（幂等） |

---

## 3. 与《MVP与复赛材料清单》§4.2 的逐项差距

| # | MVP 要求 | 状态 | 客户端证据 | 缺口 / 补齐成本 |
| --- | --- | --- | --- | --- |
| 1 | **真实 LLM 接入** | ✅ 已完成 | `DemoAIGateway` → `AIServiceCloud` → `CloudFunctionService` → `llm-daily-summary` / `llm-memory-correction` / `llm-chat`；`llm-common.js` 用 `DEEPSEEK_API_KEY` | 依赖 AGC 环境变量配好；本机无法验证真实返回 |
| 2 | **Observation 最小实现**（记一笔 + 备忘录 / 日历） | 🟡 部分 | 「记一笔」可用：`pages/MainPage.ets:170-182` 写 `MemoryRepository`；系统数据代码已写：`service/system/SystemDataService.ets:104` 读日历、`:183` 读提醒 | 权限申请只在启动时做一次（`:52-53`），UI 开关不触发；用户拒绝后无再次申请入口。补齐成本：中（设置页开关 → 权限申请 → 失败态提示） |
| 3 | **Memory Agent（L1）** | 🟡 部分 | `EventRepository.generateDailySummary()` → `AIServiceDailySummary` 云端生成 ✓；落库 ✗；「默默的理解」8/9 条为硬编码 ✗ | LLM 只产出**一段总结文本**，未产出结构化洞察。补齐成本：中（让云函数返回 JSON 洞察，或客户端二次解析） |
| 4 | **Expression（漫画）** | ✅ 已完成 | `llm-comic-script` 出分镜 → `image-generate` 出图 → `ComicRepository` 装配 `Comic.pages` | **无模板贴图降级**：当前失败时退到占位图漫画，而非「LLM 文案 + 模板拼装」。补齐成本：低-中 |
| 5 | **Reflection** | 🟡 部分 | `llm-memory-correction` 可用，结果写回 L1 总结：`pages/B_TodayMemory.ets:108-121` | **未修改 L2、未影响花园**；与 MVP 的验收口径「纠正后花园与档案随之变化」**不符**。补齐成本：高（需云函数返回结构化 MemoryUpdate + 客户端落到 `MemoryRepository`） |
| 6 | **数据持久化** | 🟡 部分 | L2 记忆本机落盘 ✓（`DataSyncService`）；演示模式内存态 ✓ | L1 每日总结不落盘；云端 L0/L1/L2 同步被 `t3_contract_test.mjs:93-94` 主动锁死为「未验证游客不启用」——这是**设计决策而非缺陷** |
| 7 | **演示模式** | ✅ 已完成 | 本轮实现，见第 1 节 | 无 |

**图例**：✅ 已完成 / 🟡 部分完成 / ❌ 未开始

### 3.1 一句话验收的达成度

> MVP 的验收口径：「评委现场输入一句话，默默当天生成真实总结与漫画，纠正后花园与档案随之变化。」

| 环节 | 达成 |
| --- | --- |
| 现场输入一句话 | ✅ 可用（「+」记一笔） |
| 生成真实总结 | ✅ 可用（依赖网络与 AGC 密钥） |
| 生成真实漫画 | ✅ 可用（依赖即梦 AI 配额） |
| 纠正后花园与档案随之变化 | ❌ **未达成**，纠正只改 L1 总结 |

**演示口径建议**：讲「观察 → 理解 → 表达 → 用户纠正」的前四步，把「纠正影响长期记忆与花园」明确说成路线图而非现状，避免答辩现场被追问后失分。

---

## 4. 文档与代码的偏差（本次核实发现）

这些偏差说明**删除过程报告是必要的**——它们描述的是已经不存在的代码。下表保留偏差记录，避免后续重复踩坑。

| # | 被删文档的说法 | 代码实际 | 处理 |
| --- | --- | --- | --- |
| 1 | （**本报告首版曾误判，此处更正**）提交信息 `2cc0943` 写「修改包名为 `com.agent.momo`」 | 该提交的**内容**里 `AppScope/app.json5` 仍是 `com.example.momo`，与提交信息不符。真机 `bm dump` 与 `agconnect-services.json` 的 `package_name` 也都确认是 `com.example.momo` | ✅ README 保持原包名 `com.example.momo` |
| 2 | README「后续任务路线」称 AI 能力留给后续轮次 | 真实 AI 闭环已接入 | ✅ 已修正 README |
| 3 | `3D_GARDEN_*` / `HOW_TO_VIEW_3D_GARDEN.md` 称 3D 花园「已完成」 | `MemoryNode3D.ets`、`Garden3DDemo*.ets` 在代码中**已不存在** | 🗄 归档；本报告登记 |
| 4 | `AI服务架构文档.md` / `快速开始.md` 描述旧版 `AIService` + `MockProvider` | 仅被未注册的 `B_AITest*` 引用，属死代码 | 🗄 归档；本报告列入技术债 |
| 5 | 多份文档提「配置 `rawfile/ai_config.json`」 | 该文件从未存在（`resources/rawfile/` 只有 `agconnect-services.json`），已被 `.gitignore` 排除 | 🗄 归档；本报告列入技术债 |
| 6 | `客户端测试指南.md` 称已实现「Mock 模式 AI 服务」 | 真实链路已接入，该描述已过时 | 🗄 归档 |
| 7 | 旧花园地图的节点标记与锚点间距不匹配（标称「节点地图」，实际必然重叠） | 已改版为**气泡花园**（按类型分簇 + 蜂巢落位 + 焦点档才显示日期） | ✅ 已修，见第 10 节 |

---

## 5. 运维知识保全

以下信息原本散落在被归档的报告里，此处集中保留。

### 5.1 签名与分发包名

| 检查项 | 值 |
| --- | --- |
| 应用包名 | `com.example.momo`（`AppScope/app.json5`；真机 `bm dump -a` 与 `agconnect-services.json` 的 `package_name` 一致） |
| AGC App ID / Client ID | `6917617207632124463`（`entry/src/main/module.json5` metadata） |
| 仓库签名配置 | `build-profile.json5` 的 `signingConfigs` 指向 `C:\Users\x2027\.ohos\config\default_MoMo-Agent-lkn_*.{cer,p12,p7b}` |
| 密钥别名 | `debugKey`，算法 `SHA256withECDSA` |
| 不进仓库的材料 | `sign/` 全部内容、`entry/signatures/*.p12|p7b|json`、`cloud-functions/character-config.json`（见 `.gitignore`） |

> 注意：`build-profile.json5` 在本轮开始前就已是「修改未提交」状态（含本机签名材料路径与口令）。本次未改动该文件。

### 5.2 CloudDB 对象类型导入

1. AGC 控制台 → 云数据库 → 对象类型 → **导入 `objecttypes.json`**（仓库根目录，`tests/t3_contract_test.mjs` 依赖它）。
2. 五个对象类型：`UserProfile` / `DailyRecord` / `ComicImage` / `UserFeedback` / `LongTermMemory`。
3. 权限契约：`World` 与 `Authenticated` 均无权限，仅 `Creator` / `Administrator` 有 `Read/Upsert/Delete`（由 t3 测试锁定，**不得**为了游客放宽为 World 写入）。
4. 端侧还要求部署后存在 `AppScope/resources/rawfile/schema.json`，当前仓库没有该文件——须在 AGC 部署数据区后由工具下载，**不能手工伪造**。

### 5.3 云函数部署

需要在 AGC 项目中部署 6 个云函数，并在环境变量中配置密钥：

| 函数 | 用途 | 必需环境变量 |
| --- | --- | --- |
| `llm-chat` | 通用对话 | `DEEPSEEK_API_KEY` |
| `llm-daily-summary` | 每日总结 | `DEEPSEEK_API_KEY` |
| `llm-comic-script` | 漫画分镜 | `DEEPSEEK_API_KEY`（+ `character-config.json`） |
| `llm-memory-correction` | 记忆纠正 | `DEEPSEEK_API_KEY` |
| `image-generate` | 文生图（即梦 AI） | Ark 相关密钥 |
| `image-get-status` | 出图状态查询 | 同上 |

可选：`DEEPSEEK_MODEL`、`DEEPSEEK_TIMEOUT_MS`（1000–55000）。密钥**只放云函数环境变量**，不写入仓库。

### 5.4 公开分发的四条注意事项

1. 只跑本地：保持 `signingConfigs` 为空，先用游客登录跑通本地流程。
2. 共享后端：让使用者自行编译源码即可复用同一 AGC 项目；分发已签名 HAP 与「让源码可编译」是两件事。
3. 密钥只在云端：`agconnect-services.json` 属客户端配置可随工程分发；服务密钥不可。
4. 不可共享：`.p12` 私钥、签名口令、与本机调试设备绑定的 `.p7b`。

---

## 6. 技术债登记（本次按约定未动）

| # | 项目 | 位置 | 影响 | 建议 |
| --- | --- | --- | --- | --- |
| 1 | 5 个非路由页面 | `B_AITest.ets`、`B_AITest_V2.ets`、`AuthTestPage.ets`、`EntryAbility_WithHuaweiLogin.ets`；均未注册在 `main_pages.json` | 干扰阅读，拖慢编译 | 决赛前删除或移入 `archive/` |
| 2 | 旧版 AI 模块死代码 | `service/ai/AIService.ets`、`MockProvider.ets`、`MockProviderModels.ets`、`AutoConfigManager`；`ai_config.json` 从未存在 | 误导后续开发（文档说它可配） | 与第 1 项一起清理 |
| 3 | 昵称不一致 | `MockData.buildUser()` 的昵称在 README 写「MoMo」，`User.name` 默认值也是 `MoMo`，但游客实际显示为 `用户<id 前6位>`（`DeviceAuthProvider.ets:57`） | 演示时昵称像随机串 | 演示模式已用「小雨」规避；普通模式建议给游客一个友好默认名 |
| 4 | 花园默认选中硬编码 | `pages/A_Garden.ets:151` `getById('m4')` | 演示种子必须保证 `m4` 存在且为重要回忆（已在 `DemoMockData` 中满足） | 改为「按重要度取第一条」更稳 |
| 5 | 洞察与总结分属两源 | `insights` 硬编码、`summary` 由 LLM 生成 | 「默默的理解」名不副实 | 让 `llm-daily-summary` 一并返回结构化洞察 |
| 6 | 权限申请只做一次 | `SystemDataService.ets:52-53` 在启动时申请 | 用户拒绝后无法重试，系统数据路径永久失效 | 设置页开关接入真实权限申请与失败态 |
| 7 | 根目录静态资产 | `Comic.png`(1.85MB)、`character.png`(448KB)、`momo_profile.json`、`_shots/`、`test_3d_garden.sh`、`build_install_simulator.sh` | 按约定本次保留；`Comic.png` 全仓库无引用，`_shots/` 已被 `.gitignore` | 后续可直接删除（`Comic.png` 已确认无引用） |

---

## 7. 本次变更清单

### 7.1 新增（5 个文件）

| 文件 | 行数 | 说明 |
| --- | --- | --- |
| `entry/src/main/ets/mock/DemoMockData.ets` | 373 | 演示数据工厂：14 条记忆（相对日期）、7 事件、9 洞察、漫画 + 分镜、预制 AI 文案、演示身份与状态 |
| `entry/src/main/ets/service/DemoModeService.ets` | 123 | 演示模式唯一开关：事务式 enable/disable + 逆序回滚 + 单点广播；零持久化、零联网 |
| `entry/src/main/ets/service/ai/DemoAIGateway.ets` | 149 | AI 分流与降级网关：演示态秒回预制内容，真实态走云端并在失败时降级 + toast |
| `tests/demo_mode_contract_test.mjs` | 197 | 演示模式静态契约测试（9 组断言，含演示种子不变量） |
| `tests/demo_ai_contract_test.mjs` | 130 | AI 通路静态契约测试（5 组断言） |

### 7.2 修改（8 个文件）

| 文件 | 改动要点 |
| --- | --- |
| `entry/src/main/ets/repository/Repositories.ets` | 六个仓库的演示态支持：Memory/Event/Comic/User 快照还原；Tree/Companion 委托查询；Memory 写操作演示态短路上云；新增 `setGeneratedComic()` / `getGeneratedScript()` |
| `entry/src/main/ets/service/DataSyncService.ets` | 新增 `persistenceSuspended` + `suspend/resumeGuestPersistence()`；`scheduleGuestPersist()` 与 `persistGuestLoop()` 双重守卫。**未改动** `initialize()` 默认分支 |
| `entry/src/main/ets/pages/A_Settings.ets` | 新增「演示模式」区块：开关（含二次确认）、重置演示数据（仅演示态显示）、身份与联网状态只读说明 |
| `entry/src/main/ets/pages/MainPage.ets` | 冷启动强制回真实态；标题加「演示 · 」前缀；菜单项加「演示·」前缀；首次打卡改走网关并回填仓库 |
| `entry/src/main/ets/pages/B_TodayMemory.ets` | AI 调用改走 `DemoAIGateway`；菜单/提示/纠正浮层按模式切换文案 |
| `entry/src/main/ets/pages/B_DailyComic.ets` | 同上；演示态不再要求「先生成云端总结」 |
| `entry/src/main/ets/service/Services.ets` | 新增 `DemoUIState`（演示态文案集中管理） |
| `.gitignore` | 新增 `/.md-reports-backup/` |

### 7.3 归档（37 份文档，非破坏性）

移入本机 `MoMo/.md-reports-backup/`（该目录不进仓库，可随时还原）：

- 根目录 36 份：3D 花园 3 份、AI 集成/架构 3 份、编译修复 3 份、华为云方案 6 份、华为账号登录 5 份、签名/部署/分发 4 份、过程总结与日志 8 份、其他 4 份
- `entry/src/main/ets/service/ai/README.md` 1 份（描述已成死代码的旧版 `AIService`）

**根目录文档从 39 份收敛到 3 份**：`README.md`、`MVP与复赛材料清单.md`、本报告。

### 7.4 同步修正的引用

- `README.md`：删除指向已归档 `PUBLIC_REPOSITORY_SETUP.md` 的悬空链接，其 4 条要点内联为「共享后端与签名说明」；更新当前状态、工程结构、Mock 数据清单（新增演示数据表）、后续路线状态列、新增测试章节
- `MVP与复赛材料清单.md`：§4.2 第 7 项与 §5 D9 标注演示模式已完成

---

## 8. 验收记录

### 8.1 已执行的验证

| 验证项 | 命令 | 结果 |
| --- | --- | --- |
| 云数据/ACL/游客边界契约 | `node tests/t3_contract_test.mjs` | ✅ `T3 contract checks passed` |
| 演示模式契约 | `node tests/demo_mode_contract_test.mjs` | ✅ `演示模式契约检查通过` |
| AI 通路契约 | `node tests/demo_ai_contract_test.mjs` | ✅ `AI 通路契约检查通过` |
| 全新编译（删除 build/ 后） | `hvigorw assembleHap --mode module -p product=default --no-daemon` | ✅ `BUILD SUCCESSFUL in 33 s`，`CompileArkTS` 耗时 18.9 s（真实重编译，非缓存） |
| 产物 | `entry/build/default/outputs/default/` | ✅ `entry-default-signed.hap` 12,688,162 B；`entry-default-unsigned.hap` 12,641,765 B |

编译仅有既有警告，无新增错误：HDS 相关 API 需 6.1.0(23) 而 `compatibleSdkVersion` 为 6.0.2(22)（8 条，改动前已存在）、`animateTo` / `pushUrl` / `getContext` 废弃提示。

### 8.2 未验证项（如实标注）

| 项目 | 原因 |
| --- | --- |
| 真机交互验收（第 1.6 节 8 条） | 本机无连接设备，无法替代 |
| 真实云端 AI 返回 | 依赖 AGC 项目密钥与配额，本机不具备 |
| Hero 图卡片与共享元素转场的演示态表现 | 属视觉确认，需真机 |
| 演示模式反复开关的长期稳定性 | 需真机长时间操作 |

### 8.3 复现构建的命令

```powershell
$env:DEVECO_SDK_HOME="<DevEco>/sdk"          # 注意是 DevEco Studio\sdk，不是 sdk\system-image
$env:JAVA_HOME="<DevEco>/jbr"                 # 否则 PackageHap 报 spawn java ENOENT
$env:PATH="$env:JAVA_HOME\bin;$env:PATH"
& "<DevEco>/tools/hvigor/bin/hvigorw.bat" assembleHap --mode module -p product=default --no-daemon
```

---

## 9. 假设与遗留风险

1. **默认选中节点被硬编码**：气泡花园与大纲/树视图都会 `getById('m4')` 作为默认选中项，依赖演示种子里 `m4` 存在且为重要回忆。已在 `DemoMockData` 中满足，并**已由契约测试第 9 组断言自动守护**（校验 14 条种子、`m4` 存在且为 `IMPORTANT`）——若后续调整演示记忆，测试会失败而不是静默演示出问题。彻底修法见第 6 节第 4 项。
2. **演示模式无跨重启记忆**：按「不长期保存」的要求刻意如此。若演示中误关 App，需重新开启演示模式（数据会重置为初始 14 条）。
3. **`build-profile.json5` 含本机签名口令**：本轮开始前即为「修改未提交」状态，本次未改动。提交前请确认该文件是否应入库。
4. **文档声明与代码的一致性没有自动守护**：README 与 MVP 清单中标记为 ✅/🟡 的结论来自本次人工核对，后续代码变动不会自动使它们失效。

---

## 10. 追加变更：记忆花园改版为「气泡花园」

### 10.1 问题诊断（改版前的实测证据）

改版不是因为「不好看」这种主观判断，而是三个可以量化的问题：

| # | 问题 | 证据 |
| --- | --- | --- |
| 1 | 单个节点标记远宽于节点间距，**必然重叠** | 旧 `GardenNodeMarker` 整体宽 **110vp**；而 `A_Garden.nodePosOf` 的锚点最小间距为 15% 屏宽（360vp 屏上约 **54vp**） |
| 2 | 节点内含 4 层内容，文字互相压盖 | 圆（64vp）+ 重要度圆点（5 颗，`position({x:28,y:2})` 已溢出圆外）+ 日期胶囊 + 标题（宽 108vp、`Ellipsis` 截断） |
| 3 | 第 9 条记忆起落到兜底公式，形成第二簇重叠 | `nodePosOf` 对 `index >= 8` 走 `x = 14 + (index*29)%76` |

### 10.2 改版方案

按**记忆类型**分簇，同一类记忆作为花瓣汇聚在花心周围；每条花瓣是纯圆气泡；越靠屏幕中心的气泡越大，进入焦点档即在圆内显示日期（`MM.DD`）。

**最终布局模型**（经历三轮真机修正后定型）：画布按行（band）推进 → 每行并排放若干簇的矩形分组 → 每块自上而下为「花心段（`CENTER_D + MIN_GAP`）→ 花瓣段（每行 2 个、行距 `PITCH_Y`）」→ 同一 band 内所有簇的花瓣行共享同一组 y 基线 → 相邻簇间距按两者**实际半宽**分别计算 → 最后 `resolveCollisions()` 全局收敛兜底。

同一 band 内共享 y 基线是关键：任意两颗花瓣要么同行（x 间距由列距保证）、要么不同行（y 间距由行距保证），从几何上消掉了「矮簇花瓣落进高簇花瓣列间隙」这一整类冲突。

布局算法参考 [LVGL 复刻 watchOS 气泡网格](https://lvgl.io/blog/tutorial-recreating-apple-watch-bubble-component) 的错落行思想；未采用其拖拽/惯性/边界压缩/邻近吸附（需要自维护 16ms 定时器，与全仓 `animateTo` 触发式动效体系不一致）。

### 10.3 关键设计取舍

| 取舍 | 决定 | 理由 |
| --- | --- | --- |
| 标签 | **只有焦点气泡在圆内显示日期**，其余纯图标 | 360vp 屏宽放 5 簇 14 瓣，每个都带标签必然碰撞。日期信息不丢——焦点档可见，完整信息在底部详情浮层 |
| 重要度 | 由「5 颗圆点」改为**描边粗细**（`importance >= 4` 加粗） | 圆点原本已溢出圆外，是拥挤来源之一 |
| 碰撞检测 | **不做** | 当前常量下相邻簇花瓣最小间隙约 14vp（已验算）。这是设计约束，改常量后需重新验算 |
| 视图归属 | 新增 `GardenMode.BUBBLE = 3` 作为默认，`GARDEN = 0` 数值保留 | 枚举数值参与 `AppStorage('gardenMode')` 与 `GardenController` 传递，改动会导致菜单高亮错位 |
| 动效 | 入场错峰绽放 + 点按收缩变暗，全部 `animateTo + Curve.EaseOut` | 与全仓其余 6 处过渡一致，不新增动效体系 |

### 10.4 变更清单

**新增（3 个文件）**

| 文件 | 说明 |
| --- | --- |
| `entry/src/main/ets/utils/BubbleLayout.ets` | 分簇 + 统一网格/矩形分组落位 + 焦点缩放 + `resolveCollisions()` 全局收敛；尺寸集中于常量区 |
| `entry/src/main/ets/components/MemoryBubble.ets` | 单个气泡：纯圆、尺寸按 `d` 派生、圆内仅图标与焦点日期 |
| `tests/bubble_layout_contract_test.mjs` | 契约测试：布局签名与常量、防重叠结构化保证、纯圆约束、旧实现零残留、枚举兼容、入口可达 |

**修改（6 个文件）**

| 文件 | 改动 |
| --- | --- |
| `pages/A_Garden.ets` | 新增 `gardenHeader()` / `bubbleView()` / `recomputeBubbleLayout()` / `onAreaChange` 取真实尺寸；删除 `gardenView()` 与 `nodePosOf()`（约 100 行）；默认视图改为 `BUBBLE` |
| `model/Models.ets` | 新增 `GardenMode.BUBBLE = 3`；`GardenState.currentMode` 默认改为 `BUBBLE` |
| `components/ModeMenu.ets` | 「花园模式」→「气泡花园」，指向 `GardenMode.BUBBLE` |
| `pages/MainPage.ets` | 标题栏菜单两处「花园模式」→「气泡花园」 |
| `mock/MockData.ets`、`mock/DemoMockData.ets` | 删除无消费者的 `buildGardenNodes()` 与 `GardenNodeItem` import |
| `utils/TreeLayout.ets`、`components/MemoryTreeGraph.ets` | 修正头注释里「依赖 GardenNodeMarker 尺寸常量」的错误描述（两者本来没有依赖关系） |

**删除（1 个文件 + 2 个类型）**：`components/GardenNodeMarker.ets`、`model/Models.ets` 的 `GardenNodeItem`、两处 `buildGardenNodes()`。

### 10.5 真机联调记录（本次用 DevEco 虚拟机 + hdc 实测）

**环境**：DevEco Studio 自带 hdc 3.2.0e 连接 `127.0.0.1:5555` 虚拟机（1320×2856 px，≈ 377×816 vp）。
截图用 `hdc shell snapshot_display`，点击用 `hdc shell uinput -T -d/-u`（`-m` 单击在本机常被识别为 Scroll 手势而 reject，**必须用显式 down/up**）。

**实测推翻了 4 处我原本的静态判断**——这些都是只有真机才能暴露的：

| # | 现象 | 根因 | 修法 |
| --- | --- | --- | --- |
| 1 | 花心被压进顶部玻璃卡头部里，顶行花瓣被遮 | 纵向锚点按「屏高比例」定位，没考虑头部卡占据 92–220vp | 改为「距顶部绝对偏移」：`HEADER_BOTTOM + ROW1_OFFSET` |
| 2 | 相邻簇的花瓣互相重叠 | 蜂巢几何算错：`PITCH_X = 33` 配 3 列，两颗 52vp 的圆水平间距只有 33vp | 间距约束一律按**最大**直径 + `MIN_GAP` 校验；最终列距 60 |
| 3 | 改对后仍有重叠：高簇的最后一排花瓣压到下一行花心 | 花心与花瓣共享纵向区间，band 推进没预留花心高度 | 花心**独占**一段纵向空间（`CENTER_D + MIN_GAP`），band 高度含花心段 |
| 4 | 8 个气泡被推散成一条对角线 | `COL_PITCH_IDEAL = 56`，而两半径 + 间隙 = `2×26 + 5 = 57`，**差 1vp** 触发 `resolveCollisions` 链式挤推 | 列距 60，留出 `MIN_GAP` 余量 |

**外加 2 个纯渲染层问题**（布局数据本身是对的，肉眼看却是错的）：

| # | 现象 | 根因 | 修法 |
| --- | --- | --- | --- |
| 5 | 演示态下头部显示 14 条、花瓣也是演示数据，但花心仍写「2 条 / 1 条」（旧值） | `ForEach` 的 key 只用了 `c.type`，簇大小变化时 ArkUI 复用旧组件、文本被冻结 | key 并入数量与坐标 |
| 6 | 同样场景下 `this.memories` 仍是旧数组 | 页面可能先于 `repoListener` 的 `setState` 渲染（刚开演示模式就切到花园），`recomputeBubbleLayout()` 读到过期数组 | 改为**直接读 `MemoryRepository`**，以仓库为唯一数据源 |

确认方式：在 `layout()` 里临时打一行 `Logger.info`，实测输出
`layout in=14 centers=5 slots=14 counts=[4,3,2,2,3]` —— 布局数据完全正确，从而把问题定位到渲染层的 key 复用。定位后已移除该日志。

**一个方法论教训**：修复后再看缩放截图，我一度以为「重要回忆」的一颗花瓣压住了「目标」花心，连续三轮调整算法都没解决。最后改为在**真实代码路径**里加运行时自检（遍历所有气泡与花心，打印最小间隙），实测输出
`SELFCHECK slots=14 worstGap=10.0 petal(99,413)<->petal(159,413)` —— 真实最小间隙 10vp，**从头到尾就没有重叠**，是 544px 宽的预览图把相邻两颗误看成了一颗压住另一颗。
诊断代码定位后已移除。结论：这类几何问题应当以运行时数值为准，不要靠肉眼读缩放截图下判断。

### 10.6 编译期踩坑记录（供后续参考）

ArkTS 的三条限制在本次改版中真实触发，均已修复：

1. `Stack` **没有** `justifyContent`，只有 `alignContent`。
2. `ForEach` 的 `keyGenerator` **不能写 `this.xxx` 或复杂表达式**——必须预先算好 key 存成字段，回调里只返回 `item.keygen`。
3. `interface` 作为 `ForEach` 的项类型时被判定为「类型不能当值使用」，改 `class` 解决。
4. 本机签名材料与包名：`build-profile.json5` 的 `signingConfigs` 已指向 DevEco 自动生成的 `C:\Users\x2027\.ohos\config\default_MoMo-Agent-lkn_*.{cer,p12,p7b}`，`hdc install -r` 可直接安装，无需手工配签名。

### 10.7 验收记录

| 验证项 | 结果 |
| --- | --- |
| `tests/bubble_layout_contract_test.mjs` | ✅ 通过 |
| `tests/t3_contract_test.mjs`、`demo_mode`、`demo_ai` | ✅ 全部继续通过（无回归） |
| 蜂窝排布验证脚本（簇内 1–15 个节点） | ✅ 主圆两两 ≥ 8vp 不重叠、花心不被覆盖 |
| 全新编译（`entry/build` 删除后） | ✅ `BUILD SUCCESSFUL`，`CompileArkTS` 24–36 s（真实重编译，非缓存） |
| **真机安装启动** | ✅ `hdc install -r` 成功，游客登录 → 档案 → 主页全程可用 |
| **真机气泡花园（普通模式 8 条）** | ✅ 4 簇按类型分明、主圆显示图标 + 日期、可自由纵向滚动 |
| **真机点主圆** | ✅ 点 09.21 弹出正确详情（「第一次拒绝了临时加会」） |
| **真机演示模式（14 条）** | ✅ 头部 14 条、图例 5/3/4/2 与各簇实际节点数一致 |
| **真机方形阴影修复** | ✅ 圆外为柔和圆环光晕，四角不再出现方形边缘 |
| **真机视图切换** | ✅ 标题栏菜单显示「气泡花园 / 大纲模式 / 记忆树」，切大纲正常（14 条日期倒序） |
| 截图留档 | `_shots/bubble_*.jpeg`、`_shots/garden_*.jpeg`（约 40 张，含每个中间版本的对照） |

**仍未验证**：入场绽放动画的观感（静态截图看不出）、点按反馈手感、平板/折叠屏等其它形态、超长会话下的布局稳定性、簇内节点数超过 6 个时小圆点的实际观感（当前演示数据最大 4 个，需手动补数据才能复现）。布局常量已全部集中在 `BubbleLayoutUtil` 常量区，可直接整体缩放。

### 10.8 第三轮改版：按用户草图重做（4 簇 / 纯色标记 / 自由滚动 / 修方形阴影）

用户提供了两张手绘草图，并给出明确要求。据此做了本轮重做，**推翻了前两轮的若干决定**：

| 要求 | 落地 |
| --- | --- |
| 5 个标签圆圈改成 4 个 | `TYPE_ORDER` 只保留 生活/学习/目标/兴趣 4 类 |
| 标签只按颜色标记，不显示文字与数字 | 花心改为 **Ø22 纯色实心圆**（原来是带类型名与数量的白底圆） |
| 橙=生活、蓝=学习、红=目标、绿=兴趣 | 重映射 `MemoryTypeUtil` 的 base 主色（原为 生活绿/学习蓝/兴趣紫/目标橙/重要回忆粉红） |
| 重要回忆仅作为标签出现在一条记忆里 | **数据层改动**：`IMPORTANT` 从类型降为 `tags` 里的标签 + `importance 5`；`DataSyncService` 增加旧数据迁移 |
| 强化生长感；没展示完的用更小的同色实心圆代替 | 簇内**花心独占顶端 + 逐排向下铺开**；超过 6 个改用 Ø20 同色实心小圆点 |
| 不再按离焦点远近决定大小/内容 | 删除焦点缩放与 `focused` 标记；主圆统一 Ø64，**统一显示图标 + `MM.DD`** |
| 像记忆树一样能自由滑动 | 气泡区改为可滚动；内容高度由布局的 `contentHeight` 给出，不再强求一屏放下 |
| 图标与背景对比度更高 | 配色改为「base 主色 → 派生的深色图标 + 浅色底圆」，对比度关系恒定 |
| 修 bug：点击圆形图标时阴影是方形的 | ArkUI 的 `shadow` 按**外接矩形**绘制、不跟随 `borderRadius`；把底圆放进一层 `clip(true)` 的内嵌 `Stack`，阴影被裁进圆内后退化为圆环柔光 |

**本轮真机又抓到 4 个只有实测才暴露的问题**：

| # | 现象 | 根因 | 修法 |
| --- | --- | --- | --- |
| 3-1 | 一簇里两颗主圆叠了 31vp | 偏移表把两个主圆放在相邻的**半排**上（y 只差 33vp 而直径 64vp） | 主圆一律落在整排（排距 = `MAIN_D`） |
| 3-2 | 花心被同色气泡盖住 | 花瓣同时排在花心上下两侧，花心落在同一行位上 | 花心**独占顶端**，花瓣只向下生长 |
| 3-3 | 气泡整体下移约 285vp，位置全错 | 给气泡区的 `Scroll` 加了 `expandSafeArea`，改变了内容坐标原点 | 去掉该属性，顶部留白改由 `CLUSTER_TOP0` 承担（已在 README 记录为「勿回退」） |
| 3-4 | 一簇 5 个主圆时最小间距 -15.8vp | 用了斜向排列 `(±0.5, 0.5×PITCH_Y)`，横向 36 + 纵向 32 的斜距不足 | 改公式化分排，每排最多 3 列（360vp 屏放不下第 4 列，会被 `clampInside` 压到同一位置） |

定位手段同样是**运行时日志**而非读图：`console.info('[GARDEN] w=377 centers=4 slots=8 items=8 h=946')` 一行就确认了「8 个节点都在、布局正确，只是内容高 946vp 需要滚动」。

### 10.9 第四轮改版：修掉滚动 / 裁切 / 遮挡（改用自适应网格）

用户反馈：「还是上下滚动、每个圆圈像是被裁切了、排版也不对、还出现了遮挡」。这三个现象**是同一个根因**：

> 固定 Ø64 + 一簇一行时，4 簇纵向叠加需 `4 × 300 = 1200vp`，而实际可用区域只有 **361×466vp**。

先做了布局可行性推演（而不是继续改参数）：

| 方案 | Ø64 | Ø56 | Ø48 | 结论 |
| --- | --- | --- | --- | --- |
| 一簇一行、3 列簇 | 一行只放得下 1 个簇 | 同 | 2 个簇 | 必然纵向溢出 |
| 四簇横排、每簇 1 列 | 288vp ✓ | 256 ✓ | 224 ✓ | 竖排会让每簇过高 |
| 两簇并排（3 列簇） | 超宽 83vp | 超宽 35vp | 348 ✓ | Ø48 才放得下 |

最终采用：**可用矩形切成 2×2 的 cell，簇内 3 列金字塔，直径由宽高两个约束反解** → 实测落在 **Ø49**，4 簇全部装进一屏。

| 用户反馈 | 根因 | 修法 |
| --- | --- | --- |
| 还在上下滚动 | 内容 1200vp > 可用 466vp | 去掉 `Scroll`，直径自适应 + 2×2 网格 |
| 圆圈像被裁切 | `Scroll` 视口裁掉了上下两端（`GardenHeader` 之后、`Column` 之外的圆） | 同上；并确认首排圆顶部 ≥ 头部卡下沿 |
| 排版不对 | 一簇占满整行，4 簇纵向串成一条 | 2×2 网格，每簇一个 cell |
| 出现遮挡 | 下一簇的花心落在上一簇花瓣的行位上（簇距 172vp < 簇高 ~300vp） | cell 之间留 `CELL_GAP`，且 cell 高按「花心 + 最大排数」反算 |

**顺带修掉一个用户迟早会发现的细节**：`Memory.date` 历史种子不补零（`2026.11.4` 表示 11 月 4 日），
圆内显示成 `11.4` 会被读成「11 月 4 日」还是「11 月 4 号」有歧义、和 `11.24` 并列时更易误读；
现统一补零为 `MM.DD`。

**验收**：四个契约测试通过；全新编译通过；真机确认 4 簇 2×2 一屏呈现、圆圈完整、无遮挡、不滚动；
点击主圆弹出正确详情；普通模式 8 条与演示模式 14 条均正常。契约测试新增了
「直径必须由可用矩形反解」与「bubbleView 内不得出现 Scroll」两条断言，防止回退。

### 10.10 第五轮改版：花心居中、花瓣围绕（并修方形裁切）

用户反馈两点：「没有理解花心的意思——要让代表记忆的圆圈**围绕**花心，方式如前图」；
「花瓣四周有**方形裁切**的样式问题」。

**一、花瓣围绕花心（推翻前一轮"从上方往下排"的做法）**

前一轮把花心放在 cell 顶部、花瓣往下铺，确实不是"围绕"。本轮改为**花心在 cell 正中、花瓣占它的六角邻位**。

几何上用数值推演验证，连续踩了四次坑，每次都"看起来对"：

| # | 错误的偏移表 | 实际距离 | 后果 |
| --- | --- | --- | --- |
| 1 | 列步 0.5 / 行步 0.5（直角坐标） | 水平邻 P、对角邻 0.707P | 一圈花瓣疏密不均 |
| 2 | 把 P 当"到邻位的距离"再乘 (0.5, 0.866) | 对角邻 0.866P | 斜向花瓣互叠 |
| 3 | 混用格单位与笛卡尔单位 `(0,±0.866)` 与 `(0.5,±0.866)` | 一对 0.866P、另一对 P | 仍是重叠 |
| 4 | 取满六角格的 6 个邻位 | 邻位之间 0.866P | **六角格是蜂窝格，圆填不满**，必然重叠 |

最终采用 **5 个花瓣位**（右/左/下/左上/右上）的对称构型：5 个位到花心距离全相等，
两两最小距离统一为 `0.866 × 列距`，因此列距下限是 `(直径 + 间隙) / 0.866`。
顺序上每一档都对称：2 片在左右、3 片左右下、4 片成十字、5 片补满。

花瓣位超过 5 个时，多出来的记忆用**同色小实心圆点**沿半径 2 的外圈均匀分布
（不是复用内环坐标——那会让相邻两点只差 0.5 个格单位而叠住，数值实测过）。

**二、方形裁切**

根因不是 shadow，而是我上一轮自己引入的：把描边圆画在**未裁剪**的同尺寸 `Column` 上，
它与不透明底圆的外接矩形形成方框。ArkUI 的 `border` 与 `shadow` **都按外接矩形绘制、不跟随 `borderRadius`**。
修法是把组件改为严格三层，且**描边层也必须 `clip(true)`**：
① 底圆 + clip（阴影退化为圆环柔光）→ ② 描边圆单独一层 + clip → ③ 图标与日期（宽度取圆的 88%）。

**验收**：数值上跑了 9 组场景（含 5/3/4/2、2/1/3/2、满环 6/6/6/6、9/9/2/2、单簇 4/6/10），
除"簇内超过 6 条"的溢出场景外全部零重叠；溢出场景的圆会整体缩小（包络变大），
且小圆点会落在 cell 外——该场景在 2×2 网格下无法完全避免（见技术债）。

真机日志确认布局与计算一致：`centers=(97,431) (280,431) (97,489) (280,489) d46 slots=8`，
即 **Ø46 圆、2×2 网格、簇间距 183vp**。

### 10.11 第六轮改版：花心点居中、记忆圆环绕（并彻底修掉方形裁切）

用户指出两点：(1) 仍未理解花心的意思——**要让代表记忆的圆圈围绕花心**；
(2) **花瓣四周的方形裁切样式**仍未修好。

**一、花心点与记忆圆重叠（这是我上一版理解错误的直接后果）**

上一版把「花心标记点」和「承载记忆的圆」都放在 (0,0)，两者完全重叠：
实心点盖住了圆的图标与日期（用户截图里那颗实心橙圆点就是它）。

修法：**花心只是很小的点（Ø ≈ 主圆的 16%），所有承载记忆的圆全部放在环上围绕它**。

环位几何又踩了两次坑，都是"看起来对"的坐标：

| # | 环位取法 | 相邻两点距离 | 后果 |
| --- | --- | --- | --- |
| 1 | 六角格的 6 个邻位 `(1,0) (0.5,0.866)…` | 最近邻 **0.518P** | 圆叠得很厉害 |
| 2 | 手写 6 点表（混用格单位/笛卡尔单位） | 一对 0.866P、另一对 1.0P | 仍会重叠 |

最终改为**等弧长**：半径 1、每 60° 一个位，弦长恒为 **1.0P**，列距下限回到简洁的 `直径 + 间隙`。
环位不再手写表，直接由 `cos/sin(60°×i)` 现算——**前五轮的错误全部来自手写偏移表**，这是根本性的修法改变。

**二、方形裁切（三种方案都被真机否掉）**

ArkUI 的 `shadow` 与 `border` 都按**外接矩形**绘制、不跟随 `borderRadius`：

| 方案 | 真机结果 |
| --- | --- |
| 直接给圆加 `.shadow()` | 四角出现方形阴影 |
| 外面套 `clip(true)` | 圆的直线段处仍透出**矩形栅格的边**（用户截图里那圈方形边） |
| 两层半透明同心圆模拟柔光 | 叠出**脏色描边** |

最终方案：**完全不用 shadow**，只保留「浅色底圆 + 干净描边」。Apple Watch 的图标本身就是扁平的，观感更贴近。

**验收**：真机日志确认几何精确——`cores=t0(97,376)d8 … slots=(157,376)d52 (127,428)d52 (67,428)d52 (37,376)d52 (67,324)d52 …`，
即花心点 Ø8、记忆圆 Ø52 以半径 60 环绕，簇间距约 183vp；
截图确认圆圈无脏色描边、无方形边、花瓣围绕花心点成环。

### 10.12 第七轮改版：修点击延迟与闪烁

用户反馈三点：「底下的阴影还是方形的」「从一个按钮点击到另一个按钮时两个按钮都会闪烁」「切换按钮的点击过程出现延迟和卡顿」。

**关于"方形阴影"**：把真机截图**按 4 倍最近邻放大后逐像素检查**，当前 `MemoryBubble` 与底部悬浮栏都**没有任何矩形残留**——
气泡是干净的正圆（纯色底 + 圆形描边），悬浮栏是干净的圆角胶囊。此前的三次修复（去掉 `shadow` → 去掉 `clip` 包裹
→ 去掉半透明光晕层）已经把它消掉了。若仍看到方形，需要用户提供一张该状态的截图以定位具体元素。

**点击延迟与闪烁：根因确认并已修复**。三个叠加原因：

| # | 原因 | 后果 | 修法 |
| --- | --- | --- | --- |
| 1 | `BubbleItem.keygen` 里带了**选中态** | 点任意一颗气泡 → 所有气泡的 key 都失效 → ArkUI **销毁并重建全部 14 个组件** | key 只用 `memory.id` |
| 2 | `MemoryBubble` 有 `.opacity(entered?1:0)` + `.animation()` 入场动画 | 组件一旦被重建就先渲染成透明再淡入 → **"两颗按钮一起闪"**；每颗各挂一份 `.animation()` 也拖慢响应 | 去掉透明度动画，只用 `scale` 做按压/选中反馈 |
| 3 | `selectMemory()` 调用 `recomputeBubbleLayout()` | 每次点击都重跑整轮布局 + 碰撞收敛 | 新增 `syncBubbleSelection()`；选中只更新 `@Prop selected` |

第 1 条是**最关键的一条**：选中态变化本不该影响组件标识。修复后点击是"就地更新 1 个 `@Prop`"，
而不是"整片重建 + 每颗重放淡入"。

另外顺手移除了 `MemoryBubble` 的 `order` 入参与其 `setTimeout`（入场错峰已不需要），
避免每颗气泡各挂一个定时器。

### 10.13 新增技术债

| # | 项目 | 位置 | 影响 | 建议 |
| --- | --- | --- | --- | --- |
| 8 | 簇内超过 6 条记忆时，小圆点会落到 cell 外（2×2 网格下无法完全避免） | `BubbleLayoutUtil.RING2_RADIUS` | 该簇的圆会整体缩小，小圆点可能压到相邻簇的空白区 | 记忆规模真的上来后，改为「一簇一行 + 可滚动」或按类型分屏 |
| 9 | 每朵花最多 5 片花瓣是硬约束（由屏宽与"一屏放下 4 簇"共同决定） | `BubbleLayoutUtil.SLOTS`(5 位) | 超过 5 条的记忆只能用圆点表示，看不到日期 | 放宽为「一簇一行」时可用满 8 位并放大直径 |
| 10 | `A_Garden` 仍硬编码 `getById('m4')` 作为默认高亮 | `A_Garden.aboutToAppear` | 依赖演示种子里 `m4` 存在 | 改为「按重要性/日期取第一条」，与第 6 节第 4 项同源 |
| 11 | 「重要回忆」的标签迁移只在读取时进行，未回写本机快照 | `DataSyncService.storedMemoryToMemory` | 每次启动都会重复迁移同一条旧数据（幂等，无副作用） | 若要彻底，可在迁移后主动 flush 一次游客快照 |
| 12 | `MemoryType.IMPORTANT = 4` 作为兼容值长期存在 | `model/Models.ets` | 后续容易误用为「第 5 种类型」 | 待确认无旧数据后，从枚举中移除并删除迁移代码 |
| 13 | 花瓣位的几何有四次踩坑史，且都是"看起来对"的坐标 | `BubbleLayoutUtil.SLOT_GX/SLOT_GY` | 后人凭直觉改这张表极可能重新引入重叠 | 改表后必须跑 `tests/bubble_layout_contract_test.mjs` 与数值验证脚本 |
