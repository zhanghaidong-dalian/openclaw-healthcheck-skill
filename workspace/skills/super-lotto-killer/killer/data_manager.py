"""
大乐透杀号选球技能 - 数据管理模块
从本地数据库获取历史数据，自动维护数据新鲜度
"""

import sqlite3
import os
from datetime import datetime, timedelta
from typing import List, Tuple, Optional

# 数据库路径（复用上级数据库）
def get_db_path():
    # 向上两级目录找到 super-lotto 的 data 目录
    current = os.path.dirname(os.path.abspath(__file__))
    # killer/ -> super-lotto-killer/ -> skills/ -> workspace/
    parent = os.path.dirname(os.path.dirname(current))
    db_dir = os.path.join(parent, 'super-lotto', 'data')
    return os.path.join(db_dir, 'super_lotto.db')

DB_PATH = get_db_path()


class DataManager:
    """数据管理器"""
    
    def __init__(self, db_path: str = None):
        self.db_path = db_path or DB_PATH
    
    def get_connection(self):
        """获取数据库连接"""
        return sqlite3.connect(self.db_path)
    
    def get_history(self, count: int = 100) -> List[dict]:
        """
        从本地数据库获取近N期历史数据
        
        Args:
            count: 获取期数，默认100期
            
        Returns:
            List[dict]: 历史数据列表，每项包含期号、日期、前区、后区
        """
        conn = self.get_connection()
        cursor = conn.cursor()
        
        # 按期号降序获取
        cursor.execute("""
            SELECT issue_number, draw_date, 
                   front_ball_1, front_ball_2, front_ball_3, front_ball_4, front_ball_5,
                   back_ball_1, back_ball_2
            FROM lottery_records 
            ORDER BY issue_number DESC 
            LIMIT ?
        """, (count,))
        
        rows = cursor.fetchall()
        conn.close()
        
        # 转换为字典列表
        history = []
        for row in rows:
            history.append({
                'issue': row[0],
                'date': row[1],
                'front': [row[2], row[3], row[4], row[5], row[6]],
                'back': [row[7], row[8]]
            })
        
        return history
    
    def get_latest(self) -> Optional[dict]:
        """获取最新一期数据"""
        history = self.get_history(1)
        return history[0] if history else None
    
    def get_count(self) -> int:
        """获取本地数据总数"""
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT COUNT(*) FROM lottery_records')
        count = cursor.fetchone()[0]
        conn.close()
        return count
    
    def get_latest_update_time(self) -> Optional[datetime]:
        """获取最新数据的更新时间"""
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT MAX(updated_at) FROM lottery_records')
        result = cursor.fetchone()[0]
        conn.close()
        if result:
            return datetime.fromisoformat(result)
        return None
    
    def is_fresh(self, hours: int = 48) -> bool:
        """检查数据是否新鲜"""
        update_time = self.get_latest_update_time()
        if not update_time:
            return False
        return datetime.now() - update_time < timedelta(hours=hours)
    
    def need_more_data(self, required: int = 100) -> bool:
        """检查是否需要更多数据"""
        return self.get_count() < required
    
    def get_statistics(self, history: List[dict]) -> dict:
        """
        计算统计数据
        
        Args:
            history: 历史数据列表（按期号降序，最新在前）
            
        Returns:
            dict: 包含频率、遗漏等统计信息
        """
        total = len(history)
        
        # 初始化前区统计（1-35）
        front_count = {i: 0 for i in range(1, 36)}
        back_count = {i: 0 for i in range(1, 13)}
        
        # 初始化遗漏 = 总期数（表示从未出现）
        front_missing = {i: total for i in range(1, 36)}
        back_missing = {i: total for i in range(1, 13)}
        
        # 遍历历史数据：idx=0是最新，idx越大越老
        for idx, record in enumerate(history):
            for ball in record['front']:
                front_count[ball] += 1
                # 遗漏 = 该球最后一次出现时的索引（最小的索引=最新的出现）
                # 因为按降序排列，idx越小越新
                # 所以遗漏 = idx（从最后一次出现到现在隔了多少期）
                if front_missing[ball] == total:  # 第一次处理这个球
                    front_missing[ball] = idx
            
            for ball in record['back']:
                back_count[ball] += 1
                if back_missing[ball] == total:
                    back_missing[ball] = idx
        
        # 计算尾数统计
        tail_count = {i: 0 for i in range(10)}
        for ball in range(1, 36):
            tail_count[ball % 10] += front_count[ball]
        
        # 获取各区出号情况（7区划分）
        zones = self._get_zone_distribution(history)
        
        return {
            'front_count': front_count,
            'back_count': back_count,
            'front_missing': front_missing,
            'back_missing': back_missing,
            'tail_count': tail_count,
            'zones': zones,
            'total': total
        }
    
    def _get_zone_distribution(self, history: List[dict]) -> dict:
        """
        计算区间分布
        7区划分: 01-05, 06-10, 11-15, 16-20, 21-25, 26-30, 31-35
        """
        zones = {i: [] for i in range(1, 8)}  # 7个区
        
        for record in history:
            for ball in record['front']:
                zone = (ball - 1) // 5 + 1
                zones[zone].append(ball)
        
        return zones
    
    def get_recent_sums(self, history: List[dict], count: int = 10) -> List[int]:
        """获取近N期前区和值"""
        sums = []
        for record in history[:count]:
            sums.append(sum(record['front']))
        return sums
    
    def get_recent_tails(self, history: List[dict], count: int = 10) -> dict:
        """
        获取近N期尾数出现情况
        返回: {尾数: [近count期是否出现]}
        """
        tails = {i: [] for i in range(10)}
        
        for record in history[:count]:
            record_tails = [ball % 10 for ball in record['front']]
            for t in range(10):
                tails[t].append(1 if t in record_tails else 0)
        
        return tails


def ensure_data_fresh(required: int = 100) -> Tuple[bool, str]:
    """
    确保数据新鲜，不足时提示用户运行抓取脚本
    
    Returns:
        (是否足够, 提示信息)
    """
    dm = DataManager()
    count = dm.get_count()
    
    if count < required:
        msg = f"⚠️ 本地数据仅 {count} 期，建议运行以下命令补充数据：\n"
        msg += f"```bash\ncd {os.path.dirname(os.path.dirname(__file__))}\n"
        msg += f"python scripts/fetch_history.py\n```"
        return False, msg
    
    if not dm.is_fresh():
        msg = "📅 本地数据可能不是最新的，建议运行抓取脚本更新。"
        # 不阻塞，只是提示
        return True, msg
    
    return True, "✅ 数据充足"


if __name__ == '__main__':
    # 测试
    dm = DataManager()
    print(f"本地数据量: {dm.get_count()} 期")
    print(f"数据是否新鲜: {dm.is_fresh()}")
    
    history = dm.get_history(30)
    stats = dm.get_statistics(history)
    
    print(f"\n前区最热5个: {sorted(stats['front_count'].items(), key=lambda x: -x[1])[:5]}")
    print(f"前区遗漏最多: {sorted(stats['front_missing'].items(), key=lambda x: -x[1])[:5]}")
