---
name: healthcheck
description: OpenClaw 主机安全加固工具。支持CVE漏洞检查、恶意技能扫描、提示词注入防护、MCP权限审计。适用于VPS/云服务器、本地工作站、Docker容器等场景。触发词：安全检查、security audit、安全审计、加固、hardening。
version: 4.8.8
updated: 2026-05-13
---

# OpenClaw 主机安全加固工具 v5.2.0

## 🚀 快速开始

### 一键安全检查
```bash
# 快速扫描（无需 root）
./scripts/quick-check.sh

# 深度扫描（需要 root）
sudo ./scripts/quick-check.sh --deep
```

### 批量检查多台主机
```bash
# 创建主机列表文件
cat > hosts.txt << EOF
192.168.1.100 user1
192.168.1.101 user2
server.example.com admin
EOF

# 批量检查
./scripts/batch-check.sh --hosts-file hosts.txt --parallel 5
```

### 自动修复
```bash
# 一键自动修复（安全级别）
./scripts/auto-fixer.sh --level auto-safe

# SSH 自动加固
sudo ./scripts/fix-ssh-auto.sh
```

---

## 📋 功能清单

### ✅ 核心功能
| 功能 | 命令 | 说明 |
|------|------|------|
| 快速扫描 | `./scripts/quick-check.sh` | 无需 root，快速安全检查 |
| 深度扫描 | `./scripts/quick-check.sh --deep` | 完整安全审计 |
| 批量检查 | `./scripts/batch-check.sh` | 多主机并行扫描 |
| 自动修复 | `./scripts/auto-fixer.sh` | 自动修复安全问题 |
| SSH加固 | `./scripts/fix-ssh-auto.sh` | 一键加固 SSH 配置 |

### ✅ 检查项
1. **CVE漏洞检查** - 集成 2026 年 5 月最新威胁情报
2. **SSH安全** - 检测弱配置、暴力破解风险
3. **防火墙审计** - 检查端口暴露、规则配置
4. **文件权限** - OpenClaw 文件、日志权限
5. **敏感数据** - 检测密钥、密码泄露
6. **MCP工具权限** - 审计工具权限配置
7. **恶意技能扫描** - 检测风险技能
8. **提示词注入防护** - 防护 AI 特有攻击
9. **CIS合规检测** - 对标国际安全标准

### ✅ 四级修复分类
| 级别 | 说明 | 自动执行 |
|------|------|----------|
| `auto-safe` | 安全无害，自动修复 | ✅ 是 |
| `auto-risk` | 有风险，需确认 | ⚠️ 询问 |
| `manual-guide` | 需手动操作 | 📋 提供指南 |
| `manual-expert` | 专家级问题 | 🔴 仅提示 |

---

## 🌐 Web 管理界面

启动 Web Dashboard：
```bash
cd dashboard
python3 app.py
# 访问 http://localhost:8080
```

功能：
- 📊 安全状态仪表盘
- 🔍 一键扫描按钮
- 🛠️ 自动修复按钮
- 📈 历史趋势图表

---

## 📖 使用场景

### 场景1：VPS/云服务器
```bash
# 1. SSH 加固
sudo ./scripts/fix-ssh-auto.sh

# 2. 防火墙配置
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw enable

# 3. 安装 fail2ban
sudo apt install fail2ban
sudo systemctl enable fail2ban

# 4. 完整扫描
sudo ./scripts/quick-check.sh --deep
```

### 场景2：本地工作站
```bash
# 快速检查（无需 root）
./scripts/quick-check.sh

# 查看报告
cat reports/latest.md
```

### 场景3：批量运维
```bash
# 检查 50 台服务器
./scripts/batch-check.sh --hosts-file servers.txt --parallel 10 --output batch-report.md
```

---

## 🤖 Agent 模式（Coze/Dify/混元）

在 Agent 平台使用时，自动启用 Agent 模式：

```python
from agent.scanner import SecurityScanner
from agent.auto_fixer import AutoFixer

# 扫描
scanner = SecurityScanner()
result = scanner.scan()

# 自动修复
fixer = AutoFixer()
fixer.fix(result.issues, level='auto-safe')
```

---

## ❓ 常见问题

### Q1: 需要 root 权限吗？
**A**: 快速扫描无需 root，深度扫描和修复需要 sudo。

### Q2: 支持哪些操作系统？
**A**: 
- ✅ Ubuntu/Debian (100%)
- ✅ CentOS/RHEL (90%)
- ✅ macOS (80%)
- ⚠️ Windows (需 PowerShell，50%)

### Q3: 如何回滚修复？
**A**: 所有修复前自动备份到 `/var/backup/healthcheck/`：
```bash
# 回滚 SSH 配置
sudo cp /var/backup/healthcheck/sshd_config.* /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### Q4: 批量检查如何并行？
**A**: 使用 `--parallel` 参数控制并发数，默认 5：
```bash
./scripts/batch-check.sh --hosts-file hosts.txt --parallel 10
```

### Q5: Web Dashboard 如何部署？
**A**: 
```bash
cd dashboard
pip3 install -r requirements.txt
python3 app.py --host 0.0.0.0 --port 8080
```

---

## 🔧 高级配置

### 自定义检查规则
编辑 `config/rules.yaml`：
```yaml
ssh:
  permit_root_login: false
  password_auth: false
  port: 22
  
firewall:
  allowed_ports: [22, 80, 443]
  
updates:
  auto_update: true
```

### 定时任务
```bash
# 每日 3:00 自动检查
crontab -e
0 3 * * * /path/to/scripts/quick-check.sh --notify
```

---

## 📦 扩展包

### CVE 漏洞库
```bash
# 安装扩展
cd extensions/cve-db
./install.sh

# 更新漏洞库
./update-cve-db.sh
```

### 高级修复
```bash
# 安装高级修复扩展
cd extensions/advanced-fix
./install.sh
```

---

## 📊 版本历史

| 版本 | 日期 | 更新内容 |
|------|------|----------|
| 5.2.0 | 2026-05-13 | 批量检查、Web UI、Agent自动修复、SSH一键加固 |
| 5.1.0 | 2026-05-01 | 一键自动修复、CIS合规检测 |
| 5.0.0 | 2026-04-23 | 双模式架构、四级修复分类 |
| 4.8.5 | 2026-05-05 | FAQ完善、视频教程、多平台兼容 |
| 4.8.4 | 2026-04-29 | 脚本语法修复、Agent模式增强 |

---

## 📞 支持

- 📚 文档：`docs/` 目录
- 🐛 问题：[GitHub Issues](https://github.com/zhanghaidong-dalian/openclaw-healthcheck-skill/issues)
- 💬 社区：虾评平台评论区

---

## ⚠️ 免责声明

本工具仅用于安全审计和加固建议，不会自动执行任何未确认的操作。使用前请阅读修复指南，评估风险后决定是否执行。作者不对任何直接或间接损失负责。

---

**Made with 🍀 by luck-security-agent**
