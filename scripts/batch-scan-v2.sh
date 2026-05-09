#!/bin/bash
#================================================================
# batch-scan-v2.sh - 增强版批量检查脚本
# 支持多Agent/多主机并行扫描
#================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
PARALLEL_JOBS=4
OUTPUT_DIR="$SKILL_DIR/reports/batch"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认参数
AGENTS=""
HOSTS=""
MODE="parallel"
VERBOSE=false
DRY_RUN=false

usage() {
    cat << 'EOF'
用法: batch-scan-v2.sh [选项]

选项:
    --agents <列表>      逗号分隔的Agent名称列表
    --hosts <列表>       逗号分隔的用户@主机列表 (SSH)
    --parallel <N>       并行任务数 (默认: 4)
    --mode <模式>        执行模式: parallel|sequential (默认: parallel)
    --output <目录>      输出目录 (默认: reports/batch)
    --verbose, -v        详细输出
    --dry-run            仅显示将要执行的操作
    --help, -h           显示此帮助

示例:
    batch-scan-v2.sh --agents agent1,agent2,agent3
    batch-scan-v2.sh --hosts user@host1,user@host2 --parallel 2
EOF
}

log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# 检查单个Agent
check_agent() {
    local agent_name="$1"
    local output_file="$OUTPUT_DIR/${agent_name}_${TIMESTAMP}.json"
    log "检查 Agent: $agent_name"
    
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] 将在 $agent_name 上执行安全检查"
        return 0
    fi
    
    # 执行Agent模式检查
    if [ -f "$SKILL_DIR/agent/quick-check-agent.py" ]; then
        python3 "$SKILL_DIR/agent/quick-check-agent.py" --output "$output_file" --format json 2>/dev/null || true
        log_success "$agent_name 检查完成"
    fi
}

# 检查远程主机
check_host() {
    local host="$1"
    local host_name=$(echo "$host" | cut -d'@' -f2 | tr '.' '_')
    log "检查主机: $host"
    
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] 将在 $host 上执行安全检查"
        return 0
    fi
    
    if command -v ssh >/dev/null 2>&1; then
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$host" "cd $SKILL_DIR && bash scripts/quick-check.sh" > "$OUTPUT_DIR/${host_name}.log" 2>&1 || true
        log_success "$host 检查完成"
    else
        log_error "SSH 不可用"
    fi
}

# 解析参数
while [ $# -gt 0 ]; do
    case "$1" in
        --agents) AGENTS="$2"; shift 2 ;;
        --hosts) HOSTS="$2"; shift 2 ;;
        --parallel) PARALLEL_JOBS="$2"; shift 2 ;;
        --mode) MODE="$2"; shift 2 ;;
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        --verbose|-v) VERBOSE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) shift ;;
    esac
done

mkdir -p "$OUTPUT_DIR"

main() {
    echo "=============================================="
    echo "🔒 批量安全检查 v2.0"
    echo "=============================================="
    
    tasks=""
    
    # 收集Agent任务
    if [ -n "$AGENTS" ]; then
        OLD_IFS="$IFS"
        IFS=','
        for agent in $AGENTS; do
            tasks="$tasks agent:$agent"
        done
        IFS="$OLD_IFS"
    fi
    
    # 收集主机任务
    if [ -n "$HOSTS" ]; then
        OLD_IFS="$IFS"
        IFS=','
        for host in $HOSTS; do
            tasks="$tasks host:$host"
        done
        IFS="$OLD_IFS"
    fi
    
    task_count=$(echo "$tasks" | wc -w)
    
    if [ "$task_count" -eq 0 ]; then
        log_error "没有指定任何Agent或主机"
        usage
        exit 1
    fi
    
    echo "模式: $MODE | 并行数: $PARALLEL_JOBS | 任务: $task_count"
    echo ""
    
    # 执行
    for task in $tasks; do
        case "$task" in
            agent:*)
                name="${task#agent:}"
                check_agent "$name" &
                ;;
            host:*)
                name="${task#host:}"
                check_host "$name" &
                ;;
        esac
        
        if [ "$MODE" = "parallel" ]; then
            while [ $(jobs -r 2>/dev/null | wc -l) -ge "$PARALLEL_JOBS" ]; do sleep 1; done
        fi
    done
    wait
    
    echo ""
    log_success "批量检查完成! 报告: $OUTPUT_DIR"
}

main
