#!/bin/bash
#===============================================================================
# 批量安全检查脚本
# 支持对多个Agent/主机进行批量安全检查
#===============================================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
REPORT_DIR="${SKILL_DIR}/reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BATCH_REPORT="${REPORT_DIR}/batch-scan-${TIMESTAMP}"

# 打印函数
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${CYAN}$1${NC}"; }

# 显示帮助
show_help() {
    cat << 'EOF'
批量安全检查脚本

用法: batch-scan.sh [选项]

选项:
    -f, --file FILE       指定主机列表文件（每行一个主机）
    -a, --agents LIST     直接指定Agent列表，逗号分隔
    -m, --mode MODE       检查模式: shell|agent (默认: shell)
    -o, --output DIR      报告输出目录
    -p, --parallel N      并行检查数量（默认: 3）
    -s, --summary         仅输出汇总报告
    -h, --help            显示帮助

主机列表文件格式:
    # 支持多种格式:
    user@hostname
    hostname:port
    user@hostname:port
    192.168.1.100
    agent-001

示例:
    # 从文件批量检查
    batch-scan.sh -f hosts.txt

    # 直接指定Agent列表
    batch-scan.sh -a "agent-001,agent-002,agent-003"

    # Agent模式批量检查
    batch-scan.sh -f agents.txt -m agent

    # 并行5个，仅汇总
    batch-scan.sh -f hosts.txt -p 5 -s

EOF
}

# 解析参数
parse_args() {
    HOSTS_FILE=""
    AGENTS_LIST=""
    MODE="shell"
    PARALLEL=3
    SUMMARY_ONLY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file)
                HOSTS_FILE="$2"
                shift 2
                ;;
            -a|--agents)
                AGENTS_LIST="$2"
                shift 2
                ;;
            -m|--mode)
                MODE="$2"
                shift 2
                ;;
            -o|--output)
                BATCH_REPORT="$2/batch-scan-${TIMESTAMP}"
                shift 2
                ;;
            -p|--parallel)
                PARALLEL="$2"
                shift 2
                ;;
            -s|--summary)
                SUMMARY_ONLY=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$HOSTS_FILE" && -z "$AGENTS_LIST" ]]; then
        print_error "必须指定主机列表文件(-f)或Agent列表(-a)"
        show_help
        exit 1
    fi
}

# 创建报告目录
init_report_dir() {
    mkdir -p "$BATCH_REPORT"
    print_info "报告将保存到: $BATCH_REPORT"
}

# 读取主机列表
read_hosts() {
    local hosts=()
    
    if [[ -n "$HOSTS_FILE" ]]; then
        if [[ ! -f "$HOSTS_FILE" ]]; then
            print_error "文件不存在: $HOSTS_FILE"
            exit 1
        fi
        while IFS= read -r line || [[ -n "$line" ]]; do
            # 跳过注释和空行
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// }" ]] && continue
            hosts+=("$line")
        done < "$HOSTS_FILE"
    fi
    
    if [[ -n "$AGENTS_LIST" ]]; then
        IFS=',' read -ra agent_array <<< "$AGENTS_LIST"
        hosts+=("${agent_array[@]}")
    fi
    
    echo "${hosts[@]}"
}

# 执行单主机检查
check_host() {
    local host=$1
    local output_file="${BATCH_REPORT}/${host//[\/:]/_}.txt"
    
    print_info "正在检查: $host"
    
    if [[ "$MODE" == "agent" ]]; then
        # Agent模式
        python3 "${SKILL_DIR}/agent/quick-check-agent.py" --target "$host" > "$output_file" 2>&1 || true
    else
        # Shell模式（本地检查）
        # 如果是远程主机，使用SSH执行
        if [[ "$host" == *@* ]] || [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$host" \
                "bash -s" < "${SCRIPT_DIR}/quick-check.sh" > "$output_file" 2>&1 || {
                echo "ERROR: 无法连接到 $host" > "$output_file"
            }
        else
            # 本地检查
            bash "${SCRIPT_DIR}/quick-check.sh" > "$output_file" 2>&1
        fi
    fi
    
    # 提取评分
    local score=$(grep -oE "安全评分:[[:space:]]*[0-9]+" "$output_file" | grep -oE "[0-9]+" || echo "0")
    echo "$host:$score"
}

# 生成汇总报告
generate_summary() {
    local summary_file="${BATCH_REPORT}/SUMMARY.md"
    
    print_header "正在生成汇总报告..."
    
    cat > "$summary_file" << EOF
# 批量安全检查报告

**生成时间:** $(date '+%Y-%m-%d %H:%M:%S')  
**检查模式:** $MODE  
**检查主机数:** ${#HOSTS[@]}  

## 汇总统计

| 主机 | 安全评分 | 状态 | 详情 |
|------|----------|------|------|
EOF
    
    local total_score=0
    local pass_count=0
    local warn_count=0
    local fail_count=0
    
    for host in "${HOSTS[@]}"; do
        local output_file="${BATCH_REPORT}/${host//[\/:]/_}.txt"
        local score=0
        local status="✓"
        local status_color="GREEN"
        
        if [[ -f "$output_file" ]]; then
            score=$(grep -oE "安全评分:[[:space:]]*[0-9]+" "$output_file" | grep -oE "[0-9]+" || echo "0")
            
            if [[ "$score" -ge 90 ]]; then
                status="✓"
                ((pass_count++))
            elif [[ "$score" -ge 70 ]]; then
                status="⚠"
                ((warn_count++))
            else
                status="✗"
                ((fail_count++))
            fi
        else
            score="N/A"
            status="✗"
            ((fail_count++))
        fi
        
        total_score=$((total_score + score))
        
        echo "| $host | $score | $status | [查看详情](${host//[\/:]/_}.txt) |" >> "$summary_file"
    done
    
    local avg_score=$((total_score / ${#HOSTS[@]}))
    
    cat >> "$summary_file" << EOF

## 统计概览

- **平均分:** $avg_score
- **优秀(≥90):** $pass_count 台
- **警告(70-89):** $warn_count 台
- **危险(<70):** $fail_count 台

## 详细信息

完整检查报告请查看各主机对应的 .txt 文件。

EOF
    
    print_success "汇总报告已生成: $summary_file"
}

# 在终端显示汇总
show_terminal_summary() {
    echo ""
    print_header "========================================"
    print_header "       批量安全检查完成"
    print_header "========================================"
    echo ""
    
    for host in "${HOSTS[@]}"; do
        local output_file="${BATCH_REPORT}/${host//[\/:]/_}.txt"
        local score=$(grep -oE "安全评分:[[:space:]]*[0-9]+" "$output_file" 2>/dev/null | grep -oE "[0-9]+" || echo "0")
        
        if [[ "$score" -ge 90 ]]; then
            printf "${GREEN}%-20s %s${NC}\n" "$host" "✓ 安全 ($score分)"
        elif [[ "$score" -ge 70 ]]; then
            printf "${YELLOW}%-20s %s${NC}\n" "$host" "⚠ 警告 ($score分)"
        else
            printf "${RED}%-20s %s${NC}\n" "$host" "✗ 危险 ($score分)"
        fi
    done
    
    echo ""
    print_info "详细报告: ${BATCH_REPORT}/"
}

# 主函数
main() {
    parse_args "$@"
    init_report_dir
    
    # 读取主机列表
    IFS=' ' read -ra HOSTS <<< "$(read_hosts)"
    
    if [[ ${#HOSTS[@]} -eq 0 ]]; then
        print_error "没有找到有效的主机"
        exit 1
    fi
    
    print_info "开始批量检查 ${#HOSTS[@]} 台主机..."
    
    # 并行执行检查
    if command -v parallel &> /dev/null; then
        printf '%s\n' "${HOSTS[@]}" | parallel -j "$PARALLEL" check_host
    else
        # 使用后台进程实现并行
        local running=0
        for host in "${HOSTS[@]}"; do
            check_host "$host" &
            ((running++))
            
            if [[ $running -ge $PARALLEL ]]; then
                wait -n 2>/dev/null || wait
                ((running--))
            fi
        done
        wait
    fi
    
    # 生成汇总报告
    generate_summary
    
    # 在终端显示
    if [[ "$SUMMARY_ONLY" == false ]]; then
        show_terminal_summary
    fi
    
    print_success "批量检查完成！"
}

main "$@"
