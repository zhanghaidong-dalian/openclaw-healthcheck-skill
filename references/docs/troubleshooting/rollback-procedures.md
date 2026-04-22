# 回滚程序

## 📋 概述

本文档提供各种安全配置的回滚步骤。在执行任何回滚前，请确保：
1. 了解当前系统状态
2. 有备份可用
3. 知道如何验证回滚成功

---

## 🔄 通用回滚流程

### 1. 防火墙回滚

```bash
# 备份当前规则
sudo ufw status numbered > ~/ufw-backup.txt
sudo iptables-save > ~/iptables-backup.txt

# 方法A: 重置UFW
sudo ufw reset
sudo ufw enable  # 重新配置

# 方法B: 恢复iptables
sudo iptables-restore < ~/iptables-backup.txt

# 方法C: 临时禁用
sudo ufw disable
```

---

### 2. SSH配置回滚

```bash
# 检查备份
ls -la /etc/ssh/sshd_config.backup.*

# 恢复配置
sudo cp /etc/ssh/sshd_config.backup.20260422 /etc/ssh/sshd_config
sudo systemctl restart sshd

# 如果无法SSH，从控制台执行
```

---

### 3. 系统更新回滚

```bash
# 查看可用的历史版本
dpkg -l | grep ^ii

# 降级特定包
sudo apt install package=version

# 降级所有包到特定日期
sudo apt-get install --allow-downgrades ...
```

---

### 4. 服务配置回滚

```bash
# 查看systemd配置
systemctl cat service-name

# 恢复默认配置
sudo systemctl revert service-name

# 或手动恢复
sudo cp /etc/systemd/system/service-name.service.backup \
    /etc/systemd/system/service-name.service
sudo systemctl daemon-reload
sudo systemctl restart service-name
```

---

## 🚨 紧急回滚场景

### 场景1: 远程完全无法访问

**优先级**: 🔴 最高

**步骤**:
1. 使用VNC/控制台/KVM访问
2. 诊断问题：`systemctl status sshd`
3. 恢复SSH配置
4. 重新加载：`systemctl restart sshd`
5. 验证连接

---

### 场景2: 防火墙阻止所有流量

**优先级**: 🔴 最高

**步骤**:
1. 本地控制台访问
2. 禁用防火墙：`sudo ufw disable`
3. 检查规则：`sudo ufw status verbose`
4. 修复规则或恢复备份
5. 重新启用：`sudo ufw enable`

---

### 场景3: 系统更新后启动失败

**优先级**: 🔴 高

**步骤**:
1. 进入GRUB菜单
2. 选择"Advanced options"
3. 选择"Recovery mode"
4. 选择"root shell"
5. 修复或回滚

```bash
# 修复引导
update-grub

# 回滚内核
apt remove linux-image-xxx
apt install linux-image-xxx-old

# 重启
reboot
```

---

## 💾 备份策略

### 推荐备份内容

1. **配置文件**
   - `/etc/ssh/sshd_config`
   - `/etc/iptables/rules.v4`
   - `/etc/fail2ban/jail.local`
   - `/etc/systemd/system/`

2. **系统状态**
   - 服务列表：`systemctl list-unit-files`
   - 防火墙规则：`ufw status > rules.txt`
   - 用户列表：`cat /etc/passwd`

3. **数据**
   - 用户home目录
   - 数据库
   - 配置文件

---

## ✅ 验证回滚成功

```bash
# 验证服务状态
systemctl status service-name
sudo ss -ltnp | grep port

# 验证配置
sudo sshd -t

# 验证连接
ssh user@server

# 验证功能
curl http://localhost:port
```

---

**提示**: 定期测试回滚流程，确保备份有效！
