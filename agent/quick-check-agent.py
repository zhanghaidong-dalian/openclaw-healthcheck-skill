#!/usr/bin/env python3
#========================================
# 一键安全检查脚本 (Agent模式专用)
# 版本: v5.0.0
# 用途: Coze/Dify/混元等无exec环境
#========================================

import json
import os
import sys
from datetime import datetime
from typing import Dict, List, Tuple

# 颜色定义
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'

class SecurityChecker:
    """安全检查器 - 无需root权限"""
    
    def __init__(self):
        self.issues = []
        self.warnings = []
        self.passed = []
        self.score = 100
        
    def check_openclaw_installed(self) -> bool:
        """检查OpenClaw是否安装"""
        print(f"{Colors.BLUE}[1/6] 检查OpenClaw安装状态...{Colors.NC}")
        
        # 检查常见安装路径
        possible_paths = [
            '/usr/local/bin/openclaw',
            '/usr/bin/openclaw',
            os.path.expanduser('~/.local/bin/openclaw'),
            os.path.expanduser('~/openclaw'),
        ]
        
        # 检查PATH中的openclaw
        for path in os.environ.get('PATH', '').split(':'):
            full_path = os.path.join(path, 'openclaw')
            if os.path.isfile(full_path) and os.access(full_path, os.X_OK):
                self.passed.append(f"OpenClaw已安装: {full_path}")
                return True
        
        for path in possible_paths:
            if os.path.isfile(path) and os.access(path, os.X_OK):
                self.passed.append(f"OpenClaw已安装: {path}")
                return True
        
        self.warnings.append("OpenClaw未在PATH中找到")
        return False
    
    def check_config_directory(self) -> None:
        """检查配置目录"""
        print(f"{Colors.BLUE}[2/6] 检查配置目录...{Colors.NC}")
        
        home = os.path.expanduser('~')
        config_dir = os.path.join(home, '.openclaw')
        
        if not os.path.exists(config_dir):
            self.warnings.append(f"配置目录不存在: {config_dir}")
            self.score -= 15
            return
        
        # 检查权限
        try:
            mode = os.stat(config_dir).st_mode & 0o777
            mode_str = oct(mode)[-3:]
            
            if mode_str == '700':
                self.passed.append(f"配置目录权限正常: {mode_str}")
            else:
                self.warnings.append(f"配置目录权限过宽: {mode_str} (建议: 700)")
                self.score -= 10
        except Exception as e:
            self.warnings.append(f"无法检查配置目录权限: {e}")
    
    def check_config_files(self) -> None:
        """检查配置文件"""
        print(f"{Colors.BLUE}[3/6] 检查配置文件...{Colors.NC}")
        
        home = os.path.expanduser('~')
        config_file = os.path.join(home, '.openclaw', 'gateway.yml')
        db_file = os.path.join(home, '.openclaw', 'gateway.db')
        
        # 检查gateway.yml
        if os.path.exists(config_file):
            try:
                mode = os.stat(config_file).st_mode & 0o777
                mode_str = oct(mode)[-3:]
                
                if mode_str == '600':
                    self.passed.append(f"配置文件权限正常: {mode_str}")
                else:
                    self.warnings.append(f"配置文件权限过宽: {mode_str} (建议: 600)")
                    self.score -= 5
            except Exception as e:
                self.warnings.append(f"无法检查配置文件权限: {e}")
        else:
            self.warnings.append(f"配置文件不存在: {config_file}")
        
        # 检查gateway.db
        if os.path.exists(db_file):
            self.passed.append("数据库文件存在")
        else:
            self.warnings.append("数据库文件不存在 (可能首次运行)")
    
    def check_logs_directory(self) -> None:
        """检查日志目录"""
        print(f"{Colors.BLUE}[4/6] 检查日志目录...{Colors.NC}")
        
        home = os.path.expanduser('~')
        logs_dir = os.path.join(home, '.openclaw', 'logs')
        
        if os.path.exists(logs_dir):
            self.passed.append("日志目录存在")
            
            # 检查日志文件权限
            try:
                for item in os.listdir(logs_dir):
                    if item.endswith('.log'):
                        log_path = os.path.join(logs_dir, item)
                        mode = os.stat(log_path).st_mode & 0o777
                        mode_str = oct(mode)[-3:]
                        
                        if int(mode_str, 8) <= 0o640:
                            self.passed.append(f"日志文件权限正常: {item} ({mode_str})")
                        else:
                            self.warnings.append(f"日志文件权限过宽: {item} ({mode_str})")
            except Exception as e:
                self.warnings.append(f"无法检查日志文件: {e}")
        else:
            self.warnings.append("日志目录不存在")
    
    def check_environment_vars(self) -> None:
        """检查环境变量"""
        print(f"{Colors.BLUE}[5/6] 检查环境变量...{Colors.NC}")
        
        # 检查敏感环境变量
        sensitive_vars = ['OPENCLAW_TOKEN', 'GATEWAY_SECRET', 'API_KEY']
        
        for var in sensitive_vars:
            if var in os.environ:
                self.passed.append(f"环境变量已设置: {var}")
            else:
                self.warnings.append(f"环境变量未设置: {var}")
    
    def run_security_audit(self) -> None:
        """运行安全审计（如果OpenClaw可用）"""
        print(f"{Colors.BLUE}[6/6] 安全审计...{Colors.NC}")
        
        # 检查subprocess是否可用
        try:
            import subprocess
            
            # 尝试运行openclaw security audit
            try:
                result = subprocess.run(
                    ['openclaw', 'security', 'audit'],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                if result.returncode == 0:
                    self.passed.append("OpenClaw安全审计通过")
                else:
                    self.warnings.append("OpenClaw安全审计发现问题")
                    if result.stdout:
                        for line in result.stdout.split('\n')[:5]:
                            if line.strip():
                                self.warnings.append(f"  {line.strip()}")
            except FileNotFoundError:
                self.warnings.append("无法运行openclaw命令 (Agent模式限制)")
            except subprocess.TimeoutExpired:
                self.warnings.append("安全审计超时")
        except ImportError:
            self.warnings.append("subprocess模块不可用")
    
    def generate_report(self) -> Dict:
        """生成检查报告"""
        print("\n" + "="*50)
        print(f"{Colors.BLUE}📊 安全检查报告{Colors.NC}")
        print("="*50)
        
        print(f"\n检查时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        # 评分
        print(f"\n安全评分: {self.score}/100")
        
        if self.score >= 90:
            print(f"{Colors.GREEN}🟢 状态: 安全{Colors.NC}")
        elif self.score >= 70:
            print(f"{Colors.YELLOW}🟡 状态: 需注意{Colors.NC}")
        else:
            print(f"{Colors.RED}🔴 状态: 需修复{Colors.NC}")
        
        # 通过项
        if self.passed:
            print(f"\n{Colors.GREEN}✅ 通过项 ({len(self.passed)}){Colors.NC}")
            for item in self.passed:
                print(f"  ✓ {item}")
        
        # 警告项
        if self.warnings:
            print(f"\n{Colors.YELLOW}⚠️ 警告项 ({len(self.warnings)}){Colors.NC}")
            for item in self.warnings:
                print(f"  ⚠ {item}")
        
        # 问题项
        if self.issues:
            print(f"\n{Colors.RED}🔴 问题项 ({len(self.issues)}){Colors.NC}")
            for item in self.issues:
                print(f"  ✗ {item}")
        
        # 建议
        print(f"\n{Colors.BLUE}💡 建议操作{Colors.NC}")
        print("-" * 50)
        
        if self.score < 100:
            print("1. 修复配置文件权限: chmod 600 ~/.openclaw/gateway.yml")
            print("2. 修复配置目录权限: chmod 700 ~/.openclaw")
        
        print("3. 运行完整安全审计: openclaw security audit --deep")
        print("4. 设置定时检查: openclaw cron add ...")
        
        return {
            'score': self.score,
            'passed': self.passed,
            'warnings': self.warnings,
            'issues': self.issues,
            'timestamp': datetime.now().isoformat()
        }
    
    def run_all_checks(self) -> Dict:
        """运行所有检查"""
        self.check_openclaw_installed()
        self.check_config_directory()
        self.check_config_files()
        self.check_logs_directory()
        self.check_environment_vars()
        self.run_security_audit()
        
        return self.generate_report()


def main():
    """主函数"""
    print("\n" + "="*50)
    print(f"{Colors.BLUE}🔒 OpenClaw 一键安全检查 v5.0.0{Colors.NC}")
    print("="*50)
    print(f"\n{Colors.YELLOW}Agent模式 - 无需root权限{Colors.NC}\n")
    
    checker = SecurityChecker()
    report = checker.run_all_checks()
    
    # JSON输出（可选）
    if '--json' in sys.argv:
        print("\n" + "="*50)
        print("JSON格式输出:")
        print("="*50)
        print(json.dumps(report, indent=2, ensure_ascii=False))
    
    return 0 if report['score'] >= 80 else 1


if __name__ == '__main__':
    sys.exit(main())
