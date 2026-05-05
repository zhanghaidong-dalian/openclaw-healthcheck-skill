#!/bin/bash
#========================================
# 一键安全检查脚本 (无需Root权限)
# 版本: v5.0.0
#========================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查OpenClaw是否安装
check_openclaw() {
    echo -e "${BLUE}[1/5] 检查OpenClaw安装状态...${NC}"
    
    if command -v openclaw &> /dev/null; then
        VERSION=$(openclaw --version 2>/dev/null || echo "未知")
        echo -e "${GREEN}✅ OpenClaw已安装${NC} (版本: $VERSION)"
        return 0
    else
        echo -e "${YELLOW}⚠️ OpenClaw未安装或不在PATH中${NC}"
        echo -e "${YELLOW}   提示: 请确保OpenClaw已正确安装${NC}"
        return 1
    fi
}

# 检查Gateway状态
check_gateway() {
    echo -e "${BLUE}[2/5] 检查Gateway运行状态...${NC}"
    
    # 检查进程
    if pgrep -f "openclaw" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Gateway进程正在运行${NC}"
    else
        echo -e "${YELLOW}⚠️ Gateway进程未运行${NC}"
        echo -e "${YELLOW}   提示: 运行 'openclaw gateway start' 启动${NC}"
    fi
    
    # 检查端口
    if command -v ss &> /dev/null; then
        if ss -ltn 2>/dev/null | grep -q ":18888\|:8080"; then
            echo -e "${GREEN}✅ Gateway端口可访问${NC}"
        else
            echo -e "${YELLOW}⚠️ Gateway端口未检测到监听${NC}"
        fi
    fi
}

# 基础安全检查
basic_security_check() {
    echo -e "${BLUE}[3/5] 执行基础安全检查...${NC}"
    
    local ISSUES=0
    
    # 检查OpenClaw配置目录权限
    if [ -d "$HOME/.openclaw" ]; then
        PERMS=$(stat -c "%a" "$HOME/.openclaw" 2>/dev/null || stat -f "%Lp" "$HOME/.openclaw" 2>/dev/null)
        if [ "$PERMS" = "700" ] || [ "$PERMS" = "600" ]; then
            echo -e "${GREEN}✅ 配置目录权限正常 ($PERMS)${NC}"
        else
            echo -e "${YELLOW}⚠️ 配置目录权限过宽: $PERMS (建议: 700)${NC}"
            ((ISSUES++))
        fi
    else
        echo -e "${YELLOW}⚠️ 配置目录不存在${NC}"
    fi
    
    # 检查配置文件权限
    if [ -f "$HOME/.openclaw/gateway.yml" ]; then
        PERMS=$(stat -c "%a" "$HOME/.openclaw/gateway.yml" 2>/dev/null || stat -f "%Lp" "$HOME/.openclaw/gateway.yml" 2>/dev/null)
        if [ "$PERMS" = "600" ]; then
            echo -e "${GREEN}✅ 配置文件权限正常 ($PERMS)${NC}"
        else
            echo -e "${YELLOW}⚠️ 配置文件权限过宽: $PERMS (建议: 600)${NC}"
            ((ISSUES++))
        fi
    fi
    
    # 检查日志目录
    if [ -d "$HOME/.openclaw/logs" ]; then
        echo -e "${GREEN}✅ 日志目录存在${NC}"
    else
        echo -e "${YELLOW}⚠️ 日志目录不存在${NC}"
    fi
    
    return $ISSUES
}

# OpenClaw安全审计
run_security_audit() {
    echo -e "${BLUE}[4/5] 运行OpenClaw安全审计...${NC}"
    
    if command -v openclaw &> /dev/null; then
        echo -e "${YELLOW}执行 'openclaw security audit'...${NC}"
        echo ""
        
        # 运行审计（只读模式）
        if openclaw security audit 2>&1; then
            echo ""
            echo -e "${GREEN}✅ 安全审计完成${NC}"
        else
            echo ""
            echo -e "${YELLOW}⚠️ 安全审计发现问题，请查看上方输出${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ OpenClaw未安装，跳过安全审计${NC}"
    fi
}

# 版本检查
check_updates() {
    echo -e "${BLUE}[5/5] 检查更新...${NC}"
    
    if command -v openclaw &> /dev/null; then
        echo -e "${YELLOW}检查OpenClaw更新...${NC}"
        openclaw update status 2>&1 || true
    fi
}

# 生成报告
generate_report() {
    echo ""
    echo "========================================"
    echo -e "${BLUE}📊 一键检查报告${NC}"
    echo "========================================"
    echo ""
    echo "检查时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # 安全评分（基于检查结果）
    SCORE=100
    
    # 扣分项
    if [ ! -d "$HOME/.openclaw" ]; then
        ((SCORE-=20))
    fi
    
    if [ -f "$HOME/.openclaw/gateway.yml" ]; then
        PERMS=$(stat -c "%a" "$HOME/.openclaw/gateway.yml" 2>/dev/null || echo "600")
        if [ "$PERMS" != "600" ]; then
            ((SCORE-=10))
        fi
    fi
    
    echo -e "安全评分: ${SCORE}/100"
    
    if [ $SCORE -ge 90 ]; then
        echo -e "${GREEN}🟢 状态: 安全${NC}"
    elif [ $SCORE -ge 70 ]; then
        echo -e "${YELLOW}🟡 状态: 需注意${NC}"
    else
        echo -e "${RED}🔴 状态: 需修复${NC}"
    fi
    
    echo ""
    echo "========================================"
    echo -e "${BLUE}💡 建议操作${NC}"
    echo "========================================"
    echo ""
    echo "1. 运行完整安全审计: openclaw security audit --deep"
    echo "2. 启用自动修复: openclaw security audit --fix"
    echo "3. 设置定时检查: openclaw cron add ..."
    echo ""
    echo "如需帮助，请查看 FAQ 或联系支持。"
    echo ""
}

# 主函数
main() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   🔒 OpenClaw 一键安全检查 v5.0.0    ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo -e "${YELLOW}无需Root权限，快速检查系统安全状态${NC}"
    echo ""
    
    check_openclaw
    check_gateway
    basic_security_check
    run_security_audit
    check_updates
    generate_report
    
    echo -e "${GREEN}✅ 检查完成！${NC}"
}

# 运行
main "$@"
