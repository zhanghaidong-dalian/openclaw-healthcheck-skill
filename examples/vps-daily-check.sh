#!/bin/bash
# vps-daily-check.sh - VPS 每日巡检脚本
# 适用场景: VPS 云服务器日常安全巡检
# 使用方法: ./vps-daily-check.sh

set -e

echo "================================================"
echo "🔍 VPS 每日安全巡检"
echo "================================================"
echo ""
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "主机: $(hostname)"
echo ""

# 创建报告目录
REPORT_DIR="/tmp/vps-security-reports"
mkdir -p "$REPORT_DIR"

# 生成报告文件名
REPORT_FILE="$REPORT_DIR/report-$(date +%Y%m%d).json"

echo "📊 开始扫描..."
echo ""

# 执行轻量级扫描
if ./bin/healthcheck --quick --output json "$REPORT_FILE" 2>/dev/null; then
    echo "✅ 扫描完成"
else
    echo "⚠️ 扫描遇到问题，使用控制台模式"
    ./bin/healthcheck --quick
fi

echo ""
echo "================================================"
echo "📋 关键安全指标检查"
echo "================================================"
echo ""

# 关键项检查
./bin/healthcheck --check firewall 2>/dev/null || echo "⚠️ 防火墙检查跳过"
echo ""

./bin/healthcheck --check ssh 2>/dev/null || echo "⚠️ SSH 检查跳过"
echo ""

./bin/healthcheck --check updates 2>/dev/null || echo "⚠️ 系统更新检查跳过"
echo ""

echo "================================================"
echo "📊 巡检完成"
echo "================================================"
echo ""
echo "📁 报告位置: $REPORT_FILE"
echo ""

# 显示报告摘要
if [ -f "$REPORT_FILE" ]; then
    echo "📊 报告摘要:"
    cat "$REPORT_FILE" | grep -E '"passed"|"warning"|"failed"' | head -5
fi

echo ""
echo "💡 建议:"
echo "  - 每天执行此脚本进行日常巡检"
echo "  - 定期执行深度扫描: ./bin/healthcheck --deep"
echo "  - 查看完整报告: cat $REPORT_FILE"
echo ""
