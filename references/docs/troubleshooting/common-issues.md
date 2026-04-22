# 常见问题解答

## 📋 快速索引

1. [基础问题](#基础问题)
2. [防火墙问题](#防火墙问题)
3. [SSH问题](#ssh问题)
4. [更新问题](#更新问题)
5. [加密问题](#加密问题)
6. [服务问题](#服务问题)

---

## 基础问题

### Q1: 如何知道我的系统是否有安全问题？

**A**: 运行基础安全检查：

```bash
openclaw security audit
openclaw security audit --deep
```

---

### Q2: 安全检查会影响系统性能吗？

**A**: 不会。所有检查都是只读的，不会修改任何文件或影响性能。

---

### Q3: 我需要root权限来运行检查吗？

**A**: 
- 基础检查：不需要root
- 修复操作：需要root/sudo

---

## 防火墙问题

### Q1: 启用防火墙后无法连接SSH？

**A**: 
1. 确保防火墙规则允许SSH：`sudo ufw allow ssh`
2. 检查端口是否正确：`sudo ufw status`
3. 从本地控制台访问并修复

---

### Q2: 如何查看被防火墙阻止的连接？

**A**:
```bash
sudo ufw logging on
sudo tail -f /var/log/ufw.log
```

---

### Q3: 防火墙会影响网站访问吗？

**A**: 如果运行Web服务，确保允许HTTP/HTTPS：
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

---

## SSH问题

### Q1: 修改SSH配置后无法登录？

**A**: 
1. **保持原会话** - 始终保持一个活跃的SSH会话
2. **测试配置** - 使用 `sudo sshd -t` 测试语法
3. **重启服务** - `sudo systemctl restart sshd`

---

### Q2: 禁用密码认证后无法登录？

**A**: 确保：
1. 公钥已添加到 `~/.ssh/authorized_keys`
2. 密钥权限正确：`chmod 600 ~/.ssh/authorized_keys`
3. SSH客户端配置了密钥

---

### Q3: fail2ban误封了正常用户？

**A**:
```bash
# 解封特定IP
sudo fail2ban-client set sshd unbanip <IP>

# 查看被封IP
sudo fail2ban-client status sshd

# 临时禁用fail2ban
sudo systemctl stop fail2ban
```

---

## 更新问题

### Q1: 更新后系统无法启动？

**A**:
1. 使用救援模式启动
2. 查看日志：`journalctl -xb`
3. 恢复到之前的快照（如果有）

---

### Q2: 如何回滚更新？

**A**:
```bash
# Ubuntu/Debian - 查看已安装版本
apt-cache showpkg package-name

# 降级
sudo apt install package-name=version

# 或使用时间机
sudo apt-get install -y --allow-downgrades package=version
```

---

### Q3: 自动更新占用太多带宽？

**A**:
```bash
# 限制下载速度
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
# 添加：Acquire::http::Dl-Limit "100";
```

---

## 加密问题

### Q1: 忘记了LUKS密码怎么办？

**A**: 
1. **如果有恢复密钥**：使用恢复密钥解锁
2. **如果没有**：无法恢复，磁盘数据将丢失
3. **预防措施**：始终创建恢复密钥并安全保存

---

### Q2: 加密后系统启动变慢？

**A**: 正常现象。解密过程需要时间。
- 优化：使用SSD
- 使用TPM自动解锁（进阶配置）

---

### Q3: 如何备份LUKS头？

**A**:
```bash
# 备份
sudo cryptsetup luksHeaderBackup /dev/sdaX \
    --header-backup-file /root/luks-header.img

# 验证
sudo cryptsetup luksHeaderRestore /dev/sdaX \
    --header-backup-file /root/luks-header.img --type luks
```

---

## 服务问题

### Q1: 禁用服务后某些功能不工作？

**A**:
1. 检查服务依赖：`systemctl list-dependencies service-name`
2. 重新启用服务：`sudo systemctl enable service-name`
3. 查看日志：`journalctl -u service-name`

---

### Q2: 如何知道哪些服务应该禁用？

**A**: 通常可以禁用的服务：
- bluetooth（不使用蓝牙）
- cups（不使用打印机）
- avahi-daemon（不使用网络发现）
- rpcbind（不使用NFS）

**谨慎禁用**：
- network-manager
- systemd-resolved
- sshd

---

### Q3: AppArmor阻止了合法操作？

**A**:
```bash
# 临时允许（测试用）
sudo aa-complain /path/to/binary

# 永久允许（测试后）
sudo nano /etc/apparmor.d/local/usr.bin.program
# 添加规则

# 重载配置
sudo systemctl reload apparmor
```

---

## 🚨 紧急情况处理

### 场景1: 完全无法SSH访问

**解决方案**:
1. 使用云控制台/VNC
2. 本地访问（如果可以）
3. 重置SSH配置：
```bash
sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### 场景2: 防火墙锁死

**解决方案**:
```bash
# 本地执行
sudo ufw disable

# 或
sudo systemctl stop ufw
```

### 场景3: 系统无法启动

**解决方案**:
1. 进入恢复模式
2. 选择root shell
3. 修复问题或回滚更改

---

## 📞 获取更多帮助

- **文档**: 查看详细指南
- **社区**: https://discord.com/invite/clawd
- **GitHub**: https://github.com/openclaw/openclaw/issues
