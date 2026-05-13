---

## 🎛️ 命令行参数 | Command Line Options (v4.3.0+)

> ⚙️ **灵活配置，精准检查**

### 基本语法

```bash
healthcheck [选项]
```

### 可用参数

#### 1. 检查模式 | Check Modes

```bash
--mode <模式>          # 指定检查模式
```

| 模式 | 描述 | 耗时 | 适用场景 |
|------|------|------|---------|
| `quick` | 快速检查（基础状态 + 高危漏洞） | 5-8秒 | 日常巡检 |
| `standard` | 标准检查（全面检查） | 15-30秒 | 定期审计 |
| `deep` | 深度检查（包含详细报告和建议） | 30-60秒 | 全面评估 |
| `scan-only` | 仅扫描不修复 | 10-20秒 | 风险评估 |

**示例**:
```bash
healthcheck --mode quick          # 快速检查
healthcheck --mode deep           # 深度检查
```

---

#### 2. 预设配置 | Presets

```bash
--preset <预设>        # 使用预设配置
```

| 预设 | 描述 | 检查项 | 适用场景 |
|------|------|-------|---------|
| `development` | 开发环境 | 跳过网络暴露检查、宽松风险阈值 | 本地开发 |
| `production` | 生产环境 | 完整检查、严格风险阈值 | 生产服务器 |
| `minimal` | 最小化检查 | 仅检查高危项 | 快速验证 |
| `compliance` | 合规检查 | 包含合规性检查项 | 安全审计 |

**示例**:
```bash
healthcheck --preset development   # 开发环境宽松检查
healthcheck --preset production    # 生产环境严格检查
```

---

#### 3. 排除检查项 | Exclude Checks

```bash
--exclude <检查项>     # 排除特定检查项
```

**支持的检查项**:
- `cve` - CVE漏洞检查
- `malware` - 恶意技能扫描
- `firewall` - 防火墙检查
- `ssh` - SSH配置检查
- `updates` - 系统更新检查
- `permissions` - 文件权限检查
- `network` - 网络暴露检查
- `injection` - 提示词注入防护检查

**示例**:
```bash
# 跳过防火墙和SSH检查（适用于沙盒环境）
healthcheck --exclude firewall,ssh

# 仅检查CVE漏洞和恶意技能
healthcheck --exclude firewall,ssh,updates,permissions,network,injection
```

**注意**: 可以同时排除多个检查项，用逗号分隔。

---

#### 4. 风险等级过滤 | Severity Threshold

```bash
--severity <等级>     # 仅显示指定风险等级以上的问题
```

| 风险等级 | 说明 | Emoji |
|---------|------|-------|
| `critical` | 严重 | 🔴 |
| `high` | 高危 | 🟠 |
| `medium` | 中危 | 🟡 |
| `low` | 低危 | 🟢 |
| `info` | 信息 | 🔵 |

**示例**:
```bash
# 仅显示严重和高危问题
healthcheck --severity high

# 显示所有问题（包括低危和信息）
healthcheck --severity info
```

**默认值**: `medium`（显示中危及以上问题）

---

#### 5. 输出格式 | Output Format

```bash
--format <格式>        # 指定输出格式
```

| 格式 | 描述 | 适用场景 |
|------|------|---------|
| `terminal` | 终端格式（默认） | 交互式使用 |
| `markdown` | Markdown格式 | 文档生成 |
| `json` | JSON格式 | 自动化处理 |
| `html` | HTML报告 | 网页展示 |

**示例**:
```bash
healthcheck --format json        # 输出JSON格式
healthcheck --format markdown    # 输出Markdown格式
```

---

#### 6. 自动修复 | Auto-Fix

```bash
--fix                   # 交互式修复
--fix-auto              # 自动修复高危问题
```

**示例**:
```bash
# 交互式修复（每个问题都询问）
healthcheck --fix

# 自动修复所有高危问题
healthcheck --fix-auto --severity critical
```

**警告**: `--fix-auto` 会自动修复问题，请谨慎使用！

---

#### 7. 帮助信息 | Help

```bash
--help                  # 显示帮助信息
```

---

### 组合使用示例

**示例1：生产环境标准检查**
```bash
healthcheck --preset production --mode standard
```

**示例2：沙盒环境快速检查（跳过系统级检查）**
```bash
healthcheck --mode quick --exclude firewall,ssh,updates
```

**示例3：仅检查严重漏洞并自动修复**
```bash
healthcheck --severity critical --fix-auto
```

**示例4：开发环境宽松检查，输出JSON格式**
```bash
healthcheck --preset development --mode quick --format json
```

**示例5：排除特定检查项**
```bash
healthcheck --exclude malware,network --mode deep
```

---

## 📊 可视化安全报告 | Visual Security Report (v4.3.0+)

> 🎨 **清晰直观，一目了然**

### 报告结构

#### 1. 总体评分 | Overall Score

```
┌─────────────────────────────────────────┐
│   OpenClaw 安全状态报告 🛡️              │
├─────────────────────────────────────────┤
│   总体评分: 82/100 (良好) ⭐⭐⭐⭐        │
│   检查时间: 2026-04-01 19:39:21        │
│   环境: VPS (阿里云)                   │
│   检查模式: 标准                       │
└─────────────────────────────────────────┘
```

#### 2. 风险分布 | Risk Distribution

```
📊 风险等级分布:

🔴 严重 (Critical): 2  ████████░░░░░░░░░░  15%
🟠 高危 (High):      5  ██████████████░░░░  38%
🟡 中危 (Medium):    4  ████████████░░░░░░  31%
🟢 低危 (Low):       2  ████████░░░░░░░░░░  15%
🔵 信息 (Info):      0  ░░░░░░░░░░░░░░░░░░   0%

总计: 13 个问题
```

#### 3. 安全仪表盘 | Security Dashboard

```
┌─────────────────────────────────────────────────────┐
│  安全仪表盘                                          │
├─────────────────────────────────────────────────────┤
│  CVE漏洞      │ ██████████████░░  10/12 ✅         │
│  恶意技能      │ ████████████████  0/3  ✅         │
│  防火墙配置    │ ████████░░░░░░░░   4/6  ⚠️         │
│  SSH配置      │ ████████████░░░░   5/7  ⚠️         │
│  文件权限      │ ████████████████  8/8  ✅         │
│  网络暴露      │ ████████████████  2/2  ✅         │
│  系统更新      │ ████████████████  1/1  ✅         │
└─────────────────────────────────────────────────────┘
```

#### 4. 问题清单 | Issue List

**高优先级问题（优先修复）**:

```
🔴 [CRITICAL] CVE-2026-25253 检测到受影响版本
   ├─ 风险等级: 🔴 严重 (CVSS 9.8)
   ├─ 影响范围: OpenClaw < v4.1.0
   ├─ 修复建议: 立即升级到 v4.2.1+
   └─ 预计耗时: 5分钟
   ┌──────────────────────────────┐
   │  [1] 立即修复  [2] 查看详情  │
   └──────────────────────────────┘

🔴 [CRITICAL] SSH 允许 root 登录
   ├─ 风险等级: 🔴 严重
   ├─ 当前配置: PermitRootLogin yes
   ├─ 修复建议: 改为 PermitRootLogin no
   └─ 预计耗时: 2分钟
   ┌──────────────────────────────┐
   │  [1] 立即修复  [2] 查看详情  │
   └──────────────────────────────┘
```

**中优先级问题**:

```
🟠 [HIGH] 防火墙未启用
   ├─ 风险等级: 🟠 高危
   ├─ 当前状态: inactive
   ├─ 修复建议: 启用 ufw 并配置规则
   └─ 预计耗时: 5分钟

🟡 [MEDIUM] 系统未启用自动更新
   ├─ 风险等级: 🟡 中危
   ├─ 当前配置: disabled
   ├─ 修复建议: 启用 unattended-upgrades
   └─ 预计耗时: 3分钟
```

#### 5. 修复进度条 | Fix Progress

```
🔧 正在修复问题...

[████████████░░░░░░░] 60% (3/5)

✅ 已完成:
   • CVE-2026-25253 修复
   • SSH root 登录禁用
   • 防火墙启用

⏳ 进行中:
   • 自动更新配置...

⏸️ 待修复:
   • 文件权限调整
```

#### 6. 修复前后对比 | Before/After Comparison

```
📊 修复前后对比

┌────────────────────────────────────────────────────┐
│ 项目              │ 修复前  │ 修复后  │ 改进     │
├────────────────────────────────────────────────────┤
│ 总体评分          │ 65/100  │ 85/100  │ +20%     │
│ 🔴 严重问题       │ 3       │ 0       │ -100%    │
│ 🟠 高危问题       │ 7       │ 2       │ -71%     │
│ 🟡 中危问题       │ 5       │ 3       │ -40%     │
│ CVE漏洞          │ 10/12   │ 12/12   │ ✅       │
│ 恶意技能          │ 2/3     │ 0/3     │ ✅       │
└────────────────────────────────────────────────────┘
```

---

### 快速修复功能

#### 一键修复高危项

```bash
healthcheck --fix-auto --severity critical
```

**流程**:
1. 扫描检测高危问题
2. 显示待修复问题列表
3. 确认修复（可选）
4. 自动执行修复
5. 验证修复结果
6. 生成对比报告

**输出示例**:
```
🔧 自动修复高危问题

检测到 2 个高危问题:

1. CVE-2026-25253 检测到受影响版本
2. SSH 允许 root 登录

准备修复... [Ctrl+C 取消]

[████████████████] 修复完成

✅ 修复结果:
   • CVE-2026-25253: 已修复 (v4.1.0 → v4.2.1)
   • SSH root 登录: 已禁用

📊 修复前后对比:
   总体评分: 65/100 → 85/100 (+20%)
```

---

### 报告导出

```bash
# 导出为 Markdown
healthcheck --format markdown > security-report.md

# 导出为 JSON
healthcheck --format json > security-report.json

# 导出为 HTML
healthcheck --format html > security-report.html
```

---

