#!/bin/bash

# 部署角色配置到华为云函数
# 使用方法：./deploy-config.sh

set -e

echo "=== 部署角色配置到华为云函数 ==="
echo ""

# 检查配置文件是否存在
if [ ! -f "character-config.json" ]; then
    echo "❌ 错误: character-config.json 不存在"
    echo "请先创建配置文件"
    exit 1
fi

# 验证 JSON 格式
echo "1. 验证配置文件格式..."
if node -e "JSON.parse(require('fs').readFileSync('character-config.json', 'utf8'))" 2>/dev/null; then
    echo "✅ JSON 格式正确"
else
    echo "❌ JSON 格式错误，请检查 character-config.json"
    exit 1
fi

# 运行测试
echo ""
echo "2. 运行配置测试..."
if node test-character-config.js > /tmp/test-output.txt 2>&1; then
    echo "✅ 配置测试通过"
    cat /tmp/test-output.txt | grep "✅" | head -5
else
    echo "❌ 配置测试失败"
    cat /tmp/test-output.txt
    exit 1
fi

# 提示下一步
echo ""
echo "=== 配置验证通过 ==="
echo ""
echo "📦 image-generate 部署包必须包含："
echo "   - image-generate.js"
echo "   - image-task-token.js"
echo "   - character-config.json"
echo "   - assets/protagonist.png"
echo "   - assets/scene-reference.png"
echo ""
echo "📤 部署步骤："
echo "1. 登录华为云控制台 https://console.huaweicloud.com"
echo "2. 进入 FunctionGraph (云函数服务)"
echo "3. 找到以下函数："
echo "   - llm-comic-script (漫画脚本生成)"
echo "   - image-generate (图片生成)"
echo "4. 点击「代码」标签"
echo "5. 将以上文件打成 ZIP 后上传到 image-generate 的代码包"
echo "6. 点击「保存」并等待部署完成"
echo ""
echo "✨ 或者使用华为云 CLI 自动部署（如果已配置）："
echo "   hcloud functiongraph function update --function-name llm-comic-script --code-file character-config.json"
echo "   hcloud functiongraph function update --function-name image-generate --code-file character-config.json"
echo ""
echo "🎨 配置完成后，打开应用测试漫画生成功能"
