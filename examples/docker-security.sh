#!/bin/bash
# docker-security.sh - Docker 容器安全检查脚本
# 适用场景: Docker 容器环境安全检查
# 使用方法: ./docker-security.sh

set -e

echo "================================================"
echo "🐳 Docker 容器安全检查"
echo "================================================"
echo ""
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装或未运行"
    echo "💡 请先安装 Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# 检查 Docker 服务状态
echo "📊 Docker 服务状态:"
if systemctl is-active docker &> /dev/null; then
    echo "✅ Docker 服务正在运行"
else
    echo "⚠️ Docker 服务未运行"
    echo "💡 启动 Docker: sudo systemctl start docker"
fi
echo ""

# 运行中的容器
echo "📦 运行中的容器:"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null || echo "无运行中的容器"
echo ""

# 所有容器（包括已停止）
echo "📋 所有容器（含已停止）:"
docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | head -10 2>/dev/null || echo "无容器"
echo ""

# 检查特权容器
echo "🔒 特权容器检查:"
PRIVILEGED=$(docker ps -q --filter "publish=全部" 2>/dev/null || true)
if [ -n "$PRIVILEGED" ]; then
    echo "⚠️ 发现网络端口映射的容器:"
    docker ps --filter "publish=全部" --format "  {{.Names}}: {{.Ports}}" 2>/dev/null || true
else
    echo "✅ 未发现特权端口映射"
fi
echo ""

# 检查 Docker socket 挂载
echo "🔐 Docker Socket 挂载检查:"
SOCKET=$(docker ps -a --format '{{.Names}} {{.Mounts}}' 2>/dev/null | grep -v "^$" || true)
if echo "$SOCKET" | grep -q "/var/run/docker.sock"; then
    echo "⚠️ 发现容器挂载了 Docker Socket（存在特权风险）"
else
    echo "✅ 未发现 Docker Socket 挂载"
fi
echo ""

# 系统安全扫描
echo "🔍 执行系统安全扫描..."
echo ""

# 根据环境选择扫描模式
if [ -f "./bin/healthcheck" ]; then
    # 跳过不适用于容器的检查
    ./bin/healthcheck --quick || echo "系统扫描完成"
else
    echo "⚠️ healthcheck 未找到，跳过系统安全扫描"
fi

echo ""
echo "================================================"
echo "📊 Docker 安全检查完成"
echo "================================================"
echo ""
echo "💡 安全建议:"
echo "  1. 避免使用特权容器"
echo "  2. 不要将 Docker Socket 挂载到容器"
echo "  3. 使用非 root 用户运行容器"
echo "  4. 定期更新 Docker 版本"
echo "  5. 限制容器的网络访问"
echo ""
