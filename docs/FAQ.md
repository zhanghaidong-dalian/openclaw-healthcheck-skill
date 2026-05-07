#========================================
# 常见问题 FAQ (v5.0.0)
#========================================

## 📚 目录

1. [基础问题](#1-基础问题)
2. [安装配置](#2-安装配置)
3. [安全检查](#3-安全检查)
4. [故障排查](#4-故障排查)
5. [高级功能](#5-高级功能)
6. [视频教程](#6-视频教程)

---

## 1. 基础问题

### Q1.1: 什么是 OpenClaw 安全检查技能？

**答**: OpenClaw 安全检查技能是一个全面的主机安全审计和加固工具，专门为 OpenClaw 环境设计。它可以：

- 检测配置错误和权限问题
- 扫描已知漏洞 (CVE)
- 提供自动化修复建议
- 生成安全报告

**适用版本**: v4.8.0+

---

### Q1.2: 这个技能支持哪些平台？

**答**: 支持以下平台：

| 平台 | 支持状态 | 功能完整度 |
|------|----------|------------|
| OpenClaw 本地 | ✅ 完全支持 | 100% |
| Coze 扣子 | ✅ 支持 | 90% |
| Dify | ✅ 支持 | 90% |
| 腾讯混元 | ✅ 支持 | 90% |
| 钉钉 | 🟡 开发中 | 70% |

**使用说明**: 
- Shell 模式: 需要 exec 权限的完整功能版本
- Agent 模式: 无 exec 权限的 Python 独立版本

---

### Q1.3: 需要 root 权限吗？

**答**: 不需要！

**不同检查模式**:

| 模式 | 权限要求 | 功能 |
|------|----------|------|
| 一键检查 | 无需 root | 快速安全扫描 |
| 完整审计 | 无需 root | 详细安全检查 |
| 自动修复 | 部分需要 sudo | 修复配置问题 |

**推荐流程**:
1. 先用一键检查（无需权限）
2. 发现问题后用完整审计
3. 修复时根据提示使用 sudo

---

### Q1.4: 如何快速开始？

**答**: 3 步快速开始：

**Step 1: 触发安全检查**
```
直接告诉 AI: "帮我检查 OpenClaw 安全"
```

**Step 2: 查看结果**
```
AI 会显示安全评分和发现的问题
```

**Step 3: 执行修复**
```
根据 AI 建议，选择要修复的项目
```

**视频教程**: [5分钟快速入门](#6-视频教程)

---

## 2. 安装配置

### Q2.1: 如何安装安全检查技能？

**答**: 两种安装方式：

**方式一: 虾评平台安装（推荐）**
```
1. 打开 https://xiaping.coze.site
2. 搜索 "安全检查"
3. 点击安装
```

**方式二: 手动安装**
```bash
# 下载技能包
wget https://github.com/zhanghaidong-dalian/openclaw-healthcheck-skill/releases/latest/download/healthcheck-v5.0.0.zip

# 解压到技能目录
unzip healthcheck-v5.0.0.zip -d /path/to/skills/
```

---

### Q2.2: 技能安装后如何验证？

**答**: 运行验证命令：

```bash
# 方式1: 使用一键检查
bash <技能路径>/scripts/quick-check.sh

# 方式2: Python 脚本验证
python3 <技能路径>/agent/quick-check-agent.py

# 方式3: AI 对话验证
直接告诉 AI: "检查 OpenClaw 安全状态"
```

**预期输出**:
```
🔒 OpenClaw 一键安全检查 v5.0.0
✅ OpenClaw已安装
✅ 配置目录权限正常
📊 安全评分: 95/100
🟢 状态: 安全
```

---

### Q2.3: 如何配置定时安全检查？

**答**: 三种配置方式：

**方式1: AI 对话配置**
```
告诉 AI: "每天早上8点检查一次安全"
```

**方式2: 手动配置 cron**
```bash
# 每天早上8点检查
openclaw cron add \
  --name "daily-security-check" \
  --schedule "0 8 * * *" \
  --command "openclaw security audit"

# 每周一检查
openclaw cron add \
  --name "weekly-security-check" \
  --schedule "0 9 * * 1" \
  --command "openclaw security audit --deep"
```

**方式3: 使用定时任务脚本**
```bash
bash <技能路径>/scripts/cron-manager.sh
```

---

## 3. 安全检查

### Q3.1: 一键检查和深度检查有什么区别？

**答**:

| 项目 | 一键检查 | 深度检查 |
|------|----------|----------|
| 执行时间 | ~10 秒 | ~60 秒 |
| 检查范围 | 基础配置 | 全面审计 |
| CVE 扫描 | ❌ | ✅ |
| 权限检查 | ✅ | ✅ |
| 网络扫描 | 基础 | 详细 |
| 报告输出 | 摘要 | 完整报告 |

**使用场景**:
- **一键检查**: 日常快速扫描
- **深度检查**: 首次检查或每周巡检

---

### Q3.2: 安全评分是怎么计算的？

**答**: 安全评分基于以下维度：

**评分体系 (0-100)**:

| 级别 | 分数 | 状态 | 说明 |
|------|------|------|------|
| A | 90-100 | 🟢 安全 | 优秀 |
| B | 80-89 | 🟢 安全 | 良好 |
| C | 70-79 | 🟡 注意 | 需关注 |
| D | 60-69 | 🟠 警告 | 需修复 |
| E | <60 | 🔴 危险 | 紧急修复 |

**扣分项**:
- 配置目录权限不当: -15
- 配置文件权限不当: -10
- 缺少日志目录: -5
- 未启用防火墙: -10
- SSH 配置不安全: -15
- 存在已知 CVE: -20

---

### Q3.3: 发现了高危问题怎么办？

**答**: 按以下步骤处理：

**Step 1: 查看详细报告**
```
AI 会显示具体的问题和风险等级
```

**Step 2: 了解修复方法**
```
AI 提供详细的修复指导
```

**Step 3: 执行修复**
```
选择自动修复或手动修复
```

**Step 4: 验证修复**
```
重新运行安全检查确认问题已解决
```

**紧急情况处理**:

| 风险等级 | 处理时间 | 建议操作 |
|----------|----------|----------|
| 🔴 Critical | 立即 | 立即修复 |
| 🟠 High | 24小时内 | 尽快修复 |
| 🟡 Medium | 1周内 | 计划修复 |
| 🟢 Low | 可延后 | 可选修复 |

---

### Q3.4: 如何生成完整的安全报告？

**答**: 多种报告格式：

**Markdown 报告**:
```bash
openclaw security audit --report markdown
```

**JSON 报告**:
```bash
openclaw security audit --report json
```

**HTML 报告**:
```bash
bash <技能路径>/scripts/reports/generate-report.sh --format html
```

**报告包含内容**:
- 📊 安全评分和趋势
- 🔴 高危问题列表
- ⚠️ 警告项详情
- ✅ 通过项确认
- 💡 修复建议

---

## 4. 故障排查

### Q4.1: 安全检查脚本报错 "Permission denied"

**答**: 这是正常的！

**原因**: 没有 root 权限时，某些系统级检查无法执行

**解决方案**:

1. **使用一键检查（推荐）**:
```bash
bash <技能路径>/scripts/quick-check.sh
```

2. **使用 Agent 模式**:
```bash
python3 <技能路径>/agent/quick-check-agent.py
```

3. **获取必要权限**:
```bash
sudo bash <技能路径>/scripts/quick-check.sh
```

---

### Q4.2: 提示 "OpenClaw 未安装"

**答**: 按以下步骤排查：

**Step 1: 检查 OpenClaw 是否安装**
```bash
which openclaw
openclaw --version
```

**Step 2: 如果未安装**
```bash
# 安装 OpenClaw
npm install -g openclaw

# 或使用官方安装脚本
curl -fsSL https://raw.githubusercontent.com/openclaw/openclaw/main/install.sh | bash
```

**Step 3: 验证安装**
```bash
openclaw status
```

---

### Q4.3: CVE 扫描失败或超时

**答**: 可能的解决方案：

**原因 1: 网络问题**
```bash
# 检查网络连接
ping nvd.nist.gov

# 设置代理（如需要）
export HTTPS_PROXY=http://proxy:8080
```

**原因 2: 使用离线缓存**
```bash
# 首次运行后，CVE 数据会缓存
# 查看缓存位置
ls ~/.openclaw/cve-cache/

# 手动更新缓存
bash <技能路径>/scripts/update-cve-cache.sh
```

**原因 3: 超时设置**
```bash
# 增加超时时间
openclaw security audit --timeout 120
```

---

### Q4.4: 自动修复失败

**答**: 故障排查步骤：

**Step 1: 查看详细日志**
```bash
cat /tmp/openclaw-auto-fix.log
```

**Step 2: 手动回滚**
```bash
# 查看备份
ls /tmp/openclaw-auto-fix/backups/

# 回滚到修复前
cp /tmp/openclaw-auto-fix/backups/<filename> <original>
```

**Step 3: 手动修复**
```bash
# 根据日志中的具体错误手动修复
# 或联系技术支持
```

---

### Q4.5: 定时任务不执行

**答**: 检查配置：

**Step 1: 查看定时任务列表**
```bash
openclaw cron list
```

**Step 2: 检查任务状态**
```bash
openclaw cron runs <job-id>
```

**Step 3: 测试手动执行**
```bash
openclaw cron run <job-id>
```

**常见问题**:
- 任务被禁用: `openclaw cron edit <id> --enable`
- 时间格式错误: 使用正确的 cron 表达式
- 权限不足: 确保 Gateway 有执行权限

---

## 5. 高级功能

### Q5.1: 如何启用实时威胁监控？

**答**: 使用实时监控脚本：

```bash
# 单次检查
python3 <技能路径>/agent/realtime-monitor.py --once

# 持续监控（每60秒）
python3 <技能路径>/agent/realtime-monitor.py --interval 60

# 导出报告
python3 <技能路径>/agent/realtime-monitor.py --export report.json
```

**监控内容**:
- 🔒 配置变更检测
- 📁 权限变更告警
- 🔍 异常进程监控
- 🌐 网络连接监控

---

### Q5.2: 如何自定义安全检查规则？

**答**: 创建自定义规则：

**Step 1: 创建规则文件**
```bash
mkdir -p ~/.openclaw/security-rules
vi ~/.openclaw/security-rules/custom-rules.yaml
```

**Step 2: 添加自定义规则**
```yaml
rules:
  - id: CUSTOM_001
    name: "检查自定义配置"
    check: |
      test -f ~/.openclaw/custom-config.yml
    severity: medium
    description: "自定义配置文件应存在"
```

**Step 3: 使用自定义规则**
```bash
openclaw security audit --rules ~/.openclaw/security-rules/custom-rules.yaml
```

---

### Q5.3: 如何集成飞书/企业微信通知？

**答**: 配置通知渠道：

**飞书配置**:
```bash
# 在 AI 对话中配置
"设置飞书通知，监控到高危问题时发送通知"
```

**企业微信配置**:
```bash
# 配置 webhook
export WECOM_WEBHOOK="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=xxx"

# 测试通知
bash <技能路径>/scripts/notifications/test-wecom.sh
```

---

### Q5.4: 如何备份和恢复安全配置？

**答**: 使用备份工具：

**创建备份**:
```bash
bash <技能路径>/scripts/backup-config.sh
```

**查看备份**:
```bash
ls ~/.openclaw/backups/
```

**恢复配置**:
```bash
bash <技能路径>/scripts/restore-config.sh <backup-file>
```

---

## 6. 视频教程

### 📺 官方视频教程

| 教程 | 时长 | 内容 |
|------|------|------|
| [5分钟快速入门](https://www.bilibili.com/video/BVxxx/) | 5分钟 | 基本使用 |
| [高级安全配置](https://www.bilibili.com/video/BVxxx/) | 15分钟 | 高级功能 |
| [定时任务配置](https://www.bilibili.com/video/BVxxx/) | 10分钟 | 自动化 |
| [故障排查指南](https://www.bilibili.com/video/BVxxx/) | 20分钟 | 问题解决 |

### 📖 图文教程

| 教程 | 链接 |
|------|------|
| 快速入门指南 | [点击查看](./docs/quick-start.md) |
| 高级配置教程 | [点击查看](./docs/advanced.md) |
| API 文档 | [点击查看](./docs/api.md) |
| 常见问题 | 本文档 |

### 🎓 学习路径

```
入门 → 进阶 → 专家
 ↓      ↓       ↓
基础   自动化   企业级
配置   监控     合规
```

---

## 💬 获取帮助

如果以上 FAQ 无法解决您的问题：

1. **查看完整文档**: [GitHub 文档](https://github.com/zhanghaidong-dalian/openclaw-healthcheck-skill)
2. **提交 Issue**: [GitHub Issues](https://github.com/zhanghaidong-dalian/openclaw-healthcheck-skill/issues)
3. **联系支持**: 在虾评平台评论或发消息

---

*最后更新: v5.0.0 | 2026-05-05*

---

## 7. SSH 安全专题 (v5.0.0 新增)

### Q7.1: SSH 安全评分偏低怎么办？

**答**: SSH 安全评分偏低通常是因为以下配置问题：

| 问题 | 影响 | 修复命令 |
|------|------|----------|
| 允许 root 登录 | 🔴 高危 | 使用 `scripts/fix-ssh-hardening.sh` |
| 使用密码认证 | 🔴 高危 | 配置 SSH 密钥后禁用密码 |
| 使用默认 22 端口 | 🟡 中危 | 修改 SSH 端口 |
| 未限制登录用户 | 🟡 中危 | 配置 AllowUsers |

**快速修复**:
```bash
# 一键检查 SSH 状态
bash scripts/fix-ssh-hardening.sh status

# 交互式修复
bash scripts/fix-ssh-hardening.sh fix
```

**详细指南**: 查看 [SSH_FIX_GUIDE.md](SSH_FIX_GUIDE.md)

---

### Q7.2: 如何安全地禁用 root 登录？

**答**: 禁用 root 登录前必须确保：

1. **已有普通用户可用**
```bash
# 检查普通用户
id username

# 创建新用户（如果没有）
sudo useradd -m -s /bin/bash username
sudo passwd username
```

2. **使用修复脚本**
```bash
bash scripts/fix-ssh-hardening.sh fix
# 选择 "禁用root登录" 选项
```

3. **验证修复**
```bash
# 测试普通用户登录
ssh username@server

# 测试 root 无法登录
ssh root@server
# 应该显示: Permission denied
```

**⚠️ 重要**: 不要直接编辑配置文件，先保留一个有效的 SSH 连接！

---

### Q7.3: 如何配置 SSH 密钥认证？

**答**: 按以下步骤配置：

**Step 1: 生成密钥对**
```bash
# 推荐 Ed25519 算法
ssh-keygen -t ed25519 -C "your-email@example.com"

# 或使用 RSA
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
```

**Step 2: 复制公钥到服务器**
```bash
ssh-copy-id username@server
```

**Step 3: 测试密钥登录**
```bash
ssh username@server
# 应该无需密码直接登录
```

**Step 4: 禁用密码认证（可选）**
```bash
bash scripts/fix-ssh-hardening.sh fix
# 选择 "禁用密码认证" 选项
```

---

### Q7.4: 忘记配置普通用户，现在无法登录怎么办？

**答**: 需要通过物理控制台或 VNC 恢复：

**方法 1: 使用控制台/VNC**
1. 登录服务器控制台（云平台 VNC 或物理键盘）
2. 恢复 SSH 配置：
```bash
sudo cp /etc/ssh/sshd_config.backup.XXX /etc/ssh/sshd_config
sudo systemctl restart sshd
```

**方法 2: 使用修复脚本恢复**
```bash
bash scripts/fix-ssh-hardening.sh restore
```

**方法 3: 单用户模式**
1. 重启系统
2. 在启动菜单选择 "Recovery Mode"
3. 进入 root shell
4. 修复 SSH 配置

**预防措施**: 始终在执行 SSH 修改前创建备份，并保持当前连接不断开。

---

### Q7.5: 检查显示 SSH 使用默认端口，需要修改吗？

**答**: 修改 SSH 端口有以下考虑：

**优点**:
- 减少自动化扫描攻击
- 降低日志中的暴力破解尝试
- 稍微增加攻击者发现难度

**缺点**:
- 需要记住非标准端口
- 某些防火墙可能需要额外配置
- 安全性提升有限（属于"隐藏式安全"）

**建议**:
- 如果服务器暴露在互联网：建议修改
- 如果在内网：可选修改
- 务必配合禁用密码认证使用

**修改命令**:
```bash
bash scripts/fix-ssh-hardening.sh fix
# 选择 "修改默认端口" 选项
# 建议使用 1024-65535 之间的高位端口
```

---

### Q7.6: SSH 配置更改后如何验证？

**答**: 使用以下方法验证：

**方法 1: 使用脚本验证**
```bash
# 查看当前状态
bash scripts/fix-ssh-hardening.sh status

# 验证配置语法
bash scripts/fix-ssh-hardening.sh test
```

**方法 2: 手动验证配置**
```bash
# 检查配置语法
sudo sshd -t

# 查看当前配置
sudo sshd -T | grep -E "permitrootlogin|passwordauthentication|port"
```

**方法 3: 实际登录测试**
```bash
# 测试密钥登录
ssh -o PasswordAuthentication=no username@server

# 测试 root 无法登录
ssh root@server
# 应该被拒绝
```

---

### Q7.7: 批量检查多台服务器的 SSH 配置？

**答**: 使用 v5.0.0 新增的批量检查功能：

**Step 1: 创建主机列表**
```bash
cat > hosts.txt << 'HOSTS'
# 服务器列表
user@server1.example.com
user@server2.example.com
192.168.1.100
192.168.1.101:2222
HOSTS
```

**Step 2: 执行批量检查**
```bash
# 检查所有主机
bash scripts/batch-scan.sh -f hosts.txt

# 并行检查（5个并发）
bash scripts/batch-scan.sh -f hosts.txt -p 5

# 仅显示汇总
bash scripts/batch-scan.sh -f hosts.txt -s
```

**Step 3: 查看报告**
```bash
# 查看汇总
ls reports/batch-scan-*/SUMMARY.md

# 查看单个主机详情
ls reports/batch-scan-*/*_server1_example_com.txt
```

---

**SSH 专题最后更新**: 2026-05-07  
**版本**: 5.0.0
