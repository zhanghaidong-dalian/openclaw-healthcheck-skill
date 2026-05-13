#!/bin/bash
#
# OpenClaw 安全技能 - 批量检查脚本
# 功能：并行扫描多台主机的安全状态
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

# 默认配置
PARALLEL=5
TIMEOUT=30
OUTPUT="batch-report-$(date +%Y%m%d_%H%M%S).md"
HOSTS_FILE=""

# 帮助信息
show_help() {
    cat << EOF
OpenClaw 批量安全检查工具 v5.2.0

用法: $0 [选项]

选项:
    -f, --hosts-file FILE    主机列表文件（格式：IP 用户名）
    -p, --parallel NUM       并发数（默认：5）
    -o, --output FILE        输出报告文件（默认：batch-report-TIMESTAMP.md）
    -t, --timeout SECONDS    单主机超时时间（默认：30秒）
    -h, --help               显示帮助信息

主机文件格式示例:
    192.168.1.100 user1
    192.168.1.101 user2
    server.example.com admin

示例:
    $0 --hosts-file hosts.txt --parallel 10
    $0 -f servers.txt -p 5 -o my-report.md

EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--hosts-file)
            HOSTS_FILE="$2"
            shift 2
            ;;
        -p|--parallel)
            PARALLEL="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
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

# 检查必要参数
if [[ -z "$HOSTS_FILE" ]]; then
    echo -e "${RED}错误: 必须指定主机文件${NC}"
    show_help
    exit 1
fi

if [[ ! -f "$HOSTS_FILE" ]]; then
    echo -e "${RED}错误: 主机文件不存在: $HOSTS_FILE${NC}"
    exit 1
fi

# 读取主机列表
declare -a HOSTS
declare -a USERS
while IFS=' ' read -r host user; do
    [[ -z "$host" || "$host" =~ ^# ]] && continue
    HOSTS+=("$host")
    USERS+=("$user")
done < "$HOSTS_FILE"

TOTAL_HOSTS=${#HOSTS[@]}

if [[ $TOTAL_HOSTS -eq 0 ]]; then
    echo -e "${RED}错误: 主机文件为空${NC}"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  OpenClaw 批量安全检查 v5.2.0${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "📊 配置信息:"
echo -e "   主机数量: ${GREEN}$TOTAL_HOSTS${NC}"
echo -e "   并发数:   ${GREEN}$PARALLEL${NC}"
echo -e "   超时时间: ${GREEN}$TIMEOUT 秒${NC}"
echo -e "   输出文件: ${GREEN}$OUTPUT${NC}"
echo ""

# 检查单个主机的函数
check_host() {
    local host=$1
    local user=$2
    local tmpfile="/tmp/healthcheck_${host}.tmp"
    
    echo -e "${YELLOW}[$(date +%H:%M:%S)]${NC} 正在检查: ${BLUE}$user@$host${NC}"
    
    # 通过 SSH 执行远程检查
    ssh -o ConnectTimeout=$TIMEOUT -o StrictHostKeyChecking=no \
        "$user@$host" "bash -s" < "$(dirname "$0")/quick-check.sh" > "$tmpfile" 2>&1
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} 完成: $host"
        echo "HOST: $host" >> /tmp/batch_results.txt
        echo "STATUS: SUCCESS" >> /tmp/batch_results.txt
        cat "$tmpfile" >> /tmp/batch_results.txt
        echo "---" >> /tmp/batch_results.txt
    else
        echo -e "${RED}✗${NC} 失败: $host (错误码: $exit_code)"
        echo "HOST: $host" >> /tmp/batch_results.txt
        echo "STATUS: FAILED" >> /tmp/batch_results.txt
        echo "ERROR: Exit code $exit_code" >> /tmp/batch_results.txt
        echo "---" >> /tmp/batch_results.txt
    fi
    
    rm -f "$tmpfile"
}

# 导出函数供 xargs 使用
export -f check_host
export PARALLEL TIMEOUT

# 清理临时文件
rm -f /tmp/batch_results.txt
touch /tmp/batch_results.txt

# 并行执行检查
echo -e "\n${BLUE}🔍 开始批量扫描...${NC}\n"

# 使用简单循环模拟并行（避免 xargs 兼容性问题）
pids=()
for i in "${!HOSTS[@]}"; do
    host="${HOSTS[$i]}"
    user="${USERS[$i]}"
    
    # 控制并发数
    while [[ ${#pids[@]} -ge $PARALLEL ]]; do
        temp_pids=()
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                temp_pids+=("$pid")
            fi
        done
        pids=("${temp_pids[@]}")
        sleep 0.5
    done
    
    check_host "$host" "$user" &
    pids+=($!)
done

# 等待所有后台任务完成
wait

echo -e "\n${BLUE}📊 生成汇总报告...${NC}"

# 生成报告
cat > "$OUTPUT" << EOF
# OpenClaw 批量安全检查报告

**扫描时间**: $(date '+%Y-%m-%d %H:%M:%S')
**主机数量**: $TOTAL_HOSTS
**并发数**: $PARALLEL

---

## 检查结果汇总

| 主机 | 状态 |
|------|------|
EOF

# 统计结果
SUCCESS=0
FAILED=0

while IFS= read -r line; do
    if [[ "$line" == "HOST:"* ]]; then
        host=$(echo "$line" | cut -d' ' -f2)
    elif [[ "$line" == "STATUS: SUCCESS" ]]; then
        echo "| $host | ✅ 成功 |" >> "$OUTPUT"
        ((SUCCESS++))
    elif [[ "$line" == "STATUS: FAILED" ]]; then
        echo "| $host | ❌ 失败 |" >> "$OUTPUT"
        ((FAILED++))
    fi
done < /tmp/batch_results.txt

cat >> "$OUTPUT" << EOF

---

## 统计信息

- ✅ 成功: $SUCCESS 台
- ❌ 失败: $FAILED 台
- 📊 成功率: $(( SUCCESS * 100 / TOTAL_HOSTS ))%

---

## 详细结果

EOF

cat /tmp/batch_results.txt >> "$OUTPUT"

# 清理
rm -f /tmp/batch_results.txt

echo -e "${GREEN}✓${NC} 报告已生成: ${BLUE}$OUTPUT${NC}"
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  批量检查完成${NC}"
echo -e "${BLUE}========================================${NC}"
