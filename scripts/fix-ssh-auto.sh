#!/bin/bash
#
# OpenClaw 安全技能 - SSH 自动加固脚本
# 功能：一键修复 SSH 安全配置
# 版本：5.2.0
# 更新：2026-05-13
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_DIR="/var/backup/healthcheck"
BACKUP_FILE="$BACKUP_DIR/sshd_config.$(date +%Y%m%d_%H%M%S).bak"

# 帮助信息
show_help() {
    cat << EOF
OpenClaw SSH 自动加固工具 v5.2.0

用法: sudo $0 [选项]

选项:
    --disable-root        禁用 root 登录
    --disable-password    禁用密码认证（强制密钥登录）
    --change-port PORT    修改 SSH 端口
    --all                 执行所有加固操作
    --dry-run             仅显示将要修改的内容
    --rollback            回滚到上次备份
    -h, --help            显示帮助信息

示例:
    sudo $0 --all
    sudo $0 --disable-root --disable-password
    sudo $0 --change-port 2222
    sudo $0 --rollback

EOF
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要 root 权限${NC}"
        echo "请使用: sudo $0 $@"
        exit 1
    fi
}

# 备份配置文件
backup_config() {
    mkdir -p "$BACKUP_DIR"
    cp "$SSHD_CONFIG" "$BACKUP_FILE"
    echo -e "${GREEN}✓${NC} 配置已备份到: ${BLUE}$BACKUP_FILE${NC}"
}

# 显示当前配置
show_current_config() {
    echo -e "\n${BLUE}当前 SSH 配置:${NC}"
    echo "----------------------------------------"
    grep -E "^(PermitRootLogin|PasswordAuthentication|Port)" "$SSHD_CONFIG" 2>/dev/null || echo "未找到相关配置"
    echo "----------------------------------------"
}

# 禁用 root 登录
disable_root_login() {
    echo -e "${YELLOW}→ 禁用 root 登录...${NC}"
    
    if grep -q "^PermitRootLogin" "$SSHD_CONFIG"; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    elif grep -q "^#PermitRootLogin" "$SSHD_CONFIG"; then
        sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    else
        echo "PermitRootLogin no" >> "$SSHD_CONFIG"
    fi
    
    echo -e "${GREEN}✓${NC} 已禁用 root 登录"
}

# 禁用密码认证
disable_password_auth() {
    echo -e "${YELLOW}→ 禁用密码认证...${NC}"
    
    # 警告：确保已配置 SSH 密钥
    if [[ ! -f ~/.ssh/authorized_keys ]] && [[ ! -f /root/.ssh/authorized_keys ]]; then
        echo -e "${RED}警告: 未检测到 SSH 密钥！禁用密码认证可能导致无法登录！${NC}"
        echo -e "${YELLOW}请先配置 SSH 密钥: ssh-copy-id user@server${NC}"
        read -p "是否继续？(yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "已取消操作"
            return 1
        fi
    fi
    
    if grep -q "^PasswordAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
    elif grep -q "^#PasswordAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
    else
        echo "PasswordAuthentication no" >> "$SSHD_CONFIG"
    fi
    
    echo -e "${GREEN}✓${NC} 已禁用密码认证"
}

# 修改 SSH 端口
change_ssh_port() {
    local new_port=$1
    
    if [[ -z "$new_port" ]]; then
        echo -e "${RED}错误: 必须指定端口号${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}→ 修改 SSH 端口为 $new_port...${NC}"
    
    if grep -q "^Port" "$SSHD_CONFIG"; then
        sed -i "s/^Port.*/Port $new_port/" "$SSHD_CONFIG"
    elif grep -q "^#Port" "$SSHD_CONFIG"; then
        sed -i "s/^#Port.*/Port $new_port/" "$SSHD_CONFIG"
    else
        echo "Port $new_port" >> "$SSHD_CONFIG"
    fi
    
    echo -e "${GREEN}✓${NC} SSH 端口已修改为 $new_port"
    echo -e "${YELLOW}⚠️  请记得更新防火墙规则！${NC}"
    echo -e "${YELLOW}   例如: sudo ufw allow $new_port/tcp${NC}"
}

# 验证配置
validate_config() {
    echo -e "\n${BLUE}验证 SSH 配置...${NC}"
    
    if sshd -t 2>/dev/null; then
        echo -e "${GREEN}✓${NC} 配置语法正确"
        return 0
    else
        echo -e "${RED}✗${NC} 配置语法错误！"
        return 1
    fi
}

# 重启 SSH 服务
restart_sshd() {
    echo -e "\n${BLUE}重启 SSH 服务...${NC}"
    
    if systemctl restart sshd 2>/dev/null; then
        echo -e "${GREEN}✓${NC} SSH 服务已重启"
    elif systemctl restart ssh 2>/dev/null; then
        echo -e "${GREEN}✓${NC} SSH 服务已重启"
    elif service ssh restart 2>/dev/null; then
        echo -e "${GREEN}✓${NC} SSH 服务已重启"
    else
        echo -e "${RED}✗${NC} 无法重启 SSH 服务"
        return 1
    fi
}

# 回滚配置
rollback_config() {
    echo -e "${BLUE}查找备份文件...${NC}"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo -e "${RED}错误: 备份目录不存在${NC}"
        exit 1
    fi
    
    local latest_backup=$(ls -t "$BACKUP_DIR"/sshd_config.*.bak 2>/dev/null | head -1)
    
    if [[ -z "$latest_backup" ]]; then
        echo -e "${RED}错误: 未找到备份文件${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}找到备份: ${BLUE}$latest_backup${NC}"
    echo -e "\n备份内容预览:"
    echo "----------------------------------------"
    grep -E "^(PermitRootLogin|PasswordAuthentication|Port)" "$latest_backup" 2>/dev/null
    echo "----------------------------------------"
    
    read -p "确认回滚？(yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "已取消操作"
        exit 0
    fi
    
    cp "$latest_backup" "$SSHD_CONFIG"
    echo -e "${GREEN}✓${NC} 配置已回滚"
    
    validate_config && restart_sshd
}

# 显示修改后的配置
show_new_config() {
    echo -e "\n${BLUE}修改后的 SSH 配置:${NC}"
    echo "----------------------------------------"
    grep -E "^(PermitRootLogin|PasswordAuthentication|Port)" "$SSHD_CONFIG" 2>/dev/null || echo "未找到相关配置"
    echo "----------------------------------------"
}

# 解析参数
DRY_RUN=false
ACTION_ROOT=false
ACTION_PASSWORD=false
ACTION_PORT=""
ACTION_ALL=false
ACTION_ROLLBACK=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --disable-root)
            ACTION_ROOT=true
            shift
            ;;
        --disable-password)
            ACTION_PASSWORD=true
            shift
            ;;
        --change-port)
            ACTION_PORT="$2"
            shift 2
            ;;
        --all)
            ACTION_ALL=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --rollback)
            ACTION_ROLLBACK=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 主流程
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  OpenClaw SSH 自动加固 v5.2.0${NC}"
echo -e "${BLUE}========================================${NC}"

# 回滚模式
if [[ "$ACTION_ROLLBACK" == true ]]; then
    check_root
    rollback_config
    exit 0
fi

# 检查是否有操作
if [[ "$ACTION_ROOT" == false ]] && [[ "$ACTION_PASSWORD" == false ]] && [[ -z "$ACTION_PORT" ]] && [[ "$ACTION_ALL" == false ]]; then
    show_help
    exit 1
fi

# 检查权限
check_root "$@"

# 显示当前配置
show_current_config

# Dry run 模式
if [[ "$DRY_RUN" == true ]]; then
    echo -e "\n${YELLOW}[DRY RUN] 将执行以下操作:${NC}"
    [[ "$ACTION_ROOT" == true ]] || [[ "$ACTION_ALL" == true ]] && echo "  - 禁用 root 登录"
    [[ "$ACTION_PASSWORD" == true ]] || [[ "$ACTION_ALL" == true ]] && echo "  - 禁用密码认证"
    [[ -n "$ACTION_PORT" ]] && echo "  - 修改 SSH 端口为 $ACTION_PORT"
    exit 0
fi

# 备份配置
backup_config

# 执行加固
if [[ "$ACTION_ALL" == true ]]; then
    disable_root_login
    disable_password_auth
    change_ssh_port 2222
else
    [[ "$ACTION_ROOT" == true ]] && disable_root_login
    [[ "$ACTION_PASSWORD" == true ]] && disable_password_auth
    [[ -n "$ACTION_PORT" ]] && change_ssh_port "$ACTION_PORT"
fi

# 显示修改后的配置
show_new_config

# 验证配置
if validate_config; then
    echo -e "\n${YELLOW}⚠️  重要提示:${NC}"
    echo "1. 请确保已配置 SSH 密钥（如禁用密码认证）"
    echo "2. 请更新防火墙规则（如修改端口）"
    echo "3. 建议保持当前会话，另开终端测试连接"
    echo ""
    read -p "确认重启 SSH 服务？(yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        restart_sshd
        echo -e "\n${GREEN}✓${NC} SSH 加固完成！"
    else
        echo -e "\n${YELLOW}配置已修改但未重启服务${NC}"
        echo "手动重启: sudo systemctl restart sshd"
    fi
else
    echo -e "\n${RED}配置验证失败，未重启服务${NC}"
    echo "请检查配置文件: $SSHD_CONFIG"
fi

echo -e "\n${BLUE}========================================${NC}"
