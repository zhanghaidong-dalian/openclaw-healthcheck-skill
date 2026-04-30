#!/bin/bash
# ci-cd-integration.sh - CI/CD 集成示例
# 适用场景: GitHub Actions, GitLab CI, Jenkins
# 使用方法: 参考下方示例配置

set -e

echo "================================================"
echo "🔄 CI/CD 安全扫描集成示例"
echo "================================================"
echo ""

# 配置
SCAN_MODE="${1:-quick}"  # 支持: quick, deep, intelligent
OUTPUT_FILE="${2:-/tmp/security-report.json}"

echo "📊 配置信息:"
echo "  扫描模式: $SCAN_MODE"
echo "  输出文件: $OUTPUT_FILE"
echo ""

# 执行扫描
echo "🔍 开始安全扫描..."
./bin/healthcheck --$SCAN_MODE --output json "$OUTPUT_FILE"

# 检查结果
echo ""
echo "📋 扫描结果摘要:"
if [ -f "$OUTPUT_FILE" ]; then
    # 使用 grep 解析 JSON（无 jq 依赖）
    PASSED=$(grep -o '"passed":[0-9]*' "$OUTPUT_FILE" | cut -d: -f2 || echo "0")
    WARNING=$(grep -o '"warning":[0-9]*' "$OUTPUT_FILE" | cut -d: -f2 || echo "0")
    FAILED=$(grep -o '"failed":[0-9]*' "$OUTPUT_FILE" | cut -d: -f2 || echo "0")
    
    echo "  ✅ 通过: $PASSED"
    echo "  ⚠️ 警告: $WARNING"
    echo "  ❌ 失败: $FAILED"
    
    # 如果有失败项，退出码非零
    if [ "$FAILED" -gt "0" ]; then
        echo ""
        echo "❌ 检测到安全风险，CI/CD 构建应该失败"
        exit 1
    fi
fi

echo ""
echo "✅ 安全扫描完成"
echo "📁 完整报告: $OUTPUT_FILE"

# ========================================
# CI/CD 集成示例
# ========================================

# GitHub Actions 示例:
cat << 'GITHUB'
# .github/workflows/security.yml
name: Security Scan

on:
  push:
    branches: [main]
  schedule:
    - cron: '0 2 * * *'

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Security Scan
        run: |
          chmod +x bin/healthcheck
          ./bin/healthcheck --quick --output json report.json
      
      - name: Upload Report
        uses: actions/upload-artifact@v3
        with:
          name: security-report
          path: report.json
GITHUB

echo ""
echo "📋 复制上方配置到 .github/workflows/security.yml"
echo ""

# GitLab CI 示例:
cat << 'GITLAB'
# .gitlab-ci.yml
security_scan:
  image: ubuntu:latest
  script:
    - apt-get update && apt-get install -y git
    - git clone https://github.com/zhanghaidong-dalian/openclaw-healthcheck-skill.git
    - cd openclaw-healthcheck-skill
    - chmod +x bin/healthcheck
    - ./bin/healthcheck --quick --output json report.json
  artifacts:
    paths:
      - report.json
    expire_in: 1 week
  only:
    - main
GITLAB

echo "📋 复制上方配置到 .gitlab-ci.yml"
echo ""

# Jenkins Pipeline 示例:
cat << 'JENKINS'
// Jenkinsfile
pipeline {
    agent any
    
    stages {
        stage('Security Scan') {
            steps {
                sh '''
                    chmod +x bin/healthcheck
                    ./bin/healthcheck --quick --output json report.json
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'report.json'
                }
            }
        }
    }
}
JENKINS

echo "📋 复制上方配置到 Jenkinsfile"
echo ""
echo "================================================"
