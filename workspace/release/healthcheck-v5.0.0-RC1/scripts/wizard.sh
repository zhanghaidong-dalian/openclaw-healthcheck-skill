#!/bin/bash
# version: 4.9.0-dev
# ==============================================================================
# 中文交互式安全向导脚本 - wizard.sh
# 功能: 通过交互式问答引导用户完成安全检查配置
# 对话流程: 机器类型 → 使用者范围 → 检查深度
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
# 配置
# ---------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# 导出的配置变量（供其他脚本使用）
export MACHINE_TYPE=""
export USER_SCOPE=""
export CHECK_DEPTH=""
export WIZARD_COMPLETE=false

# ---------------------------------------------
# 打印装饰函数
# ---------------------------------------------
print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}🛡️  OpenClaw 安全检测向导${NC}${CYAN}                       ║${NC}"
    echo -e "${CYAN}║${NC}  交互式配置，引导您完成安全检查${CYAN}                   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    local num=$1
    local title=$2
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  第 ${num} 步：${title}${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_options() {
    local -a options=("$@")
    for i in "${!options[@]}"; do
        echo -e "  ${CYAN}[$((i+1))]${NC}  ${options[$i]}"
    done
}

print_selected() {
    local label=$1
    local value=$2
    echo -e "  ${GREEN}✓${NC} 已选择: ${BOLD}${value}${NC} $label"
}

print_note() {
    echo -e "  ${YELLOW}💡 提示:${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

# ---------------------------------------------
# 函数: 等待用户按 Enter
# 功能: 暂停等待用户确认
# ---------------------------------------------
wait_enter() {
    echo ""
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -rp "  按 ${BOLD}Enter${NC} 键继续... " dummy
}

# ---------------------------------------------
# 函数: 安全读取用户输入
# 功能: 带验证的菜单选择
# ---------------------------------------------
safe_read() {
    local prompt="$1"
    local min="$2"
    local max="$3"
    local var_name="$4"

    while true; do
        read -rp "  $prompt " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge "$min" ] && [ "$choice" -le "$max" ]; then
            eval "$var_name=$choice"
            return 0
        else
            print_error "请输入 ${min}-${max} 之间的数字"
        fi
    done
}

# ---------------------------------------------
# 函数: 第1步 - 选择机器类型
# 功能: 让用户选择部署场景
# ---------------------------------------------
step1_machine_type() {
    print_step 1 "选择机器类型"

    echo ""
    echo "  请问您要在哪种类型的机器上进行安全检测？"
    echo ""

    local options=(
        "💻 个人电脑（macOS / Linux 桌面）"
        "🖥️  VPS / 云服务器"
        "🍓 树莓派（Raspberry Pi）"
        "🏢 公司服务器"
        "🐳 Docker 容器环境"
    )

    print_options "${options[@]}"
    echo ""

    safe_read "请选择 (1-5): " 1 5 MACHINE_TYPE_CHOICE

    case $MACHINE_TYPE_CHOICE in
        1) MACHINE_TYPE="个人电脑" ;;
        2) MACHINE_TYPE="VPS" ;;
        3) MACHINE_TYPE="树莓派" ;;
        4) MACHINE_TYPE="公司服务器" ;;
        5) MACHINE_TYPE="Docker" ;;
    esac

    print_selected "" "$MACHINE_TYPE"
    echo ""
}

# ---------------------------------------------
# 函数: 第2步 - 选择使用者范围
# 功能: 确定安全检查的严格程度
# ---------------------------------------------
step2_user_scope() {
    print_step 2 "选择使用者范围"

    echo ""
    echo "  哪些人会使用这台机器？"
    echo ""

    local options=(
        "👤 仅我自己"
        "👥 我的小团队（2-10人）"
        "🌐 对外提供服务（互联网访问）"
    )

    print_options "${options[@]}"
    echo ""

    safe_read "请选择 (1-3): " 1 3 USER_SCOPE_CHOICE

    case $USER_SCOPE_CHOICE in
        1) USER_SCOPE="仅自己" ;;
        2) USER_SCOPE="团队" ;;
        3) USER_SCOPE="对外服务" ;;
    esac

    print_selected "" "$USER_SCOPE"

    # 根据选择显示不同建议
    case $USER_SCOPE_CHOICE in
        1)
            print_note "适合个人开发环境，重点关注本地数据安全"
            ;;
        2)
            print_note "需要考虑团队协作安全，建议开启审计日志"
            ;;
        3)
            print_note "安全要求最高，建议开启所有安全检查项"
            ;;
    esac
    echo ""
}

# ---------------------------------------------
# 函数: 第3步 - 选择检查深度
# 功能: 确定检查的详细程度
# ---------------------------------------------
step3_check_depth() {
    print_step 3 "选择检查深度"

    echo ""
    echo "  请选择安全检查的详细程度："
    echo ""

    local options=(
        "⚡ 快速检查（5分钟）- 核心安全项，适合日常巡检"
        "🔧 标准检查（15分钟）- 全面检查，覆盖常见风险"
        "🔍 完整审计（30分钟）- 深度检查，包括渗透测试"
    )

    print_options "${options[@]}"
    echo ""

    safe_read "请选择 (1-3): " 1 3 CHECK_DEPTH_CHOICE

    case $CHECK_DEPTH_CHOICE in
        1) CHECK_DEPTH="快速" ;;
        2) CHECK_DEPTH="标准" ;;
        3) CHECK_DEPTH="完整" ;;
    esac

    print_selected "" "$CHECK_DEPTH"
    echo ""
}

# ---------------------------------------------
# 函数: 显示配置确认
# 功能: 让用户确认所有选择
# ---------------------------------------------
show_confirmation() {
    print_step 4 "确认配置"

    echo ""
    echo -e "  请确认以下配置："
    echo ""
    echo -e "  ${CYAN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "  ${CYAN}│${NC}  机器类型    : ${GREEN}${MACHINE_TYPE}${NC}"
    echo -e "  ${CYAN}│${NC}  使用者范围  : ${GREEN}${USER_SCOPE}${NC}"
    echo -e "  ${CYAN}│${NC}  检查深度    : ${GREEN}${CHECK_DEPTH}${NC}"
    echo -e "  ${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo ""
}

# ---------------------------------------------
# 函数: 执行检查
# 功能: 根据配置执行相应的检查脚本
# ---------------------------------------------
execute_checks() {
    print_step 5 "执行检查"

    echo ""
    echo -e "  ${GREEN}🚀 开始执行安全检查...${NC}"
    echo ""

    # 根据检查深度选择执行脚本
    local extra_args=""

    case $CHECK_DEPTH in
        "快速")
            extra_args="--quick"
            ;;
        "标准")
            extra_args=""
            ;;
        "完整")
            extra_args="--full --audit"
            ;;
    esac

    # 根据机器类型添加额外参数
    case $MACHINE_TYPE in
        "Docker")
            extra_args="$extra_args --container"
            ;;
        "树莓派")
            extra_args="$extra_args --arm"
            ;;
    esac

    # 根据使用者范围调整
    case $USER_SCOPE in
        "对外服务")
            extra_args="$extra_args --strict"
            ;;
    esac

    echo -e "  执行命令: ${CYAN}bash $SCRIPT_DIR/security-checks.sh $extra_args${NC}"
    echo ""

    # 执行检查
    if bash "$SCRIPT_DIR/security-checks.sh" $extra_args; then
        echo ""
        echo -e "  ${GREEN}✅ 安全检查完成！${NC}"
    else
        echo ""
        echo -e "  ${YELLOW}⚠️  安全检查完成，但存在一些警告${NC}"
    fi
}

# ---------------------------------------------
# 函数: 显示后续建议
# 功能: 检查完成后展示可进行的操作
# ---------------------------------------------
show_next_steps() {
    print_step 6 "后续操作"

    echo ""
    echo -e "  ${BOLD}检查完成！您还可以：${NC}"
    echo ""

    local steps=(
        "🔧 自动修复检测到的风险项"
        "📊 查看详细报告"
        "⏰ 设置每日定时巡检"
        "🔄 重新运行向导"
        "❌ 退出"
    )

    for i in "${!steps[@]}"; do
        echo -e "    ${CYAN}[$((i+1))]${NC}  ${steps[$i]}"
    done

    echo ""
    safe_read "请选择 (1-5): " 1 5 NEXT_CHOICE

    case $NEXT_CHOICE in
        1)
            echo ""
            echo -e "  ${GREEN}🚀 启动自动修复向导...${NC}"
            bash "$SCRIPT_DIR/auto-fixer-v2.sh"
            ;;
        2)
            echo ""
            echo -e "  ${GREEN}📊 打开报告目录...${NC}"
            local log_dir="${HOME}/.openclawhealthcheck/logs"
            if [ -d "$log_dir" ]; then
                ls -lh "$log_dir"/*.log 2>/dev/null || echo "  暂无报告"
            else
                echo "  暂无报告"
            fi
            ;;
        3)
            echo ""
            echo -e "  ${GREEN}⏰ 启动定时任务管理器...${NC}"
            bash "$SCRIPT_DIR/cron-manager.sh"
            ;;
        4)
            echo ""
            bash "$0"
            ;;
        5)
            echo ""
            echo -e "  ${CYAN}👋 再见！记得定期进行安全检查哦～${NC}"
            echo ""
            exit 0
            ;;
    esac
}

# ---------------------------------------------
# 函数: 主函数
# 功能: 协调整个向导流程
# ---------------------------------------------
main() {
    print_banner

    # 检查前置条件
    echo -e "  ${YELLOW}💡 欢迎使用安全检测向导！${NC}"
    echo "  我们将通过几个简单的问题，为您定制最适合的安全检查方案。"
    echo ""
    wait_enter

    # 执行各步骤
    step1_machine_type
    wait_enter

    step2_user_scope
    wait_enter

    step3_check_depth
    wait_enter

    # 确认配置
    show_confirmation
    echo -e "  ${GREEN}请确认以上配置，按 Enter 开始检查...${NC}"
    wait_enter

    # 标记向导完成
    WIZARD_COMPLETE=true
    export WIZARD_COMPLETE

    # 执行检查
    execute_checks

    # 后续操作
    show_next_steps
}

# 入口
main "$@"
