#!/bin/bash
# healthcheck-skill Rule Engine v5.0.0
# 规则引擎：加载、验证、执行规则

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_DIR="${SCRIPT_DIR}/../rules"
CONFIG_DIR="${SCRIPT_DIR}/../config"
LOG_FILE="/tmp/healthcheck-rules.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 加载所有规则
load_all_rules() {
    log_info "加载所有规则..."

    if [[ ! -d "$RULES_DIR" ]]; then
        log_error "规则目录不存在: $RULES_DIR"
        return 1
    fi

    local rule_count=0
    local loaded_count=0
    local failed_count=0

    while IFS= read -r -d '' rule_file; do
        ((rule_count++))
        local rule_name=$(basename "$rule_file" .yaml)

        if validate_rule "$rule_file"; then
            ((loaded_count++))
            log_success "规则加载成功: $rule_name"
        else
            ((failed_count++))
            log_error "规则加载失败: $rule_name"
        fi
    done < <(find "$RULES_DIR" -name "*.yaml" -print0)

    log_info "规则加载完成: 总计 $rule_count, 成功 $loaded_count, 失败 $failed_count"

    if [[ $failed_count -gt 0 ]]; then
        return 1
    fi

    return 0
}

# 验证规则文件
validate_rule() {
    local rule_file="$1"

    # 检查文件是否存在
    if [[ ! -f "$rule_file" ]]; then
        log_error "规则文件不存在: $rule_file"
        return 1
    fi

    # 检查 YAML 格式
    if ! command -v yq &> /dev/null; then
        log_warning "yq 未安装，跳过 YAML 格式验证"
        return 0
    fi

    if ! yq eval '.' "$rule_file" > /dev/null 2>&1; then
        log_error "YAML 格式错误: $rule_file"
        return 1
    fi

    # 检查必需字段
    local required_fields=("id" "name" "category" "severity" "description")
    for field in "${required_fields[@]}"; do
        if ! yq eval ".$field" "$rule_file" > /dev/null 2>&1; then
            log_error "规则缺少必需字段 '$field': $rule_file"
            return 1
        fi
    done

    return 0
}

# 执行单个规则
execute_rule() {
    local rule_file="$1"
    local report_file="${2:-/tmp/rule-report.json}"

    log_info "执行规则: $rule_file"

    # 解析规则
    local rule_id=$(yq eval '.id' "$rule_file")
    local rule_name=$(yq eval '.name' "$rule_file")
    local rule_category=$(yq eval '.category' "$rule_file")
    local rule_severity=$(yq eval '.severity' "$rule_file")
    local rule_check_type=$(yq eval '.check.type' "$rule_file")

    # 执行检查
    local check_result="unknown"
    local current_value=""
    local expected_value=""

    case "$rule_check_type" in
        config_file)
            local config_file=$(yq eval '.check.file' "$rule_file")
            local config_regex=$(yq eval '.check.regex' "$rule_file")
            expected_value=$(yq eval '.expected' "$rule_file")

            if [[ -f "$config_file" ]]; then
                if grep -qE "$config_regex" "$config_file"; then
                    current_value=$(grep -E "$config_regex" "$config_file" | tail -1)
                    if [[ "$current_value" =~ $expected_value ]]; then
                        check_result="passed"
                    else
                        check_result="failed"
                    fi
                else
                    check_result="not_found"
                    current_value="配置项未找到"
                fi
            else
                check_result="file_not_found"
                current_value="配置文件不存在"
            fi
            ;;
        command)
            local command=$(yq eval '.check.command' "$rule_file")
            expected_value=$(yq eval '.expected' "$rule_file")

            if eval "$command" > /dev/null 2>&1; then
                current_value=$(eval "$command" 2>&1)
                if [[ "$current_value" =~ $expected_value ]]; then
                    check_result="passed"
                else
                    check_result="failed"
                fi
            else
                check_result="command_failed"
                current_value="命令执行失败"
            fi
            ;;
        service)
            local service=$(yq eval '.check.service' "$rule_file")
            local expected_status=$(yq eval '.expected' "$rule_file")

            if systemctl is-active "$service" > /dev/null 2>&1; then
                current_value="active"
                if [[ "$expected_status" == "active" ]]; then
                    check_result="passed"
                else
                    check_result="failed"
                fi
            else
                current_value="inactive"
                if [[ "$expected_status" == "inactive" ]]; then
                    check_result="passed"
                else
                    check_result="failed"
                fi
            fi
            ;;
        *)
            log_error "未知的检查类型: $rule_check_type"
            check_result="unknown"
            ;;
    esac

    # 生成报告
    cat > "$report_file" << EOF
{
  "rule_id": "$rule_id",
  "name": "$rule_name",
  "category": "$rule_category",
  "severity": "$rule_severity",
  "status": "$check_result",
  "current": "$current_value",
  "expected": "$expected_value",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

    if [[ "$check_result" == "passed" ]]; then
        return 0
    else
        return 1
    fi
}

# 列出所有规则
list_rules() {
    log_info "列出所有规则..."

    if [[ ! -d "$RULES_DIR" ]]; then
        log_error "规则目录不存在: $RULES_DIR"
        return 1
    fi

    echo "规则列表:"
    echo "--------------------------------------------------"
    printf "%-10s %-20s %-15s %-10s\n" "ID" "名称" "类别" "严重级别"
    echo "--------------------------------------------------"

    while IFS= read -r -d '' rule_file; do
        local rule_id=$(yq eval '.id' "$rule_file" 2>/dev/null || echo "unknown")
        local rule_name=$(yq eval '.name' "$rule_file" 2>/dev/null || echo "unknown")
        local rule_category=$(yq eval '.category' "$rule_file" 2>/dev/null || echo "unknown")
        local rule_severity=$(yq eval '.severity' "$rule_file" 2>/dev/null || echo "unknown")

        printf "%-10s %-20s %-15s %-10s\n" "$rule_id" "$rule_name" "$rule_category" "$rule_severity"
    done < <(find "$RULES_DIR" -name "*.yaml" -print0)

    echo "--------------------------------------------------"
}

# 更新规则（从远程仓库）
update_rules() {
    log_info "更新规则..."

    # TODO: 实现从远程仓库更新规则的逻辑
    log_warning "规则更新功能尚未实现"
    return 0
}

# 显示帮助
show_help() {
    cat << EOF
healthcheck 规则引擎 v5.0.0

用法: $0 [选项] [参数]

选项:
  --load-all           加载所有规则
  --validate <规则文件>  验证规则文件
  --execute <规则文件> [输出文件]  执行规则
  --list               列出所有规则
  --update             更新规则（从远程仓库）
  --help               显示此帮助信息

示例:
  $0 --load-all
  $0 --validate rules/ssh-hardening.yaml
  $0 --execute rules/ssh-hardening.yaml /tmp/report.json
  $0 --list

EOF
}

# 主函数
main() {
    local action="${1:-}"

    case "$action" in
        --load-all)
            load_all_rules
            ;;
        --validate)
            shift
            validate_rule "$1"
            ;;
        --execute)
            shift
            execute_rule "$1" "$2"
            ;;
        --list)
            list_rules
            ;;
        --update)
            update_rules
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
