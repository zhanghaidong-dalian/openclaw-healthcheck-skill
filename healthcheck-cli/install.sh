#!/bin/bash
#
# HealthCheck CLI Tool 安装脚本
# 版本: v5.0.0
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="healthcheck"

echo "========================================="
echo "  HealthCheck CLI Tool 安装程序"
echo "  版本: v5.0.0"
echo "========================================="
echo ""

# 检查Python是否安装
if ! command -v python3 &> /dev/null; then
    echo "❌ 错误: 未找到 python3"
    echo "   请先安装 Python 3.6 或更高版本"
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo "✓ Python版本: $PYTHON_VERSION"

# 检查是否有root权限
if [ "$EUID" -ne 0 ]; then
    echo ""
    echo "⚠️  注意: 安装需要root权限"
    echo "   使用 sudo 运行此脚本"
    exit 1
fi

echo ""
echo "正在安装..."
echo ""

# 检查目标文件是否存在
if [ -f "$INSTALL_DIR/$BINARY_NAME" ]; then
    echo "⚠️  警告: $BINARY_NAME 已存在于 $INSTALL_DIR"
    read -p "是否覆盖? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "✗ 安装取消"
        exit 1
    fi
    # 备份旧版本
    BACKUP_FILE="$INSTALL_DIR/$BINARY_NAME.backup"
    echo "→ 备份旧版本到: $BACKUP_FILE"
    mv "$INSTALL_DIR/$BINARY_NAME" "$BACKUP_FILE"
fi

# 复制文件
echo "→ 复制文件到 $INSTALL_DIR/$BINARY_NAME"
cp "$SCRIPT_DIR/healthcheck.py" "$INSTALL_DIR/$BINARY_NAME"

# 添加执行权限
echo "→ 添加执行权限"
chmod +x "$INSTALL_DIR/$BINARY_NAME"

# 验证安装
echo ""
echo "验证安装..."
if "$INSTALL_DIR/$BINARY_NAME" --version &> /dev/null; then
    echo "✓ 安装成功！"
    echo ""
    echo "========================================="
    echo "  安装完成！"
    echo "========================================="
    echo ""
    echo "使用方法:"
    echo "  $BINARY_NAME --help"
    echo "  $BINARY_NAME --mode quick"
    echo "  $BINARY_NAME --mode deep"
    echo ""
    echo "完整文档: $SCRIPT_DIR/USAGE.md"
    echo ""
else
    echo "✗ 安装失败"
    echo "   请检查错误信息并重试"
    exit 1
fi
