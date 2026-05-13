"""
大乐透杀号选球技能 - 报告生成模块
"""

from killer.kill_rules import KillRuleEngine, KillResult
from killer.predict_after_kill import PredictAfterKill, print_predictions
from killer.backtest import BacktestEngine, print_backtest_result


def generate_report(history, stats, engine: KillRuleEngine, 
                   predictions, backtest_result=None, verbose: bool = False):
    """生成完整报告"""
    
    latest = history[0]
    killed_front, killed_back = engine.get_all_killed()
    remaining_front, remaining_back = engine.get_remaining_pool()
    high_conf = engine.get_high_confidence()
    
    # ========== 头部信息 ==========
    print("\n" + "═" * 60)
    print("🍀 大乐透杀号选球报告")
    print("═" * 60)
    print(f"📊 数据来源: 本地数据库 ({len(history)}期)")
    print(f"📅 最新数据: {latest['issue']}期 ({latest['date']})")
    print(f"🔢 上期号码: {' '.join(f'{b:02d}' for b in latest['front'])} | 后区 {' '.join(f'{b:02d}' for b in latest['back'])}")
    
    # ========== 统计分析 ==========
    print("\n" + "═" * 60)
    print("📈 历史统计分析（近{}期）".format(len(history)))
    print("─" * 60)
    
    # 前区热号
    sorted_front = sorted(stats['front_count'].items(), key=lambda x: -x[1])
    hot_front = [f"{b}({c}次)" for b, c in sorted_front[:5]]
    print(f"🔥 前区热号: {', '.join(hot_front)}")
    
    # 前区冷号
    sorted_missing = sorted(stats['front_missing'].items(), key=lambda x: -x[1])
    cold_front = [f"{b}(漏{c}期)" for b, c in sorted_missing[:5] if c > 0]
    if cold_front:
        print(f"❄️ 前区冷号: {', '.join(cold_front)}")
    
    # 尾数趋势
    tail_appear = {}
    for ball in range(1, 36):
        tail = ball % 10
        if tail not in tail_appear:
            tail_appear[tail] = 0
        tail_appear[tail] += stats['front_count'][ball]
    
    avg_tail = sum(tail_appear.values()) / 10
    hot_tails = [t for t, c in tail_appear.items() if c >= avg_tail * 1.3]
    cold_tails = [t for t, c in tail_appear.items() if c <= avg_tail * 0.7]
    
    if hot_tails:
        print(f"🔢 活跃尾数: {', '.join(map(str, hot_tails))}")
    if cold_tails:
        print(f"🔢 低迷尾数: {', '.join(map(str, cold_tails))}")
    
    # ========== 杀号详情 ==========
    print("\n" + "═" * 60)
    print("🔪 杀号详情")
    print("─" * 60)
    
    for result in engine.results:
        if result.killed_front or result.killed_back:
            front_str = ', '.join(f"{b:02d}" for b in sorted(result.killed_front)) if result.killed_front else '-'
            back_str = ', '.join(f"{b:02d}" for b in sorted(result.killed_back)) if result.killed_back else '-'
            
            print(f"\n【{result.rule_name}】")
            if result.killed_front:
                print(f"  前区: {front_str}")
            if result.killed_back:
                print(f"  后区: {back_str}")
    
    # ========== 高置信度 ==========
    if high_conf:
        print("\n" + "─" * 60)
        print("⭐ 高置信度杀号（被≥2规则同时命中）")
        print("─" * 60)
        for ball, rules in sorted(high_conf.items()):
            print(f"  {ball:02d}号 ← {' + '.join(rules)}")
    
    # ========== 汇总 ==========
    print("\n" + "═" * 60)
    print("📊 杀号统计")
    print("─" * 60)
    print(f"  前区: 杀掉 {len(killed_front)} 个 → 剩余 {len(remaining_front)} 个")
    print(f"  后区: 杀掉 {len(killed_back)} 个 → 剩余 {len(remaining_back)} 个")
    
    if remaining_front:
        print(f"\n  剩余前区: {' '.join(f'{b:02d}' for b in remaining_front)}")
    if remaining_back:
        print(f"  剩余后区: {' '.join(f'{b:02d}' for b in remaining_back)}")
    
    # ========== 预测 ==========
    if predictions:
        print_predictions(predictions)
    
    # ========== 回测结果 ==========
    if backtest_result and 'error' not in backtest_result:
        print_backtest_result(backtest_result)
    
    # ========== 底部 ==========
    print("\n" + "═" * 60)
    print("⚠️ 彩票开奖完全随机，预测仅供参考，理性购彩！")
    print("═" * 60)


def generate_kill_only_report(history, stats, engine: KillRuleEngine):
    """仅杀号报告（不生成预测）"""
    
    latest = history[0]
    killed_front, killed_back = engine.get_all_killed()
    remaining_front, remaining_back = engine.get_remaining_pool()
    high_conf = engine.get_high_confidence()
    
    print("\n🍀 大乐透杀号报告")
    print("═" * 50)
    print(f"📅 {latest['issue']}期 | 上期: {' '.join(f'{b:02d}' for b in latest['front'])}")
    
    print("\n📊 杀号统计")
    print(f"  前区杀号: {len(killed_front)}个 → 剩余{len(remaining_front)}个")
    print(f"  后区杀号: {len(killed_back)}个 → 剩余{len(remaining_back)}个")
    
    if remaining_front:
        print(f"\n✅ 剩余前区: {' '.join(f'{b:02d}' for b in remaining_front)}")
    
    if high_conf:
        print("\n⭐ 高置信度:")
        for ball, rules in sorted(high_conf.items())[:5]:
            print(f"  {ball:02d}号")
