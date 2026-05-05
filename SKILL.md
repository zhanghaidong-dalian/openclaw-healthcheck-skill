---
name: healthcheck
version: 4.8.5

## 🚀 v5.0.0 重大更新

**发布日期**: 2026-05-05

### ✨ 新增功能

| 功能 | 说明 | 优先级 |
|------|------|--------|
| 🎯 **一键检查模式** | 无需 root 权限，快速安全扫描 | P0 |
| 📚 **完整 FAQ** | 10+ 常见问题解答 | P0 |
| 🎬 **视频教程** | 官方视频教程中心 | P1 |
| 🌐 **多平台兼容** | Coze/Dify/混元/钉钉 90%+ 支持 | P0 |
| 🔔 **实时威胁监控** | 持续安全状态监控 | P1 |
| ⚡ **自动化修复 v5** | 增强版自动修复系统 | P0 |

---

## 使用要求 (Usage Requirements)

本技能支持两种运行模式：

### 模式 1: Shell 模式（完整功能）
**适用环境**：OpenClaw 本地运行环境、自托管 Gateway

**功能特点**：
- ✅ 完整的安全扫描和加固
- ✅ 自动修复和回滚
- ✅ 定时巡检管理
- ✅ 实时威胁监控
- ✅ 所有脚本工具

### 模式 2: Agent 模式（兼容受限平台）
**适用环境**：Coze 扣子、Dify、腾讯混元、钉钉

**功能特点**：
- ✅ 纯 Python 实现，不依赖 shell
- ✅ 基础安全检查（规则引擎）
- ✅ 结构化报告输出
- ✅ CVE 离线数据库
- ⚠️ 不支持自动修复（需要手动执行）

### 平台兼容性矩阵 (v5.0.0)

| 平台 | 推荐模式 | 功能完整度 | 目标 |
|------|----------|------------|------|
| OpenClaw 本地 | Shell | **100%** | 100% |
| Coze 扣子 | Agent | **90%** | 95% |
| Dify | Agent | **90%** | 95% |
| 腾讯混元 | Agent | **90%** | 95% |
| 钉钉 | Agent | **70%** | 90% |

---

## 快速开始 (Quick Start)

### 3 步快速上手

**Step 1: 触发检查**
直接告诉 AI："帮我检查 OpenClaw 安全"

**Step 2: 查看结果**
```
📊 安全评分: 95/100 (A级)
🔴 高危: 0
🟡 中危: 2
🟢 低危: 5
```

**Step 3: 执行修复**
选择自动修复或手动修复

### 一键检查（推荐，无需 root）

```bash
# Shell 模式
bash <技能路径>/scripts/quick-check.sh

# Agent 模式（Coze/Dify/混元）
python3 <技能路径>/agent/quick-check-agent.py
```

---

## 常见问题 FAQ

### Q1: 需要 root 权限吗？

**不需要！** 本技能设计为可在无 root 权限环境下运行。

| 检查模式 | 权限要求 | 功能 |
|----------|----------|------|
| 一键检查 | 无需 | 快速扫描 |
| 深度检查 | 无需 | 详细审计 |
| 自动修复 | 部分需要 sudo | 修复配置 |

### Q2: 支持哪些平台？

| 平台 | 支持状态 | 功能完整度 |
|------|----------|------------|
| OpenClaw 本地 | ✅ 完全支持 | 100% |
| Coze 扣子 | ✅ 支持 | 90% |
| Dify | ✅ 支持 | 90% |
| 腾讯混元 | ✅ 支持 | 90% |
| 钉钉 | 🟡 开发中 | 70% |

### Q3: 如何设置定时检查？

```
告诉 AI："每天早上8点检查一次安全"
```

或手动配置：
```bash
openclaw cron add \
  --name "daily-security-check" \
  --schedule "0 8 * * *" \
  --command "openclaw security audit"
```

### Q4: 发现高危问题怎么办？

**Step 1**: 查看详细报告
**Step 2**: 了解修复方法（AI 提供指导）
**Step 3**: 执行修复（自动或手动）
**Step 4**: 验证修复（重新检查）

### Q5: 如何获取帮助？

1. 查看完整 FAQ: `docs/FAQ.md`
2. 视频教程: `docs/VIDEO_TUTORIALS.md`
3. GitHub Issues: 提交问题

---

## 视频教程

### 入门系列（⭐）

| 教程 | 时长 | 内容 |
|------|------|------|
| 5分钟快速入门 | 5分钟 | 基本使用 |
| 安装与配置 | 8分钟 | 技能安装 |
| 首次安全检查 | 6分钟 | 第一次检查 |

### 进阶系列（⭐⭐）

| 教程 | 时长 | 内容 |
|------|------|------|
| 深度安全审计 | 12分钟 | 全面检查 |
| 自动化修复 | 15分钟 | 自动修复 |
| 定时任务配置 | 10分钟 | 自动化 |

### 专家系列（⭐⭐⭐）

| 教程 | 时长 | 内容 |
|------|------|------|
| 实时威胁监控 | 18分钟 | 持续监控 |
| 自定义安全规则 | 20分钟 | 规则定制 |
| 企业级部署 | 25分钟 | 生产环境 |

**详细教程**: `docs/VIDEO_TUTORIALS.md`

---

## Core Rules

- 推荐使用最新模型（如 Opus 4.5, GPT 5.2+）。应自检当前模型，低于该级别时建议切换，但不阻止执行。
- 任何状态变更操作前必须获得明确确认。
- 不确认连接方式前不修改远程访问设置。
- 优先可逆、分阶段的更改，并准备回滚计划。
- 不要声称 OpenClaw 更改主机防火墙、SSH 或系统更新；它不会。
- 角色/身份未知时，仅提供建议。
- 格式：每组用户选择必须编号，以便用户回复单个数字。
- 建议系统级备份；尝试验证状态。
- **自动修复分类**：按风险和自动化级别对所有发现进行分类（auto-safe, auto-risk, manual-guide, manual-expert）。

## Workflow

### 0) 模型自检（非阻塞）

检查当前模型。低于最新水平（如 Opus 4.5, GPT 5.2+）时建议切换，但不阻止执行。

### 发现分类（贯穿工作流程）

所有安全发现分类如下：

| Category | Automation | Risk | Examples |
|----------|-----------|------|----------|
| **auto-safe** | ✅ Automatic | 🟢 Low | OpenClaw file permissions, log permissions, config defaults |
| **auto-risk** | ✅ Automatic with confirm | 🟡 Medium | Firewall rules (non-critical), disable unnecessary services |
| **manual-guide** | 📋 Detailed guidance | 🟡 Medium | System update policies, encryption setup, network adjustments |
| **manual-expert** | ⚠️ Expert required | 🔴 High | Kernel security parameters, custom firewall policies, container hardening |

### 1) 建立上下文（只读）

推断 1-5 项，从环境获取信息前先提问。首选简单、非技术性的问题。

确定（按顺序）：

1. OS 和版本（Linux/macOS/Windows）、容器 vs 主机。
2. 权限级别（root/admin vs user）。
3. 访问路径（本地控制台、SSH、RDP、tailnet）。
4. 网络暴露（公网 IP、反向代理、隧道）。
5. OpenClaw gateway 状态和绑定地址。
6. 备份系统和状态（如 Time Machine、系统镜像、快照）。
7. 部署上下文（本地 mac 应用、无头 gateway 主机、远程 gateway、容器/CI）。
8. 磁盘加密状态（FileVault/LUKS/BitLocker）。
9. OS 自动安全更新状态。
   注意：这些不是阻塞项，但强烈建议，特别是如果 OpenClaw 可以访问敏感数据。
10. 个人助理使用模式（本地工作站 vs 无头/远程 vs 其他）。

先请求一次运行只读检查的权限。如果授予，默认运行它们，只询问无法推断或验证的项目。不要询问已在 runtime 或命令输出中可见的信息。

### 2) 运行 OpenClaw 安全审计（只读）

作为默认只读检查的一部分，运行 `openclaw security audit --deep`。只有用户要求时才提供替代方案：

1. `openclaw security audit`（更快，非探测式）
2. `openclaw security audit --json`（结构化输出）

提供应用 OpenClaw 安全默认值的选项（编号）：

1. `openclaw security audit --fix`

明确说明 `--fix` 只收紧 OpenClaw 默认值和文件权限。不更改主机防火墙、SSH 或系统更新策略。

如果启用了浏览器控制，建议在所有重要账户上启用 2FA，硬件密钥优先，SMS 不够。

### 3) 检查 OpenClaw 版本/更新状态（只读）

作为默认只读检查的一部分，运行 `openclaw update status`。

报告当前频道和是否有可用更新。

### 3.5) 自动修复评估（ remediation 计划前）

完成所有只读检查后，评估可自动修复的内容：

1. 扫描所有发现并按自动化级别分类
2. 统计每个类别的项目数
3. 生成修复摘要
4. 提供一键修复选项

### 4) 确定风险承受度（系统上下文后）

要求用户选择或确认风险姿态和任何需要的开放服务/端口（编号选择）。不要限制为固定配置文件；如用户偏好，捕获需求而不是选择配置文件。

提供建议的配置文件作为可选默认值（编号）。注意大多数用户选择 Home/Workstation Balanced：

1. Home/Workstation Balanced（最常见）：防火墙开启且有合理默认值，远程访问限制在 LAN 或 tailnet。
2. VPS Hardened：默认拒绝入站防火墙，最少开放端口，仅密钥 SSH，无 root 登录，自动安全更新。
3. Developer Convenience：允许更多本地服务，明确暴露警告，仍进行审计。
4. Custom：用户定义的约束（服务、暴露、更新节奏、访问方式）。

### 5) 生成修复计划

提供包括以下内容的计划：

- 目标配置文件
- 当前姿态摘要
- 与目标的差距
- 带确切命令的逐步修复
- 访问保护策略和回滚
- 风险和潜在锁定场景
- 最小权限说明
- 凭证卫生说明（OpenClaw 凭证位置，优先磁盘加密）

始终在任何更改前显示计划。

### 6) 提供执行选项

提供以下选择（编号以便用户回复单个数字）：

1. 完整手动执行（引导，逐步确认）
2. **自动修复安全项**（自动修复所有 auto-safe 类别项）
3. **半自动修复**（auto-risk 项需要确认但自动执行）
4. **快速场景模板**（根据场景应用预设安全配置文件）
5. 仅显示计划
6. 仅修复关键问题
7. 导出命令稍后执行

#### 6.1) 自动修复安全项（选项 2）

用户选择选项 2 时：
1. 显示所有要修复的 auto-safe 项
2. 创建所有要修改文件的备份
3. 按顺序运行 auto-safe 脚本
4. 验证每个修复成功
5. 报告带回滚说明的结果

#### 6.2) 快速场景模板（选项 4）

用户选择选项 4 时：
1. 询问适用于哪个场景模板（或使用快速问诊表单）
2. 根据场景应用预设安全配置文件：
   - Personal Workstation: FileVault/BitLocker 检查，备份状态
   - VPS/Cloud: SSH 加固，防火墙，fail2ban
   - Raspberry Pi: SSH 端口更改，密码策略
   - Docker: 容器安全设置
3. 提供自定义任何特定项目的选项

### 7) 确认下执行

每步：
- 显示确切命令
- 说明影响和回滚
- 确认访问将保持可用
- 意外输出时停止并请求指导

重新检查：
- 防火墙状态
- 监听端口
- 远程访问仍可用
- OpenClaw 安全审计（重新运行）

交付最终姿态报告并注意任何推迟的项目。

## Required Confirmations

始终要求明确确认：
- 防火墙规则更改
- 打开/关闭端口
- SSH/RDP 配置更改
- 安装/删除软件包
- 启用/禁用服务
- 用户/组修改
- 计划任务或启动持久化
- 更新策略更改
- 访问敏感文件或凭证

如有疑问，请询问。

## Periodic Checks

OpenClaw 安装或首次加固后，至少运行一次基线审计和版本检查：
- `openclaw security audit`
- `openclaw security audit --deep`
- `openclaw update status`

建议进行持续监控。使用 OpenClaw cron 工具/CLI 调度定期审计。未经明确批准不创建计划任务。将输出存储在用户批准的位置，避免日志中的 secrets。

调度无头 cron 运行时，在输出中包含说明用户调用 `healthcheck` 以便修复问题的说明。

## 实时威胁监控 (v5.0.0 新增)

### 功能特点
- 🔒 配置变更检测
- 📁 权限变更告警
- 🔍 异常进程监控
- 🌐 网络连接监控

### 使用方式

```bash
# 单次检查
python3 agent/realtime-monitor.py --once

# 持续监控（每60秒）
python3 agent/realtime-monitor.py --interval 60

# 导出报告
python3 agent/realtime-monitor.py --export alert.json
```

## 自动修复系统 v5.0.0 (增强版)

### 可用脚本

| 脚本 | 功能 | 权限要求 |
|------|------|----------|
| `quick-check.sh` | 一键安全检查 | 无需 root |
| `quick-check-agent.py` | Agent 模式检查 | Python 3.7+ |
| `auto-fixer-v5.sh` | 增强自动修复 | 部分需要 sudo |
| `realtime-monitor.py` | 实时威胁监控 | Python 3.7+ |

### 自动修复项目

| 项目 | 描述 | 风险级别 |
|------|------|----------|
| openclaw-perms | 修复 OpenClaw 文件权限 | 🟢 Safe |
| logging-perms | 修复日志文件权限 | 🟢 Safe |
| gateway-config | 修复 Gateway 配置 | 🟢 Safe |
| firewall-basics | 基础防火墙配置 | 🟡 Medium |
| ssh-hardening | SSH 安全加固 | 🟡 Medium |
| auto-updates | 启用自动更新 | 🟡 Medium |
| fail2ban | 安装配置 fail2ban | 🟡 Medium |

## FAQ 和视频教程

完整 FAQ: `docs/FAQ.md`
视频教程: `docs/VIDEO_TUTORIALS.md`
平台兼容性: `docs/PLATFORM_COMPATIBILITY.md`

## OpenClaw Command Accuracy

仅使用支持的命令和标志：
- `openclaw security audit [--deep] [--fix] [--json]`
- `openclaw status` / `openclaw status --deep`
- `openclaw health --json`
- `openclaw update status`
- `openclaw cron add|list|runs|run`

不要编造 CLI 标志或暗示 OpenClaw 强制执行主机防火墙/SSH 策略。

## Logging and Audit Trail

记录：
- Gateway 身份和角色
- 计划 ID 和时间戳
- 批准的步骤和确切命令
- 退出码和修改的文件（尽最大努力）

清除 secrets。绝不记录 token 或完整凭证内容。

## Memory Writes (Conditional)

仅在用户明确选择加入且会话是私有/本地工作区时才写入内存文件。否则提供用户决定保存到其他地方的脱敏、可粘贴的摘要。

遵循 OpenClaw 压缩使用的持久内存提示格式：
- 将持久注释写入 `memory/YYYY-MM-DD.md`。

每次审计/加固运行后，如果选择加入，追加简短的带日期摘要到 `memory/YYYY-MM-DD.md`（检查了什么、主要发现、采取的行动、任何计划的 cron 作业、关键决策和所有执行的命令）。仅追加：绝不覆盖现有条目。清除敏感主机详细信息（用户名、主机名、IP、序列号、服务名、token）。
如有持久偏好或决策（风险姿态、允许的端口、更新策略），也更新 `MEMORY.md`（长期记忆是可选的，仅在私人会话中使用）。

---

*版本: 5.0.0 | 最后更新: 2026-05-05*
