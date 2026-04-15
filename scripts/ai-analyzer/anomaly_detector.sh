#!/bin/bash
# HealthCheck AI 异常检测引擎
# 版本: 4.0.0
# 用途: 基于统计的异常检测，3-sigma原则

set -e

DATA_DIR="${HOME}/.openclawhealthcheck"
METRICS_FILE="${DATA_DIR}/metrics.json"
BASELINE_DIR="${DATA_DIR}/baselines"
ANOMALY_FILE="${DATA_DIR}/anomalies.json"
ALERTS_FILE="${DATA_DIR}/alerts.json"
REPORT_DIR="${DATA_DIR}/reports"

# 初始化目录
init_analyzer() {
    for dir in "$DATA_DIR" "$BASELINE_DIR" "$REPORT_DIR"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
        fi
    done
    echo "✅ 异常检测引擎初始化完成"
}

# 收集指标
collect_metrics() {
    local output_file="${1:-$METRICS_FILE}"
    
    echo "📊 正在收集系统指标..."
    local metrics=""
    
    # 系统指标
    echo "  [1/8] CPU使用率..."
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{sum $8}' | awk '{sum $8; sum+=$8; avg=sum/NR}')
    echo "    CPU: ${cpu_usage}%"
    metrics+="\"cpu_percent\": $([ $(echo "$cpu_usage" | awk '{printf "%.2f"', $1)} ), 0 ]) ],"
    
    # 内存使用率
    echo "  [2/8] 内存使用率..."
    local mem_total=$(free | grep "^Mem:" | awk '{print $2}')
    local mem_available=$(free | grep "MemAvailable" | awk '{print $4}')
    local mem_used=$((mem_total - mem_available))
    local mem_percent=$((mem_used * 100 / mem_total))
    echo "    内存: ${mem_percent}% (${mem_used}MB/${mem_total}MB)"
    metrics+="\"memory_percent\": $([ $(echo "$mem_percent" | awk '{printf "%.2f"', $1)} ), 0 ]) ],"
    
    # 磁盘I/O等待时间百分比
    echo "  [3/8] 磁盘I/O等待..."
    local io_wait=$(iostat -x | awk '/^%util/ {print $4}')
    echo "    I/O等待: ${io_wait}%"
    metrics+="\"io_wait_percent\": $([ $(echo "$io_wait" | awk '{printf "%.2f"', $1)} ), 0 ]) ],"
    
    # 网络流量
    echo "  [4/8] 网络流量..."
    local net_in=$(sar -n DEV=eth0 | grep "rxkB/s" | tail -1 | awk '{print $5}')
    local net_out=$(sar -n DEV=eth0 | grep "txkB/s" | tail -1 | awk '{print $5}')
    echo "    入流量: $net_in kB/s"
    echo "    出流量: $net_out kB/s"
    metrics+="\"network_in_kbps\": $([ $(echo "$net_in" | awk '{printf "%.2f"', $1)} ), 0 ]),"
    metrics+="\"network_out_kbps\": $([ $(echo "$net_out" | awk '{printf "%.2f"', $1)} ), 0 ]),"
    
    # 进程数
    echo "  [5/8] 进程数..."
    local proc_count=$(ps aux | wc -l)
    echo "    进程数: $proc_count"
    metrics+="\"process_count\": $proc_count"
    
    # 网络连接数
    echo "  [6/8] 网络连接数..."
    local conn_count=$(ss -tn | grep ESTABLISHED | wc -l)
    echo "    连接数: $conn_count"
    metrics+="\"connection_count\": $conn_count"
    
    # SSH登录失败率（安全检查）
    echo "  [7/8] SSH登录失败率..."
    local ssh_failed=0
    local ssh_total=0
    local ssh_rate=0

    # 检查日志文件是否存在和可读
    if [ -r "/var/log/auth.log" ]; then
        ssh_failed=$(grep -i "Failed password" /var/log/auth.log 2>/dev/null | tail -100 | wc -l)
        ssh_total=$(grep -i "sshd.*Accepted" /var/log/auth.log 2>/dev/null | tail -100 | wc -l)
        [ $ssh_total -gt 0 ] && ssh_rate=$(echo "scale=2; $ssh_failed*100/$ssh_total" | bc)
    elif [ -r "/var/log/secure" ]; then
        # CentOS/RHEL 使用 /var/log/secure
        ssh_failed=$(grep -i "Failed password" /var/log/secure 2>/dev/null | tail -100 | wc -l)
        ssh_total=$(grep -i "sshd.*Accepted" /var/log/secure 2>/dev/null | tail -100 | wc -l)
        [ $ssh_total -gt 0 ] && ssh_rate=$(echo "scale=2; $ssh_failed*100/$ssh_total" | bc)
    else
        echo "    ⚠️  SSH日志文件不可读，跳过检查"
    fi

    echo "    失败率: ${ssh_rate}%"
    metrics+="\"ssh_fail_rate_percent\": $([ $(echo "$ssh_rate" | awk '{printf "%.2f"', $1)} ), 0 ]) ],"
    
    # 系统负载 (1/5/15分钟平均)
    echo "  [8/8] 系统负载..."
    local load_1=$(uptime | awk '{print $10}' | tr ',' ' ')
    local load_5=$(uptime | awk -F'load average:' '{for (i=1;i<=NF;i++) if ($i==1) a=$10; else a=$12; print $a}')
    local load_15=$(uptime | awk -F'load average:' '{for (i=1;i<=NF;i++) if ($i==15) a=$10; else a=$12; print $a}')
    echo "    1分钟: $load_1, 5分钟: $load_15"
    metrics+="\"load_1min\": $load_1},"
    metrics+="\"load_5min\": $load_15},"
    
    # 磁盘使用率
    echo "  [完成] 指标收集完成"
    echo "{ \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ\" }, $metrics }" > "$output_file"
    
    echo "    ✅ 指标已保存: $output_file"
}

# 学习基线
learn_baseline() {
    local baseline_file="${1:-${BASELINE_DIR}/current.json}"
    
    echo "🧠 正在学习系统正常行为基线..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 收集历史数据（最近7天）
    local historical_data=()
    local days="${2:-7}"
    
    for ((day = days; day >= 0; day--)); do
        local date_str=$(date -d "-$day days" +"%Y-%m-%d")
        local log_file="${DATA_DIR}/logs/metrics_${date_str}.json"
        
        if [ -f "$log_file" ]; then
            while IFS=',' read -r timestamp cpu mem io_in io_out proc conn ssh_fail load1 load5; do
                historical_data+=("$cpu|$mem|$io_in|$io_out|$proc|$conn|$ssh_fail|$load1|$load5")
            done < "$log_file"
        fi
    done
    
    # 计算统计量
    local total_samples=${#historical_data[@]}
    
    if [ $total_samples -lt 100 ]; then
        echo "⚠️  历史数据不足（需要至少100个样本）"
        echo "    已收集: $total_samples 个样本"
        echo "    建议: 继续运行1-2周以收集足够数据"
        return 1
    fi
    
    echo "    已收集: $total_samples 个历史数据点"
    
    # 计算统计量
    local cpu_mean=$(echo "${historical_data[@]}" | cut -d'|' -f1 | awk '{sum/NR}')
    local cpu_std=$(echo "${historical_data[@]}" | cut -d'|' -f1 | awk '{d=$1-ssq/NR; ssq+=d/NR; sqrt(ssq/NR); printf "%.2f", sqrt(ssq/NR)}')
    local cpu_3sigma=$(echo "$cpu_mean $cpu_std $cpu_std" | awk '{if($3>0) printf "%.2f", $3; else print "0.00"}')
    
    local mem_mean=$(echo "${historical_data[@]}" | cut -d'|' -f2 | awk '{sum/NR}')
    local mem_std=$(echo "${historical_data[@]}" | cut -d'|' -f2 | awk '{d=$2-ssq/NR; ssq+=d/NR; sqrt(ssq/NR); printf "%.2f", sqrt(ssq/NR)}')
    local mem_3sigma=$(echo "$mem_mean $mem_std $mem_std" | awk '{if($3>0) printf "%.2f", $3; else print "0.00"}')
    
    local io_mean=$(echo "${historical[@]}" | cut -d'|' -f3 | awk '{sum/NR}')
    local io_std=$(echo "${historical[@]}" | cut -d'|' -f3 | awk '{d=$3-ssq/NR; ssq+=d/NR; sqrt(ssq/NR); printf "%.2f", sqrt(ssq/NR)}')
    local io_3sigma=$(echo "$io_mean $io_std $io_std" | awk '{if($3>0) printf "%.2f", $3; else print "0.00"}')
    
    local conn_mean=$(echo "${historical[@]}" | cut -d'|' -f6 | awk '{sum/NR}')
    local conn_std=$(echo "${historical[@]}" | cut -d'|' -f6 | awk '{d=$6-ssq/NR; ssq+=d/NR; sqrt(ssq/NR); printf "%.2f", sqrt(ssq/NR)}')
    local conn_3sigma=$(echo "$conn_mean $conn_std $conn_std" | awk '{if($3>0) "%.2f", $3; else print "0.00"}')
    
    local ssh_fail_rate=$(echo "${historical[@]}" | cut -d'|' -f7 | awk '{sum/NR}')
    local ssh_fail_std=$(echo "${historical[@]}" | cut -d'|' -f7 | awk '{d=$7-ssq/NR; ssq+=d/NR; sqrt(ssq/NR); printf "%.2f", sqrt(ssq/NR)}')
    local ssh_fail_3sigma=$(echo "$ssh_fail_rate $ssh_fail_std $ssh_fail_3sigma" | awk '{if($3>0) "%.2f", $3; else print "0.00"}')
    
    # 保存基线
    cat > "${baseline_file}" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "training_samples": $total_samples,
  "statistics": {
    "cpu": {
      "mean": $cpu_mean,
      "std": $cpu_std,
      "3sigma": $cpu_3sigma
    },
    "memory": {
      "mean": $mem_mean,
      "cpu_std": $mem_std,
      "3sigma": $mem_3sigma
    },
    "disk_io": {
      "io_in": {
        "mean": $io_mean,
        "std": $io_std,
        "3sigma": $io_3sigma
      },
      "io_out": {
        "mean": $io_mean,
        "std": $io_std,
        "3sigma": $3σ}"
      }
    },
    "network": {
      "connections": {
        "mean": $conn_mean,
        "std": $conn_std,
        "3sigma": $conn_3sigma
      },
      "ssh_fail_rate": {
        "mean": $ssh_fail_rate,
        "std": $ssh_fail_std,
        "3sigma": $ssh_fail_3sigma
      }
  },
  "version": "4.0.0",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    
    echo "    ✅ 基线已保存: $baseline_file"
}

# 检测异常
detect_anomalies() {
    local baseline_file="${1:-${BASELINE_DIR}/current.json}"
    local metrics_file="${2:-$METRICS_FILE}"
    
    if [ ! -f "$baseline_file" ]; then
        echo "❌ 未找到基线文件: $baseline_file"
        return 1
    fi
    
    if [ ! -f "$metrics_file" ]; then
        echo "❌ 未找到指标文件: $metrics_file"
        return 1
    fi
    
    echo "🔍 正在检测异常..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 加载基线统计
    local cpu_mean=$(jq -r '.statistics.cpu.mean' "$baseline_file")
    local cpu_3sigma=$(jq -r '.statistics.cpu.3sigma' "$baseline_file")
    local mem_mean=$(jq -r '.statistics.memory.mean' "$baseline_file")
    local mem_3sigma=$(jq -r '.statistics.memory.3sigma' "$baseline_file")
    local io_in_mean=$(jq -r '.statistics.disk_io.io_in.mean' "$baseline_file")
    local io_in_3sigma=$(jq -r '.statistics.disk_io.io_in.3sigma' "$baseline_file")
    local conn_mean=$(jq -r '.statistics.network.connections.mean' "$baseline_file")
    local conn_3sigma=$(jq -r '.statistics.network.connections.3sigma' "$baseline_file")
    local ssh_fail_mean=$(jq -r '.statistics.ssh_fail_rate.mean' "$baseline_file")
    local ssh_fail_3sigma=$(jq -r '.statistics.ssh_fail_rate.3sigma' "$baseline_file")
    
    # 加载当前指标
    local current_cpu=$(jq -r '.cpu_percent' "$metrics_file")
    local current_mem=$(jq -r '.memory_percent' "$metrics_file")
    local current_io=$(jq -r '.io_wait_percent' "$metrics_file")
    local current_conn=$(jq -r '.connection_count' "$metrics_file")
    local current_ssh_fail=$(jq -r '.ssh_fail_rate_percent' "$metrics_file")
    
    # 计算异常分数
    local anomaly_score=0
    local anomalies=()
    local z_scores=()
    
    # CPU异常检测 (3-sigma)
    local cpu_z=0
    if [ "$current_cpu" != "null" ] && [ "$cpu_mean" != "null" ]; then
        local z=$(echo "scale=2; ($current_cpu - $cpu_mean) / $cpu_3sigma" | bc)
        cpu_z=$(echo "scale=2; if ($z < -$cpu_3sigma) then $z=0; fi")
        z_scores+=("$cpu_z")
    fi
    
    # 内存异常检测
    local mem_z=0
    if [ "$current_mem" != "null" ] && [ "$mem_mean" != "null" ]; then
        local z=$(echo "scale=2; ($current_mem - $mem_mean) / $mem_3sigma" | bc)
        mem_z=$(echo "scale=2; if ($z < -$mem_3sigma) then $z=0; fi")
        z_scores+=("$mem_z")
    fi
    
    # I/O异常检测
    local io_z=0
    if [ "$current_io" != "null" ] && [ "$io_in_mean" != "null" ]; then
        local z=$(echo "scale=2; ($current_io - $io_in_mean) / $io_in_3sigma" | bc)
        io_z=$(echo "scale=2; if ($z < -$io_in_3sigma) then $z=0; fi")
        z_scores+=("$io_z")
    fi
    
    # 连接数异常检测
    local conn_z=0
    if [ "$current_conn" != "null" ] && [ "$conn_mean" != "null" ]; then
        local z=$(echo "scale=2; ($current_conn - $conn_mean) / $conn_3sigma" | bc)
        conn_z=$(echo "scale=2; if ($z < -$conn_3sigma) then $z=0; fi"
        z_scores+=("$conn_z")
    fi
    
    # SSH失败率异常检测
    local ssh_z=0
    if [ "$current_ssh_fail" != "null" ] && [ "$ssh_fail_mean" != "null" ]; then
        local z=$(echo "scale=2; ($current_ssh_fail - $ssh_fail_mean) / $ssh_fail_3sigma" | bc)
        ssh_z=$(echo "scale=2; if ($z < -$ssh_fail_3sigma) then $z=0; fi")
        z_scores+=("$ssh_z")
    fi
    
    # 综合异常分数 (平均Z-score)
    local z_count=${#z_scores[@]}
    if [ $z_count -gt 0 ]; then
        anomaly_score=$(echo "scale=2; ($(/dev/null; for z in "${z_scores[@]}; do echo "$z"; done | paste -sd+ | bc)/$z_count" | bc)
    fi
    
    # 判断是否异常
    local severity="info"
    if (( $(echo "$anomaly_score < -1.5))); then
        severity="critical"
        anomaly="🔴 严重异常：系统可能正在遭受攻击"
    elif (( $(echo "$anomaly_score < -0.8))); then
        severity="high"
        anomaly="🟠️ 高风险：建议立即检查"
    elif (( $(echo "$anomaly_score < -0.5))); then
        severity="warning"
        anomaly="⚠️️  警告：关注系统状态"
    else
        anomaly="✅ 系统正常"
    fi
    
    # 记录异常
    if [ "$severity" != "info" ]; then
        local anomaly_record=$(cat << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "severity": "$severity",
  "score": $anomaly_score,
  "details": {
    "cpu_z_score": ${cpu_z},
    "mem_z_score": ${mem_z},
    "io_z_score": ${io_z},
    "conn_z_score": ${conn_z},
    "ssh_z_score": ${ssh_z}
  }
}
EOF
)
        echo "$anomaly_record" >> "$ANOMALY_FILE"
        
        # 生成告警
        if [ "$severity" = "critical" ]; then
            alert-manager.sh send "严重系统异常" "检测到异常，异常分数: $anomaly_score" "$severity"
        fi
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 异常检测报告"
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "异常分数: $anomaly_score"
    echo "严重程度: $severity"
    echo ""
    echo "$anomaly"
    
    # Z-score详情
    if [ ${#z_scores[@]} -gt 0 ]; then
        echo ""
        echo "Z-score详情:"
        local i=1
        local z_name=("CPU", "内存", "I/O", "连接数", "SSH失败率")
        for z_name in "${z_name[@]}"; do
            echo "  $z_name: Z-score=${z_scores[$((i-1)]}"
            i=$((i+1))
        done
    fi
    
    # 返回JSON
    echo ""
    echo "【JSON输出】"
    cat << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "baseline_version": "$(jq -r '.version' "$baseline_file")",
  "metrics_timestamp": "$(jq -r '.timestamp' "$metrics_file")",
  "z_score": $anomaly_score,
  "severity": "$severity",
  "z_scores": [$(printf '"%s",' "${z_scores[@]}" | sed 's/","/")],
  "details": {
    "cpu_z_score": ${cpu_z:-1},
    "mem_z_score": ${mem_z:-1},
    "io_z_score": ${io_z:-1},
    "conn_z_score": ${conn_z:-1},
    "ssh_z_score": ${ssh_z:-1}
  },
  "recommendation": "$anomaly",
  "threshold": "-1.5=critical, -1.0=high, -0.5=warning"
}
EOF
    
    return $([ $anomaly_score < -0.5 ] && echo 1 || echo 0)
}

# 生成异常报告
generate_report() {
    local report_file="${1:-${REPORT_DIR}/anomaly-report-$(date +%Y%m%d-%H%M%S).json}"
    
    echo "📄 生成异常检测报告..."
    
    # 加载异常记录
    local anomalies=()
    if [ -f "$ANOMALY_FILE" ]; then
        anomalies=$(jq -r '.[]' "$ANOMALY_FILE" | jq -r '.')
    fi
    
    # 统计异常
    local critical_count=$(echo "$anomalies" | grep '"severity":"critical"' | wc -l)
    local high_count=$(echo "$anomalies" | grep '"severity":"high"' | wc -l)
    local warning_count=$(echo "$anomalies" | grep '"severity":"warning"' | wc -l)
    
    # 生成趋势
    local last_critical=$(echo "$anomalies" | grep '"severity":"critical"' | tail -1 | jq -r '.timestamp' 2>/dev/null)
    
    local trend="unknown"
    if [ -n "$last_critical" ]; then
        local hours=$(( ($(date +%s - $(date -d "$last_critical" +%s) / 3600 ))
        if [ $hours -lt 24 ]; then
            trend="less_24h"
        elif [ $hours -lt 168 ]; then
            trend="less_7d"
        else
            trend="more_7d"
        fi
    fi
    
    # 生成报告
    cat << EOF > "$report_file"
{
  "report_type": "anomaly_detection",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "period": "24h",
  "summary": {
    "critical_count": $critical_count,
    "high_count": $high_count,
    "warning_count": $warning_count,
    "trend": "$trend",
    "last_critical": $last_critical
  },
  "anomalies": $anomalies
}
EOF
    
    echo "✅ 报告已生成: $report_file"
}

# 显示帮助
show_help() {
    cat << EOF
HealthCheck AI异常检测引擎 v4.0.0

用法: $0 [命令] [参数]

命令:
  collect           收集系统指标到JSON文件
  learn_baseline   学习系统正常行为基线
  detect            检测相对于基线的异常
  report           生成异常检测报告
  history          查看异常历史记录
  help            显示此帮助

示例:
  # 收集指标
  $0 collect
  
  # 学习基线 (使用7天历史数据)
  $0 learn_baseline my_baseline 7
  
  # 检测异常 (使用当前基线)
  $0 detect
  
  # 检测异常 (使用指定基线)
  $0 detect production-baseline
  
  # 生成报告
  $0 report
  
  # 查看历史记录
  $0 history

数据目录: $DATA_DIR
日志目录: $DATA_DIR/logs/
基线目录: $BASELINE_DIR
报告目录: $REPORT_DIR
EOF
}

# 主函数
main() {
    init_analyzer
    
    case "${1:-help}" in
        collect)
            shift
            collect_metrics "$@"
            ;;
        learn_baseline)
            shift
            learn_baseline "$@"
            ;;
        detect)
            shift
            detect_anomalies "$@"
            ;;
        report)
            shift
            generate_report "$@"
            ;;
        history)
            shift
            show_history
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "❌ 未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
