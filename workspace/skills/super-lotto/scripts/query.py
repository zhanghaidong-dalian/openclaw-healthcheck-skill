#!/usr/bin/env python3
"""
大乐透数据查询脚本
提供多种查询和分析功能
"""

import sqlite3
import sys
from pathlib import Path
from datetime import datetime
from collections import Counter

# 数据库路径
DB_PATH = Path(__file__).parent.parent / "data" / "super_lotto.db"


def query_latest(limit=10):
    """查询最新的开奖记录"""
    if not DB_PATH.exists():
        print("❌ 数据库不存在，请先运行 fetch_history.py 抓取数据")
        return
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT issue_number, draw_date,
               front_ball_1, front_ball_2, front_ball_3,
               front_ball_4, front_ball_5,
               back_ball_1, back_ball_2
        FROM lottery_records
        ORDER BY draw_date DESC
        LIMIT ?
    ''', (limit,))
    
    records = cursor.fetchall()
    conn.close()
    
    print(f"\n📊 最新 {len(records)} 期开奖结果:\n")
    print(f"{'期号':<10} {'日期':<12} {'前区（红球）':<30} {'后区（蓝球）':<10}")
    print("-" * 70)
    
    for record in records:
        issue, date, f1, f2, f3, f4, f5, b1, b2 = record
        front_balls = f"{f1:02d} {f2:02d} {f3:02d} {f4:02d} {f5:02d}"
        back_balls = f"{b1:02d} {b2:02d}"
        print(f"{issue:<10} {date:<12} {front_balls:<30} {back_balls:<10}")


def query_by_issue(issue_number):
    """按期号查询"""
    if not DB_PATH.exists():
        print("❌ 数据库不存在")
        return
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT issue_number, draw_date,
               front_ball_1, front_ball_2, front_ball_3,
               front_ball_4, front_ball_5,
               back_ball_1, back_ball_2,
               pool_amount, sales_amount
        FROM lottery_records
        WHERE issue_number = ?
    ''', (issue_number,))
    
    record = cursor.fetchone()
    conn.close()
    
    if record:
        issue, date, f1, f2, f3, f4, f5, b1, b2, pool, sales = record
        print(f"\n🎯 第 {issue} 期开奖结果:")
        print(f"   日期: {date}")
        print(f"   前区（红球）: {f1:02d} {f2:02d} {f3:02d} {f4:02d} {f5:02d}")
        print(f"   后区（蓝球）: {b1:02d} {b2:02d}")
        if pool:
            print(f"   奖池金额: {pool:,} 元")
        if sales:
            print(f"   销售金额: {sales:,} 元")
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
               front_ball_1, front_ball_2, front_ball_3,
               front_ball_4, front_ball_5,
               back_ball_1, back_ball_2
        FROM lottery_records
        WHERE draw_date BETWEEN ? AND ?
        ORDER BY draw_date DESC
    ''', (start_date, end_date))
    
    records = cursor.fetchall()
    conn.close()
    
    print(f"\n📅 {start_date} 至 {end_date} 开奖记录 ({len(records)} 期):\n")
    
    for record in records:
        issue, date, f1, f2, f3, f4, f5, b1, b2 = record
        front_balls = f"{f1:02d} {f2:02d} {f3:02d} {f4:02d} {f5:02d}"
        back_balls = f"{b1:02d} {b2:02d}"
        print(f"{issue:<10} {date:<12} {front_balls:<30} {back_balls:<10}")


def analyze_frequency(limit=100):
    """分析号码出现频率"""
    if not DB_PATH.exists():
        print("❌ 数据库不存在")
        return
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT front_ball_1, front_ball_2, front_ball_3,
               front_ball_4, front_ball_5,
               back_ball_1, back_ball_2
        FROM lottery_records
        ORDER BY draw_date DESC
        LIMIT ?
    ''', (limit,))
    
    records = cursor.fetchall()
    conn.close()
    
    if not records:
        print("❌ 没有数据")
        return
    
    # 统计前区（红球）频率
    front_counter = Counter()
    back_counter = Counter()
    
    for record in records:
        for i in range(5):
            front_counter[record[i]] += 1
        back_counter[record[5]] += 1
        back_counter[record[6]] += 1
    
    print(f"\n📊 最近 {limit} 期号码频率统计:\n")
    
    print("前区（红球）出现频率 TOP 10:")
    for ball, count in front_counter.most_common(10):
        freq = count / limit * 100
        print(f"  {ball:02d}号: {count}次 ({freq:.1f}%)")
    
    print("\n后区（蓝球）出现频率 TOP 5:")
    for ball, count in back_counter.most_common(5):
        freq = count / limit * 100
        print(f"  {ball:02d}号: {count}次 ({freq:.1f}%)")
    
    # 热号和冷号
    print("\n🔥 热号（高频）:")
    hot_front = [str(ball) for ball, _ in front_counter.most_common(7)]
    front_str = ' '.join(["{:02d}".format(int(x)) for x in hot_front])
    print(f"  前区: {front_str}")
    
    hot_back = [str(ball) for ball, _ in back_counter.most_common(3)]
    back_str = ' '.join(["{:02d}".format(int(x)) for x in hot_back])
    print(f"  后区: {back_str}")
    
    print("\n❄️ 冷号（低频）:")
    cold_front = [str(ball) for ball, _ in front_counter.most_common()[-7:]]
    cold_front_str = ' '.join(["{:02d}".format(int(x)) for x in cold_front])
    print(f"  前区: {cold_front_str}")
    
    cold_back = [str(ball) for ball, _ in back_counter.most_common()[-3:]]
    cold_back_str = ' '.join(["{:02d}".format(int(x)) for x in cold_back])
    print(f"  后区: {cold_back_str}")

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
    
    # 前区范围
    cursor.execute('''
        SELECT MIN(front_ball_1), MAX(front_ball_5)
        FROM lottery_records
    ''')
    min_front, max_front = cursor.fetchone()
    
    # 后区范围
    cursor.execute('SELECT MIN(back_ball_1), MAX(back_ball_2) FROM lottery_records')
    min_back, max_back = cursor.fetchone()
    
    conn.close()
    
    print("\n📈 数据统计:")
    print(f"  总记录数: {total} 期")
    print(f"  时间范围: {min_date} 至 {max_date}")
    print(f"  前区（红球）范围: {min_front} - {max_front}")
    print(f"  后区（蓝球）范围: {min_back} - {max_back}")


def main():
    """主函数"""
    if len(sys.argv) < 2:
        print("大乐透数据查询工具")
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
