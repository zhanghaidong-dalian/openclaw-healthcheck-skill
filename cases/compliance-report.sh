#!/bin/bash
# compliance-report.sh - 合规报告生成脚本
# 适用场景: 生成安全合规报告
# 使用方法: ./compliance-report.sh [output-file]

set -e

# 配置
OUTPUT_FILE="${1:-/tmp/compliance-report-$(date +%Y%m%d).md}"
SCAN_RESULT_FILE="/tmp/scan-result-$$.json"

echo "================================================"
echo "📝 安全合规报告生成"
echo "================================================"
echo ""
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "输出: $OUTPUT_FILE"
echo ""

# 执行深度扫描
echo "📊 执行深度安全扫描..."
echo ""

if ./bin/healthcheck --deep --output json "$SCAN_RESULT_FILE"; then
    echo "✅ 扫描完成"
else
    echo "⚠️ 扫描遇到问题"
fi

echo ""
echo "📝 生成合规报告..."

# 生成报告
{
    cat << EOF
# 安全合规报告

**生成时间**: $(date '+%Y-%m-%d %H:%M:%S')
**扫描模式**: 深度扫描
**系统版本**: $(uname -r)
**主机名**: $(hostname)

---

## 1. 执行摘要

本报告基于 OpenClaw 主机安全加固工具的深度扫描结果编写，
旨在帮助您了解当前系统的安全状况并采取相应的加固措施。

EOF

    # 扫描统计
    if [ -f "$SCAN_RESULT_FILE" ]; then
        TOTAL=$(grep -o '"total":[0-9]*' "$SCAN_RESULT_FILE" | cut -d: -f2 || echo "N/A")
        PASSED=$(grep -o '"passed":[0-9]*' "$SCAN_RESULT_FILE" | cut -d: -f2 || echo "N/A")
        WARNING=$(grep -o '"warning":[0-9]*' "$SCAN_RESULT_FILE" | cut -d: -f2 || echo "N/A")
        FAILED=$(grep -o '"failed":[0-9]*' "$SCAN_RESULT_FILE" | cut -d: -f2 || echo "N/A")

        cat << EOF
### 1.1 扫描统计

| 指标 | 数量 |
|------|------|
| 总检查项 | $TOTAL |
| 通过 | $PASSED |
| 警告 | $WARNING |
| 失败 | $FAILED |

### 1.2 合规状态

EOF

        if [ "$FAILED" -eq "0" ]; then
            echo "| 状态 | ✅ 合规 |"
            echo "||"
            echo "| 说明 | 所有检查项通过 |"
        elif [ "$FAILED" -lt "3" ]; then
            echo "| 状态 | ⚠️ 基本合规 |"
            echo "||"
            echo "| 说明 | 存在少量不符合项，建议修复 |"
        else
            echo "| 状态 | ❌ 不合规 |"
            echo "||"
            echo "| 说明 | 存在多项不符合项，需要立即修复 |"
        fi
    fi

    cat << 'EOF'

---

## 2. 检查项详情

### 2.1 高风险项

| 检查项 | 状态 | 说明 | 建议 |
|--------|------|------|------|
EOF

    # 提取高风险项
    if [ -f "$SCAN_RESULT_FILE" ]; then
        grep -A10 "HIGH\|high" "$SCAN_RESULT_FILE" 2>/dev/null | head -30 || echo "无高风险项"
    fi

    cat << 'EOF'

### 2.2 中风险项

| 检查项 | 状态 | 说明 | 建议 |
|--------|------|------|------|
EOF

    # 提取中风险项
    if [ -f "$SCAN_RESULT_FILE" ]; then
        grep -A10 "MEDIUM\|medium" "$SCAN_RESULT_FILE" 2>/dev/null | head -30 || echo "无中风险项"
    fi

    cat << 'EOF'

---

## 3. 加固建议

### 3.1 紧急修复（高风险）

1. **SSH 安全配置**
   - 禁用 root 登录
   - 禁用密码认证，使用密钥
   - 更改默认端口

2. **防火墙配置**
   - 启用防火墙
   - 限制 SSH 访问
   - 关闭不必要的端口

3. **系统更新**
   - 安装所有安全更新
   - 配置自动更新

### 3.2 建议措施（中风险）

1. **日志配置**
   - 配置日志轮转
   - 保护敏感日志

2. **入侵检测**
   - 安装并配置 fail2ban
   - 配置审计规则

3. **备份策略**
   - 定期备份重要数据
   - 测试恢复流程

---

## 4. 合规标准参考

本检查依据以下安全标准：

- **CIS Benchmark**: Center for Internet Security Benchmarks
- **NIST**: National Institute of Standards and Technology
- **ISO 27001**: Information Security Management

---

## 5. 下一步行动

1. **立即行动**（24小时内）
   - 修复高风险项
   - 启用防火墙
   - 安装安全更新

2. **短期行动**（1周内）
   - 配置 fail2ban
   - 优化日志配置
   - 完成所有中风险项修复

3. **长期行动**（1月内）
   - 建立定期扫描机制
   - 完善应急响应流程
   - 进行安全培训

---

## 6. 附录

### 6.1 扫描命令

\`\`\`bash
./bin/healthcheck --deep --output json $SCAN_RESULT_FILE
\`\`\`

### 6.2 修复命令

\`\`\`bash
# 查看可修复项
./bin/healthcheck --list-fixes

# 执行修复
./bin/healthcheck --fix
\`\`\`

### 6.3 联系方式

- 文档: [USAGE.md](../docs/USAGE.md)
- 问题反馈: [GitHub Issues](https://github.com/zhanghaidong-dalian/openclaw-healthcheck-skill/issues)

---

**报告生成工具**: OpenClaw 主机安全加固工具 v4.8.x
**生成时间**: $(date '+%Y-%m-%d %H:%M:%S')
EOF

} > "$OUTPUT_FILE"

# 清理临时文件
rm -f "$SCAN_RESULT_FILE"

echo ""
echo "================================================"
echo "✅ 合规报告生成完成"
echo "================================================"
echo ""
echo "📄 报告位置: $OUTPUT_FILE"
echo ""
echo "💡 查看报告:"
echo "  cat $OUTPUT_FILE"
echo ""
echo "💡 导出为 PDF（需要 pandoc）:"
echo "  pandoc $OUTPUT_FILE -o report.pdf"
echo ""
