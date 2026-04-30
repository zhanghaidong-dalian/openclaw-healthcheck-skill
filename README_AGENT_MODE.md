# Agent Mode 使用指南

## 什么是 Agent 模式？

Agent 模式是 HealthCheck 技能的**纯 Python 实现**，专为以下场景设计：

- ✅ **Coze 扣子** - 没有 `exec` 权限
- ✅ **Dify** - 沙盒环境限制
- ✅ **其他受限平台** - 不允许执行 shell 命令

## 与 Shell 模式的区别

| 特性 | Shell 模式 | Agent 模式 |
|------|------------|-----------|
| **执行方式** | Shell 脚本 | Python 代码 |
| **功能完整度** | 100% | ~60% |
| **自动修复** | ✅ 支持 | ❌ 不支持 |
| **系统检查** | ✅ 完整 | ⚠️ 基础 |
| **CVE 检查** | ✅ 完整 | ✅ 完整 |
| **平台兼容** | OpenClaw 本地 | 所有平台 |

## 快速开始

### 1. 目录结构

```
healthcheck-skill/
├── agent/                  # Agent 模式核心代码
│   ├── __init__.py
│   ├── scanner.py           # 安全扫描器
│   ├── rule_parser.py       # 规则解析器
│   └── report_gen.py        # 报告生成器
├── rules/                  # 安全规则库
│   ├── cve-2024-3094-polkit.yaml
│   ├── cve-2024-2961-liblzma.yaml
│   └── ... (共 23 个规则)
└── examples/
    └── agent-mode-quickstart.sh
```

### 2. 基础使用

#### 运行安全扫描

```bash
# 运行完整扫描
python3 agent/scanner.py

# 输出示例：
# ============================================
# Security Scanner - Agent Mode
# ============================================
#
# Loading security rules...
# Loaded 23 rules
#
# Detecting operating system...
# Detected OS: ubuntu
#
# Running health checks...
#   Port 22: OPEN
#   Port 80: CLOSED
#   Port 443: CLOSED
#
# Generating report...
```

#### 解析安全规则

```bash
# 解析所有 YAML 规则并导出 JSON
python3 agent/rule_parser.py

# 输出文件: /tmp/parsed-rules.json
```

#### 生成报告

```bash
# 生成 Markdown 格式报告
python3 agent/report_gen.py
```

## 技能调用示例

### 在 Coze 扣子中调用

**Prompt 示例：**

```
请使用 HealthCheck 技能的 Agent 模式进行安全扫描。

执行以下步骤：
1. 调用 agent/scanner.py 运行基础扫描
2. 解析 rules/ 目录中的 CVE 规则
3. 生成 Markdown 格式报告

注意事项：
- Agent 模式不支持自动修复
- 检测到的端口状态仅供参考
- 如需完整功能，请切换到 Shell 模式
```

### 在 Dify 中调用

**Workflow 配置：**

```yaml
steps:
  - name: Run Security Scan
    code: |
      import os
      os.chdir('/workspace/projects/workspace/healthcheck-skill')
      exec('python3 agent/scanner.py')
  
  - name: Parse Rules
    code: |
      exec('python3 agent/rule_parser.py')
  
  - name: Generate Report
    code: |
      exec('python3 agent/report_gen.py')
```

## 报告输出示例

### Markdown 格式

```markdown
# Security Scan Report

**Generated:** 2026-04-30T08:30:00
**Scanner Version:** 4.9.0
**Scan Mode:** Agent (Python-based)

---

## Executive Summary

| Metric | Value |
|--------|--------|
| Total Findings | 3 |
| Critical Issues | 1 |
| High Severity | 1 |
| Medium Severity | 1 |
| Low Severity | 0 |
| Risk Level | 🟠 HIGH |

---

## Findings by Severity

### 🔴 Critical Issues

#### 1. cve-2024-3094
**Severity:** 🔴 CRITICAL
**Description:** Polkit 权限提升漏洞 (CVE-2024-3094)
**Status:** VULNERABLE
**Remediation:** Update polkit to version 0.124+
```

## 限制与建议

### 当前限制

1. **无自动修复能力**
   - Agent 模式只能检测，不能自动执行修复
   - 需要手动运行修复命令

2. **端口检测有限**
   - 仅支持本地 127.0.0.1 端口检测
   - 不能检测远程主机

3. **依赖 Python 环境**
   - 需要 Python 3.7+
   - PyYAML（可选，增强规则解析）

### 使用建议

1. **快速检查**: 使用 Agent 模式进行日常扫描
2. **深度加固**: 使用 Shell 模式进行完整加固
3. **报告导出**: 两种模式都支持 JSON/Markdown 导出

## 下一步

- 阅读完整文档: `SKILL.md`
- 查看 Shell 模式: `scripts/` 目录
- 获取支持: [虾评平台](https://xiaping.coze.site/skill/61c9999f-1794-4f55-a6b8-6e457376b51e)