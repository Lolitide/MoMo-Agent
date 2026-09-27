# 默默 Mo Mo - 华为云端云一体化版本

<div align="center">

![HarmonyOS](https://img.shields.io/badge/HarmonyOS-NEXT-red)
![Status](https://img.shields.io/badge/Status-开发完成-brightgreen)
![License](https://img.shields.io/badge/License-MIT-blue)

**一个温暖的AI桌宠，陪伴你的每一天**

基于华为端云一体化服务 · DeepSeek AI · 即梦AI文生图

</div>

---

## 🎯 项目概述

**默默（Mo Mo）** 是一个基于HarmonyOS NEXT的AI桌宠应用，采用**华为端云一体化架构**，实现：

- 🔐 **华为账号一键登录** - Account Kit
- 💾 **云端数据存储** - Cloud DB
- 🖼️ **漫画图片存储** - Cloud Storage
- ⚡ **AI服务调用** - Cloud Functions
- 🤖 **智能对话总结** - DeepSeek API
- 🎨 **AI文生图** - 即梦AI（火山引擎）

---

## ✨ 核心功能

### 1. 每日记录
- 📝 记录今日事件（时间 + 内容 + 心情）
- 🧠 AI自动生成温馨总结
- 🎨 生成5格漫画分镜
- 🌸 保存到「记忆花园」

### 2. 漫画生成
- 📖 DeepSeek生成漫画脚本
- 🎨 即梦AI生成分镜图片
- 💾 自动上传到云存储
- 📱 本地缓存优化

### 3. 记忆管理
- 🌺 查看历史记录
- ✏️ 纠正AI总结
- 🔄 云端自动同步
- 📊 配额管理

---

## 🏗️ 技术架构

```
┌─────────────────────────────────────────────────────────┐
│              HarmonyOS NEXT 客户端（ArkTS）              │
├─────────────────────────────────────────────────────────┤
│  service/                                                │
│    ├─ auth/            # 认证模块                        │
│    │   ├─ AccountKitAuthProvider  # 华为账号登录         │
│    │   └─ DeviceAuthProvider      # 设备ID登录（备选）   │
│    │                                                      │
│    ├─ cloud/           # 华为云服务                      │
│    │   ├─ CloudServiceManager     # 统一管理器           │
│    │   ├─ CloudDBService          # 云数据库             │
│    │   ├─ CloudStorageService     # 云存储               │
│    │   └─ CloudFunctionService    # 云函数               │
│    │                                                      │
│    └─ ai/              # AI服务                          │
│        └─ AIServiceCloud          # 业务逻辑封装         │
└─────────────────────────────────────────────────────────┘
                        ↕ 华为云SDK
┌─────────────────────────────────────────────────────────┐
│           华为 AppGallery Connect 云服务                 │
├─────────────────────────────────────────────────────────┤
│  ✅ Account Kit       # 华为账号登录                     │
│  ✅ Cloud DB          # 云数据库（UserProfile、Record）  │
│  ✅ Cloud Storage     # 云存储（漫画图片）               │
│  ✅ Cloud Functions   # 云函数（调用AI服务）             │
└─────────────────────────────────────────────────────────┘
                        ↕ HTTPS
┌─────────────────────────────────────────────────────────┐
│                    第三方AI服务                          │
├─────────────────────────────────────────────────────────┤
│  🤖 DeepSeek API     # LLM服务（总结、脚本）             │
│  🎨 即梦AI API       # 文生图服务（漫画分镜）            │
└─────────────────────────────────────────────────────────┘
```

---

## 📦 项目结构

```
Momo/
├── entry/src/main/ets/          # 客户端代码
│   ├── service/
│   │   ├── auth/                # 认证模块
│   │   │   ├── AccountKitAuthProvider.ets  ✅ 新增
│   │   │   ├── DeviceAuthProvider.ets
│   │   │   ├── AuthService.ets
│   │   │   └── TokenManager.ets
│   │   │
│   │   ├── cloud/               # 华为云服务 ✅ 新增
│   │   │   ├── CloudServiceManager.ets
│   │   │   ├── CloudDBService.ets
│   │   │   ├── CloudStorageService.ets
│   │   │   ├── CloudFunctionService.ets
│   │   │   ├── CloudDBModels.ets
│   │   │   └── index.ets
│   │   │
│   │   └── ai/                  # AI服务
│   │       ├── AIServiceCloud.ets  ✅ 新增
│   │       ├── AIService.ets
│   │       ├── LLMService.ets
│   │       └── ImageGenService.ets
│   │
│   ├── pages/                   # 页面
│   ├── components/              # 组件
│   └── model/                   # 数据模型
│
├── cloud-functions/             # 云函数 ✅ 新增
│   ├── llm-daily-summary.js    # 生成每日总结
│   ├── llm-comic-script.js     # 生成漫画脚本
│   ├── image-generate.js       # 生成图片
│   ├── functions.json          # 配置文件
│   └── README.md               # 部署说明
│
└── docs/                        # 文档 ✅ 新增
    ├── 华为云服务配置指南.md
    ├── 华为云快速开始.md
    ├── 华为云实施报告.md
    └── 完整技术方案.md
```

---

## 🚀 快速开始

### 1. 环境准备

- **DevEco Studio**: 5.0.0+
- **HarmonyOS SDK**: API 12+
- **华为开发者账号**: 已实名认证

### 2. 配置华为云服务

详细配置步骤见：[华为云服务配置指南.md](华为云服务配置指南.md)

**快速清单：**
- [ ] 创建AppGallery Connect项目
- [ ] 下载 `agconnect-services.json` 到 `entry/src/main/resources/rawfile/`
- [ ] 开通 Account Kit
- [ ] 创建 Cloud DB 存储区 `MomoDataZone`
- [ ] 创建对象类型（UserProfile、DailyRecord、ComicImage）
- [ ] 创建 Cloud Storage 存储桶 `momo-images`
- [ ] 部署3个云函数
- [ ] 配置API密钥（DeepSeek + 即梦AI）

### 3. 运行应用

```bash
# 安装依赖
ohpm install

# 连接HarmonyOS设备

# 运行
# 点击DevEco Studio的「Run」按钮
```

---

## 📊 代码统计

| 模块 | 文件数 | 代码行数 | 状态 |
|------|--------|----------|------|
| 认证模块 | 1 | 200 | ✅ |
| 云数据库 | 2 | 530 | ✅ |
| 云存储 | 1 | 280 | ✅ |
| 云函数客户端 | 2 | 400 | ✅ |
| AI服务 | 1 | 350 | ✅ |
| 云函数后端 | 3 | 420 | ✅ |
| **总计** | **13** | **~3260行** | **✅** |

---

## 💰 成本分析

### 华为云服务（免费额度）
- **Account Kit**: 免费
- **Cloud DB**: 2GB存储 + 50万次读写/月
- **Cloud Storage**: 5GB存储 + 50GB流量/月
- **Cloud Functions**: 40万GBs/月

### AI服务（按量付费）
- **DeepSeek**: ¥0.001-0.002/次
- **即梦AI**: ¥0.05-0.1/张

**单用户日成本**: ¥0.5/天  
**100用户月成本**: ¥115（华为云免费 + AI服务¥115）

**对比自建后端**: 节省 ¥90/月（44%）

---

## 📚 文档

- [华为云服务配置指南](华为云服务配置指南.md) - 完整配置步骤
- [华为云快速开始](华为云快速开始.md) - 快速上手指南
- [华为云实施报告](华为云实施报告.md) - 项目总结报告
- [完整技术方案](完整技术方案.md) - 原始技术设计
- [云函数部署说明](cloud-functions/README.md) - 云函数部署指南

---

## 🎯 功能特性

### ✅ 已实现

- [x] 华为账号登录
- [x] 云数据库存储
- [x] 云存储管理
- [x] 云函数调用
- [x] 每日总结生成
- [x] 漫画脚本生成
- [x] 漫画图片生成
- [x] 配额管理（20次LLM/天，5张图片/天）
- [x] 历史记录查询
- [x] 本地缓存优化

### 🚧 待优化

- [ ] 多端同步
- [ ] 分享功能
- [ ] 数据导出
- [ ] 主题切换
- [ ] 更多AI模型支持

---

## 🐛 问题反馈

遇到问题？查看：
- [故障排查](华为云服务配置指南.md#故障排查)
- [常见问题](华为云快速开始.md#故障排查)

---

## 📄 开源协议

本项目采用 MIT 协议开源。

---

## 🙏 致谢

- [HarmonyOS](https://developer.huawei.com/) - 操作系统和云服务
- [DeepSeek](https://www.deepseek.com/) - LLM服务
- [火山引擎](https://www.volcengine.com/) - 即梦AI文生图服务

---

<div align="center">

**⭐ 如果这个项目对你有帮助，请给个Star支持一下！**

Made with ❤️ by [Your Name]

</div>
