#!/usr/bin/env python3
"""
Rule Parser for Agent Mode
Parses YAML security rules and extracts check commands
"""

import os
import re
import json
from typing import Dict, List, Optional


class RuleParser:
    """
    Parse security rules from YAML files
    """
    
    def __init__(self, rules_dir: str = None):
        if rules_dir is None:
            # 默认规则目录：从当前脚本位置推断
            script_dir = os.path.dirname(os.path.abspath(__file__))
            self.rules_dir = os.path.join(script_dir, '..', 'rules')
        else:
            self.rules_dir = rules_dir
        self.rules = []
    
    def parse_all_rules(self) -> List[Dict]:
        """
        Parse all YAML files in rules directory
        """
        if not os.path.exists(self.rules_dir):
            print(f"Warning: Rules directory not found: {self.rules_dir}")
            return []
        
        for filename in os.listdir(self.rules_dir):
            if filename.endswith('.yaml'):
                rule = self._parse_yaml_file(
                    os.path.join(self.rules_dir, filename)
                )
                if rule:
                    self.rules.append(rule)
        
        print(f"Parsed {len(self.rules)} rules from {self.rules_dir}")
        return self.rules
    
    def _parse_yaml_file(self, filepath: str) -> Optional[Dict]:
        """
        Parse a single YAML file
        For now, use simple regex-based parsing
        Full YAML parser requires PyYAML
        """
        try:
            with open(filepath, 'r') as f:
                content = f.read()
            
            # Extract basic fields using regex
            rule = {
                'filename': os.path.basename(filepath),
                'rule_id': self._extract_field(content, 'rule_id: ([^\n]+)'),
                'category': self._extract_field(content, 'category: ([^\n]+)'),
                'severity': self._extract_field(content, 'severity: ([^\n]+)'),
                'description': self._extract_field(content, 'description: "([^"]+)"'),
                'check_command': self._extract_field(content, 'check_command: "([^"]+)"'),
                'check_pattern': self._extract_field(content, 'check_pattern: "([^"]+)"'),
            }
            
            return rule
            
        except Exception as e:
            print(f"Error parsing {filepath}: {e}")
            return None
    
    def _extract_field(self, content: str, pattern: str) -> str:
        """
        Extract a field using regex pattern
        """
        match = re.search(pattern, content)
        if match:
            return match.group(1).strip()
        return ''
    
    def get_rules_by_severity(self, severity: str) -> List[Dict]:
        """
        Filter rules by severity
        """
        return [r for r in self.rules if r['severity'] == severity]
    
    def get_rules_by_category(self, category: str) -> List[Dict]:
        """
        Filter rules by category
        """
        return [r for r in self.rules if r['category'] == category]
    
    def export_to_json(self, output_path: str):
        """
        Export parsed rules to JSON
        """
        with open(output_path, 'w') as f:
            json.dump(self.rules, f, indent=2)
        print(f"Exported {len(self.rules)} rules to {output_path}")
    
    def get_check_commands(self) -> List[Dict]:
        """
        Extract all check commands from rules
        """
        commands = []
        for rule in self.rules:
            if rule.get('check_command'):
                commands.append({
                    'rule_id': rule.get('rule_id'),
                    'command': rule['check_command'],
                    'pattern': rule.get('check_pattern', ''),
                    'severity': rule.get('severity')
                })
        return commands


def main():
    """Test rule parser"""
    # 使用绝对路径
    parser = RuleParser()
    rules = parser.parse_all_rules()
    
    print("\n=== Sample Rules ===")
    for rule in rules[:5]:
        print(f"\nRule: {rule.get('rule_id')}")
        print(f"  Severity: {rule.get('severity')}")
        print(f"  Command: {rule.get('check_command')}")
    
    # Export to JSON
    parser.export_to_json('/tmp/parsed-rules.json')


if __name__ == '__main__':
    main()