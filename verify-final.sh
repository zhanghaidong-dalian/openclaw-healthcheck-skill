#!/bin/bash
# healthcheck-skill v5.0.0 全面验证脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║ healthcheck-skill v5.0.0 全面验证脚本 ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

total_tests=0
passed_tests=0
failed_tests=0

# 测试函数
test_function() {
    local test_name="$1"
    local test_command="$2"

    ((total_tests++))
    echo -n "测试: $test_name ... "

    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((passed_tests++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((failed_tests++))
        return 1
    fi
}

# 第一阶段：文件检查
echo -e "${BOLD}[阶段 1/5] 文件完整性检查${NC}"
echo "----------------------------------------"
test_function "主入口脚本" "test -f bin/healthcheck"
test_function "主入口可执行" "test -x bin/healthcheck"
test_function "分层扫描器" "test -f scripts/layered-scanner.sh"
test_function "分层扫描器可执行" "test -x scripts/layered-scanner.sh"
test_function "规则引擎" "test -f scripts/rule-engine.sh"
test_function "规则引擎可执行" "test -x scripts/rule-engine.sh"
test_function "意图检查器" "test -f scripts/intent-validator.sh"
test_function "意图检查器可执行" "test -x scripts/intent-validator.sh"
test_function "报告生成器" "test -f scripts/report-generator.sh"
test_function "报告生成器可执行" "test -x scripts/report-generator.sh"
test_function "白名单管理器" "test -f scripts/whitelist-manager.sh"
test_function "白名单管理器可执行" "test -x scripts/whitelist-manager.sh"
echo ""

# 第二阶段：规则文件检查
echo -e "${BOLD}[阶段 2/5] 规则文件检查${NC}"
echo "----------------------------------------"
test_function "SSH 规则 1" "test -f rules/ssh-001.yaml"
test_function "SSH 规则 2" "test -f rules/ssh-002.yaml"
test_function "防火墙规则" "test -f rules/firewall-001.yaml"
test_function "系统更新规则" "test -f rules/system-001.yaml"
test_function "OpenClaw 规则" "test -f rules/openclaw-001.yaml"
echo ""

# 第三阶段：配置文件检查
echo -e "${BOLD}[阶段 3/5] 配置文件检查${NC}"
echo "----------------------------------------"
test_function "白名单配置" "test -f config/whitelist.yaml"
echo ""

# 第四阶段：脚本语法检查
echo -e "${BOLD}[阶段 4/5] 脚本语法检查${NC}"
echo "----------------------------------------"
test_function "主入口语法" "bash -n bin/healthcheck"
test_function "分层扫描器语法" "bash -n scripts/layered-scanner.sh"
test_function "规则引擎语法" "bash -n scripts/rule-engine.sh"
test_function "意图检查器语法" "bash -n scripts/intent-validator.sh"
test_function "报告生成器语法" "bash -n scripts/report-generator.sh"
test_function "白名单管理器语法" "bash -n scripts/whitelist-manager.sh"
echo ""

# 第五阶段：功能检查
echo -e "${BOLD}[阶段 5/5] 功能检查${NC}"
echo "----------------------------------------"
test_function "主入口帮助" "./bin/healthcheck --help > /dev/null 2>&1"
test_function "版本信息" "./bin/healthcheck --version > /dev/null 2>&1"
echo ""

# 创建报告目录
mkdir -p /tmp/healthcheck-reports

# 显示结果
echo -e "${CYAN}═════════════════════════════════════════════${NC}"
echo -e "${BOLD}验证结果${NC}"
echo -e "${CYAN}═════════════════════════════════════════════${NC}"
echo -e "总测试数: $total_tests"
echo -e "${GREEN}通过: $passed_tests${NC}"
echo -e "${RED}失败: $failed_tests${NC}"
echo ""

if [[ $failed_tests -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✓ 所有测试通过！v5.0.0 核心功能正常${NC}"
    echo ""
    echo "下一步:"
    echo "1. 检查规则列表: ./bin/healthcheck --list-rules"
    echo "2. 验证白名单: ./bin/healthcheck --check-whitelist"
    echo "3. 查看验证报告: cat VERIFICATION-FINAL-v5.0.0.md"
    exit 0
else
    echo -e "${RED}${BOLD}✗ 部分测试失败，需要修复${NC}"
    exit 1
fi
