# 编译测试指南

## 🔍 当前状态检查

### ✅ 已完成
- EntryAbility 中添加了 AI 服务初始化
- EventRepository 已添加 generateDailySummary() 和 getHistorySummaries()
- ComicRepository 已添加 generateTodayComic() 和 generateComicScript()
- 创建了增强版页面（B_TodayMemory_Enhanced 和 B_DailyComic_Enhanced）

### ⚠️ 发现的问题
1. **hdc 工具未找到** - 需要安装或配置 HarmonyOS 开发工具
2. **构建脚本检查** - 项目使用 hvigor 构建系统

---

## 📋 编译前准备清单

### 1. 环境检查

#### 检查 DevEco Studio 是否安装
```bash
# macOS
ls -la /Applications/DevEco-Studio.app/

# 或查找命令行工具
which hdc
which ohpm
```

#### 检查 Node.js 版本
```bash
node --version  # 应该 >= 14.x
npm --version
```

### 2. 安装依赖（如果还没装）

```bash
# 进入项目目录
cd /Users/kaylnlu/Kalyn/Momo

# 安装 npm 依赖
npm install

# 或使用 ohpm（HarmonyOS 包管理器）
ohpm install
```

### 3. 配置 HarmonyOS SDK

确保已配置：
- HarmonyOS SDK 6.0.2(22)
- API Version 22
- 签名配置（已有 sign/momo_debug.p12）

---

## 🛠️ 编译方法

### 方法 1：使用 DevEco Studio（推荐）

1. **打开项目**
   - 启动 DevEco Studio
   - File → Open → 选择 `/Users/kaylnlu/Kalyn/Momo`

2. **同步依赖**
   - 等待 Gradle/Hvigor 同步完成
   - 查看底部状态栏

3. **检查配置**
   - Build → Select Build Variant → 选择 `debug`
   - 确认签名配置正确

4. **编译**
   - Build → Make Module 'entry'
   - 或点击工具栏的 🔨 按钮

5. **安装到设备**
   - 连接 HarmonyOS 设备或启动模拟器
   - Run → Run 'entry'
   - 或点击工具栏的 ▶️ 按钮

### 方法 2：使用命令行

```bash
# 进入项目目录
cd /Users/kaylnlu/Kalyn/Momo

# 清理构建缓存
rm -rf entry/build/

# 编译 HAP 包
node ./node_modules/@ohos/hvigor/bin/hvigor.js --mode module -p product=default -p module=entry@default assembleHap

# 或者使用 npm script（如果配置了）
npm run build
```

### 方法 3：使用 hvigorw 包装器（如果存在）

```bash
# 给执行权限
chmod +x hvigorw

# 编译
./hvigorw assembleHap --mode module -p product=default -p module=entry@default
```

---

## 🔧 可能遇到的问题

### 问题 1：hdc 命令未找到

**原因**：HarmonyOS 命令行工具未添加到 PATH

**解决方法**：
```bash
# 查找 DevEco Studio 安装路径
find /Applications -name "hdc" 2>/dev/null

# 临时添加到 PATH（替换为你的实际路径）
export PATH="/Applications/DevEco-Studio.app/Contents/sdk/HarmonyOS-NEXT-DB6/hmscore/5.0.0.71/toolchains:$PATH"

# 或永久添加到 ~/.zshrc
echo 'export PATH="/Applications/DevEco-Studio.app/Contents/sdk/HarmonyOS-NEXT-DB6/hmscore/5.0.0.71/toolchains:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### 问题 2：找不到 @kit.UIDesignKit

**原因**：HDS 组件库未安装

**解决方法**：
```bash
ohpm install @kit.UIDesignKit
```

### 问题 3：签名配置错误

**检查**：
```bash
ls -la sign/momo_debug.p12
ls -la sign/momo_debug.cer
```

**确认 build-profile.json5 中的签名配置**：
```json
"signingConfigs": [
  {
    "name": "default",
    "type": "HarmonyOS",
    "material": {
      "certPath": "sign/momo_debug.cer",
      "storeFile": "sign/momo_debug.p12",
      "keyAlias": "debugKey",
      "storePassword": "...",
      "keyPassword": "..."
    }
  }
]
```

### 问题 4：导入错误或类型错误

**检查关键导入**：
```typescript
// EntryAbility.ets
import { AIServiceCloud } from '../service/ai/AIServiceCloud';

// Repositories.ets
import { MockData } from '../mock/MockData';
import { Comic, DailyMemory, Memory } from '../model/Models';
```

**如果报错，检查文件是否存在**：
```bash
ls entry/src/main/ets/service/ai/AIServiceCloud.ets
ls entry/src/main/ets/mock/MockData.ets
ls entry/src/main/ets/model/Models.ets
```

---

## 📱 测试步骤

### 1. 编译成功后

**查看生成的 HAP 包**：
```bash
ls -lh entry/build/default/outputs/default/*.hap
```

### 2. 安装到设备

#### 使用 DevEco Studio
- Run → Run 'entry'

#### 使用命令行
```bash
# 连接设备
hdc list targets

# 安装 HAP
hdc install entry/build/default/outputs/default/entry-default-signed.hap

# 启动应用
hdc shell aa start -a EntryAbility -b com.agent.momo
```

### 3. 查看日志

```bash
# 实时查看日志
hdc shell hilog | grep "MoMo"

# 或使用 DevEco Studio 的 Logcat 面板
```

**期望看到的日志**：
```
[MoMo] Ability onCreate autoNav=
[MoMo] 开始初始化AI云服务...
[MoMo] ✅ 用户认证完成
[MoMo] ✅ 华为云服务初始化完成
[MoMo] 🎉 AI云服务初始化成功
```

### 4. 测试 AI 功能

#### 测试今日总结生成
1. 进入「今日状态」页面
2. 点击右上角菜单
3. 点击「生成总结」（需要先切换到增强版页面）
4. 观察 Toast 提示
5. 等待 3-5 秒
6. 查看总结是否更新

#### 测试今日漫画生成
1. 进入「今日漫画」页面
2. 点击右上角菜单
3. 点击「生成漫画」（需要先切换到增强版页面）
4. 观察 Loading 状态
5. 等待 30-60 秒
6. 查看漫画是否生成

---

## 🚨 如果编译失败

### 收集错误信息

1. **编译错误日志**
```bash
# 保存完整编译日志
node ./node_modules/@ohos/hvigor/bin/hvigor.js assembleHap 2>&1 | tee build.log
```

2. **检查语法错误**
```bash
# 检查 TypeScript 文件
grep -r "export class EventRepository" entry/src/main/ets/
grep -r "export class ComicRepository" entry/src/main/ets/
```

3. **检查导入路径**
```bash
# 检查 AIServiceCloud 导入
grep -r "AIServiceCloud" entry/src/main/ets/entryability/
grep -r "AIServiceCloud" entry/src/main/ets/repository/
```

### 常见错误修复

#### 错误：Cannot find module 'AIServiceCloud'
**原因**：导入路径错误

**检查**：
```bash
ls entry/src/main/ets/service/ai/AIServiceCloud.ets
```

**修复**：确认路径正确
```typescript
import { AIServiceCloud } from '../service/ai/AIServiceCloud';
```

#### 错误：Property 'generateDailySummary' does not exist
**原因**：方法未正确添加到 EventRepository

**检查**：
```bash
grep -A 20 "async generateDailySummary" entry/src/main/ets/repository/Repositories.ets
```

---

## 📝 编译成功检查清单

- [ ] 项目在 DevEco Studio 中打开
- [ ] 依赖同步完成（无红色波浪线）
- [ ] 编译无错误
- [ ] HAP 包生成成功
- [ ] 应用成功安装到设备
- [ ] 启动页面正常显示
- [ ] 日志显示 AI 服务初始化成功（或失败但不崩溃）
- [ ] 可以正常导航到各个页面

---

## 🎯 下一步

编译成功后：

1. **立即测试**：查看 AI 服务初始化日志
2. **如果初始化成功**：测试生成功能
3. **如果初始化失败**：检查云服务配置（华为账号、云函数、API Key）
4. **记录问题**：把遇到的问题告诉我，我帮你解决

---

## 📞 需要帮助？

把以下信息提供给我：

1. **编译错误日志**（如果有）
2. **运行时错误日志**（hilog 输出）
3. **具体现象**（崩溃/白屏/功能不工作）
4. **环境信息**：
   - DevEco Studio 版本
   - HarmonyOS SDK 版本
   - Node.js 版本
   - macOS 版本

我会帮你诊断和修复！
