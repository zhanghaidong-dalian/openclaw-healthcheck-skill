---
name: double-color-ball
description: 双色球历史数据抓取、存储和分析技能。用于查询彩票网站、抓取历史开奖数据（红球+蓝球）、存储到本地数据库、进行数据分析和频率统计、生成号码预测。触发词：双色球、彩票、开奖、彩票预测、历史数据、中奖号码、彩票分析。
---

# 双色球数据抓取与分析预测

## 概述

此技能提供双色球历史开奖数据的抓取、存储、查询分析和号码预测能力。支持从官方彩票网站抓取完整历史数据，存储到本地SQLite数据库，提供频率分析、热冷号统计，并基于多种策略生成预测号码。

## 快速开始

### 1. 初始化数据库（首次使用）

```bash
python scripts/init_db.py
```

### 2. 抓取历史数据

```bash
# 使用官方数据源（推荐）
python scripts/fetch_history.py cwl

# 使用500彩票网数据源
python scripts/fetch_history.py 500com
```

### 3. 生成预测

```bash
# 生成所有策略的预测（推荐）
python scripts/predict.py

# 查看详细统计
python scripts/predict.py --stats

# 生成3组热号策略预测
python scripts/predict.py --strategy hot --count 3

# 使用最近100期数据预测
python scripts/predict.py --history 100
```

## 预测模型

### 预测策略

| 策略 | 说明 | 适用场景 |
|------|------|----------|
| 🔥 **热号策略** | 选择历史出现频率最高的号码 | 追热号 |
| ❄️ **冷号策略** | 选择历史出现频率最低的号码 | 追冷号 |
| 📈 **遗漏策略** | 选择很久未出现的号码 | 追遗漏 |
| ⚖️ **均衡策略** | 热号+冷号+遗漏混合 | 平衡风险 |
| 🤖 **ML加权策略** | 频率40%+遗漏60%加权评分 | 智能推荐 |

### 预测命令

```bash
# 生成1组预测（默认所有策略）
python scripts/predict.py

# 生成5组热号预测
python scripts/predict.py --strategy hot --count 5

# 生成5组冷号预测
python scripts/predict.py --strategy cold --count 5

# 生成5组遗漏策略预测
python scripts/predict.py --strategy missing --count 5

# 生成5组均衡策略预测
python scripts/predict.py --strategy balanced --count 5

# 生成5组ML加权策略预测
python scripts/predict.py --strategy ml --count 5

# 显示详细统计信息
python scripts/predict.py --stats

# 使用最近100期数据预测
python scripts/predict.py --history 100
```

## 使用场景

### 场景1：获取最新预测

用户："双色球预测"

操作步骤：
1. 运行 `python scripts/predict.py`
2. 选择喜欢的策略组合

### 场景2：查看统计信息

用户："分析一下双色球的热门号码"

操作步骤：
```bash
python scripts/predict.py --stats
```

会输出：
- 红球号码频率柱状图 TOP 10
- 蓝球号码频率柱状图
- 遗漏排行榜（红球）

### 场景3：抓取最新数据

用户："帮我更新双色球数据"

操作步骤：
```bash
python scripts/fetch_history.py cwl
```

## 双色球规则

- **红球**：从 01-33 中选择 6 个不重复的号码
- **蓝球**：从 01-16 中选择 1 个号码
- **开奖频率**：每周二、四、日

## 数据源

### 中国福利彩票网（推荐）

- **URL**: https://www.cwl.gov.cn
- **优势**: 官方数据源，准确可靠

### 500彩票网

- **URL**: https://datachart.500.com

## 工作流程

```
┌─────────────┐
│ 初始化数据库 │ → python scripts/init_db.py
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  抓取数据    │ → python scripts/fetch_history.py cwl
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  预测分析    │ → python scripts/predict.py
└─────────────┘
```

## 脚本说明

### predict.py（新增）

- 基于历史数据的多策略预测模型
- 支持5种预测策略
- 生成频率统计和遗漏分析
- 蓝球号码智能推荐

### init_db.py

- 初始化SQLite数据库
- 创建表结构和索引

### fetch_history.py

- 从彩票网站抓取历史数据
- 支持多个数据源

### query.py

- 提供多种查询功能
- 支持频率分析

## 数据库表：lottery_records

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| issue_number | TEXT | 期号（如 2026050） |
| draw_date | DATE | 开奖日期 |
| red_ball_1~6 | INTEGER | 红球号码（1-33） |
| blue_ball | INTEGER | 蓝球号码（1-16） |

## ⚠️ 免责声明

彩票开奖是完全随机的概率事件，历史数据分析和任何预测模型都无法保证中奖。本技能提供的预测仅供参考娱乐，请理性购彩，量力而行。

## 与大乐透的区别

| 彩票类型 | 红球 | 蓝球 |
|---------|------|------|
| 双色球 | 6个（1-33） | 1个（1-16） |
| 大乐透 | 5个（1-35） | 2个（1-12） |
