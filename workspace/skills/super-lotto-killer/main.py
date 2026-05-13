#!/usr/bin/env python3
"""
大乐透杀号选球技能 - 主程序

用法:
    python main.py                    # 完整杀号预测
    python main.py --history 50       # 指定分析期数
    python main.py --kill-only         # 只看杀号
    python main.py --backtest          # 回测验证
    python main.py --rules             # 查看规则说明
    python main.py --count 5          # 生成5组预测
"""

import argparse
import sys
import os

# 添加当前目录到路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from killer import (
    DataManager, KillRuleEngine, PredictAfterKill,
    BacktestEngine, generate_report, generate_kill_only_report
)


def parse_args():
    parser = argparse.ArgumentParser(
        description='大乐透杀号选球技能',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  python main.py                    # 完整杀号预测（默认3组）
  python main.py --count 5          # 生成5组预测
  python main.py --history 50       # 用50期数据分析
  python main.py --kill-only        # 只看杀号结果
  python main.py --backtest         # 回测验证
  python main.py --rules            # 查看所有规则说明
        """
    )
    
    parser.add_argument('--history', '-n', type=int, default=30,
                        help='分析的历史期数 (默认: 30)')
    parser.add_argument('--count', '-c', type=int, default=3,
                        help='生成预测组数 (默认: 3)')
    parser.add_argument('--kill-only', '-k', action='store_true',
                        help='只显示杀号结果，不生成预测')
    parser.add_argument('--backtest', '-b', action='store_true',
                        help='运行回测验证')
    parser.add_argument('--rules', '-r', action='store_true',
                        help='显示杀号规则说明')
    parser.add_argument('--verbose', '-v', action='store_true',
                        help='显示详细信息')
    
    return parser.parse_args()


def print_rules():
    """打印杀号规则说明"""
    rules = """
🍀 大乐透杀号规则说明
═══════════════════════════════════════════════════════════════

【规则1】冷热号杀号
───────────────────────────────────────────────────────────────
• 热号：近N期出现频率超过平均值2倍的号码
• 冷号：频率最低的前5个号码
• 逻辑：热号短期可能降温，冷号长期不出概率低

【规则2】遗漏值杀号
───────────────────────────────────────────────────────────────
• 前区遗漏超过15期、后区超过10期的号码
• 逻辑：遗漏越大，开出概率越低

【规则3】尾数杀号
───────────────────────────────────────────────────────────────
• 热尾：出现频率超过平均值1.5倍的尾数（该尾数全部杀掉）
• 冷尾：连续5期未出现的尾数
• 逻辑：尾数分布有周期性规律

【规则4】断区杀号
───────────────────────────────────────────────────────────────
• 7区划分：01-05, 06-10, 11-15, 16-20, 21-25, 26-30, 31-35
• 出号密度极低的区间整体杀掉
• 逻辑：每期至少2个区"断区"

【规则5】加减法杀号
───────────────────────────────────────────────────────────────
• 相邻号相减（大减小）得出杀号
• 上期号码+3（超过35则-35）
• 上期号码-3（小于1则+35）
• 逻辑：基于上期号码的数学运算

【规则6】公式杀号（三种经典公式）
───────────────────────────────────────────────────────────────
• 公式1: A5-A3-A1=B，杀 B, B+1, B+3
• 公式2: A4-A2=C，杀 C, C+10, C-10
• 公式3: 杀 A5-A3, A3-A1, A5-A1 的差值
• 逻辑：经典杀号公式，经验证有一定准确率

【规则7】首尾联动杀号
───────────────────────────────────────────────────────────────
• (上期最小前区 + 后区最大号) % 35
• 逻辑：首尾号码存在某种关联性

【规则8】和值杀号
───────────────────────────────────────────────────────────────
• 根据近10期和值趋势
• 和值偏离平均值过多时，杀掉相应区间的号码
• 逻辑：和值会在均值附近波动

═══════════════════════════════════════════════════════════════
💡 高置信度：被≥2规则同时命中的号码，杀号可信度更高
═══════════════════════════════════════════════════════════════
"""
    print(rules)


def main():
    args = parse_args()
    
    # 规则说明
    if args.rules:
        print_rules()
        return
    
    print("\n🍀 正在加载数据...")
    
    # 数据管理
    dm = DataManager()
    
    # 检查数据量
    total = dm.get_count()
    if total < 10:
        print(f"\n⚠️ 本地数据不足 ({total}期)")
        print("请先运行以下命令抓取数据：")
        print(f"  cd {os.path.dirname(os.path.dirname(__file__))}")
        print("  python scripts/fetch_history.py")
        return
    
    # 获取历史数据
    history = dm.get_history(args.history)
    if len(history) < 5:
        print(f"\n⚠️ 历史数据不足，无法分析")
        return
    
    # 计算统计
    stats = dm.get_statistics(history)
    
    # 执行杀号
    print(f"📊 使用 {len(history)} 期数据执行杀号分析...")
    engine = KillRuleEngine(history, stats)
    results = engine.run_all()
    
    killed_front, killed_back = engine.get_all_killed()
    remaining_front, remaining_back = engine.get_remaining_pool()
    
    # 仅杀号模式
    if args.kill_only:
        generate_kill_only_report(history, stats, engine)
        return
    
    # 生成预测
    predictions = None
    if remaining_front and len(remaining_front) >= 5 and remaining_back and len(remaining_back) >= 2:
        print(f"🎯 基于剩余号码池生成 {args.count} 组预测...")
        predictor = PredictAfterKill(remaining_front, remaining_back, history)
        predictions = predictor.generate(args.count)
    
    # 回测
    backtest_result = None
    if args.backtest:
        print(f"📈 运行回测验证...")
        bt = BacktestEngine(history)
        backtest_result = bt.run_backtest(skip_recent=3)
    
    # 生成报告
    generate_report(history, stats, engine, predictions, backtest_result, args.verbose)


if __name__ == '__main__':
    main()
