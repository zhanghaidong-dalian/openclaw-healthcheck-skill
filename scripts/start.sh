#!/bin/bash
# OpenClaw Gateway 启动脚本（预览服务调用）
set -e
export HOME="/root"
export PATH="/root/.local/share/pnpm:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
cd /workspace/projects
exec /usr/bin/openclaw gateway run --port=5000 --force "$@"
