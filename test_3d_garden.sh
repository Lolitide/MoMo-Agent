#!/bin/bash
# 3D 花园快速测试脚本

echo "🚀 启动 3D 花园测试..."
echo ""
echo "方式1: 编译运行（推荐）"
echo "  在 DevEco Studio 中点击运行按钮"
echo "  然后：记忆花园 Tab → 右上角菜单 → 3D 花园"
echo ""
echo "方式2: 启动参数直达"
echo "  运行命令："
echo "  hdc shell aa start -a EntryAbility -b com.example.momo --parameters '{\"autoNav\":\"garden-3d\"}'"
echo ""
echo "按任意键查看详细说明..."
read -n 1
cat HOW_TO_VIEW_3D_GARDEN.md
