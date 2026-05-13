#!/usr/bin/env python3
"""
双色球数据库初始化脚本
创建SQLite数据库和表结构
"""

import sqlite3
import os
from pathlib import Path

# 数据库文件路径
DB_PATH = Path(__file__).parent.parent / "data" / "double_color_ball.db"

def init_database():
    """初始化数据库"""
    # 确保数据目录存在
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # 创建开奖记录表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS lottery_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            issue_number TEXT UNIQUE NOT NULL,      -- 期号
            draw_date DATE NOT NULL,                -- 开奖日期
            red_ball_1 INTEGER NOT NULL,            -- 红球1
            red_ball_2 INTEGER NOT NULL,            -- 红球2
            red_ball_3 INTEGER NOT NULL,            -- 红球3
            red_ball_4 INTEGER NOT NULL,            -- 红球4
            red_ball_5 INTEGER NOT NULL,            -- 红球5
            red_ball_6 INTEGER NOT NULL,            -- 红球6
            blue_ball INTEGER NOT NULL,             -- 蓝球
            sales_amount INTEGER,                    -- 销售金额（分）
            pool_amount INTEGER,                     -- 奖池金额（分）
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
