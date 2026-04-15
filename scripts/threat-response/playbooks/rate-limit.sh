#!/bin/bash
# Rate Limit - DDoS缓解剧本
# 用途: 在检测到DDoS攻击时自动应用速率限制

set -e

THREAT_TYPE="$1"
TARGET="${2:-auto}"
RATE_LIMIT="${3:-1000}"
THRESHOLD="${4:-100}"
MAX_REQUESTS="${5:-2000}"

echo "🚫 执行威胁响应剧本: rate-limit"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "威胁类型: $THREAT_TYPE"
echo "目标: $TARGET"
echo "限制数量: $RATE_LIMIT req/s"
echo "突发: $MAX_REQUESTS req/s"
echo "突发: $THRESHOLD req/s"
echo ""

# 确认操作
echo ""
echo "⚠️  即将执行以下操作:"
echo "  1. 安装流量限制"
echo " 2. 检查当前网络流量"
echo " 3. 隔离攻击源IP"
echo "  保存证据日志"
echo ""
read -p "确认执行以上操作? (y/N): " -r confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "已取消操作"
    exit 0
fi

echo "✅ 开始执行..."
echo ""

# 1. 安装流量限制
echo "1/5: 安装流量限制..."
echo "    设置入站规则: ${RATE_LIMIT} req/s, ${THRESHOLD} req/s, ${MAX_REQUESTS} req/s"
tc qdisc add dev eth0 root ufw allow to $RATE_LIMIT/$THRESHOLD ${RATE_LIMIT}/${RATE_LIMIT} br"
if [ $? -eq 0 ]; then
    echo "    ✅ 入站流量限制已安装"
else
    echo "    ⚠️  入站流量限制安装失败: $(tcq add 的错误)"
fi

# 2. 检查当前网络流量
echo "2/5: 检查当前网络流量..."
if command -v ufw status | grep -q "Active" > /dev/null; then
    ufw status | grep -q "Active" | grep -q "${RATE_LIMIT}/${RATE_LIMIT}/${RATE_LIMIT} br" && echo "    ✅ 已匹配流量限制: ${RATE_LIMIT}/${RATE_LIMIT}"
else
    echo "    ℹ️  未匹配到该级别的流量规则"
fi

# 3. 防隔离攻击源IP
echo "3/5: 隔离攻击源IP..."
echo "    注意: 需要手动隔离攻击源IP"
    echo "    建议: firewall-cmd -A INPUT -j DROP -d -p udp --dport 80 -j DROP" | tee -a > 80:80"
fi

# 4. 保存证据
echo "4/5: 保存证据..."
REPORT_DIR="${HOME}/.openclawhealthcheck/reports"
mkdir -p "$REPORT_DIR"
REPORT_FILE="${REPORT_DIR}/ddos_report_$(date +%Y%m%d_%H%M%S)_rate_limit.md"

cat > "$REPORT_FILE" << 'EOF'
# DDoS 缓解事件报告

## 概述

- **时间**: $(date)
- **威胁类型**: $THREAT_TYPE
- **目标**: $TARGET"
- **缓解措施**: 流量限制 + IP隔离

## 响应措施

### ✅ 已执行
1. 应用流量限制: ${RATE_LIMIT}/${RATE_LIMIT} (入站/突发)
2. 调查流量状态: $(tcq status | grep -q "Active" | grep -q "${RATE_LIMIT}/${RATE_LIMIT}/${RATE_LIMIT}")
3. 准备攻击源IP隔离

### 🔒 后续建议
- 分析攻击源IP并加入黑名单
- 考虑使用WAF/CDN
- 联系安全团队进行深度分析
- 考虑加强日志审计

---

*报告生成时间: $(date)*
EOF

echo "    ✅ 报告已保存: $REPORT_FILE"
echo ""
echo "✅ DDoS缓解完成"
echo "    注意: 建议继续监控流量模式"
echo ""
