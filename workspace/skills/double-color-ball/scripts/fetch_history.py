#!/usr/bin/env python3
"""
双色球历史数据爬虫脚本
支持多个数据源，抓取历史开奖数据
"""

import requests
import sqlite3
import re
import json
from datetime import datetime
from pathlib import Path
from bs4 import BeautifulSoup
import time

# 数据库路径
DB_PATH = Path(__file__).parent.parent / "data" / "double_color_ball.db"

# 数据源配置
DATA_SOURCES = {
    "500com": {
        "name": "500彩票网",
        "url": "https://datachart.500.com/ssq/history/newinc/history.php",
        "params": {
            "start": "03001",  # 起始期号（2003年第1期）
            "end": "25000"     # 结束期号（当前最新）
        },
        "parser": "parse_500com"
    },
    "cwl": {
        "name": "中国福利彩票网",
        "url": "https://www.cwl.gov.cn/cwl_admin/front/cwlkj/search/kjxx/findDrawNotice",
        "params": {
            "name": "ssq",
            "issueCount": 1000,
            "pageNo": 1,
            "pageSize": 1000
        },
        "parser": "parse_cwl"
    }
}

# 请求头
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
}


def parse_500com(html_content):
    """
    解析500彩票网数据
    返回格式: [(issue_number, draw_date, red_balls, blue_ball), ...]
    """
    records = []
    soup = BeautifulSoup(html_content, 'html.parser')
    
    # 查找所有行
    rows = soup.find_all('tr', {'class': 't_tr1'})
    
    for row in rows:
        try:
            tds = row.find_all('td')
            if len(tds) < 12:
                continue
            
            # 期号
            issue_number = tds[0].get_text(strip=True)
            
            # 开奖日期
            draw_date_str = tds[1].get_text(strip=True)
            draw_date = datetime.strptime(draw_date_str, '%Y-%m-%d').date()
            
            # 红球（6个）
            red_balls = []
            for i in range(2, 8):
                ball = int(tds[i].get_text(strip=True))
                red_balls.append(ball)
            
            # 蓝球
            blue_ball = int(tds[8].get_text(strip=True))
            
            records.append({
                'issue_number': issue_number,
                'draw_date': draw_date,
                'red_balls': red_balls,
                'blue_ball': blue_ball
            })
            
        except Exception as e:
            print(f"⚠️ 解析行失败: {e}")
            continue
    
    return records


def parse_cwl(json_content):
    """
    解析中国福利彩票网数据（JSON格式）
    返回格式: [(issue_number, draw_date, red_balls, blue_ball), ...]
    """
    records = []
    
    try:
        data = json.loads(json_content)
        
        if data.get('state') != 0:
            print(f"❌ API返回错误: {data.get('message', '未知错误')}")
            return records
        
        for item in data.get('result', []):
            try:
                issue_number = item.get('code')
                draw_date_str = item.get('date', '')
                
                # 处理日期格式: "2026-05-05(二)" -> "2026-05-05"
                # 移除括号和星期信息
                import re
                draw_date_str = re.sub(r'\([^)]*\)', '', draw_date_str).strip()
                
                draw_date = datetime.strptime(draw_date_str, '%Y-%m-%d').date()
                
                # 红球
                red_str = item.get('red', '')
                red_balls = [int(x) for x in red_str.split(',')]
                
                # 蓝球
                blue_ball = int(item.get('blue', 0))
                
                records.append({
                    'issue_number': issue_number,
                    'draw_date': draw_date,
                    'red_balls': red_balls,
                    'blue_ball': blue_ball
                })
                
            except Exception as e:
                print(f"⚠️ 解析记录失败: {e}")
                continue
                
    except json.JSONDecodeError as e:
        print(f"❌ JSON解析失败: {e}")
    
    return records


def fetch_data(source_name="cwl"):
    """从指定数据源抓取数据"""
    if source_name not in DATA_SOURCES:
        print(f"❌ 不支持的数据源: {source_name}")
        return []
    
    source = DATA_SOURCES[source_name]
    print(f"📡 正在从 {source['name']} 抓取数据...")
    print(f"   URL: {source['url']}")
    
    try:
        response = requests.get(
            source['url'],
            params=source.get('params', {}),
            headers=HEADERS,
            timeout=30
        )
        response.raise_for_status()
        
        # 根据数据源类型选择解析器
        parser_func = globals().get(source['parser'])
        if not parser_func:
            print(f"❌ 未找到解析器: {source['parser']}")
            return []
        
        # 检查响应类型
        content_type = response.headers.get('Content-Type', '')
        
        if 'json' in content_type or source['parser'] == 'parse_cwl':
            records = parser_func(response.text)
        else:
            records = parser_func(response.content)
        
        print(f"✅ 成功抓取 {len(records)} 条记录")
        return records
        
    except requests.exceptions.RequestException as e:
        print(f"❌ 网络请求失败: {e}")
        return []
    except Exception as e:
        print(f"❌ 抓取失败: {e}")
        return []


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
                # 插入新记录
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
            print(f"⚠️ 保存记录失败 {record['issue_number']}: {e}")
            continue
    
    conn.commit()
    conn.close()
    
    print(f"✅ 数据保存完成: 新增 {inserted} 条, 更新 {updated} 条")
    return inserted + updated


def fetch_all_history(source_name="cwl"):
    """抓取全部历史数据（支持分页）"""
    print("=" * 60)
    print("🎲 双色球历史数据抓取")
    print("=" * 60)
    
    all_records = []
    
    if source_name == "cwl":
        # 中国福利彩票网支持分页，需要多次请求
        page = 1
        page_size = 500
        
        while True:
            print(f"\n📄 正在抓取第 {page} 页...")
            
            params = {
                "name": "ssq",
                "issueCount": 5000,
                "pageNo": page,
                "pageSize": page_size
            }
            
            try:
                response = requests.get(
                    "https://www.cwl.gov.cn/cwl_admin/front/cwlkj/search/kjxx/findDrawNotice",
                    params=params,
                    headers=HEADERS,
                    timeout=30
                )
                response.raise_for_status()
                
                records = parse_cwl(response.text)
                
                if not records:
                    print("✅ 已抓取全部数据")
                    break
                
                all_records.extend(records)
                print(f"   当前已抓取: {len(all_records)} 条")
                
                # 如果返回数据少于页面大小，说明已经是最后一页
                if len(records) < page_size:
                    break
                
                page += 1
                time.sleep(0.5)  # 避免请求过快
                
            except Exception as e:
                print(f"❌ 抓取第 {page} 页失败: {e}")
                break
    else:
        # 其他数据源直接抓取
        all_records = fetch_data(source_name)
    
    # 保存到数据库
    if all_records:
        saved = save_to_database(all_records)
        print(f"\n✅ 总计保存 {saved} 条记录")
        return saved
    
    return 0


if __name__ == "__main__":
    import sys
    
    # 检查数据库是否存在
    if not DB_PATH.exists():
        print("⚠️ 数据库未初始化，正在初始化...")
        import init_db
        init_db.init_database()
    
    # 默认使用中国福利彩票网
    source = sys.argv[1] if len(sys.argv) > 1 else "cwl"
    
    fetch_all_history(source)
