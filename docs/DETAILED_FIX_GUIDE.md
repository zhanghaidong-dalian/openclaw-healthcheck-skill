# 详细修复指南

本文档提供所有安全问题的详细修复指导。

## SSH安全配置

### SSH-001: 禁止密码登录

**修复步骤**:

```bash
# 1. 确保已配置SSH密钥登录
ssh-copy-id user@your-server

# 2. 编辑SSH配置
sudo vi /etc/ssh/sshd_config
# 修改: PasswordAuthentication no

# 3. 重启SSH
sudo systemctl restart sshd
```

**验证**:

```bash
grep "^PasswordAuthentication" /etc/ssh/sshd_config
# 应该显示: PasswordAuthentication no
```

---

### SSH-002: 禁止root登录

```bash
sudo vi /etc/ssh/sshd_config
# 修改: PermitRootLogin no
sudo systemctl restart sshd
```

---

## 防火墙配置

### Firewall-001: 启用UFW

```bash
# 安装
sudo apt-get update && sudo apt-get install ufw

# 配置默认策略
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 允许SSH
sudo ufw allow ssh

# 启用
sudo ufw enable
```

⚠️ **重要**: 启用防火墙前必须先允许SSH，否则会失去访问！

---

## Fail2ban防暴力破解

### 安装Fail2ban

```bash
sudo apt-get install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### SSH防护配置

```bash
sudo vi /etc/fail2ban/jail.local

[sshd]
enabled = true
port = ssh
maxretry = 3
bantime = 3600

sudo systemctl restart fail2ban
```

---

## 一键自动修复

使用 `one-click-fixer.sh` 脚本:

```bash
# 查看所有可修复问题
bash scripts/one-click-fixer.sh --list

# 自动修复所有问题
bash scripts/one-click-fixer.sh --auto

# 仅显示将要执行的修复
bash scripts/one-click-fixer.sh --dry-run

# 修复指定问题
bash scripts/one-click-fixer.sh --fix ssh-001
```

---

## 回滚指南

所有修复前都会自动备份到 `/tmp/healthcheck-backups/`

```bash
# 恢复SSH配置
sudo cp /tmp/healthcheck-backups/*/sshd_config.bak /etc/ssh/sshd_config
sudo systemctl restart sshd

# 恢复防火墙
sudo ufw disable
```

---

*文档版本: v5.1.0 | 更新日期: 2026-05-09*
