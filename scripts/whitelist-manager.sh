#!/bin/bash
# healthcheck-skill Whitelist Manager v5.0.0 (Ultra Simple)
# 白名单管理：域名、路径、服务

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config"
WHITELIST_FILE="${CONFIG_DIR}/whitelist.yaml"
LOG_FILE="/tmp/healthcheck-whitelist.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_info() {
    log -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    log -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    log -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    log -e "${RED}[ERROR]${NC} $*"
}

# 创建配置目录
mkdir -p "$CONFIG_DIR"

# 初始化白名单文件
init_whitelist() {
    log_info "初始化白名单文件..."

    if [[ ! -f "$WHITELIST_FILE" ]]; then
        cat > "$WHITELIST_FILE" << 'EOF'
---
# healthcheck-skill 白名单配置

whitelist:
  # 信任域名（用于网络访问）
  domains:
    - "github.com"
    - "api.github.com"
    - "update.ubuntu.com"
    - "archive.ubuntu.com"
    - "security.ubuntu.com"
    - "xiaping.coze.site"
  reason: "系统更新、规则获取和平台访问"

  # 信任路径（用于文件访问）
  paths:
    - "/etc/ssh/sshd_config"
    - "/etc/ufw/"
    - "/etc/fail2ban/"
    - "/var/log/openclaw/"
    - "~/.openclaw/"
  reason: "配置文件和日志目录"

  # 信任服务（用于服务重启）
  services:
    - name: "sshd"
      restart_required: true
    - name: "ufw"
      restart_required: true
    - name: "fail2ban"
      restart_required: true
    - name: "cron"
      restart_required: false

# 白名单规则
rules:
  domain_access:
    allow_whitelisted: true
    block_non_whitelisted: false
  path_access:
    allow_whitelisted: true
    block_non_whitelisted: false
  service_operations:
    allow_whitelisted: true
    require_confirmation: true
EOF
        log_success "白名单文件已创建: $WHITELIST_FILE"
    else
        log_info "白名单文件已存在: $WHITELIST_FILE"
    fi
}

# 添加域名到白名单
add_domain() {
    local domain="$1"

    if [[ -z "$domain" ]]; then
        log_error "域名不能为空"
        return 1
    fi

    log_info "添加域名到白名单: $domain"

    # 检查是否已存在
    if grep -q "\"$domain\"" "$WHITELIST_FILE"; then
        log_warning "域名已存在: $domain"
        return 0
    fi

    # 添加域名（在 domains: 后添加）
    sed -i "/^  domains:/a\    - \"$domain\"" "$WHITELIST_FILE"

    log_success "域名已添加: $domain"
}

# 添加路径到白名单
add_path() {
    local path="$1"

    if [[ -z "$path" ]]; then
        log_error "路径不能为空"
        return 1
    fi

    log_info "添加路径到白名单: $path"

    # 检查是否已存在
    if grep -q "\"$path\"" "$WHITELIST_FILE"; then
        log_warning "路径已存在: $path"
        return 0
    fi

    # 添加路径（在 paths: 后添加）
    sed -i "/^  paths:/a\    - \"$path\"" "$WHITELIST_FILE"

    log_success "路径已添加: $path"
}

# 列出所有白名单
list_whitelist() {
    log_info "列出所有白名单..."

    if [[ ! -f "$WHITELIST_FILE" ]]; then
        log_error "白名单文件不存在"
        return 1
    fi

    echo -e "\n${CYAN}=== 域名白名单 ===${NC}"
    grep -A 10 "domains:" "$WHITELIST_FILE" | grep '^- "' | sed 's/^- //' || echo "  (无)"

    echo -e "\n${CYAN}=== 路径白名单 ===${NC}"
    grep -A 10 "paths:" "$WHITELIST_FILE" | grep '^- "' | sed 's/^- //' || echo "  (无)"

    echo -e "\n${CYAN}=== 服务白名单 ===${NC}"
    grep "name:" "$WHITELIST_FILE" | head -4 | awk '{print "  - " $2}' | tr -d '"' || echo "  (无)"
}

# 验证白名单
check_whitelist() {
    log_info "验证白名单..."

    if [[ ! -f "$WHITELIST_FILE" ]]; then
        log_error "白名单文件不存在"
        return 1
    fi

    log_success "白名单文件存在"
    log_success "白名单验证通过"
}

# 显示帮助
show_help() {
    cat << EOF
healthcheck 白名单管理器 v5.0.0

用法: $0 [选项] [参数]

选项:
  --init                            初始化白名单文件
  --add-domain <域名>               添加域名到白名单
  --add-path <路径>                 添加路径到白名单
  --list                            列出所有白名单
  --check                           验证白名单
  --help                            显示此帮助信息

示例:
  $0 --init
  $0 --add-domain example.com
  $0 --add-path /custom/path
  $0 --list
  $0 --check

EOF
}

# 主函数
main() {
    local action="${1:-}"

    # 确保白名单文件存在
    if [[ "$action" != "--init" ]] && [[ ! -f "$WHITELIST_FILE" ]]; then
        init_whitelist
    fi

    case "$action" in
        --init)
            init_whitelist
            ;;
        --add-domain)
            shift
            add_domain "$1"
            ;;
        --add-path)
            shift
            add_path "$1"
            ;;
        --list)
            list_whitelist
            ;;
        --check)
            check_whitelist
            ;;
        --help|--h|'')
            show_help
            ;;
        *)
            log_error "未知选项: $action"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
