#!/bin/bash
# OpenClaw Gateway 停止脚本
fuser -k 5000/tcp 2>/dev/null || true
echo "[stop] Gateway stopped"
