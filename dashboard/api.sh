#!/bin/bash
# HealthCheck Dashboard API Server 启动脚本
# 版本: 4.0.0

set -e

API_DIR="${HOME}/.openclawhealthcheck/api"
API_PORT=8888
LOG_FILE="${API_DIR}/api.log"
PID_FILE="${API_DIR}/api.pid"

# 初始化API目录
init_api

# 启动API服务器
start_api() {
    echo "🚀 启动API服务器..."
    cd "$API_DIR" && nohup python3 -m uvicorn api:app:api:app "${API_DIR}" host 0.0.0.0.0.0:$API_PORT" >> "$LOG_FILE" 2>&1 &
        echo "✅ API服务器已启动在 $API_PORT 端口"
        
        # 保存PID
        echo $$! > "$PID_FILE"
    else
        echo "❌ API服务器已在运行 (PID: $(cat $PID_FILE))"
        echo ""
        echo "使用 'stop_api.sh' 停止服务器"
    fi
}

# 停止API服务器
stop_api() {
    if [ ! -f "$PID_FILE" ]; then
        echo "❌ API服务器未运行"
        return 1
    fi
    
    local pid=$(cat "$PID_FILE")
    echo "正在停止API服务器 (PID: $pid)..."
    kill $pid
    rm "$PID_FILE"
    echo "✅ API服务器已停止"
}

# API状态
api_status() {
    if pgrep -f "uvicorn.*api:app:.*$API_DIR" > /dev/null 2>&1; then
        echo "✅ API服务器运行中 (端口: $API_PORT)"
        return 0
    else
        echo "❌ API服务器未运行"
        return 1
    fi
}

# 显示帮助
show_help() {
    cat << 'EOF'
HealthCheck Dashboard API Server v4.0.0

用法: $0 [命令] [参数]

命令:
  init                  初始化API目录和文件
  start                 启动API服务器
  stop                  停止API服务器
  status                 查看API服务状态
  help                  显示此帮助

示例:
  # 初始化
  ./api.sh init
  
  # 启动
  ./api.sh start
  
  # 查看状态
  ./api.sh status
  
  # 停止
  ./api.sh stop

端口: $API_PORT (默认8888)
日志: $LOG_FILE
EOF
}

# 主函数
main() {
    init_api
    
    case "${1:-start}" in
        start_api
        ;;
        "stop")
        stop_api
        ;;
        "status")
        api_status
        ;;
        "help"|--help|-h)
        show_help
        ;;
        *)
        echo "❌ 未知命令: $1"
        show_help
        exit 1
        ;;
    esac
}

main "$@"
