# SSH 加固指南

## 📋 问题描述

SSH 是远程管理的核心服务，但也是攻击者的主要目标。不安全的 SSH 配置可能导致：
- 暴力破解攻击
- 未授权访问
- 密码泄露
- 中间人攻击

---

## ⚠️ 风险评估

| 项目 | 评估 |
|------|------|
| **严重程度** | 🔴 高 |
| **修复难度** | ⭐ 简单 |
| **预计时间** | 10-20分钟 |
| **影响范围** | 远程访问 |

---

## 📝 前置要求

### 1. 备份当前配置

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)
```

### 2. 检查当前配置

```bash
sudo sshd -T | grep -E "permitrootlogin|passwordauthentication|pubkeyauthentication"
```

### 3. 确保有替代访问方式

- 本地控制台访问
- 另一个SSH会话保持打开
- IPMI/KVM 访问

---

## 🔧 修复步骤

### 🟢 入门版（适合新手）

#### 步骤1：禁用 root 登录

编辑 `/etc/ssh/sshd_config`：

```bash
sudo nano /etc/ssh/sshd_config
```

找到并修改：

```ssh
# 禁用 root 登录
PermitRootLogin no

# 禁用密码认证（使用密钥）
PasswordAuthentication no

# 启用公钥认证
PubkeyAuthentication yes
```

#### 步骤2：修改默认端口（可选但推荐）

```ssh
# 修改 SSH 端口（避免默认22）
Port 2222
```

**注意**: 修改端口后需要更新防火墙规则。

#### 步骤3：限制登录尝试次数

```bash
# 安装 fail2ban
sudo apt install fail2ban  # Ubuntu/Debian
sudo yum install fail2ban  # CentOS/RHEL

# 配置 SSH 监控
sudo nano /etc/fail2ban/jail.local
```

添加：

```ini
[sshd]
enabled = true
port = ssh,2222
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
findtime = 600
```

#### 步骤4：重启SSH服务

```bash
sudo systemctl restart sshd
```

#### 步骤5：测试新配置

**不要关闭当前会话！** 在新终端中测试：

```bash
ssh -p 2222 username@your-server-ip
```

---

### 🟡 进阶版（适合有经验用户）

#### 步骤1：生成SSH密钥对（如果还没有）

```bash
# 在客户端生成密钥
ssh-keygen -t ed25519 -a 100 -C "your-email@example.com"

# 或者使用 RSA 4096
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
```

#### 步骤2：部署公钥到服务器

```bash
# 方法1：使用 ssh-copy-id
ssh-copy-id -p 2222 username@your-server-ip

# 方法2：手动复制
cat ~/.ssh/id_ed25519.pub | ssh -p 2222 username@your-server-ip "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

#### 步骤3：配置密钥权限

```bash
# 在服务器上
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chown -R username:username ~/.ssh
```

#### 步骤4：高级SSH配置

编辑 `/etc/ssh/sshd_config`：

```ssh
# 基础安全设置
Protocol 2
Port 2222

# 认证设置
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no

# 会话设置
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2

# 访问限制
AllowUsers username1 username2
# 或允许特定组
AllowGroup ssh-users

# 加密算法
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

# 禁用不安全功能
X11Forwarding no
AllowTcpForwarding no
GatewayPorts no

# 日志
LogLevel VERBOSE
```

#### 步骤5：配置防火墙

```bash
# 只允许特定IP访问SSH
sudo ufw allow from 203.0.113.0/24 to any port 2222

# 或限制连接速率
sudo ufw limit 2222/tcp
```

#### 步骤6：重启并验证

```bash
# 测试配置语法
sudo sshd -t

# 重启服务
sudo systemctl restart sshd

# 查听端口
sudo ss -ltnp | grep ssh
```

---

### 🔴 专业版（适合安全专家）

#### 步骤1：实现双因素认证（2FA）

```bash
# 安装 Google Authenticator
sudo apt install libpam-google-authenticator  # Ubuntu/Debian
sudo yum install google-authenticator  # CentOS/RHEL

# 运行配置向导
google-authenticator
```

配置完成后，编辑 `/etc/pam.d/sshd`：

```bash
# 在文件开头添加
auth required pam_google_authenticator.so
```

编辑 `/etc/ssh/sshd_config`：

```ssh
ChallengeResponseAuthentication yes
AuthenticationMethods publickey,keyboard-interactive
```

#### 步骤2：实现主机密钥轮换

```bash
#!/bin/bash
# 轮换主机密钥脚本

KEY_TYPES=("rsa" "ecdsa" "ed25519")
KEY_DIR="/etc/ssh"
BACKUP_DIR="/etc/ssh/backup_$(date +%Y%m%d)"

mkdir -p "$BACKUP_DIR"

# 备份旧密钥
for key_type in "${KEY_TYPES[@]}"; do
    cp "$KEY_DIR/ssh_host_${key_type}_key"* "$BACKUP_DIR/" 2>/dev/null
done

# 生成新密钥
for key_type in "${KEY_TYPES[@]}"; do
    ssh-keygen -t "$key_type" -f "$KEY_DIR/ssh_host_${key_type}_key" -N ""
done

# 重启SSH服务
systemctl restart sshd

echo "Keys rotated. Backup in $BACKUP_DIR"
```

#### 步骤3：配置 SSH 监控和告警

```bash
# 创建登录监控脚本
cat > /usr/local/bin/ssh-login-monitor.sh << 'EOF'
#!/bin/bash

LOG_FILE="/var/log/ssh-login-monitor.log"
ALERT_EMAIL="admin@example.com"

# 监控登录失败
tail -f /var/log/auth.log | grep --line-buffered "Failed password" | \
    while read line; do
        echo "[$(date)] $line" >> "$LOG_FILE"
        echo "$line" | mail -s "SSH Login Failed" "$ALERT_EMAIL"
    done
EOF

chmod +x /usr/local/bin/ssh-login-monitor.sh

# 创建 systemd 服务
cat > /etc/systemd/system/ssh-login-monitor.service << 'EOF'
[Unit]
Description=SSH Login Monitor

[Service]
ExecStart=/usr/local/bin/ssh-login-monitor.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable ssh-login-monitor
systemctl start ssh-login-monitor
```

#### 步骤4：实现 SSH 会话记录

编辑 `/etc/ssh/sshd_config`：

```ssh
# 启用会话记录
ForceCommand /usr/local/bin/ssh-session-record
```

创建记录脚本：

```bash
#!/bin/bash
# /usr/local/bin/ssh-session-record

SESSION_LOG="/var/log/ssh-sessions/${USER}_$(date +%Y%m%d_%H%M%S).log"
mkdir -p /var/log/ssh-sessions
chown root:adm /var/log/ssh-sessions
chmod 750 /var/log/ssh-sessions

# 记录会话
script -q -f "$SESSION_LOG" --command="$SSH_ORIGINAL_COMMAND"

# 记录会话信息
echo "Session ended: $(date)" >> "$SESSION_LOG"
echo "User: $USER, IP: $SSH_CLIENT" >> "$SESSION_LOG"
```

#### 步骤5：实现自动化安全扫描

```bash
#!/bin/bash
# SSH 安全扫描脚本

echo "=== SSH Security Scan ==="

# 检查配置
echo "[1] Checking SSH configuration..."
sshd -T | grep -E "permitrootlogin|passwordauthentication" | \
    grep -v "no" && echo "⚠️  WARNING: Insecure settings found"

# 检查弱密码
echo "[2] Checking for weak passwords..."
if [ -f /etc/shadow ]; then
    john --wordlist=/usr/share/wordlists/rockyou.txt /etc/shadow --show | \
        head -5
fi

# 检查最近的登录失败
echo "[3] Recent login failures:"
grep "Failed password" /var/log/auth.log | tail -10

# 检查异常登录
echo "[4] Unusual login locations:"
last | awk '{print $3}' | sort | uniq -c | sort -rn | head -10
```

---

## ✅ 验证方法

### 基础验证

```bash
# 测试SSH连接
ssh -p 2222 username@your-server-ip

# 检查SSH配置
sudo sshd -T | grep -E "PermitRootLogin|PasswordAuthentication"

# 检查监听端口
sudo ss -ltnp | grep ssh
```

### 高级验证

```bash
# 测试2FA（如果配置）
ssh username@your-server-ip
# 应该提示输入验证码

# 检查fail2ban状态
sudo fail2ban-client status sshd

# 查看SSH日志
sudo tail -f /var/log/auth.log

# 扫描SSH服务
nmap -p 2222 --script ssh2-enum-algos your-server-ip
```

---

## 🔄 回滚方案

### 恢复配置

```bash
# 恢复备份的配置
sudo cp /etc/ssh/sshd_config.backup.YYYYMMDD /etc/ssh/sshd_config

# 重启服务
sudo systemctl restart sshd
```

### 紧急访问

如果无法SSH访问：

```bash
# 方法1：通过本地控制台登录
# 方法2：使用救援模式
# 方法3：通过云服务商的控制台（VPS）
```

### 禁用fail2ban（如果误封）

```bash
# 解封IP
sudo fail2ban-client set sshd unbanip <ip-address>

# 或临时停止fail2ban
sudo systemctl stop fail2ban
```

---

## ❓ 常见问题

### Q1: 禁用密码认证后无法登录？

**A1**: 确保已正确配置SSH密钥：
```bash
# 检查authorized_keys
ls -la ~/.ssh/authorized_keys
cat ~/.ssh/authorized_keys
```

### Q2: 如何查看被fail2ban封禁的IP？

**A2**:
```bash
sudo fail2ban-client status sshd
```

### Q3: 修改端口后无法连接？

**A3**: 检查防火墙规则：
```bash
sudo ufw allow 2222/tcp
sudo ufw status numbered
```

### Q4: 如何强制所有用户使用密钥？

**A4**: 在sshd_config中设置：
```ssh
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
```

---

## 📚 参考资料

- [OpenSSH 官方文档](https://www.openssh.com/manual.html)
- [SSH 安全最佳实践](https://www.ssh.com/academy/ssh/security)
- [fail2ban 文档](https://fail2ban.readthedocs.io/)
- [Google Authenticator](https://github.com/google/google-authenticator)

---

**耗时**: 入门版10分钟 | 进阶版20分钟 | 专业版1小时
**难度**: ⭐ 简单
**风险**: 🔴 高（可能导致无法远程访问）

⚠️ **重要**: 
- 始终保持一个活跃的SSH会话
- 确保有替代访问方式
- 在生产环境测试前先在测试环境验证！
