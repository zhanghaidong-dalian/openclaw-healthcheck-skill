# 🔧 故障排查指南 - OpenClaw 主机安全加固工具

**版本**: v4.8.x
**更新时间**: 2026-04-28

---

## 目录

1. [常见问题](#常见问题)
2. [错误信息解读](#错误信息解读)
3. [修复脚本问题](#修复脚本问题)
4. [环境问题](#环境问题)
5. [性能问题](#性能问题)
6. [高级排查](#高级排查)

---

## 常见问题

### Q1: 提示 "Permission denied"

**问题描述**：
```
bash: ./bin/healthcheck: Permission denied
```

**原因分析**：
- 文件没有执行权限
- 当前用户权限不足

**解决方法**：

```bash
# 方法1: 赋予执行权限
chmod +x bin/healthcheck

# 方法2: 使用 sudo
sudo ./bin/healthcheck --quick

# 方法3: 检查文件权限
ls -la bin/healthcheck
```

---

### Q2: 提示 "command not found"

**问题描述**：
```
./bin/healthcheck: command not found
```

**原因分析**：
- 工作目录不正确
- 脚本文件名错误

**解决方法**：

```bash
# 检查当前目录
pwd

# 进入正确目录
cd /path/to/openclaw-healthcheck-skill

# 确认文件存在
ls -la bin/

# 使用绝对路径
./bin/healthcheck --help
```

---

### Q3: 扫描结果全是绿色/通过

**问题描述**：
- 所有检查项都显示通过
- 但系统可能存在问题

**原因分析**：
- 沙盒环境限制
- 容器环境权限限制
- 检查规则未覆盖

**解决方法**：

```bash
# 在真实 Linux 环境中运行
./bin/healthcheck --deep

# 使用详细模式
./bin/healthcheck --quick --verbose

# 检查系统信息
uname -a
cat /etc/os-release
```

---

### Q4: 防火墙检查失败

**问题描述**：
```
⚠️ 防火墙未启用
```

**原因分析**：
- ufw/iptables 未安装
- 防火墙服务未启动
- 容器环境限制

**解决方法**：

```bash
# 安装 ufw
sudo apt install ufw

# 启用防火墙
sudo ufw enable

# 检查状态
sudo ufw status

# 如果是容器环境，忽略此警告
# 容器网络安全由容器平台负责
```

---

### Q5: SSH 检查失败

**问题描述**：
```
⚠️ SSH root 登录已启用
```

**原因分析**：
- sshd_config 配置允许 root 登录
- 存在安全风险

**解决方法**：

```bash
# 查看当前配置
sudo grep "PermitRootLogin" /etc/ssh/sshd_config

# 修改配置
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# 重启 SSH 服务
sudo systemctl restart sshd

# 注意：确保有非 root 用户可以 SSH 登录！
```

---

### Q6: 系统更新检查失败

**问题描述**：
```
⚠️ 系统有待安装的更新
```

**原因分析**：
- 有可用更新未安装
- 更新源配置问题

**解决方法**：

```bash
# 更新软件包列表
sudo apt update

# 查看可更新软件包
apt list --upgradable

# 执行更新
sudo apt upgrade -y

# 或者使用安全更新
sudo apt update && sudo apt upgrade -y
```

---

### Q7: Fail2ban 检查失败

**问题描述**：
```
⚠️ Fail2ban 未安装
```

**原因分析**：
- fail2ban 未安装
- fail2ban 服务未启动

**解决方法**：

```bash
# 安装 fail2ban
sudo apt install fail2ban

# 启动服务
sudo systemctl start fail2ban

# 启用开机自启
sudo systemctl enable fail2ban

# 检查状态
sudo systemctl status fail2ban
```

---

## 错误信息解读

### 错误级别说明

| 级别 | 颜色 | 含义 | 处理建议 |
|------|------|------|----------|
| 🟢 LOW | 绿色 | 低风险 | 可选修复 |
| 🟡 MEDIUM | 黄色 | 中风险 | 建议修复 |
| 🔴 HIGH | 红色 | 高风险 | 立即修复 |

### 常见错误代码

| 错误代码 | 含义 | 解决方法 |
|----------|------|----------|
| E001 | 文件权限不足 | 使用 sudo |
| E002 | 命令未找到 | 安装依赖 |
| E003 | 配置文件缺失 | 创建配置文件 |
| E004 | 服务未运行 | 启动服务 |
| E005 | 检查超时 | 增加超时时间 |

### SSH 错误

| 错误信息 | 含义 | 解决方法 |
|----------|------|----------|
| `SSH password auth enabled` | 密码认证已启用 | 改用密钥认证 |
| `SSH root login enabled` | root 登录已启用 | 禁用 root 登录 |
| `SSH port 22` | 使用默认端口 | 更改端口 |
| `SSH config writable` | 配置可写 | 限制权限 |

### 防火墙错误

| 错误信息 | 含义 | 解决方法 |
|----------|------|----------|
| `Firewall not enabled` | 防火墙未启用 | 启用防火墙 |
| `Firewall rules too open` | 规则过于宽松 | 添加规则 |
| `Unused ports open` | 有未使用端口开放 | 关闭端口 |

---

## 修复脚本问题

### 修复脚本执行失败

**常见原因**：
1. 权限不足
2. 依赖缺失
3. 服务冲突
4. 配置锁定

**排查步骤**：

```bash
# 1. 检查权限
ls -la scripts/*.sh

# 2. 手动执行修复脚本（带调试）
bash -x scripts/fix-ssh.sh

# 3. 查看详细输出
./bin/healthcheck --fix --verbose

# 4. 检查系统日志
journalctl -xe
```

### 修复后服务无法启动

**解决方法**：

```bash
# 1. 检查服务状态
systemctl status sshd

# 2. 查看错误日志
journalctl -u sshd -n 50

# 3. 测试配置
sshd -t

# 4. 恢复备份的配置
sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### 修复脚本备份

修复脚本会自动备份原文件：

```bash
# 查看备份目录
ls -la /tmp/healthcheck-backups/

# 手动恢复
sudo cp /tmp/healthcheck-backups/sshd_config.$(date +%Y%m%d) /etc/ssh/sshd_config
```

---

## 环境问题

### Docker 容器环境

**已知限制**：
- 防火墙检查会失败（容器网络由平台管理）
- 部分系统检查受限

**建议**：
```bash
# 跳过不适用的检查
./bin/healthcheck --quick --skip firewall

# 查看帮助
./bin/healthcheck --help
```

### 树莓派环境

**已知限制**：
- 部分检查项不适用

**建议**：
```bash
# 使用轻量级扫描
./bin/healthcheck --quick

# 跳过不适用项
./bin/healthcheck --quick --skip disk-encryption
```

### WSL 环境

**已知问题**：
- systemd 服务不可用
- 部分检查受限

**建议**：
```bash
# 使用快速扫描
./bin/healthcheck --quick

# 手动检查关键项
./bin/healthcheck --check ssh
./bin/healthcheck --check updates
```

---

## 性能问题

### 扫描速度慢

**可能原因**：
1. 网络检查超时
2. 大量日志文件
3. 系统负载高

**解决方法**：

```bash
# 使用轻量级模式
./bin/healthcheck --quick

# 跳过网络检查
./bin/healthcheck --quick --skip network

# 查看扫描耗时
time ./bin/healthcheck --quick
```

### 内存占用高

**可能原因**：
- 系统日志过大
- 规则文件过多

**解决方法**：

```bash
# 清理日志
sudo journalctl --vacuum-time=7d

# 检查内存
free -h

# 使用轻量级模式
./bin/healthcheck --quick
```

---

## 高级排查

### 启用调试模式

```bash
# 查看详细日志
./bin/healthcheck --quick --verbose

# 保存完整输出
./bin/healthcheck --quick --verbose 2>&1 | tee debug.log
```

### 检查依赖

```bash
# 检查必需命令
which bash grep sed awk systemctl

# 检查可选命令
which yq jq python3

# 查看所有依赖
./bin/healthcheck --check-deps
```

### 查看系统信息

```bash
# 系统信息
uname -a
cat /etc/os-release

# 资源使用
df -h
free -h
top -bn1 | head -10

# 网络状态
ss -tuln
netstat -tuln
```

### 提交问题报告

如果以上方法无法解决，请提交问题：

```bash
# 生成诊断报告
./bin/healthcheck --diagnose > diagnostic-report.txt

# 提交到 GitHub
# https://github.com/zhanghaidong-dalian/openclaw-healthcheck-skill/issues

# 请包含以下信息：
# 1. 操作系统版本
# 2. 错误信息截图
# 3. 诊断报告
# 4. 复现步骤
```

---

## 联系支持

- 🐛 问题反馈: [GitHub Issues](https://github.com/zhanghaidong-dalian/openclaw-healthcheck-skill/issues)
- 📖 完整文档: [USAGE.md](USAGE.md)
- 🚀 快速开始: [QUICK-START.md](QUICK-START.md)

---

**最后更新**: 2026-04-28
**版本**: v4.8.x
