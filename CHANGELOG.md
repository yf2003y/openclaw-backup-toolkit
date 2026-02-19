# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.0.0] - 2026-02-18

### Added
- 初始版本发布
- 通用安装脚本 `install.sh`，支持自动检测 OpenClaw 安装
- 手工备份脚本 `backup.sh`，支持多种备份模式
- 一键还原脚本 `restore.sh`，支持交互式选择和自动匹配
- 启动诊断脚本 `start.sh`，全面检查 OpenClaw 状态
- 配置文件支持 `~/.openclaw-backup.conf`
- 环境变量支持 `OPENCLAW_BACKUP_CONFIG`
- 备份保留策略（自动清理旧备份）
- 定时备份集成（OpenClaw cron 或系统 cron）
- 紧急备份机制（还原前自动备份当前状态）
- 跨平台支持（自动适配不同安装路径）

### Features
- 自动检测 OpenClaw 配置目录和 Workspace
- 自动检测 openclaw CLI 位置
- 智能匹配同批次备份文件
- 全面的错误检查和修复建议
- 彩色输出（自动检测终端支持）
- 备份备注功能
- 备份列表查看
- 配置文件 JSON 格式验证

### Security
- 还原前强制创建紧急备份
- 还原操作需要输入 RESTORE 确认
- 敏感配置信息不出现在日志中

## [1.1.0] - 2026-02-19

### Added
- 新增 `restore-simple.sh` 简化版还原工具
  - 无颜色依赖，兼容所有终端环境
  - 按时间点分组显示备份（自动匹配 workspace + config）
  - 交互式编号选择还原点
  - 支持仅还原 Workspace 或仅还原 Config
  - 还原前自动创建紧急备份
  - 安全确认机制（输入 yes 确认）

### Improved
- 优化还原流程，更清晰的菜单导航
- 改进备份列表显示，一目了然查看批次和时间

## [Unreleased]

### Planned
- 增量备份支持
- 远程备份存储（S3、rsync）
- 备份加密功能
- Web UI 管理界面
- 多 workspace 支持
