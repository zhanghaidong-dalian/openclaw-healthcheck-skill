#!/bin/bash
# Agent Mode Quick Start - For restricted platforms
# Use this when you cannot execute shell scripts

echo "==================================================="
echo "HealthCheck Agent Mode - Quick Start"
echo "==================================================="
echo ""
echo "This mode uses Python-based tools (no shell execution)"
echo ""
echo "Choose what you want to do:"
echo "1. Run basic security scan"
echo "2. Parse security rules"
echo "3. Generate sample report"
echo ""
read -p "Enter choice (1-3): " choice

case $choice in
    1)
        echo "Running security scan..."
        python3 agent/scanner.py
        ;;
    2)
        echo "Parsing security rules..."
        python3 agent/rule_parser.py
        ;;
    3)
        echo "Generating sample report..."
        python3 agent/report_gen.py
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac