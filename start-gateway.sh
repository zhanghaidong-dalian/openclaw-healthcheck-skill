#!/bin/bash
# OpenClaw Gateway 启动脚本 - 用于预览服务和手动启动
# 使用绝对路径确保在任何环境下都能工作

export HOME="/root"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export NODE_ENV="production"

cd /workspace/projects

exec /usr/bin/openclaw gateway run --port=5000 --force "$@"
