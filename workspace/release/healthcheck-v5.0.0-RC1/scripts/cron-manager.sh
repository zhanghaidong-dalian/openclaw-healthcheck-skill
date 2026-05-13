#!/bin/bash
# version: 4.9.0-dev
# ==============================================================================
# 定时巡检管理脚本 - cron-manager.sh
# 功能: 管理 OpenClaw 安全巡检定时任务
# 操作: 设置/查看/删除定时任务，支持飞书通知
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
CRON_MARKER="# OPENCLAW_HEALTHCHECK"
CRON_LABEL="OpenClaw 安全巡检"
LOG_DIR="${HOME}/.openclawhealthcheck/logs"

# 通知配置
NOTIFY_ENABLED=false
NOTIFY_SUMMARY=false

# 巡检脚本路径
HEALTHCHECK_SCRIPT="$SCRIPT_DIR/security-checks.sh"
QUICK_DETECT_SCRIPT="$SCRIPT_DIR/quick-detect.sh"

# ---------------------------------------------
# 日志函数
# ---------------------------------------------
log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[✓]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[⚠]${NC}  $1"; }
log_fail()  { echo -e "${RED}[✗]${NC}  $1"; }

# ---------------------------------------------
# 打印函数
# ---------------------------------------------
print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}⏰ OpenClaw 定时巡检管理器${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  自动化安全巡检，守护系统安全${NC}                       ${CYAN}║${NC}"
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
# 函数: 检查 cron 是否可用
# 功能: 验证系统支持 cron
# ---------------------------------------------
check_cron_available() {
    if ! command -v crontab >/dev/null 2>&1; then
        log_fail "cron 未安装，请先安装 cron"
        echo "  Ubuntu/Debian: sudo apt install cron"
        echo "  CentOS/RHEL:   sudo yum install cronie"
        return 1
    fi

    if ! systemctl is-active --quiet cron 2>/dev/null && ! pgrep -x crond >/dev/null; then
        log_warn "cron 服务未运行，尝试启动..."
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl start cron 2>/dev/null || sudo systemctl start crond 2>/dev/null || true
        fi
    fi

    return 0
}

# ---------------------------------------------
# 函数: 获取现有 cron 任务
# 功能: 读取用户的 crontab 内容
# ---------------------------------------------
get_cron_jobs() {
    crontab -l 2>/dev/null || true
}

# ---------------------------------------------
# 函数: 检查 OpenClaw 巡检任务是否已存在
# 功能: 判断定时任务是否已配置
# ---------------------------------------------
cron_exists() {
    local existing
    existing=$(get_cron_jobs)
    echo "$existing" | grep -q "$CRON_MARKER"
}

# ---------------------------------------------
# 函数: 获取 OpenClaw 巡检任务详情
# 功能: 提取并展示已配置的巡检任务
# ---------------------------------------------
get_cron_details() {
    local existing
    existing=$(get_cron_jobs)

    local jobs
    jobs=$(echo "$existing" | grep "$CRON_MARKER" || true)

    if [ -z "$jobs" ]; then
        echo ""
        log_warn "未找到 OpenClaw 巡检任务"
        return 1
    fi

    echo ""
    echo -e "  ${GREEN}已配置的巡检任务：${NC}"
    echo ""

    local i=1
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            # 解析 cron 表达式
            local cron_expr="${line%% *}"
            cron_expr="${cron_expr#* }"  # 去掉第一个空格前的字符

            # 简化显示
            local desc=""
            if echo "$line" | grep -q "quick-detect"; then
                desc="快速检测"
            elif echo "$line" | grep -q "security-checks"; then
                desc="安全检查"
            fi

            if echo "$line" | grep -q "notify"; then
                desc="$desc + 飞书通知"
            fi

            if echo "$line" | grep -q "summary"; then
                desc="$desc + 摘要报告"
            fi

            echo -e "  ${CYAN}[$i]${NC} $cron_expr"
            echo -e "      任务: $desc"
            echo -e "      脚本: ${line##*bash }"
            echo ""
            i=$((i + 1))
        fi
    done <<< "$jobs"

    return 0
}

# ---------------------------------------------
# 函数: 列出所有定时任务
# 功能: 查看当前用户的完整 cron 配置
# ---------------------------------------------
list_cron_jobs() {
    print_step "📋 查看定时任务"

    check_cron_available || return 1

    # 显示 OpenClaw 任务
    get_cron_details

    # 显示其他任务（可选）
    echo -e "  ${BLUE}完整 cron 配置：${NC}"
    echo ""

    local existing
    existing=$(get_cron_jobs)

    if [ -z "$existing" ]; then
        echo "  (空 - 无定时任务)"
    else
        echo "$existing" | grep -v "^#" | grep -v "^$" | head -20
    fi

    echo ""
    echo -e "  ${BLUE}💡 提示：${NC}"
    echo "    使用 --cron list 查看 OpenClaw 巡检任务详情"
    echo ""
}

# ---------------------------------------------
# 函数: 安装 cron 任务
# 功能: 添加 OpenClaw 巡检定时任务
# ---------------------------------------------
install_cron_job() {
    local cron_expr="$1"

    print_step "🔧 安装定时任务"

    check_cron_available || return 1

    # 验证 cron 表达式
    if ! echo "$cron_expr" | grep -qE "^[0-9*,/-]+\s+[0-9*,/-]+\s+[0-9*,/-]+\s+[0-9*,/-]+\s+[0-9*,/-]+$"; then
        log_fail "无效的 cron 表达式: $cron_expr"
        show_cron_help
        return 1
    fi

    echo ""
    echo -e "  ${GREEN}✅ 计划安装的巡检任务：${NC}"
    echo ""
    echo -e "    表达式: ${CYAN}$cron_expr${NC}"
    echo -e "    说明:   ${CYAN}$(describe_cron "$cron_expr")${NC}"
    echo ""

    # 询问使用哪个脚本
    echo "  请选择巡检脚本："
    echo "    [1] 快速检测 (quick-detect.sh) - 推荐"
    echo "    [2] 完整安全检查 (security-checks.sh)"
    echo ""
    read -rp '  请选择 (1-2，默认1): ' script_choice
    script_choice="${script_choice:-1}"

    case $script_choice in
        1) selected_script="$QUICK_DETECT_SCRIPT" ;;
        2) selected_script="$HEALTHCHECK_SCRIPT" ;;
        *) selected_script="$QUICK_DETECT_SCRIPT" ;;
    esac

    # 通知选项
    echo ""
    echo -e "  ${BLUE}通知选项：${NC}"
    read -rp '  是否发送飞书通知? (y/N): ' enable_notify
    if [ "$enable_notify" = "y" ] || [ "$enable_notify" = "Y" ]; then
        NOTIFY_ENABLED=true
        echo -e "    ✓ 启用飞书通知"
    fi

    read -rp '  是否生成摘要报告? (y/N): ' enable_summary
    if [ "$enable_summary" = "y" ] || [ "$enable_summary" = "Y" ]; then
        NOTIFY_SUMMARY=true
        echo -e "    ✓ 生成摘要报告"
    fi

    # 确认安装
    echo ""
    read -rp '  确认安装? (Y/n): ' confirm
    confirm="${confirm:-Y}"

    if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
        echo "  已取消"
        return 0
    fi

    # 构建 cron 命令
    local cron_cmd="$cron_expr bash $selected_script"
    if [ "$NOTIFY_ENABLED" = true ]; then
        cron_cmd="$cron_cmd --notify"
    fi
    if [ "$NOTIFY_SUMMARY" = true ]; then
        cron_cmd="$cron_cmd --summary"
    fi

    # 移除旧任务
    remove_cron_job

    # 添加新任务
    local current_cron
    current_cron=$(get_cron_jobs)

    # 添加注释和任务
    local new_cron="${current_cron:+$current_cron}"
    new_cron="${new_cron}${CRON_MARKER} $CRON_LABEL"$'
'
    new_cron="${new_cron}${cron_cmd}"

    # 写入 crontab
    echo "$new_cron" | crontab -

    if [ $? -eq 0 ]; then
        echo ""
        log_ok "定时任务安装成功！"
        echo ""
        echo -e "  ${GREEN}任务详情：${NC}"
        echo "    $cron_cmd"
        echo ""

        # 验证
        echo -e "  ${BLUE}验证安装：${NC}"
        get_cron_details

        # 设置日志轮转
        setup_log_rotation

        echo ""
        echo -e "  ${CYAN}✅ 定时巡检已启用！${NC}"
        echo "    预计首次执行: $(next_run_time "$cron_expr")"
        echo ""
    else
        log_fail "安装失败"
        return 1
    fi
}

# ---------------------------------------------
# 函数: 删除 cron 任务
# 功能: 移除 OpenClaw 巡检定时任务
# ---------------------------------------------
remove_cron_job() {
    print_step "🗑️  删除定时任务"

    check_cron_available || return 1

    if ! cron_exists; then
        log_warn "未找到 OpenClaw 巡检任务，无需删除"
        return 0
    fi

    echo ""
    echo -e "  ${YELLOW}⚠️  即将删除 OpenClaw 巡检定时任务${NC}"
    echo ""

    read -rp '  确认删除? (yes/no): ' confirm

    if [ "$confirm" != "yes" ]; then
        echo "  已取消"
        return 0
    fi

    # 移除任务
    local current_cron
    current_cron=$(get_cron_jobs)

    local new_cron
    new_cron=$(echo "$current_cron" | grep -v "$CRON_MARKER" | grep -v "^$CRON_LABEL$" || true)

    echo "$new_cron" | crontab -

    if [ $? -eq 0 ]; then
        echo ""
        log_ok "定时任务已删除"
        echo ""
        echo -e "  ${GREEN}✅ 巡检任务已停止！${NC}"
        echo "    历史日志仍保留在: $LOG_DIR"
        echo ""
    else
        log_fail "删除失败"
        return 1
    fi
}

# ---------------------------------------------
# 函数: 设置日志轮转
# 功能: 配置 logrotate 保留巡检日志
# ---------------------------------------------
setup_log_rotation() {
    local logrotate_conf="/etc/logrotate.d/openclaw-healthcheck"

    if [ ! -w "$(dirname "$logrotate_conf")" ]; then
        # 没有权限创建系统级配置，创建用户级配置
        local user_logrotate="${HOME}/.logrotate.d/openclaw-healthcheck"
        mkdir -p "$(dirname "$user_logrotate")"

        cat > "$user_logrotate" << EOF
$LOG_DIR/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
EOF
        log_info "已创建日志轮转配置: $user_logrotate"
        return 0
    fi

    # 系统级配置
    cat > "$logrotate_conf" << EOF
$LOG_DIR/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 0644 root root
}
EOF

    log_ok "已配置日志轮转（保留7天）"
}

# ---------------------------------------------
# 函数: 描述 cron 表达式含义
# 功能: 将 cron 表达式转换为可读描述
# ---------------------------------------------
describe_cron() {
    local expr="$1"
    local parts=($expr)

    # 简化解释
    case "$expr" in
        "0 2 * * *")  echo "每天凌晨 2:00 执行" ;;
        "0 */4 * * *") echo "每 4 小时执行一次" ;;
        "0 */6 * * *") echo "每 6 小时执行一次" ;;
        "0 9 * * 1-5") echo "工作日每天上午 9:00 执行" ;;
        "0 9 * * *")   echo "每天上午 9:00 执行" ;;
        "0 2 * * 0")   echo "每周日凌晨 2:00 执行" ;;
        "0 2 1 * *")   echo "每月1日凌晨 2:00 执行" ;;
        *)             echo "按自定义表达式执行: $expr" ;;
    esac
}

# ---------------------------------------------
# 函数: 计算下次执行时间
# 功能: 估算 cron 下次执行的大致时间
# ---------------------------------------------
next_run_time() {
    local expr="$1"

    # 使用简单估算（不依赖 cron 库）
    local hour minute
    minute=$(echo "$expr" | awk '{print $1}')
    hour=$(echo "$expr" | awk '{print $2}')

    if [ "$minute" = "0" ]; then
        echo "约 ${hour}:00"
    else
        echo "约 ${hour}:${minute}"
    fi
}

# ---------------------------------------------
# 函数: 显示 cron 帮助
# 功能: 展示常用 cron 表达式示例
# ---------------------------------------------
show_cron_help() {
    cat << EOF

${CYAN}╔════════════════════════════════════════════════════════╗${NC}
${CYAN}║${NC}  ${BOLD}⏰ 常用 Cron 表达式参考${NC}                            ${CYAN}║${NC}
${CYAN}╚════════════════════════════════════════════════════════╝${NC}

  表达式格式: 分 时 日 月 周

  ┌─────────────────┬────────────────────────┐
  │ 表达式          │ 说明                    │
  ├─────────────────┼────────────────────────┤
  │ 0 2 * * *       │ 每天凌晨 2:00          │
  │ 0 */4 * * *     │ 每 4 小时               │
  │ 0 9 * * 1-5     │ 工作日每天 9:00        │
  │ 0 9 * * *       │ 每天 9:00              │
  │ 0 2 * * 0       │ 每周日 2:00            │
  │ 0 2 1 * *       │ 每月 1日 2:00          │
  └─────────────────┴────────────────────────┘

  在线验证: https://crontab.guru/

EOF
}

# ---------------------------------------------
# 函数: 发送飞书通知（示例）
# 功能: 调用飞书 API 发送巡检结果
# ---------------------------------------------
send_feishu_notification() {
    local status="$1"
    local message="$2"

    if [ "$NOTIFY_ENABLED" != true ]; then
        return 0
    fi

    # 检查是否有飞书配置
    local feishu_token
    feishu_token=$(grep -r "feishu.*token\|lark.*token" "$HOME/.openclaw" 2>/dev/null | head -1 | awk '{print $NF}' || true)

    if [ -z "$feishu_token" ]; then
        log_warn "未配置飞书通知，跳过"
        return 0
    fi

    # 构造消息
    local title="🛡️ OpenClaw 安全巡检报告"
    local content="状态: $status\n\n$message"

    # 调用飞书 webhook（示例）
    # 实际使用时需要替换为真实的 webhook URL
    log_info "飞书通知: $status"
}

# ---------------------------------------------
# 函数: 生成摘要报告
# 功能: 创建简短的巡检摘要
# ---------------------------------------------
generate_summary_report() {
    if [ "$NOTIFY_SUMMARY" != true ]; then
        return 0
    fi

    local latest_log
    latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)

    if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
        echo ""
        echo -e "  ${BLUE}📊 最近巡检摘要：${NC}"
        echo ""

        # 提取关键信息
        local total=$(grep -c "CHECK\|FIX\|WARN" "$latest_log" 2>/dev/null || echo "0")
        local passed=$(grep -c "✓\|PASS\|OK" "$latest_log" 2>/dev/null || echo "0")
        local failed=$(grep -c "✗\|FAIL\|ERROR" "$latest_log" 2>/dev/null || echo "0")

        echo "    总检查项: $total"
        echo "    通过: $passed"
        echo "    失败: $failed"
        echo ""
    fi
}

# ---------------------------------------------
# 函数: 交互式向导
# 功能: 引导用户设置定时任务
# ---------------------------------------------
interactive_setup() {
    print_step "🎯 交互式设置定时任务"

    echo ""
    echo "  欢迎使用定时巡检设置向导！"
    echo ""

    # 选择预设或自定义
    echo "  请选择巡检频率："
    echo '    [1] 每天凌晨 2:00  (推荐)'
    echo "    [2] 每 4 小时"
    echo "    [3] 工作日每天 9:00"
    echo "    [4] 每周日凌晨 2:00"
    echo "    [5] 自定义表达式"
    echo ""

    read -rp '  请选择 (1-5): ' freq_choice
    freq_choice="${freq_choice:-1}"

    case $freq_choice in
        1) install_cron_job "0 2 * * *" ;;
        2) install_cron_job "0 */4 * * *" ;;
        3) install_cron_job "0 9 * * 1-5" ;;
        4) install_cron_job "0 2 * * 0" ;;
        5)
            echo ""
            echo -e "  ${BLUE}请输入 cron 表达式（分 时 日 月 周）：${NC}"
            echo -e "  示例: ${CYAN}30 3 * * *${NC}"
            read -rp '  表达式: ' custom_expr
            if [ -n "$custom_expr" ]; then
                install_cron_job "$custom_expr"
            else
                log_fail "表达式不能为空"
            fi
            ;;
        *)
            install_cron_job "0 2 * * *"
            ;;
    esac
}

# ---------------------------------------------
# 函数: 显示状态
# 功能: 展示当前巡检配置状态
# ---------------------------------------------
show_status() {
    print_step "📊 巡检状态"

    check_cron_available || return 1

    echo ""

    if cron_exists; then
        echo -e "  ${GREEN}🟢 定时巡检: 已启用${NC}"
        echo ""
        get_cron_details
        generate_summary_report
    else
        echo -e "  ${YELLOW}🟡 定时巡检: 未配置${NC}"
        echo ""
        echo -e "  ${BLUE}💡 要启用定时巡检，请运行：${NC}"
        echo "    bash $0 --cron \"0 2 * * *\""
        echo ""
        echo "  或使用交互式设置："
        echo "    bash $0 --cron"
        echo ""
    fi

    # 显示最近日志
    if [ -d "$LOG_DIR" ]; then
        local latest_log
        latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)

        if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
            echo -e "  ${BLUE}📁 最近日志：${NC} $latest_log"
            echo -e "  最后修改: $(stat -c %y "$latest_log" 2>/dev/null | cut -d'.' -f1)"
        fi
    fi
}

# ---------------------------------------------
# 函数: 显示帮助
# ---------------------------------------------
show_help() {
    cat << EOF

${CYAN}╔════════════════════════════════════════════════════════╗${NC}
${CYAN}║${NC}  ${BOLD}⏰ OpenClaw 定时巡检管理器${NC}                         ${CYAN}║${NC}
${CYAN}╚════════════════════════════════════════════════════════╝${NC}

${BOLD}用法:${NC}
  bash $0 --cron <表达式或操作> [选项]

${BOLD}定时任务操作:${NC}
  --cron "0 2 * * *"     设置每日凌晨 2:00 巡检
  --cron list            查看已配置的巡检任务
  --cron remove          删除巡检定时任务
  --cron status          查看巡检状态

${BOLD}巡检选项:${NC}
  --notify               巡检完成后发送飞书通知
  --summary              生成并显示摘要报告

${BOLD}示例:${NC}
  # 设置每日巡检
  bash $0 --cron "0 2 * * *"

  # 设置每4小时巡检并启用飞书通知
  bash $0 --cron "0 */4 * * *" --notify

  # 查看已配置的任务
  bash $0 --cron list

  # 删除定时任务
  bash $0 --cron remove

  # 交互式设置（无参数）
  bash $0 --cron

${BOLD}常用 Cron 表达式:${NC}
  0 2 * * *       每天凌晨 2:00
  0 */4 * * *     每 4 小时
  0 9 * * 1-5     工作日 9:00
  0 2 * * 0       每周日 2:00

EOF
}

# ---------------------------------------------
# 函数: 解析参数
# ---------------------------------------------
parse_args() {
    local action=""
    local cron_expr=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --cron)
                action="install"
                if [[ "${2:-}" != "" ]] && [[ "${2:-}" != --* ]]; then
                    cron_expr="$2"
                    shift
                elif [[ "${2:-}" == "" ]] || [[ "${2:-}" == --* ]]; then
                    # 无参数或下一参数是选项，进入交互模式
                    action="interactive"
                fi
                shift
                ;;
            --notify)
                NOTIFY_ENABLED=true
                shift
                ;;
            --summary)
                NOTIFY_SUMMARY=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            list|remove|status)
                action="$1"
                shift
                ;;
            *)
                echo -e "  ${RED}✗ 未知参数: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done

    # 执行操作
    case "$action" in
        install)
            if [ -n "$cron_expr" ]; then
                install_cron_job "$cron_expr"
            else
                install_cron_job "0 2 * * *"
            fi
            ;;
        interactive)
            interactive_setup
            ;;
        list)
            list_cron_jobs
            ;;
        remove)
            remove_cron_job
            ;;
        status)
            show_status
            ;;
        *)
            show_status
            ;;
    esac
}

# ---------------------------------------------
# 主函数
# ---------------------------------------------
main() {
    print_header

    mkdir -p "$LOG_DIR"

    parse_args "$@"
}

# 入口
main "$@"
