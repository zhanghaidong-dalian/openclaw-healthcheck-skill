#!/usr/bin/env python3
"""
Agent Mode Security Scanner
Pure Python implementation for restricted platforms
"""

import os
import re
import json
import subprocess
from datetime import datetime
from typing import Dict, List, Tuple, Optional


class SecurityScanner:
    """
    Security Scanner - Agent Mode
    Compatible with platforms that don't support shell execution
    """
    
    def __init__(self, rules_dir: str = "../rules"):
        self.rules_dir = rules_dir
        self.findings = []
        self.timestamp = datetime.now().isoformat()
        
    def load_rules(self) -> List[Dict]:
        """Load all YAML rules from rules directory"""
        try:
            import yaml
        except ImportError:
            # Fallback to simple YAML parser
            print("Warning: PyYAML not installed, using simple parser")
            return self._load_rules_simple()
        
        rules = []
        if not os.path.exists(self.rules_dir):
            print(f"Rules directory not found: {self.rules_dir}")
            return rules
        
        for filename in os.listdir(self.rules_dir):
            if filename.endswith('.yaml'):
                with open(os.path.join(self.rules_dir, filename)) as f:
                    try:
                        rules.append(yaml.safe_load(f))
                    except Exception as e:
                        print(f"Error loading {filename}: {e}")
        
        return rules
    
    def _load_rules_simple(self) -> List[Dict]:
        """Simple YAML fallback parser"""
        rules = []
        # For now, return empty list - full implementation needed
        return rules
    
    def run_check(self, check_command: str) -> Tuple[int, str, str]:
        """
        Run a security check
        Returns: (exit_code, stdout, stderr)
        """
        try:
            result = subprocess.run(
                check_command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=30
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return -1, "", "Command timed out"
        except Exception as e:
            return -1, "", str(e)
    
    def check_version(self, version_output: str, pattern: str) -> bool:
        """
        Check if version matches vulnerable pattern
        """
        if not version_output:
            return False
        return bool(re.search(pattern, version_output))
    
    def scan_port(self, port: int) -> bool:
        """
        Check if a port is listening (Agent mode - limited)
        """
        try:
            result = subprocess.run(
                f'echo > /dev/tcp/127.0.0.1/{port}',
                shell=True,
                timeout=2
            )
            return result.returncode == 0
        except Exception:
            return False
    
    def detect_os(self) -> str:
        """
        Detect the operating system
        """
        if os.path.exists('/etc/os-release'):
            with open('/etc/os-release') as f:
                content = f.read()
                if 'ubuntu' in content.lower():
                    return 'ubuntu'
                elif 'debian' in content.lower():
                    return 'debian'
                elif 'fedora' in content.lower():
                    return 'fedora'
                elif 'centos' in content.lower():
                    return 'centos'
        return 'unknown'
    
    def generate_report(self, format: str = 'json') -> str:
        """
        Generate security report
        format: 'json' or 'markdown'
        """
        if format == 'json':
            return json.dumps({
                'timestamp': self.timestamp,
                'findings': self.findings,
                'summary': self._generate_summary()
            }, indent=2)
        elif format == 'markdown':
            return self._generate_markdown_report()
        else:
            return "Unsupported format"
    
    def _generate_summary(self) -> Dict:
        """Generate summary statistics"""
        critical = len([f for f in self.findings if f.get('severity') == 'critical'])
        high = len([f for f in self.findings if f.get('severity') == 'high'])
        medium = len([f for f in self.findings if f.get('severity') == 'medium'])
        low = len([f for f in self.findings if f.get('severity') == 'low'])
        
        return {
            'total': len(self.findings),
            'critical': critical,
            'high': high,
            'medium': medium,
            'low': low
        }
    
    def _generate_markdown_report(self) -> str:
        """Generate Markdown report"""
        report = f"""# Security Scan Report

**Timestamp:** {self.timestamp}
**Scan Type:** Agent Mode (Python-based)

## Summary

| Severity | Count |
|----------|--------|
| Critical | {len([f for f in self.findings if f.get('severity') == 'critical'])} |
| High | {len([f for f in self.findings if f.get('severity') == 'high'])} |
| Medium | {len([f for f in self.findings if f.get('severity') == 'medium'])} |
| Low | {len([f for f in self.findings if f.get('severity') == 'low'])} |

## Findings

"""
        for idx, finding in enumerate(self.findings, 1):
            report += f"""
### {idx}. {finding.get('rule_id', 'Unknown')}
- **Severity:** {finding.get('severity', 'unknown').upper()}
- **Description:** {finding.get('description', 'No description')}
- **Status:** {finding.get('status', 'unknown')}
- **Remediation:** {finding.get('remediation', 'See rule file')}
"""
        
        return report


def main():
    """Main entry point for agent mode"""
    scanner = SecurityScanner()
    
    print("=" * 60)
    print("Security Scanner - Agent Mode")
    print("=" * 60)
    print()
    
    # Load rules
    print("Loading security rules...")
    rules = scanner.load_rules()
    print(f"Loaded {len(rules)} rules")
    print()
    
    # Detect OS
    print("Detecting operating system...")
    os_type = scanner.detect_os()
    print(f"Detected OS: {os_type}")
    print()
    
    # Quick health checks (Agent mode - limited)
    print("Running health checks...")
    
    # Check for common ports
    common_ports = [22, 80, 443, 3000]
    for port in common_ports:
        listening = scanner.scan_port(port)
        status = "OPEN" if listening else "CLOSED"
        scanner.findings.append({
            'rule_id': f'port-{port}',
            'severity': 'info',
            'description': f'Port {port} status',
            'status': status,
            'remediation': 'Review if this port should be open'
        })
        print(f"  Port {port}: {status}")
    
    print()
    print("Generating report...")
    print()
    
    # Output report
    report = scanner.generate_report(format='markdown')
    print(report)
    
    # Save to file
    output_file = f"/tmp/security-report-{datetime.now().strftime('%Y%m%d-%H%M%S')}.md"
    with open(output_file, 'w') as f:
        f.write(report)
    print(f"Report saved to: {output_file}")


if __name__ == '__main__':
    main()