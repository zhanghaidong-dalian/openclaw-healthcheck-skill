#!/bin/bash
# version: 4.9.0-dev
# ==============================================================================
# 增强版自动修复脚本 - auto-fixer-v2.sh
# 功能: 分级自动修复安全问题，支持备份和回滚
# 模式: --risk-level safe / standard / high
# ==============================================================================

# Home变量默认值处理（兼容沙盒环境）
: "${HOME:=/tmp}"

set -euo pipefail

# ---------------------------------------------
# 颜色定义
# ---------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# ---------------------------------------------
# 路径配置
# ---------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# 引入备份函数库
if [ -f "$SCRIPT_DIR/backup-functions.sh" ]; then
    source "$SCRIPT_DIR/backup-functions.sh"
fi

# ---------------------------------------------
# 全局配置
# ---------------------------------------------
RISK_LEVEL="safe"
BACKUP_DIR="${HOME}/.healthcheck/backups"
LOG_DIR="${HOME}/.healthcheck/logs"
LOG_FILE=""
ROLLBACK_FILE=""
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 统计
FIXED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0
WARN_COUNT=0

# 修复项追踪
declare -a FIXED_ITEMS=()
declare -a FAILED_ITEMS=()
declare -a SKIPPED_ITEMS=()

# 回滚记录
declare -a ROLLBACK_CMDS=()

# ---------------------------------------------
# 日志函数
# ---------------------------------------------
init_logging() {
    mkdir -p "$LOG_DIR"
    mkdir -p "$BACKUP_DIR"
    LOG_FILE="$LOG_DIR/auto-fix-$(date +%Y%m%d-%H%M%S).log"
    ROLLBACK_FILE="$LOG_DIR/rollback-$(date +%Y%m%d-%H%M%S).sh"

    echo "# 自动修复回滚脚本 - $TIMESTAMP" > "$ROLLBACK_FILE"
    echo "# 执行此脚本可撤销本次修复操作" >> "$ROLLBACK_FILE"
    echo "" >> "$ROLLBACK_FILE"
    chmod +x "$ROLLBACK_FILE"
}

log() {
    local level="$1"
    local msg="$2"
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] [$level] $msg" >> "$LOG_FILE"
}

log_info()   { echo -e "${BLUE}[INFO]${NC}  $1"; log "INFO" "$1"; }
log_ok()     { echo -e "${GREEN}[✓]${NC}  $1"; log "OK" "$1"; }
log_warn()   { echo -e "${YELLOW}[⚠]${NC}  $1"; log "WARN" "$1"; }
log_fail()   { echo -e "${RED}[✗]${NC}  $1"; log "FAIL" "$1"; }
log_skip()   { echo -e "${CYAN}[○]${NC}  $1"; log "SKIP" "$1"; }

# ---------------------------------------------
# 函数: 打印标题
# ---------------------------------------------
print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}🔧 OpenClaw 增强版自动修复  v2.0${NC}                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  风险级别: ${BOLD}$RISK_LEVEL${NC}                                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ---------------------------------------------
# 函数: 创建备份
# 功能: 备份目标文件并记录回滚命令
# ---------------------------------------------
backup_file() {
    local file="$1"
    local desc="${2:-备份}"

    if [ ! -f "$file" ]; then
        log_warn "备份跳过(文件不存在): $file"
        return 1
    fi

    # 创建备份目录
    local backup_subdir="$BACKUP_DIR/$TIMESTAMP"
    mkdir -p "$backup_subdir"

    # 备份文件
    local backup_path="$backup_subdir$(basename "$file").backup"
    cp "$file" "$backup_path"
    chmod 644 "$backup_path"

    # 记录回滚命令
    echo "# 回滚: $desc" >> "$ROLLBACK_FILE"
    echo "cp '$backup_path' '$file'" >> "$ROLLBACK_FILE"
    echo "" >> "$ROLLBACK_FILE"

    log_info "已备份: $file → $backup_path"
    return 0
}

# ---------------------------------------------
# 函数: 需要确认的修复（高风险）
# 功能: 对于高风险操作，需要用户二次确认
# ---------------------------------------------
require_confirm() {
    local desc="$1"
    local cmd="$2"

    echo ""
    echo -e "  ${YELLOW}⚠️  高风险操作确认${NC}"
    echo -e "  操作: ${RED}$desc${NC}"
    echo ""
    read -rp "  是否继续? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo "  已取消"
        return 1
    fi
    return 0
}

# ---------------------------------------------
# 函数: 修复 SSH 配置
# 功能: 禁用 root 登录和密码认证
# ---------------------------------------------
fix_ssh_config() {
    print_step "🔐 修复 SSH 配置"

    local sshd_config="/etc/ssh/sshd_config"
    local sshd_config_d="/etc/ssh/sshd_config.d"

    # 检查是否有写权限（需要 sudo）
    if [ ! -w "$sshd_config" ]; then
        log_warn "SSH 配置需要 root 权限，将使用 sudo"
        local use_sudo="sudo"
    else
        local use_sudo=""
    fi

    # 修复 1: 禁用 root 登录
    echo ""
    echo -e "  ${BLUE}检查 SSH root 登录...${NC}"

    if $use_sudo grep -qE "^PermitRootLogin" "$sshd_config" 2>/dev/null; then
        local current
        current=$($use_sudo grep "^PermitRootLogin" "$sshd_config" | head -1)
        if echo "$current" | grep -q "no"; then
            log_skip "SSH root 登录已禁用"
            SKIPPED_ITEMS+=("SSH root 登录已禁用")
        else
            backup_file "$sshd_config" "SSH root 登录配置"
            $use_sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "$sshd_config"
            log_ok "已禁用 SSH root 登录"
            FIXED_ITEMS+=("禁用 SSH root 登录")
            FIXED_COUNT=$((FIXED_COUNT + 1))
        fi
    else
        backup_file "$sshd_config" "SSH root 登录配置"
        echo "PermitRootLogin no" | $use_sudo tee -a "$sshd_config" >/dev/null
        log_ok "已添加: 禁用 SSH root 登录"
        FIXED_ITEMS+=("禁用 SSH root 登录")
        FIXED_COUNT=$((FIXED_COUNT + 1))
    fi

    # 修复 2: 禁用密码认证
    echo ""
    echo -e "  ${BLUE}检查 SSH 密码认证...${NC}"

    if $use_sudo grep -qE "^PasswordAuthentication" "$sshd_config" 2>/dev/null; then
        local current
        current=$($use_sudo grep "^PasswordAuthentication" "$sshd_config" | head -1)
        if echo "$current" | grep -q "no"; then
            log_skip "SSH 密码认证已禁用"
            SKIPPED_ITEMS+=("SSH 密码认证已禁用")
        else
            backup_file "$sshd_config" "SSH 密码认证配置"
            $use_sudo sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$sshd_config"
            log_ok "已禁用 SSH 密码认证"
            FIXED_ITEMS+=("禁用 SSH 密码认证")
            FIXED_COUNT=$((FIXED_COUNT + 1))
        fi
    else
        backup_file "$sshd_config" "SSH 密码认证配置"
        echo "PasswordAuthentication no" | $use_sudo tee -a "$sshd_config" >/dev/null
        log_ok "已添加: 禁用 SSH 密码认证"
        FIXED_ITEMS+=("禁用 SSH 密码认证")
        FIXED_COUNT=$((FIXED_COUNT + 1))
    fi

    # 验证 SSH 配置语法
    if $use_sudo sshd -t 2>/dev/null; then
        log_ok "SSH 配置语法正确"
    else
        log_warn "SSH 配置语法可能有问题，请检查"
        WARN_COUNT=$((WARN_COUNT + 1))
    fi
}

# ---------------------------------------------
# 函数: 配置防火墙
# 功能: 启用并配置 ufw 或 firewalld
# ---------------------------------------------
fix_firewall() {
    print_step "🔥 配置防火墙"

    echo ""
    echo -e "  ${BLUE}检测可用防火墙...${NC}"

    # 检查 ufw
    if command -v ufw >/dev/null 2>&1; then
        echo -e "  检测到: ${GREEN}UFW${NC}"

        if systemctl is-active --quiet ufw 2>/dev/null; then
            log_skip "UFW 已启用"
            SKIPPED_ITEMS+=("UFW 防火墙已启用")
        else
            echo -e "  ${BLUE}启用 UFW...${NC}"
            sudo ufw --force enable
            sudo ufw default deny incoming
            sudo ufw default allow outgoing
            log_ok "已启用 UFW 防火墙"
            FIXED_ITEMS+=("启用 UFW 防火墙")
            FIXED_COUNT=$((FIXED_COUNT + 1))
        fi

    # 检查 firewalld
    elif command -v firewall-cmd >/dev/null 2>&1; then
        echo -e "  检测到: ${GREEN}firewalld${NC}"

        if systemctl is-active --quiet firewalld 2>/dev/null; then
            log_skip "firewalld 已启用"
            SKIPPED_ITEMS+=("firewalld 已启用")
        else
            echo -e "  ${BLUE}启用 firewalld...${NC}"
            sudo systemctl enable firewalld
            sudo systemctl start firewalld
            sudo firewall-cmd --set-default-zone=drop
            log_ok "已启用 firewalld 防火墙"
            FIXED_ITEMS+=("启用 firewalld 防火墙")
            FIXED_COUNT=$((FIXED_COUNT + 1))
        fi

    else
        log_warn "未检测到 ufw 或 firewalld，跳过防火墙配置"
        WARN_COUNT=$((WARN_COUNT + 1))
    fi
}

# ---------------------------------------------
# 函数: 安装并配置 Fail2ban
# 功能: 防止暴力破解
# ---------------------------------------------
fix_fail2ban() {
    print_step "🛡️  安装/配置 Fail2ban"

    if command -v fail2ban-client >/dev/null 2>&1; then
        echo -e "  检测到: ${GREEN}Fail2ban 已安装${NC}"

        if systemctl is-active --quiet fail2ban 2>/dev/null; then
            log_skip "Fail2ban 服务已运行"
            SKIPPED_ITEMS+=("Fail2ban 已运行")
        else
            echo -e "  ${BLUE}启动 Fail2ban...${NC}"
            sudo systemctl enable fail2ban
            sudo systemctl start fail2ban
            log_ok "已启动 Fail2ban"
            FIXED_ITEMS+=("启动 Fail2ban")
            FIXED_COUNT=$((FIXED_COUNT + 1))
        fi
    else
        echo -e "  ${YELLOW}Fail2ban 未安装，尝试安装...${NC}"

        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update -qq
            sudo apt-get install -y fail2ban
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y fail2ban
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y fail2ban
        else
            log_warn "无法自动安装 Fail2ban，请手动安装"
            WARN_COUNT=$((WARN_COUNT + 1))
            return
        fi

        # 配置 Fail2ban
        if command -v fail2ban-client >/dev/null 2>&1; then
            sudo systemctl enable fail2ban
            sudo systemctl start fail2ban
            log_ok "已安装并启动 Fail2ban"
            FIXED_ITEMS+=("安装并启动 Fail2ban")
            FIXED_COUNT=$((FIXED_COUNT + 1))
        fi
    fi
}

# ---------------------------------------------
# 函数: 修复低风险项（standard 模式）
# 功能: 修复次要安全问题
# ---------------------------------------------
fix_low_risk_items() {
    print_step "🔓 修复低风险项 (standard)"

    # 1. 设置安全的文件权限
    echo ""
    echo -e "  ${BLUE}检查 SSH 密钥文件权限...${NC}"

    local ssh_dir="$HOME/.ssh"
    if [ -d "$ssh_dir" ]; then
        if [ "$(stat -c %a "$ssh_dir" 2>/dev/null)" != "700" ]; then
            chmod 700 "$ssh_dir"
            log_ok "已修正 .ssh 目录权限为 700"
            FIXED_ITEMS+=("修正 .ssh 目录权限")
            FIXED_COUNT=$((FIXED_COUNT + 1))
        fi

        # 修正 authorized_keys 权限
        if [ -f "$ssh_dir/authorized_keys" ]; then
            chmod 600 "$ssh_dir/authorized_keys"
            log_ok "已修正 authorized_keys 权限为 600"
            FIXED_ITEMS+=("修正 authorized_keys 权限")
            FIXED_COUNT=$((FIXED_COUNT + 1))
        fi
    fi

    # 2. 检查 /tmp 目录的 noexec 选项
    echo ""
    echo -e "  ${BLUE}检查 /tmp 挂载选项...${NC}"

    if mount | grep -q "on /tmp"; then
        if ! mount | grep "on /tmp" | grep -q "noexec"; then
            log_warn "/tmp 目录可能没有 noexec 选项（需要手动检查）"
            WARN_COUNT=$((WARN_COUNT + 1))
        else
            log_skip "/tmp 已设置 noexec"
        fi
    fi

    # 3. 检查系统更新
    echo ""
    echo -e "  ${BLUE}检查系统安全更新...${NC}"

    if command -v apt-get >/dev/null 2>&1; then
        local updates
        updates=$(apt-get -qq upgrade 2>&1 | grep -c "升级" || echo "0")
        if [ "$updates" -gt 0 ]; then
            log_warn "有 $updates 个安全更新可用，建议运行: sudo apt-get upgrade"
        else
            log_ok "系统已是最新版本"
        fi
    fi
}

# ---------------------------------------------
# 函数: 修复中风险项（high 模式）
# 功能: 修复需要二次确认的中风险项
# ---------------------------------------------
fix_medium_risk_items() {
    print_step "⚡ 修复中风险项 (high)"

    # 1. 设置密码策略
    echo ""
    echo -e "  ${BLUE}配置密码策略...${NC}"

    if command -v pam_passwdqc_test >/dev/null 2>&1 || [ -f /etc/security/pwquality.conf ]; then
        local pwquality="/etc/security/pwquality.conf"

        if [ -f "$pwquality" ]; then
            backup_file "$pwquality" "密码策略配置"

            # 设置最小密码长度
            if ! grep -q "^minlen" "$pwquality" 2>/dev/null; then
                echo "minlen = 12" | sudo tee -a "$pwquality" >/dev/null
            fi

            log_ok "已配置密码策略（最小长度 12）"
            FIXED_ITEMS+=("配置密码策略")
            FIXED_COUNT=$((FIXED_COUNT + 1))
        fi
    fi

    # 2. 禁用不必要的服务
    echo ""
    echo -e "  ${BLUE}检查不必要的网络服务...${NC}"

    local dangerous_services=("telnet" "ftp" "rsh" "rlogin" "rexec")
    for svc in "${dangerous_services[@]}"; do
        if command -v "$svc" >/dev/null 2>&1; then
            log_warn "检测到不安全的服务: $svc"
            echo "  建议手动禁用: sudo systemctl stop $svc && sudo systemctl disable $svc"
            WARN_COUNT=$((WARN_COUNT + 1))
        fi
    done

    # 3. 检查 OpenClaw 安全配置
    echo ""
    echo -e "  ${BLUE}检查 OpenClaw 安全配置...${NC}"

    local oc_config="${HOME}/.openclaw/config.json"
    if [ -f "$oc_config" ]; then
        if grep -q '"auth": "token"' "$oc_config" 2>/dev/null; then
            log_warn "OpenClaw 使用 token 认证，建议切换到更安全的方式"
            WARN_COUNT=$((WARN_COUNT + 1))
        fi
    fi
}

# ---------------------------------------------
# 函数: 执行回滚
# 功能: 根据时间戳回滚到指定备份
# ---------------------------------------------
rollback_backup() {
    local backup_ts="$1"
    local backup_path="$BACKUP_DIR/$backup_ts"

    if [ ! -d "$backup_path" ]; then
        echo -e "  ${RED}✗ 备份不存在: $backup_path${NC}"
        exit 1
    fi

    echo ""
    echo -e "  ${YELLOW}⚠️  开始回滚操作${NC}"
    echo "  备份时间: $backup_ts"
    echo ""

    # 执行备份目录中的回滚脚本
    local rollback_script="$LOG_DIR/rollback-$backup_ts.sh"
    if [ -f "$rollback_script" ]; then
        echo -e "  执行回滚脚本: ${CYAN}$rollback_script${NC}"
        bash "$rollback_script"
        echo ""
        echo -e "  ${GREEN}✅ 回滚完成${NC}"
    else
        echo -e "  ${RED}✗ 回滚脚本不存在，请手动恢复文件${NC}"
        echo "  备份文件位于: $backup_path"
    fi
}

# ---------------------------------------------
# 函数: 列出可用备份
# 功能: 展示所有备份及回滚脚本
# ---------------------------------------------
list_backups() {
    echo ""
    echo -e "  ${CYAN}可用备份列表：${NC}"
    echo ""

    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo "  暂无备份"
        return
    fi

    local i=1
    for dir in "$BACKUP_DIR"/*/; do
        if [ -d "$dir" ]; then
            local ts=$(basename "$dir")
            local files=$(ls "$dir" 2>/dev/null | wc -l)
            echo -e "  ${CYAN}[$i]${NC} $ts ($files 个文件)"
            i=$((i + 1))
        fi
    done

    echo ""
    echo "  使用方法:"
    echo "    bash $0 --rollback --backup=时间戳"
    echo ""
}

# ---------------------------------------------
# 函数: 打印修复报告
# 功能: 输出修复结果汇总
# ---------------------------------------------
print_report() {
    print_step "📊 修复报告"

    echo ""
    echo -e "  风险级别: ${BOLD}$RISK_LEVEL${NC}"
    echo -e "  执行时间: $TIMESTAMP"
    echo ""

    echo -e "  ${GREEN}✅ 已修复 ($FIXED_COUNT 项)${NC}"
    if [ ${#FIXED_ITEMS[@]} -gt 0 ]; then
        for item in "${FIXED_ITEMS[@]}"; do
            echo -e "    ├─ $item"
        done
    else
        echo -e "    └─ (无)"
    fi
    echo ""

    echo -e "  ${CYAN}○ 已跳过 (${#SKIPPED_ITEMS[@]} 项)${NC}"
    if [ ${#SKIPPED_ITEMS[@]} -gt 0 ]; then
        for item in "${SKIPPED_ITEMS[@]}"; do
            echo -e "    ├─ $item"
        done
    else
        echo -e "    └─ (无)"
    fi
    echo ""

    echo -e "  ${RED}✗ 失败 (${#FAILED_ITEMS[@]} 项)${NC}"
    if [ ${#FAILED_ITEMS[@]} -gt 0 ]; then
        for item in "${FAILED_ITEMS[@]}"; do
            echo -e "    ├─ $item"
        done
    else
        echo -e "    └─ (无)"
    fi
    echo ""

    echo -e "  ${YELLOW}⚠️  警告 ($WARN_COUNT 项)${NC}"
    echo ""

    echo -e "  ${BLUE}📁 日志文件:${NC} $LOG_FILE"
    echo -e "  ${BLUE}🔄 回滚脚本:${NC} $ROLLBACK_FILE"
    echo ""

    if [ -f "$ROLLBACK_FILE" ] && [ -s "$ROLLBACK_FILE" ]; then
        echo -e "  ${GREEN}✅ 如需回滚，请运行:${NC}"
        echo -e "    bash $ROLLBACK_FILE"
        echo ""
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ---------------------------------------------
# 函数: 显示帮助
# ---------------------------------------------
show_help() {
    cat << EOF
${CYAN}╔════════════════════════════════════════════════════════╗${NC}
${CYAN}║${NC}  🔧 OpenClaw 增强版自动修复 v2.0                    ${CYAN}║${NC}
${CYAN}╚════════════════════════════════════════════════════════╝${NC}

${BOLD}用法:${NC}
  bash $0 [选项]

${BOLD}选项:${NC}
  --risk-level <级别>    设置修复风险级别
    safe       仅修复明确安全项（防火墙/SSH/Fail2ban）
    standard   修复低风险项 + safe
    high       修复中风险项 + standard（需二次确认）

  --rollback --backup=<时间戳>  回滚到指定备份
  --list-backups             列出所有可用备份
  --help                     显示帮助信息

${BOLD}示例:${NC}
  bash $0 --risk-level safe
  bash $0 --risk-level standard
  bash $0 --risk-level high
  bash $0 --rollback --backup=20240101_120000
  bash $0 --list-backups

EOF
}

# ---------------------------------------------
# 函数: 解析参数
# ---------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --risk-level)
                RISK_LEVEL="$2"
                shift 2
                ;;
            --rollback)
                ROLLBACK_MODE=true
                shift
                ;;
            --backup=*)
                BACKUP_TS="${1#*=}"
                shift
                ;;
            --list-backups)
                LIST_BACKUPS=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "  ${RED}✗ 未知参数: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# ---------------------------------------------
# 主函数
# ---------------------------------------------
main() {
    local ROLLBACK_MODE=false
    local LIST_BACKUPS=false
    local BACKUP_TS=""

    parse_args "$@"

    # 列出备份
    if [ "$LIST_BACKUPS" = true ]; then
        list_backups
        exit 0
    fi

    # 执行回滚
    if [ "$ROLLBACK_MODE" = true ]; then
        if [ -z "$BACKUP_TS" ]; then
            echo -e "  ${RED}✗ 请指定备份时间戳: --backup=时间戳${NC}"
            exit 1
        fi
        rollback_backup "$BACKUP_TS"
        exit 0
    fi

    # 验证风险级别
    case $RISK_LEVEL in
        safe|standard|high) ;;
        *)
            echo -e "  ${RED}✗ 无效的风险级别: $RISK_LEVEL${NC}"
            echo "  有效值: safe, standard, high"
            exit 1
            ;;
    esac

    # 初始化
    init_logging
    print_header

    echo -e "  ${YELLOW}⚠️  修复前建议：${NC}"
    echo "  1. 重要操作前请备份数据"
    echo "  2. 确保有 SSH 密钥登录（禁用密码前）"
    echo "  3. 建议在低峰期执行"
    echo ""

    if [ "$RISK_LEVEL" = "high" ]; then
        echo -e "  ${RED}⚠️  high 模式包含中风险操作，需要二次确认${NC}"
        echo ""
        read -rp "  是否继续? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            echo "  已取消"
            exit 0
        fi
    fi

    # Safe 模式：核心安全项
    fix_ssh_config
    fix_firewall
    fix_fail2ban

    # Standard 模式：低风险项
    if [ "$RISK_LEVEL" = "standard" ] || [ "$RISK_LEVEL" = "high" ]; then
        fix_low_risk_items
    fi

    # High 模式：中风险项
    if [ "$RISK_LEVEL" = "high" ]; then
        fix_medium_risk_items
    fi

    # 打印报告
    print_report
}

# 入口
main "$@"
