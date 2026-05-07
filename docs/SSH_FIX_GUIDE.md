# SSH 安全配置修复指南

本指南详细介绍如何修复 SSH 相关的安全问题，提升系统安全评分。

---

## 📋 目录

1. [快速修复](#快速修复)
2. [SSH-001: 禁用 Root 登录](#ssh-001-禁用-root-登录)
3. [SSH-002: 使用密钥认证](#ssh-002-使用密钥认证)
4. [SSH-003: 限制登录用户](#ssh-003-限制登录用户)
5. [SSH-004: 禁用密码认证](#ssh-004-禁用密码认证)
6. [SSH-005: 修改默认端口](#ssh-005-修改默认端口)
7. [常见问题](#常见问题)

---

## 快速修复

使用一键修复脚本：

```bash
# 查看当前状态
bash scripts/fix-ssh-hardening.sh status

# 交互式修复
bash scripts/fix-ssh-hardening.sh fix

# 自动修复基础项（禁用root登录，启用协议v2）
bash scripts/fix-ssh-hardening.sh auto
```

---

## SSH-001: 禁用 Root 登录

### 问题描述
SSH 允许 root 用户直接登录，存在严重安全风险：
- 一旦密码泄露，攻击者获得最高权限
- 无法进行用户操作审计
- 自动化攻击工具优先尝试 root 账户

### 安全影响
| 等级 | 说明 |
|------|------|
| 🔴 高危 | 可能导致系统完全沦陷 |

### 修复步骤

#### 方法 1: 使用修复脚本（推荐）
```bash
bash scripts/fix-ssh-hardening.sh fix
# 选择 "禁用root登录"
```

#### 方法 2: 手动修复

**Step 1: 确保已有普通用户**
```bash
# 检查是否存在普通用户
id username

# 如果没有，创建新用户
sudo useradd -m -s /bin/bash username
sudo passwd username
sudo usermod -aG sudo username  # 添加到sudo组（可选）
```

**Step 2: 备份配置文件**
```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)
```

**Step 3: 编辑 SSH 配置**
```bash
sudo nano /etc/ssh/sshd_config
```

找到并修改以下行：
```
# 修改前
#PermitRootLogin yes

# 修改后
PermitRootLogin no
```

**Step 4: 验证配置**
```bash
sudo sshd -t
# 应该没有输出（表示配置正确）
```

**Step 5: 重启 SSH 服务**
```bash
# Ubuntu/Debian
sudo systemctl restart sshd

# CentOS/RHEL
sudo systemctl restart sshd

# 旧版本系统
sudo service ssh restart
```

**Step 6: 测试新配置**
```bash
# 在另一个终端测试（不要关闭当前连接！）
ssh username@your-server-ip

# 确认可以登录后，测试 root 无法登录
ssh root@your-server-ip
# 应该显示：Permission denied
```

### 回滚方法
```bash
# 如果无法登录，通过控制台/VNC 登录并恢复
sudo cp /etc/ssh/sshd_config.backup.XXX /etc/ssh/sshd_config
sudo systemctl restart sshd
```

---

## SSH-002: 使用密钥认证

### 问题描述
仅使用密码认证容易被暴力破解攻击。

### 安全影响
| 等级 | 说明 |
|------|------|
| 🔴 高危 | 密码可被暴力破解 |

### 修复步骤

#### 生成 SSH 密钥对

**Step 1: 在本地机器生成密钥**
```bash
# 使用 Ed25519 算法（推荐）
ssh-keygen -t ed25519 -C "your-email@example.com"

# 或使用 RSA 算法（兼容性更好）
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
```

**Step 2: 复制公钥到服务器**
```bash
# 方法 1: 使用 ssh-copy-id
ssh-copy-id username@your-server-ip

# 方法 2: 手动复制
ssh username@your-server-ip "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
scp ~/.ssh/id_ed25519.pub username@your-server-ip:~/.ssh/authorized_keys
ssh username@your-server-ip "chmod 600 ~/.ssh/authorized_keys"
```

**Step 3: 测试密钥登录**
```bash
# 应该无需密码直接登录
ssh username@your-server-ip
```

---

## SSH-003: 限制登录用户

### 问题描述
没有限制可以登录的用户，增加攻击面。

### 修复步骤

**编辑 SSH 配置**
```bash
sudo nano /etc/ssh/sshd_config
```

添加以下行：
```
# 只允许特定用户
AllowUsers username1 username2

# 或者只允许特定组
AllowGroups ssh-users

# 拒绝特定用户
DenyUsers baduser
```

**重启服务**
```bash
sudo systemctl restart sshd
```

---

## SSH-004: 禁用密码认证

### ⚠️ 重要警告
**启用此配置前，必须确保：**
1. ✅ 已配置 SSH 密钥认证
2. ✅ 已测试密钥可以正常登录
3. ✅ 保留另一个有效的 SSH 连接

### 修复步骤

**Step 1: 确认密钥认证工作**
```bash
# 在新终端窗口测试
ssh -o PasswordAuthentication=no username@your-server-ip
# 如果能登录，说明密钥配置正确
```

**Step 2: 编辑配置**
```bash
sudo nano /etc/ssh/sshd_config
```

添加/修改：
```
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
```

**Step 3: 重启并测试**
```bash
sudo systemctl restart sshd

# 测试密码登录（应该失败）
ssh -o PubkeyAuthentication=no username@your-server-ip
# 应该显示：Permission denied (publickey)
```

---

## SSH-005: 修改默认端口

### 问题描述
使用默认 22 端口容易受到自动化扫描攻击。

### 修复步骤

**Step 1: 选择新端口**
```bash
# 选择 1024-65535 之间的高位端口
NEW_PORT=2222
```

**Step 2: 更新防火墙**
```bash
# Ubuntu/Debian (UFW)
sudo ufw allow $NEW_PORT/tcp
sudo ufw delete allow 22/tcp  # 可选：删除旧端口

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-port=$NEW_PORT/tcp
sudo firewall-cmd --reload
```

**Step 3: 修改 SSH 配置**
```bash
sudo nano /etc/ssh/sshd_config
```

修改：
```
Port 2222
```

**Step 4: 重启服务**
```bash
sudo systemctl restart sshd
```

**Step 5: 使用新端口连接**
```bash
ssh -p 2222 username@your-server-ip
```

---

## 完整安全配置示例

```bash
# /etc/ssh/sshd_config 推荐配置

# 基础安全
Port 2222
Protocol 2
PermitRootLogin no

# 认证设置
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no

# 限制用户
AllowUsers yourusername

# 会话设置
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 60
MaxAuthTries 3
MaxSessions 2

# 禁用不必要功能
X11Forwarding no
AllowTcpForwarding no
PermitTunnel no
```

---

## 常见问题

### Q: 禁用 root 登录后，普通用户如何执行管理操作？
**A:** 使用 `sudo` 命令：
```bash
sudo apt update
sudo systemctl restart service
```

### Q: 忘记配置普通用户，现在无法登录怎么办？
**A:** 通过物理控制台或 VNC 登录：
```bash
# 在控制台登录后恢复
sudo cp /etc/ssh/sshd_config.backup.XXX /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### Q: 密钥认证失败，如何排查？
**A:** 检查以下几点：
```bash
# 1. 检查密钥权限
ls -la ~/.ssh/
# 应该显示：
# -rw------- 1 user user  464 id_ed25519
# -rw-r--r-- 1 user user  104 id_ed25519.pub

# 2. 检查服务器端权限
ssh username@server "ls -la ~/.ssh/"
# authorized_keys 应该是 -rw------- (600)

# 3. 检查 SSH 日志
sudo tail -f /var/log/auth.log  # Ubuntu/Debian
sudo tail -f /var/log/secure    # CentOS/RHEL
```

### Q: 如何检查当前 SSH 安全状态？
**A:** 使用技能脚本：
```bash
bash scripts/quick-check.sh --category ssh

# 或使用修复脚本的 status 命令
bash scripts/fix-ssh-hardening.sh status
```

---

## 参考资源

- [OpenSSH 官方文档](https://www.openssh.com/manual.html)
- [CIS SSH Benchmark](https://www.cisecurity.org/benchmark/ssh)
- [NIST SSH 安全指南](https://nvd.nist.gov/)

---

**最后更新**: 2026-05-07  
**版本**: 5.0.0
