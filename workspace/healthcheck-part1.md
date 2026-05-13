---
name: healthcheck
description: OpenClaw 主机安全加固与风险评估工具。适用于安全审计、防火墙/SSH加固、更新管理、风险暴露检查、定时监控等场景。支持 VPS、云服务器、本地工作站、Docker 容器、沙盒环境等多种部署形态。
keywords: [security, audit, hardening, firewall, ssh, update, cron, 安全, 审计, 加固, 防火墙]
author: OpenClaw Community
version: 4.2.0
language: zh-CN, en
tags: [security, system, maintenance]
---

# OpenClaw 主机安全加固指南 | Host Hardening Guide

> 🛡️ **让每一台 OpenClaw 主机都安全可控**
>
> 支持环境：VPS/云服务器 | 本地工作站 | Docker 容器 | 沙盒环境（扣子/Coze）
>
> 语言：中文 | English

## 概述 | Overview

对运行 OpenClaw 的主机进行**全面安全评估和加固**，集成**2026年3月最新威胁情报**，专项检测已发现在野利用的CVE漏洞（CVE-2026-25253等12个高危漏洞）、恶意技能/插件供应链风险、提示词注入攻击防护等。根据用户定义的风险承受能力进行调整，同时确保不中断正常访问。

## 🚀 5分钟快速上手 | Quick Start

> ⏱️ **预计耗时**：5分钟  
> 📋 **适用场景**：首次使用、日常快速检查

### 最简单的使用方法

```bash
# 1. 运行快速安全检查（5-8秒）
healthcheck --mode quick

# 2. 查看结果
# 技能会自动输出安全状态报告
```

### 快速检查清单（无需技能）

如果只想快速检查，可以直接运行以下命令：

```bash
# 检查 OpenClaw 状态
openclaw status

# 检查版本更新
openclaw update status

# 运行安全审计
openclaw security audit --deep
```

### 需要修复？

```bash
# 自动修复 Critical 问题
openclaw security audit --fix --severity=critical
```

> 💡 **提示**：首次使用建议先运行 `healthcheck --mode quick`，根据结果再决定是否需要深度检查。

### 🚨 紧急安全提醒（2026年3月）

```
⚠️ 当前威胁态势：
• 全球46.9万OpenClaw实例暴露，27%存在高危漏洞
• CVE-2026-25253 (ClawJacked) 已发现在野大规模利用
• ClawHub技能市场12%为恶意技能（超1,184个）
• 朝鲜APT37、Kimsuky，俄罗斯APT28等正在积极攻击

✅ 本技能覆盖：
• 12个CVE高危漏洞专项检查
• 恶意技能自动扫描与清除
• 提示词注入防护检测
• MCP工具权限审计
• 敏感数据泄露防护
```

### 🎯 典型使用场景

**场景1：新部署 VPS 初始化**
```
用户：我刚买了一台阿里云 VPS，要部署 OpenClaw，帮我做安全加固
→ 检测环境：VPS/云服务器
→ 执行：CVE漏洞检查 + 防火墙配置 + SSH加固 + OpenClaw配置 + 定时审计
```

**场景2：CVE紧急响应**
```
用户：听说OpenClaw有严重漏洞，帮我检查一下
→ 执行：CVE-2026-25253/32302/28466等专项检查
→ 发现：X个高危漏洞需要修复
→ 修复：一键修复配置漏洞，升级版本
```

**场景3：恶意技能排查**
```
用户：我安装了一些技能，帮我检查是否安全
→ 执行：扫描已安装技能
