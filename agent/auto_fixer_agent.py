#!/usr/bin/env python3
"""
Agent 模式自动修复模块
支持 Coze/Dify/混元/钉钉 等受限平台的自动修复功能

使用方式：
    python3 auto_fixer_agent.py --check-json '<JSON检查结果>'
    python3 auto_fixer_agent.py --fix <issue-id>
"""

import json
import os
import sys
import argparse
from typing import Dict, List, Optional, Any

# 修复指南数据库
FIX_GUIDES: Dict[str, Dict[str, Any]] = {
    "ssh-001": {
        "title": "SSH 允许密码登录",
        "severity": "high",
        "auto_fix_cmd": "sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && systemctl restart sshd",
        "verification": "grep '^PasswordAuthentication' /etc/ssh/sshd_config | grep -v '#' | grep 'no'",
        "backup_cmd": "cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak",
        "rollback_cmd": "cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config && systemctl restart sshd",
        "risk_level": "medium",
        "requires_root": True,
    },
    "ssh-002": {
        "title": "SSH 允许 root 登录",
        "severity": "high",
        "auto_fix_cmd": "sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config && systemctl restart sshd",
        "verification": "grep '^PermitRootLogin' /etc/ssh/sshd_config | grep -v '#' | grep 'no'",
        "backup_cmd": "cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak",
        "rollback_cmd": "cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config && systemctl restart sshd",
        "risk_level": "medium",
        "requires_root": True,
    },
    "ssh-003": {
        "title": "SSH 空密码",
        "severity": "critical",
        "auto_fix_cmd": "passwd -l root 2>/dev/null || echo 'Please set password manually'",
        "verification": "! grep -q '^root::' /etc/shadow",
        "backup_cmd": "cp /etc/shadow /etc/shadow.bak 2>/dev/null || true",
        "rollback_cmd": "passwd root 2>/dev/null || echo 'Manual intervention required'",
        "risk_level": "high",
        "requires_root": True,
    },
    "ssh-004": {
        "title": "SSH Protocol 版本",
        "severity": "medium",
        "auto_fix_cmd": "sed -i 's/^Protocol.*/Protocol 2/' /etc/ssh/sshd_config && systemctl restart sshd",
        "verification": "grep '^Protocol' /etc/ssh/sshd_config | grep '2'",
        "backup_cmd": "cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak",
        "rollback_cmd": "cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config && systemctl restart sshd",
        "risk_level": "low",
        "requires_root": True,
    },
    "ssh-005": {
        "title": "SSH MaxAuthTries 设置",
        "severity": "medium",
        "auto_fix_cmd": "sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config && systemctl restart sshd",
        "verification": "grep '^MaxAuthTries' /etc/ssh/sshd_config | awk '{print $2}' | grep -E '^[123]$'",
        "backup_cmd": "cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak",
        "rollback_cmd": "cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config && systemctl restart sshd",
        "risk_level": "low",
        "requires_root": True,
    },
    "ssh-006": {
        "title": "SSH ClientAliveInterval",
        "severity": "low",
        "auto_fix_cmd": "sed -i 's/^#*ClientAliveInterval.*/ClientAliveInterval 300/' /etc/ssh/sshd_config && systemctl restart sshd",
        "verification": "grep '^ClientAliveInterval' /etc/ssh/sshd_config | awk '{print $2}' | grep -E '^[0-9]+$'",
        "backup_cmd": "cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak",
        "rollback_cmd": "cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config && systemctl restart sshd",
        "risk_level": "none",
        "requires_root": True,
    },
    "ssh-007": {
        "title": "SSH PubkeyAuthentication",
        "severity": "medium",
        "auto_fix_cmd": "sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && systemctl restart sshd",
        "verification": "grep '^PubkeyAuthentication' /etc/ssh/sshd_config | grep -v '#' | grep 'yes'",
        "backup_cmd": "cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak",
        "rollback_cmd": "cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config && systemctl restart sshd",
        "risk_level": "low",
        "requires_root": True,
    },
    "firewall-001": {
        "title": "防火墙未启用",
        "severity": "high",
        "auto_fix_cmd": "ufw --force enable || systemctl enable ufw",
        "verification": "ufw status | grep -q 'Status: active'",
        "backup_cmd": "ufw status > /tmp/ufw-backup.txt",
        "rollback_cmd": "ufw disable || true",
        "risk_level": "medium",
        "requires_root": True,
    },
    "firewall-002": {
        "title": "默认入站规则",
        "severity": "medium",
        "auto_fix_cmd": "ufw default deny incoming",
        "verification": "ufw status verbose | grep -q 'Default deny incoming'",
        "backup_cmd": "ufw status verbose > /tmp/ufw-backup.txt",
        "rollback_cmd": "ufw default allow incoming",
        "risk_level": "low",
        "requires_root": True,
    },
    "fail2ban-001": {
        "title": "Fail2ban 未安装",
        "severity": "medium",
        "auto_fix_cmd": "apt-get update && apt-get install -y fail2ban",
        "verification": "which fail2ban",
        "backup_cmd": "echo 'No backup needed for installation'",
        "rollback_cmd": "apt-get remove -y fail2ban",
        "risk_level": "none",
        "requires_root": True,
    },
    "fail2ban-002": {
        "title": "Fail2ban 服务未启用",
        "severity": "medium",
        "auto_fix_cmd": "systemctl enable fail2ban && systemctl start fail2ban",
        "verification": "systemctl is-active fail2ban",
        "backup_cmd": "cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.bak",
        "rollback_cmd": "systemctl stop fail2ban",
        "risk_level": "none",
        "requires_root": True,
    },
    "fail2ban-003": {
        "title": "Fail2ban SSH 防护",
        "severity": "low",
        "auto_fix_cmd": "fail2ban-client set sshd enabled true",
        "verification": "fail2ban-client status sshd | grep -q 'Status'",
        "backup_cmd": "fail2ban-client get sshd | head -20 > /tmp/fail2ban-backup.txt",
        "rollback_cmd": "fail2ban-client set sshd enabled false",
        "risk_level": "none",
        "requires_root": True,
    },
    "system-001": {
        "title": "系统更新未检查",
        "severity": "medium",
        "auto_fix_cmd": "apt-get update && apt-get upgrade -y",
        "verification": "apt list --upgradable 2>/dev/null | grep -v 'Listing...' | wc -l",
        "backup_cmd": "echo 'Package updates do not require backup'",
        "rollback_cmd": "echo 'Rollback not applicable for package updates'",
        "risk_level": "none",
        "requires_root": True,
    },
    "system-002": {
        "title": "可疑定时任务",
        "severity": "high",
        "auto_fix_cmd": "crontab -r 2>/dev/null || true",
        "verification": "crontab -l | grep -v '^#' | wc -l",
        "backup_cmd": "crontab -l > /tmp/crontab-backup.txt",
        "rollback_cmd": "crontab /tmp/crontab-backup.txt 2>/dev/null || true",
        "risk_level": "high",
        "requires_root": True,
    },
    "system-monitor-001": {
        "title": "资源监控未配置",
        "severity": "low",
        "auto_fix_cmd": "apt-get install -y sysstat && systemctl enable sysstat && systemctl start sysstat",
        "verification": "which sar && systemctl is-active sysstat",
        "backup_cmd": "echo 'Monitoring setup does not require backup'",
        "rollback_cmd": "systemctl stop sysstat",
        "risk_level": "none",
        "requires_root": True,
    },
    "openclaw-001": {
        "title": "OpenClaw 配置权限",
        "severity": "medium",
        "auto_fix_cmd": "chmod 600 ~/.openclaw/config.yaml 2>/dev/null || true",
        "verification": "stat -c '%a' ~/.openclaw/config.yaml 2>/dev/null | grep -E '^600$'",
        "backup_cmd": "cp ~/.openclaw/config.yaml ~/.openclaw/config.yaml.bak",
        "rollback_cmd": "chmod 644 ~/.openclaw/config.yaml",
        "risk_level": "low",
        "requires_root": False,
    },
    "openclaw-002": {
        "title": "OpenClaw 日志权限",
        "severity": "low",
        "auto_fix_cmd": "chmod -R 700 ~/.openclaw/logs 2>/dev/null || true",
        "verification": "stat -c '%a' ~/.openclaw/logs 2>/dev/null | grep -E '^700$'",
        "backup_cmd": "ls -la ~/.openclaw/logs > /tmp/openclaw-logs-backup.txt",
        "rollback_cmd": "chmod -R 755 ~/.openclaw/logs",
        "risk_level": "none",
        "requires_root": False,
    },
    "password-001": {
        "title": "密码策略",
        "severity": "medium",
        "auto_fix_cmd": "apt-get install -y libpam-pwquality && pam-auth-update --enable pwquality",
        "verification": "grep -q 'pam_pwquality.so' /etc/pam.d/common-password",
        "backup_cmd": "cp /etc/pam.d/common-password /etc/pam.d/common-password.bak",
        "rollback_cmd": "cp /etc/pam.d/common-password.bak /etc/pam.d/common-password",
        "risk_level": "medium",
        "requires_root": True,
    },
    "kernel-001": {
        "title": "内核参数优化",
        "severity": "low",
        "auto_fix_cmd": "sysctl -w net.ipv4.conf.all.rp_filter=1 && sysctl -w net.ipv4.conf.default.rp_filter=1",
        "verification": "sysctl net.ipv4.conf.all.rp_filter | grep '= 1'",
        "backup_cmd": "sysctl -a > /tmp/sysctl-backup.txt",
        "rollback_cmd": "sysctl --system",
        "risk_level": "none",
        "requires_root": True,
    },
    "network-001": {
        "title": "网络配置",
        "severity": "low",
        "auto_fix_cmd": "sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1",
        "verification": "sysctl net.ipv4.icmp_echo_ignore_broadcasts | grep '= 1'",
        "backup_cmd": "sysctl -a > /tmp/sysctl-backup.txt",
        "rollback_cmd": "sysctl --system",
        "risk_level": "none",
        "requires_root": True,
    },
}

class AgentAutoFixer:
    """Agent模式自动修复器"""
    
    def __init__(self, dry_run: bool = True, verbose: bool = False):
        self.dry_run = dry_run
        self.verbose = verbose
        self.results = []
        
    def get_fix_guide(self, issue_id: str) -> Optional[Dict[str, Any]]:
        """获取修复指南"""
        return FIX_GUIDES.get(issue_id)
    
    def list_all_fixes(self) -> List[Dict[str, Any]]:
        """列出所有可用的修复"""
        fixes = []
        for issue_id, guide in FIX_GUIDES.items():
            fixes.append({
                "id": issue_id,
                "title": guide["title"],
                "severity": guide["severity"],
                "risk_level": guide["risk_level"],
                "requires_root": guide["requires_root"],
            })
        return fixes
    
    def can_auto_fix(self, issue_id: str) -> bool:
        """检查是否可以自动修复"""
        guide = self.get_fix_guide(issue_id)
        if not guide:
            return False
        return guide.get("risk_level") in ["none", "low"]
    
    def get_fix_commands(self, issue_id: str) -> Dict[str, str]:
        """获取修复命令"""
        guide = self.get_fix_guide(issue_id)
        if not guide:
            return {}
        return {
            "backup": guide.get("backup_cmd", ""),
            "fix": guide.get("auto_fix_cmd", ""),
            "verify": guide.get("verification", ""),
            "rollback": guide.get("rollback_cmd", ""),
        }
    
    def execute_fix(self, issue_id: str) -> Dict[str, Any]:
        """执行修复"""
        guide = self.get_fix_guide(issue_id)
        if not guide:
            return {
                "success": False,
                "error": f"Unknown issue ID: {issue_id}",
            }
        
        result = {
            "issue_id": issue_id,
            "title": guide["title"],
            "severity": guide["severity"],
            "risk_level": guide["risk_level"],
            "requires_root": guide["requires_root"],
            "steps": [],
            "success": True,
        }
        
        # 检查权限
        if guide["requires_root"] and os.geteuid() != 0:
            result["steps"].append({
                "step": "permission_check",
                "status": "warning",
                "message": "需要root权限，但当前非root用户",
            })
            # 非root用户只能获取指导，不能执行
            result["steps"].append({
                "step": "fix_commands",
                "status": "info",
                "commands": guide["auto_fix_cmd"],
                "message": "以下是需要sudo/root执行的修复命令：",
            })
            result["steps"].append({
                "step": "backup_commands",
                "status": "info",
                "commands": guide["backup_cmd"],
                "message": "执行修复前建议先备份：",
            })
            result["steps"].append({
                "step": "rollback_commands",
                "status": "info",
                "commands": guide["rollback_cmd"],
                "message": "如需回滚，执行：",
            })
            return result
        
        # 1. 备份
        if guide.get("backup_cmd"):
            result["steps"].append({
                "step": "backup",
                "command": guide["backup_cmd"],
                "status": "pending",
            })
        
        # 2. 执行修复
        result["steps"].append({
            "step": "fix",
            "command": guide["auto_fix_cmd"],
            "status": "pending",
        })
        
        # 3. 验证
        result["steps"].append({
            "step": "verify",
            "command": guide["verification"],
            "status": "pending",
        })
        
        if self.dry_run:
            result["steps"].append({
                "step": "dry_run",
                "status": "info",
                "message": "Dry-run模式：未实际执行修复",
            })
            return result
        
        # 实际执行
        import subprocess
        for step in result["steps"]:
            if step["status"] != "pending":
                continue
            try:
                if step["step"] == "backup":
                    subprocess.run(step["command"], shell=True, 
                                 capture_output=True, timeout=30)
                    step["status"] = "success"
                elif step["step"] == "fix":
                    result_exec = subprocess.run(step["command"], shell=True,
                                               capture_output=True, timeout=60)
                    if result_exec.returncode == 0:
                        step["status"] = "success"
                    else:
                        step["status"] = "failed"
                        step["error"] = result_exec.stderr.decode()
                        result["success"] = False
                elif step["step"] == "verify":
                    result_exec = subprocess.run(step["command"], shell=True,
                                               capture_output=True, timeout=30)
                    if result_exec.returncode == 0:
                        step["status"] = "success"
                    else:
                        step["status"] = "warning"
                        step["message"] = "验证未通过，可能需要手动检查"
            except subprocess.TimeoutExpired:
                step["status"] = "failed"
                step["error"] = "Command timeout"
                result["success"] = False
            except Exception as e:
                step["status"] = "failed"
                step["error"] = str(e)
                result["success"] = False
        
        return result
    
    def fix_from_check_result(self, check_result: Dict) -> List[Dict]:
        """从检查结果自动修复"""
        findings = check_result.get("findings", [])
        fixed = []
        
        for finding in findings:
            issue_id = finding.get("id", "")
            if self.can_auto_fix(issue_id):
                result = self.execute_fix(issue_id)
                fixed.append(result)
        
        return fixed

def main():
    parser = argparse.ArgumentParser(
        description="Agent模式自动修复工具 - 支持Coze/Dify/混元/钉钉"
    )
    parser.add_argument("--check-json", help="JSON格式的检查结果")
    parser.add_argument("--fix", help="指定修复的issue ID")
    parser.add_argument("--list", action="store_true", help="列出所有可修复项")
    parser.add_argument("--can-fix", help="检查指定issue是否可以自动修复")
    parser.add_argument("--dry-run", action="store_true", default=True, 
                        help="Dry-run模式（不实际执行）")
    parser.add_argument("--execute", action="store_true", 
                        help="实际执行修复（默认只显示）")
    parser.add_argument("--verbose", "-v", action="store_true", help="详细输出")
    
    args = parser.parse_args()
    
    fixer = AgentAutoFixer(dry_run=not args.execute, verbose=args.verbose)
    
    if args.list:
        print(json.dumps({
            "code": 0,
            "message": "success",
            "data": fixer.list_all_fixes()
        }, indent=2, ensure_ascii=False))
        return
    
    if args.can_fix:
        result = fixer.can_auto_fix(args.can_fix)
        print(json.dumps({
            "code": 0,
            "message": "success",
            "data": {
                "issue_id": args.can_fix,
                "can_auto_fix": result
            }
        }, indent=2, ensure_ascii=False))
        return
    
    if args.fix:
        result = fixer.execute_fix(args.fix)
        print(json.dumps({
            "code": 0,
            "message": "success",
            "data": result
        }, indent=2, ensure_ascii=False))
        return
    
    if args.check_json:
        try:
            check_result = json.loads(args.check_json)
            results = fixer.fix_from_check_result(check_result)
            print(json.dumps({
                "code": 0,
                "message": "success",
                "data": {
                    "total_findings": len(check_result.get("findings", [])),
                    "auto_fixed": len(results),
                    "results": results
                }
            }, indent=2, ensure_ascii=False))
        except json.JSONDecodeError as e:
            print(json.dumps({
                "code": 1,
                "message": f"JSON parse error: {e}",
            }))
            return
    
    if not any([args.list, args.can_fix, args.fix, args.check_json]):
        parser.print_help()

if __name__ == "__main__":
    main()
