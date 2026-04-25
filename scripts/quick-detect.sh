#!/bin/bash
# version: 4.9.0-dev
# ==============================================================================
# 极简安全检测脚本 - quick-detect.sh
# 功能: 自动探测 OS/网络环境/已安装服务/OpenClaw部署模式
# 输出: 带 emoji 的友好摘要 + 推荐下一步操作
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
NC='\033[0m'

# ---------------------------------------------
# 配置
# ---------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${HOME}/.openclawhealthcheck/logs"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# ---------------------------------------------
# 探测结果变量
# ---------------------------------------------
DETECTED_OS=""
DETECTED_ENV=""
DETECTED_SERVICES=()
OPENCLAW_MODE=""
OPENCLAW_STATUS=""
SECURITY_SCORE=0
RISK_ITEMS=()
RECOMMENDATIONS=()

# ---------------------------------------------
# 日志函数
# ---------------------------------------------
log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[✓]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[⚠]${NC}  $1"; }
log_fail()  { echo -e "${RED}[✗]${NC}  $1"; }

# ---------------------------------------------
# 函数: 检测操作系统
# 功能: 识别 Linux 发行版类型
# ---------------------------------------------
detect_os() {
    log_info "正在检测操作系统..."
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        DETECTED_OS="$NAME ($VERSION_ID)"
    elif command -v uname >/dev/null 2>&1; then
        DETECTED_OS=$(uname -s)
    else
        DETECTED_OS="未知"
    fi
    log_ok "操作系统: $DETECTED_OS"
}

# ---------------------------------------------
# 函数: 检测运行环境
# 功能: 识别容器/VPS/物理机等环境
# ---------------------------------------------
detect_environment() {
    log_info "正在检测运行环境..."
    if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        DETECTED_ENV="🐳 Docker 容器"
    elif [ -f /run/systemd/system ]; then
        DETECTED_ENV="🖥️  Systemd 物理机/虚拟机"
    elif command -v systemctl >/dev/null 2>&1; then
        DETECTED_ENV="🖥️  虚拟机 (无 systemd)"
    elif [ -f /proc/1/cgroup ] && grep -q "lxc" /proc/1/cgroup 2>/dev/null; then
        DETECTED_ENV="📦 LXC 容器"
    elif [ -f /proc/vz ] && [ ! -d /proc/bc ]; then
        DETECTED_ENV="🆔 OpenVZ 容器"
    else
        DETECTED_ENV="❓ 未知环境"
    fi
    log_ok "运行环境: $DETECTED_ENV"
}

# ---------------------------------------------
# 函数: 检测已安装服务
# 功能: 检查常用服务是否运行
# ---------------------------------------------
detect_services() {
    log_info "正在检测已安装服务..."

    local services=("sshd" "firewalld" "ufw" "iptables" "fail2ban" "docker" "nginx" "apache2" "httpd" "supervisord" "systemd" "cron")
    local found=()

    for svc in "${services[@]}"; do
        if command -v "$svc" >/dev/null 2>&1; then
            found+=("$svc")
        elif systemctl is-active "$svc" >/dev/null 2>&1; then
            found+=("$svc(systemd)")
        elif service "$svc" status >/dev/null 2>&1; then
            found+=("$svc(service)")
        fi
    done

    if [ ${#found[@]} -eq 0 ]; then
        DETECTED_SERVICES=("无检测到常用服务")
    else
        DETECTED_SERVICES=("${found[@]}")
    fi

    local svc_display=$(IFS=', '; echo "${DETECTED_SERVICES[*]}")
    log_ok "已安装服务: $svc_display"
}

# ---------------------------------------------
# 函数: 检测 OpenClaw 部署模式
# 功能: 识别 OpenClaw 的安装和运行状态
# ---------------------------------------------
detect_openclaw() {
    log_info "正在检测 OpenClaw 部署状态..."

    # 检查进程
    if pgrep -f "openclaw" >/dev/null 2>&1 || pgrep -f "gateway" >/dev/null 2>&1; then
        OPENCLAW_STATUS="🟢 运行中"
    elif systemctl is-active openclaw >/dev/null 2>&1 || systemctl is-active gateway >/dev/null 2>&1; then
        OPENCLAW_STATUS="🟢 运行中 (systemd)"
    elif [ -f /workspace/projects/scripts/start.sh ]; then
        OPENCLAW_STATUS="🟡 已安装 (supervisord 管理)"
    else
        OPENCLAW_STATUS="⚪ 未运行"
    fi

    # 检查安装位置
    if command -v openclaw >/dev/null 2>&1; then
        local oc_path=$(which openclaw)
        OPENCLAW_MODE="CLI ($oc_path)"
    elif [ -d "/workspace/projects" ]; then
        OPENCLAW_MODE="源码部署 (/workspace/projects)"
    elif [ -d "${HOME}/.openclaw" ]; then
        OPENCLAW_MODE="用户目录 (~/.openclaw)"
    elif [ -d "/usr/local/openclaw" ]; then
        OPENCLAW_MODE="系统安装 (/usr/local/openclaw)"
    else
        OPENCLAW_MODE="未检测到"
    fi

    log_ok "OpenClaw 状态: $OPENCLAW_STATUS"
    log_ok "OpenClaw 模式: $OPENCLAW_MODE"
}

# ---------------------------------------------
# 函数: 快速安全评分
# 功能: 基于检测结果计算安全评分
# ---------------------------------------------
quick_security_score() {
    log_info "正在计算安全评分..."

    local score=60  # 基础分
    local risks=()

    # SSH 检查
    if [ -f /etc/ssh/sshd_config ]; then
        if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
            score=$((score + 10))
        else
            risks+=("⚠️  SSH 允许 root 登录")
        fi

        if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
            score=$((score + 10))
        else
            risks+=("⚠️  SSH 使用密码认证")
        fi
    fi

    # 防火墙检查
    if systemctl is-active firewalld >/dev/null 2>&1 || systemctl is-active ufw >/dev/null 2>&1; then
        score=$((score + 10))
    else
        risks+=("🔴 未检测到防火墙")
    fi

    # Fail2ban 检查
    if systemctl is-active fail2ban >/dev/null 2>&1; then
        score=$((score + 5))
    else
        risks+=("⚠️  未安装 Fail2ban")
    fi

    # OpenClaw 状态
    if echo "$OPENCLAW_STATUS" | grep -q "运行中"; then
        score=$((score + 5))
    else
        risks+=("⚠️  OpenClaw 未运行")
    fi

    SECURITY_SCORE=$score
    RISK_ITEMS=("${risks[@]}")

    log_ok "安全评分: $SECURITY_SCORE/100"
}

# ---------------------------------------------
# 函数: 生成推荐操作
# 功能: 根据检测结果推荐下一步操作
# ---------------------------------------------
generate_recommendations() {
    RECOMMENDATIONS=()

    if [ "$SECURITY_SCORE" -ge 85 ]; then
        RECOMMENDATIONS+=("✅ 安全状态良好，可进行快速检查确认")
    elif [ "$SECURITY_SCORE" -ge 60 ]; then
        RECOMMENDATIONS+=("🔧 建议运行标准加固: bash $SCRIPT_DIR/auto-fixer-v2.sh --risk-level safe")
    else
        RECOMMENDATIONS+=("🚨 安全风险较高，建议立即加固: bash $SCRIPT_DIR/auto-fixer-v2.sh --risk-level high")
    fi

    if [ "$OPENCLAW_STATUS" != "🟢 运行中" ] && [ "$OPENCLAW_STATUS" != "🟡 已安装 (supervisord 管理)" ]; then
        RECOMMENDATIONS+=("🚀 OpenClaw 未运行，如需启动请参考: bash $SCRIPT_DIR/quick-start.sh")
    fi

    RECOMMENDATIONS+=("📋 如需交互式向导: bash $SCRIPT_DIR/wizard.sh")
    RECOMMENDATIONS+=("⏰ 设置每日巡检: bash $SCRIPT_DIR/cron-manager.sh --cron \"0 2 * * *\"")
}

# ---------------------------------------------
# 函数: 打印摘要报告
# 功能: 输出完整的检测摘要
# ---------------------------------------------
print_summary() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  🛡️  OpenClaw 安全检测报告  |  $TIMESTAMP${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # 系统信息
    echo -e "  ${BLUE}📡 系统信息${NC}"
    echo -e "  ├─ 操作系统   : $DETECTED_OS"
    echo -e "  └─ 运行环境   : $DETECTED_ENV"
    echo ""

    # 服务状态
    echo -e "  ${BLUE}📦 已安装服务${NC}"
    local svc_count=${#DETECTED_SERVICES[@]}
    if [ "$svc_count" -eq 1 ] && [ "${DETECTED_SERVICES[0]}" = "无检测到常用服务" ]; then
        echo -e "  └─ $DETECTED_SERVICES"
    else
        for i in "${!DETECTED_SERVICES[@]}"; do
            local svc="${DETECTED_SERVICES[$i]}"
            if [ $i -eq $((svc_count - 1)) ]; then
                echo -e "  └─ $svc"
            else
                echo -e "  ├─ $svc"
            fi
        done
    fi
    echo ""

    # OpenClaw 状态
    echo -e "  ${BLUE}🚀 OpenClaw 状态${NC}"
    echo -e "  ├─ 运行状态   : $OPENCLAW_STATUS"
    echo -e "  └─ 部署模式   : $OPENCLAW_MODE"
    echo ""

    # 安全评分
    echo -e "  ${BLUE}🔒 安全评分${NC}"
    local bar_len=$((SECURITY_SCORE / 5))
    local bar=$(printf '█%.0s' $(seq 1 $bar_len))
    local bar_filled=$(printf '░%.0s' $(seq 1 $((20 - bar_len))))
    if [ "$SECURITY_SCORE" -ge 85 ]; then
        local score_color="${GREEN}"
    elif [ "$SECURITY_SCORE" -ge 60 ]; then
        local score_color="${YELLOW}"
    else
        local score_color="${RED}"
    fi
    echo -e "  └─ [$score_color$bar${NC}$bar_filled] $SECURITY_SCORE/100"
    echo ""

    # 风险提示
    if [ ${#RISK_ITEMS[@]} -gt 0 ] && [ "${RISK_ITEMS[0]}" != "" ]; then
        echo -e "  ${RED}⚠️  检测到的风险项${NC}"
        for risk in "${RISK_ITEMS[@]}"; do
            echo -e "  ├─ $risk"
        done
        echo ""
    fi

    # 推荐操作
    echo -e "  ${BLUE}💡 推荐操作${NC}"
    for rec in "${RECOMMENDATIONS[@]}"; do
        echo -e "  ├─ $rec"
    done
    echo ""

    # 快捷命令
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  快速命令:"
    echo -e "  ├─ 🔍 快速检查:  bash $SCRIPT_DIR/security-checks.sh --quick"
    echo -e "  ├─ 🔧 标准加固:  bash $SCRIPT_DIR/auto-fixer-v2.sh --risk-level safe"
    echo -e "  ├─ 🎯 交互向导:  bash $SCRIPT_DIR/wizard.sh"
    echo -e "  └─ ⏰ 定时巡检:  bash $SCRIPT_DIR/cron-manager.sh --cron list"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ---------------------------------------------
# 函数: 保存报告
# 功能: 将检测结果保存到日志目录
# ---------------------------------------------
save_report() {
    mkdir -p "$LOG_DIR"
    local report_file="$LOG_DIR/quick-detect-$(date +%Y%m%d-%H%M%S).log"

    {
        echo "OpenClaw 安全检测报告 - $TIMESTAMP"
        echo "=========================================="
        echo "操作系统: $DETECTED_OS"
        echo "运行环境: $DETECTED_ENV"
        echo "服务列表: ${DETECTED_SERVICES[*]}"
        echo "OpenClaw 状态: $OPENCLAW_STATUS"
        echo "OpenClaw 模式: $OPENCLAW_MODE"
        echo "安全评分: $SECURITY_SCORE/100"
        echo "风险项: ${RISK_ITEMS[*]}"
    } > "$report_file"

    log_info "报告已保存: $report_file"
}

# ---------------------------------------------
# 主函数
# 功能: 协调执行所有检测步骤
# ---------------------------------------------
main() {
    echo ""
    echo -e "${CYAN}🛡️  OpenClaw 极简安全检测${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    detect_os
    detect_environment
    detect_services
    detect_openclaw
    quick_security_score
    generate_recommendations
    print_summary
    save_report
}

# 入口
main "$@"
