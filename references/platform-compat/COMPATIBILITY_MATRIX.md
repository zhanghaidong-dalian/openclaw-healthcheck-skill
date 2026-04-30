# 平台兼容性说明

## 兼容性总览

| 平台 | 推荐模式 | 功能完整度 | 自动修复 | 说明 |
|------|----------|----------|---------|------|
| OpenClaw 本地 | Shell | 100% | ✅ | 完整功能，推荐使用 |
| Coze 扣子 | Agent | 60% | ❌ | 无 exec 权限，只能使用 Python 工具 |
| Dify | Agent | 60% | ❌ | 沙盒环境，禁止 shell 执行 |
| 腾讯混元 | Agent | 60% | ❌ | 受限环境 |
| 自托管 Gateway | Shell | 100% | ✅ | 需安装 openclaw CLI |
| LangChain | Agent | 60% | ❌ | Python 环境优先 |

## 模式详细对比

### Shell 模式（完整功能）

**适用环境：**
- ✅ OpenClaw 本地运行
- ✅ 自托管 Gateway（有 exec 权限）
- ✅ 任何支持 bash 执行的环境

**可用功能：**
| 功能类别 | 说明 | 文件位置 |
|---------|------|---------|
| 分层扫描 | 轻量/深度/智能三层扫描 | `scripts/layered-scanner.sh` |
| 规则引擎 | 23+ 个安全规则 | `rules/*.yaml` |
| 自动修复 | 分级自动修复 + 回滚 | `scripts/auto-fixer-v2.sh` |
| 定时巡检 | Cron 定时任务管理 | `scripts/cron-manager.sh` |
| 报告生成 | 结构化报告导出 | `scripts/report-generator.sh` |
| 向导模式 | 交互式配置向导 | `scripts/wizard.sh` |

**示例调用：**
```bash
# 运行完整扫描
./scripts/layered-scanner.sh --mode deep

# 自动修复
./scripts/auto-fixer-v2.sh --auto-fix --backup

# 查看报告
cat reports/security-report-20260430.md
```

### Agent 模式（兼容受限平台）

**适用环境：**
- ✅ Coze 扣子（无 exec 权限）
- ✅ Dify（沙盒环境）
- ✅ 其他受限 Agent 平台

**可用功能：**
| 功能类别 | 说明 | 文件位置 |
|---------|------|---------|
| 基础扫描 | Python 安全扫描器 | `agent/scanner.py` |
| 规则解析 | YAML 规则解析器 | `agent/rule_parser.py` |
| 报告生成 | JSON/Markdown 报告 | `agent/report_gen.py` |
| CVE 检查 | 5+ 个 CVE 规则 | `rules/cve-*.yaml` |

**示例调用：**
```python
# Python 代码调用
from agent.scanner import SecurityScanner

scanner = SecurityScanner()
rules = scanner.load_rules()
scanner.run_checks()
report = scanner.generate_report(format='json')
```

## 平台特定说明

### Coze 扣子

**环境限制：**
- ❌ 无法执行 shell 脚本
- ❌ 无法调用 `exec` 或 `process` 工具
- ✅ 支持 Python 代码执行

**推荐配置：**
```
技能配置:
- 模式: Agent (Python)
- 版本: 4.9.0+
- 依赖: Python 3.7+
```

**调用示例：**
```python
# 在 Coze 工作流中
import sys
sys.path.insert(0, '/workspace/projects/workspace/healthcheck-skill')

from agent.scanner import SecurityScanner

scanner = SecurityScanner()
scanner.main()
```

### Dify

**环境限制：**
- ❌ 禁止系统命令执行
- ✅ 支持 Python 代码节点
- ✅ 支持文件读写

**推荐配置：**
```
Workflow:
- Code Node: Python 3.10+
- Variables: rules_dir, output_format
```

### 腾讯混元

**环境限制：**
- ❌ 无系统级权限
- ✅ 支持 Python 脚本
- ⚠️ 部分函数库可能受限

**推荐配置：**
```
技能包:
- 运行时: Python 3.9+
- 权限: 基础 (无系统调用)
```

## 选择建议

### 场景 1: OpenClaw 本地用户

**推荐：Shell 模式**
- 完整功能（100%）
- 自动修复和回滚
- 最佳用户体验

### 场景 2: Coze 扣子用户

**推荐：Agent 模式**
- 无 exec 权限，无法运行 Shell 脚本
- 使用 Python 工具可获得 60% 功能
- 可以检测和报告，但需手动修复

### 场景 3: Dify 用户

**推荐：Agent 模式**
- 沙盒环境限制
- 使用 Python 工作流
- 配合 Code Node 使用

### 场景 4: 自托管 Gateway

**推荐：Shell 模式**
- 完整 OpenClaw 环境
- 支持 exec 和 process 工具
- 推荐用于生产环境

## 故障排查

### 问题 1: Agent 模式扫描无输出

**可能原因：**
- Python 版本过低 (< 3.7)
- 规则目录路径错误

**解决方案：**
```bash
# 检查 Python 版本
python3 --version

# 检查规则目录
ls -la rules/
```

### 问题 2: Shell 模式无法执行

**可能原因：**
- 缺少执行权限
- 依赖工具未安装

**解决方案：**
```bash
# 添加执行权限
chmod +x scripts/*.sh

# 安装依赖（以 Ubuntu 为例）
apt install ufw fail2ban openssh-server
```

### 问题 3: 平台不支持任意模式

**建议：**
1. 使用平台的专用安全检查工具
2. 联系平台管理员确认环境配置
3. 考虑迁移到 OpenClaw 本地环境

## 更新日志

- **v4.9.0** (2026-04-30)
  - 新增 Agent 模式 Python 工具
  - 增加 5 个 CVE 检查规则
  - 完善平台兼容性矩阵
  - 更新 SKILL.md 使用要求章节