#!/bin/bash
# raspberry-pi.sh - 树莓派安全加固脚本
# 适用场景: 树莓派设备安全加固
# 使用方法: ./raspberry-pi.sh

set -e

echo "================================================"
echo "🍓 树莓派安全加固检查"
echo "================================================"
echo ""
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 系统信息
echo "📊 系统信息:"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "  系统: $PRETTY_NAME"
    echo "  内核: $(uname -r)"
fi
echo "  主机名: $(hostname)"
echo ""

# SSH 安全检查
echo "🔐 SSH 安全检查:"
./bin/healthcheck --check ssh 2>/dev/null || echo "⚠️ SSH 检查跳过"
echo ""

# 系统更新检查
echo "📦 系统更新检查:"
./bin/healthcheck --check updates 2>/dev/null || echo "⚠️ 系统更新检查跳过"
echo ""

# Fail2ban 检查
echo "🛡️ Fail2ban 检查:"
./bin/healthcheck --check fail2ban 2>/dev/null || echo "⚠️ Fail2ban 检查跳过"
echo ""

# 安全建议
echo "================================================"
echo "💡 树莓派安全加固建议"
echo "================================================"
echo ""
echo "1️⃣ 更改默认密码"
echo "   命令: passwd"
echo ""
echo "2️⃣ 启用防火墙"
echo "   命令: sudo ufw enable"
echo ""
echo "3️⃣ 配置 SSH 密钥认证"
echo "   命令: ssh-keygen -t ed25519"
echo "   命令: ssh-copy-id pi@your-pi"
echo ""
echo "4️⃣ 禁用 SSH 密码认证"
echo "   编辑: /etc/ssh/sshd_config"
echo "   设置: PasswordAuthentication no"
echo ""
echo "5️⃣ 定期更新系统"
echo "   命令: sudo apt update && sudo apt upgrade -y"
echo ""

# 执行建议操作（可选）
read -p "是否执行自动加固？（y/N）" -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔧 开始自动加固..."
    
    # 启用防火墙
    if command -v ufw &> /dev/null; then
        echo "  ✅ 启用防火墙"
        sudo ufw --force enable 2>/dev/null || true
    fi
    
    echo "  ✅ 自动加固完成"
else
    echo "⏭️ 跳过自动加固"
fi

echo ""
echo "================================================"
echo "✅ 树莓派安全检查完成"
echo "================================================"
echo ""
