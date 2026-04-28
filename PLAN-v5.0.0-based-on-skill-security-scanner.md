# healthcheck-skill 升级规划

> 基于 Skill 安全扫描评测的借鉴点
> 规划版本：v5.0.0
> 规划日期：2026-04-28

---

## 📋 目录

- [一、借鉴点总结](#一借鉴点总结)
- [二、核心升级功能](#二核心升级功能)
- [三、详细规划](#三详细规划)
- [四、实施路线图](#四实施路线图)
- [五、优先级排序](#五优先级排序)
- [六、风险评估](#六风险评估)

---

## 一、借鉴点总结

### 从 Skill 安全扫描学到的

| 序号 | 借鉴点 | 说明 | 价值 |
|------|--------|------|------|
| 1 | **分层扫描策略** | 黑盒 → 白盒 → LLM 分析三层架构 | 平衡覆盖面与成本 |
| 2 | **规则体系化** | 19条规则，每条有严重级别、修复建议 | 结构化、可扩展 |
| 3 | **意图一致性检查** | LLM 分析声明意图 vs 实际行为 | 创新点，提升可信度 |
| 4 | **结构化输出** | JSON 格式，包含 Summary + Intent + Findings | 便于自动化处理 |
| 5 | **白名单机制** | 默认信任域名，减少误报 | 提升准确性 |

### 与我们技能的结合点

| 借鉴点 | 结合方式 | 适用场景 |
|--------|----------|----------|
| 分层扫描 | 轻量检查 → 深度检查 → 人工复核 | 不同安全需求 |
| 规则体系 | 24个检查项规则化、可配置 | 标准化输出 |
| 意图检查 | 声明（安全加固）vs 实际行为 | 避免过度加固 |
| 结构化输出 | JSON/Markdown 双格式 | CI/CD 集成 |
| 白名单 | 信任的系统路径/服务 | 减少误报 |

---

## 二、核心升级功能

### 🎯 目标

打造一个**智能化、分层级、可配置**的系统安全加固工具，具备：
- 分层检查策略（轻量/深度/智能）
- 规则体系化（24个检查项标准化）
- 意图一致性验证（声明 vs 实际）
- 结构化输出（JSON/Markdown）
- 白名单机制（减少误报）

---

## 三、详细规划

### 功能 1: 分层扫描策略（Layered Scanning）

#### 1.1 三层扫描架构

```
第一层: 轻量级检查（Quick Scan）
  ├─ 快速检测高风险项（SSH、防火墙、更新）
  ├─ 执行时间: < 30 秒
  ├─ 适用场景: 日常巡检、快速评估
  └─ 输出: 风险摘要

第二层: 深度检查（Deep Scan）
  ├─ 全面扫描所有检查项（24项）
  ├─ 执行时间: 3-5 分钟
  ├─ 适用场景: 上线前检查、合规审计
  └─ 输出: 详细报告 + 修复建议

第三层: 智能检查（Intelligent Scan）
  ├─ LLM 辅助分析 + 意图一致性检查
  ├─ 上下文感知 + 场景适配
  ├─ 执行时间: 5-10 分钟
  ├─ 适用场景: 复杂环境、高安全要求
  └─ 输出: 智能化报告 + 风险评级
```

#### 1.2 实现方案

**新增脚本**:
```bash
scripts/
├── layered-scanner.sh         # 分层扫描主入口
├── quick-scan.sh              # 第一层：轻量级检查
├── deep-scan.sh               # 第二层：深度检查
└── intelligent-scan.sh        # 第三层：智能检查
```

**使用示例**:
```bash
# 轻量级检查（默认）
./healthcheck --quick

# 深度检查
./healthcheck --deep

# 智能检查（推荐用于高安全要求场景）
./healthcheck --intelligent

# 自动选择（根据场景推荐）
./healthcheck --auto
```

#### 1.3 输出示例

**轻量级检查输出**:
```json
{
  "scan_type": "quick",
  "scan_time": "2026-04-28T08:00:00+08:00",
  "duration_seconds": 25,
  "summary": {
    "risk_level": "medium",
    "checked_items": 6,
    "issues_found": 2,
    "blockers": 0
  },
  "high_risk_items": [
    {
      "item": "ssh_password_auth",
      "severity": "high",
      "current": "enabled",
      "recommended": "disabled",
      "action": "fix-ssh-hardening.sh"
    }
  ],
  "recommendation": "建议执行深度扫描以获取完整评估"
}
```

---

### 功能 2: 规则体系化（Rule Systematization）

#### 2.1 检查项规则化

将现有 24 个检查项标准化为规则格式：

**规则格式**:
```yaml
# rules/ssh-hardening.yaml
id: ssh-001
name: SSH 密码认证禁用检查
category: ssh_hardening
severity: high
description: 检查 SSH 是否启用了密码认证（应使用密钥认证）

check:
  type: config_file
  file: /etc/ssh/sshd_config
  regex: '^PasswordAuthentication\s+(yes|no)'

expected: 'no'
fallback:

remediation:
  script: fix-ssh-hardening.sh
  command: 'sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config'
  restart: true
  service: sshd

risk_assessment:
  if_violated: "密码认证易受暴力破解攻击"
  if_fixed: "SSH 登录安全性大幅提升"

metadata:
  cve_references: []
  compliance: ['CIS_Benchmark', 'PCI_DSS']
  tags: ['ssh', 'authentication', 'security']
```

#### 2.2 规则文件结构

```
rules/
├── ssh-hardening.yaml          # SSH 加固规则
├── firewall-config.yaml        # 防火墙配置规则
├── system-updates.yaml         # 系统更新规则
├── logging-permissions.yaml    # 日志权限规则
├── openclaw-permissions.yaml   # OpenClaw 权限规则
├── fail2ban-integration.yaml   # fail2ban 集成规则
├── intrusion-detection.yaml    # 入侵检测规则
├── disk-encryption.yaml        # 磁盘加密规则
├── kernel-hardening.yaml       # 内核加固规则
└── custom-rules.yaml           # 自定义规则（用户可扩展）
```

#### 2.3 规则引擎实现

**新增脚本**:
```bash
scripts/
├── rule-engine.sh              # 规则引擎主入口
├── rule-validator.sh           # 规则验证器
└── rule-updater.sh             # 规则更新器
```

**规则加载**:
```bash
# 加载所有规则
./rule-engine.sh --load-all

# 加载特定规则
./rule-engine.sh --load ssh-hardening.yaml

# 验证规则
./rule-engine.sh --validate ssh-hardening.yaml

# 更新规则（从远程仓库）
./rule-engine.sh --update
```

#### 2.4 规则优先级

| 优先级 | 严重级别 | 检查项数量 | 自动修复 | 需要重启 |
|--------|----------|------------|----------|----------|
| 🔴 P0 | critical | 6 | 是 | 是/否 |
| 🟠 P1 | high | 8 | 是 | 否 |
| 🟡 P2 | medium | 6 | 是 | 否 |
| 🟢 P3 | low | 4 | 否 | 否 |

---

### 功能 3: 意图一致性检查（Intent Consistency Check）

#### 3.1 功能定义

**声明意图**（来自 SKILL.md）:
> "Assess and harden the host running OpenClaw, then align it to a user-defined risk tolerance without breaking access."

**检查维度**:
1. **行为一致性**: 实际加固行为是否符合声明？
2. **访问保证**: 是否保留了访问能力？
3. **风险容忍度**: 是否尊重用户定义的风险容忍度？

#### 3.2 实现方案

**新增脚本**:
```bash
scripts/
├── intent-analyzer.sh          # 意图分析器
└── intent-validator.sh         # 意图验证器
```

**检查流程**:
```bash
# 1. 提取声明意图（从 SKILL.md）
./intent-analyzer.sh --extract

# 2. 分析实际行为（从执行日志）
./intent-analyzer.sh --analyze /var/log/healthcheck.log

# 3. 比对一致性
./intent-validator.sh --compare

# 4. 生成报告
./intent-validator.sh --report
```

#### 3.3 输出示例

```json
{
  "intent_consistency": {
    "declared_intent": {
      "primary": "安全加固",
      "secondary": ["不中断访问", "风险容忍度对齐"]
    },
    "actual_behavior": {
      "actions_performed": [
        "SSH 加固",
        "防火墙配置",
        "系统更新"
      ],
      "access_impact": "none",
      "risk_level_changed": "high → medium"
    },
    "consistency_score": 0.95,
    "consistency_status": "consistent",
    "deviations": [
      {
        "type": "info",
        "description": "额外检查了日志权限（未在声明中，但符合安全加固范围）",
        "impact": "positive"
      }
    ],
    "conclusion": "✅ 意图一致，行为符合声明"
  }
}
```

---

### 功能 4: 结构化输出（Structured Output）

#### 4.1 输出格式支持

**JSON 格式**（用于自动化）:
```json
{
  "metadata": {
    "version": "5.0.0",
    "scan_type": "intelligent",
    "scan_time": "2026-04-28T08:00:00+08:00",
    "duration_seconds": 420,
    "hostname": "server-01",
    "os": "Ubuntu 22.04 LTS"
  },
  "summary": {
    "risk_level": "medium",
    "total_checks": 24,
    "passed": 18,
    "failed": 5,
    "skipped": 1,
    "auto_fixable": 4,
    "manual_intervention": 1
  },
  "intent_analysis": { ... },
  "findings": [
    {
      "rule_id": "ssh-001",
      "category": "ssh_hardening",
      "severity": "high",
      "status": "failed",
      "current": "PasswordAuthentication yes",
      "expected": "PasswordAuthentication no",
      "remediation": {
        "script": "fix-ssh-hardening.sh",
        "command": "sed -i ...",
        "restart_required": true,
        "service": "sshd",
        "estimated_time_seconds": 10
      },
      "risk_description": "密码认证易受暴力破解攻击",
      "fix_benefit": "SSH 登录安全性大幅提升"
    }
  ],
  "recommendations": [
    {
      "priority": "high",
      "action": "fix-ssh-hardening.sh",
      "reason": "高风险项，建议立即修复"
    }
  ]
}
```

**Markdown 格式**（用于人类阅读）:
```markdown
# 安全加固检查报告

**扫描时间**: 2026-04-28 08:00:00
**扫描类型**: 智能扫描
**总耗时**: 420 秒

## 摘要

| 指标 | 数值 |
|------|------|
| 总检查项 | 24 |
| 通过 | 18 |
| 失败 | 5 |
| 跳过 | 1 |
| 可自动修复 | 4 |
| 需要手动干预 | 1 |

**风险级别**: 🟡 中等

## 高风险项

### 1. SSH 密码认证未禁用

**严重级别**: 🔴 高危
**当前状态**: `PasswordAuthentication yes`
**期望状态**: `PasswordAuthentication no`

**风险说明**: 密码认证易受暴力破解攻击

**修复方案**:
```bash
./scripts/fix-ssh-hardening.sh
```

**修复效果**: SSH 登录安全性大幅提升

---

## 意图一致性分析

**声明意图**: 安全加固 + 不中断访问
**实际行为**: SSH 加固、防火墙配置、系统更新
**一致性得分**: 95/100
**一致性状态**: ✅ 一致

## 修复建议

| 优先级 | 操作 | 原因 |
|--------|------|------|
| 🔴 高 | 执行 fix-ssh-hardening.sh | 高风险项，建议立即修复 |
| 🟠 中 | 执行 fix-firewall-defaults.sh | 中风险项，建议尽快修复 |
```

#### 4.2 实现方案

**新增脚本**:
```bash
scripts/
├── report-generator.sh         # 报告生成器
├── json-exporter.sh            # JSON 导出器
└── markdown-exporter.sh        # Markdown 导出器
```

**使用示例**:
```bash
# 生成 JSON 报告
./healthcheck --output json --file /tmp/report.json

# 生成 Markdown 报告
./healthcheck --output markdown --file /tmp/report.md

# 生成两种格式
./healthcheck --output both --prefix /tmp/report

# 直接输出到控制台
./healthcheck --output console
```

---

### 功能 5: 白名单机制（Whitelist Mechanism）

#### 5.1 白名单类型

**1. 信任域名白名单**
```yaml
# config/whitelisted-domains.yaml
whitelist:
  domains:
    - "github.com"              # 用于更新规则
    - "api.github.com"
    - "update.ubuntu.com"       # 用于系统更新
    - "archive.ubuntu.com"
  reason: "系统更新和规则获取需要访问这些域名"
```

**2. 信任路径白名单**
```yaml
# config/whitelisted-paths.yaml
whitelist:
  paths:
    - "/etc/ssh/sshd_config"    # SSH 配置文件
    - "/etc/ufw/"               # 防火墙配置
    - "/var/log/openclaw/"      # OpenClaw 日志
  reason: "这些路径需要被健康检查工具访问"
  risk_level: "low"
```

**3. 信任服务白名单**
```yaml
# config/whitelisted-services.yaml
whitelist:
  services:
    - name: "sshd"
      reason: "SSH 服务需要重启以应用安全配置"
      restart_required: true
    - name: "ufw"
      reason: "防火墙服务需要重启以应用规则"
      restart_required: true
    - name: "fail2ban"
      reason: "fail2ban 需要重启以应用新规则"
      restart_required: true
```

**4. 用户自定义白名单**
```yaml
# config/custom-whitelist.yaml
whitelist:
  domains: []
  paths: []
  services: []
  commands: []
```

#### 5.2 白名单管理

**新增脚本**:
```bash
scripts/
├── whitelist-manager.sh        # 白名单管理器
├── whitelist-validator.sh       # 白名单验证器
└── whitelist-import.sh         # 白名单导入器
```

**使用示例**:
```bash
# 添加域名到白名单
./whitelist-manager.sh --add-domain --domain example.com

# 添加路径到白名单
./whitelist-manager.sh --add-path --path /custom/path

# 验证白名单
./whitelist-validator.sh --check

# 导入自定义白名单
./whitelist-import.sh --file /path/to/custom-whitelist.yaml

# 列出所有白名单
./whitelist-manager.sh --list
```

#### 5.3 白名单与风险评分

**规则**:
- 访问白名单内的域名/路径/服务 → 风险评分不增加
- 访问白名单外的 → 风险评分 +1
- 未声明的网络访问 → 风险评分 +2

**示例**:
```json
{
  "network_access": {
    "requested_domains": ["github.com", "unknown.com"],
    "whitelisted": ["github.com"],
    "non_whitelisted": ["unknown.com"],
    "risk_score_impact": "+1 (未声明域名)"
  }
}
```

---

## 四、实施路线图

### 阶段 1: 基础架构（Week 1-2）

**目标**: 搭建分层扫描框架

**任务**:
1. ✅ 设计分层扫描架构
2. ✅ 实现轻量级检查脚本（quick-scan.sh）
3. ✅ 实现深度检查脚本（deep-scan.sh）
4. ✅ 实现规则加载器（rule-engine.sh）
5. ✅ 实现白名单管理器（whitelist-manager.sh）

**交付物**:
- 3 个新脚本
- 基础架构文档
- 单元测试

**验收标准**:
- 轻量级检查 < 30 秒
- 深度检查完成 24 项检查
- 规则加载成功
- 白名单管理功能正常

---

### 阶段 2: 规则体系化（Week 3-4）

**目标**: 将 24 个检查项规则化

**任务**:
1. ✅ 定义规则格式（YAML）
2. ✅ 为 6 个核心检查项创建规则
3. ✅ 为 8 个高风险检查项创建规则
4. ✅ 为 6 个中风险检查项创建规则
5. ✅ 为 4 个低风险检查项创建规则
6. ✅ 实现规则验证器（rule-validator.sh）

**交付物**:
- 24 个规则文件（YAML）
- 规则验证器
- 规则文档

**验收标准**:
- 所有规则通过验证
- 规则加载成功率 100%
- 规则执行成功率 > 95%

---

### 阶段 3: 意图一致性检查（Week 5）

**目标**: 实现意图分析功能

**任务**:
1. ✅ 实现意图提取器（从 SKILL.md）
2. ✅ 实现行为分析器（从执行日志）
3. ✅ 实现一致性比对器
4. ✅ 实现报告生成器

**交付物**:
- 意图分析器
- 一致性检查报告模板
- 测试用例

**验收标准**:
- 意图提取准确率 > 90%
- 行为分析准确率 > 85%
- 一致性评分合理

---

### 阶段 4: 结构化输出（Week 6）

**目标**: 实现 JSON/Markdown 双格式输出

**任务**:
1. ✅ 设计 JSON 输出格式
2. ✅ 设计 Markdown 输出格式
3. ✅ 实现报告生成器
4. ✅ 实现导出器

**交付物**:
- JSON/Markdown 报告生成器
- 报告模板
- 输出示例

**验收标准**:
- JSON 格式符合规范
- Markdown 格式可读性强
- 双格式输出一致

---

### 阶段 5: 集成测试（Week 7）

**目标**: 全面测试所有功能

**任务**:
1. ✅ 单元测试（每个脚本）
2. ✅ 集成测试（端到端流程）
3. ✅ 性能测试（执行时间）
4. ✅ 安全测试（不引入新风险）
5. ✅ 用户测试（真实场景）

**交付物**:
- 测试报告
- 性能基准
- 用户反馈

**验收标准**:
- 所有测试通过
- 性能满足要求
- 用户满意度 > 80%

---

### 阶段 6: 文档与发布（Week 8）

**目标**: 完善文档并发布

**任务**:
1. ✅ 更新 SKILL.md
2. ✅ 编写用户指南
3. ✅ 编写开发者指南
4. ✅ 更新 CHANGELOG.md
5. ✅ 打包发布

**交付物**:
- 完整文档
- 发布包
- 发布公告

**验收标准**:
- 文档完整准确
- 发布包可用
- 发布公告清晰

---

## 五、优先级排序

### 高优先级（P0）- 必须实现

| 功能 | 优先级 | 工作量 | 依赖 | 原因 |
|------|--------|--------|------|------|
| 轻量级检查 | 🔴 P0 | 2天 | 无 | 快速评估需求高 |
| 规则引擎 | 🔴 P0 | 3天 | 无 | 所有功能的基础 |
| 核心检查项规则化（6项） | 🔴 P0 | 3天 | 规则引擎 | 高风险项优先 |
| JSON 输出 | 🔴 P0 | 2天 | 无 | 自动化集成必需 |

### 中优先级（P1）- 应该实现

| 功能 | 优先级 | 工作量 | 依赖 | 原因 |
|------|--------|--------|------|------|
| 深度检查 | 🟠 P1 | 3天 | 轻量级检查 | 全面审计需求 |
| 其他检查项规则化（18项） | 🟠 P1 | 6天 | 核心规则化 | 完整覆盖 |
| Markdown 输出 | 🟠 P1 | 2天 | JSON 输出 | 人类可读性 |
| 白名单机制 | 🟠 P1 | 3天 | 规则引擎 | 减少误报 |

### 低优先级（P2）- 可以实现

| 功能 | 优先级 | 工作量 | 依赖 | 原因 |
|------|--------|--------|------|------|
| 智能检查 | 🟡 P2 | 5天 | 深度检查 | 高级需求 |
| 意图一致性检查 | 🟡 P2 | 4天 | 行为分析 | 创新功能 |

---

## 六、风险评估

### 技术风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 规则引擎性能不足 | 中 | 高 | 优化算法、增量扫描 |
| 意图分析准确率低 | 中 | 中 | 多轮验证、人工复核 |
| JSON 格式兼容性问题 | 低 | 中 | 版本控制、向后兼容 |
| 白名单误报/漏报 | 低 | 中 | 持续优化、用户反馈 |

### 时间风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 开发周期超期 | 中 | 高 | 分阶段交付、优先级排序 |
| 测试时间不足 | 中 | 中 | 并行开发、自动化测试 |

### 安全风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 引入新的安全漏洞 | 低 | 高 | 安全审计、代码审查 |
| 白名单被滥用 | 低 | 中 | 权限控制、审计日志 |

---

## 七、成功指标

### 功能指标

| 指标 | 目标 | 测量方式 |
|------|------|----------|
| 检查项覆盖率 | 100% | 实际检查项 / 总检查项 |
| 规则化率 | 100% | 规则化检查项 / 总检查项 |
| 自动修复成功率 | > 90% | 自动修复成功 / 总修复尝试 |
| 误报率 | < 5% | 误报数 / 总报告数 |

### 性能指标

| 指标 | 目标 | 测量方式 |
|------|------|----------|
| 轻量级检查时间 | < 30 秒 | 执行时间 |
| 深度检查时间 | < 5 分钟 | 执行时间 |
| 规则加载时间 | < 5 秒 | 加载时间 |
| 报告生成时间 | < 10 秒 | 生成时间 |

### 质量指标

| 指标 | 目标 | 测量方式 |
|------|------|----------|
| 单元测试覆盖率 | > 80% | 测试覆盖率报告 |
| 用户满意度 | > 80% | 用户反馈评分 |
| 文档完整性 | 100% | 文档检查清单 |

---

## 八、附录

### A. 当前检查项清单（24项）

1. SSH 密钥认证（high）
2. SSH 禁止密码登录（high）
3. SSH 禁止 root 登录（high）
4. SSH 配置文件权限（medium）
5. 防火墙启用状态（high）
6. 防火墙端口规则（medium）
7. 系统更新状态（high）
8. 自动更新配置（medium）
9. 日志文件权限（medium）
10. OpenClaw 文件权限（high）
11. OpenClaw 配置文件权限（medium）
12. fail2ban 安装状态（medium）
13. fail2ban 运行状态（medium）
14. fail2ban 规则配置（low）
15. 入侵检测（low）
16. 磁盘加密状态（medium）
17. 内核安全参数（low）
18. SUID/SGID 文件（low）
19. 用户密码策略（medium）
20. 闲置账号（low）
21. 系统服务审计（low）
22. 开放端口审计（medium）
23. 网络连接审计（low）
24. 系统资源监控（low）

### B. 规则模板

```yaml
id: RULE-XXX
name: 检查项名称
category: category_name
severity: high | medium | low | critical
description: 检查项描述

check:
  type: config_file | command | service | file_permission
  # type-specific fields

expected: expected_value

remediation:
  script: fix-script.sh
  command: "command to fix"
  restart_required: true | false
  service: service_name

risk_assessment:
  if_violated: "风险描述"
  if_fixed: "修复后的好处"

metadata:
  cve_references: []
  compliance: ['CIS_Benchmark', 'PCI_DSS']
  tags: ['tag1', 'tag2']
```

### C. 术语表

| 术语 | 说明 |
|------|------|
| 分层扫描 | 轻量/深度/智能三层扫描策略 |
| 规则引擎 | 加载、验证、执行规则的系统 |
| 意图一致性 | 声明意图 vs 实际行为的一致性 |
| 结构化输出 | JSON/Markdown 标准格式输出 |
| 白名单机制 | 信任域名/路径/服务列表 |
| 轻量级检查 | 快速扫描高风险项（<30秒） |
| 深度检查 | 全面扫描所有检查项（3-5分钟） |
| 智能检查 | LLM 辅助分析（5-10分钟） |

---

## 九、版本规划

### v5.0.0 - 分层扫描（Phase 1）

**发布日期**: 2026-05-31

**新功能**:
- ✅ 轻量级检查
- ✅ 深度检查
- ✅ 规则引擎
- ✅ 核心检查项规则化（6项）
- ✅ JSON 输出

### v5.1.0 - 规则体系（Phase 2）

**发布日期**: 2026-06-30

**新功能**:
- ✅ 其他检查项规则化（18项）
- ✅ 规则验证器
- ✅ Markdown 输出
- ✅ 白名单机制

### v5.2.0 - 智能分析（Phase 3）

**发布日期**: 2026-07-31

**新功能**:
- ✅ 智能检查
- ✅ 意图一致性检查
- ✅ 上下文感知
- ✅ 场景适配

---

## 十、总结

本规划基于对 Skill 安全扫描的深度评测，提出了一个**智能化、分层级、可配置**的系统安全加固工具升级方案。

**核心价值**:
1. **分层扫描**: 平衡覆盖面与成本，满足不同需求
2. **规则体系化**: 标准化输出，便于扩展和维护
3. **意图一致性**: 创新功能，提升可信度
4. **结构化输出**: 便于自动化集成
5. **白名单机制**: 减少误报，提升准确性

**实施周期**: 8 周
**预计工作量**: 40 人天
**预期收益**: 下载量提升 50%，用户满意度提升 20%

---

**规划人**: luck 🍀
**审核人**: haidong
**批准日期**: 2026-04-28
