#!/usr/bin/env python3
"""
大乐透预测模型
基于历史数据频率分析和遗漏值统计生成推荐号码
"""

import sqlite3
import random
from collections import Counter
from datetime import datetime
import argparse

DB_PATH = 'data/super_lotto.db'

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

def analyze_front_balls(records):
    """分析前区号码（红球 1-35）频率"""
    front_balls = []
    for record in records:
        # 前区是 record[3:8] (front_ball_1 到 front_ball_5)
        front_balls.extend(record[3:8])
    return Counter(front_balls)

def analyze_back_balls(records):
    """分析后区号码（蓝球 1-12）频率"""
    back_balls = []
    for record in records:
        # 后区是 record[8:10]
        back_balls.extend(record[8:10])
    return Counter(back_balls)

def calculate_missing_days(records, ball_type='front'):
    """计算号码遗漏天数（距上次出现的期数）"""
    conn = get_connection()
    cursor = conn.cursor()
    
    max_ball = 35 if ball_type == 'front' else 12
    
    cursor.execute('''
        SELECT issue_number FROM lottery_records 
        ORDER BY issue_number DESC
    ''')
    issues = [row[0] for row in cursor.fetchall()]
    latest_issue = int(issues[0]) if issues else 0
    
    missing_days = {}
    for ball in range(1, max_ball + 1):
        if ball_type == 'front':
            cursor.execute('''
                SELECT issue_number FROM lottery_records 
                WHERE front_ball_1=? OR front_ball_2=? OR front_ball_3=? OR front_ball_4=? OR front_ball_5=?
                ORDER BY issue_number DESC
                LIMIT 1
            ''', (ball, ball, ball, ball, ball))
        else:
            cursor.execute('''
                SELECT issue_number FROM lottery_records 
                WHERE back_ball_1=? OR back_ball_2=?
                ORDER BY issue_number DESC
                LIMIT 1
            ''', (ball, ball))
        
        result = cursor.fetchone()
        if result:
            missing_days[ball] = latest_issue - int(result[0])
        else:
            missing_days[ball] = latest_issue  # 从未出现
    
    conn.close()
    return missing_days

def generate_hot_number_prediction(records, count=5):
    """基于热号生成预测（前区）"""
    front_freq = analyze_front_balls(records)
    # 选择出现频率最高的号码
    hot_balls = front_freq.most_common(count)
    return [ball for ball, freq in hot_balls]

def generate_cold_number_prediction(records, count=5):
    """基于冷号生成预测（前区）"""
    front_freq = analyze_front_balls(records)
    # 找出所有号码
    all_balls = set(range(1, 36))
    appeared = set(front_freq.keys())
    never_appeared = all_balls - appeared
    
    # 选择出现次数最少的号码
    if len(front_freq) >= count:
        cold_balls = [ball for ball, freq in front_freq.most_common()[-count:]]
    else:
        cold_balls = []
    
    # 如果不够5个，补充从未出现的号码
    result = cold_balls + list(never_appeared)
    return result[:count]

def generate_missing_prediction(records, count=5):
    """基于遗漏值生成预测（前区）"""
    missing = calculate_missing_days(records, 'front')
    # 选择遗漏值最大的号码
    sorted_missing = sorted(missing.items(), key=lambda x: x[1], reverse=True)
    return [ball for ball, days in sorted_missing[:count]]

def generate_random_prediction(count=5, ball_range=(1, 35)):
    """生成随机号码"""
    return sorted(random.sample(range(ball_range[0], ball_range[1] + 1), count))

def generate_balanced_prediction(records):
    """生成均衡型预测（结合热号、冷号、随机）"""
    # 2个热号
    hot = generate_hot_number_prediction(records, 2)
    # 1个冷号
    cold = generate_cold_number_prediction(records, 1)
    # 2个遗漏值大的号
    missing = generate_missing_prediction(records, 2)
    
    # 合并并去重
    combined = hot + cold + missing
    seen = set()
    result = []
    for ball in combined:
        if ball not in seen and len(result) < 5:
            seen.add(ball)
            result.append(ball)
    
    # 如果不够5个，随机补足
    while len(result) < 5:
        ball = random.randint(1, 35)
        if ball not in seen:
            seen.add(ball)
            result.append(ball)
    
    return sorted(result)

def generate_ml_style_prediction(records):
    """基于加权评分的预测（模拟简单ML模型）"""
    front_freq = analyze_front_balls(records)
    missing = calculate_missing_days(records, 'front')
    
    # 计算每个号码的加权分数
    max_freq = max(front_freq.values()) if front_freq else 1
    max_missing = max(missing.values()) if missing else 1
    
    scores = {}
    for ball in range(1, 36):
        freq_score = front_freq.get(ball, 0) / max_freq  # 频率分数
        missing_score = missing.get(ball, 0) / max_missing  # 遗漏分数
        # 加权：频率占40%，遗漏占60%
        scores[ball] = freq_score * 0.4 + missing_score * 0.6
    
    # 选择分数最高的5个号码
    sorted_balls = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    return [ball for ball, score in sorted_balls[:5]]

def generate_back_balls_prediction(records, count=2):
    """生成后区号码预测"""
    back_freq = analyze_back_balls(records)
    missing = calculate_missing_days(records, 'back')
    
    max_freq = max(back_freq.values()) if back_freq else 1
    max_missing = max(missing.values()) if missing else 1
    
    scores = {}
    for ball in range(1, 13):
        freq_score = back_freq.get(ball, 0) / max_freq
        missing_score = missing.get(ball, 0) / max_missing
        scores[ball] = freq_score * 0.4 + missing_score * 0.6
    
    sorted_balls = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    return [ball for ball, score in sorted_balls[:count]]

def print_prediction(title, front_balls, back_balls):
    """打印预测结果"""
    print(f"\n{'='*50}")
    print(f"📊 {title}")
    print(f"{'='*50}")
    print(f"🎱 前区号码: {' '.join(f'{b:02d}' for b in front_balls)}")
    print(f"🔵 后区号码: {' '.join(f'{b:02d}' for b in back_balls)}")
    print(f"{'='*50}")

def print_statistics(records):
    """打印统计信息"""
    print(f"\n{'='*50}")
    print(f"📈 历史数据统计")
    print(f"{'='*50}")
    
    front_freq = analyze_front_balls(records)
    back_freq = analyze_back_balls(records)
    
    print(f"\n🎱 前区号码频率 TOP 10:")
    for ball, freq in front_freq.most_common(10):
        bar = '█' * freq
        print(f"   {ball:02d}: {bar} ({freq}次)")
    
    print(f"\n🔵 后区号码频率:")
    for ball, freq in back_freq.most_common():
        bar = '█' * freq
        print(f"   {ball:02d}: {bar} ({freq}次)")
    
    print(f"\n📊 遗漏情况 (前区):")
    missing = calculate_missing_days(records, 'front')
    sorted_missing = sorted(missing.items(), key=lambda x: x[1], reverse=True)[:10]
    for ball, days in sorted_missing:
        print(f"   {ball:02d}: {days}期未出现")

def main():
    parser = argparse.ArgumentParser(description='大乐透预测模型')
    parser.add_argument('--strategy', '-s', type=str, 
                       choices=['hot', 'cold', 'missing', 'balanced', 'ml', 'all'],
                       default='all', help='预测策略')
    parser.add_argument('--count', '-c', type=int, default=3, help='生成几组号码')
    parser.add_argument('--history', type=int, default=None, help='使用最近多少期数据')
    parser.add_argument('--stats', action='store_true', help='显示统计信息')
    args = parser.parse_args()
    
    records = get_all_records(args.history)
    
    if not records:
        print("❌ 数据库中没有数据，请先运行 fetch_history.py 抓取数据")
        return
    
    print(f"\n🎲 大乐透预测模型")
    print(f"📈 数据来源: 最近 {len(records)} 期历史数据")
    
    # 显示统计信息
    if args.stats:
        print_statistics(records)
    
    # 生成后区号码池
    back_balls_pool = list(range(1, 13))
    
    if args.strategy == 'all':
        # 生成多种策略的预测
        strategies = [
            ('🔥 热号策略 (高频号码)', 'hot'),
            ('❄️ 冷号策略 (低频号码)', 'cold'),
            ('📈 遗漏策略 (长未出现)', 'missing'),
            ('⚖️ 均衡策略 (冷热混合)', 'balanced'),
            ('🤖 ML加权策略 (频率+遗漏)', 'ml'),
        ]
        
        for name, strategy in strategies:
            for i in range(args.count):
                if strategy == 'hot':
                    front = generate_hot_number_prediction(records, 5)
                elif strategy == 'cold':
                    front = generate_cold_number_prediction(records, 5)
                elif strategy == 'missing':
                    front = generate_missing_prediction(records, 5)
                elif strategy == 'balanced':
                    front = generate_balanced_prediction(records)
                else:
                    front = generate_ml_style_prediction(records)
                
                back = generate_back_balls_prediction(records, 2)
                title = f"{name} 第{i+1}组"
                print_prediction(title, front, back)
    else:
        # 生成指定策略的预测
        for i in range(args.count):
            if args.strategy == 'hot':
                front = generate_hot_number_prediction(records, 5)
            elif args.strategy == 'cold':
                front = generate_cold_number_prediction(records, 5)
            elif args.strategy == 'missing':
                front = generate_missing_prediction(records, 5)
            elif args.strategy == 'balanced':
                front = generate_balanced_prediction(records)
            else:
                front = generate_ml_style_prediction(records)
            
            back = generate_back_balls_prediction(records, 2)
            title = f"预测 第{i+1}组"
            print_prediction(title, front, back)
    
    # 打印统计信息
    print(f"\n📊 历史数据统计 (前区)")
    front_freq = analyze_front_balls(records)
    print(f"   最热号码: {front_freq.most_common(3)}")
    print(f"   最冷号码: {front_freq.most_common()[-3:]}")

if __name__ == '__main__':
    main()
