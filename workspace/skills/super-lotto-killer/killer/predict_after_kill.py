"""
大乐透杀号选球技能 - 杀号后预测模块
基于剩余号码池生成预测组合
"""

import random
from typing import List, Tuple, Set


class PredictAfterKill:
    """杀号后预测生成器"""
    
    def __init__(self, remaining_front: List[int], remaining_back: List[int], history: List[dict] = None):
        self.remaining_front = remaining_front
        self.remaining_back = remaining_back
        self.history = history or []
    
    def generate(self, count: int = 3, strategy: str = "balanced") -> List[dict]:
        """
        生成预测号码组合
        
        Args:
            count: 生成组数
            strategy: 策略 - balanced(均衡) / hot(热号) / cold(冷号)
            
        Returns:
            List[dict]: 预测结果列表
        """
        predictions = []
        
        for i in range(count):
            if strategy == "hot":
                pred = self._generate_hot()
            elif strategy == "cold":
                pred = self._generate_cold()
            else:  # balanced
                pred = self._generate_balanced(i)
            
            predictions.append(pred)
        
        return predictions
    
    def _generate_balanced(self, index: int) -> dict:
        """均衡策略：区间、奇偶、大小均衡"""
        front = self._select_balanced_front(index)
        back = self._select_back()
        
        return {
            'front': sorted(front),
            'back': sorted(back)
        }
    
    def _generate_hot(self) -> dict:
        """热号策略：从剩余号码中选择出现频率较高的"""
        if not self.history:
            return self._generate_balanced(0)
        
        # 统计频率
        from killer.data_manager import DataManager
        dm = DataManager()
        stats = dm.get_statistics(self.history)
        
        # 按频率排序剩余号码
        sorted_front = sorted(self.remaining_front, 
                             key=lambda x: stats['front_count'][x], 
                             reverse=True)
        sorted_back = sorted(self.remaining_back,
                            key=lambda x: stats['back_count'][x],
                            reverse=True)
        
        # 选择频率最高的
        front = sorted_front[:5]
        back = sorted_back[:2]
        
        return {'front': front, 'back': back}
    
    def _generate_cold(self) -> dict:
        """冷号策略：从剩余号码中选择出现频率较低的"""
        if not self.history:
            return self._generate_balanced(0)
        
        from killer.data_manager import DataManager
        dm = DataManager()
        stats = dm.get_statistics(self.history)
        
        # 按遗漏排序（遗漏大的优先）
        sorted_front = sorted(self.remaining_front,
                             key=lambda x: stats['front_missing'][x],
                             reverse=True)
        sorted_back = sorted(self.remaining_back,
                            key=lambda x: stats['back_missing'][x],
                             reverse=True)
        
        front = sorted_front[:5]
        back = sorted_back[:2]
        
        return {'front': front, 'back': back}
    
    def _select_balanced_front(self, index: int) -> List[int]:
        """
        均衡选择前区号码
        - 区间均衡：1-12, 13-24, 25-35 各区选取
        - 奇偶均衡：2-3个奇数，2-3个偶数
        """
        selected = set()
        
        # 按区间分组
        zone1 = [b for b in self.remaining_front if 1 <= b <= 12]
        zone2 = [b for b in self.remaining_front if 13 <= b <= 24]
        zone3 = [b for b in self.remaining_front if 25 <= b <= 35]
        
        # 均衡选取：每区1-2个
        zones = [zone1, zone2, zone3]
        
        # 简单轮换策略
        patterns = [
            [2, 2, 1],  # 2-2-1
            [2, 1, 2],  # 2-1-2
            [1, 2, 2],  # 1-2-2
            [1, 2, 2],  # 1-2-2
        ]
        
        pattern = patterns[index % len(patterns)]
        
        for zone, count in zip(zones, pattern):
            if len(zone) >= count:
                chosen = random.sample(zone, count)
                selected.update(chosen)
        
        # 如果不够5个，从其他区补充
        while len(selected) < 5:
            for zone in zones:
                remaining = [b for b in zone if b not in selected]
                if remaining:
                    chosen = random.choice(remaining)
                    selected.add(chosen)
                    if len(selected) >= 5:
                        break
        
        return list(selected)[:5]
    
    def _select_back(self) -> List[int]:
        """选择后区号码"""
        if len(self.remaining_back) < 2:
            return self.remaining_back * 2 if self.remaining_back else [1, 2]
        
        # 随机选择2个
        return random.sample(self.remaining_back, 2)
    
    def add_consecutive(self, front: List[int]) -> List[int]:
        """
        确保有连号
        大乐透连号出现概率约86%
        """
        if len(front) < 2:
            return front
        
        # 检查是否已有连号
        sorted_front = sorted(front)
        has_consecutive = False
        for i in range(len(sorted_front) - 1):
            if sorted_front[i+1] - sorted_front[i] == 1:
                has_consecutive = True
                break
        
        # 如果没有连号，尝试替换一个号码形成连号
        if not has_consecutive and self.remaining_front:
            # 找一个可以形成连号的号码
            for i, ball in enumerate(sorted_front):
                candidates = [b for b in self.remaining_front 
                             if b not in front
                             and (abs(b - ball) == 1 or abs(b - ball) == 2)]
                if candidates:
                    front[i] = random.choice(candidates)
                    break
        
        return front


def format_prediction(pred: dict, index: int) -> str:
    """格式化预测结果"""
    front_str = ' '.join(f"{b:02d}" for b in pred['front'])
    back_str = ' '.join(f"{b:02d}" for b in pred['back'])
    return f"第{index+1}组：{front_str} | 后区 {back_str}"


def print_predictions(predictions: List[dict]):
    """打印预测结果"""
    print("\n═══════════════════════════════════════════════════════")
    print("🎯 精选预测（3组）")
    print("═══════════════════════════════════════════════════════")
    
    for i, pred in enumerate(predictions):
        front_str = ' '.join(f"{b:02d}" for b in sorted(pred['front']))
        back_str = ' '.join(f"{b:02d}" for b in sorted(pred['back']))
        print(f"  第{i+1}组：{front_str} | 后区 {back_str}")


if __name__ == '__main__':
    # 测试
    from killer.data_manager import DataManager
    from killer.kill_rules import KillRuleEngine
    
    dm = DataManager()
    history = dm.get_history(30)
    stats = dm.get_statistics(history)
    
    engine = KillRuleEngine(history, stats)
    engine.run_all()
    
    remaining_front, remaining_back = engine.get_remaining_pool()
    
    print(f"剩余前区: {remaining_front}")
    print(f"剩余后区: {remaining_back}")
    
    predictor = PredictAfterKill(remaining_front, remaining_back, history)
    predictions = predictor.generate(3)
    
    print_predictions(predictions)
