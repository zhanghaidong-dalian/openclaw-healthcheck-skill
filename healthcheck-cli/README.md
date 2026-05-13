# HealthCheck CLI Tool

OpenClaw 主机安全加固工具 - 命令行版本

## 功能特性

✅ 完整的命令行参数支持
✅ 多种检查模式
✅ 可视化报告输出
✅ 自动修复功能
✅ 多格式导出

## 安装

```bash
chmod +x healthcheck.py
sudo ln -s $(pwd)/healthcheck.py /usr/local/bin/healthcheck
```

## 使用示例

```bash
# 快速检查
healthcheck --mode quick

# 深度检查
healthcheck --mode deep

# 自动修复高危问题
healthcheck --fix-auto --severity critical

# 导出JSON报告
healthcheck --mode deep --format json
```

## 开发状态

- [ ] 命令行参数解析
- [ ] 检查模块实现
- [ ] 报告生成
- [ ] 修复功能
- [ ] 测试
- [ ] 文档
