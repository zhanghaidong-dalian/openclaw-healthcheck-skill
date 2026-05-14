#!/usr/bin/env python3
"""
双色球历史数据爬虫脚本（官方API版）
使用中国福利彩票网官方API分页抓取
"""

import sqlite3
import requests
import json
from datetime import datetime
from pathlib import Path

# 数据库路径
DB_PATH = Path(__file__).parent.parent / "data" / "double_color_ball.db"

# 官方API
API_URL = "https://www.cwl.gov.cn/cwl_admin/front/cwlkj/search/kjxx/findDrawNotice"

# 请求头
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Referer': 'https://www.cwl.gov.cn/',
}


def parse_cwl_data(data_list):
    """解析官方API返回的数据"""
    records = []

    for item in data_list:
        try:
            # 期号
            issue_number = item.get('code', '')

            # 开奖日期
            draw_date_str = item.get('date', '')
            # 处理日期格式: "2026-05-05(二)" -> "2026-05-05"
            import re
            draw_date_str = re.sub(r'\([^)]*\)', '', draw_date_str).strip()

            if draw_date_str:
                draw_date = datetime.strptime(draw_date_str, '%Y-%m-%d').date()
            else:
                continue

            # 红球
            red_str = item.get('red', '')
            red_balls = [int(x) for x in red_str.split(',')]

            # 蓝球
            blue_ball = int(item.get('blue', 0))

            if len(red_balls) == 6 and blue_ball:
                records.append({
                    'issue_number': issue_number,
                    'draw_date': draw_date,
                    'red_balls': red_balls,
                    'blue_ball': blue_ball
                })

        except Exception as e:
            continue

    return records


def fetch_all_history():
    """抓取全部历史数据（自动去重）"""
    print("=" * 60)
    print("🎲 双色球历史数据抓取（官方API版）")
    print("=" * 60)

    all_records = []
    seen_issues = set()
    page = 1
    max_pages = 5  # 最多抓取5页，避免无限循环

    print(f"\n📡 开始从官方API抓取...")

    while page <= max_pages:
        print(f"📄 正在抓取第 {page} 页...")

        params = {
            "name": "ssq",
            "issueCount": 10000,
            "pageNo": page,
            "pageSize": 5000
        }

        try:
            response = requests.get(API_URL, params=params, headers=HEADERS, timeout=30)

            if response.status_code == 403:
                print(f"   ⚠️ 被反爬虫拦截，尝试切换请求头...")
                HEADERS['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                time.sleep(2)
                continue

            response.raise_for_status()

            data = response.json()

            if data.get('state') != 0:
                print(f"   ❌ API返回错误: {data.get('message', '未知错误')}")
                break

            result_list = data.get('result', [])

            if not result_list:
                print(f"   ✅ 第 {page} 页没有数据，抓取完成")
                break

            # 解析并去重
            records = parse_cwl_data(result_list)
            new_records = []
            for record in records:
                if record['issue_number'] not in seen_issues:
                    seen_issues.add(record['issue_number'])
                    new_records.append(record)

            if new_records:
                all_records.extend(new_records)
                print(f"   ✅ 新增 {len(new_records)} 条，总计 {len(all_records)} 条")
            else:
                print(f"   ℹ️  第 {page} 页无新数据（重复 {len(records)} 条）")
                # 如果连续2页无新数据，停止抓取
                page += 1
                if page > max_pages:
                    break
                continue

            # 如果没有新数据，继续抓取下一页
            page += 1

            # 避免请求过快
            import time
            time.sleep(0.5)

        except requests.exceptions.RequestException as e:
            print(f"   ❌ 第 {page} 页抓取失败: {e}")
            break

    print(f"\n📊 总计抓取: {len(all_records)} 条记录")

    # 保存到数据库
    if all_records:
        saved = save_to_database(all_records)
        print(f"\n✅ 总计保存 {saved} 条记录")
        return saved

    return 0


def save_to_database(records):
    """保存数据到数据库"""
    if not records:
        print("⚠️ 没有数据需要保存")
        return 0

    if not DB_PATH.exists():
        print("❌ 数据库文件不存在，请先运行 init_db.py")
        return 0

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    inserted = 0
    updated = 0

    for record in records:
        try:
            cursor.execute(
                'SELECT id FROM lottery_records WHERE issue_number = ?',
                (record['issue_number'],)
            )

            if cursor.fetchone():
                cursor.execute('''
                    UPDATE lottery_records SET
                        draw_date = ?,
                        red_ball_1 = ?,
                        red_ball_2 = ?,
                        red_ball_3 = ?,
                        red_ball_4 = ?,
                        red_ball_5 = ?,
                        red_ball_6 = ?,
                        blue_ball = ?,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE issue_number = ?
                ''', (
                    record['draw_date'],
                    record['red_balls'][0],
                    record['red_balls'][1],
                    record['red_balls'][2],
                    record['red_balls'][3],
                    record['red_balls'][4],
                    record['red_balls'][5],
                    record['blue_ball'],
                    record['issue_number']
                ))
                updated += 1
            else:
                cursor.execute('''
                    INSERT INTO lottery_records (
                        issue_number, draw_date,
                        red_ball_1, red_ball_2, red_ball_3,
                        red_ball_4, red_ball_5, red_ball_6,
                        blue_ball
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    record['issue_number'],
                    record['draw_date'],
                    record['red_balls'][0],
                    record['red_balls'][1],
                    record['red_balls'][2],
                    record['red_balls'][3],
                    record['red_balls'][4],
                    record['red_balls'][5],
                    record['blue_ball']
                ))
                inserted += 1

        except Exception as e:
            continue

    conn.commit()
    conn.close()

    print(f"✅ 数据保存完成: 新增 {inserted} 条, 更新 {updated} 条")
    return inserted + updated


if __name__ == "__main__":
    import sys

    if not DB_PATH.exists():
        print("⚠️ 数据库未初始化，正在初始化...")
        import init_db
        init_db.init_database()

    fetch_all_history()