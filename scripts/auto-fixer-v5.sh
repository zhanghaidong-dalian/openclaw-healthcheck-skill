#========================================
# 自动化修复系统 v5.0.0
# 版本: 5.0.0
#========================================

#!/bin/bash

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志文件
LOG_DIR="/tmp/openclaw-auto-fix"
LOG_FILE="${LOG_DIR}/fix-$(date +%Y%m%d-%H%M%S).log"
BACKUP_DIR="${LOG_DIR}/backups"

# 创建日志目录
mkdir -p "${LOG_DIR}"
mkdir -p "${BACKUP_DIR}"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# 错误函数
error() {
    echo -e "${RED}[错误] $1${NC}" | tee -a "${LOG_FILE}"
}

# 成功函数
success() {
    echo -e "${GREEN}[成功] $1${NC}" | tee -a "${LOG_FILE}"
}

# 警告函数
warn() {
    echo -e "${YELLOW}[警告] $1${NC}" | tee -a "${LOG_FILE}"
}

# 信息函数
info() {
    echo -e "${BLUE}[信息] $1${NC}" | tee -a "${LOG_FILE}"
}

# 备份文件
backup_file() {
    local file="$1"
    local backup_path="${BACKUP_DIR}/$(basename ${file})-$(date +%Y%m%d-%H%M%S).bak"
    
    if [ -f "$file" ]; then
        cp -p "$file" "$backup_path"
        log "已备份: $file -> $backup_path"
        echo "$backup_path"
    fi
}

# 回滚函数
rollback() {
    local backup_file="$1"
    local original_file="$2"
    
    if [ -f "$backup_file" ]; then
        cp -p "$backup_file" "$original_file"
        success "已回滚: $original_file"
    else
        error "回滚失败: 备份文件不存在"
        return 1
    fi
}

#========================================
# 修复项目定义
#========================================

declare -A FIX_ITEMS=(
    ["openclaw-perms"]="修复OpenClaw文件权限"
    ["logging-perms"]="修复日志文件权限"
    ["gateway-config"]="修复Gateway配置"
    ["firewall-basics"]="基础防火墙配置"
    ["ssh-hardening"]="SSH安全加固"
    ["auto-updates"]="启用自动更新"
    ["fail2ban"]="安装配置fail2ban"
)

#========================================
# 修复函数
#========================================

fix_openclaw_permissions() {
    info "修复 OpenClaw 文件权限..."
    
    local config_dir="${HOME}/.openclaw"
    local errors=0
    
    # 创建配置目录（如果不存在）
    if [ ! -d "$config_dir" ]; then
        mkdir -p "$config_dir"
        log "已创建配置目录: $config_dir"
    fi
    
    # 修复目录权限
    chmod 700 "$config_dir" 2>/dev/null && success "配置目录权限: $config_dir (700)" || { error "无法设置目录权限"; ((errors++)); }
    
    # 修复配置文件权限
    if [ -f "${config_dir}/gateway.yml" ]; then
        chmod 600 "${config_dir}/gateway.yml" 2>/dev/null && success "配置文件权限: gateway.yml (600)" || { error "无法设置配置文件权限"; ((errors++)); }
    fi
    
    # 修复日志目录
    local logs_dir="${config_dir}/logs"
    if [ -d "$logs_dir" ]; then
        chmod 750 "$logs_dir" 2>/dev/null && success "日志目录权限: $logs_dir (750)" || { error "无法设置日志目录权限"; ((errors++)); }
        
        # 修复日志文件
        find "$logs_dir" -name "*.log" -exec chmod 640 {} \; 2>/dev/null
    fi
    
    # 修复数据库文件
    if [ -f "${config_dir}/gateway.db" ]; then
        chmod 600 "${config_dir}/gateway.db" 2>/dev/null && success "数据库文件权限: gateway.db (600)" || { error "无法设置数据库文件权限"; ((errors++)); }
    fi
    
    if [ $errors -eq 0 ]; then
        success "OpenClaw 权限修复完成"
        return 0
    else
        error "OpenClaw 权限修复完成，但有 $errors 个错误"
        return 1
    fi
}

fix_logging_permissions() {
    info "修复日志文件权限..."
    
    local logs_dirs=(
        "${HOME}/.openclaw/logs"
        "/var/log/openclaw"
    )
    
    for logs_dir in "${logs_dirs[@]}"; do
        if [ -d "$logs_dir" ]; then
            # 修复目录权限
            chmod 750 "$logs_dir" 2>/dev/null
            
            # 修复日志文件权限
            find "$logs_dir" -name "*.log" -exec chmod 640 {} \; 2>/dev/null
            
            success "已修复: $logs_dir"
        fi
    done
    
    success "日志权限修复完成"
}

fix_gateway_config() {
    info "修复 Gateway 配置..."
    
    local config_dir="${HOME}/.openclaw"
    local config_file="${config_dir}/gateway.yml"
    
    # 备份原配置
    if [ -f "$config_file" ]; then
        backup_file "$config_file"
    fi
    
    # 创建默认配置（如果不存在）
    if [ ! -f "$config_file" ]; then
        cat > "$config_file" << 'EOF'
# OpenClaw Gateway 配置
# 生成时间: $(date +%Y-%m-%d)

gateway:
  bind: localhost
  port: 18888
  
logging:
  level: info
  file: ~/.openclaw/logs/gateway.log
  
security:
  requireDeviceAuth: true
EOF
        chmod 600 "$config_file"
        success "已创建默认配置: $config_file"
    else
        # 检查必要配置项
        if grep -q "requireDeviceAuth" "$config_file"; then
            success "安全配置已启用"
        else
            warn "建议启用 requireDeviceAuth"
        fi
    fi
}

fix_firewall_basics() {
    info "配置基础防火墙规则..."
    
    # 检测防火墙类型
    if command -v ufw &> /dev/null; then
        info "使用 UFW 防火墙"
        
        # 确保UFW已启用
        if ! ufw status | grep -q "Status: active"; then
            echo "即将启用 UFW 防火墙 (将只允许 SSH、80、443 端口)"
            read -p "继续? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                ufw default deny incoming
                ufw default allow outgoing
                ufw allow 22/tcp comment 'SSH'
                ufw allow 80/tcp comment 'HTTP'
                ufw allow 443/tcp comment 'HTTPS'
                ufw --force enable
                success "UFW 防火墙已启用"
            fi
        else
            success "UFW 防火墙已启用"
        fi
        
    elif command -v firewall-cmd &> /dev/null; then
        info "使用 firewalld"
        
        if systemctl is-active --quiet firewalld; then
            success "firewalld 已运行"
            firewall-cmd --list-all
        fi
        
    elif command -v iptables &> /dev/null; then
        info "使用 iptables (需要 root 权限)"
        warn "请手动运行: sudo iptables -L"
    else
        warn "未检测到防火墙"
    fi
}

fix_ssh_hardening() {
    info "SSH 安全加固..."
    
    local sshd_config="/etc/ssh/sshd_config"
    
    if [ ! -f "$sshd_config" ]; then
        warn "SSH 配置文件不存在，跳过"
        return 0
    fi
    
    # 备份
    backup_file "$sshd_config"
    
    # 检查当前配置
    local changes=0
    
    # 禁用 root 登录
    if grep -q "^PermitRootLogin yes" "$sshd_config"; then
        sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' "$sshd_config"
        success "已禁用 root SSH 登录"
        ((changes++))
    fi
    
    # 禁用密码认证（如果存在密钥）
    if [ -d "${HOME}/.ssh" ] && ls "${HOME}/.ssh"/*.pub &> /dev/null; then
        if grep -q "^PasswordAuthentication yes" "$sshd_config"; then
            sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' "$sshd_config"
            success "已禁用密码认证"
            ((changes++))
        fi
    fi
    
    # 禁用空密码
    if grep -q "^PermitEmptyPasswords yes" "$sshd_config"; then
        sed -i 's/^PermitEmptyPasswords yes/PermitEmptyPasswords no/' "$sshd_config"
        success "已禁用空密码"
        ((changes++))
    fi
    
    # 设置 SSH 协议版本 2
    if grep -q "^Protocol 1" "$sshd_config"; then
        sed -i 's/^Protocol 1/Protocol 2/' "$sshd_config"
        success "已设置 SSH 协议版本 2"
        ((changes++))
    fi
    
    if [ $changes -gt 0 ]; then
        info "SSH 配置已更新，请重启 SSH 服务: sudo systemctl restart sshd"
        success "SSH 加固完成"
    else
        success "SSH 配置已符合安全标准"
    fi
}

enable_auto_updates() {
    info "启用自动安全更新..."
    
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        info "检测到 Debian/Ubuntu 系统"
        
        # 安装 unattended-upgrades
        if ! command -v unattended-upgrades &> /dev/null; then
            info "安装 unattended-upgrades..."
            apt-get update && apt-get install -y unattended-upgrades
        fi
        
        # 启用
        dpkg-reconfigure -plow unattended-upgrades
        
        success "自动更新已启用"
        
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        info "检测到 RHEL/CentOS 系统"
        
        yum install -y dnf-automatic
        systemctl enable dnf-automatic.timer
        
        success "自动更新已启用"
        
    elif command -v brew &> /dev/null; then
        # macOS
        info "检测到 macOS 系统"
        
        # Homebrew 自动更新
        if command -v brew &> /dev/null; then
            brew autoupdate start 3600 --cleanup
            success "Homebrew 自动更新已启用"
        fi
        
    else
        warn "未检测到支持的包管理器"
    fi
}

install_fail2ban() {
    info "安装和配置 fail2ban..."
    
    if command -v fail2ban-client &> /dev/null; then
        success "fail2ban 已安装"
    else
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y fail2ban
        elif command -v yum &> /dev/null; then
            yum install -y fail2ban
        else
            warn "无法安装 fail2ban: 不支持的包管理器"
            return 1
        fi
    fi
    
    # 创建 OpenClaw 专用配置
    cat > /etc/fail2ban/jail.d/openclaw.conf << 'EOF'
[openclaw-ssh]
enabled = true
port = ssh
filter = openclaw-ssh
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
findtime = 600

[openclaw-gateway]
enabled = true
port = 18888
filter = openclaw-gateway
logpath = ~/.openclaw/logs/gateway.log
maxretry = 10
bantime = 1800
findtime = 300
EOF
    
    systemctl enable fail2ban 2>/dev/null || true
    systemctl restart fail2ban 2>/dev/null || true
    
    success "fail2ban 已配置并启动"
}

#========================================
# 主菜单
#========================================

show_menu() {
    clear
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║     🔒 OpenClaw 自动化修复系统 v5.0.0        ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
    echo "  请选择要执行的操作："
    echo ""
    echo "  [1] 修复 OpenClaw 文件权限"
    echo "  [2] 修复日志文件权限"
    echo "  [3] 修复 Gateway 配置"
    echo "  [4] 基础防火墙配置"
    echo "  [5] SSH 安全加固"
    echo "  [6] 启用自动安全更新"
    echo "  [7] 安装配置 fail2ban"
    echo "  [8] 运行所有修复（推荐）"
    echo "  [9] 查看修复日志"
    echo "  [0] 退出"
    echo ""
}

show_status() {
    echo ""
    echo "══════════════════════════════════════════════════"
    echo "  📊 当前安全状态"
    echo "══════════════════════════════════════════════════"
    echo ""
    
    # OpenClaw 权限
    if [ -d "${HOME}/.openclaw" ]; then
        perms=$(stat -c "%a" "${HOME}/.openclaw" 2>/dev/null || echo "未知")
        echo "  OpenClaw 配置目录: ${HOME}/.openclaw"
        echo "  权限: $perms $([ "$perms" = "700" ] && echo '✅' || echo '❌')"
    else
        echo "  OpenClaw 配置目录: ❌ 不存在"
    fi
    
    echo ""
    echo "══════════════════════════════════════════════════"
    echo ""
}

#========================================
# 主程序
#========================================

main() {
    local choice
    
    while true; do
        show_menu
        show_status
        
        read -p "请输入选项 [0-9]: " choice
        
        case $choice in
            1)
                fix_openclaw_permissions
                read -p "按 Enter 继续..."
                ;;
            2)
                fix_logging_permissions
                read -p "按 Enter 继续..."
                ;;
            3)
                fix_gateway_config
                read -p "按 Enter 继续..."
                ;;
            4)
                fix_firewall_basics
                read -p "按 Enter 继续..."
                ;;
            5)
                fix_ssh_hardening
                read -p "按 Enter 继续..."
                ;;
            6)
                enable_auto_updates
                read -p "按 Enter 继续..."
                ;;
            7)
                install_fail2ban
                read -p "按 Enter 继续..."
                ;;
            8)
                info "开始运行所有修复..."
                fix_openclaw_permissions
                fix_logging_permissions
                fix_gateway_config
                success "所有修复完成！"
                echo ""
                echo "📋 修复日志: ${LOG_FILE}"
                echo "📦 备份目录: ${BACKUP_DIR}"
                read -p "按 Enter 继续..."
                ;;
            9)
                if [ -f "$LOG_FILE" ]; then
                    less "$LOG_FILE"
                else
                    info "暂无修复日志"
                fi
                ;;
            0)
                info "再见！"
                exit 0
                ;;
            *)
                error "无效选项，请重试"
                sleep 1
                ;;
        esac
    done
}

# 交互模式
if [ "$1" = "--auto" ]; then
    # 自动模式（无人值守）
    info "自动模式：执行所有安全修复..."
    fix_openclaw_permissions
    fix_logging_permissions
    fix_gateway_config
    success "自动修复完成"
else
    # 交互模式
    main
fi
