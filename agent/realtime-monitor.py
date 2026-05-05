#========================================
# 实时威胁监控系统
# 版本: v5.0.0
#========================================

import os
import sys
import json
import time
import logging
import hashlib
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
from enum import Enum

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class ThreatLevel(Enum):
    """威胁级别"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class AlertType(Enum):
    """告警类型"""
    CONFIG_CHANGED = "config_changed"
    PERMISSION_CHANGED = "permission_changed"
    NEW_PORT_OPEN = "new_port_open"
    SUSPICIOUS_ACCESS = "suspicious_access"
    FILE_MODIFIED = "file_modified"
    SERVICE_DOWN = "service_down"


@dataclass
class ThreatAlert:
    """威胁告警"""
    timestamp: str
    alert_type: str
    level: str
    title: str
    description: str
    details: Dict
    action_required: bool
    
    def to_dict(self) -> Dict:
        return asdict(self)
    
    def to_json(self) -> str:
        return json.dumps(self.to_dict(), ensure_ascii=False)


class ConfigMonitor:
    """配置文件监控"""
    
    def __init__(self, config_paths: List[str]):
        self.config_paths = config_paths
        self.snapshots: Dict[str, str] = {}
        
    def take_snapshot(self) -> None:
        """拍摄配置快照"""
        for path in self.config_paths:
            if os.path.exists(path):
                try:
                    with open(path, 'r') as f:
                        content = f.read()
                    self.snapshots[path] = hashlib.sha256(content.encode()).hexdigest()
                    logger.info(f"快照已保存: {path}")
                except Exception as e:
                    logger.error(f"无法读取配置文件 {path}: {e}")
                    
    def check_changes(self) -> List[ThreatAlert]:
        """检查配置变更"""
        alerts = []
        
        for path in self.config_paths:
            if not os.path.exists(path):
                continue
                
            try:
                with open(path, 'r') as f:
                    content = f.read()
                current_hash = hashlib.sha256(content.encode()).hexdigest()
                
                if path in self.snapshots:
                    if current_hash != self.snapshots[path]:
                        alerts.append(ThreatAlert(
                            timestamp=datetime.now().isoformat(),
                            alert_type=AlertType.CONFIG_CHANGED.value,
                            level=ThreatLevel.HIGH.value,
                            title=f"配置变更检测: {os.path.basename(path)}",
                            description=f"配置文件 {path} 发生了变更",
                            details={
                                'path': path,
                                'old_hash': self.snapshots[path],
                                'new_hash': current_hash
                            },
                            action_required=True
                        ))
                        logger.warning(f"配置变更: {path}")
                else:
                    # 首次运行，保存初始快照
                    self.snapshots[path] = current_hash
                    
            except Exception as e:
                logger.error(f"检查配置变更失败 {path}: {e}")
                
        return alerts


class PermissionMonitor:
    """权限监控"""
    
    def __init__(self, paths_to_monitor: List[str]):
        self.paths_to_monitor = paths_to_monitor
        self.baseline: Dict[str, str] = {}
        
    def set_baseline(self) -> None:
        """设置权限基线"""
        for path in self.paths_to_monitor:
            if os.path.exists(path):
                try:
                    mode = os.stat(path).st_mode & 0o777
                    self.baseline[path] = oct(mode)
                    logger.info(f"权限基线已设置: {path} -> {oct(mode)}")
                except Exception as e:
                    logger.error(f"无法获取权限 {path}: {e}")
                    
    def check_permissions(self) -> List[ThreatAlert]:
        """检查权限变更"""
        alerts = []
        
        for path in self.paths_to_monitor:
            if not os.path.exists(path):
                continue
                
            try:
                current_mode = os.stat(path).st_mode & 0o777
                current_mode_str = oct(current_mode)
                
                if path in self.baseline:
                    if current_mode_str != self.baseline[path]:
                        alerts.append(ThreatAlert(
                            timestamp=datetime.now().isoformat(),
                            alert_type=AlertType.PERMISSION_CHANGED.value,
                            level=ThreatLevel.MEDIUM.value,
                            title=f"权限变更: {os.path.basename(path)}",
                            description=f"{path} 权限从 {self.baseline[path]} 变为 {current_mode_str}",
                            details={
                                'path': path,
                                'old_mode': self.baseline[path],
                                'new_mode': current_mode_str
                            },
                            action_required=True
                        ))
                        logger.warning(f"权限变更: {path}")
                else:
                    self.baseline[path] = current_mode_str
                    
            except Exception as e:
                logger.error(f"检查权限失败 {path}: {e}")
                
        return alerts


class ProcessMonitor:
    """进程监控"""
    
    def __init__(self):
        self.baseline_processes: set = set()
        
    def set_baseline(self) -> None:
        """设置进程基线"""
        try:
            for pid in os.listdir('/proc'):
                if pid.isdigit():
                    try:
                        with open(f'/proc/{pid}/cmdline', 'r') as f:
                            cmdline = f.read().replace('\x00', ' ').strip()
                            if cmdline:
                                self.baseline_processes.add(cmdline[:100])
                    except:
                        pass
            logger.info(f"进程基线已设置: {len(self.baseline_processes)} 个进程")
        except Exception as e:
            logger.error(f"无法设置进程基线: {e}")
            
    def check_processes(self) -> List[ThreatAlert]:
        """检查异常进程"""
        alerts = []
        
        try:
            current_processes = set()
            for pid in os.listdir('/proc'):
                if pid.isdigit():
                    try:
                        with open(f'/proc/{pid}/cmdline', 'r') as f:
                            cmdline = f.read().replace('\x00', ' ').strip()
                            if cmdline:
                                current_processes.add(cmdline[:100])
                    except:
                        pass
            
            # 检查新增进程
            new_processes = current_processes - self.baseline_processes
            
            # 检查可疑进程关键字
            suspicious_keywords = [
                'nc -l', 'nc -e', '/bin/sh -i',
                'wget', 'curl -o', 'python.*shell',
                'mkfifo', '/dev/tcp'
            ]
            
            for proc in new_processes:
                for keyword in suspicious_keywords:
                    if keyword in proc:
                        alerts.append(ThreatAlert(
                            timestamp=datetime.now().isoformat(),
                            alert_type=AlertType.SUSPICIOUS_ACCESS.value,
                            level=ThreatLevel.CRITICAL.value,
                            title="可疑进程检测",
                            description=f"检测到可疑命令: {proc[:80]}",
                            details={'process': proc},
                            action_required=True
                        ))
                        
        except Exception as e:
            logger.error(f"检查进程失败: {e}")
            
        return alerts


class RealtimeMonitor:
    """实时监控系统"""
    
    def __init__(self, interval: int = 60):
        """
        初始化监控器
        
        Args:
            interval: 检查间隔（秒）
        """
        self.interval = interval
        self.config_monitor = ConfigMonitor([
            os.path.expanduser('~/.openclaw/gateway.yml'),
            os.path.expanduser('~/.openclaw/config.yml'),
        ])
        self.permission_monitor = PermissionMonitor([
            os.path.expanduser('~/.openclaw'),
            os.path.expanduser('~/.openclaw/gateway.yml'),
        ])
        self.process_monitor = ProcessMonitor()
        self.alerts: List[ThreatAlert] = []
        self.running = False
        
    def initialize(self) -> None:
        """初始化监控"""
        logger.info("初始化实时监控系统...")
        
        # 设置基线
        self.config_monitor.take_snapshot()
        self.permission_monitor.set_baseline()
        self.process_monitor.set_baseline()
        
        logger.info("监控系统初始化完成")
        
    def check_once(self) -> List[ThreatAlert]:
        """执行一次检查"""
        all_alerts = []
        
        # 配置变更检查
        config_alerts = self.config_monitor.check_changes()
        all_alerts.extend(config_alerts)
        
        # 权限变更检查
        perm_alerts = self.permission_monitor.check_permissions()
        all_alerts.extend(perm_alerts)
        
        # 进程检查
        process_alerts = self.process_monitor.check_processes()
        all_alerts.extend(process_alerts)
        
        return all_alerts
    
    def start(self, duration: Optional[int] = None) -> None:
        """
        启动监控
        
        Args:
            duration: 监控时长（秒），None表示无限
        """
        self.initialize()
        self.running = True
        
        start_time = time.time()
        check_count = 0
        
        logger.info(f"开始实时监控 (间隔: {self.interval}秒)")
        
        while self.running:
            check_count += 1
            logger.info(f"执行第 {check_count} 次检查...")
            
            alerts = self.check_once()
            
            if alerts:
                for alert in alerts:
                    self.alerts.append(alert)
                    logger.warning(f"告警: {alert.title}")
                    
            # 检查是否超时
            if duration and (time.time() - start_time) >= duration:
                break
                
            # 等待下次检查
            time.sleep(self.interval)
            
        logger.info(f"监控结束，共执行 {check_count} 次检查")
        
    def stop(self) -> None:
        """停止监控"""
        self.running = False
        logger.info("监控已停止")
        
    def get_alerts(self, level: Optional[str] = None) -> List[Dict]:
        """获取告警列表"""
        alerts = self.alerts
        
        if level:
            alerts = [a for a in alerts if a.level == level]
            
        return [a.to_dict() for a in alerts]
    
    def export_report(self, output_file: str) -> None:
        """导出报告"""
        report = {
            'timestamp': datetime.now().isoformat(),
            'total_alerts': len(self.alerts),
            'by_level': {
                'critical': len([a for a in self.alerts if a.level == ThreatLevel.CRITICAL.value]),
                'high': len([a for a in self.alerts if a.level == ThreatLevel.HIGH.value]),
                'medium': len([a for a in self.alerts if a.level == ThreatLevel.MEDIUM.value]),
                'low': len([a for a in self.alerts if a.level == ThreatLevel.LOW.value]),
            },
            'alerts': [a.to_dict() for a in self.alerts]
        }
        
        with open(output_file, 'w') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
            
        logger.info(f"报告已导出: {output_file}")


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='OpenClaw 实时威胁监控')
    parser.add_argument('--interval', type=int, default=60, help='检查间隔（秒）')
    parser.add_argument('--duration', type=int, help='监控时长（秒）')
    parser.add_argument('--once', action='store_true', help='执行一次检查')
    parser.add_argument('--export', type=str, help='导出报告文件')
    
    args = parser.parse_args()
    
    monitor = RealtimeMonitor(interval=args.interval)
    
    if args.once:
        # 单次检查
        monitor.initialize()
        alerts = monitor.check_once()
        
        print(f"\n{'='*50}")
        print(f"🔍 检查完成，发现 {len(alerts)} 个告警")
        print(f"{'='*50}\n")
        
        for alert in alerts:
            print(f"[{alert.level.upper()}] {alert.title}")
            print(f"  {alert.description}\n")
            
    else:
        # 持续监控
        try:
            monitor.start(duration=args.duration)
        except KeyboardInterrupt:
            print("\n正在停止监控...")
            monitor.stop()
            
    if args.export:
        monitor.export_report(args.export)


if __name__ == '__main__':
    main()
