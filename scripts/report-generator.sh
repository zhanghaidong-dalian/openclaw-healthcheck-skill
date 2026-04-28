#!/bin/bash
# healthcheck-skill Report Generator v5.0.0
# 结构化输出工具：JSON/Markdown 格式

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd"
OUTPUT_DIR="/tmp/healthcheck-reports"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 生成 JSON 报告
generate_json() {
    local input_file="$1"
    local output_file="${2:-${OUTPUT_DIR}/report-$(date +%Y%m%d-%H%M%S).json}"

    log_info "生成 JSON 报告: $output_file"

    if [[ ! -f "$input_file" ]]; then
        log_error "输入文件不存在: $input_file"
        return 1
    fi

    # 添加元数据
    jq -c --arg version "5.0.0" '
        .metadata = {
            "version": $version,
            "generator": "healthcheck-skill v5.0.0",
            "generated_at": now
        }
    | .
    ' "$input_file" > "$output_file"

    log_success "JSON 报告已生成: $output_file"
    echo "$output_file"
}

# 生成 Markdown 报告
generate_markdown() {
    local input_file="$1"
    local output_file="${2:-${OUTPUT_DIR}/report-$(date +%Y%m%d-%H%M%S).md}"

    log_info "生成 Markdown 报告: $output_file"

    if [[ ! -f "$input_file" ]]; then
        log_error "输入文件不存在: $input_file"
        return 1
    fi

    # 解析 JSON 并生成 Markdown
    local scan_type=$(jq -r '.scan_type // "unknown"' "$input_file")
    local scan_time=$(jq -r '.scan_time // "unknown"' "$input_file")
    local duration=$(jq -r '.duration_seconds // 0' "$input_file")
    local hostname=$(jq -r '.hostname // "unknown"' "$input_file")
    local os=$(jq -r '.os // "unknown"' "$input_file")

    local total_checks=$(jq -r '.summary.total_checks // .summary.checked_items // 0' "$input_file")
    local passed=$(jq -r '.summary.passed // 0' "$input_file")
    local failed=$(jq -r '.summary.failed // .summary.issues_found // 0' "$input_file")
    local risk_level=$(jq -r '.summary.risk_level // "unknown"' "$input_file")

    # 风险级别图标
    local risk_icon="🟢"
    case "$risk_level" in
        high) risk_icon="🔴" ;;
        medium) risk_icon="🟡" ;;
        low) risk_icon="🟢" ;;
    esac

    cat > "$output_file" << EOF
# 安全加固检查报告

**扫描类型**: $scan_type
**扫描时间**: $scan_time
**总耗时**: ${duration} 秒
**主机名**: $hostname
**操作系统**: $os

---

## 摘要

| 指标 | 数值 |
|------|------|
| 总检查项 | $total_checks |
| 通过 | $passed |
| 失败 | $failed |
**风险级别**: ${risk_icon} $risk_level

---

EOF

    # 添加高风险项
    if jq -e '.high_risk_items' "$input_file" > /dev/null 2>&1; then
        echo "## 高风险项" >> "$output_file"
        echo "" >> "$output_file"
        jq -r '.high_risk_items[]' "$input_file" | while IFS= read -r item; do
            local item_name=$(echo "$item" | jq -r '.name // .rule_id // "未知"')
            local severity=$(echo "$item" | jq -r '.severity // "unknown"')
            local current=$(echo "$item" | jq -r '.current // "未知"')
            local expected=$(echo "$item" | jq -r '.expected // "未知"')
            local action=$(echo "$item" | jq -r '.remediation.script // .action // "unknown"')

            echo "### $item_name" >> "$output_file"
            echo "" >> "$output_file"
            echo "**严重级别**: 🔴 高危" >> "$output_file"
            echo "**当前状态**: \`${current}\`" >> "$output_file"
            echo "**期望状态**: \`${expected}\`" >> "$output_file"
            echo "" >> "$output_file"
            echo "**修复方案**: \`$action\`" >> "$output_file"
            echo "" >> "$output_file"
        done
        echo "" >> "$output_file"
    fi

    # 添加发现项
    if jq -e '.findings' "$input_file" > /dev/null 2>&1; then
        echo "## 所有发现项" >> "$output_file"
        echo "" >> "$output_file"
        jq -r '.findings[]' "$input_file" | while IFS= read -r item; do
            local item_id=$(echo "$item" | jq -r '.rule_id // "unknown"')
            local item_name=$(echo "$item" | jq -r '.name // "未知"')
            local severity=$(echo "$item" | jq -r '.severity // "unknown"')
            local status=$(echo "$item" | jq -r '.status // "unknown"')
            local current=$(echo "$item" | jq -r '.current // "未知"')
            local expected=$(echo "$item" | jq -r '.expected // "未知"')

            local severity_icon="🟢"
            case "$severity" in
                high|critical) severity_icon="🔴" ;;
                medium) severity_icon="🟠" ;;
                low) severity_icon="🟢" ;;
            esac

            local status_icon="✅"
            if [[ "$status" != "passed" ]]; then
                status_icon="❌"
            fi

            echo "### ${severity_icon} ${status_icon} $item_name ($item_id)" >> "$output_file"
            echo "" >> "$output_file"
            echo "- **严重级别**: $severity" >> "$output_file"
            echo "- **状态**: $status" >> "$output_file"
            echo "- **当前值**: \`${current}\`" >> "$output_file"
            echo "- **期望值**: \`${expected}\`" >> "$output_file"
            echo "" >> "$output_file"
        done
        echo "" >> "$output_file"
    fi

    # 添加意图分析
    if jq -e '.intent_analysis' "$input_file" > /dev/null 2>&1; then
        echo "## 意图一致性分析" >> "$output_file"
        echo "" >> "$output_file"

        local declared=$(jq -r '.intent_analysis.declared_intent.primary // "未知"' "$input_file")
        local consistency=$(jq -r '.intent_analysis.consistency_status // "unknown"' "$input_file")
        local conclusion=$(jq -r '.intent_analysis.conclusion // "未知"' "$input_file")

        echo "**声明意图**: $declared" >> "$output_file"
        echo "**一致性状态**: $consistency" >> "$output_file"
        echo "**结论**: $conclusion" >> "$output_file"
        echo "" >> "$output_file"
    fi

    # 添加页脚
    cat >> "$output_file" << EOF
---

**生成时间**: $(date '+%Y-%m-%d %H:%M:%S')
**生成工具**: healthcheck-skill v5.0.0
**报告格式**: Markdown

---

> 本报告由 healthcheck-skill 自动生成
> 如有疑问，请运行 \`./healthcheck --help\` 查看帮助信息
EOF

    log_success "Markdown 报告已生成: $output_file"
    echo "$output_file"
}

# 生成双格式报告
generate_both() {
    local input_file="$1"
    local prefix="${2:-${OUTPUT_DIR}/report}"

    log_info "生成双格式报告..."

    local json_file="${prefix}.json"
    local markdown_file="${prefix}.md"

    generate_json "$input_file" "$json_file"
    generate_markdown "$input_file" "$markdown_file"

    echo "$json_file"
    echo "$markdown_file"
}

# 控制台输出
output_console() {
    local input_file="$1"

    if [[ ! -f "$input_file" ]]; then
        log_error "输入文件不存在: $input_file"
        return 1
    fi

    # 输出摘要
    local scan_type=$(jq -r '.scan_type // "unknown"' "$input_file")
    local duration=$(jq -r '.duration_seconds // 0' "$input_file")
    local failed=$(jq -r '.summary.failed // .summary.issues_found // 0' "$input_file")
    local risk_level=$(jq -r '.summary.risk_level // "unknown"' "$input_file")

    local risk_icon="🟢"
    case "$risk_level" in
        high) risk_icon="🔴" ;;
        medium) risk_icon="🟡" ;;
    esac

    echo -e "\n${CYAN}=== 安全加固检查报告 ===${NC}"
    echo "扫描类型: $scan_type"
    echo "扫描耗时: ${duration} 秒"
    echo "风险级别: ${risk_icon} $risk_level"
    echo "发现问题: $failed 个"
    echo ""
}

# 显示帮助
show_help() {
    cat << EOF
healthcheck 报告生成器 v5.0.0

用法: $0 [选项] [参数]

选项:
  --json <输入文件> [输出文件]    生成 JSON 报告
  --markdown <输入文件> [输出文件]  生成 Markdown 报告
  --both <输入文件> [前缀]      生成双格式报告
  --console <输入文件>          控制台输出
  --help                       显示此帮助信息

示例:
  $0 --json /tmp/scan-result.json /tmp/report.json
  $0 --markdown /tmp/scan-result.json /tmp/report.md
  $0 --both /tmp/scan-result.json /tmp/report
  $0 --console /tmp/scan-result.json

EOF
}

# 主函数
main() {
    local action="${1:-}"

    case "$action" in
        --json)
            shift
            generate_json "$@"
            ;;
        --markdown)
            shift
            generate_markdown "$@"
            ;;
        --both)
            shift
            generate_both "$@"
            ;;
        --console)
            shift
            output_console "$@"
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
