#!/usr/bin/env python3
"""
大乐透数据库初始化脚本
创建SQLite数据库和表结构
"""

import sqlite3
import os
from pathlib import Path

# 数据库文件路径
DB_PATH = Path(__file__).parent.parent / "data" / "super_lotto.db"

def init_database():
    """初始化数据库"""
    # 确保数据目录存在
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # 创建开奖记录表
    # 大乐透规则：
    # - 前区（红球）：从01-35中选择5个号码
    # - 后区（蓝球）：从01-12中选择2个号码
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS lottery_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            issue_number TEXT UNIQUE NOT NULL,      -- 期号（如26048表示2026年第48期）
            draw_date DATE NOT NULL,                -- 开奖日期
            front_ball_1 INTEGER NOT NULL,          -- 前区（红球）1
            front_ball_2 INTEGER NOT NULL,          -- 前区（红球）2
            front_ball_3 INTEGER NOT NULL,          -- 前区（红球）3
            front_ball_4 INTEGER NOT NULL,          -- 前区（红球）4
            front_ball_5 INTEGER NOT NULL,          -- 前区（红球）5
            back_ball_1 INTEGER NOT NULL,           -- 后区（蓝球）1
            back_ball_2 INTEGER NOT NULL,           -- 后区（蓝球）2
            pool_amount INTEGER,                    -- 奖池金额（分）
            sales_amount INTEGER,                   -- 销售金额（分）
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # 创建索引
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_issue_number ON lottery_records(issue_number)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_draw_date ON lottery_records(draw_date)')
    
    conn.commit()
    conn.close()
    
    print(f"✅ 数据库初始化成功: {DB_PATH}")
    return DB_PATH

if __name__ == "__main__":
    init_database()
