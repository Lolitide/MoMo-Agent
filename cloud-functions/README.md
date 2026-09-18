# 云函数部署说明

## 📦 云函数列表

### 1. llm-daily-summary
- **功能**: 生成每日总结
- **运行时**: Node.js 18
- **内存**: 512MB
- **超时**: 60秒
- **环境变量**: `DEEPSEEK_API_KEY`

### 2. llm-comic-script
- **功能**: 生成漫画脚本
- **运行时**: Node.js 18
- **内存**: 512MB
- **超时**: 60秒
- **环境变量**: `DEEPSEEK_API_KEY`

### 3. image-generate
- **功能**: 生成图片（即梦AI）
- **运行时**: Node.js 18
- **内存**: 1024MB
- **超时**: 120秒
- **环境变量**: `JIMENG_ACCESS_KEY`, `JIMENG_SECRET_KEY`

---

## 🚀 部署步骤

### 方法1: 手动部署（推荐）

1. 登录 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)
2. 进入「构建」→「云函数」
3. 点击「创建函数」

**对于每个函数：**

1. 上传代码文件（.js文件）
2. 配置参数：
   - 函数名称：见上表
   - 运行时：Node.js 18
   - 内存：见上表
   - 超时：见上表
3. 配置环境变量（见下方）
4. 保存并部署

### 方法2: 批量部署（使用配置文件）

```bash
# 安装AGC CLI（如果有的话）
npm install -g @agconnect/cli

# 登录
agc login

# 批量部署
agc function deploy --config functions.json
```

---

## 🔑 环境变量配置

### DeepSeek API Key

1. 访问 [DeepSeek开放平台](https://platform.deepseek.com/)
2. 创建API Key
3. 在云函数环境变量中添加：
   ```
   DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxx
   ```

### 即梦AI密钥

1. 访问 [火山引擎控制台](https://console.volcengine.com/)
2. 进入「视觉智能」→「即梦AI」
3. 创建密钥
4. 在云函数环境变量中添加：
   ```
   JIMENG_ACCESS_KEY=AKxxxxxxxxxxxxxxxx
   JIMENG_SECRET_KEY=xxxxxxxxxxxxxxxx
   ```

---

## 🧪 测试云函数

### 测试 llm-daily-summary

**测试输入：**
```json
{
  "userId": "test_user_001",
  "events": [
    "09:00 起床，阳光明媚",
    "10:30 写代码，完成了新功能",
    "12:00 午餐，吃了美味的面条",
    "15:00 运动，跑步5公里",
    "20:00 看书，读完一章"
  ],
  "mood": "开心"
}
```

**预期输出：**
```json
{
  "success": true,
  "content": "今天是充实而美好的一天！早晨在温暖的阳光中醒来...",
  "usage": {
    "promptTokens": 150,
    "completionTokens": 80,
    "totalTokens": 230
  }
}
```

### 测试 llm-comic-script

**测试输入：**
```json
{
  "userId": "test_user_001",
  "summary": "今天是充实而美好的一天！早晨在温暖的阳光中醒来...",
  "events": [
    "09:00 起床，阳光明媚",
    "12:00 午餐，吃了美味的面条",
    "15:00 运动，跑步5公里"
  ]
}
```

**预期输出：**
```json
{
  "success": true,
  "panels": [
    {
      "index": 0,
      "description": "清晨，阳光透过窗帘",
      "prompt": "A cute AI pet waking up by the window in the morning, warm sunlight...",
      "dialogue": "早安！新的一天开始啦~"
    },
    ...
  ],
  "theme": "充实的一天"
}
```

### 测试 image-generate

**测试输入：**
```json
{
  "userId": "test_user_001",
  "prompt": "A cute AI pet sitting by the window, anime style, warm colors",
  "style": "anime",
  "size": "1024x1024"
}
```

**预期输出：**
```json
{
  "success": true,
  "taskId": "task_1726675200_abc123",
  "status": "success",
  "imageUrl": "https://cloudStorage-xxx.xxx.com/momo-images/comics/..."
}
```

---

## 📊 监控和日志

### 查看日志

1. 进入「云函数」→「函数列表」
2. 点击函数名称
3. 点击「日志」标签
4. 查看执行日志和错误信息

### 监控指标

在「监控」标签查看：
- 调用次数
- 错误率
- 平均响应时间
- 内存使用
- 超时次数

---

## 🐛 常见问题

### 1. 云函数超时

**现象**: `Function execution timeout`

**解决**:
- 增加超时时间到120秒
- 优化API调用逻辑
- 检查网络连接

### 2. 环境变量未生效

**现象**: `DEEPSEEK_API_KEY is not defined`

**解决**:
- 确认环境变量已配置
- 重新部署云函数
- 检查变量名拼写

### 3. API调用失败

**现象**: `DeepSeek API error: 401 Unauthorized`

**解决**:
- 检查API Key是否有效
- 检查API额度是否充足
- 查看API服务状态

---

## 💰 成本估算

### 云函数成本

- **免费额度**: 40万GBs/月
- **计算方式**: (内存/1024) × 执行时间(秒) × 调用次数

**示例计算**:
```
单次调用成本 = (512MB/1024) × 2秒 = 1 GBs
100用户/天 × 3次调用 × 30天 = 9000次/月
总消耗 = 9000 GBs/月 (远小于40万免费额度)
```

### AI服务成本

- **DeepSeek**: ¥0.001-0.002/次
- **即梦AI**: ¥0.05-0.1/张

**单用户日成本**: 约¥0.5/天

---

**文档更新时间**: 2026-09-18
