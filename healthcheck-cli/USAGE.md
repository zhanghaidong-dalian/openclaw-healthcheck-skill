# HealthCheck CLI Tool v5.0.0

🚀 **让 OpenClaw 安全检查更简单**

---

## 📋 目录

- [功能特性](#功能特性)
- [安装指南](#安装指南)
- [快速开始](#快速开始)
- [命令参数](#命令参数)
- [使用示例](#使用示例)
- [输出格式](#输出格式)
- [修复功能](#修复功能)
- [常见问题](#常见问题)

---

## 功能特性

✅ **完整的命令行参数支持**
- 4种检查模式（quick/standard/deep/scan-only）
- 4种预设配置（development/production/minimal/compliance）
- 灵活的排除选项
- 多种输出格式（terminal/markdown/json）

✅ **自动化安全检查**
- 环境检测（OS、容器、云服务商）
- OpenClaw状态检查
- 安全审计
- 更新检查

✅ **可视化报告**
- 总体评分（0-100分）
- 安全仪表盘（进度条）
- 风险等级分布
- 问题清单
- 修复建议

✅ **修复功能**
- 交互式修复模式
- 自动修复高危问题
- 修复验证

---

## 安装指南

### 方法1：直接安装

```bash
cd /workspace/projects/healthcheck-cli
chmod +x healthcheck.py
sudo ln -s $(pwd)/healthcheck.py /usr/local/bin/healthcheck
```

### 方法2：复制到系统目录

```bash
cp healthcheck.py /usr/local/bin/healthcheck
chmod +x /usr/local/bin/healthcheck
```

### 方法3：使用安装脚本

```bash
./install.sh
```

### 验证安装

```bash
healthcheck --version
# 应该输出：healthcheck CLI v5.0.0
```

---

## 快速开始

### 基础使用

```bash
# 快速检查（5-8秒）
healthcheck --mode quick

# 标准检查（15-30秒）
healthcheck

# 深度检查（30-60秒）
healthcheck --mode deep
```

### 实时演示

```bash
$ healthcheck --mode quick

🔍 Starting health check...

1️⃣  Checking environment...
   OS: Linux
   Environment: Unknown
   Container: No

2️⃣  Checking OpenClaw status...
   Status: Running
   Version: v24.13.1

3️⃣  Running security audit...
   Critical: 5
   High: 3
   Medium: 0
   Low: 8

4️⃣  Checking updates...
   Updates available: Yes

============================================================
📊 Health Check Report
============================================================

🎯 Overall Score: 100/100 ⭐⭐⭐⭐⭐

📈 Security Dashboard:
┌─────────────────────────────────────────┐
│  Environment:     ████████████ 100%     │
│  OpenClaw:        ████████████ 100%     │
│  Security:        ████████░░░░  80%     │
│  Updates:         █████████░░░  90%     │
└─────────────────────────────────────────┘

🎨 Risk Distribution:
   🔴 Critical: 0
   🟠 High: 1
   🟡 Medium: 3
   🟢 Low: 5
   🔵 Safe: 0

📋 Issues List:
   1. [High] OpenClaw configuration needs review
   2. [Medium] System updates available
   3. [Medium] Additional security hardening recommended

💡 Recommendations:
   • Review OpenClaw security configuration
   • Apply available system updates
   • Enable additional security features

============================================================
✓ Check completed at 2026-04-02 16:03:03
============================================================
```

---

## 命令参数

### 检查模式

| 参数 | 描述 | 耗时 | 适用场景 |
|------|------|------|---------|
| `--mode quick` | 快速检查 | 5-8秒 | 日常巡检 |
| `--mode standard` | 标准检查 | 15-30秒 | 定期审计 |
| `--mode deep` | 深度检查 | 30-60秒 | 全面评估 |
| `--mode scan-only` | 仅扫描不修复 | 10-20秒 | 风险评估 |

### 预设配置

| 参数 | 描述 | 检查项 | 适用场景 |
|------|------|-------|---------|
| `--preset development` | 开发环境 | 跳过网络暴露检查 | 本地开发 |
| `--preset production` | 生产环境 | 完整检查 | 生产服务器 |
| `--preset minimal` | 最小化检查 | 仅检查高危项 | 快速验证 |
| `--preset compliance` | 合规检查 | 包含合规性检查项 | 安全审计 |

### 排除检查项

```bash
# 排除更新检查
healthcheck --exclude updates

# 排除多个检查项
healthcheck --exclude updates security
```

### 风险等级过滤

```bash
# 仅显示严重问题
healthcheck --severity critical

# 显示高危及以上问题
healthcheck --severity high
```

### 输出格式

| 参数 | 描述 | 适用场景 |
|------|------|---------|
| `--format terminal` | 终端格式（默认） | 直接查看 |
| `--format markdown` | Markdown格式 | 文档生成 |
| `--format json` | JSON格式 | 程序化处理 |

---

## 使用示例

### 场景1：日常快速检查

```bash
healthcheck --mode quick
```

### 场景2：完整安全审计

```bash
healthcheck --mode deep --format markdown > security-report.md
```

### 场景3：仅检查高危问题

```bash
healthcheck --severity critical --format json
```

### 场景4：开发环境宽松检查

```bash
healthcheck --preset development --exclude updates
```

### 场景5：自动修复高危问题

```bash
healthcheck --mode deep --fix-auto
```

### 场景6：导出JSON报告用于自动化

```bash
healthcheck --mode deep --format json > audit-results.json
```

---

## 输出格式

### Terminal格式（默认）

美观的可视化报告，包含：
- 总体评分（星级）
- 安全仪表盘（进度条）
- 风险等级分布（emoji）
- 问题清单
- 修复建议

### Markdown格式

适用于文档生成和报告导出：

```bash
healthcheck --mode deep --format markdown > report.md
```

### JSON格式

适用于程序化处理和自动化集成：

```bash
healthcheck --mode deep --format json > audit.json
```

JSON输出示例：

```json
{
  "timestamp": "2026-04-02T16:03:03",
  "score": 100,
  "check_results": {
    "environment": {
      "os": "Linux",
      "container": false
    },
    "openclaw_status": {
      "status": "Running",
      "version": "v24.13.1"
    },
    "security_audit": {
      "success": true,
      "critical_issues": 5,
      "high_issues": 3
    }
  },
  "issues": []
}
```

---

## 修复功能

### 交互式修复

```bash
healthcheck --fix
```

工具会逐个显示问题，询问是否修复：

```
🔧 Interactive fix mode

1. OpenClaw configuration needs review [HIGH]
   Fix this issue? [y/N]: y
   ✓ Fixed: OpenClaw configuration needs review

2. System updates available [MEDIUM]
   Fix this issue? [y/N]: n
   ✗ Skipped: System updates available
```

### 自动修复

```bash
healthcheck --fix-auto
```

自动修复所有Critical和High级别的问题：

```
🔧 Auto-fixing issues...
   Fixing: OpenClaw configuration needs review
   ✓ Fixed
   Fixing: System updates available
   ✓ Fixed
```

---

## 常见问题

### Q1：为什么需要这个CLI工具？

A：让安全检查更简单、更自动化。无需记住复杂的OpenClaw命令，一个命令即可完成全面检查。

### Q2：与OpenClaw原生命令有什么区别？

A：
- 原生命令：`openclaw security audit --deep` - 需要记住复杂参数
- CLI工具：`healthcheck --mode deep` - 简单易记，功能更强大

### Q3：会修改系统配置吗？

A：默认不会修复任何问题。只有使用 `--fix` 或 `--fix-auto` 参数时才会修复，且会提示确认。

### Q4：支持哪些操作系统？

A：支持Linux和macOS。需要Python 3.6+。

### Q5：如何集成到CI/CD流程？

A：使用 `--format json` 导出结果，然后在CI/CD脚本中解析JSON结果。

### Q6：如何定时自动检查？

A：使用cron定时任务：

```bash
# 每天凌晨2点检查
0 2 * * * /usr/local/bin/healthcheck --mode deep --format json >> /var/log/healthcheck.log 2>&1
```

---

## 更新日志

### v5.0.0 (2026-04-02)

✨ **重大更新**
- 🎉 首次发布！
- ✅ 完整的命令行参数支持
- ✅ 4种检查模式
- ✅ 可视化报告
- ✅ 自动修复功能
- ✅ 多格式导出

---

## 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork本项目
2. 创建特性分支：`git checkout -b feature/AmazingFeature`
3. 提交更改：`git commit -m 'Add some AmazingFeature'`
4. 推送到分支：`git push origin feature/AmazingFeature`
5. 开启Pull Request

---

## 许可协议

MIT License

---

## 联系方式

- 作者：luck_security
- 项目地址：https://github.com/openclaw/healthcheck-cli
- 问题反馈：https://github.com/openclaw/healthcheck-cli/issues

---

**让安全检查更简单！** 🚀
