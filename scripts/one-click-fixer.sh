#!/bin/bash
#================================================================
# one-click-fixer.sh - 一键自动修复脚本
# 完全实现用户反馈的一键修复功能需求
#================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="/tmp/healthcheck-backups/$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$SKILL_DIR/reports/fixer_$(date +%Y%m%d_%H%M%S).log"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DRY_RUN=false

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}✓${NC} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}✗${NC} $1" | tee -a "$LOG_FILE"; }

# 可修复问题列表
FIX_LIST="ssh-001:SSH允许密码登录
ssh-002:SSH允许root登录
ssh-005:SSH MaxAuthTries设置
firewall-001:防火墙未启用
firewall-002:默认入站规则
fail2ban-001:Fail2ban未安装
fail2ban-002:Fail2ban服务未启用
system-001:系统更新未检查
openclaw-001:OpenClaw配置权限"

# 修复命令
get_fix_cmd() {
    case "$1" in
        ssh-001) echo "sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && systemctl restart sshd" ;;
        ssh-002) echo "sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config && systemctl restart sshd" ;;
        ssh-005) echo "sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config && systemctl restart sshd" ;;
        firewall-001) echo "ufw --force enable && systemctl enable ufw" ;;
        firewall-002) echo "ufw default deny incoming" ;;
        fail2ban-001) echo "apt-get update && apt-get install -y fail2ban" ;;
        fail2ban-002) echo "systemctl enable fail2ban && systemctl start fail2ban" ;;
        system-001) echo "apt-get update && apt-get upgrade -y" ;;
        openclaw-001) echo "chmod 600 ~/.openclaw/config.yaml 2>/dev/null || true" ;;
        *) echo "" ;;
    esac
}

usage() {
    cat << 'EOF'
用法: one-click-fixer.sh [选项]

选项:
    --auto              自动模式 (无需确认)
    --dry-run           仅显示将要执行的修复
    --fix <问题ID>      只修复指定的问题
    --list              列出所有可修复的问题
    --help, -h          显示此帮助

示例:
    one-click-fixer.sh --auto
    one-click-fixer.sh --dry-run
    one-click-fixer.sh --list
EOF
}

show_list() {
    echo ""
    echo "可修复的安全问题:"
    printf "%-15s %-30s\n" "ID" "问题"
    printf "%s\n" "----------------------------------------"
    echo "$FIX_LIST" | while IFS=: read -r id desc; do
        printf "%-15s %-30s\n" "$id" "$desc"
    done
    echo ""
}

do_fix() {
    local id="$1"
    local cmd=$(get_fix_cmd "$id")
    
    if [ -z "$cmd" ]; then
        log_error "未知问题ID: $id"
        return 1
    fi
    
    echo ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "修复: $id"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "> $cmd"
    
    if [ "$DRY_RUN" = true ]; then
        log "[DRY-RUN] 未实际执行"
        return 0
    fi
    
    # 检查root权限
    needs_root=""
    case "$id" in
        ssh-*|firewall-*|fail2ban-*|system-*) needs_root="yes" ;;
    esac
    
    if [ "$needs_root" = "yes" ] && [ "$(id -u)" -ne 0 ]; then
        log_error "需要root权限，使用: echo '$cmd' | sudo bash"
        return 1
    fi
    
    # 备份
    case "$id" in
        ssh-*) cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.bak" 2>/dev/null || true ;;
    esac
    
    # 执行
    if eval "$cmd" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "修复成功"
    else
        log_error "修复失败"
        return 1
    fi
}

# 解析参数
AUTO=false
FIX_ID=""
SHOW_LIST=false

while [ $# -gt 0 ]; do
    case "$1" in
        --auto) AUTO=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --fix) FIX_ID="$2"; shift 2 ;;
        --list) SHOW_LIST=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) shift ;;
    esac
done

mkdir -p "$BACKUP_DIR" "$SKILL_DIR/reports"

if [ "$SHOW_LIST" = true ]; then
    show_list
    exit 0
fi

if [ -n "$FIX_ID" ]; then
    do_fix "$FIX_ID"
elif [ "$AUTO" = true ]; then
    log "自动模式: 修复所有可自动修复问题"
    echo "$FIX_LIST" | while IFS=: read -r id desc; do
        do_fix "$id" || true
    done
else
    usage
fi

log "日志: $LOG_FILE"
log "备份: $BACKUP_DIR"
