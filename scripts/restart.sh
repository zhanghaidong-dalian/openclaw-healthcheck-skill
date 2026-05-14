#!/bin/bash
# OpenClaw Gateway 重启脚本
bash "$(dirname "$0")/stop.sh"
sleep 1
bash "$(dirname "$0")/start.sh"
