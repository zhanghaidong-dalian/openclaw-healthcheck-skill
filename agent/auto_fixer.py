#!/usr/bin/env python3
"""
OpenClaw 安全技能 - Agent 模式自动修复器
功能：在 Agent 平台自动修复安全问题
版本：5.2.0
更新：2026-05-13
"""

import os
import json
import shutil
import subprocess
from datetime import datetime
from typing import List, Dict, Optional
from dataclasses import dataclass
from enum import Enum


class FixLevel(Enum):
    """修复级别"""
    AUTO_SAFE = "auto-safe"        # 安全无害，自动执行
    AUTO_RISK = "auto-risk"         # 有风险，需确认
    MANUAL_GUIDE = "manual-guide"   # 需手动操作
    MANUAL_EXPERT = "manual-expert" # 专家级问题


@dataclass
class Issue:
    """安全问题"""
    id: str
    category: str
    severity: str  # high, medium, low
    title: str
    description: str
    fix_level: FixLevel
    fix_command: Optional[str] = None
    fix_guide: Optional[str] = None


class AutoFixer:
    """自动修复器"""
    
    def __init__(self, backup_dir: str = "/tmp/healthcheck/backups"):
        self.backup_dir = backup_dir
        self.fix_log = []
        os.makedirs(backup_dir, exist_ok=True)
    
    def fix(self, issues: List[Issue], level: FixLevel = FixLevel.AUTO_SAFE, 
            dry_run: bool = False) -> Dict:
        """
        自动修复安全问题
        
        Args:
            issues: 问题列表
            level: 修复级别（只修复该级别及以下的问题）
            dry_run: 是否仅模拟运行
        
        Returns:
            修复结果报告
        """
        results = {
            "timestamp": datetime.now().isoformat(),
            "total_issues": len(issues),
            "fixed": 0,
            "skipped": 0,
            "failed": 0,
            "details": []
        }
        
        level_order = {
            FixLevel.AUTO_SAFE: 0,
            FixLevel.AUTO_RISK: 1,
            FixLevel.MANUAL_GUIDE: 2,
            FixLevel.MANUAL_EXPERT: 3
        }
        
        for issue in issues:
            # 只修复指定级别的问题
            if level_order[issue.fix_level] > level_order[level]:
                results["skipped"] += 1
                results["details"].append({
                    "issue_id": issue.id,
                    "status": "skipped",
                    "reason": f"修复级别超出限制 ({issue.fix_level.value} > {level.value})"
                })
                continue
            
            # 根据修复级别处理
            if issue.fix_level == FixLevel.AUTO_SAFE:
                success = self._fix_auto_safe(issue, dry_run)
            elif issue.fix_level == FixLevel.AUTO_RISK:
                success = self._fix_auto_risk(issue, dry_run)
            elif issue.fix_level == FixLevel.MANUAL_GUIDE:
                success = self._provide_guide(issue)
            else:
                success = self._provide_expert_guide(issue)
            
            if success:
                results["fixed"] += 1
                results["details"].append({
                    "issue_id": issue.id,
                    "status": "fixed",
                    "level": issue.fix_level.value
                })
            else:
                results["failed"] += 1
                results["details"].append({
                    "issue_id": issue.id,
                    "status": "failed",
                    "level": issue.fix_level.value
                })
        
        return results
    
    def _fix_auto_safe(self, issue: Issue, dry_run: bool) -> bool:
        """自动安全修复"""
        if not issue.fix_command:
            return False
        
        try:
            if dry_run:
                print(f"[DRY RUN] Would execute: {issue.fix_command}")
                return True
            
            # 备份
            self._backup(issue)
            
            # 执行修复
            result = subprocess.run(
                issue.fix_command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                self.fix_log.append({
                    "issue_id": issue.id,
                    "command": issue.fix_command,
                    "timestamp": datetime.now().isoformat()
                })
                return True
            else:
                print(f"修复失败: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"修复异常: {e}")
            return False
    
    def _fix_auto_risk(self, issue: Issue, dry_run: bool) -> bool:
        """有风险修复（需确认）"""
        print(f"\n⚠️  警告: 此操作有风险")
        print(f"问题: {issue.title}")
        print(f"描述: {issue.description}")
        print(f"修复命令: {issue.fix_command}")
        
        if dry_run:
            print("[DRY RUN] 不会实际执行")
            return True
        
        confirm = input("\n是否执行？(yes/no): ")
        if confirm.lower() == "yes":
            return self._fix_auto_safe(issue, dry_run=False)
        
        print("已跳过")
        return False
    
    def _provide_guide(self, issue: Issue) -> bool:
        """提供手动修复指南"""
        print(f"\n📋 手动修复指南")
        print(f"问题: {issue.title}")
        print(f"严重性: {issue.severity}")
        print(f"\n{issue.fix_guide}")
        return True
    
    def _provide_expert_guide(self, issue: Issue) -> bool:
        """提供专家级指南"""
        print(f"\n🔴 专家级问题")
        print(f"问题: {issue.title}")
        print(f"建议: 此问题需要专业安全人员处理")
        print(f"参考: {issue.fix_guide}")
        return True
    
    def _backup(self, issue: Issue):
        """备份相关文件"""
        # 根据问题类型备份不同文件
        backup_map = {
            "ssh": "/etc/ssh/sshd_config",
            "firewall": "/etc/ufw/ufw.conf",
            "permissions": "/etc/permissions"
        }
        
        for key, file_path in backup_map.items():
            if key in issue.category.lower():
                if os.path.exists(file_path):
                    backup_name = f"{os.path.basename(file_path)}.{datetime.now().strftime('%Y%m%d_%H%M%S')}.bak"
                    backup_path = os.path.join(self.backup_dir, backup_name)
                    shutil.copy2(file_path, backup_path)
                    print(f"✓ 已备份: {backup_path}")
    
    def generate_fix_script(self, issues: List[Issue], output_file: str = "fix-script.sh"):
        """生成修复脚本"""
        with open(output_file, 'w') as f:
            f.write("#!/bin/bash\n")
            f.write(f"# OpenClaw 自动修复脚本\n")
            f.write(f"# 生成时间: {datetime.now().isoformat()}\n")
            f.write("# 警告: 请在执行前仔细检查脚本内容！\n\n")
            
            for issue in issues:
                if issue.fix_command:
                    f.write(f"# 问题: {issue.title}\n")
                    f.write(f"# 级别: {issue.fix_level.value}\n")
                    f.write(f"# {issue.fix_command}\n\n")
        
        os.chmod(output_file, 0o755)
        print(f"✓ 修复脚本已生成: {output_file}")


# 预定义问题库
COMMON_ISSUES = [
    Issue(
        id="ssh-root-login",
        category="ssh",
        severity="high",
        title="允许 root 用户 SSH 登录",
        description="root 用户直接登录存在安全风险",
        fix_level=FixLevel.AUTO_RISK,
        fix_command="sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config",
        fix_guide="编辑 /etc/ssh/sshd_config，设置 PermitRootLogin no"
    ),
    Issue(
        id="ssh-password-auth",
        category="ssh",
        severity="high",
        title="允许密码认证",
        description="密码认证易受暴力破解攻击",
        fix_level=FixLevel.AUTO_RISK,
        fix_command="sudo sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config",
        fix_guide="编辑 /etc/ssh/sshd_config，设置 PasswordAuthentication no"
    ),
    Issue(
        id="ssh-default-port",
        category="ssh",
        severity="medium",
        title="SSH 使用默认端口 22",
        description="默认端口易被扫描发现",
        fix_level=FixLevel.MANUAL_GUIDE,
        fix_guide="建议修改为非标准端口（如 2222），并更新防火墙规则"
    ),
    Issue(
        id="fail2ban-not-installed",
        category="security",
        severity="medium",
        title="未安装 fail2ban",
        description="缺少防暴力破解保护",
        fix_level=FixLevel.AUTO_SAFE,
        fix_command="sudo apt-get install -y fail2ban && sudo systemctl enable fail2ban",
        fix_guide="安装 fail2ban 防止暴力破解"
    ),
    Issue(
        id="firewall-disabled",
        category="firewall",
        severity="high",
        title="防火墙未启用",
        description="系统暴露在未保护状态",
        fix_level=FixLevel.AUTO_RISK,
        fix_command="sudo ufw enable",
        fix_guide="启用 UFW 防火墙并配置规则"
    )
]


# 示例用法
if __name__ == "__main__":
    # 创建修复器
    fixer = AutoFixer()
    
    # 扫描并获取问题（这里使用预定义问题演示）
    print("🔍 扫描安全问题...")
    issues = COMMON_ISSUES[:3]  # 演示前3个问题
    
    print(f"发现 {len(issues)} 个问题\n")
    
    # 自动修复（仅 auto-safe 级别）
    print("修复级别: AUTO_SAFE")
    results = fixer.fix(issues, level=FixLevel.AUTO_SAFE, dry_run=True)
    
    print(f"\n📊 修复结果:")
    print(f"  - 总计: {results['total_issues']}")
    print(f"  - 已修复: {results['fixed']}")
    print(f"  - 已跳过: {results['skipped']}")
    print(f"  - 失败: {results['failed']}")
    
    # 生成修复脚本
    fixer.generate_fix_script(issues)
