# 🚀 立即发布命令

## 第一步：发布包已准备 ✅

```bash
# 发布包位置
ls -lh /workspace/projects/workspace/healthcheck-skill-v2.1.0.tar.gz

# 查看发布包内容
tar -tzf /workspace/projects/workspace/healthcheck-skill-v2.1.0.tar.gz
```

---

## 第二步：创建GitHub仓库并推送

```bash
cd /workspace/projects/workspace/healthcheck-skill

# 1. 初始化Git
git init

# 2. 添加所有文件
git add .

# 3. 提交
git commit -m "feat: release v2.1.0 - Security Emergency Update

🔴 CVE-2026-25253 (ClawJacked) detection
🦠 Malicious skill scanning (1,184 skills)
💉 Prompt injection protection
🛠️ MCP tool permission audit
🔐 Sensitive data protection
📚 1,477 lines documentation"

# 4. 添加远程仓库（替换YOUR_USERNAME）
git remote add origin https://github.com/YOUR_USERNAME/openclaw-healthcheck.git

# 5. 推送到GitHub
git branch -M main
git push -u origin main
```

---

## 第三步：创建GitHub Release

1. **访问你的GitHub仓库**
   ```
   https://github.com/YOUR_USERNAME/openclaw-healthcheck/releases/new
   ```

2. **填写Release信息**：

   ```
   Tag version: v2.1.0
   Release title: v2.1.0 - Security Emergency Update

   Release notes:
   🛡️ OpenClaw 主机安全加固与风险评估工具

   ⚠️ 紧急安全更新：
   - CVE-2026-25253 (ClawJacked) 已大规模在野利用
   - ClawHub技能市场12%为恶意技能（1,184个）
   - 全球46.9万实例暴露，27%存在高危漏洞

   ✨ 核心特性：
   - 12个CVE高危漏洞专项检测
   - 1,184个已知恶意技能数据库
   - 提示词注入防护检测
   - MCP工具权限审计
   - 敏感数据泄露防护

   🚀 快速开始：
   openclaw skills install https://github.com/YOUR_USERNAME/openclaw-healthcheck.git
   healthcheck --deep

   📚 详细文档：
   https://github.com/YOUR_USERNAME/openclaw-healthcheck/blob/main/SKILL.md
   ```

3. **上传发布文件**：
   - 点击 "Attach binaries"
   - 选择 `/workspace/projects/workspace/healthcheck-skill-v2.1.0.tar.gz`

4. **点击 "Publish release"**

---

## 用户安装方式

发布后，用户可以通过以下方式安装：

```bash
# 方式1：通过Git URL
openclaw skills install https://github.com/YOUR_USERNAME/openclaw-healthcheck.git

# 方式2：下载发布包
wget https://github.com/YOUR_USERNAME/openclaw-healthcheck/releases/download/v2.1.0/healthcheck-skill-v2.1.0.tar.gz
openclaw skills install healthcheck-skill-v2.1.0.tar.gz
```

---

## 社区推广文案（可直接复制）

### 标题
🛡️ OpenClaw安全技能v2.1.0发布：一键检测CVE-2026-25253等12个高危漏洞

### 正文
当前OpenClaw面临严峻安全威胁：
- ⚠️ 全球46.9万实例暴露，27%存在高危漏洞
- ⚠️ CVE-2026-25253 (ClawJacked) 已大规模在野利用
- ⚠️ ClawHub技能市场12%为恶意技能（1,184个）

OpenClaw Healthcheck Skill v2.1.0提供：
✅ 12个CVE高危漏洞专项检测（含ClawJacked）
✅ 1,184个已知恶意技能数据库
✅ 提示词注入防护检测
✅ MCP工具权限审计
✅ 敏感数据泄露防护

立即安装保护你的OpenClaw：
```bash
openclaw skills install https://github.com/YOUR_USERNAME/openclaw-healthcheck.git
healthcheck --deep
```

📚 详细文档：https://github.com/YOUR_USERNAME/openclaw-healthcheck

---

## 发布后立即检查

```bash
# 1. 验证发布包可以安装
openclaw skills install healthcheck-skill-v2.1.0.tar.gz

# 2. 验证技能功能
healthcheck --cve-check
healthcheck --skill-scan

# 3. 查看已安装技能
openclaw skills list | grep healthcheck
```

---

## 📦 所有发布文件

```
/workspace/projects/workspace/
├── healthcheck-skill-v2.1.0.tar.gz      ⭐ 发布包
├── RELEASE_ANNOUNCEMENT.md              发布公告
├── PUBLISH_GUIDE.md                     发布指南
├── TEST_REPORT.md                       测试报告
└── healthcheck-skill/                   源代码目录
```

---

## 🎯 快速链接

- **GitHub仓库创建**: https://github.com/new
- **Release创建**: https://github.com/YOUR_USERNAME/openclaw-healthcheck/releases/new
- **README模板**: /workspace/projects/workspace/healthcheck-skill/README.md
- **更新日志**: /workspace/projects/workspace/healthcheck-skill/CHANGELOG.md

---

## 🎉 开始发布！

替换以下内容后立即开始：

```
YOUR_USERNAME → 你的GitHub用户名
```

然后依次执行上面的命令即可！

---

**祝发布成功！** 🚀🛡️🍀

