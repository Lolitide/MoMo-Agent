# 默默 Mo Mo

> 一只会观察、会画画、能随时随地陪伴用户的鸿蒙 AI 桌宠。

默默不是传统聊天机器人，也不是简单电子宠物。它的核心体验是一个长期陪伴循环：

```text
观察 → 理解 → 表达 → 用户反馈 → 纠正 → 积累 → 再次观察
```

默默会在用户授权范围内读取日历、待办、备忘录等信息，理解用户的生活片段；通过漫画、动作和低频互动表达陪伴；通过 L0 原始事件、L1 每日小结、L2 长期档案三级记忆逐渐理解用户，并允许用户随时查看、纠正、删除。

## 当前状态

**产品骨架 + 真实云端 AI 闭环 + 演示模式，均已可用。** 页面与导航来自第一轮 Mock UI；此后接入了华为云函数（DeepSeek 总结/纠正、即梦出图）与云数据库模型；本轮新增**演示模式**，用于比赛现场无风险演示。

- 包名：`com.example.momo`
- 版本：2.0
- 目标设备：phone
- 登录：华为账号登录 或 **游客登录**（设备 ID）；游客数据默认只存本机，AI 云函数不要求登录

### 演示模式（本机内存态，默认关闭）

入口：**设置 → 演示模式**。打开后载入一套预置演示内容（14 条长期记忆、7 条今日事件、9 条「默默的理解」、5 页今日漫画），全站标题与菜单会带「演示 ·」前缀。

- **只在演示模式展示 Mock 数据**：关闭时一切走真实数据路径，行为与接入演示模式前逐屏一致。
- **数据是分离的**：演示内容只存在于内存，绝不写入游客快照（`momo_guest_data_v1`）、档案（`momo_onboarding_v1`）、AI 配置或云端；退出演示模式时全部丢弃，进入前的数据原样还原。
- **游客照样能用 AI**：演示模式下默认秒回预制内容（不联网）；点标题栏的「演示·生成总结 / 演示·生成漫画」即可走真实云端 AI，失败时自动降级并提示，不会把现场演示卡在错误页。
- **演示记忆条数可调（设置 → 演示模式 → 演示记忆条数，仅演示态可见）**：滑杆范围 4~60，默认 14。
  用来现场"放大"花园，看记忆变多时记忆花园会变成什么样（布局的两种模式见下文「气泡花园布局」）。
  - 调大：14 条手工种子之上，按**确定性规则**补齐（id 为 `x1`、`x2`…，类型按四类轮转，日期从第 15 天往前推，每 7 条安排 1 条「重要回忆」）——同一个条数每次得到完全相同的花园，便于对比。
  - 调小：保住 m4（首屏默认高亮节点）并让四种类型各留一条，再按日期倒序补齐，不会削出"缺一朵花"的残花园。
  - **松手才生效**：拖动过程只改数字，`SliderChangeMode.End/Click` 时才重建演示记忆，否则每移动一格都要全量重排花园。
  - 条数本身也**不落盘**（`DemoModeService` 依旧零 Preferences 读写），冷启动回到默认 14。
- 与普通 Mock 的分工：普通模式兜底数据在 `mock/MockData.ets`，演示数据在 `mock/DemoMockData.ets`。

实现与验收细节见 `项目现状与MVP差距报告.md`。

## 技术栈

| 项目 | 说明 |
| --- | --- |
| 系统 | HarmonyOS NEXT |
| SDK | 6.0.2(22)，兼容目标 6.0.2(22) |
| 语言 / UI | ArkTS / ArkUI |
| 导航 | `HdsNavigation`（UIDesignKit）+ 全局 `NavPathStack`（`AppRouter`） |
| 一级导航 | `HdsTabs`（底部悬浮导航栏 + 分离式加号 miniBar） |
| 架构 | Page → Service / Repository → Mock Data，发布-订阅刷新 |

## 工程结构

```text
entry/src/main/ets/
├── pages/            # 页面
│   ├── MainPage.ets        # 应用外壳：HdsNavigation + HdsTabs + 全局浮窗
│   ├── A_Home.ets          # 一级：首页（陪伴空间）
│   ├── A_Garden.ets        # 一级：记忆花园（气泡花园 / 大纲 / 记忆树三模式）
│   ├── A_Settings.ets      # 一级：设置
│   ├── B_TodayMemory.ets   # 二级：今日状态
│   ├── B_DailyComic.ets    # 二级：今日漫画
│   ├── B_About.ets         # 二级：关于默默
│   ├── B_Search.ets        # 二级：记忆搜索
│   └── B_ComicViewer.ets   # 三级：漫画查看器
├── components/       # 复用组件（MoMoAvatar、MoMoCard、EventTimeline、MemoryBubble、
│   │                 #   MemoryTreeGraph、GlassSheet、StateViews、BottomNavBar 等）
│   └── momo/         # 默默角色引擎（状态表、动作数学、覆盖层、地理数据）
├── model/            # 领域模型（Memory、EventItem、DailyMemory、Comic、
│                     #   MoMoState、GardenMode、PageState 等）
├── mock/             # Mock 数据（MockData 兜底数据 / DemoMockData 演示数据）
├── repository/       # 仓库层（Memory / Event / Comic / User，单例 + 订阅 + 演示态切换）
├── router/           # AppRouter：统一路由名与压栈 / 出栈封装
├── service/          # 服务层（CompanionService 状态机、DemoModeService 演示模式、
│                     #   GardenController、TabController、ShellState）
│   ├── ai/           # AI 通路（AIServiceCloud 真实云端 / DemoAIGateway 分流与降级）
│   ├── auth/         # 认证（设备 ID 游客 / 华为账号）
│   ├── cloud/        # 华为云（函数 / 数据库 / 存储）
│   └── system/       # 系统数据源（日历 / 待办等，未启用）
└── utils/            # 工具（Theme、DateUtil、DeviceUtil、TreeLayout、BubbleLayout、PromptUtil）
```

## 第一轮已完成任务

依据 `MoMo-DOC/第一轮提示词`（总控 Prompt + head.md + page.md + 各页面子 Prompt）执行，完成内容如下：

### 页面与路由

- 全部页面可编译、可运行、可跳转，无返回死路
- 一级页面（首页 / 记忆花园 / 设置）由底部导航切换；二级、三级页面经统一路由表压栈进入
- 漫画图片查看、记忆搜索等页面超出第一轮基本要求，已一并实现

### UI 与交互

- 按设计稿还原各页面布局、信息层级、卡片、圆角、留白与字体层级
- 全量沉浸式 HDS 标题栏：滚动渐变模糊、系统菜单（换状态 / 去花园 / 关于 / 搜索 / 树缩放等）
- 底部悬浮导航栏 + 分离式 "+" 加号，点击弹出全局 "记一笔" 浮窗（写入 Mock 记忆仓库）
- 记忆花园三模式：**气泡花园**（按记忆类型分簇的花瓣式蜂巢，默认）、大纲模式（列表）、记忆树模式（可缩放树图）
- 默默角色：多种表情状态绘制、动画与状态切换（首页菜单可手动切换状态）
- 补齐 Loading / Empty / Error 页面状态、点击反馈、Mock 删除与撤回 / 重做、设置项开关等基础交互
- 应用图标与启动页适配

### 架构与数据

- Page → Repository → Mock Data 分层，页面不直接持有业务数据
- Repository 单例 + 发布-订阅，写操作后自动刷新视图；支持 `clearAll` / `restoreSamples` 演示数据复原
- `CompanionService` 状态机（IDLE / CURIOUS / HAPPY / THINKING / LISTENING / SLEEPING）与跨页状态同步
- 路由统一由 `AppRouter` + `RouteName` 管理，页面内不散落字符串

### 明确未做

真实向量数据库 / RAG 语义检索、真实日历 / 待办 / 备忘录读取（仅本地偏好开关）、真实跨端迁移、完整账号体系与用户级云端数据隔离——详见 `项目现状与MVP差距报告.md` 的差距对照表。

## 后续任务路线

参照 `MoMo-DOC/开发笔记参考/05-鸿蒙实现与开发计划.md` 的 Phase 划分：

| 阶段 | 任务 | 说明 | 状态 |
| --- | --- | --- | --- |
| AI 能力 | LLM 总结 / 纠正、漫画脚本 + 出图 | 经华为云函数接 DeepSeek 与即梦 AI | ✅ 已接入（游客可用） |
| 演示模式 | 预置演示数据 + 离线降级 + 与真实数据隔离 | 设置页开关，内存态 | ✅ 已完成（本轮） |
| 数据持久化 | L2 记忆本机落盘 + 游客快照 | 云端 L0/L1/L2 同步受 Creator ACL 阻塞 | 🟡 部分完成 |
| 系统数据接入 | 日历、待办、备忘录 | 申请数据权限，替换 `EventRepository` 的 Mock 实现 | ❌ 未开始 |
| Agent 系统 | Observation / Memory / Expression / Reflection / Companion | 五 Agent 协作，接入 HarmonyOS Agent Framework | 🟡 职责已映射到服务层，未按 Agent 抽象 |
| 跨设备 | 分布式迁移、云端同步 | 默默在不同设备间延续陪伴 | ❌ 未开始 |
| 增强（P1/P2） | 更丰富桌宠动画与状态、记忆搜索强化、陪伴统计、更多数据源、关系成长体系 | 在现有骨架上迭代 | ❌ 未开始 |

迭代方式：小步修改、不重构整页、不破坏已完成页面（见 `MoMo-DOC/迭代用提示词/page-edit.md`）。

## 构建与运行

1. 使用 DevEco Studio 打开本工程（或使用 CLI 构建）；
2. 连接 HarmonyOS NEXT 手机或启动模拟器（SDK 6.0.2(22)+，HDS 组件需 6.1.0(23) 特性，低版本会降级警告）；
3. 签名配置后构建安装 `entry` 模块即可运行。

### 共享后端与签名说明

如果你要分发自己已经签名的应用，让其他人直接使用你的华为登录和云函数后端，请注意：

1. **只跑本地 Mock 版本**：保持 `build-profile.json5` 的 `signingConfigs` 为空，先用「游客登录」跑通本地流程；云服务初始化失败会自动降级，这不代表云端已配置好。
2. **共享同一套已部署后端**：把源码给对方自行编译即可复用同一个 AGC 项目；分发已签名 HAP 与「让源码可编译」是两件事，需要分开处理。
3. **密钥只放云端**：云函数的 DeepSeek、Ark 等服务密钥只配置在华为云函数环境变量里，不得写入仓库；`agconnect-services.json` 属于客户端配置文件，可随工程分发。
4. **不可共享的材料**：`.p12` 私钥、签名密码、与本机调试设备绑定的 `.p7b` Provisioning Profile。仓库已通过 `.gitignore` 排除 `sign/`、`entry/signatures/` 与 `cloud-functions/character-config.json`。

当前工程默认把游客和未完成 Cloud Foundation 身份绑定的数据保存在本机。AI 云函数可以使用共享 AGC 项目，但 CloudDB/Cloud Storage 只有在完成真实云身份与用户级 ACL 配置后才会启用，不能仅凭客户端 `userId` 实现多人数据隔离（该边界由 `tests/t3_contract_test.mjs` 持续守护）。

调试入口：启动参数 `want.parameters.autoNav` 支持 `B_TodayMemory` / `B_DailyComic` / `B_About` / `garden-search` / `garden-tree` / `garden-outline` / `add`，可直接跳转对应页面验证。

## 设计资产：记忆花园背景图

花园背景的生成链路保存在 `design/garden/`，便于后续替换：

```text
design/garden/
├── garden_bg.html    # 背景 SVG 源文件（天空/远山/草地/小路/花木，1080x1900）
├── garden_raw.png    # 浏览器截图得到的原始图
└── crop_png.js       # PNG 裁剪脚本（无依赖，Node 运行）
```

替换流程：

1. 修改 `design/garden/garden_bg.html` 中的 SVG；
2. 浏览器打开并按 1080x1900 截图，保存覆盖 `garden_raw.png`；
3. 运行 `node crop_png.js garden_raw.png ..\entry\src\main\resources\base\media\garden_bg.png <保留高度>`（自底向上裁剪）；
4. 代码无需改动——`A_Garden.ets` 始终通过 `$r('app.media.garden_bg')` 引用 `resources/base/media/garden_bg.png`。

## Mock 数据清单

Mock 数据分两套，分开维护：

| 工厂 | 何时生效 | 作用 |
| --- | --- | --- |
| `mock/MockData.ets` | 真实数据不可用时的兜底（含普通模式） | 保证任何路径都有内容可显示 |
| `mock/DemoMockData.ets` | **仅** `DemoModeService.isDemo()` 为 true 时 | 比赛演示用的高密度预置内容 |

两套都经 Repository 层供页面读取；页面的读取代码在两种模式下完全一致，差异只发生在仓库内部。

### 普通模式兜底数据（`MockData.ets`）

**用户（`buildUser`）**

| 字段 | 值 |
| --- | --- |
| 昵称 | MoMo |
| 签名 | 今天也要好好生活呀 |

**默默状态（`buildCompanion`）**

| 字段 | 值 |
| --- | --- |
| 初始状态 | IDLE（闲） |
| 心情 | 安静陪伴 |
| 描述 | 默默在安静地陪着你 |

状态机共 6 态（`MoMoState`）：IDLE 闲 / CURIOUS 好奇 / HAPPY 开心 / THINKING 想 / LISTENING 听 / SLEEPING 困；首页菜单"换状态"随机在前 4 态中切换。

**今日状态（`buildDailyMemory`）**

- 日期：当天（动态生成）；总结文案 1 条
- 事件 5 条（L0 演示）：

| id | 时间 | 事件 | 分类 |
| --- | --- | --- | --- |
| e1 | 07:20 | 起床后散步 20 分钟 | life |
| e2 | 09:30 | 专注写「HDS 视觉规范」方案 | work |
| e3 | 14:00 | 与设计同学评审首页改版 | work |
| e4 | 19:40 | 晚饭后看了会的漫画 | interest |
| e5 | 22:10 | 记下今天的三个小确幸 | life |

- 洞察 8 条（i1–i8）：工作节奏 / 兴趣偏好 / 情绪趋势 / 关系触点 / 身体信号 / 灵感摘要 / 番茄节拍 / 小小成就

**今日漫画（`buildComic`）**

- id：`comic-2026`；标题：默默的一天 vol.28；日期：当天；留言：今天也有好好陪你，明天见面的路上记得看一眼窗外的云。
- 5 页：清晨 / 专注时刻 / 讨论 / 漫画时间 / 晚安，分别使用占位图 `comic_1` ~ `comic_5`

**长期记忆（`DemoMockData.buildMemories`，L2 演示）**

- 手工种子 **14 条**：`m1` 把晨间散步变成固定习惯（LIFE）……`m14` 开始把「照顾自己」排在任务前面（LIFE），
  日期一律按「今天 − N 天」动态生成（N = 13…1，因此演示当天永远落在最近两周内、日历可点）。
  **具体条目以 `mock/DemoMockData.ets` 为准**（这里不再逐条抄一遍：抄过一次，抄完就与代码漂移了）。
- 三条带「重要回忆」标签 + `importance = 5`：`m4`（GOAL，默认高亮节点，id 不可改）、`m8`（GOAL）、`m14`（LIFE）。
- **日期必须互不相同**：`m4` 与 `m8` 曾经都是「今天 − 10 天」，花园里会出现两颗都写 `09.17` 的圆，
  看起来像重复渲染的 bug —— 现在 `m8` 用「今天 − 9 天」。新增种子时请顺手检查这一点。
- 条数可调（4~60，默认 14）：超出部分由 `extend()` 按 `x1`、`x2`… 确定性补齐，不足部分由 `trim()` 保锚点、保类型后截取。

**气泡花园布局（`utils/BubbleLayout.ets`，运行时计算）**

气泡花园不再使用预置坐标表：布局每次由 `BubbleLayoutUtil.layout(memories, viewportW)` 现算，输入是日期倒序的记忆数组。

- **分簇**：按 `MemoryType` 分成 **4 簇**（生活 / 学习 / 目标 / 兴趣，与头部图例同序），空簇不渲染空花。
  「重要回忆」是**标签**而不是类型（见下节），因此不单独成簇。
- **配色（语义色板）**：生活 = 橙、学习 = 蓝、目标 = 红、兴趣 = 绿。
  只维护一个 base 主色，其余两档按固定规则派生，保证四类颜色的对比度关系恒定：
  - `colorOf` = base，用于图例圆点、小圆点花瓣、花心；
  - `iconColorOf` = base 压暗到 68%，作为主圆内的图标色；
  - `bubbleBgOf` = base 与白色按 86% 混合，作为主圆的浅色底。
  这样「深色图标压在浅色底圆上」的明度差始终成立，改色只需改 base 一处。
- **布局模型：花心点 + 环绕花瓣 + 自适应网格，一屏放得下就不滚动**
  - **花心是一个很小的点（Ø ≈ 主圆的 16%）固定在 cell 正中；承载记忆的圆全部在环上环绕它**。
    花心点**不承载任何记忆**——早期把花心点与记忆圆都放在 (0,0)，实心点会完整盖住圆的图标与日期（真机实测）。
  - 环位**等弧长**（每 60° 一个，最多 6 个），因此每个圆到花心的距离相等、看起来是朵花；
    相邻两点的**弦长 = 1.0 个列距**，所以列距下限就是 `直径 + 间隙`。
  - 超过 6 条的记忆用**同色小实心圆点**沿半径 2 的外圈均匀分布（表示"还在继续生长"）；
    外圈第一圈最多 12 个，超过 18 条会自动再往外开一圈，不会把多出来的点叠在同一圈上。
  - 全局把可用矩形切成 `gCols × gRows` 个 cell，每簇占一个；4 簇优先取 **2×2**。
  - **直径由可用矩形反解**，实测这台 377×816vp 的机器上是 **Ø52**。
  - 主圆内固定为「类型图标 + 一行 `MM.DD`」（日期统一补零，避免 `11.4` 被读成 `11.24`）。
- **两种排布模式（由布局单向决定，页面不自己猜）**：`BubbleLayoutResult.contentHeight`
  - `contentHeight = 0` → **一屏放得下**：4 簇 2×2、直径反解，页面不套 `Scroll`（默认 14 条演示记忆走这条路径，观感与加入本设置前逐像素一致）。
  - `contentHeight > 0` → **向下生长**：某一簇超过 6 条（出现外圈小圆点）后包络从 2 个列距变 4 个列距，
    2 列放不下，布局退化为**单列纵向排布**并给出内容高度，页面据此套 `Scroll`。
    此时列距能吃满，直径反而升到上限 **Ø64**，圆圈更大更好点。
  - 滚动区**从头部玻璃卡下沿开始裁剪**（`BubbleLayoutUtil.topInset()`）：不裁剪时上滑能看到花压在「记忆花园」标题上（真机实测）。
  - 实测分布（4 个类型簇的条数 → 结果，见 `tests/bubble_scale_sim_test.mjs`）：

    | 演示条数 | 簇分布 | 模式 | 直径 | 内容高度 |
    |---|---|---|---|---|
    | 4 | 1/1/1/1 | 一屏 2×2 | Ø51.8 | 816（一屏） |
    | 8 | 3/1/3/1 | 一屏 2×2 | Ø51.8 | 816 |
    | 14（默认） | 5/3/4/2 | 一屏 2×2 | Ø51.8 | 816 |
    | 16 | 6/4/4/2 | 一屏 2×2 | Ø51.8 | 816 |
    | 19 | 7/4/5/3 | 单列滚动 | Ø64 | 1312 |
    | 30 | 9/7/8/6 | 单列滚动 | Ø64 | 1639 |
    | 60（上限） | 17/15/15/13 | 单列滚动 | Ø64 | 1802 |
- **环位几何（踩了五次坑，勿凭直觉改）**：
  - 必须**等弧长**：半径 1、每 60° → 弦长 1.0P。若用六角格的 6 个邻位，最近邻只有 **0.518P**，圆会叠得很厉害。
  - 前几轮反复出错都源于**手写偏移表**（混用格单位与笛卡尔单位、把 P 当成"到邻位的距离"再乘系数）。
    现在环位由 `cos/sin(60°×i)` 现算，不再手写表。
  - `colsAcrossOf/rowsAcrossOf` 返回的是**全宽**（×2 后的值），`solveD` 的 `gCols*(colsAcross+1)` 依赖这一点。
    曾经误传半宽，外圈小圆点被排到屏幕外（实测 x = −23vp）——改这两个函数前先看 `tests/bubble_scale_sim_test.mjs`。
- **不重叠是结构化保证**：`cell 尺寸 = 簇包络 + CELL_SLACK`；`CELL_SLACK` 是必要的——
  若 cell 宽恰好等于包络，最外侧节点会被 `clampInside` 推回零点几 vp，反而贴到相邻节点上（实测 −0.3vp）。
- **行高按每簇自己的包络算**：只有 3 个圆的簇若也按 17 个圆的包络占高，单列排布时会空出一大片。
- **为什么必须自适应直径**：固定 Ø64 + 一簇一行时，4 簇纵向叠加需 `4 × 300 = 1200vp`，
  远超可用的 466vp，表现就是「必须滚动 + 圆圈被裁 + 气泡压到下一簇花心」——这三个现象根因是同一个。
- 布局算法参考 [LVGL 复刻 watchOS 气泡网格](https://lvgl.io/blog/tutorial-recreating-apple-watch-bubble-component) 的错落行思想；未引入其拖拽/惯性/边界压缩（需要自维护定时器，与全仓 `animateTo` 触发式动效体系不一致）。

**「重要回忆」是标签，不是类型**

为把标签圆圈收敛到 4 个，「重要回忆」从 `MemoryType` 降级为 `tags` 里的一个标签：

- 新数据一律写入四类之一，重要性用 `importance >= GOAL_IMPORTANT_IMPORTANCE(5)` + 标签 `重要回忆` 表达；
- 历史数据（`type == IMPORTANT`）在读取时由 `DataSyncService.migrateType()/migrateTags()` 自动迁移为
  「目标 + 重要回忆标签 + importance 5」，因此旧记忆不会因为不属于任何一簇而消失；
- `MemoryType.IMPORTANT = 4` 仅保留用于兼容旧持久化数据，`TYPE_ORDER` 里不再包含它。

**真机才暴露的渲染/布局坑（已修，勿回退）**：

1. `ForEach` 的 key 只写类型时，簇大小变化（如切换演示模式）会让 ArkUI **复用旧组件**、把文本与坐标冻结在旧值。key 必须带数量与坐标。
2. `recomputeBubbleLayout()` 必须**直接读 `MemoryRepository`**，不能读 `this.memories`：页面可能先于 `repoListener` 的 `setState` 渲染，否则出现「气泡是新的、计数是旧的」。
3. **不要给气泡区的 `Scroll` 加 `expandSafeArea`**：扩展安全区会改变内容坐标原点，导致整组气泡偏移（实测布局算出的 y=150 渲染在 y≈435vp）。顶部留白由布局的 `TOP_INSET` 承担，不要用安全区扩展去顶。
4. **固定直径 + 一簇一行会同时引出三个现象**：必须滚动、圆圈被裁、气泡压到下一簇花心。三者根因相同（4 簇纵向叠加 1200vp 远超可用 466vp），修法只有一个：**按可用矩形反解直径**并采用 2×2 网格。
5. **滚动区不要用 `padding` 从头部下沿硬裁**：那样上滑时圆点会被切出一条生硬直边（用户截图指出）。
   现在滚动区铺满整屏，用 `linearGradientBlur` 让内容越往上越模糊，最终化进标题栏与头部玻璃卡：
   ```ts
   .linearGradientBlur(24, {
     fractionStops: [[1.0, 0.0],                     // 顶部全模糊（标题栏那一条）
                     [0.7, topInset() / viewportH * 0.86],  // 玻璃卡下沿仍保留 70%
                     [0.0, topInset() / viewportH]],        // 头部预留高度处完全不模糊
     direction: GradientDirection.Bottom
   })
   ```
   止点必须跟着布局的 `topInset()` 走，而不是拍一个比例：这样偏移为 0 时第一排节点
   （最低在 `topInset()` 处）永远清晰，而滑上去的圆点是"从卡片下沿化出来"的，不是被切断的。
   `FractionStop` 是 `[模糊强度, 位置]`（不是 `[位置, 强度]`），位置按屏高归一化且必须严格递增。
6. **`contentHeight` 只由布局给出**：页面不能自己判断"要不要滚动"——同一份记忆在 16 条时一屏放下、19 条时必须滚动，
   阈值取决于包络（是否出现外圈小圆点），不是条数的绝对值。
7. **`ForEach` 的 item 生成函数里不要写 `if`**（本轮真机实测的新坑，比第 1 条更隐蔽）：
   溢出小圆点原先写成 `ForEach(bubbleLayout.slots) { if (s.mini) { … } }`，key 里只有 `类型|序号`。
   切换演示条数后，键没变的那一颗**连 `if` 分支里的 `.position()` 都不会重算**，
   于是停在上一个条数的位置上，同时本该出现的新位置又整颗缺失（实测 24→37 条：
   多一颗在 `(45,407)`、少一颗在 `(233,544)`）。
   修法两条同时做：小圆点走**独立数组** `bubbleMinis`（去掉 `if`）+ key 里带坐标。
   排查手段记一笔：`tools/crop_zoom.ps1` 把真机截图裁一块放大成 PNG，
   配合 `hilog` 里打印的布局坐标逐点比对，才能确认"渲染位置 ≠ 布局位置"。

单个气泡由 `components/MemoryBubble.ets` 渲染：纯圆、直径由外部传入、圆内只有图标与日期。

**「方形裁切」的三次修复过程（结论：完全不要用 `shadow`）**：ArkUI 的 `shadow` 与 `border` 都按**外接矩形**绘制、
不跟随 `borderRadius`。依次试过并都被真机否掉：
1. 直接给圆加 `.shadow()` → 四角是方形阴影；
2. 外面套一层 `clip(true)` → 圆的直线段处仍会透出矩形栅格的边；
3. 用两层半透明同心圆模拟柔光 → 叠出脏色描边。
最终方案：**不用 shadow，只保留「浅色底圆 + 干净描边」**——Apple Watch 的图标本身就是扁平的，观感也更贴近。
验收方式：把真机截图按 4 倍最近邻放大后逐像素检查，确认圆外没有任何矩形残留。

**点击延迟与闪烁的根因（已修，勿回退）**：

1. `BubbleItem.keygen` **不能带选中态**。带上后，点任意一颗气泡都会让**所有**气泡的 key 失效，
   ArkUI 销毁并重建全部组件——视觉上就是"当前与目标两颗一起闪"。
2. `MemoryBubble` **不能有 `.opacity(entered?1:0)` 这类入场动画**：组件一旦重建就会先渲染成透明再淡入。
   现在只用 `scale` 做按压/选中反馈，不带透明度。
3. `selectMemory()` **不能调用 `recomputeBubbleLayout()`**：选中是纯 UI 状态，走 `syncBubbleSelection()` 即可；
   重算布局只在数据或尺寸变化时发生。这一条同时省掉了每次点击的整轮布局计算与碰撞收敛。

**记忆树（`buildTreeNodes`）**

```text
记忆花园（root）
├── 生活：m1 晨间散步习惯、m6 咖啡店窗边座位
├── 学习成长：m2 HDS 设计规范初稿
├── 兴趣：m3 重读设计中的设计、m7 万物生灵合集
├── 目标：m5 年末12篇漫画
└── 重要回忆：m4 记忆花园第一株花、m8 遇见默默
```

### 演示模式数据（`DemoMockData.ets`）

演示数据全部**按「今天 − N 天」的相对日期生成**，因此无论哪天演示，内容都落在最近 14 天内，日历、时间线与大纲排序不会出现空档。

| 内容 | 规模 | 说明 |
| --- | --- | --- |
| 长期记忆 | 14 条（m1–m14，跨 14 天） | 五种类型齐全；**m4 固定为「重要回忆」**，因为 `A_Garden` 默认选中该节点 |
| 今日事件 | 7 条（e1–e7） | 与记忆的 `sourceEvents` 互相引用，经得起现场追问 |
| 默默的理解 | 9 条 | 「今日状态」页两列网格铺满 |
| 今日漫画 | 5 页 + 5 段分镜脚本 | 复用 `comic_1`~`comic_5`，同时登记为「已生成」，首页卡片不再空白 |
| 身份与档案 | 用户「小雨」+ 已完成档案 | 避免进入演示后被档案引导页拦截 |
| 默默状态 | HAPPY / 元气满满 | 现场展示动作表现 |
| AI 预制返回 | 总结 / 纠正 / 反馈确认文案 | 演示态秒回，不联网 |

### 设置默认值（`SettingsService`）

| 项 | 默认值 |
| --- | --- |
| 演示模式 | 关（内存态，冷启动永远为关） |
| 深色模式 | 关 |
| 大字号 | 关 |
| 主题色 | #97FFAB |
| 日历权限 | 开 |
| 待办权限 | 开 |
| 备忘录权限 | 关 |
| 相机权限 | 关 |
| 低打扰模式 | 开 |

### 页面级 Mock 交互（仅 Toast / 本地状态，不落库）

- 首页"记一笔"：花园 Tab 下会真实写入 MemoryRepository；其他 Tab 仅提示"默默已记下（Mock）"
- 今日状态页：切换日期提示"（Mock 数据）"、刷新提示"Mock 数据未变化"
- 今日漫画页：重新生成提示、仅支持查看当天；内置 Mock 错误态演示（`ComicRepository.loadFailed`，菜单可恢复）
- 设置页：主题色 / 深色模式 / 字号 / 低打扰 / 权限开关均 Toast 反馈；"清空记忆"与"恢复示例数据"真实操作 Mock 仓库（`clearAll` / `restoreSamples`）；清理缓存提示"已释放 1.2 MB（Mock）"
- 关于页：外部链接仅展示；页脚版本"MoMo 2.0 · 正式体验版"

### 占位图片资源（`resources/base/media/`）

`comic_1` ~ `comic_5`（漫画占位图）、`garden_bg`（花园背景，源文件见上文设计资产）、`background` / `foreground`（ layered_image 分层图标）、`icon` / `icon_startwindow` / `startIcon`。

## 测试

无需 DevEco 环境即可运行的静态契约测试（只读源码做断言）：

```bash
node tests/t3_contract_test.mjs          # 云数据库 schema / ACL / 游客本地模式 / 迁移安全
node tests/demo_mode_contract_test.mjs   # 演示模式：内存隔离、零持久化、零上云、设置页入口、演示条数设置
node tests/demo_ai_contract_test.mjs     # AI 通路：函数名对齐、游客可调用、演示态短路与降级
node tests/bubble_layout_contract_test.mjs  # 气泡花园：分簇蜂巢布局、纯圆气泡、旧实现零残留
node tests/bubble_scale_sim_test.mjs     # 气泡花园 4~60 条的几何仿真：无重叠 / 无越界 / 无遮挡
```

`bubble_scale_sim_test.mjs` 把 `BubbleLayout.ets` 的几何算法在 Node 里复刻一遍，用真实演示分布跑
4/8/14/16/19/25/30/40/50/60 十组条数，逐对校验**同簇内**与**跨簇**的节点间距、横向越界与高度遮挡。
开头先比对源码常量，常量改了而仿真没跟上会直接报错。它替设备把"这个条数下布局是否还成立"的成本从一轮编译+装机压到 1 秒。

排查真机渲染问题时用得上：

```bash
# 需要看细节时，把截图裁一块放大成 PNG（read_image 会把整屏缩到 544px 宽，细节全糊）
pwsh tools/crop_zoom.ps1 -In shot.jpeg -Out crop.png -X 60 -Y 850 -W 1200 -H 1150 -Scale 2
```

## 相关文档

- `项目现状与MVP差距报告.md`：本次改动说明、与 MVP 清单的逐项差距、运维知识保全、技术债登记
- `MVP与复赛材料清单.md`：应用 MVP 定义、两周开发计划与复赛材料准备清单
- `../MoMo-DOC/开发笔记参考/`：产品功能、UI 规格、数据与记忆系统、Agent 系统、鸿蒙实现与开发计划
- `../MoMo-DOC/第一轮提示词/`：第一轮总控 Prompt、全局开发规范（head.md / page.md）与各页面子 Prompt
- `../MoMo-DOC/迭代用提示词/`：后续 UI 迭代修改规范
- `../MoMo-DOC/UI参考图/`、`../MoMo-DOC/占位图片/`、`../MoMo-DOC/应用图标/`：设计资产

> 根目录原有的 37 份过程/阶段报告（第一轮、华为云接入、编译修复、3D 花园实验、账号登录等）已归档到本机 `.md-reports-backup/`（该目录不进仓库）。其中仍有用的运维信息（签名、云函数部署、对象类型导入、公开分发）已整理进 `项目现状与MVP差距报告.md`。

