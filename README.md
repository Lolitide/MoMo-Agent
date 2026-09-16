# 默默 Mo Mo

> 一只会观察、会画画、能随时随地陪伴用户的鸿蒙 AI 桌宠。

默默不是传统聊天机器人，也不是简单电子宠物。它的核心体验是一个长期陪伴循环：

```text
观察 → 理解 → 表达 → 用户反馈 → 纠正 → 积累 → 再次观察
```

默默会在用户授权范围内读取日历、待办、备忘录等信息，理解用户的生活片段；通过漫画、动作和低频互动表达陪伴；通过 L0 原始事件、L1 每日小结、L2 长期档案三级记忆逐渐理解用户，并允许用户随时查看、纠正、删除。

## 当前状态

**第一轮（Mock UI 全量实现）已完成。** 当前仓库是一个可运行、可点击、可导航的完整产品骨架：全部页面使用 Mock 数据驱动，AI / 系统数据 / 跨设备能力均通过 Repository 与 Service 层隔离，为后续接入真实能力预留了替换接口。

- 包名：`com.agent.momo`
- 版本：1.0.0
- 目标设备：phone

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
│   ├── A_Garden.ets        # 一级：记忆花园（花园 / 大纲 / 记忆树三模式）
│   ├── A_Settings.ets      # 一级：设置
│   ├── B_TodayMemory.ets   # 二级：今日状态
│   ├── B_DailyComic.ets    # 二级：今日漫画
│   ├── B_About.ets         # 二级：关于默默
│   ├── B_Search.ets        # 二级：记忆搜索
│   └── B_ComicViewer.ets   # 三级：漫画查看器
├── components/       # 复用组件（MoMoAvatar、MoMoCard、EventTimeline、
│   │                 #   MemoryTreeGraph、GlassSheet、StateViews、BottomNavBar 等）
│   └── momo/         # 默默角色引擎（状态表、动作数学、覆盖层、地理数据）
├── model/            # 领域模型（Memory、EventItem、DailyMemory、Comic、
│                     #   MoMoState、GardenMode、PageState 等）
├── mock/             # Mock 数据（记忆、事件、漫画、用户）
├── repository/       # 仓库层（Memory / Event / Comic / User，单例 + 订阅）
├── router/           # AppRouter：统一路由名与压栈 / 出栈封装
├── service/          # 服务层（CompanionService 状态机、GardenController、
│                     #   TabController、ShellState）
└── utils/            # 工具（Theme、DateUtil、DeviceUtil、TreeLayout、PromptUtil）
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
- 记忆花园三模式：花园模式（节点地图）、大纲模式（列表）、记忆树模式（可缩放树图）
- 默默角色：多种表情状态绘制、动画与状态切换（首页菜单可手动切换状态）
- 补齐 Loading / Empty / Error 页面状态、点击反馈、Mock 删除与撤回 / 重做、设置项开关等基础交互
- 应用图标与启动页适配

### 架构与数据

- Page → Repository → Mock Data 分层，页面不直接持有业务数据
- Repository 单例 + 发布-订阅，写操作后自动刷新视图；支持 `clearAll` / `restoreSamples` 演示数据复原
- `CompanionService` 状态机（IDLE / CURIOUS / HAPPY / THINKING / LISTENING / SLEEPING）与跨页状态同步
- 路由统一由 `AppRouter` + `RouteName` 管理，页面内不散落字符串

### 明确未做（本轮非目标）

真实 LLM / Embedding / 向量数据库 / RAG、真实日历 / 待办 / 备忘录读取、真实跨设备迁移与云端同步、复杂账号系统——均留待后续轮次。

## 后续任务路线

参照 `MoMo-DOC/开发笔记参考/05-鸿蒙实现与开发计划.md` 的 Phase 划分：

| 阶段 | 任务 | 说明 |
| --- | --- | --- |
| 数据持久化 | Event / L1 / L2 记忆 CRUD 落盘 | 将 Mock 内存存储替换为本地数据库 |
| 系统数据接入 | 日历、待办、备忘录 | 申请数据权限，替换 `EventRepository` 的 Mock 实现 |
| Agent 系统 | Observation / Memory / Expression / Reflection / Companion | 五 Agent 协作，接入 HarmonyOS Agent Framework |
| AI 能力 | LLM、Embedding、向量记忆、RAG、漫画生成 | 通过 `AIService` 接口替换 Mock |
| 跨设备 | 分布式迁移、云端同步 | 默默在不同设备间延续陪伴 |
| 增强（P1/P2） | 更丰富桌宠动画与状态、记忆搜索强化、陪伴统计、更多数据源、关系成长体系 | 在现有骨架上迭代 |
| 测试与演示 | UI / 数据 / AI / 权限 / 网络 / 跨设备测试，Demo Mode、演示数据与脚本 | 比赛演示准备 |

迭代方式：小步修改、不重构整页、不破坏已完成页面（见 `MoMo-DOC/迭代用提示词/page-edit.md`）。

## 构建与运行

1. 使用 DevEco Studio 打开本工程（或使用 CLI 构建）；
2. 连接 HarmonyOS NEXT 手机或启动模拟器（SDK 6.0.2(22)+，HDS 组件需 6.1.0(23) 特性，低版本会降级警告）；
3. 签名配置后构建安装 `entry` 模块即可运行。

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

当前所有数据均为 Mock，统一由 `mock/MockData.ets` 工厂生成，经 Repository 层供页面读取。后续接入真实服务时只需替换 Repository 实现。清单如下，便于准备演示数据与检查覆盖度。

### 用户（`buildUser`）

| 字段 | 值 |
| --- | --- |
| 昵称 | 酪酪肽 |
| 签名 | 今天也要好好生活呀 |

### 默默状态（`buildCompanion`）

| 字段 | 值 |
| --- | --- |
| 初始状态 | IDLE（闲） |
| 心情 | 安静陪伴 |
| 描述 | 默默在安静地陪着你 |

状态机共 6 态（`MoMoState`）：IDLE 闲 / CURIOUS 好奇 / HAPPY 开心 / THINKING 想 / LISTENING 听 / SLEEPING 困；首页菜单"换状态"随机在前 4 态中切换。

### 今日状态（`buildDailyMemory`）

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

### 今日漫画（`buildComic`）

- id：`comic-2026`；标题：默默的一天 vol.28；日期：当天；留言：今天也有好好陪你，明天见面的路上记得看一眼窗外的云。
- 5 页：清晨 / 专注时刻 / 讨论 / 漫画时间 / 晚安，分别使用占位图 `comic_1` ~ `comic_5`

### 长期记忆（`buildMemories`，L2 演示）

| id | 标题 | 日期 | 类型 | 重要度 | 标签 | 关联 |
| --- | --- | --- | --- | --- | --- | --- |
| m1 | 第一次养成了晨间散步的习惯 | 2026-10-24 | LIFE | 3 | 习惯/晨间/健康 | 源事件 e1 |
| m2 | 完成 HDS 设计规范初稿 | 2026-10-22 | STUDY | 4 | 设计/文档/成长 | 源事件 e2、e3 |
| m3 | 开始重读《设计中的设计》 | 2026-10-20 | INTEREST | 2 | 阅读/设计 | — |
| m4 | 给默默的新家画了第一株花 | 2026-10-28 | IMPORTANT | 5 | 纪念日/默默/重要 | 关联 m8 |
| m5 | 年末目标：完成 12 篇漫画 | 2026-10-18 | GOAL | 3 | 目标/漫画/创作 | 关联 m4 |
| m6 | 咖啡店边窗的座位 | 2026-10-12 | LIFE | 2 | 咖啡/灵感 | — |
| m7 | 听完了《万物生灵》合集 | 2026-10-15 | INTEREST | 2 | 音乐/散步 | — |
| m8 | 遇见默默 | 2026-10-28 | IMPORTANT | 5 | 默默/生日/重要 | 关联 m4 |

### 花园节点（`buildGardenNodes`）

8 个节点（`g-node-0` ~ `g-node-7`）对应 m1–m8，在花园模式中的百分比坐标依次为：`(30,46) (52,40) (70,47) (40,56) (62,56) (24,58) (48,64) (78,60)`。

### 记忆树（`buildTreeNodes`）

```text
记忆花园（root）
├── 生活：m1 晨间散步习惯、m6 咖啡店窗边座位
├── 学习成长：m2 HDS 设计规范初稿
├── 兴趣：m3 重读设计中的设计、m7 万物生灵合集
├── 目标：m5 年末12篇漫画
└── 重要回忆：m4 记忆花园第一株花、m8 遇见默默
```

### 设置默认值（`SettingsService`）

| 项 | 默认值 |
| --- | --- |
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
- 关于页：外部链接仅展示；页脚版本"MoMo 1.0.0 · 第一轮 Mock UI"

### 占位图片资源（`resources/base/media/`）

`comic_1` ~ `comic_5`（漫画占位图）、`garden_bg`（花园背景，源文件见上文设计资产）、`background` / `foreground`（ layered_image 分层图标）、`icon` / `icon_startwindow` / `startIcon`。

## 相关文档

- `../MoMo-DOC/开发笔记参考/`：产品功能、UI 规格、数据与记忆系统、Agent 系统、鸿蒙实现与开发计划
- `../MoMo-DOC/第一轮提示词/`：第一轮总控 Prompt、全局开发规范（head.md / page.md）与各页面子 Prompt
- `../MoMo-DOC/迭代用提示词/`：后续 UI 迭代修改规范
- `../MoMo-DOC/UI参考图/`、`../MoMo-DOC/占位图片/`、`../MoMo-DOC/应用图标/`：设计资产
- `MVP与复赛材料清单.md`：应用 MVP 定义、两周开发计划与复赛材料准备清单
