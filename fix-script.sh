#!/bin/bash
# OpenClaw 自动修复脚本
# 生成时间: 2026-05-13T19:44:05.634875
# 警告: 请在执行前仔细检查脚本内容！

# 问题: 允许 root 用户 SSH 登录
# 级别: auto-risk
# sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# 问题: 允许密码认证
# 级别: auto-risk
# sudo sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

