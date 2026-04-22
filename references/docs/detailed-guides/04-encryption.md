# 磁盘加密指南

## 📋 问题描述

未加密的磁盘可能导致数据泄露，尤其是在：
- 设备丢失或被盗
- 硬盘被取出
- 未经授权的物理访问
- 旧设备处理不当

---

## ⚠️ 风险评估

| 项目 | 评估 |
|------|------|
| **严重程度** | 🟡 中高 |
| **修复难度** | ⭐⭐⭐ 复杂 |
| **预计时间** | 30分钟-2小时 |
| **影响范围** | 数据保护 |

---

## 🔧 修复步骤

### 🟢 入门版（适合新手）

#### 检查当前加密状态

```bash
# 检查是否已加密
sudo blkid | grep -i crypt
ls -la /dev/mapper/

# Ubuntu - 检查全磁盘加密
sudo lsblk -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINT,CRYPT

# 检查swap是否加密
swapon -s
```

#### 启用home目录加密（Ubuntu）

如果在安装时未选择加密home：

```bash
# 安装 ecryptfs
sudo apt install ecryptfs-utils

# 加密当前用户的home目录
ecryptfs-migrate-home -u username

# ⚠️ 警告：用户必须登出才能执行
```

#### 加密外部存储设备

```bash
# 安装 cryptsetup
sudo apt install cryptsetup

# 创建加密容器文件（1GB示例）
dd if=/dev/urandom of=/path/to/encrypted_file bs=1M count=1024

# 设置加密映射
sudo cryptsetup luksFormat /path/to/encrypted_file

# 打开加密卷
sudo cryptsetup luksOpen /path/to/encrypted_file encrypted_vol

# 创建文件系统
sudo mkfs.ext4 /dev/mapper/encrypted_vol

# 挂载使用
sudo mkdir /mnt/encrypted
sudo mount /dev/mapper/encrypted_vol /mnt/encrypted

# 使用完后关闭
sudo umount /mnt/encrypted
sudo cryptsetup luksClose encrypted_vol
```

---

### 🟡 进阶版（适合有经验用户）

#### 全磁盘加密（FDE）配置

**使用 LUKS:**

```bash
# 1. 创建加密分区
sudo fdisk /dev/sdb

# 2. 初始化LUKS
sudo cryptsetup luksFormat /dev/sdb1

# 3. 打开加密卷
sudo cryptsetup luksOpen /dev/sdb1 encrypted_disk

# 4. 创建PV
sudo pvcreate /dev/mapper/encrypted_disk

# 5. 创建VG
sudo vgcreate vg_crypto /dev/mapper/encrypted_disk

# 6. 创建LV
sudo lvcreate -L 10G -n encrypted_data vg_crypto

# 7. 创建文件系统
sudo mkfs.ext4 /dev/vg_crypto/encrypted_data

# 8. 添加到/etc/crypttab
echo "encrypted_disk /dev/sdb1 none luks" | sudo tee -a /etc/crypttab

# 9. 添加到/etc/fstab
echo "/dev/mapper/vg_crypto-encrypted_data /mnt/encrypted ext4 defaults 0 2" | sudo tee -a /etc/fstab
```

#### TPM 2.0 集成（Secure Boot）

```bash
# 安装 TPM 工具
sudo apt install tpm2-tools trousers

# 检查 TPM 芯片
sudo tpm2_getcap properties-fixed

# 创建 TPM 绑定的密钥
sudo tpm2_createprimary --context /tmp/primary.ctx
sudo tpm2_create --context-parent /tmp/primary.ctx \
    --algorithm aes --key-alg rsa \
    --public /tmp/pub.key --private /tmp/priv.key

# 将密钥添加到 LUKS
sudo cryptsetup luksAddKey /dev/sdaX --key-file=/tmp/priv.key
```

#### 自动解锁配置

```bash
# 编辑 /etc/crypttab
sudo nano /etc/crypttab

# 添加配置
# 格式: name device key-file options
encrypted_disk UUID=xxxx none luks,keyscript=/bin/cat

# 使用密钥文件自动解锁
# 1. 创建密钥文件
sudo dd if=/dev/urandom of=/root/luks-keyfile bs=512 count=4
sudo chmod 600 /root/luks-keyfile

# 2. 添加到LUKS
sudo cryptsetup luksAddKey /dev/sdaX /root/luks-keyfile

# 3. 修改crypttab使用密钥
sudo nano /etc/crypttab
# encrypted_disk UUID=xxxx /root/luks-keyfile luks
```

---

### 🔴 专业版（适合安全专家）

#### 紧急恢复机制

```bash
#!/bin/bash
# LUKS 紧急恢复脚本

RECOVERY_FILE="/root/luks-recovery-$(date +%Y%m%d).txt"
DEVICE="/dev/sda1"

echo "=== LUKS Emergency Recovery Info ===" > "$RECOVERY_FILE"
echo "Date: $(date)" >> "$RECOVERY_FILE"
echo "Device: $DEVICE" >> "$RECOVERY_FILE"
echo "" >> "$RECOVERY_FILE"

# 保存LUKS头信息
sudo cryptsetup luksHeaderBackup "$DEVICE" \
    --header-backup-file /root/luks-header-backup.img

# 保存密钥槽信息
sudo cryptsetup luksDump "$DEVICE" >> "$RECOVERY_FILE"

# 创建紧急启动U盘脚本
cat > /root/emergency_unlock.sh << 'EOF'
#!/bin/bash
# 紧急解锁脚本

DEVICE="/dev/sda1"
MAPPER="encrypted_root"

# 解锁
cryptsetup luksOpen "$DEVICE" "$MAPPER"

# 挂载
mount /dev/mapper/"$MAPPER" /mnt

echo "System unlocked. Run 'mount -a' if needed."
EOF

chmod +x /root/emergency_unlock.sh

echo "Recovery info saved to: $RECOVERY_FILE"
echo "Header backup: /root/luks-header-backup.img"
```

#### 加密性能优化

```bash
# 检查CPU加密支持
cat /proc/crypto | grep -i aes

# 使用高性能加密算法（推荐）
# 编辑 /etc/crypttab
sudo nano /etc/crypttab
# 添加: luks,cipher=aes-xts-plain64,size=512,hash=sha512

# 或使用多核加速
# cryptsetup luksFormat --type luks2 --cipher=aes-xts-plain64 \
#     --key-size=512 --hash=sha512 --iter-time=5000 /dev/sdaX
```

#### 密钥派生优化

```bash
# 使用 Argon2i（更好的密钥派生）
# 注意：需要 cryptsetup 2.1+
sudo cryptsetup luksFormat --type luks2 \
    --key-file - /dev/sdaX <<< "yourpassword"

# 或使用 PBKDF2（兼容性更好）
sudo cryptsetup luksFormat --type luks1 \
    --pbkdf pbkdf2 --pbkdf-force-iterations 1000000 \
    /dev/sdaX
```

---

## ✅ 验证方法

```bash
# 检查加密状态
sudo cryptsetup isLuks /dev/sdaX
sudo blkid | grep crypto_LUKS

# 检查密钥槽
sudo cryptsetup luksDump /dev/sdaX

# 测试解锁
sudo cryptsetup luksOpen /dev/sdaX test_volume
sudo cryptsetup close test_volume

# 检查TPM状态
tpm2_getcap properties-fixed
```

---

## ⚠️ 重要警告

1. **备份始终重要** - 即使加密也会丢失数据
2. **密码必须记住** - 无法恢复遗忘的密码
3. **保留恢复密钥** - 存放在安全位置
4. **测试恢复流程** - 在真正需要前验证

---

**耗时**: 入门版15分钟 | 进阶版45分钟 | 专业版2小时
**难度**: ⭐⭐⭐ 复杂
**风险**: 🔴 高（可能导致数据丢失）

⚠️ **强烈建议**: 在生产环境操作前，先在测试环境充分测试！
