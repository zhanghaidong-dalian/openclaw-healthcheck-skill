# 大乐透数据结构说明

## 数据库结构

### 表：lottery_records

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键（自增） |
| issue_number | TEXT | 期号（如26048表示2026年第48期） |
| draw_date | DATE | 开奖日期 |
| front_ball_1 | INTEGER | 前区（红球）1（1-35） |
| front_ball_2 | INTEGER | 前区（红球）2（1-35） |
| front_ball_3 | INTEGER | 前区（红球）3（1-35） |
| front_ball_4 | INTEGER | 前区（红球）4（1-35） |
| front_ball_5 | INTEGER | 前区（红球）5（1-35） |
| back_ball_1 | INTEGER | 后区（蓝球）1（1-12） |
| back_ball_2 | INTEGER | 后区（蓝球）2（1-12） |
| pool_amount | INTEGER | 奖池金额（元） |
| sales_amount | INTEGER | 销售金额（元） |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |

## 大乐透规则

- **前区（红球）**：从 1-35 中选择 5 个不重复的号码
- **后区（蓝球）**：从 1-12 中选择 2 个号码
- **开奖频率**：每周一、三、六

## 数据来源

**彩票500万网**
- URL: https://datachart.500.com/dlt/history/newinc/history.php
- 格式: HTML表格
- 支持查看最近30期、50期、100期

## 文件结构

```
super-lotto/
├── data/
│   └── super_lotto.db    # SQLite数据库
├── scripts/
│   ├── init_db.py        # 数据库初始化
│   ├── fetch_history.py  # 数据抓取
│   └── query.py          # 数据查询
└── references/
    └── data_structure.md # 本文档
```
