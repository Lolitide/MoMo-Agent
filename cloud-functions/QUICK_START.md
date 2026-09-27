# 快速开始 - 配置你的漫画主人公

## 🚀 三步配置

### 第一步：填写主人公信息

编辑 `character-config.json`，替换以下内容：

```json
{
  "character": {
    "name": "你的主人公名字",
    "appearance": "外观描述（英文）",
    "traits": ["性格1", "性格2", "性格3"],
    "styleKeywords": "风格关键词（英文）",
    "referenceImageUrl": "场景/画风参考图 HTTPS URL",
    "protagonistImageUrl": "主角形象参考图 HTTPS URL"
  }
}
```

**示例**：
```json
{
  "character": {
    "name": "小雨",
    "appearance": "young woman with long black hair, warm brown eyes, wearing casual sweater and jeans",
    "traits": ["温柔", "善良", "爱笑"],
    "styleKeywords": "soft lighting, warm colors, gentle expression",
    "referenceImageUrl": ""
  }
}
```

### 第二步：本地测试

```bash
cd cloud-functions
node test-character-config.js
```

看到 ✅ 表示配置正确。

### 第三步：部署到云端

**方式 1：华为云控制台**
1. 登录 https://console.huaweicloud.com
2. 进入 FunctionGraph → 找到 `llm-comic-script` 和 `image-generate`
3. 上传 `character-config.json` 文件
4. 保存

**方式 2：命令行（推荐）**
```bash
./deploy-config.sh
```

## 📝 填写技巧

### appearance（外观描述）

格式：`[年龄描述] [性别] with [发型和发色], [眼睛], wearing [服装]`

✅ 好例子：
- `young girl with shoulder-length brown hair, bright green eyes, wearing cozy sweater`
- `teenage boy with short black hair, glasses, casual t-shirt and jeans`

❌ 避免：
- 太短：`一个女孩`
- 太抽象：`very beautiful person`
- 用中文：会导致图片生成效果不佳

### traits（性格）

3-5 个形容词即可，中文或英文都可以。

例如：`["温柔", "善良", "爱笑"]` 或 `["gentle", "kind", "cheerful"]`

### styleKeywords（风格关键词）

描述你希望的画面氛围和光线效果。

常用组合：
- 温暖风格：`soft lighting, warm colors, cozy atmosphere`
- 清新风格：`bright natural light, fresh colors, outdoor scene`
- 文艺风格：`artistic composition, muted colors, contemplative mood`

### referenceImageUrl（参考图）

**可选但推荐**。如果有主人公的清晰照片或插画：

1. 上传到华为云存储（通过应用或控制台）
2. 获取公开访问的 URL
3. 填入这里

暂时留空也没关系，文本描述已经能达到较好效果。

## ✨ 现在开始

准备好了吗？提供给我：
1. 主人公的名字
2. 外观描述（或者你直接告诉我特征，我帮你写英文描述）
3. 性格特点
4. （可选）参考图

我会帮你配置到 `character-config.json` 中！
