# 防火墙加固指南

## 📋 问题描述

防火墙是网络安全的第一道防线。不正确配置的防火墙可能导致：
- 未授权访问
- 服务被攻击
- 数据泄露

---

## ⚠️ 风险评估

| 项目 | 评估 |
|------|------|
| **严重程度** | 🔴 高 |
| **修复难度** | ⭐⭐ 中等 |
| **预计时间** | 15-30分钟 |
| **影响范围** | 网络访问控制 |

---

## 📝 前置要求

### 检查当前防火墙状态

```bash
# Ubuntu/Debian (ufw)
sudo ufw status

# CentOS/RHEL (firewalld)
sudo firewall-cmd --state

# 检查正在监听的端口
sudo ss -ltnup
```

---

## 🔧 修复步骤

### 🟢 入门版（适合新手）

#### 步骤1：启用防火墙

```bash
# Ubuntu/Debian
sudo ufw enable

# CentOS/RHEL
sudo systemctl enable firewalld
sudo systemctl start firewalld
```

#### 步骤2：允许必要的端口

```bash
# 允许 SSH（重要！否则会断开连接）
sudo ufw allow ssh
# 或指定端口
sudo ufw allow 22/tcp

# 允许 HTTP（如果需要Web服务）
sudo ufw allow 80/tcp

# 允许 HTTPS（如果需要Web服务）
sudo ufw allow 443/tcp
```

#### 步骤3：设置默认策略

```bash
# 拒绝所有入站连接
sudo ufw default deny incoming

# 允许所有出站连接
sudo ufw default allow outgoing

# 查看规则
sudo ufw status numbered
```

#### 步骤4：验证配置

```bash
# 查看状态
sudo ufw status verbose
```

**预期输出**: 显示所有启用的规则

---

### 🟡 进阶版（适合有经验用户）

#### 步骤1：配置详细的端口规则

```bash
# 只允许特定IP访问SSH（推荐）
sudo ufw allow from 192.168.1.0/24 to any port 22

# 或仅允许特定IP
sudo ufw allow from 203.0.113.1 to any port 22

# 限制连接速率（防暴力破解）
sudo ufw limit 22/tcp
```

#### 步骤2：配置 NAT/转发（如果需要）

```bash
# 编辑 /etc/default/ufw
# 设置 DEFAULT_FORWARD_POLICY="ACCEPT"

# 编辑 /etc/ufw/sysctl.conf
# 取消注释 net/ipv4/ip_forward=1

# 重载规则
sudo ufw reload
```

#### 步骤3：日志配置

```bash
# 启用日志
sudo ufw logging on

# 设置日志级别
sudo ufw logging high

# 查看日志
sudo tail -f /var/log/ufw.log
```

#### 步骤4：配置应用配置文件

```bash
# 查看可用应用配置
sudo ufw app list

# 应用特定配置
sudo ufw allow 'Nginx Full'
sudo ufw allow 'Apache Full'
```

---

### 🔴 专业版（适合安全专家）

#### 步骤1：使用 iptables 直接配置

```bash
# 清空现有规则
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X

# 设置默认策略
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# 允许回环接口
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT

# 允许已建立的连接
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 允许SSH（限制速率）
sudo iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
sudo iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# 防止端口扫描
sudo iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
sudo iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# 保存规则
sudo iptables-save > /etc/iptables/rules.v4
```

#### 步骤2：配置 fail2ban 集成

```bash
# 安装 fail2ban
sudo apt install fail2ban  # Ubuntu/Debian
sudo yum install fail2ban  # CentOS/RHEL

# 创建本地配置
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# 编辑 /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600

# 启动服务
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

#### 步骤3：配置高级规则

```bash
# 防止 SYN Flood 攻击
sudo iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT

# 防止 ICMP Flood 攻击
sudo iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 1 -j ACCEPT

# 丢弃无效包
sudo iptables -A INPUT -m state --state INVALID -j DROP

# 配置端口转发
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
```

#### 步骤4：创建规则管理脚本

```bash
#!/bin/bash
# /usr/local/bin/firewall-manage.sh

case "$1" in
  start)
    echo "Starting firewall..."
    iptables-restore < /etc/iptables/rules.v4
    ;;
  stop)
    echo "Stopping firewall..."
    iptables -F
    iptables -X
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    ;;
  save)
    echo "Saving rules..."
    iptables-save > /etc/iptables/rules.v4
    ;;
  *)
    echo "Usage: $0 {start|stop|save}"
    exit 1
    ;;
esac

exit 0
```

---

## ✅ 验证方法

### 基础验证

```bash
# 检查防火墙状态
sudo ufw status  # ufw
sudo firewall-cmd --list-all  # firewalld

# 测试端口连接
nc -zv <your-ip> 22
nc -zv <your-ip> 80
```

### 高级验证

```bash
# 列出所有iptables规则
sudo iptables -L -n -v

# 查看fail2ban状态
sudo fail2ban-client status

# 测试SYN Flood防护
# 从另一台机器运行：hping3 -S -p 22 <target-ip> -i u1000
```

---

## 🔄 回滚方案

### 备份当前规则

```bash
# ufw
sudo ufw status numbered > ~/ufw-rules-backup.txt

# iptables
sudo iptables-save > ~/iptables-backup.txt
```

### 恢复规则

```bash
# ufw - 重置为默认
sudo ufw reset

# iptables - 恢复备份
sudo iptables-restore < ~/iptables-backup.txt
```

### 紧急访问

如果防火墙配置错误导致无法访问：

```bash
# 方法1：通过本地控制台
# 方法2：重启服务器（规则未保存的情况）
# 方法3：使用救援模式
```

---

## ❓ 常见问题

### Q1: 启用防火墙后无法SSH连接？

**A1**: 确保在启用前已经允许SSH端口：
```bash
sudo ufw allow ssh
sudo ufw enable
```

### Q2: 如何临时禁用防火墙？

**A2**:
```bash
sudo ufw disable  # 临时禁用
sudo ufw enable   # 重新启用
```

### Q3: 如何查看被阻止的连接？

**A3**:
```bash
sudo ufw logging on
sudo tail -f /var/log/ufw.log
```

### Q4: 防火墙会影响性能吗？

**A4**: 影响很小，现代服务器可以轻松处理数万条规则。

---

## 📚 参考资料

- [UFW 官方文档](https://help.ubuntu.com/community/UFW)
- [iptables 教程](https://www.frozentux.net/iptables-tutorial/iptables-tutorial.html)
- [firewalld 文档](https://firewalld.org/)
- [fail2ban 文档](https://fail2ban.readthedocs.io/)

---

**耗时**: 入门版15分钟 | 进阶版30分钟 | 专业版1小时
**难度**: ⭐⭐ 中等
**风险**: 🟡 中等（可能影响网络访问）

⚠️ **重要**: 在生产环境操作前，确保有本地控制台访问权限！
