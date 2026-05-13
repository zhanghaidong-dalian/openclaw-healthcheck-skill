#!/bin/bash
#
# HealthCheck CLI Tool 测试脚本
# 版本: v5.0.0
#

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$SCRIPT_DIR/healthcheck.py"

echo "========================================="
echo "  HealthCheck CLI Tool 测试套件"
echo "  版本: v5.0.0"
echo "========================================="
echo ""

# 测试计数器
PASSED=0
FAILED=0

# 测试函数
test_case() {
    local name="$1"
    local command="$2"

    echo "测试: $name"
    echo "命令: $command"
    echo ""

    if eval "$command" &> /dev/null; then
        echo "✓ 通过"
        ((PASSED++))
    else
        echo "✗ 失败"
        ((FAILED++))
    fi
    echo ""
}

# 测试1：版本检查
test_case "版本检查" "python3 $BINARY --version"

# 测试2：帮助信息
test_case "帮助信息" "python3 $BINARY --help"

# 测试3：快速模式
test_case "快速模式" "python3 $BINARY --mode quick"

# 测试4：标准模式
test_case "标准模式" "python3 $BINARY --mode standard"

# 测试5：排除检查项
test_case "排除检查项" "python3 $BINARY --exclude updates"

# 测试6：JSON格式输出
test_case "JSON格式输出" "python3 $BINARY --format json"

# 测试7：Markdown格式输出
test_case "Markdown格式输出" "python3 $BINARY --format markdown"

# 测试8：严重性过滤
test_case "严重性过滤" "python3 $BINARY --severity critical"

# 测试9：预设配置
test_case "预设配置" "python3 $BINARY --preset development"

# 测试10：scan-only模式
test_case "scan-only模式" "python3 $BINARY --mode scan-only"

# 测试结果
echo "========================================="
echo "  测试结果"
echo "========================================="
echo ""
echo "通过: $PASSED"
echo "失败: $FAILED"
echo "总计: $((PASSED + FAILED))"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✓ 所有测试通过！"
    exit 0
else
    echo "✗ 部分测试失败"
    exit 1
fi
