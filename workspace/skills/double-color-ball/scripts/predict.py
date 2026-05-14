#!/usr/bin/env python3
"""
双色球预测模型
基于历史数据频率分析和遗漏值统计生成推荐号码
支持单式投注和复式投注
"""

import sqlite3
import random
from collections import Counter
from itertools import combinations
from datetime import datetime
import argparse

DB_PATH = 'data/double_color_ball.db'

def get_connection():
    """获取数据库连接"""
    return sqlite3.connect(DB_PATH)

def get_all_records(limit=None):
    """获取所有开奖记录"""
    conn = get_connection()
    cursor = conn.cursor()
    if limit:
        cursor.execute(f'''
            SELECT * FROM lottery_records 
            ORDER BY issue_number DESC 
            LIMIT {limit}
        ''')
    else:
        cursor.execute('SELECT * FROM lottery_records ORDER BY issue_number DESC')
    records = cursor.fetchall()
    conn.close()
    return records

def analyze_red_balls(records):
    """分析红球号码（1-33）频率"""
    red_balls = []
    for record in records:
        # 红球是 record[3:9]
        red_balls.extend(record[3:9])
    return Counter(red_balls)

def analyze_blue_balls(records):
    """分析蓝球号码（1-16）频率"""
    blue_balls = []
    for record in records:
        # 蓝球是 record[9]
        blue_balls.append(record[9])
    return Counter(blue_balls)

def calculate_missing(records, ball_type='red'):
    """计算号码遗漏期数"""
    conn = get_connection()
    cursor = conn.cursor()
    
    if ball_type == 'red':
        max_ball = 33
        cols = ['red_ball_1', 'red_ball_2', 'red_ball_3', 'red_ball_4', 'red_ball_5', 'red_ball_6']
        placeholders = ' OR '.join([f'{c}=?' for c in cols])
    else:
        max_ball = 16
        placeholders = 'blue_ball=?'
    
    cursor.execute('SELECT issue_number FROM lottery_records ORDER BY issue_number DESC')
    issues = [row[0] for row in cursor.fetchall()]
    latest_issue = int(issues[0]) if issues else 0
    
    missing = {}
    for ball in range(1, max_ball + 1):
        if ball_type == 'red':
            cursor.execute(f'''
                SELECT issue_number FROM lottery_records 
                WHERE {placeholders}
                ORDER BY issue_number DESC
                LIMIT 1
            ''', (ball,)*6)
        else:
            cursor.execute(f'''
                SELECT issue_number FROM lottery_records 
                WHERE {placeholders}
                ORDER BY issue_number DESC
                LIMIT 1
            ''', (ball,))
        
        result = cursor.fetchone()
        if result:
            missing[ball] = latest_issue - int(result[0])
        else:
            missing[ball] = latest_issue
    
    conn.close()
    return missing

def generate_hot_red_prediction(records, count=6):
    """基于热号生成预测（红球）"""
    red_freq = analyze_red_balls(records)
    hot_balls = red_freq.most_common(count)
    return [ball for ball, freq in hot_balls]

def generate_cold_red_prediction(records, count=6):
    """基于冷号生成预测（红球）"""
    red_freq = analyze_red_balls(records)
    all_balls = set(range(1, 34))
    appeared = set(red_freq.keys())
    never_appeared = all_balls - appeared
    
    if len(red_freq) >= count:
        cold_balls = [ball for ball, freq in red_freq.most_common()[-count:]]
    else:
        cold_balls = []
    
    result = cold_balls + list(never_appeared)
    return result[:count]

def generate_missing_red_prediction(records, count=6):
    """基于遗漏值生成预测（红球）"""
    missing = calculate_missing(records, 'red')
    sorted_missing = sorted(missing.items(), key=lambda x: x[1], reverse=True)
    return [ball for ball, days in sorted_missing[:count]]

def generate_balanced_red_prediction(records):
    """生成均衡型红球预测"""
    hot = generate_hot_red_prediction(records, 2)
    cold = generate_cold_red_prediction(records, 2)
    missing = generate_missing_red_prediction(records, 2)
    
    combined = hot + cold + missing
    seen = set()
    result = []
    for ball in combined:
        if ball not in seen and len(result) < 6:
            seen.add(ball)
            result.append(ball)
    
    while len(result) < 6:
        ball = random.randint(1, 33)
        if ball not in seen:
            seen.add(ball)
            result.append(ball)
    
    return sorted(result)

def generate_ml_red_prediction(records):
    """基于加权评分的红球预测"""
    red_freq = analyze_red_balls(records)
    missing = calculate_missing(records, 'red')
    
    max_freq = max(red_freq.values()) if red_freq else 1
    max_missing = max(missing.values()) if missing else 1
    
    scores = {}
    for ball in range(1, 34):
        freq_score = red_freq.get(ball, 0) / max_freq
        missing_score = missing.get(ball, 0) / max_missing
        scores[ball] = freq_score * 0.4 + missing_score * 0.6
    
    sorted_balls = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    return [ball for ball, score in sorted_balls[:6]]

def generate_hot_blue_prediction(records, count=6):
    """生成热号蓝球预测"""
    blue_freq = analyze_blue_balls(records)
    hot_balls = blue_freq.most_common(count)
    return [ball for ball, freq in hot_balls]

def generate_ml_blue_prediction(records, count=6):
    """生成ML加权蓝球预测"""
    blue_freq = analyze_blue_balls(records)
    missing = calculate_missing(records, 'blue')
    
    max_freq = max(blue_freq.values()) if blue_freq else 1
    max_missing = max(missing.values()) if missing else 1
    
    scores = {}
    for ball in range(1, 17):
        freq_score = blue_freq.get(ball, 0) / max_freq
        missing_score = missing.get(ball, 0) / max_missing
        scores[ball] = freq_score * 0.4 + missing_score * 0.6
    
    sorted_balls = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    return [ball for ball, score in sorted_balls[:count]]

def print_prediction(title, red_balls, blue_balls):
    """打印预测结果"""
    print(f"\n{'='*50}")
    print(f"📊 {title}")
    print(f"{'='*50}")
    
    if isinstance(blue_balls, list):
        print(f"🔴 红球: {' '.join(f'{b:02d}' for b in sorted(red_balls))}")
        print(f"🔵 蓝球: {' '.join(f'{b:02d}' for b in sorted(blue_balls))}")
        red_count = len(red_balls)
        blue_count = len(blue_balls)
        if red_count > 6 or blue_count > 1:
            combos = len(list(combinations(red_balls, 6))) * blue_count
            cost = combos * 2
            print(f"📝 复式: {red_count}红 + {blue_count}蓝 = {combos}注 (¥{cost})")
    else:
        print(f"🔴 红球: {' '.join(f'{b:02d}' for b in sorted(red_balls))}")
        print(f"🔵 蓝球: {blue_balls:02d}")
    
    print(f"{'='*50}")

def print_statistics(records):
    """打印详细统计信息"""
    print(f"\n{'='*50}")
    print(f"📈 历史数据统计")
    print(f"{'='*50}")
    
    red_freq = analyze_red_balls(records)
    blue_freq = analyze_blue_balls(records)
    
    print(f"\n🔴 红球号码频率 TOP 10:")
    for ball, freq in red_freq.most_common(10):
        bar = '█' * (freq // 2)
        print(f"   {ball:02d}: {bar} ({freq}次)")
    
    print(f"\n🔵 蓝球号码频率:")
    for ball, freq in blue_freq.most_common():
        bar = '█' * (freq // 3)
        print(f"   {ball:02d}: {bar} ({freq}次)")
    
    print(f"\n📊 红球遗漏情况 TOP 10:")
    missing = calculate_missing(records, 'red')
    sorted_missing = sorted(missing.items(), key=lambda x: x[1], reverse=True)[:10]
    for ball, days in sorted_missing:
        print(f"   {ball:02d}: {days}期未出现")

def main():
    parser = argparse.ArgumentParser(description='双色球预测模型')
    parser.add_argument('--strategy', '-s', type=str, 
                       choices=['hot', 'cold', 'missing', 'balanced', 'ml'],
                       default='ml', help='预测策略')
    parser.add_argument('--count', '-c', type=int, default=3, help='生成几组号码')
    parser.add_argument('--history', type=int, default=None, help='使用最近多少期数据')
    parser.add_argument('--stats', action='store_true', help='显示统计信息')
    parser.add_argument('--compound', '-f', action='store_true', help='生成复式投注')
    parser.add_argument('--red', type=int, default=6, help='红球复式个数 (默认6)')
    parser.add_argument('--blue', type=int, default=6, help='蓝球复式个数 (默认6)')
    args = parser.parse_args()
    
    records = get_all_records(args.history)
    
    if not records:
        print("❌ 数据库中没有数据，请先运行 fetch_history.py 抓取数据")
        return
    
    print(f"\n🎯 双色球预测模型")
    print(f"📈 数据来源: 最近 {len(records)} 期历史数据")
    
    if args.stats:
        print_statistics(records)
    
    strategies = {
        'hot': ('🔥 热号策略', generate_hot_red_prediction),
        'cold': ('❄️ 冷号策略', generate_cold_red_prediction),
        'missing': ('📈 遗漏策略', generate_missing_red_prediction),
        'balanced': ('⚖️ 均衡策略', generate_balanced_red_prediction),
        'ml': ('🤖 ML加权策略', generate_ml_red_prediction),
    }
    
    name, red_func = strategies[args.strategy]
    
    print(f"\n{'='*50}")
    print(f"🎰 {name}")
    print(f"{'='*50}")
    
    # 生成红球
    if args.compound:
        # 复式投注：使用ML策略选择多个红球
        red_balls = generate_ml_red_prediction(records)
        # 如果指定数量大于6，补充随机号码
        while len(red_balls) < args.red:
            ball = random.randint(1, 33)
            if ball not in red_balls:
                red_balls.append(ball)
        red_balls = sorted(red_balls)[:args.red]
        
        # 生成蓝球
        blue_balls = generate_hot_blue_prediction(records, args.blue)
    else:
        # 单式投注
        red_balls = red_func(records)
        blue_balls = generate_hot_blue_prediction(records, 1)[0]
    
    title = f"{name} 预测"
    if args.compound:
        title += f" (复式{args.red}+{args.blue})"
    
    print_prediction(title, red_balls, blue_balls)
    
    # 显示复式组合
    if args.compound:
        print(f"\n📋 复式组合预览 (共{len(list(combinations(red_balls, 6))) * len(blue_balls)}注):")
        print(f"🔴 红球 {args.red}个: {' '.join(f'{b:02d}' for b in red_balls)}")
        print(f"🔵 蓝球 {args.blue}个: {' '.join(f'{b:02d}' for b in sorted(blue_balls))}")
        
        # 显示部分组合示例
        print(f"\n📝 前5注组合示例:")
        for i, combo in enumerate(combinations(red_balls, 6)):
            for blue in blue_balls[:2]:  # 只显示前2个蓝球
                print(f"   {i+1}. {' '.join(f'{b:02d}' for b in combo)} + 🔵{blue:02d}")
                if i >= 4:
                    break
            if i >= 4:
                break
    
    # 打印简单统计
    print(f"\n📊 历史数据统计 (红球)")
    red_freq = analyze_red_balls(records)
    print(f"   最热号码: {red_freq.most_common(3)}")
    print(f"   最冷号码: {red_freq.most_common()[-3:]}")

if __name__ == '__main__':
    main()
