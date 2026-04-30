# 💡 使用示例大全 - OpenClaw 主机安全加固工具

**版本**: v4.8.x
**更新时间**: 2026-04-28

---

## 目录

1. [基础示例](#基础示例)
2. [场景示例](#场景示例)
3. [高级示例](#高级示例)
4. [实战案例](#实战案例)

---

## 基础示例

### 1. 快速扫描

```bash
# 最简单的使用方式
./bin/healthcheck --quick
```

**适用场景**：日常快速检查，30 秒内完成

---

### 2. 深度扫描

```bash
# 全面深度扫描
./bin/healthcheck --deep
```

**适用场景**：上线前检查、安全审计

---

### 3. 智能扫描

```bash
# AI 辅助智能分析
./bin/healthcheck --intelligent
```

**适用场景**：高安全要求场景

---

### 4. 自动模式

```bash
# 根据环境自动选择
./bin/healthcheck --auto
```

**适用场景**：不确定使用哪种模式时

---

### 5. 检查指定项

```bash
# 只检查防火墙
./bin/healthcheck --check firewall

# 只检查 SSH
./bin/healthcheck --check ssh

# 检查多个项
./bin/healthcheck --check ssh,firewall,updates
```

---

### 6. 列出所有规则

```bash
./bin/healthcheck --list-rules
```

---

### 7. 列出可修复项

```bash
./bin/healthcheck --list-fixes
```

---

## 场景示例

### 场景 1: VPS 每日巡检

```bash
#!/bin/bash
# vps-daily-check.sh - VPS 每日巡检

echo "🔍 VPS 每日安全巡检"
echo "时间: $(date)"
echo ""

# 执行轻量级扫描
./bin/healthcheck --quick --output json /tmp/vps-report-$(date +%Y%m%d).json

# 检查关键项
echo ""
echo "📊 关键安全指标:"
./bin/healthcheck --check firewall
./bin/healthcheck --check ssh
./bin/healthcheck --check updates

echo ""
echo "✅ 巡检完成，报告已保存到 /tmp/"
```

---

### 场景 2: Docker 容器安全

```bash
#!/bin/bash
# docker-security.sh - Docker 容器安全检查

echo "🐳 Docker 容器安全检查..."
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装"
    exit 1
fi

# 检查运行中的容器
echo "📦 运行中的容器:"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"

# 检查特权容器
echo ""
echo "🔒 特权容器检查:"
docker ps --format "{{.Names}}: {{.Ports}}" | grep -v "^$"

# 执行系统安全扫描
echo ""
echo "🔍 执行系统安全扫描..."
./bin/healthcheck --quick

echo ""
echo "✅ Docker 安全检查完成"
```

---

### 场景 3: 树莓派安全加固

```bash
#!/bin/bash
# raspberry-pi.sh - 树莓派安全加固

echo "🍓 树莓派安全加固"
echo ""

# 检查系统
echo "📊 系统信息:"
cat /etc/os-release | grep "PRETTY_NAME"

# SSH 安全检查
echo ""
echo "🔐 SSH 安全检查:"
./bin/healthcheck --check ssh

# 更新系统
echo ""
echo "📦 检查系统更新..."
./bin/healthcheck --check updates

# 建议操作
echo ""
echo "💡 建议操作:"
echo "1. 更改默认 pi 用户密码"
echo "2. 启用防火墙"
echo "3. 配置 SSH 密钥认证"
echo "4. 定期更新系统"

echo ""
echo "✅ 树莓派安全检查完成"
```

---

### 场景 4: 工作站日常检查

```bash
#!/bin/bash
# workstation-daily.sh - 工作站日常检查

echo "🖥️ 工作站日常安全检查"
echo "时间: $(date)"
echo ""

# 轻量级扫描
./bin/healthcheck --quick --summary

# 检查关键项
echo ""
echo "📊 关键检查:"
./bin/healthcheck --check firewall
./bin/healthcheck --check ssh
./bin/healthcheck --check system-updates

echo ""
echo "✅ 工作站检查完成"
```

---

## 高级示例

### 1. 定时任务配置

```bash
# 每天凌晨 2 点执行扫描
./bin/healthcheck --cron "0 2 * * *"

# 每周一上午 9 点深度扫描
./bin/healthcheck --cron "0 9 * * 1" --deep

# 查看定时任务
./bin/healthcheck --cron-list
```

---

### 2. CI/CD 集成

#### GitHub Actions

```yaml
# .github/workflows/security-scan.yml
name: Security Scan

on:
  push:
    branches: [main]
  schedule:
    - cron: '0 2 * * *'  # 每天凌晨2点

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Security Scan
        run: |
          chmod +x bin/healthcheck
          ./bin/healthcheck --quick --output json report.json
      
      - name: Upload Report
        uses: actions/upload-artifact@v3
        with:
          name: security-report
          path: report.json
```

#### GitLab CI

```yaml
# .gitlab-ci.yml
security_scan:
  script:
    - chmod +x bin/healthcheck
    - ./bin/healthcheck --quick --output json report.json
  artifacts:
    paths:
      - report.json
  only:
    - main
```

---

### 3. Webhook 通知

```bash
# 扫描完成后发送通知
./bin/healthcheck --quick --webhook https://hooks.example.com/notify

# 发送扫描报告
./bin/healthcheck --deep --output json - | curl -X POST -d @- https://hooks.example.com/notify
```

---

### 4. 批量扫描

```bash
#!/bin/bash
# batch-scan.sh - 批量扫描多台主机

HOSTS=(
  "user@server1.example.com"
  "user@server2.example.com"
  "user@server3.example.com"
)

REPORT_DIR="/tmp/security-reports"
mkdir -p "$REPORT_DIR"

for host in "${HOSTS[@]}"; do
  echo "🔍 扫描 $host..."
  HOSTNAME=$(echo $host | cut -d@ -f2)
  ssh "$host" "bash -s" < bin/healthcheck --quick --output json /tmp/report.json
  scp "$host:/tmp/report.json" "$REPORT_DIR/${HOSTNAME}.json"
  echo "✅ $host 扫描完成"
done

echo ""
echo "📊 所有主机扫描完成"
echo "报告保存在: $REPORT_DIR"
```

---

### 5. 自动化修复

```bash
# 查看可修复项
./bin/healthcheck --list-fixes

# 交互式修复（推荐）
./bin/healthcheck --fix

# 自动修复所有项
./bin/healthcheck --auto-fix

# 只修复高风险项
./bin/healthcheck --fix --severity high
```

---

### 6. 输出格式切换

```bash
# JSON 格式（程序处理）
./bin/healthcheck --quick --output json /tmp/report.json

# Markdown 格式（文档存档）
./bin/healthcheck --deep --output markdown /tmp/report.md

# 摘要模式（快速查看）
./bin/healthcheck --summary

# 增量检查（只报告新问题）
./bin/healthcheck --incremental --notify new-only
```

---

## 实战案例

### 案例 1: CVE 漏洞检测

```bash
#!/bin/bash
# cve-detection.sh - CVE 漏洞检测

echo "🔍 CVE 漏洞检测"
echo "时间: $(date)"
echo ""

# 执行深度扫描
./bin/healthcheck --deep --output json /tmp/cve-report.json

# 检查 CVE 相关结果
echo "📊 CVE 检测结果:"
cat /tmp/cve-report.json | grep -A5 "cve"

# 如果有 CVE 漏洞，发送告警
if grep -q "CVE" /tmp/cve-report.json; then
  echo "⚠️ 检测到 CVE 漏洞！"
  # 发送告警（需要配置）
  # curl -X POST https://hooks.example.com/alert -d "检测到CVE漏洞"
else
  echo "✅ 未检测到 CVE 漏洞"
fi
```

---

### 案例 2: 修复前后对比

```bash
#!/bin/bash
# before-after-fix.sh - 修复前后对比

echo "🔄 安全加固 - 修复前后对比"
echo "时间: $(date)"
echo ""

# 修复前扫描
echo "📸 修复前状态:"
./bin/healthcheck --quick --summary > /tmp/before-fix.txt
cat /tmp/before-fix.txt

echo ""
echo "🔧 执行修复..."
./bin/healthcheck --auto-fix

echo ""
echo "📸 修复后状态:"
sleep 5
./bin/healthcheck --quick --summary > /tmp/after-fix.txt
cat /tmp/after-fix.txt

echo ""
echo "📊 修复前后对比:"
diff /tmp/before-fix.txt /tmp/after-fix.txt || true

echo ""
echo "✅ 修复对比完成"
```

---

### 案例 3: 合规报告生成

```bash
#!/bin/bash
# compliance-report.sh - 合规报告生成

echo "📝 合规报告生成"
echo "时间: $(date)"
echo ""

REPORT_FILE="/tmp/compliance-report-$(date +%Y%m%d).md"

cat > "$REPORT_FILE" << 'EOF'
# 安全合规报告

## 基本信息

- 报告时间: TIME
- 扫描模式: 深度扫描
- 系统版本: VERSION

## 合规检查项

EOF

# 执行扫描
./bin/healthcheck --deep --output json /tmp/scan-result.json

# 生成合规摘要
echo "## 检查结果摘要" >> "$REPORT_FILE"
./bin/healthcheck --summary >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo "## 详细结果" >> "$REPORT_FILE"
cat /tmp/scan-result.json >> "$REPORT_FILE"

echo ""
echo "✅ 合规报告已生成: $REPORT_FILE"
```

---

## 相关文档

- 🚀 [快速开始](QUICK-START.md)
- 📖 [完整使用手册](USAGE.md)
- 🔧 [故障排查指南](TROUBLESHOOTING.md)
- 🛠️ [场景脚本目录](../examples/)
- 📋 [实战案例目录](../cases/)

---

**最后更新**: 2026-04-28
**版本**: v4.8.x
