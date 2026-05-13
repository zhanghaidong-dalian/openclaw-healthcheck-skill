#!/usr/bin/env python3
"""
双色球数据查询脚本
提供多种查询和分析功能
"""

import sqlite3
import sys
from pathlib import Path
from datetime import datetime, timedelta
from collections import Counter

# 数据库路径
DB_PATH = Path(__file__).parent.parent / "data" / "double_color_ball.db"


def query_latest(limit=10):
    """查询最新的开奖记录"""
    if not DB_PATH.exists():
        print("❌ 数据库不存在，请先运行 fetch_history.py 抓取数据")
        return
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT issue_number, draw_date,
               red_ball_1, red_ball_2, red_ball_3,
               red_ball_4, red_ball_5, red_ball_6,
               blue_ball
        FROM lottery_records
        ORDER BY draw_date DESC
        LIMIT ?
    ''', (limit,))
    
    records = cursor.fetchall()
    conn.close()
    
    print(f"\n📊 最新 {len(records)} 期开奖结果:\n")
    print(f"{'期号':<12} {'日期':<12} {'红球':<25} {'蓝球':<6}")
    print("-" * 60)
    
    for record in records:
        issue, date, r1, r2, r3, r4, r5, r6, blue = record
        red_balls = f"{r1:02d} {r2:02d} {r3:02d} {r4:02d} {r5:02d} {r6:02d}"
        print(f"{issue:<12} {date:<12} {red_balls:<25} {blue:02d}")


def query_by_issue(issue_number):
    """按期号查询"""
    if not DB_PATH.exists():
        print("❌ 数据库不存在")
        return
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT issue_number, draw_date,
               red_ball_1, red_ball_2, red_ball_3,
               red_ball_4, red_ball_5, red_ball_6,
               blue_ball
        FROM lottery_records
        WHERE issue_number = ?
    ''', (issue_number,))
    
    record = cursor.fetchone()
    conn.close()
    
    if record:
        issue, date, r1, r2, r3, r4, r5, r6, blue = record
        print(f"\n🎯 第 {issue} 期开奖结果:")
        print(f"   日期: {date}")
        print(f"   红球: {r1:02d} {r2:02d} {r3:02d} {r4:02d} {r5:02d} {r6:02d}")
        print(f"   蓝球: {blue:02d}")
    else:
        print(f"❌ 未找到第 {issue_number} 期记录")


def query_by_date(start_date, end_date):
    """按日期范围查询"""
    if not DB_PATH.exists():
        print("❌ 数据库不存在")
        return
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT issue_number, draw_date,
               red_ball_1, red_ball_2, red_ball_3,
               red_ball_4, red_ball_5, red_ball_6,
               blue_ball
        FROM lottery_records
        WHERE draw_date BETWEEN ? AND ?
        ORDER BY draw_date DESC
    ''', (start_date, end_date))
    
    records = cursor.fetchall()
    conn.close()
    
    print(f"\n📅 {start_date} 至 {end_date} 开奖记录 ({len(records)} 期):\n")
    
    for record in records:
        issue, date, r1, r2, r3, r4, r5, r6, blue = record
        red_balls = f"{r1:02d} {r2:02d} {r3:02d} {r4:02d} {r5:02d} {r6:02d}"
        print(f"{issue:<12} {date:<12} {red_balls:<25} {blue:02d}")


def analyze_frequency(limit=100):
    """分析号码出现频率"""
    if not DB_PATH.exists():
        print("❌ 数据库不存在")
        return
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT red_ball_1, red_ball_2, red_ball_3,
               red_ball_4, red_ball_5, red_ball_6,
               blue_ball
        FROM lottery_records
        ORDER BY draw_date DESC
        LIMIT ?
    ''', (limit,))
    
    records = cursor.fetchall()
    conn.close()
    
    if not records:
        print("❌ 没有数据")
        return
    
    # 统计红球频率
    red_counter = Counter()
    blue_counter = Counter()
    
    for record in records:
        for i in range(6):
            red_counter[record[i]] += 1
        blue_counter[record[6]] += 1
    
    print(f"\n📊 最近 {limit} 期号码频率统计:\n")
    
    print("红球出现频率 TOP 10:")
    for ball, count in red_counter.most_common(10):
        freq = count / limit * 100
        print(f"  {ball:02d}号: {count}次 ({freq:.1f}%)")
    
    print("\n蓝球出现频率 TOP 5:")
    for ball, count in blue_counter.most_common(5):
        freq = count / limit * 100
        print(f"  {ball:02d}号: {count}次 ({freq:.1f}%)")
    
    # 热号和冷号
    print("\n🔥 热号（高频）:")
    hot_red = [str(ball) for ball, _ in red_counter.most_common(7)]
    print(f"  红球: {' '.join([f'{int(x):02d}' for x in hot_red])}")
    
    hot_blue = [str(ball) for ball, _ in blue_counter.most_common(3)]
    print(f"  蓝球: {' '.join([f'{int(x):02d}' for x in hot_blue])}")
    
    print("\n❄️ 冷号（低频）:")
    cold_red = [str(ball) for ball, _ in red_counter.most_common()[-7:]]
    print(f"  红球: {' '.join([f'{int(x):02d}' for x in cold_red])}")
    
    cold_blue = [str(ball) for ball, _ in blue_counter.most_common()[-3:]]
    print(f"  蓝球: {' '.join([f'{int(x):02d}' for x in cold_blue])}")


def statistics():
    """数据统计"""
    if not DB_PATH.exists():
        print("❌ 数据库不存在")
        return
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # 总记录数
    cursor.execute('SELECT COUNT(*) FROM lottery_records')
    total = cursor.fetchone()[0]
    
    # 日期范围
    cursor.execute('SELECT MIN(draw_date), MAX(draw_date) FROM lottery_records')
    min_date, max_date = cursor.fetchone()
    
    # 红球范围
    cursor.execute('''
        SELECT MIN(red_ball_1), MAX(red_ball_6)
        FROM lottery_records
    ''')
    min_red, max_red = cursor.fetchone()
    
    # 蓝球范围
    cursor.execute('SELECT MIN(blue_ball), MAX(blue_ball) FROM lottery_records')
    min_blue, max_blue = cursor.fetchone()
    
    conn.close()
    
    print("\n📈 数据统计:")
    print(f"  总记录数: {total} 期")
    print(f"  时间范围: {min_date} 至 {max_date}")
    print(f"  红球范围: {min_red} - {max_red}")
    print(f"  蓝球范围: {min_blue} - {max_blue}")


def main():
    """主函数"""
    if len(sys.argv) < 2:
        print("双色球数据查询工具")
        print("\n用法:")
        print("  python query.py latest [数量]        - 查询最新开奖")
        print("  python query.py issue <期号>         - 按期号查询")
        print("  python query.py date <开始> <结束>   - 按日期查询")
        print("  python query.py analyze [数量]       - 分析号码频率")
        print("  python query.py stats                - 数据统计")
        return
    
    command = sys.argv[1]
    
    if command == "latest":
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 10
        query_latest(limit)
    
    elif command == "issue":
        if len(sys.argv) < 3:
            print("❌ 请指定期号")
            return
        query_by_issue(sys.argv[2])
    
    elif command == "date":
        if len(sys.argv) < 4:
            print("❌ 请指定开始和结束日期")
            return
        query_by_date(sys.argv[2], sys.argv[3])
    
    elif command == "analyze":
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 100
        analyze_frequency(limit)
    
    elif command == "stats":
        statistics()
    
    else:
        print(f"❌ 未知命令: {command}")


if __name__ == "__main__":
    main()
