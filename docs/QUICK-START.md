# 🚀 快速开始 - OpenClaw 主机安全加固工具

**版本**: v4.8.x
**更新时间**: 2026-04-28

---

## 5 分钟上手

### 步骤 1：下载安装

```bash
# 方法1: 从 GitHub 克隆
git clone https://github.com/zhanghaidong-dalian/openclaw-healthcheck-skill.git
cd openclaw-healthcheck-skill

# 方法2: 从虾评平台下载
# 访问 https://xiaping.coze.site/skill/61c9999f-1794-4f55-a6b8-6e457376b51e

# 方法3: 下载最新 ZIP 包
wget https://github.com/zhanghaidong-dalian/openclaw-healthcheck-skill/archive/refs/heads/main.zip
unzip main.zip && cd openclaw-healthcheck-skill-main
```

### 步骤 2：赋予执行权限

```bash
chmod +x bin/healthcheck
chmod +x scripts/*.sh
```

### 步骤 3：首次扫描（推荐）

```bash
# 轻量级扫描 - 快速了解系统安全状况（< 30 秒）
./bin/healthcheck --quick

# 查看帮助信息
./bin/healthcheck --help
```

### 步骤 4：解读报告

扫描完成后，查看输出结果：

| 状态 | 颜色 | 含义 | 建议 |
|------|------|------|------|
| ✅ 安全 | 绿色 | 检查通过 | 保持现状 |
| ⚠️ 警告 | 黄色 | 存在风险 | 建议优化 |
| ❌ 危险 | 红色 | 严重风险 | 立即修复 |

### 步骤 5：执行修复

```bash
# 查看所有可修复项
./bin/healthcheck --list-fixes

# 交互式修复（推荐）
./bin/healthcheck --fix

# 自动修复（无需确认）
./bin/healthcheck --auto-fix
```

---

## 常见使用场景

### 场景 1：日常巡检（推荐）

```bash
# 每天花 30 秒快速检查
./bin/healthcheck --quick
```

**适用场景**：
- 日常安全巡检
- 快速了解系统状态
- 定期安全检查

---

### 场景 2：深度审计

```bash
# 全面深度扫描（3-5 分钟）
./bin/healthcheck --deep
```

**适用场景**：
- 上线前安全检查
- 安全审计报告
- 全面风险评估

---

### 场景 3：智能扫描

```bash
# AI 辅助智能分析（5-10 分钟）
./bin/healthcheck --intelligent
```

**适用场景**：
- 高安全要求场景
- 重要系统上线前
- 深度威胁分析

---

### 场景 4：定时巡检

```bash
# 配置定时任务（每天凌晨 2 点执行）
./bin/healthcheck --cron "0 2 * * *"

# 查看定时任务
./bin/healthcheck --cron-list
```

---

### 场景 5：输出报告

```bash
# 输出 JSON 格式（便于程序处理）
./bin/healthcheck --quick --output json /tmp/report.json

# 输出 Markdown 格式（便于阅读）
./bin/healthcheck --deep --output markdown /tmp/report.md

# 同时输出两种格式
./bin/healthcheck --intelligent --output both /tmp/report
```

---

## 命令行参数速查

| 参数 | 说明 | 示例 |
|------|------|------|
| `--quick` | 轻量级扫描（< 30 秒） | `./healthcheck --quick` |
| `--deep` | 深度扫描（3-5 分钟） | `./healthcheck --deep` |
| `--intelligent` | 智能扫描（5-10 分钟） | `./healthcheck --intelligent` |
| `--auto` | 自动选择模式 | `./healthcheck --auto` |
| `--fix` | 交互式修复 | `./healthcheck --fix` |
| `--auto-fix` | 自动修复 | `./healthcheck --auto-fix` |
| `--cron` | 配置定时任务 | `./healthcheck --cron "0 2 * * *"` |
| `--output` | 指定输出格式 | `./healthcheck --output json file.json` |
| `--list-rules` | 列出所有规则 | `./healthcheck --list-rules` |
| `--list-fixes` | 列出可修复项 | `./healthcheck --list-fixes` |
| `--check <item>` | 检查指定项 | `./healthcheck --check firewall` |
| `--whitelist` | 白名单管理 | `./healthcheck --whitelist` |
| `--summary` | 摘要报告模式 | `./healthcheck --summary` |
| `--incremental` | 增量检查 | `./healthcheck --incremental` |

---

## 输出示例

### 轻量级扫描输出

```
🔍 OpenClaw 主机安全加固工具 v4.8.2
================================================

📊 扫描模式: 轻量级
⏱️ 预计时间: < 30 秒

开始扫描...
================================================

✅ SSH 密码认证: 已禁用
✅ SSH Root 登录: 已禁用
⚠️ 防火墙状态: 未启用
✅ 系统更新: 无可用更新
✅ Fail2ban: 已安装并运行

================================================
📊 扫描完成
================================================

🟢 安全项: 4
🟡 建议项: 1
🔴 危险项: 0

⏱️ 扫描耗时: 28 秒

💡 建议: 启用防火墙以提升系统安全性
   ./bin/healthcheck --fix
```

---

## 常见问题

### Q1: 提示 "Permission denied"

```bash
# 解决: 使用 sudo
sudo ./bin/healthcheck --quick
```

### Q2: 提示 "command not found"

```bash
# 解决: 赋予执行权限
chmod +x bin/healthcheck
```

### Q3: 扫描结果全是绿色

```bash
# 可能原因: 沙盒环境限制
# 解决: 在真实 Linux 环境中运行
```

### Q4: 修复脚本执行失败

```bash
# 查看详细错误
./bin/healthcheck --fix --verbose

# 查看故障排查文档
cat docs/TROUBLESHOOTING.md
```

---

## 下一步

- 📖 [完整使用手册](docs/USAGE.md) - 了解所有功能
- 🔧 [故障排查指南](docs/TROUBLESHOOTING.md) - 解决问题
- 💡 [使用示例大全](docs/EXAMPLES.md) - 学习实战案例
- 🛠️ [场景脚本](../examples/) - 直接使用

---

## 相关链接

- 🏠 GitHub: https://github.com/zhanghaidong-dalian/openclaw-healthcheck-skill
- 📦 虾评平台: https://xiaping.coze.site/skill/61c9999f-1794-4f55-a6b8-6e457376b51e
- 💬 问题反馈: https://github.com/zhanghaidong-dalian/openclaw-healthcheck-skill/issues

---

**快速链接**：
- [上一版本说明](../CHANGELOG.md)
- [安全声明](../SECURITY_STATEMENT.md)
- [贡献指南](../CONTRIBUTING.md)
