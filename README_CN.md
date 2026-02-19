# OpenClaw Backup Toolkit

```
openclaw-backup-toolkit/
├── install.sh              # 安装脚本（自动检测和配置）
├── README.md               # 使用说明文档
├── LICENSE                 # MIT 许可证
├── CHANGELOG.md            # 更新日志
├── Makefile                # 简单的 make 命令
├── config.example.conf     # 配置文件示例
├── .gitignore             # Git 忽略文件
├── scripts/               # 核心脚本目录
│   ├── backup.sh          # 手工备份脚本
│   ├── restore.sh         # 一键还原脚本
│   └── start.sh           # 启动诊断脚本
└── docs/                  # （可选）详细文档目录
```

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/yourusername/openclaw-backup-toolkit.git
cd openclaw-backup-toolkit
```

### 2. 运行安装

```bash
./install.sh
```

安装脚本会：
- 自动检测 OpenClaw 安装路径
- 生成 `~/.openclaw-backup.conf` 配置文件
- 安装脚本到 `~/.local/bin/`

### 3. 使用工具

```bash
# 备份
oc-backup.sh "修改前"

# 还原
oc-restore.sh

# 启动
oc-start.sh
```

## 配置

安装后配置文件位于 `~/.openclaw-backup.conf`：

```bash
OPENCLAW_CONFIG="$HOME/.openclaw"
OPENCLAW_WORKSPACE="$HOME/clawd"
OPENCLAW_CLI="openclaw"
BACKUP_DIR="$HOME/clawd/backups"
BACKUP_RETENTION_DAYS=7
```

## 特性

- ✅ 自动检测 OpenClaw 安装位置
- ✅ 支持任意安装路径
- ✅ 全面备份（workspace + config）
- ✅ 一键还原（交互式 + 自动匹配）
- ✅ 启动诊断（全面检查）
- ✅ 定时备份（可选）
- ✅ 跨平台兼容

## 兼容性

- macOS (Intel/Apple Silicon)
- Linux (x86_64/ARM64)
- 任意 OpenClaw 安装方式

## 开发

```bash
# 测试脚本语法
make test

# 安装到自定义目录
make install PREFIX=/usr/local

# 卸载
make uninstall
```

## 贡献

欢迎提交 PR 和 Issue！

## 许可证

MIT License
