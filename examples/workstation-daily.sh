#!/bin/bash
# workstation-daily.sh - 工作站日常安全检查脚本
# 适用场景: 个人电脑/工作站日常安全巡检
# 使用方法: ./workstation-daily.sh

set -e

echo "================================================"
echo "🖥️ 工作站日常安全检查"
echo "================================================"
echo ""
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "主机: $(hostname)"
echo ""

# 快速扫描
echo "🔍 执行快速安全扫描..."
./bin/healthcheck --quick --summary

echo ""

# 关键检查项
echo "================================================"
echo "📋 关键检查项"
echo "================================================"
echo ""

# 系统更新
echo "📦 系统更新状态:"
./bin/healthcheck --check updates 2>/dev/null || echo "⚠️ 系统更新检查跳过"
echo ""

# SSH 配置
echo "🔐 SSH 配置:"
./bin/healthcheck --check ssh 2>/dev/null || echo "⚠️ SSH 检查跳过"
echo ""

# 日志配置
echo "📋 日志配置:"
./bin/healthcheck --check logging 2>/dev/null || echo "⚠️ 日志检查跳过"
echo ""

echo "================================================"
echo "✅ 工作站检查完成"
echo "================================================"
echo ""
echo "💡 建议:"
echo "  - 每天执行此脚本进行日常巡检"
echo "  - 定期执行深度扫描: ./bin/healthcheck --deep"
echo "  - 保持系统更新"
echo ""
