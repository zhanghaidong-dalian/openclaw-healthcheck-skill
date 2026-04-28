# healthcheck-skill 升级规划摘要

> 基于 Skill 安全扫描评测的借鉴点
> 规划版本：v5.0.0
> 规划周期：8 周

---

## 📊 核心对比

| 维度 | Skill 安全扫描 | 当前 healthcheck-skill | 升级后 healthcheck-skill |
|------|---------------|----------------------|------------------------|
| **扫描策略** | 分层扫描（黑盒→白盒→LLM） | 单一模式 | ✅ 分层扫描（轻量→深度→智能） |
| **规则体系** | 19 条规则，严重分级 | 24 个脚本 | ✅ 24 个规则文件（YAML） |
| **意图检查** | ✅ 意图一致性检查 | ❌ 无 | ✅ 声明 vs 实际行为比对 |
| **输出格式** | JSON + Markdown | Markdown | ✅ JSON + Markdown 双格式 |
| **白名单** | ✅ 域名白名单 | ❌ 无 | ✅ 域名/路径/服务白名单 |

---

## 🎯 五大核心升级功能

### 1️⃣ 分层扫描策略（Layered Scanning）

**三层架构**:
```
轻量级检查（< 30秒）
  ├─ 快速检测 6 个高风险项
  ├─ 适用：日常巡检
  └─ 输出：风险摘要

深度检查（3-5 分钟）
  ├─ 全面扫描 24 个检查项
  ├─ 适用：上线前检查
  └─ 输出：详细报告

智能检查（5-10 分钟）
  ├─ LLM 辅助 + 意图一致性
  ├─ 适用：高安全要求场景
  └─ 输出：智能化报告
```

**使用示例**:
```bash
./healthcheck --quick      # 轻量级检查
./healthcheck --deep       # 深度检查
./healthcheck --intelligent # 智能检查
./healthcheck --auto       # 自动推荐
```

---

### 2️⃣ 规则体系化（Rule Systematization）

**24 个检查项 → 24 个规则文件**

```yaml
# rules/ssh-hardening.yaml
id: ssh-001
name: SSH 密码认证禁用检查
category: ssh_hardening
severity: high
description: 检查 SSH 是否启用了密码认证

check:
  type: config_file
  file: /etc/ssh/sshd_config
  regex: '^PasswordAuthentication\s+(yes|no)'

expected: 'no'

remediation:
  script: fix-ssh-hardening.sh
  command: 'sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config'
  restart_required: true
  service: sshd

risk_assessment:
  if_violated: "密码认证易受暴力破解攻击"
  if_fixed: "SSH 登录安全性大幅提升"

metadata:
  compliance: ['CIS_Benchmark', 'PCI_DSS']
  tags: ['ssh', 'authentication', 'security']
```

**规则引擎**:
```bash
./rule-engine.sh --load-all          # 加载所有规则
./rule-engine.sh --validate ssh-001  # 验证规则
./rule-engine.sh --update            # 更新规则
```

---

### 3️⃣ 意图一致性检查（Intent Consistency Check）

**声明意图**: "安全加固 + 不中断访问 + 风险容忍度对齐"

**检查维度**:
1. **行为一致性**: 实际加固行为是否符合声明？
2. **访问保证**: 是否保留了访问能力？
3. **风险容忍度**: 是否尊重用户定义的风险容忍度？

**输出示例**:
```json
{
  "intent_consistency": {
    "declared_intent": {
      "primary": "安全加固",
      "secondary": ["不中断访问", "风险容忍度对齐"]
    },
    "actual_behavior": {
      "actions_performed": ["SSH 加固", "防火墙配置", "系统更新"],
      "access_impact": "none",
      "risk_level_changed": "high → medium"
    },
    "consistency_score": 0.95,
    "consistency_status": "consistent",
    "conclusion": "✅ 意图一致，行为符合声明"
  }
}
```

---

### 4️⃣ 结构化输出（Structured Output）

**JSON 格式**（自动化集成）:
```json
{
  "metadata": {
    "version": "5.0.0",
    "scan_type": "intelligent",
    "scan_time": "2026-04-28T08:00:00+08:00",
    "duration_seconds": 420
  },
  "summary": {
    "risk_level": "medium",
    "total_checks": 24,
    "passed": 18,
    "failed": 5,
    "auto_fixable": 4
  },
  "intent_analysis": { ... },
  "findings": [
    {
      "rule_id": "ssh-001",
      "severity": "high",
      "status": "failed",
      "remediation": {
        "script": "fix-ssh-hardening.sh",
        "estimated_time_seconds": 10
      }
    }
  ]
}
```

**Markdown 格式**（人类阅读）:
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
| 可自动修复 | 4 |

**风险级别**: 🟡 中等

## 高风险项

### 1. SSH 密码认证未禁用

**严重级别**: 🔴 高危
**修复方案**: `./scripts/fix-ssh-hardening.sh`
```

**导出命令**:
```bash
./healthcheck --output json --file /tmp/report.json
./healthcheck --output markdown --file /tmp/report.md
./healthcheck --output both --prefix /tmp/report
```

---

### 5️⃣ 白名单机制（Whitelist Mechanism）

**三种白名单**:

1. **信任域名**:
```yaml
whitelist:
  domains:
    - "github.com"
    - "update.ubuntu.com"
```

2. **信任路径**:
```yaml
whitelist:
  paths:
    - "/etc/ssh/sshd_config"
    - "/etc/ufw/"
    - "/var/log/openclaw/"
```

3. **信任服务**:
```yaml
whitelist:
  services:
    - name: "sshd"
      restart_required: true
    - name: "ufw"
      restart_required: true
```

**管理命令**:
```bash
./whitelist-manager.sh --add-domain --domain example.com
./whitelist-manager.sh --add-path --path /custom/path
./whitelist-manager.sh --list
./whitelist-manager.sh --check
```

**风险评分**:
- 访问白名单内 → 风险评分不增加
- 访问白名单外 → 风险评分 +1
- 未声明网络访问 → 风险评分 +2

---

## 📅 实施路线图（8 周）

### Week 1-2: 基础架构
- ✅ 设计分层扫描架构
- ✅ 实现轻量级检查脚本
- ✅ 实现深度检查脚本
- ✅ 实现规则引擎
- ✅ 实现白名单管理器

### Week 3-4: 规则体系化
- ✅ 定义规则格式（YAML）
- ✅ 为 24 个检查项创建规则
- ✅ 实现规则验证器

### Week 5: 意图一致性检查
- ✅ 实现意图提取器
- ✅ 实现行为分析器
- ✅ 实现一致性比对器

### Week 6: 结构化输出
- ✅ 设计 JSON/Markdown 格式
- ✅ 实现报告生成器
- ✅ 实现导出器

### Week 7: 集成测试
- ✅ 单元测试
- ✅ 集成测试
- ✅ 性能测试
- ✅ 用户测试

### Week 8: 文档与发布
- ✅ 更新文档
- ✅ 打包发布

---

## 🏆 预期收益

### 功能提升

| 指标 | 当前 | 升级后 | 提升 |
|------|------|--------|------|
| 检查速度 | 5 分钟 | 30 秒（轻量） | 10x |
| 自动化程度 | 60% | 90% | +50% |
| 规则可扩展性 | 低 | 高 | - |
| 输出格式 | Markdown | JSON + Markdown | +1 |

### 质量提升

| 指标 | 目标 |
|------|------|
| 检查项覆盖率 | 100% |
| 规则化率 | 100% |
| 自动修复成功率 | > 90% |
| 误报率 | < 5% |
| 用户满意度 | > 80% |

### 业务收益

- 📈 **下载量**: 预计提升 50%
- 📊 **用户满意度**: 预计提升 20%
- 🔄 **复购率**: 预计提升 30%
- 💬 **口碑**: 预计获得更多正面评价

---

## 🎯 优先级排序

### 高优先级（P0）- 必须实现

| 功能 | 工作量 | 原因 |
|------|--------|------|
| 轻量级检查 | 2天 | 快速评估需求高 |
| 规则引擎 | 3天 | 所有功能的基础 |
| 核心检查项规则化（6项） | 3天 | 高风险项优先 |
| JSON 输出 | 2天 | 自动化集成必需 |

### 中优先级（P1）- 应该实现

| 功能 | 工作量 | 原因 |
|------|--------|------|
| 深度检查 | 3天 | 全面审计需求 |
| 其他检查项规则化（18项） | 6天 | 完整覆盖 |
| Markdown 输出 | 2天 | 人类可读性 |
| 白名单机制 | 3天 | 减少误报 |

### 低优先级（P2）- 可以实现

| 功能 | 工作量 | 原因 |
|------|--------|------|
| 智能检查 | 5天 | 高级需求 |
| 意图一致性检查 | 4天 | 创新功能 |

---

## 💡 关键创新点

### 1. 分层扫描
借鉴 Skill 安全扫描的三层架构，平衡覆盖面与成本。

### 2. 规则体系化
将 24 个脚本标准化为 YAML 规则，便于扩展和维护。

### 3. 意图一致性检查
分析声明意图 vs 实际行为，避免过度加固。

### 4. 结构化输出
JSON 格式便于 CI/CD 集成，Markdown 格式便于人类阅读。

### 5. 白名单机制
减少误报，提升准确性。

---

## ⚠️ 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 规则引擎性能不足 | 中 | 高 | 优化算法、增量扫描 |
| 意图分析准确率低 | 中 | 中 | 多轮验证、人工复核 |
| 开发周期超期 | 中 | 高 | 分阶段交付 |
| 误报率升高 | 低 | 中 | 白名单机制 |

---

## 📦 版本规划

### v5.0.0 - 分层扫描（Phase 1）
**发布日期**: 2026-05-31
- 轻量级检查
- 深度检查
- 规则引擎
- 核心检查项规则化（6项）
- JSON 输出

### v5.1.0 - 规则体系（Phase 2）
**发布日期**: 2026-06-30
- 其他检查项规则化（18项）
- 规则验证器
- Markdown 输出
- 白名单机制

### v5.2.0 - 智能分析（Phase 3）
**发布日期**: 2026-07-31
- 智能检查
- 意图一致性检查
- 上下文感知
- 场景适配

---

## 📝 总结

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
**日期**: 2026-04-28
