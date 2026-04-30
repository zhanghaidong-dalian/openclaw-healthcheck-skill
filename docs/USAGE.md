# 📖 完整使用手册 - OpenClaw 主机安全加固工具

**版本**: v4.8.x
**更新时间**: 2026-04-28

---

## 目录

1. [概述](#概述)
2. [安装指南](#安装指南)
3. [命令行参数](#命令行参数)
4. [配置文件](#配置文件)
5. [输出报告](#输出报告)
6. [规则系统](#规则系统)
7. [白名单管理](#白名单管理)
8. [定时任务](#定时任务)
9. [高级用法](#高级用法)

---

## 概述

### 什么是 OpenClaw 主机安全加固工具？

OpenClaw 主机安全加固工具是一款全面的系统安全审计和加固工具，支持：

- ✅ CVE 漏洞检查
- ✅ 恶意技能扫描
- ✅ 提示词注入防护
- ✅ 分层扫描策略
- ✅ 白名单机制
- ✅ 自动化修复

### 核心特性

| 特性 | 说明 |
|------|------|
| 分层扫描 | 轻量（30秒）/ 深度（5分钟）/ 智能（10分钟） |
| 规则体系 | 18+ YAML 规则，覆盖 6 大安全领域 |
| 白名单 | 支持域名、路径、服务白名单 |
| 输出格式 | JSON / Markdown / 控制台 |
| 自动化 | 自动修复、定时巡检、增量检查 |

---

## 安装指南

### 系统要求

| 要求 | 最低版本 |
|------|----------|
| 操作系统 | Linux (Ubuntu 18.04+, Debian 10+, CentOS 7+) |
| 架构 | x86_64 / ARM64 |
| 内存 | 512MB+ |
| 磁盘 | 100MB+ |

### 安装步骤

```bash
# 1. 下载最新版本
git clone https://github.com/zhanghaidong-dalian/openclaw-healthcheck-skill.git
cd openclaw-healthcheck-skill

# 2. 赋予执行权限
chmod +x bin/healthcheck
chmod +x scripts/*.sh

# 3. 验证安装
./bin/healthcheck --version

# 4. 首次扫描
./bin/healthcheck --quick
```

### Docker 环境

```bash
# 在 Docker 容器中运行
docker run -it --rm \
  --privileged \
  -v $(pwd):/workspace \
  ubuntu:latest \
  bash -c "apt-get update && apt-get install -y sudo curl git && cd /workspace && bash bin/healthcheck --quick"
```

---

## 命令行参数

### 扫描模式

| 参数 | 说明 | 扫描项 | 耗时 |
|------|------|--------|------|
| `--quick` | 轻量级扫描 | 6 项高风险 | < 30 秒 |
| `--deep` | 深度扫描 | 18 项全部 | 3-5 分钟 |
| `--intelligent` | 智能扫描 | 深度 + AI 分析 | 5-10 分钟 |
| `--auto` | 自动选择 | 根据环境自动 | 自动 |

### 修复功能

| 参数 | 说明 |
|------|------|
| `--fix` | 交互式修复（推荐） |
| `--auto-fix` | 自动修复（无需确认） |
| `--list-fixes` | 列出所有可修复项 |
| `--check <item>` | 检查指定项 |

### 输出控制

| 参数 | 说明 | 示例 |
|------|------|------|
| `--output <format> <file>` | 输出到文件 | `--output json report.json` |
| `--summary` | 摘要报告模式 | `--summary` |
| `--incremental` | 增量检查 | `--incremental` |

### 定时任务

| 参数 | 说明 | 示例 |
|------|------|------|
| `--cron <schedule>` | 配置定时任务 | `--cron "0 2 * * *"` |
| `--cron-list` | 列出定时任务 | - |
| `--cron-remove` | 移除定时任务 | - |

### 其他参数

| 参数 | 说明 |
|------|------|
| `--version` | 显示版本信息 |
| `--list-rules` | 列出所有规则 |
| `--whitelist` | 白名单管理 |
| `--help` | 显示帮助信息 |
| `--verbose` | 详细输出模式 |

---

## 配置文件

### 白名单配置

位置: `config/whitelist.yaml`

```yaml
# 白名单配置
whitelist:
  # 信任的域名
  domains:
    - github.com
    - ubuntu.com
    - debian.org
  
  # 信任的路径
  paths:
    - /etc/ssh/sshd_config
    - /var/log/auth.log
  
  # 信任的服务
  services:
    - sshd
    - ufw
    - fail2ban
```

### 自定义规则

位置: `rules/*.yaml`

```yaml
# 示例：自定义 SSH 规则
---
id: custom-ssh-001
name: SSH 自定义检查
category: ssh_security
severity: high
description: 自定义 SSH 安全检查

check:
  type: command
  command: grep "Port 22" /etc/ssh/sshd_config

expected: "Port 22"

remediation:
  script: fix-ssh.sh
  command: "sed -i 's/Port 22/Port 2222/' /etc/ssh/sshd_config"
  restart_required: true
  service: sshd
```

---

## 输出报告

### JSON 格式

```json
{
  "version": "4.8.2",
  "timestamp": "2026-04-28T12:00:00+08:00",
  "scan_mode": "quick",
  "summary": {
    "total": 6,
    "passed": 4,
    "warning": 1,
    "failed": 1
  },
  "results": [
    {
      "id": "ssh-001",
      "name": "SSH 密码认证",
      "status": "passed",
      "severity": "high"
    }
  ]
}
```

### Markdown 格式

```markdown
# 安全扫描报告

**版本**: v4.8.2  
**时间**: 2026-04-28 12:00  
**模式**: 轻量级扫描

## 摘要

| 状态 | 数量 |
|------|------|
| 🟢 通过 | 4 |
| 🟡 警告 | 1 |
| 🔴 失败 | 1 |

## 检查项详情

### 🟢 SSH 密码认证
- **状态**: 已禁用
- **风险**: 低

### 🔴 防火墙状态
- **状态**: 未启用
- **风险**: 高
- **建议**: 启用防火墙
```

---

## 规则系统

### 规则分类

| 风险级别 | 数量 | 说明 |
|----------|------|------|
| 高风险 | 6 | SSH、防火墙、系统更新等 |
| 中风险 | 8 | 端口规则、日志、fail2ban 等 |
| 低风险 | 4 | 内核安全、密码策略等 |

### 规则文件

```
rules/
├── ssh-001.yaml          # SSH 密码认证禁用
├── ssh-002.yaml          # SSH 禁止 root 登录
├── ssh-003.yaml          # SSH 配置文件权限
├── firewall-001.yaml     # 防火墙启用状态
├── firewall-002.yaml     # 防火墙端口规则
├── system-001.yaml       # 系统更新状态
├── system-002.yaml       # 自动更新配置
├── logging-001.yaml      # 日志文件权限
├── openclaw-001.yaml     # OpenClaw 文件权限
├── openclaw-002.yaml     # OpenClaw 配置权限
├── fail2ban-001.yaml     # fail2ban 安装状态
├── fail2ban-002.yaml     # fail2ban 运行状态
├── fail2ban-003.yaml     # fail2ban 规则配置
├── disk-001.yaml         # 磁盘加密状态
├── kernel-001.yaml       # 内核安全参数
├── password-001.yaml     # 用户密码策略
├── intrusion-001.yaml    # 入侵检测
├── network-001.yaml      # 开放端口审计
└── system-monitor-001.yaml # 系统资源监控
```

---

## 白名单管理

### 查看白名单

```bash
./bin/healthcheck --whitelist --list
```

### 添加白名单

```bash
# 添加域名
./bin/healthcheck --whitelist --add-domain example.com

# 添加路径
./bin/healthcheck --whitelist --add-path /etc/custom/config

# 添加服务
./bin/healthcheck --whitelist --add-service myservice
```

### 移除白名单

```bash
# 移除域名
./bin/healthcheck --whitelist --remove-domain example.com

# 移除路径
./bin/healthcheck --whitelist --remove-path /etc/custom/config

# 移除服务
./bin/healthcheck --whitelist --remove-service myservice
```

---

## 定时任务

### 配置定时任务

```bash
# 每天凌晨 2 点执行轻量级扫描
./bin/healthcheck --cron "0 2 * * *" --quick

# 每周一执行深度扫描
./bin/healthcheck --cron "0 9 * * 1" --deep

# 每天执行并发送报告
./bin/healthcheck --cron "0 2 * * *" --quick --output json /var/log/healthcheck/report.json
```

### 查看定时任务

```bash
./bin/healthcheck --cron-list
```

### 移除定时任务

```bash
./bin/healthcheck --cron-remove
```

---

## 高级用法

### CI/CD 集成

```yaml
# .github/workflows/security-scan.yml
name: Security Scan

on:
  push:
    branches: [main]

jobs:
  security:
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

### 批量扫描多台主机

```bash
#!/bin/bash
# batch-scan.sh - 批量扫描多台主机

HOSTS=("server1.example.com" "server2.example.com" "server3.example.com")

for host in "${HOSTS[@]}"; do
  echo "🔍 扫描 $host..."
  ssh user@$host "bash -s" < bin/healthcheck --quick --output json /tmp/report-$host.json
  echo "✅ $host 扫描完成"
done

echo "📊 所有主机扫描完成"
```

### Webhook 通知

```bash
# 扫描完成后发送通知
./bin/healthcheck --quick --webhook https://hooks.example.com/notify
```

---

## 相关文档

- 🚀 [快速开始](QUICK-START.md)
- 🔧 [故障排查指南](TROUBLESHOOTING.md)
- 💡 [使用示例大全](EXAMPLES.md)
- 📝 [CHANGELOG](../../CHANGELOG.md)

---

**最后更新**: 2026-04-28
**版本**: v4.8.x
