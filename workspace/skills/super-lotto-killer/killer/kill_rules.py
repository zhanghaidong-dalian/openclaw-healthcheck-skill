"""
大乐透杀号选球技能 - 杀号规则引擎
完整版：包含8种杀号规则
"""

from typing import List, Set, Dict, Tuple
from dataclasses import dataclass, field
from killer.data_manager import DataManager


@dataclass
class KillResult:
    """杀号结果"""
    rule_name: str
    killed_front: Set[int] = field(default_factory=set)
    killed_back: Set[int] = field(default_factory=set)
    reason: str = ""
    confidence: str = "normal"


class KillRuleEngine:
    """杀号规则引擎 - 完整8种规则"""
    
    def __init__(self, history: List[dict], stats: dict = None):
        self.history = history
        self.latest = history[0] if history else None
        self.stats = stats
        self.results: List[KillResult] = []
        self.dm = DataManager()
    
    def run_all(self) -> List[KillResult]:
        """执行所有8种杀号规则"""
        if not self.stats:
            self.stats = self.dm.get_statistics(self.history)
        
        self.results = []
        
        # 1. 冷热号杀号
        self._kill_by_hot_cold()
        
        # 2. 遗漏值杀号
        self._kill_by_missing()
        
        # 3. 尾数杀号
        self._kill_by_digit()
        
        # 4. 断区杀号
        self._kill_by_zone()
        
        # 5. 加减法杀号
        self._kill_by_add_sub()
        
        # 6. 公式杀号
        self._kill_by_formula()
        
        # 7. 首尾联动
        self._kill_by_head_tail()
        
        # 8. 和值杀号
        self._kill_by_sum()
        
        return self.results
    
    def _kill_by_hot_cold(self):
        """冷热号杀号：热号（频率>2倍均值）+ 冷号（频率最低的）"""
        front_count = self.stats['front_count']
        back_count = self.stats['back_count']
        total = self.stats['total']
        
        if total < 10:
            return
        
        front_avg = sum(front_count.values()) / 35
        back_avg = sum(back_count.values()) / 12
        
        killed_front = set()
        killed_back = set()
        
        # 前区热号（频率>2倍均值）
        for ball in range(1, 36):
            if front_count[ball] > front_avg * 2:
                killed_front.add(ball)
        
        # 前区冷号（频率最低的3个）
        cold_balls = sorted(front_count.keys(), key=lambda x: front_count[x])[:3]
        killed_front.update(cold_balls)
        
        # 后区热号
        for ball in range(1, 13):
            if back_count[ball] > back_avg * 2:
                killed_back.add(ball)
        
        # 后区冷号
        cold_back = sorted(back_count.keys(), key=lambda x: back_count[x])[:2]
        killed_back.update(cold_back)
        
        if killed_front or killed_back:
            result = KillResult(
                rule_name="冷热杀号",
                killed_front=killed_front,
                killed_back=killed_back,
                reason=f"热号(>{front_avg*2:.1f}次) + 冷号(最低3个)"
            )
            self.results.append(result)
    
    def _kill_by_missing(self):
        """遗漏值杀号：前区遗漏≥12期，后区遗漏≥8期"""
        total = self.stats['total']
        
        if total < 15:
            return
        
        killed_front = set()
        killed_back = set()
        
        # 前区遗漏
        for ball in range(1, 36):
            miss = self.stats['front_missing'].get(ball, 0)
            if miss >= 12:
                killed_front.add(ball)
        
        # 后区遗漏
        for ball in range(1, 13):
            miss = self.stats['back_missing'].get(ball, 0)
            if miss >= 8:
                killed_back.add(ball)
        
        if killed_front or killed_back:
            result = KillResult(
                rule_name="遗漏杀号",
                killed_front=killed_front,
                killed_back=killed_back,
                reason=f"前区漏≥12期, 后区漏≥8期"
            )
            self.results.append(result)
    
    def _kill_by_digit(self):
        """尾数杀号：热尾（频率>1.5倍均值）+ 冷尾（连续5期未出）"""
        total = self.stats['total']
        
        if total < 10:
            return
        
        front_count = self.stats['front_count']
        
        # 计算各尾数频率
        digit_freq = {i: 0 for i in range(10)}
        for ball in range(1, 36):
            digit = ball % 10
            digit_freq[digit] += front_count[ball]
        
        avg_digit_freq = sum(digit_freq.values()) / 10
        
        killed_front = set()
        
        # 热尾杀号
        for digit in range(10):
            if digit_freq[digit] > avg_digit_freq * 1.5:
                # 该尾数全部杀掉
                for ball in range(1, 36):
                    if ball % 10 == digit:
                        killed_front.add(ball)
        
        # 冷尾（近5期该尾数未出现）
        recent_issues = self.history[:5]
        recent_digits = set()
        for issue in recent_issues:
            for ball in issue['front']:
                recent_digits.add(ball % 10)
        
        for digit in range(10):
            if digit not in recent_digits and digit_freq[digit] < avg_digit_freq * 0.5:
                for ball in range(1, 36):
                    if ball % 10 == digit:
                        killed_front.add(ball)
        
        if killed_front:
            result = KillResult(
                rule_name="尾数杀号",
                killed_front=killed_front,
                killed_back=set(),
                reason="热尾(频率>1.5倍均值)"
            )
            self.results.append(result)
    
    def _kill_by_zone(self):
        """断区杀号：7区划分后，出号密度低的区间杀掉"""
        total = self.stats['total']
        front_count = self.stats['front_count']
        
        if total < 10:
            return
        
        killed_front = set()
        
        # 7区划分：[1-5],[6-10],[11-15],[16-20],[21-25],[26-30],[31-35]
        zones = [
            [1, 2, 3, 4, 5],
            [6, 7, 8, 9, 10],
            [11, 12, 13, 14, 15],
            [16, 17, 18, 19, 20],
            [21, 22, 23, 24, 25],
            [26, 27, 28, 29, 30],
            [31, 32, 33, 34, 35]
        ]
        
        zone_density = []
        for zone in zones:
            count = sum(front_count[b] for b in zone)
            density = count / total if total > 0 else 0
            zone_density.append(density)
        
        avg_density = sum(zone_density) / 7
        
        # 杀掉密度最低的2个区
        for idx, density in enumerate(zone_density):
            if density < avg_density * 0.5:
                killed_front.update(zones[idx])
        
        if killed_front:
            result = KillResult(
                rule_name="断区杀号",
                killed_front=killed_front,
                killed_back=set(),
                reason="密度<均值50%的区间"
            )
            self.results.append(result)
    
    def _kill_by_add_sub(self):
        """加减法杀号：上期号码±3运算"""
        if not self.latest:
            return
        
        killed_front = set()
        killed_back = set()
        
        # 前区±3
        for ball in self.latest['front']:
            for delta in [-3, 3]:
                new_ball = ball + delta
                if 1 <= new_ball <= 35:
                    killed_front.add(new_ball)
        
        # 后区±3
        for ball in self.latest['back']:
            for delta in [-3, 3]:
                new_ball = ball + delta
                if 1 <= new_ball <= 12:
                    killed_back.add(new_ball)
        
        if killed_front or killed_back:
            result = KillResult(
                rule_name="加减杀号",
                killed_front=killed_front,
                killed_back=killed_back,
                reason="上期号码±3"
            )
            self.results.append(result)
    
    def _kill_by_formula(self):
        """公式杀号：三种经典公式"""
        if not self.latest or len(self.history) < 3:
            return
        
        killed_front = set()
        front = sorted(self.latest['front'])
        
        # 公式1: A5 - A3 - A1
        if len(front) >= 5:
            val1 = front[4] - front[2] - front[0]
            if 1 <= val1 <= 35:
                killed_front.add(val1)
        
        # 公式2: A4 - A2
        if len(front) >= 4:
            val2 = front[3] - front[1]
            if 1 <= val2 <= 35:
                killed_front.add(val2)
        
        # 公式3: A3 - A1 + A2
        if len(front) >= 3:
            val3 = front[2] - front[0] + front[1]
            if 1 <= val3 <= 35:
                killed_front.add(val3)
        
        if killed_front:
            result = KillResult(
                rule_name="公式杀号",
                killed_front=killed_front,
                killed_back=set(),
                reason="A5-A3-A1, A4-A2, A3-A1+A2"
            )
            self.results.append(result)
    
    def _kill_by_head_tail(self):
        """首尾联动杀号：(最小前区 + 最大后区) % 35"""
        if not self.latest:
            return
        
        killed_front = set()
        
        min_front = min(self.latest['front'])
        max_back = max(self.latest['back'])
        
        # 公式: (min_front + max_back) % 35
        val1 = (min_front + max_back) % 35
        if val1 == 0:
            val1 = 35
        killed_front.add(val1)
        
        # 公式: (min_front * 2) % 35
        val2 = (min_front * 2) % 35
        if val2 == 0:
            val2 = 35
        killed_front.add(val2)
        
        if killed_front:
            result = KillResult(
                rule_name="首尾杀号",
                killed_front=killed_front,
                killed_back=set(),
                reason="(最小前区+最大后区)%35"
            )
            self.results.append(result)
    
    def _kill_by_sum(self):
        """和值杀号：根据近10期和值趋势杀掉偏离较大的号码"""
        if len(self.history) < 10:
            return
        
        killed_front = set()
        
        # 计算近10期和值
        sums = []
        for issue in self.history[:10]:
            s = sum(issue['front'])
            sums.append(s)
        
        avg_sum = sum(sums) / len(sums)
        
        # 和值偏高时，杀前区大号；偏低时杀小号
        if sums[0] > avg_sum + 15:
            # 上期和值偏高，杀前区大号(28-35)
            for ball in range(28, 36):
                killed_front.add(ball)
        elif sums[0] < avg_sum - 15:
            # 上期和值偏低，杀前区小号(1-8)
            for ball in range(1, 9):
                killed_front.add(ball)
        
        if killed_front:
            result = KillResult(
                rule_name="和值杀号",
                killed_front=killed_front,
                killed_back=set(),
                reason=f"近10期和值{avg_sum:.0f}, 上期{sums[0]}"
            )
            self.results.append(result)
    
    def get_all_killed(self) -> Tuple[Set[int], Set[int]]:
        """获取所有被杀掉的号码"""
        killed_front = set()
        killed_back = set()
        
        for result in self.results:
            killed_front |= result.killed_front
            killed_back |= result.killed_back
        
        killed_front = {b for b in killed_front if 1 <= b <= 35}
        killed_back = {b for b in killed_back if 1 <= b <= 12}
        
        return killed_front, killed_back
    
    def get_high_confidence(self) -> Dict[int, List[str]]:
        """获取高置信度杀号（被多个规则同时命中）"""
        ball_hits = {}
        
        for result in self.results:
            for ball in result.killed_front:
                if ball not in ball_hits:
                    ball_hits[ball] = []
                ball_hits[ball].append(result.rule_name)
        
        high_conf = {ball: rules for ball, rules in ball_hits.items() if len(rules) >= 2}
        
        return high_conf
    
    def get_remaining_pool(self) -> Tuple[List[int], List[int]]:
        """获取杀号后的剩余号码池"""
        killed_front, killed_back = self.get_all_killed()
        
        remaining_front = [b for b in range(1, 36) if b not in killed_front]
        remaining_back = [b for b in range(1, 13) if b not in killed_back]
        
        return remaining_front, remaining_back


def print_kill_results(results: List[KillResult], high_conf: dict):
    """打印杀号结果"""
    print("\n═══════════════════════════════════════════════════════")
    print("🔪 杀号详情")
    print("═══════════════════════════════════════════════════════")
    
    for result in results:
        if result.killed_front or result.killed_back:
            front_str = ', '.join(f"{b:02d}" for b in sorted(result.killed_front)) if result.killed_front else '-'
            back_str = ', '.join(f"{b:02d}" for b in sorted(result.killed_back)) if result.killed_back else '-'
            
            print(f"\n【{result.rule_name}】")
            if result.killed_front:
                print(f"  前区: {front_str}")
            if result.killed_back:
                print(f"  后区: {back_str}")
            if result.reason:
                print(f"  说明: {result.reason}")
    
    if high_conf:
        print("\n═══════════════════════════════════════════════════════")
        print("⭐ 高置信度杀号（≥2规则同时命中）")
        print("═══════════════════════════════════════════════════════")
        for ball, rules in sorted(high_conf.items()):
            print(f"  {ball:02d}号 ← {' + '.join(rules)}")


if __name__ == '__main__':
    dm = DataManager()
    history = dm.get_history(30)
    stats = dm.get_statistics(history)
    
    engine = KillRuleEngine(history, stats)
    results = engine.run_all()
    
    killed_front, killed_back = engine.get_all_killed()
    remaining_front, remaining_back = engine.get_remaining_pool()
    high_conf = engine.get_high_confidence()
    
    print(f"前区杀号: {len(killed_front)}个 - {sorted(killed_front)}")
    print(f"后区杀号: {len(killed_back)}个 - {sorted(killed_back)}")
    print(f"前区剩余: {len(remaining_front)}个")
    print(f"后区剩余: {len(remaining_back)}个")
    
    print_kill_results(results, high_conf)
