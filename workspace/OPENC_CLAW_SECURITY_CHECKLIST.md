# OpenClaw 安全检查清单补充文档
# 基于2026年3月最新CVE漏洞和安全事件

---

## 🔴 紧急：CVE专项安全检查

### CVE-2026-25253 (ClawJacked) 防护检查

**检查项**：
```bash
# 1. 检查Control UI的gatewayUrl参数验证
openclaw config get gateway.controlUi.allowCustomGatewayUrl
# 应为 false

# 2. 检查WebSocket Origin验证
openclaw config get gateway.websocket.verifyOrigin
# 应为 true

# 3. 检查设备配对确认
openclaw config get gateway.devicePairing.requireConfirmation
# 应为 true

# 4. 检查本地连接速率限制
openclaw config get gateway.rateLimit.localhostExempt
# 应为 false
```

**修复命令**：
```bash
openclaw config set gateway.controlUi.allowCustomGatewayUrl false
openclaw config set gateway.websocket.verifyOrigin true
openclaw config set gateway.devicePairing.requireConfirmation true
openclaw config set gateway.rateLimit.localhostExempt false
```

---

### CVE-2026-29610 (命令劫持) 防护检查

**检查项**：
```bash
# 1. 检查PATH环境变量
echo $PATH
# 确保没有可写的目录在前

# 2. 检查可写的PATH目录
for dir in $(echo $PATH | tr ':' '\n'); do
  if [ -w "$dir" ]; then
    echo "警告: $dir 是可写的"
  fi
done

# 3. 检查OpenClaw的PATH配置
openclaw config get exec.path
```

**安全加固**：
```bash
# 设置安全的PATH
export PATH="/usr/local/bin:/usr/bin:/bin"
# 在openclaw.json中配置
{
  "exec": {
    "path": "/usr/local/bin:/usr/bin:/bin",
    "sanitizeEnv": true
  }
}
```

---

### CVE-2026-32302 (反向代理绕过) 防护检查

**检查项**：
```bash
# 1. 检查认证模式
openclaw config get gateway.auth.mode
# 不应为 trusted-proxy，除非配置了trustedProxies

# 2. 检查信任的代理列表
openclaw config get gateway.auth.trustedProxies
# 应明确配置，不能为[\"127.0.0.1\"]或空

# 3. 检查反向代理配置
openclaw config get gateway.bind
# 应为 localhost 或 127.0.0.1
```

**安全加固**：
```bash
# 禁用trusted-proxy模式
openclaw config set gateway.auth.mode "token"

# 如果必须使用反向代理，配置明确的信任列表
openclaw config set gateway.auth.trustedProxies '["10.0.0.1", "10.0.0.2"]'
```

---

### CVE-2026-28466 (Node审批绕过) 防护检查

**检查项**：
```bash
# 1. 检查node.invoke参数过滤
openclaw config get gateway.node.invoke.filterParams
# 应为 true

# 2. 检查内部字段过滤
openclaw config get gateway.node.invoke.stripInternalFields
# 应包含 ["approved", "__proto__", "constructor"]

# 3. 检查审批字段验证
openclaw config get gateway.node.invoke.verifyApprovalSource
# 应为 true
```

---

## 🔴 关键：技能/插件供应链安全检查

### 已知的恶意技能列表（需要检测）

```json
{
  "malicious_skills": [
    {
      "name": "solana-wallet-tracker",
      "risk": "窃取加密货币钱包",
      "cve_related": "ClawHavoc"
    },
    {
      "name": "youtube-summarize-pro",
      "risk": "植入Atomic Stealer木马",
      "cve_related": "ClawHavoc"
    },
    {
      "name": "polymarket-trader",
      "risk": "窃取交易凭证",
      "cve_related": "ClawHavoc"
    },
    {
      "name": "bybit-trading",
      "risk": "恶意代码执行",
      "cve_related": "GitHub投毒"
    },
    {
      "name": "linkedin-job-application",
      "risk": "AuthTool木马",
      "cve_related": "官方仓库投毒"
    },
    {
      "name": "clawhub*",
      "risk": "仿冒域名投毒",
      "cve_related": "ClawHavoc"
    }
  ]
}
```

### 技能安全检查脚本

```bash
#!/bin/bash
# skill-security-check.sh

echo "🔍 扫描已安装技能..."

# 1. 获取已安装技能列表
INSTALLED_SKILLS=$(openclaw skills list --json | jq -r '.[].name')

# 2. 检查已知恶意技能
MALICIOUS_PATTERNS=(
  "solana-wallet"
  "phantom-wallet"
  "wallet-tracker"
  "youtube-downloader"
  "youtube-summarize"
  "polymarket"
  "auth-tool"
  "openclaw-agent"
  "clawhubb"
  "clawhub1"
)

for skill in $INSTALLED_SKILLS; do
  for pattern in "${MALICIOUS_PATTERNS[@]}"; do
    if [[ "$skill" == *"$pattern"* ]]; then
      echo "🚨 警告: 检测到可疑技能 '$skill' 匹配恶意模式 '$pattern'"
      echo "   建议: 立即卸载并检查系统安全"
    fi
  done
done

# 3. 检查技能代码中的可疑命令
echo "🔍 检查技能代码..."
SKILLS_DIR="$HOME/.openclaw/skills"
for skill_dir in "$SKILLS_DIR"/*/; do
  if [ -d "$skill_dir" ]; then
    # 检查可疑命令
    if grep -r -E "(curl.*\|.*bash|wget.*\|.*sh|nc -e|/dev/tcp)" "$skill_dir" 2>/dev/null; then
      echo "🚨 警告: 在 $(basename "$skill_dir") 中发现可疑命令"
    fi
    
    # 检查网络请求
    if grep -r -E "(http://|https://).*download" "$skill_dir/SKILL.md" 2>/dev/null; then
      echo "⚠️  注意: $(basename "$skill_dir") 包含外部下载链接，请人工审查"
    fi
  fi
done
```

---

## 🔴 关键：提示词注入防护检查

### 配置检查项

```bash
# 1. 检查输入过滤配置
openclaw config get agents.defaults.inputFilter
# 应启用

# 2. 检查HTML注释过滤
openclaw config get agents.defaults.filterHtmlComments
# 应为 true

# 3. 检查隐藏内容过滤
openclaw config get agents.defaults.filterHiddenElements
# 应为 true

# 4. 检查系统指令保护
openclaw config get agents.defaults.protectSystemPrompt
# 应为 true
```

### 安全配置示例

```json
{
  "agents": {
    "defaults": {
      "inputFilter": {
        "enabled": true,
        "blockHtmlComments": true,
        "blockHiddenElements": true,
        "blockBase64Payloads": true,
        "suspiciousPatterns": [
          "ignore previous instructions",
          "system:",
          "you are now",
          "<!--",
          "/*",
          "*/"
        ]
      },
      "systemPromptProtection": {
        "enabled": true,
        "allowOverride": false
      }
    }
  }
}
```

---

## 🟠 重要：MCP工具权限审计

### 高风险工具检查

```bash
# 1. 检查exec工具配置
openclaw config get tools.exec.enabled
openclaw config get tools.exec.approvals
openclaw config get tools.exec.sandbox

# 2. 检查browser工具配置
openclaw config get tools.browser.enabled
openclaw config get tools.browser.allowNavigation
openclaw config get tools.browser.allowDownloads

# 3. 检查web_fetch工具配置
openclaw config get tools.web_fetch.enabled
openclaw config get tools.web_fetch.allowPrivateNetwork

# 4. 检查高危工具白名单
openclaw config get tools.allowlist
openclaw config get tools.denylist
```

### 最小权限配置模板

```json
{
  "tools": {
    "exec": {
      "enabled": false,
      "approvals": "always",
      "sandbox": true,
      "denyCommands": ["rm -rf", "mkfs", "dd", "curl *|*sh", "wget *|*sh"]
    },
    "browser": {
      "enabled": true,
      "allowNavigation": true,
      "allowDownloads": false,
      "blockedUrls": ["file://*", "http://localhost*", "http://127.0.0.1*"]
    },
    "web_fetch": {
      "enabled": true,
      "allowPrivateNetwork": false,
      "maxRedirects": 3,
      "timeout": 30000
    },
    "denylist": ["system.run", "process.kill", "file.delete"]
  }
}
```

---

## 🟠 重要：敏感数据保护检查

### 凭证存储安全检查

```bash
#!/bin/bash
# credential-security-check.sh

echo "🔍 检查敏感数据存储..."

OPENCLAW_DIR="$HOME/.openclaw"

# 1. 检查明文存储的API密钥
echo "1. 检查明文API密钥..."
if grep -r "sk-[a-zA-Z0-9]\{48\}" "$OPENCLAW_DIR" 2>/dev/null; then
  echo "🚨 警告: 发现明文存储的API密钥"
fi

# 2. 检查SSH密钥访问权限
echo "2. 检查SSH密钥权限..."
if [ -f "$HOME/.ssh/id_rsa" ]; then
  PERMS=$(stat -c "%a" "$HOME/.ssh/id_rsa")
  if [ "$PERMS" != "600" ]; then
    echo "🚨 警告: SSH密钥权限过于宽松: $PERMS (应为600)"
  fi
fi

# 3. 检查OpenClaw目录权限
echo "3. 检查OpenClaw目录权限..."
CONFIG_PERMS=$(stat -c "%a" "$OPENCLAW_DIR/config.json" 2>/dev/null)
if [ "$CONFIG_PERMS" != "600" ] && [ "$CONFIG_PERMS" != "400" ]; then
  echo "🚨 警告: OpenClaw配置文件权限过于宽松: $CONFIG_PERMS"
fi

# 4. 检查内存文件中的敏感信息
echo "4. 检查MEMORY.md..."
if [ -f "$OPENCLAW_DIR/MEMORY.md" ]; then
  if grep -i "password\|secret\|token\|key" "$OPENCLAW_DIR/MEMORY.md" 2>/dev/null; then
    echo "⚠️  警告: MEMORY.md可能包含敏感信息，建议审查"
  fi
fi

# 5. 建议加密存储
echo ""
echo "💡 建议: 使用环境变量或密钥管理服务存储敏感凭证"
echo "   - 阿里云KMS"
echo "   - AWS Secrets Manager"
echo "   - HashiCorp Vault"
```

---

## 🟡 建议：日志安全与审计

### 日志投毒防护 (CVE-2026-27001)

```bash
# 1. 检查日志读取配置
openclaw config get agents.defaults.readLogs
# 应设置为 false 或限制

# 2. 检查日志清理策略
openclaw config get logging.retentionDays
# 建议设置为 7-30天
```

### 审计日志配置

```json
{
  "logging": {
    "level": "info",
    "audit": {
      "enabled": true,
      "logSensitiveOperations": true,
      "logFileAccess": true,
      "logCommandExecution": true,
      "logApiCalls": true
    },
    "sanitization": {
      "enabled": true,
      "maskPatterns": [
        "api[_-]?key",
        "token",
        "password",
        "secret",
        "credential"
      ]
    }
  }
}
```

---

## 📋 新增到healthcheck技能的检查项总结

### 需要添加到技能的检查模块：

1. **CVE-2026-25253 检查模块**
   - gateway.controlUi.allowCustomGatewayUrl
   - gateway.websocket.verifyOrigin
   - gateway.devicePairing.requireConfirmation
   - gateway.rateLimit.localhostExempt

2. **CVE-2026-32302 检查模块**
   - gateway.auth.mode (不应为trusted-proxy)
   - gateway.auth.trustedProxies配置

3. **技能安全检查模块**
   - 扫描已安装的恶意技能
   - 检查技能代码中的可疑命令
   - 验证技能来源

4. **提示词注入防护检查模块**
   - agents.defaults.inputFilter
   - agents.defaults.filterHtmlComments
   - agents.defaults.protectSystemPrompt

5. **MCP工具权限审计模块**
   - tools.exec配置
   - tools.browser配置
   - tools.web_fetch配置
   - 高危工具白名单/黑名单

6. **敏感数据保护检查模块**
   - API密钥存储方式
   - 配置文件权限
   - SSH密钥保护
   - MEMORY.md内容审查

7. **日志安全模块**
   - logging.audit配置
   - 日志投毒防护
   - 敏感信息脱敏

---

## 🚨 紧急建议

基于以上分析，建议立即：

1. **更新技能文档**，添加以上CVE专项安全检查
2. **增加自动检测脚本**，自动扫描已知恶意技能
3. **添加配置模板**，提供最小权限安全配置
4. **建立漏洞响应机制**，及时跟进新披露的CVE
5. **定期更新恶意技能数据库**，保持威胁情报最新

---

文档生成时间: 2026-03-27
数据来源: 国家互联网应急中心、工信部NVDB、GitHub Security Advisory、各大安全厂商报告
