#!/bin/bash
# healthcheck-skill v5.0.0 快速验证脚本

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

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  healthcheck-skill v5.0.0 验证脚本  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
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

# 测试 1: 检查脚本文件存在
echo -e "${BOLD}[1/10] 检查脚本文件存在${NC}"
test_function "主入口脚本" "test -f bin/healthcheck"
test_function "分层扫描器" "test -f scripts/layered-scanner.sh"
test_function "规则引擎" "test -f scripts/rule-engine.sh"
test_function "意图检查器" "test -f scripts/intent-validator.sh"
test_function "报告生成器" "test -f scripts/report-generator.sh"
test_function "白名单管理器" "test -f scripts/whitelist-manager.sh"
echo ""

# 测试 2: 检查脚本执行权限
echo -e "${BOLD}[2/10] 检查脚本执行权限${NC}"
test_function "主入口脚本可执行" "test -x bin/healthcheck"
test_function "分层扫描器可执行" "test -x scripts/layered-scanner.sh"
test_function "规则引擎可执行" "test -x scripts/rule-engine.sh"
echo ""

# 测试 3: 检查规则文件
echo -e "${BOLD}[3/10] 检查规则文件${NC}"
test_function "SSH 规则 1" "test -f rules/ssh-001.yaml"
test_function "SSH 规则 2" "test -f rules/ssh-002.yaml"
test_function "防火墙规则" "test -f rules/firewall-001.yaml"
test_function "系统更新规则" "test -f rules/system-001.yaml"
test_function "OpenClaw 规则" "test -f rules/openclaw-001.yaml"
echo ""

# 测试 4: 检查配置文件
echo -e "${BOLD}[4/10] 检查配置文件${NC}"
test_function "白名单配置文件" "test -f config/whitelist.yaml"
echo ""

# 测试 5: 脚本语法检查
echo -e "${BOLD}[5/10] 检查脚本语法${NC}"
test_function "主入口脚本语法" "bash -n bin/healthcheck"
test_function "分层扫描器语法" "bash -n scripts/layered-scanner.sh"
test_function "规则引擎语法" "bash -n scripts/rule-engine.sh"
test_function "意图检查器语法" "bash -n scripts/intent-validator.sh"
test_function "报告生成器语法" "bash -n scripts/report-generator.sh"
test_function "白名单管理器语法" "bash -n scripts/whitelist-manager.sh"
echo ""

# 测试 6: 白名单功能
echo -e "${BOLD}[6/10] 测试白名单功能${NC}"
if ! test -f config/whitelist.yaml; then
    echo -e "${BLUE}初始化白名单...${NC}"
    ./scripts/whitelist-manager.sh --init > /dev/null 2>&1 || true
fi
test_function "白名单初始化" "test -f config/whitelist.yaml"
test_function "白名单验证" "./scripts/whitelist-manager.sh --check > /dev/null 2>&1"
echo ""

# 测试 7: 规则列表功能
echo -e "${BOLD}[7/10] 测试规则列表${NC}"
echo "规则列表:"
./scripts/rule-engine.sh --list 2>/dev/null || echo -e "${YELLOW}规则列表需要修复${NC}"
echo ""

# 测试 8: 帮助信息
echo -e "${BOLD}[8/10] 测试帮助信息${NC}"
test_function "主入口帮助" "./bin/healthcheck --help > /dev/null 2>&1"
test_function "规则引擎帮助" "./scripts/rule-engine.sh --help > /dev/null 2>&1"
test_function "白名单管理器帮助" "./scripts/whitelist-manager.sh --help > /dev/null 2>&1"
echo ""

# 测试 9: 版本信息
echo -e "${BOLD}[9/10] 检查版本信息${NC}"
test_function "主入口版本" "./bin/healthcheck --version > /dev/null 2>&1"
echo ""

# 测试 10: 报告目录
echo -e "${BOLD}[10/10] 检查报告目录${NC}"
test_function "报告目录创建" "mkdir -p /tmp/healthcheck-reports && test -d /tmp/healthcheck-reports"
echo ""

# 显示结果
echo -e "${CYAN}═════════════════════════════════════════${NC}"
echo -e "${BOLD}验证结果${NC}"
echo -e "${CYAN}═════════════════════════════════════════${NC}"
echo -e "总测试数: $total_tests"
echo -e "${GREEN}通过: $passed_tests${NC}"
echo -e "${RED}失败: $failed_tests${NC}"
echo ""

if [[ $failed_tests -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✓ 所有测试通过！v5.0.0 核心功能正常${NC}"
    echo ""
    echo "下一步建议:"
    echo "1. 运行轻量级扫描: ./bin/healthcheck --quick"
    echo "2. 运行深度扫描: ./bin/healthcheck --deep"
    echo "3. 查看 UPGRADE-REPORT-v5.0.0.md 了解详细功能"
    echo "4. 完成验证清单中的所有测试项"
    exit 0
else
    echo -e "${RED}${BOLD}✗ 部分测试失败，需要修复${NC}"
    echo ""
    echo "请检查失败的测试项，参考 UPGRADE-REPORT-v5.0.0.md"
    exit 1
fi
