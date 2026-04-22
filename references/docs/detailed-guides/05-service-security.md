# 服务安全配置指南

## 📋 问题描述

不安全的系统服务可能导致：
- 未授权访问
- 权限提升
- 服务被利用
- 信息泄露

---

## ⚠️ 风险评估

| 项目 | 评估 |
|------|------|
| **严重程度** | 🟡 中 |
| **修复难度** | ⭐ 简单 |
| **预计时间** | 20-40分钟 |
| **影响范围** | 系统服务 |

---

## 🔧 修复步骤

### 🟢 入门版（适合新手）

#### 检查运行中的服务

```bash
# 列出所有服务
systemctl list-units --type=service --all

# 查找正在运行的服务
systemctl list-units --type=service --state=running

# 查看开机自启服务
systemctl list-unit-files --type=service
```

#### 禁用不需要的服务

```bash
# 常见应禁用服务示例
sudo systemctl stop bluetooth
sudo systemctl disable bluetooth

sudo systemctl stop cups  # 打印机服务
sudo systemctl disable cups

sudo systemctl stop avahi-daemon  # 网络发现
sudo systemctl disable avahi-daemon

sudo systemctl stop rpcbind  # RPC服务（除非需要NFS）
sudo systemctl disable rpcbind
```

#### 检查监听端口

```bash
# 查看监听端口
sudo ss -ltnp

# 或
sudo netstat -tlnp

# 识别每个端口对应的服务
```

---

### 🟡 进阶版（适合有经验用户）

#### 配置服务权限

```bash
# 创建服务专用用户
sudo useradd -r -s /sbin/nologin service_name

# 设置目录权限
sudo chown -R service_user:service_group /path/to/service

# 配置systemd限制
sudo mkdir -p /etc/systemd/system/service_name.service.d
sudo nano /etc/systemd/system/service_name.service.d/override.conf
```

添加限制配置：
```ini
[Service]
User=service_user
Group=service_group
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/var/log/service
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictRealtime=true
RestrictNamespaces=true
```

#### 启用服务安全功能

```bash
# AppArmor 配置
sudo apt install apparmor apparmor-utils
sudo aa-status

# 启用/禁用配置文件
sudo aa-complain /etc/apparmor.d/*
sudo aa-enforce /etc/apparmor.d/*

# SELinux 配置（CentOS/RHEL）
sudo getenforce
sudo setenforce 1
sudo nano /etc/selinux/config
```

#### 审计服务访问

```bash
# 启用服务审计
sudo auditdctl -e 1

# 监控服务文件访问
sudo auditctl -w /usr/bin/service_name -p x -k service_exec

# 查看审计日志
sudo ausearch -k service_exec
```

---

### 🔴 专业版（适合安全专家）

#### 容器化危险服务

```bash
# 使用Docker运行危险服务
docker run -d \
    --name isolated_service \
    --read-only \
    --no-new-privileges \
    --cap-drop ALL \
    --security-opt=no-new-privileges \
    -v /readonly/path:/data:ro \
    service_image

# 或使用Podman（无守护进程）
podman run -d \
    --name isolated_service \
    --security-opt label=type:container_service_t \
    --read-only \
    --cap-drop all \
    service_image
```

#### 服务隔离配置

```bash
# 使用 systemd slice 隔离
sudo mkdir -p /etc/systemd/system/app.slice.d
sudo nano /etc/systemd/system/app.slice.d/limits.conf
```

```ini
[Slice]
MemoryAccounting=true
MemoryLimit=512M
CPUAccounting=true
CPUQuota=50%
TasksAccounting=true
TasksMax=50
```

#### 入侵检测集成

```bash
# 配置 AIDE（高级入侵检测环境）
sudo apt install aide
sudo aideinit

# 创建基线
sudo aide --init
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db.old

# 定期检查
sudo aide --check

# 配置自动检查
sudo nano /etc/cron.d/aide
# 0 3 * * * root /usr/sbin/aide --check
```

---

## ✅ 验证方法

```bash
# 验证服务状态
systemctl status service_name

# 检查资源限制
systemctl show service_name | grep -E "Memory|CPU|Tasks"

# 测试AppArmor状态
sudo aa-status

# 检查SELinux状态
getenforce
sestatus

# 验证文件权限
ls -la /path/to/service
```

---

## 📚 参考资料

- [systemd 安全文档](https://www.freedesktop.org/software/systemd/man/systemd.exec.html)
- [AppArmor 文档](https://gitlab.com/apparmor/apparmor/-/wikis/Documentation)
- [AIDE 文档](https://aide.github.io/)

---

**耗时**: 入门版20分钟 | 进阶版30分钟 | 专业版1小时
**难度**: ⭐ 简单
**风险**: 🟡 中等（可能影响服务功能）

⚠️ **重要**: 禁用服务前确认其功能是否必需！
