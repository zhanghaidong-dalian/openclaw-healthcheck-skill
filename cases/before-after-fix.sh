#!/bin/bash
# before-after-fix.sh - 修复前后对比脚本
# 适用场景: 展示安全加固效果
# 使用方法: ./before-after-fix.sh

set -e

echo "================================================"
echo "🔄 安全加固 - 修复前后对比"
echo "================================================"
echo ""
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 创建报告目录
REPORT_DIR="/tmp/security-fix-comparison"
mkdir -p "$REPORT_DIR"

BEFORE_FILE="$REPORT_DIR/before-fix.txt"
AFTER_FILE="$REPORT_DIR/after-fix.txt"
DIFF_FILE="$REPORT_DIR/diff.txt"

echo "📸 第一步：修复前状态扫描"
echo "================================================"
echo ""

# 修复前扫描
./bin/healthcheck --quick --summary > "$BEFORE_FILE" 2>&1 || true
cat "$BEFORE_FILE"

echo ""
echo "📸 第二步：执行安全修复"
echo "================================================"
echo ""

# 执行修复
read -p "是否执行自动修复？（y/N）" -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔧 开始自动修复..."
    ./bin/healthcheck --auto-fix || echo "⚠️ 部分修复可能需要手动执行"
else
    echo "⏭️ 跳过自动修复，仅展示对比"
fi

echo ""
echo "⏳ 等待系统状态更新..."
sleep 3

echo ""
echo "📸 第三步：修复后状态扫描"
echo "================================================"
echo ""

# 修复后扫描
./bin/healthcheck --quick --summary > "$AFTER_FILE" 2>&1 || true
cat "$AFTER_FILE"

echo ""
echo "📊 第四步：修复前后对比"
echo "================================================"
echo ""

# 生成对比报告
{
    echo "# 安全加固修复对比报告"
    echo ""
    echo "## 修复前"
    echo '```'
    cat "$BEFORE_FILE"
    echo '```'
    echo ""
    echo "## 修复后"
    echo '```'
    cat "$AFTER_FILE"
    echo '```'
} > "$DIFF_FILE"

echo "📋 对比报告:"
echo ""
cat "$DIFF_FILE" | head -50

echo ""
echo "================================================"
echo "📁 详细报告已保存"
echo "================================================"
echo ""
echo "  📄 修复前: $BEFORE_FILE"
echo "  📄 修复后: $AFTER_FILE"
echo "  📄 对比报告: $DIFF_FILE"
echo ""

# 统计改善情况
if [ -f "$BEFORE_FILE" ] && [ -f "$AFTER_FILE" ]; then
    echo "📈 改善统计:"
    
    # 提取通过项数量
    BEFORE_PASS=$(grep -o "通过:[0-9]*" "$BEFORE_FILE" | head -1 | cut -d: -f2 || echo "0")
    AFTER_PASS=$(grep -o "通过:[0-9]*" "$AFTER_FILE" | head -1 | cut -d: -f2 || echo "0")
    
    echo "  修复前通过项: $BEFORE_PASS"
    echo "  修复后通过项: $AFTER_PASS"
    
    if [ "$AFTER_PASS" -gt "$BEFORE_PASS" ]; then
        echo "  ✅ 改善: +$((AFTER_PASS - BEFORE_PASS)) 项"
    else
        echo "  ℹ️ 无明显改善"
    fi
fi

echo ""
echo "💡 建议:"
echo "  - 定期执行此脚本监控安全状态"
echo "  - 使用深度扫描获得更详细结果: ./bin/healthcheck --deep"
echo ""
