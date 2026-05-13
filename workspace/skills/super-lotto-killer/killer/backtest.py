"""
大乐透杀号选球技能 - 回测验证模块
验证杀号规则的历史准确率
"""

from typing import List, Dict
from killer.data_manager import DataManager


class BacktestEngine:
    """回测引擎 v4（与kill_rules.py v3同步）"""
    
    def __init__(self, history: List[dict]):
        self.history = history
    
    def run_backtest(self, skip_recent: int = 5) -> Dict:
        """运行回测验证"""
        if len(self.history) < skip_recent + 10:
            return {'error': '数据量不足，无法回测'}
        
        results = []
        
        for i in range(skip_recent, len(self.history) - 1):
            train_data = self.history[i:]
            test_record = self.history[i - 1]
            
            result = self._backtest_single(train_data, test_record)
            results.append(result)
        
        return self._summarize(results, skip_recent)
    
    def _backtest_single(self, train_data: List[dict], test_record: dict) -> dict:
        """单次回测（只保留超冷杀号和严格区间杀号）"""
        dm = DataManager()
        stats = dm.get_statistics(train_data)
        
        killed_front = set()
        killed_back = set()
        
        latest = train_data[0]
        front = sorted(latest['front'])
        back = latest['back']
        total = len(train_data)
        
        front_count = stats['front_count']
        zones = stats['zones']
        front_avg = sum(front_count.values()) / 35
        
        # 1. 超冷号杀号（数据量≥25期）
        if total >= 25:
            for ball in range(1, 36):
                if front_count[ball] == 0:
                    killed_front.add(ball)
            for ball in range(1, 13):
                if stats['back_count'][ball] == 0:
                    killed_back.add(ball)
        
        # 2. 严格区间杀号：密度<3% 且 全部低频
        for zone_id in range(1, 8):
            balls_in_zone = zones.get(zone_id, [])
            density = len(balls_in_zone) / total if total > 0 else 0
            if density < 0.03:
                zone_start = (zone_id - 1) * 5 + 1
                zone_end = zone_id * 5 + 1
                has_recent = any(zone_start <= b < zone_end for b in latest['front'])
                if not has_recent:
                    all_low_freq = all(front_count.get(b, 0) < front_avg * 0.5 
                                     for b in range(zone_start, min(zone_end, 36)))
                    if all_low_freq:
                        for ball in range(zone_start, min(zone_end, 36)):
                            killed_front.add(ball)
        
        # 清理
        killed_front = {b for b in killed_front if 1 <= b <= 35}
        killed_back = {b for b in killed_back if 1 <= b <= 12}
        
        # 统计
        actual_front = set(test_record['front'])
        actual_back = set(test_record['back'])
        
        front_hit = killed_front & actual_front
        back_hit = killed_back & actual_back
        
        front_accuracy = (len(killed_front) - len(front_hit)) / max(len(killed_front), 1)
        back_accuracy = (len(killed_back) - len(back_hit)) / max(len(killed_back), 1)
        
        return {
            'killed_front_count': len(killed_front),
            'killed_back_count': len(killed_back),
            'front_hit': len(front_hit),
            'back_hit': len(back_hit),
            'front_accuracy': front_accuracy,
            'back_accuracy': back_accuracy,
            'actual_front': actual_front,
            'actual_back': actual_back,
            'killed_front': killed_front,
            'killed_back': killed_back
        }
    
    def _summarize(self, results: List[dict], skip_recent: int) -> Dict:
        """汇总回测结果"""
        if not results:
            return {'error': '无回测结果'}
        
        total_tests = len(results)
        
        front_accuracies = [r['front_accuracy'] for r in results]
        back_accuracies = [r['back_accuracy'] for r in results]
        
        avg_killed_front = sum(r['killed_front_count'] for r in results) / total_tests
        avg_killed_back = sum(r['killed_back_count'] for r in results) / total_tests
        
        front_hits = [r['front_hit'] for r in results]
        back_hits = [r['back_hit'] for r in results]
        
        perfect_front = sum(1 for r in results if r['front_hit'] == 0)
        jackpot_front = sum(1 for r in results if r['front_hit'] == 5)
        
        return {
            'total_tests': total_tests,
            'skip_recent': skip_recent,
            'avg_killed_front': avg_killed_front,
            'avg_killed_back': avg_killed_back,
            'avg_front_accuracy': sum(front_accuracies) / total_tests,
            'avg_back_accuracy': sum(back_accuracies) / total_tests,
            'avg_front_hit': sum(front_hits) / total_tests,
            'avg_back_hit': sum(back_hits) / total_tests,
            'perfect_front_count': perfect_front,
            'perfect_front_rate': perfect_front / total_tests,
            'jackpot_front_count': jackpot_front,
            'jackpot_front_rate': jackpot_front / total_tests,
            'details': results
        }


def print_backtest_result(result: Dict):
    """打印回测结果"""
    if 'error' in result:
        print(f"\n⚠️ 回测失败: {result['error']}")
        return
    
    print("\n═══════════════════════════════════════════════════════")
    print("📊 回测验证报告")
    print("═══════════════════════════════════════════════════════")
    print(f"回测期数: {result['total_tests']} 期")
    print(f"模拟预测: 跳过最近 {result['skip_recent']} 期")
    
    print("\n───────────────────────────────────────────────────────")
    print("【杀号数量统计】")
    print(f"  平均每期杀前区: {result['avg_killed_front']:.1f} 个")
    print(f"  平均每期杀后区: {result['avg_killed_back']:.1f} 个")
    
    print("\n───────────────────────────────────────────────────────")
    print("【杀号准确率】（杀的号码中有多少没中开奖）")
    print(f"  前区准确率: {result['avg_front_accuracy']*100:.1f}%")
    print(f"  后区准确率: {result['avg_back_accuracy']*100:.1f}%")
    
    print("\n───────────────────────────────────────────────────────")
    print("【命中率】（实际开奖号码被杀了多少）")
    print(f"  前区平均命中: {result['avg_front_hit']:.2f} 个/期")
    print(f"  后区平均命中: {result['avg_back_hit']:.2f} 个/期")
    
    print("\n───────────────────────────────────────────────────────")
    print("【特殊统计】")
    print(f"  前区完全没漏 ({result['perfect_front_count']}次): {result['perfect_front_rate']*100:.1f}%")
    print(f"  🎰 前区5个全杀中: {result['jackpot_front_count']}次 ({result['jackpot_front_rate']*100:.1f}%)")
    
    print("\n═══════════════════════════════════════════════════════")
    print("💡 解读:")
    print("  - 准确率 > 90% 表示杀的号码大多确实没中")
    print("  - 命中率 ≈ 0 最好，表示杀的号码都没中")
    print("  - 理想状态: 准确率高 + 命中低 = 杀对且不杀错")
    print("═══════════════════════════════════════════════════════")


if __name__ == '__main__':
    dm = DataManager()
    history = dm.get_history(30)
    
    bt = BacktestEngine(history)
    result = bt.run_backtest(skip_recent=3)
    
    print_backtest_result(result)
