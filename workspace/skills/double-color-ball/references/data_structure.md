# 双色球数据结构说明

## 数据库结构

### 表：lottery_records

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键（自增） |
| issue_number | TEXT | 期号（唯一） |
| draw_date | DATE | 开奖日期 |
| red_ball_1 | INTEGER | 红球1（1-33） |
| red_ball_2 | INTEGER | 红球2（1-33） |
| red_ball_3 | INTEGER | 红球3（1-33） |
| red_ball_4 | INTEGER | 红球4（1-33） |
| red_ball_5 | INTEGER | 红球5（1-33） |
| red_ball_6 | INTEGER | 红球6（1-33） |
| blue_ball | INTEGER | 蓝球（1-16） |
| sales_amount | INTEGER | 销售金额（分） |
| pool_amount | INTEGER | 奖池金额（分） |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |

## 双色球规则

- **红球**：从 1-33 中选择 6 个不重复的号码
- **蓝球**：从 1-16 中选择 1 个号码
- **开奖频率**：每周二、四、日

## 数据来源

1. **中国福利彩票网**（推荐）
   - 官方数据源
   - JSON API 接口
   - 支持分页查询

2. **500彩票网**
   - 第三方数据源
   - HTML 解析

## 文件结构

```
double-color-ball/
├── data/
│   └── double_color_ball.db    # SQLite数据库
├── scripts/
│   ├── init_db.py              # 数据库初始化
│   ├── fetch_history.py        # 数据抓取
│   └── query.py                # 数据查询
└── references/
    └── data_structure.md       # 本文档
```
