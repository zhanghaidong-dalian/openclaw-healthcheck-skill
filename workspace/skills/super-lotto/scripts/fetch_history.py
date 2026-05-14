#!/usr/bin/env python3
"""
大乐透历史数据爬虫脚本（增强版 - 支持全量抓取）
使用requests + BeautifulSoup抓取彩票500万网站数据
支持start/end参数指定期数范围
"""

import sqlite3
import requests
from pathlib import Path
from datetime import datetime
from bs4 import BeautifulSoup

# 数据库路径
DB_PATH = Path(__file__).parent.parent / "data" / "super_lotto.db"

# 数据源配置
BASE_URL = "https://datachart.500.com/dlt/history/newinc/history.php"

# 请求头
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
}


def parse_html(html_content):
    """解析HTML内容，提取开奖数据"""
    records = []
    soup = BeautifulSoup(html_content, 'html.parser')

    # 查找表格中的所有行
    rows = soup.find_all('tbody')

    for tbody in rows:
        trs = tbody.find_all('tr')
        for tr in trs:
            try:
                tds = tr.find_all('td')
                if len(tds) < 15:  # 数据行应该有足够的列
                    continue

                # 提取数据
                issue_number = tds[0].get_text(strip=True)

                # 检查是否是有效的期号（数字）
                if not issue_number.isdigit():
                    continue

                # 前区（红球）- 5个号码
                front_balls = []
                for i in range(1, 6):
                    ball = int(tds[i].get_text(strip=True))
                    front_balls.append(ball)

                # 后区（蓝球）- 2个号码
                back_balls = []
                for i in range(6, 8):
                    ball = int(tds[i].get_text(strip=True))
                    back_balls.append(ball)

                # 开奖日期
                draw_date_str = tds[-1].get_text(strip=True)
                draw_date = datetime.strptime(draw_date_str, '%Y-%m-%d').date()

                # 奖池金额和销售金额（可选）
                pool_amount_str = tds[8].get_text(strip=True).replace(',', '')
                sales_amount_str = tds[13].get_text(strip=True).replace(',', '')

                try:
                    pool_amount = int(pool_amount_str) if pool_amount_str else None
                    sales_amount = int(sales_amount_str) if sales_amount_str else None
                except:
                    pool_amount = None
                    sales_amount = None

                records.append({
                    'issue_number': issue_number,
                    'draw_date': draw_date,
                    'front_balls': front_balls,
                    'back_balls': back_balls,
                    'pool_amount': pool_amount,
                    'sales_amount': sales_amount
                })

            except Exception as e:
                # 忽略解析错误的行
                continue

    return records


def fetch_all_history(start_issue=None, end_issue=None):
    """抓取历史数据

    Args:
        start_issue: 起始期号（如05001），不指定则从最早开始
        end_issue: 结束期号（如26052），不指定则到最新
    """
    print("=" * 60)
    print("🎲 大乐透历史数据抓取（增强版）")
    print("=" * 60)

    all_records = []

    # 构建URL参数
    params = {}
    if start_issue:
        params['start'] = start_issue
    if end_issue:
        params['end'] = end_issue

    try:
        print(f"\n📡 正在访问彩票500万网...")
        url = BASE_URL
        if params:
            url += '?' + '&'.join([f'{k}={v}' for k, v in params.items()])
        print(f"   URL: {url}")

        response = requests.get(url, headers=HEADERS, timeout=30)
        response.raise_for_status()

        print("📊 正在解析数据...")
        records = parse_html(response.content)

        if records:
            all_records.extend(records)
            print(f"✅ 成功抓取 {len(records)} 条记录")

            if len(records) >= 1000:
                print(f"   📅 期号范围: {records[0]['issue_number']} ~ {records[-1]['issue_number']}")
        else:
            print("❌ 未抓取到数据")

    except Exception as e:
        print(f"❌ 抓取失败: {e}")

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
            # 检查是否已存在
            cursor.execute(
                'SELECT id FROM lottery_records WHERE issue_number = ?',
                (record['issue_number'],)
            )

            if cursor.fetchone():
                # 更新已有记录
                cursor.execute('''
                    UPDATE lottery_records SET
                        draw_date = ?,
                        front_ball_1 = ?,
                        front_ball_2 = ?,
                        front_ball_3 = ?,
                        front_ball_4 = ?,
                        front_ball_5 = ?,
                        back_ball_1 = ?,
                        back_ball_2 = ?,
                        pool_amount = ?,
                        sales_amount = ?,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE issue_number = ?
                ''', (
                    record['draw_date'],
                    record['front_balls'][0],
                    record['front_balls'][1],
                    record['front_balls'][2],
                    record['front_balls'][3],
                    record['front_balls'][4],
                    record['back_balls'][0],
                    record['back_balls'][1],
                    record['pool_amount'],
                    record['sales_amount'],
                    record['issue_number']
                ))
                updated += 1
            else:
                # 插入新记录
                cursor.execute('''
                    INSERT INTO lottery_records (
                        issue_number, draw_date,
                        front_ball_1, front_ball_2, front_ball_3,
                        front_ball_4, front_ball_5,
                        back_ball_1, back_ball_2,
                        pool_amount, sales_amount
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    record['issue_number'],
                    record['draw_date'],
                    record['front_balls'][0],
                    record['front_balls'][1],
                    record['front_balls'][2],
                    record['front_balls'][3],
                    record['front_balls'][4],
                    record['back_balls'][0],
                    record['back_balls'][1],
                    record['pool_amount'],
                    record['sales_amount']
                ))
                inserted += 1

        except Exception as e:
            print(f"⚠️ 保存记录失败 {record['issue_number']}: {e}")
            continue

    conn.commit()
    conn.close()

    print(f"✅ 数据保存完成: 新增 {inserted} 条, 更新 {updated} 条")
    return inserted + updated


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description='大乐透历史数据抓取工具')
    parser.add_argument('--start', type=str, help='起始期号（如05001）')
    parser.add_argument('--end', type=str, help='结束期号（如26052）')
    parser.add_argument('--all', action='store_true', help='抓取全部历史数据')

    args = parser.parse_args()

    # 检查数据库是否存在
    if not DB_PATH.exists():
        print("⚠️ 数据库未初始化，正在初始化...")
        import init_db
        init_db.init_database()

    # 执行抓取
    if args.all:
        print("🚀 抓取全部历史数据...")
        fetch_all_history(start_issue='05001', end_issue='26052')
    else:
        fetch_all_history(start_issue=args.start, end_issue=args.end)