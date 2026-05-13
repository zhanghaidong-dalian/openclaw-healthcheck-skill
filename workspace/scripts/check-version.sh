#!/bin/bash

# 版本号一致性检查脚本
# 用于确保 SKILL.md 的 version 字段与虾评平台版本号一致

SKILL_FILE="/workspace/projects/workspace/healthcheck-skill/SKILL.md"
SKILL_ID="61c9999f-1794-4f55-a6b8-6e457376b51e"
API_KEY="sk_N0wcqRIDDt_Py_rz8O7plGO8EKL1Lmmp"

echo "=== OpenClaw 安全工具 - 版本号一致性检查 ==="
echo ""

# 获取本地版本号
LOCAL_VERSION=$(grep "^version:" "$SKILL_FILE" | cut -d' ' -f2)
echo "📋 本地 SKILL.md version: $LOCAL_VERSION"

# 获取平台版本号
echo "🌐 虾评平台版本查询中..."
PLATFORM_VERSION=$(curl -s "https://xiaping.coze.site/api/skills/$SKILL_ID/versions" \
  -H "Authorization: Bearer $API_KEY" | jq -r '.data[0].version')
echo "   平台版本: $PLATFORM_VERSION"

# 比较版本号
echo ""
echo "=== 检查结果 ==="

if [ "$LOCAL_VERSION" = "$PLATFORM_VERSION" ]; then
    echo "✅ 版本号一致！"
    echo ""
    echo "版本信息:"
    echo "  - 平台版本: $PLATFORM_VERSION"
    echo "  - 本地 version: $LOCAL_VERSION"
    echo "  - 功能版本: v4.7.0 (Changelog)"
    echo "  - 状态: 一致 ✅"
    exit 0
else
    echo "❌ 版本号不一致！"
    echo ""
    echo "当前状态:"
    echo "  - 平台版本: $PLATFORM_VERSION"
    echo "  - 本地 version: $LOCAL_VERSION"
    echo ""
    echo "🔧 修复方法:"
    echo "  1. 更新 SKILL.md 的 version 字段为平台版本号"
    echo "  2. 确保格式为: version: $PLATFORM_VERSION"
    echo "  3. 重新验证"
    exit 1
fi
