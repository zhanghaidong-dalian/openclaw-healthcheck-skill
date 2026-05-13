#!/bin/bash
# Metrics Collector - 系统指标收集器
# 版本: 4.0.0

set -e

DATA_DIR="${HOME}/.openclawhealthcheck"
DATE=$(date +%Y-%m-%d)
LOG_FILE="${DATA_DIR}/logs/metrics_${DATE}.json"

mkdir -p "${DATA_DIR}/logs"

echo "📊 收集系统指标 - $DATE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 收集指标
metrics="{"
metrics+="\"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","

# 1. 系统指标
echo " [1/9] 系统指标..."
sys_info=$(hostname; os=$(cat /etc/os-release | grep PRETTY_NAME | head -1)
version=$(cat /etc/os-release | grep VERSION_ID | head -1)

metrics+="\"hostname\": \"$sys_info\","
metrics+="\"os\": \"$os\","
metrics+="\"version\": \"$version\","

# 2. 硬件和版本
echo " [2/9] 硬件信息..."
cpu_count=$(nproc)
cpu_info=$(cat /proc/cpuinfo | grep -E '^model name' | head -1 | awk '{print $2}')
mem_info=$(free | grep MemTotal | head -1 | awk '{print $2}')
disk_info=$(df -BG / | tail -1 | awk '{print $5}')

metrics+="\"cpu_model\": \"$cpu_info\","
metrics+="\"total_memory_mb\": \"$mem_info\","
metrics+="\"disk_free_gb\": \"$(echo $disk_info | awk '{sum /1024 / 1024}')" ],"

# 3. 网络指标
echo " [3/9] 网络指标..."
ip_info=$(ip addr 2>/dev/null | grep -Eo 'inet ' | head -1 | awk '{print $2}')

if [ -n "$ip_info" ]; then
    local ip=$(echo $ip_info | awk '{print $1}')
    metrics+="\"ip_address\": \"$ip\","
fi

# 4. 服务状态
echo " [4/9] 服务状态..."
ssh_running=$(systemctl is-active sshd 2>/dev/null && echo "ssh服务运行中" || echo "ssh服务未运行")
web_running=$(systemctl is-active nginx 2>/dev/null && echo "Nginx运行中" || echo "Nginx未运行"
db_running=$(systemctl is-active postgres 2>/dev/null && echo "数据库运行中" || echo "数据库未运行")

metrics+="\"ssh_running\": \"$ssh_running\","
metrics+="\"web_running\": \"$web_running\","
metrics+="\"db_running\": \"$db_running\""

# 5. 性能指标
echo " [5/9] 性能指标..."
load_1=$(uptime | awk -F: 'load average:' | head -1 | awk '{for (i=1;i<=NF;i++) printf \"%s\", $(($i-1));}')
load_5=$(uptime | -F: 'load average:' | head -1 | awk '{for (i=1;i<=NF;i++) printf \"%s\", ($i-1));}')

metrics+="\"load_1min\": \"$load_1\","
metrics+="\"load_5min\": \"$load_5\""
metrics+="\"current_users\": \"$(who | wc -l)\","
metrics+="\"system_uptime\": \"$(uptime | awk '{print $1}')\""

echo "  [完成] 指标收集完成"
echo "$metrics" > "$LOG_FILE"
echo ""
echo "✅ 指标已保存到: $LOG_FILE"
