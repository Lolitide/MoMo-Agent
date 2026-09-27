# 角色配置指南

## 功能说明

这个配置系统让漫画生成时保持**主人公形象一致**和**画风统一**，而不是每次随机生成。

## 配置文件

### 1. character-config.json

主要配置文件，包含角色设定和视觉风格：

```json
{
  "character": {
    "name": "默默",
    "appearance": "角色外观的英文描述",
    "traits": ["性格1", "性格2", "性格3"],
    "styleKeywords": "绘图风格关键词",
    "referenceImageUrl": "场景/画风参考图的 HTTPS URL",
    "protagonistImageUrl": "主角形象参考图的 HTTPS URL"
  },
  "visualStyle": {
    "artStyle": "画风描述",
    "colorPalette": "色调描述",
    "mood": "氛围描述",
    "composition": "构图描述"
  }
}
```

### 2. style-guide.md

详细的视觉风格文档，供参考和维护使用。

## 使用步骤

### 步骤 1: 准备内置参考图

1. 准备一张清晰的主角图和一张场景/画风参考图（建议 512x512 或更大）
2. 上传到华为云存储，并确保 Ark 服务端可以通过 HTTPS 访问
3. 将主角图 URL 填入 `character.protagonistImageUrl`
4. 将场景参考图 URL 填入 `character.referenceImageUrl`

应用不需要用户选择图片。仓库已内置 `assets/protagonist.png` 和 `assets/scene-reference.png`，漫画分镜默认启用图生图，云函数会自动把这两张图片转换为 Ark `image` 字段需要的 data URL。若改用云存储，也可以填写两个 HTTPS URL；URL 优先于内置文件。

### 步骤 2: 编辑配置文件

打开 `character-config.json`，根据你的主人公设定修改：

**character.name**: 主人公名字（中文）

**character.appearance**: 外观描述（英文，用于图片生成）
- 示例：`"young girl with short brown hair, green eyes, wearing a cozy cream-colored sweater"`
- 要点：发型、发色、眼睛颜色、常穿服装、身材特征

**character.traits**: 性格特征（中文数组）
- 示例：`["gentle", "observant", "warm"]`

**character.styleKeywords**: 风格关键词（英文）
- 示例：`"soft lighting, warm atmosphere, gentle expression, cozy indoor scene"`
- 用途：每张图自动添加这些关键词

**visualStyle**: 整体画风设定
- `artStyle`: 画风类型，如 `"modern anime illustration, soft watercolor style"`
- `colorPalette`: 色调，如 `"warm earth tones, soft pastels"`
- `mood`: 氛围，如 `"cozy, heartwarming, peaceful"`
- `composition`: 构图偏好，如 `"close-up emotional moments"`

### 步骤 3: 测试配置

运行测试脚本验证配置是否正确：

```bash
cd cloud-functions
node test-character-config.js
```

应该看到：
- ✅ 配置文件加载成功
- ✅ Prompt 增强成功
- ✅ 已注入角色名称

### 步骤 4: 部署到云端

1. 将修改后的 `character-config.json` 上传到华为云函数的代码包中
2. 重新部署云函数（或等待自动同步）

### 步骤 5: 在应用中测试

1. 打开应用，进入「今日漫画」页面
2. 生成漫画
3. 观察生成的图片是否符合角色设定

## 工作原理

### 1. 漫画脚本生成时 (llm-comic-script.js)

```
原始提示词 + 角色设定（名字、外观、性格）
    ↓
DeepSeek LLM 生成 5 格分镜脚本
    ↓
每个分镜的 prompt 包含主人公描述
```

### 2. 图片生成时 (image-generate.js)

```
分镜 prompt + 角色风格关键词
    ↓
（可选）+ 主角图/场景参考图 URL（Ark image 字段）
    ↓
豆包图像生成 API
    ↓
风格统一的漫画图片
```

## 提示与技巧

### 写好 appearance 描述

✅ **好的描述**：
```
"young woman with shoulder-length wavy brown hair, bright hazel eyes, 
wearing a cream turtleneck sweater and round glasses, gentle smile, 
slim build, early 20s"
```

❌ **不好的描述**：
```
"一个女孩"  // 太模糊
"very beautiful perfect face"  // 太泛化
```

### 风格关键词选择

根据你想要的画风添加：

- **温馨风格**: `soft lighting, warm colors, cozy atmosphere`
- **活力风格**: `bright colors, dynamic pose, energetic`
- **文艺风格**: `muted colors, artistic composition, introspective mood`
- **日系动漫**: `anime style, cel shading, expressive eyes`

### 参考图建议

- 使用**正面照或 3/4 侧面照**
- 背景简单干净
- 光线充足
- 如果有多套常穿服装，可以准备多个配置文件备用

## 故障排查

### 问题：生成的图片还是很随机

**可能原因**：
1. 配置文件未正确部署到云端
2. `useCharacterReference` 参数未生效
3. appearance 描述不够具体

**解决方法**：
1. 检查云函数代码包是否包含 `character-config.json`
2. 查看云函数日志，确认配置加载成功
3. 增强 appearance 描述的细节

### 问题：参考图不生效

**可能原因**：
1. 参考图 URL 无效或无法访问
2. 豆包 API 不支持参考图参数

**解决方法**：
1. 验证 URL 可以直接访问
2. 查看云函数日志中的 API 请求参数
3. 如果 API 不支持，依靠详细的文本描述也能达到较好效果

### 问题：报错"配置文件加载失败"

**可能原因**：
1. `character-config.json` 格式错误
2. 文件不在云函数目录中

**解决方法**：
1. 用 JSON 验证工具检查语法
2. 确认文件路径正确
3. 本地运行 `node test-character-config.js` 验证

## 示例配置

### 示例 1: 清新文艺风格

```json
{
  "character": {
    "name": "小悦",
    "appearance": "young woman with long straight black hair, almond-shaped eyes, wearing round glasses and oversized cardigan, holding a book",
    "traits": ["thoughtful", "quiet", "creative"],
    "styleKeywords": "soft natural lighting, muted earth tones, minimalist background, gentle expression",
    "referenceImageUrl": ""
  },
  "visualStyle": {
    "artStyle": "soft watercolor illustration, minimalist style",
    "colorPalette": "beige, soft brown, muted green, cream white",
    "mood": "peaceful, introspective, literary",
    "composition": "medium shots, natural poses, everyday moments"
  }
}
```

### 示例 2: 活力少女风格

```json
{
  "character": {
    "name": "莉莉",
    "appearance": "teenage girl with short bob haircut, bright blue eyes, wearing colorful hoodie and sneakers, energetic smile",
    "traits": ["energetic", "optimistic", "adventurous"],
    "styleKeywords": "bright vibrant colors, dynamic lighting, cheerful atmosphere, urban setting",
    "referenceImageUrl": ""
  },
  "visualStyle": {
    "artStyle": "modern anime style, cel-shaded, bold outlines",
    "colorPalette": "bright primary colors, high saturation, clean whites",
    "mood": "energetic, fun, youthful, positive",
    "composition": "dynamic angles, action shots, expressive gestures"
  }
}
```

## 总结

配置好角色设定后，每次生成漫画都会：
1. ✅ 主人公形象统一
2. ✅ 画风和色调一致
3. ✅ 符合角色性格设定
4. ✅ 保持故事连贯性

现在你可以开始配置你的专属角色了！
