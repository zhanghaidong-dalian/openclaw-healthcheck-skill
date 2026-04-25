---
name: healthcheck
---

## Quick Intake Form (快速问诊表单) - v4.8.0 新增

如果用户没有提供足够的上下文，使用以下 5 问表单快速收集信息：

**请依次回答以下 5 个问题（回复数字即可）：**

**Q1: 你使用的是什么设备/系统？**
1. Mac (macOS)
2. Windows PC
3. Linux 服务器/VPS
4. 树莓派 (Raspberry Pi)
5. Docker 容器
6. 其他

**Q2: 你在哪里使用这台设备？**
1. 本地个人电脑（只有我能接触到）
2. 家里/办公室网络（家人/同事可能访问）
3. 公网可访问的服务器（任何人可能尝试连接）

**Q3: 你如何连接这台设备？**
1. 直接坐在电脑前操作
2. SSH 远程连接
3. 内网穿透/FRP/Tailscale 等工具访问
4. 多种方式都在用

**Q4: 这台设备上运行了什么服务？**
1. 只有 OpenClaw Gateway
2. OpenClaw + 网站/博客
3. OpenClaw + 数据库/文件存储
4. OpenClaw + 多个服务

**Q5: 你希望多久检查一次安全？**
1. 只需要一次性检查
2. 每周检查一次
3. 每天检查一次
4. 我不确定，你来推荐

---

# OpenClaw Host Hardening

## Overview

Assess and harden the host running OpenClaw, then align it to a user-defined risk tolerance without breaking access. Use OpenClaw security tooling as a first-class signal, but treat OS hardening as a separate, explicit set of steps.

## Scene Templates (场景模板) - v4.8.0 新增

根据不同使用场景，预设不同的安全配置优先级：

### 场景 1: 个人工作站 (Personal Workstation)
**适用**: 本地 Mac/Windows PC，只有你能接触到

**安全优先级**:
- 🟢 基础: OpenClaw 文件权限、日志安全
- 🟢 基础: 磁盘加密检查 (FileVault/BitLocker)
- 🟡 标准: 防火墙启用（允许指定应用）
- 🟡 标准: 自动化备份验证
- 🔴 可选: 浏览器 2FA 推荐

**预设检查项**:
```bash
# 必检
openclaw security audit
openclaw status

# 可选
diskutil apfs list # macOS 磁盘加密状态
```

**加固命令示例**:
```bash
# macOS 启用 FileVault
sudo fdesetup enable

# Windows 启用 BitLocker
manage-bde -on C:
```

---

### 场景 2: VPS/云服务器 (VPS/Cloud Server)
**适用**: 公网可访问的 Linux 服务器，运行网站或 API

**安全优先级**:
- 🟢 基础: SSH 密钥登录 + 禁止密码
- 🟢 基础: 防火墙只开放必要端口
- 🟡 标准: 自动化安全更新
- 🟡 标准: fail2ban 防暴力破解
- 🔴 高危: 禁止 root 登录
- 🔴 高危: 定期漏洞扫描

**预设检查项**:
```bash
# 必检
openclaw security audit --deep
ss -ltnp  # 监听端口检查
ufw status  # 防火墙状态
cat /etc/ssh/sshd_config | grep -E "PermitRootLogin|PasswordAuthentication"
```

**加固命令示例**:
```bash
# SSH 密钥登录
ssh-copy-id user@server

# 禁用密码登录
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# UFW 防火墙
sudo ufw default deny incoming
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# fail2ban
sudo apt install fail2ban
sudo systemctl enable fail2ban
```

---

### 场景 3: 树莓派/物联网设备 (Raspberry Pi/IoT)
**适用**: 家庭网络中的小型设备，运行 Home Assistant 等

**安全优先级**:
- 🟢 基础: 修改默认 SSH 端口
- 🟢 基础: 强密码策略
- 🟡 标准: 网络隔离 (VLAN/子网)
- 🟡 标准: 定期更新 Raspbian/Debian
- 🔴 高危: 禁用 X11 转发（如果不用）

**预设检查项**:
```bash
# 必检
openclaw security audit
cat /etc/ssh/sshd_config | grep Port  # SSH 端口
passwd -S  # 用户密码状态
```

**加固命令示例**:
```bash
# 修改 SSH 端口
sudo sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# 强密码策略
sudo apt install libpam-pwquality
sudo vi /etc/security/pwquality.conf
# minlen = 12, dcredit = -1, ucredit = -1, lcredit = -1, ocredit = -1

# 自动更新
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades
```

---

### 场景 4: Docker 容器环境
**适用**: 在 Docker 中运行 OpenClaw

**安全优先级**:
- 🟢 基础: 非 root 用户运行容器
- 🟢 基础: 限制容器 capabilities
- 🟡 标准: 资源限制 (CPU/内存)
- 🟡 标准: 只读根文件系统
- 🔴 高危: 禁止 privileged 模式

**预设检查项**:
```bash
# 必检
docker ps | grep openclaw
docker inspect <container_id> | grep -E 'User|Privileged|CapAdd'
```

**加固命令示例**:
```bash
# 安全运行 OpenClaw
docker run -d \
  --name openclaw \
  --user 1000:1000 \
  --read-only \
  --memory="512m" \
  --cpus="1" \
  --cap-drop ALL \
  -v /path/to/config:/app/config \
  openclaw/openclaw:latest
```

---


## Core rules

- Recommend running this skill with a state-of-the-art model (e.g., Opus 4.5, GPT 5.2+). The agent should self-check the current model and suggest switching if below that level; do not block execution.
- Require explicit approval before any state-changing action.
- Do not modify remote access settings without confirming how the user connects.
- Prefer reversible, staged changes with a rollback plan.
- Never claim OpenClaw changes the host firewall, SSH, or OS updates; it does not.
- If role/identity is unknown, provide recommendations only.
- Formatting: every set of user choices must be numbered so the user can reply with a single digit.
- System-level backups are recommended; try to verify status.
- **Auto-fix categorization**: Classify all findings by risk and automation level (auto-safe, auto-risk, manual-guide, manual-expert).

## Workflow (follow in order)

### 0) Model self-check (non-blocking)

Before starting, check the current model. If it is below state-of-the-art (e.g., Opus 4.5, GPT 5.2+), recommend switching. Do not block execution.

### Finding categorization (used throughout workflow)

All security findings are categorized as:

| Category | Automation | Risk | Examples |
|----------|-----------|------|----------|
| **auto-safe** | ✅ Automatic | 🟢 Low | OpenClaw file permissions, log permissions, config defaults |
| **auto-risk** | ✅ Automatic with confirm | 🟡 Medium | Firewall rules (non-critical), disable unnecessary services |
| **manual-guide** | 📋 Detailed guidance | 🟡 Medium | System update policies, encryption setup, network adjustments |
| **manual-expert** | ⚠️ Expert required | 🔴 High | Kernel security parameters, custom firewall policies, container hardening |

### 1) Establish context (read-only)

Try to infer 1–5 from the environment before asking. Prefer simple, non-technical questions if you need confirmation.

Determine (in order):

1. OS and version (Linux/macOS/Windows), container vs host.
2. Privilege level (root/admin vs user).
3. Access path (local console, SSH, RDP, tailnet).
4. Network exposure (public IP, reverse proxy, tunnel).
5. OpenClaw gateway status and bind address.
6. Backup system and status (e.g., Time Machine, system images, snapshots).
7. Deployment context (local mac app, headless gateway host, remote gateway, container/CI).
8. Disk encryption status (FileVault/LUKS/BitLocker).
9. OS automatic security updates status.
   Note: these are not blocking items, but are highly recommended, especially if OpenClaw can access sensitive data.
10. Usage mode for a personal assistant with full access (local workstation vs headless/remote vs other).

First ask once for permission to run read-only checks. If granted, run them by default and only ask questions for items you cannot infer or verify. Do not ask for information already visible in runtime or command output. Keep the permission ask as a single sentence, and list follow-up info needed as an unordered list (not numbered) unless you are presenting selectable choices.

If you must ask, use non-technical prompts:

- “Are you using a Mac, Windows PC, or Linux?”
- “Are you logged in directly on the machine, or connecting from another computer?”
- “Is this machine reachable from the public internet, or only on your home/network?”
- “Do you have backups enabled (e.g., Time Machine), and are they current?”
- “Is disk encryption turned on (FileVault/BitLocker/LUKS)?”
- “Are automatic security updates enabled?”
- “How do you use this machine?”
  Examples:
  - Personal machine shared with the assistant
  - Dedicated local machine for the assistant
  - Dedicated remote machine/server accessed remotely (always on)
  - Something else?

Only ask for the risk profile after system context is known.

If the user grants read-only permission, run the OS-appropriate checks by default. If not, offer them (numbered). Examples:

1. OS: `uname -a`, `sw_vers`, `cat /etc/os-release`.
2. Listening ports:
   - Linux: `ss -ltnup` (or `ss -ltnp` if `-u` unsupported).
   - macOS: `lsof -nP -iTCP -sTCP:LISTEN`.
3. Firewall status:
   - Linux: `ufw status`, `firewall-cmd --state`, `nft list ruleset` (pick what is installed).
   - macOS: `/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate` and `pfctl -s info`.
4. Backups (macOS): `tmutil status` (if Time Machine is used).

### 2) Run OpenClaw security audits (read-only)

As part of the default read-only checks, run `openclaw security audit --deep`. Only offer alternatives if the user requests them:

1. `openclaw security audit` (faster, non-probing)
2. `openclaw security audit --json` (structured output)

Offer to apply OpenClaw safe defaults (numbered):

1. `openclaw security audit --fix`

Be explicit that `--fix` only tightens OpenClaw defaults and file permissions. It does not change host firewall, SSH, or OS update policies.

If browser control is enabled, recommend that 2FA be enabled on all important accounts, with hardware keys preferred and SMS not sufficient.

### 3) Check OpenClaw version/update status (read-only)

As part of the default read-only checks, run `openclaw update status`.

Report the current channel and whether an update is available.

### 3.5) Automated fix assessment (before remediation plan)

After completing all read-only checks, assess what can be automatically fixed:

1. Scan all findings and categorize by automation level
2. Count items in each category
3. Generate fix summary:
   ```
   📊 Auto-fix Assessment:
   ✅ auto-safe: 3 items (ready to fix automatically)
   ⚠️  auto-risk: 2 items (can fix with confirmation)
   📋 manual-guide: 4 items (detailed guidance available)
   🔴 manual-expert: 1 item (requires expert attention)
   ```
4. Offer one-click fix option (see step 6.1)

### 4) Determine risk tolerance (after system context)

Ask the user to pick or confirm a risk posture and any required open services/ports (numbered choices below).
Do not pigeonhole into fixed profiles; if the user prefers, capture requirements instead of choosing a profile.
Offer suggested profiles as optional defaults (numbered). Note that most users pick Home/Workstation Balanced:

1. Home/Workstation Balanced (most common): firewall on with reasonable defaults, remote access restricted to LAN or tailnet.
2. VPS Hardened: deny-by-default inbound firewall, minimal open ports, key-only SSH, no root login, automatic security updates.
3. Developer Convenience: more local services allowed, explicit exposure warnings, still audited.
4. Custom: user-defined constraints (services, exposure, update cadence, access methods).

### 5) Produce a remediation plan

Provide a plan that includes:

- Target profile
- Current posture summary
- Gaps vs target
- Step-by-step remediation with exact commands
- Access-preservation strategy and rollback
- Risks and potential lockout scenarios
- Least-privilege notes (e.g., avoid admin usage, tighten ownership/permissions where safe)
- Credential hygiene notes (location of OpenClaw creds, prefer disk encryption)

Always show the plan before any changes.

### 6) Offer execution options (enhanced)

Offer one of these choices (numbered so users can reply with a single digit):

1. Full manual execution (guided, step-by-step approvals)
2. **Auto-fix safe items only** (fixes all auto-safe category items automatically)
3. **Semi-automatic fix** (auto-risk items require confirmation but execute automatically)
4. **Quick scene template** (apply preset security profile based on your scenario)
5. Show plan only
6. Fix only critical issues
7. Export commands for later

#### 6.1) Auto-fix safe items (option 2)

When user selects option 2:
1. Display all auto-safe items to be fixed
2. Create backup of all files to be modified
3. Run auto-safe scripts in sequence
4. Verify each fix succeeded
5. Report results with rollback instructions

**Enhanced auto-fix capabilities (v4.8.0)**:

| Script | What it fixes | Risk Level |
|--------|--------------|------------|
| `fix-openclaw-perms.sh` | File/directory permissions | 🟢 Safe |
| `fix-logging-perms.sh` | Log file permissions | 🟢 Safe |
| `fix-firewall-defaults.sh` | Basic firewall rules | 🟡 Medium |
| `fix-ssh-hardening.sh` | SSH security settings | 🟡 Medium |
| `fix-auto-updates.sh` | Enable automatic updates | 🟡 Medium |

#### 6.2) Quick scene template (option 4)

When user selects option 4:
1. Ask which scene template applies (or use quick intake form)
2. Apply preset security profile based on scene:
   - Personal Workstation: FileVault/BitLocker check, backup status
   - VPS/Cloud: SSH hardening, firewall, fail2ban
   - Raspberry Pi: SSH port change, password policy
   - Docker: Container security settings
3. Offer to customize any specific items

**Scene template workflow**:

Auto-safe scripts characteristics:
- Always create backup before modification
- Use non-destructive operations
- Provide rollback instructions in output
- Generate logs in `/tmp/openclaw-*.log`
- Exit on error with clear message

### 7) Execute with confirmations

For each step:

- Show the exact command
- Explain impact and rollback
- Confirm access will remain available
- Stop on unexpected output and ask for guidance


Re-check:

- Firewall status
- Listening ports
- Remote access still works
- OpenClaw security audit (re-run)

Deliver a final posture report and note any deferred items.

## Required confirmations (always)

Require explicit approval for:

- Firewall rule changes
- Opening/closing ports
- SSH/RDP configuration changes
- Installing/removing packages
- Enabling/disabling services
- User/group modifications
- Scheduling tasks or startup persistence
- Update policy changes
- Access to sensitive files or credentials

If unsure, ask.

## Periodic checks

After OpenClaw install or first hardening pass, run at least one baseline audit and version check:

- `openclaw security audit`
- `openclaw security audit --deep`
- `openclaw update status`

Ongoing monitoring is recommended. Use the OpenClaw cron tool/CLI to schedule periodic audits (Gateway scheduler). Do not create scheduled tasks without explicit approval. Store outputs in a user-approved location and avoid secrets in logs.
When scheduling headless cron runs, include a note in the output that instructs the user to call `healthcheck` so issues can be fixed.

### Required prompt to schedule (always)

After any audit or hardening pass, explicitly offer scheduling and require a direct response. Use a short prompt like (numbered):

1. “Do you want me to schedule periodic audits (e.g., daily/weekly) via `openclaw cron add`?”

If the user says yes, ask for:

- cadence (daily/weekly), preferred time window, and output location
- whether to also schedule `openclaw update status`

Use a stable cron job name so updates are deterministic. Prefer exact names:

- `healthcheck:security-audit`
- `healthcheck:update-status`

Before creating, `openclaw cron list` and match on exact `name`. If found, `openclaw cron edit <id> ...`.
If not found, `openclaw cron add --name <name> ...`.

Also offer a periodic version check so the user can decide when to update (numbered):

1. `openclaw update status` (preferred for source checkouts and channels)
2. `npm view openclaw version` (published npm version)

## OpenClaw command accuracy

Use only supported commands and flags:

- `openclaw security audit [--deep] [--fix] [--json]`
- `openclaw status` / `openclaw status --deep`
- `openclaw health --json`
- `openclaw update status`
- `openclaw cron add|list|runs|run`

Do not invent CLI flags or imply OpenClaw enforces host firewall/SSH policies.

## Logging and audit trail

Record:

- Gateway identity and role
- Plan ID and timestamp
- Approved steps and exact commands
- Exit codes and files modified (best effort)

Redact secrets. Never log tokens or full credential contents.

## Memory writes (conditional)

Only write to memory files when the user explicitly opts in and the session is a private/local workspace
(per `docs/reference/templates/AGENTS.md`). Otherwise provide a redacted, paste-ready summary the user can
decide to save elsewhere.

Follow the durable-memory prompt format used by OpenClaw compaction:

- Write lasting notes to `memory/YYYY-MM-DD.md`.

After each audit/hardening run, if opted-in, append a short, dated summary to `memory/YYYY-MM-DD.md`
(what was checked, key findings, actions taken, any scheduled cron jobs, key decisions,
and all commands executed). Append-only: never overwrite existing entries.
Redact sensitive host details (usernames, hostnames, IPs, serials, service names, tokens).
If there are durable preferences or decisions (risk posture, allowed ports, update policy),
also update `MEMORY.md` (long-term memory is optional and only used in private sessions).

If the session cannot write to the workspace, ask for permission or provide exact entries
the user can paste into the memory files.

## Auto-fix scripts (Phase 1 - v4.8.0+)

### Available auto-safe scripts

The following scripts are available for automatic safe fixes:

#### fix-openclaw-perms.sh
- **Category**: auto-safe
- **Purpose**: Fix OpenClaw file and directory permissions
- **Fixes**:
  - `/root/.openclaw` → 700
  - `/var/log/openclaw` → 750
  - `/var/lib/openclaw` → 750
  - `/root/.openclaw/gateway.yml` → 600
  - OpenClaw binary → 755
- **Backup**: `/tmp/openclaw-perms-backup-YYYYMMDD-HHMMSS/`
- **Log**: `/tmp/openclaw-perms-fix.log`

#### fix-logging-perms.sh
- **Category**: auto-safe
- **Purpose**: Fix OpenClaw logging file permissions
- **Fixes**:
  - All log directories in `/var/log/openclaw/` → 750
  - All `.log` files → 640
  - Supervisor log files → 640
  - Creates `/etc/logrotate.d/openclaw` if missing
- **Backup**: `/tmp/openclaw-logging-backup-YYYYMMDD-HHMMSS/`
- **Log**: `/tmp/openclaw-logging-fix.log`

### Running scripts manually

```bash
# Run with sudo
sudo bash /usr/lib/node_modules/openclaw/skills/healthcheck/scripts/auto-safe/fix-openclaw-perms.sh
sudo bash /usr/lib/node_modules/openclaw/skills/healthcheck/scripts/auto-safe/fix-logging-perms.sh

# Check logs
tail -f /tmp/openclaw-*.log

# Restore from backup if needed
cp -r /tmp/openclaw-*-backup-*/* /
```

### Adding new auto-safe scripts

When creating new auto-safe scripts:
1. Place in `scripts/auto-safe/` directory
2. Follow naming convention: `fix-{description}.sh`
3. Include:
   - Backup mechanism with timestamp
   - Colored output (RED/GREEN/YELLOW)
   - Logging to `/tmp/openclaw-*.log`
   - Exit on error with clear message
   - Rollback instructions in output
4. Test thoroughly before use
5. Document in this section

## External Tools Integration (Phase 3 - v4.8.2+)

### Available integrations

#### 1. fail2ban Integration

**Purpose**: Intrusion prevention and brute-force protection

**Scripts**:
- `scripts/integrations/fail2ban-integrate.sh`

**Features**:
- Automatic installation and configuration
- OpenClaw-specific jail configurations
- SSH, Gateway, and API protection
- Automatic IP banning

**Usage**:
```bash
# Install and configure fail2ban
sudo bash scripts/integrations/fail2ban-integrate.sh

# Check status
sudo fail2ban-client status openclaw-ssh
sudo fail2ban-client status openclaw-gateway

# View banned IPs
sudo fail2ban-client banned openclaw-ssh

# Unban IP
sudo fail2ban-client set openclaw-ssh unbanip <IP>
```

**Configuration files**:
- `/etc/fail2ban/jail.d/openclaw.conf`
- `/etc/fail2ban/filter.d/openclaw-ssh.conf`
- `/etc/fail2ban/filter.d/openclaw-gateway.conf`
- `/etc/fail2ban/filter.d/openclaw-api.conf`

#### 2. Lynis Integration

**Purpose**: System-level security auditing

**Scripts**:
- `scripts/integrations/lynis-integrate.sh`

**Features**:
- Comprehensive system audit
- Hardening index calculation
- Security recommendations
- Compliance checking

**Usage**:
```bash
# Install Lynis and run audit
sudo bash scripts/integrations/lynis-integrate.sh

# View report
cat /tmp/lynis-report.dat

# Check hardening index
grep "hardening_index=" /tmp/lynis-report.dat

# Run standalone audit
lynis audit system
```

**Audit coverage**:
- Boot and services
- Kernel
- Memory and processes
- Users and groups
- File systems
- Networking
- Web services
- SSH
- Databases
- Logging
- Security services

#### 3. Report Generator

**Purpose**: Generate standardized security reports

**Scripts**:
- `scripts/reports/generate-report.sh`

**Output formats**:
- JSON (machine-readable)
- Markdown (human-readable)
- HTML (visual reports)

**Usage**:
```bash
# Generate all report formats
bash scripts/reports/generate-report.sh

# Reports location
ls -lh /tmp/openclaw-reports/

# View specific format
cat /tmp/openclaw-reports/security-audit-json.json
cat /tmp/openclaw-reports/security-audit-markdown.md
firefox /tmp/openclaw-reports/security-audit-html.html
```

### Integration best practices

1. **Layered security**: Use all integrations for comprehensive protection
   - OpenClaw healthcheck: Application security
   - fail2ban: Network layer protection
   - Lynis: System-level audit

2. **Regular auditing**: Schedule periodic checks
   - Daily: OpenClaw quick audit
   - Weekly: fail2ban status check
   - Monthly: Lynis full system audit

3. **Report automation**: Generate reports regularly
   - Use cron to automate report generation
   - Store reports in secure location
   - Review reports weekly

4. **Alert configuration**: Set up notifications
   - fail2ban: Email alerts for bans
   - Lynis: Critical warnings
   - OpenClaw: Security audit failures

### Dependencies

| Tool | Required | Auto-install |
|------|----------|---------------|
| openclaw | Yes | Built-in |
| fail2ban | No | Yes |
| lynis | No | Yes |
| bash | Yes | Built-in |
