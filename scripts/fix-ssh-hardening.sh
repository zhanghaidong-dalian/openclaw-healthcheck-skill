#!/bin/bash
#===============================================================================
# SSH安全加固脚本
# 一键修复SSH配置安全问题
#===============================================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# SSH配置文件路径
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_DIR="/var/backups/ssh-hardening"

# 打印带颜色的信息
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 创建备份
create_backup() {
    print_info "创建SSH配置文件备份..."
    mkdir -p "$BACKUP_DIR"
    local backup_file="$BACKUP_DIR/sshd_config.$(date +%Y%m%d_%H%M%S)"
    cp "$SSHD_CONFIG" "$backup_file"
    print_success "备份已保存到: $backup_file"
}

# 恢复备份
restore_backup() {
    local latest_backup=$(ls -t "$BACKUP_DIR"/sshd_config.* 2>/dev/null | head -1)
    if [[ -n "$latest_backup" ]]; then
        print_info "正在从备份恢复..."
        cp "$latest_backup" "$SSHD_CONFIG"
        systemctl restart sshd
        print_success "已恢复到备份: $latest_backup"
    else
        print_error "未找到备份文件"
        exit 1
    fi
}

# 检查配置项
check_config() {
    local param=$1
    local expected=$2
    local current=$(grep -E "^#?${param}\\s" "$SSHD_CONFIG" 2>/dev/null | tail -1)
    
    if echo "$current" | grep -q "$expected"; then
        echo "✓"
    else
        echo "✗ (当前: ${current:-'未设置'})"
    fi
}

# 显示当前状态
show_status() {
    echo ""
    echo "========================================"
    echo "       SSH安全配置检查报告"
    echo "========================================"
    echo ""
    printf "%-40s %s\n" "检查项" "状态"
    echo "----------------------------------------"
    printf "%-40s %s\n" "1. 禁用root登录 (PermitRootLogin no)" "$(check_config PermitRootLogin no)"
    printf "%-40s %s\n" "2. 禁用密码认证 (PasswordAuthentication no)" "$(check_config PasswordAuthentication no)"
    printf "%-40s %s\n" "3. 启用密钥认证 (PubkeyAuthentication yes)" "$(check_config PubkeyAuthentication yes)"
    printf "%-40s %s\n" "4. 使用SSH协议版本2 (Protocol 2)" "$(check_config Protocol 2)"
    printf "%-40s %s\n" "5. 修改默认端口 (Port ≠ 22)" "$(check_config Port 22 | grep -q '✗' && echo '✓' || echo '✗ (当前使用默认端口22)')"
    echo "----------------------------------------"
    echo ""
}

# 修复配置项
fix_config() {
    local param=$1
    local value=$2
    local description=$3
    
    print_info "正在配置: $description"
    
    # 删除现有的配置行（包括注释掉的）
    sed -i "/^#*${param}/d" "$SSHD_CONFIG"
    
    # 添加新的配置
    echo "" >> "$SSHD_CONFIG"
    echo "# $description" >> "$SSHD_CONFIG"
    echo "$param $value" >> "$SSHD_CONFIG"
    
    print_success "已配置: $param $value"
}

# 禁用root登录
fix_root_login() {
    fix_config "PermitRootLogin" "no" "禁用root用户直接登录"
    print_warn "提示: 请确保已有普通用户可用，否则可能无法登录！"
}

# 禁用密码认证
fix_password_auth() {
    echo ""
    print_warn "⚠️  警告: 即将禁用密码认证！"
    print_warn "   请确保已配置SSH密钥，否则会被锁定！"
    echo ""
    read -p "确认已配置SSH密钥并继续? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_info "已取消密码认证修复"
        return
    fi
    
    fix_config "PasswordAuthentication" "no" "禁用密码认证，强制使用密钥"
    fix_config "PubkeyAuthentication" "yes" "启用公钥认证"
    print_success "已启用密钥认证，禁用密码认证"
}

# 强制使用SSH协议版本2
fix_protocol() {
    fix_config "Protocol" "2" "强制使用SSH协议版本2"
}

# 修改默认端口
fix_port() {
    echo ""
    read -p "是否修改SSH默认端口? (yes/no): " change_port
    
    if [[ "$change_port" == "yes" ]]; then
        read -p "请输入新端口(1024-65535): " new_port
        
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [[ "$new_port" -ge 1024 ]] && [[ "$new_port" -le 65535 ]]; then
            fix_config "Port" "$new_port" "修改SSH服务端口"
            print_warn "⚠️  重要: SSH端口已修改为 $new_port"
            print_warn "   请使用以下命令连接:"
            print_warn "   ssh -p $new_port user@host"
        else
            print_error "无效端口，必须是1024-65535之间的数字"
        fi
    else
        print_info "保留默认端口22"
    fi
}

# 验证配置
test_config() {
    print_info "验证SSH配置..."
    if sshd -t; then
        print_success "SSH配置语法正确"
        return 0
    else
        print_error "SSH配置存在错误，请检查"
        return 1
    fi
}

# 重启SSH服务
restart_ssh() {
    print_info "重启SSH服务..."
    if systemctl restart sshd; then
        print_success "SSH服务已重启"
    else
        print_error "SSH服务重启失败"
        exit 1
    fi
}

# 显示帮助
show_help() {
    cat << EOF
SSH安全加固脚本

用法: $0 [选项]

选项:
    status      显示当前SSH安全配置状态
    fix         交互式修复SSH配置
    auto        自动修复（禁用root登录，谨慎使用）
    restore     恢复上一次的备份
    test        验证当前SSH配置
    help        显示此帮助信息

示例:
    $0 status           # 查看当前状态
    $0 fix              # 交互式修复
    $0 test             # 验证配置

警告:
    - 请确保在执行前已有普通用户账户
    - 禁用密码认证前必须配置SSH密钥
    - 建议在执行前保留当前SSH连接

EOF
}

# 主函数
main() {
    case "${1:-status}" in
        status)
            show_status
            ;;
        fix)
            check_root
            create_backup
            show_status
            
            echo ""
            echo "========================================"
            echo "       开始SSH安全加固"
            echo "========================================"
            echo ""
            
            fix_root_login
            fix_password_auth
            fix_protocol
            fix_port
            
            echo ""
            if test_config; then
                restart_ssh
                echo ""
                print_success "SSH安全加固完成！"
                show_status
            else
                print_error "配置验证失败，正在恢复..."
                restore_backup
            fi
            ;;
        auto)
            check_root
            create_backup
            fix_config "PermitRootLogin" "no" "禁用root用户直接登录"
            fix_config "Protocol" "2" "强制使用SSH协议版本2"
            test_config && restart_ssh
            print_success "基础加固完成（未禁用密码认证）"
            ;;
        restore)
            check_root
            restore_backup
            ;;
        test)
            test_config
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
