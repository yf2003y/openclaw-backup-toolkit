# OpenClaw Backup Toolkit

通用备份/还原/启动工具包，适配任意 OpenClaw 安装环境。

## ✨ 功能特性

- 🔧 **自动检测** - 自动检测 OpenClaw 安装位置和配置
- 💾 **全面备份** - 同时备份 workspace 和配置文件
- 🔄 **一键还原** - 交互式或自动还原，支持紧急回滚
- 🚀 **启动诊断** - 启动服务并全面检查问题
- ⏰ **定时备份** - 支持自动定时备份（可选）
- 🔌 **通用适配** - 适配任何 OpenClaw 安装路径和配置

## 📦 包含工具

| 工具 | 说明 |
|------|------|
| `oc-backup.sh` | 手工一键备份 |
| `oc-restore.sh` | 一键还原（完整版） |
| `oc-restore-simple.sh` | 一键还原（简化版，v1.1.1 通用版） |
| `oc-start.sh` | 启动并诊断 |
| `install.sh` | 安装脚本（自动配置） |
| `openclaw-backup-toolkit.skill` | OpenClaw Skill 包（v1.2.0 新增） |

### 🎁 OpenClaw Skill 支持（v1.2.0 新增）

本项目现在可以作为 **OpenClaw Skill** 使用！

**安装方式：**

1. 下载 skill 文件
   ```bash
   # 从 GitHub Releases 下载
   wget https://github.com/yf2003y/openclaw-backup-toolkit/releases/download/v1.2.0/openclaw-backup-toolkit.skill
   ```

2. 安装到 OpenClaw
   ```bash
   # 将 .skill 文件放到 OpenClaw skills 目录
   cp openclaw-backup-toolkit.skill ~/.openclaw/skills/
   # 或放到用户目录
   cp openclaw-backup-toolkit.skill ~/clawd/skills/
   ```

3. 使用
   
   安装后，只需对 OpenClaw 说：
   - "备份 OpenClaw" - 自动执行备份
   - "还原到之前的版本" - 启动交互式还原
   - "查看备份" - 列出所有备份

## 🚀 快速开始

### 1. 安装

```bash
git clone https://github.com/yourusername/openclaw-backup-toolkit.git
cd openclaw-backup-toolkit
./install.sh
```

安装脚本会：
- 自动检测 OpenClaw 安装位置
- 生成配置文件
- 安装脚本到 `~/.local/bin/`
- （可选）设置定时备份

### 2. 使用

```bash
# 手工备份（推荐在重要操作前）
oc-backup.sh "修改配置前"

# 查看备份列表
oc-backup.sh -l

# 一键还原
oc-restore.sh

# 启动并诊断
oc-start.sh
```

## 📖 详细使用说明

### 备份工具

```bash
# 完整备份（workspace + config）
oc-backup.sh

# 带备注的备份
c-backup.sh "更新技能前"

# 快速备份（仅 workspace）
oc-backup.sh -q

# 仅备份配置
oc-backup.sh -c

# 自定义文件名前缀
oc-backup.sh -n pre-deploy "部署前"

# 查看备份列表
oc-backup.sh -l

# 清理旧备份
oc-backup.sh --cleanup
```

### 还原工具

#### 完整版 (`oc-restore.sh`)

```bash
# 启动交互式还原
oc-restore.sh

# 然后按提示选择：
# [1] 交互式选择备份（推荐）
# [2] 自动选择最新备份
# [3] 取消
```

还原流程：
1. 显示所有可用备份
2. 自动匹配同批次的 workspace 和 config
3. 创建当前状态的紧急备份
4. 执行还原
5. 验证关键文件

#### 简化版 (`oc-restore-simple.sh`) - v1.1.1 通用版

通用版本，无颜色依赖，兼容所有终端环境。支持配置文件和环境变量。

##### 快速开始

```bash
# 启动交互式菜单
oc-restore-simple.sh

# 快速查看备份列表
oc-restore-simple.sh -l
```

##### 操作步骤

**1. 启动脚本**
```bash
./scripts/restore-simple.sh
```

**2. 选择操作**
```
══════════════════════════════════════════════════════════
  请选择操作：

  1. 查看所有备份列表（详细）
  2. 按时间点查看备份（推荐） ← 选择此项
  3. 还原到指定时间点        ← 或直接选此项
  4. 仅还原 Workspace
  5. 仅还原 Config
  6. 查看最新备份
  q. 退出
══════════════════════════════════════════════════════════

> 2
```

**3. 查看备份列表并选择**
```
📦 按时间点分组显示备份...

═══════════════════════════════════════════════════════════════════════
  编号 │ 备份时间            │ 批次 │ Workspace │ Config  │ 状态
═══════════════════════════════════════════════════════════════════════
  1    │ 2026-02-19 08:31:39 │ 3    │  72K      │ 484K    │ WC  ← 最新
  2    │ 2026-02-19 04:00:07 │ 2    │  72K      │ 464K    │ WC
  3    │ 2026-02-19 00:00:42 │ 1    │  72K      │  72K    │ WC
═══════════════════════════════════════════════════════════════════════
说明: W=Workspace备份, C=Config备份

请输入要还原的编号（或输入 0 取消）：
> 2
```

**4. 确认还原**
```
⚠️  即将执行还原操作

  Workspace: openclaw-workspace-20260219-batch2-040007.tar.gz
  Config:    openclaw-config-20260219-batch2-040007.tar.gz

警告：还原将覆盖当前文件！
是否继续？

  输入 yes 确认还原
  输入 no 或按回车取消

> yes
```

**5. 等待还原完成**
```
⚠️  创建紧急备份（还原前自动保存当前状态）...
  ✅ Workspace 紧急备份: 72K
  ✅ Config 紧急备份: 484K

🔄 开始还原...

📂 还原 Workspace...
  ✅ Workspace 还原成功
⚙️  还原 Config...
  ✅ Config 还原成功

╔══════════════════════════════════════════════════════════╗
║  ✅ 还原完成！                                           ║
╚══════════════════════════════════════════════════════════╝

💡 提示：
  - 紧急备份已保存到: /Users/yangfan/clawd/backups/emergency/
  - 建议重启 OpenClaw 以确保配置生效
```

##### 功能特点

- 📦 **按时间点分组显示** - 自动匹配同批次的 workspace + config 备份
- 🔢 **交互式编号选择** - 输入编号即可选择要还原的时间点
- 🎯 **灵活还原模式** - 支持完整还原 / 仅还原 Workspace / 仅还原 Config
- 🛡️ **自动紧急备份** - 还原前自动保存当前状态，可随时回滚
- ⚙️ **通用适配** - 支持配置文件和环境变量

##### 配置方式（三选一）

1. **安装后使用（推荐）** - 自动读取 `~/.openclaw-backup.conf`
   ```bash
   ./install.sh  # 首次运行会自动检测并生成配置
   oc-restore-simple.sh
   ```

2. **环境变量** - 临时覆盖路径
   ```bash
   export BACKUP_DIR=/path/to/backups
   export OPENCLAW_WORKSPACE=/path/to/workspace
   export OPENCLAW_CONFIG=/path/to/config
   ./scripts/restore-simple.sh
   ```

3. **命令行查看帮助**
   ```bash
   ./scripts/restore-simple.sh -h
   ```

### 启动工具

```bash
# 交互模式：检查 → 询问 → 启动 → 诊断
oc-start.sh

# 自动启动
oc-start.sh --start

# 自动重启
oc-start.sh --restart

# 仅检查
oc-start.sh --check
```

检查内容：
- CLI 可用性
- 配置文件有效性
- 工作目录完整性
- Gateway 运行状态
- 日志错误
- 网络端口

## ⚙️ 配置文件

安装后生成 `~/.openclaw-backup.conf`：

```bash
# OpenClaw 配置目录
OPENCLAW_CONFIG="$HOME/.openclaw"

# OpenClaw Workspace 目录
OPENCLAW_WORKSPACE="$HOME/clawd"

# OpenClaw CLI 路径
OPENCLAW_CLI="openclaw"

# 备份存储目录
BACKUP_DIR="$HOME/clawd/backups"

# 备份保留天数
BACKUP_RETENTION_DAYS=7

# 定时备份间隔（小时）
SCHEDULE_INTERVAL_HOURS=4

# 时区
TIMEZONE="Asia/Shanghai"
```

如需修改配置，直接编辑此文件。

## 📁 备份文件

备份文件命名格式：

```
manual-workspace-YYYYMMDD-HHMMSS.tar.gz
manual-config-YYYYMMDD-HHMMSS.tar.gz
emergency-workspace-before-restore-YYYYMMDD-HHMMSS.tar.gz
```

备份内容：
- **Workspace**: SOUL.md、AGENTS.md、memory/、skills/ 等
- **Config**: openclaw.json、clawdbot.json、cron/ 等

排除项：node_modules、.git、backups/、*.log

## 🔄 典型工作流

### 日常开发流程

```bash
# 1. 做任何修改前，先备份
oc-backup.sh "修改 XX 前"

# 2. 执行你的修改
# ... 修改文件 ...

# 3. 如果出问题，一键还原
oc-restore.sh

# 4. 还原后重新启动
oc-start.sh
```

### 配置迁移流程

```bash
# 原机器
oc-backup.sh -n migration "迁移备份"
scp ~/clawd/backups/migration-*.tar.gz new-machine:/tmp/

# 新机器
./install.sh  # 安装工具包
cd /tmp
oc-restore.sh  # 选择迁移备份
oc-start.sh    # 启动服务
```

## 🔧 环境变量

```bash
# 使用自定义配置文件
export OPENCLAW_BACKUP_CONFIG=/path/to/custom.conf
oc-backup.sh

# 临时覆盖备份目录
BACKUP_DIR=/mnt/backup oc-backup.sh
```

## 🐛 故障排除

### 安装失败

```bash
# 检查 OpenClaw 是否安装
which openclaw
openclaw --version

# 手动指定路径安装
./install.sh
# 然后按提示输入自定义路径
```

### 备份失败

```bash
# 检查目录权限
ls -ld ~/.openclaw
ls -ld ~/clawd

# 检查磁盘空间
df -h

# 查看详细日志
cat ~/.openclaw-backup.log
```

### 还原后无法启动

```bash
# 使用启动诊断
oc-start.sh --check

# 查看 Gateway 日志
tail -100 ~/.openclaw/logs/gateway.log

# 如果仍有问题，使用紧急备份回滚
oc-restore.sh  # 选择 emergency-*-before-restore-*.tar.gz
```

## 📝 更新日志

| 版本 | 日期 | 说明 |
|------|------|------|
| **1.2.1** | **2026-02-21** | **修复 `set -e` 模式下 `((count++))` 导致脚本退出的问题** |
| **1.2.0** | **2026-02-19** | **新增 OpenClaw Skill 支持，可直接安装使用** |
| 1.1.1 | 2026-02-19 | `restore-simple.sh` 改为通用版本，支持配置文件和环境变量 |
| 1.1.0 | 2026-02-19 | 新增简化版还原工具 `restore-simple.sh` |
| 1.0.0 | 2026-02-18 | 初始版本，通用备份/还原/启动工具 |

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 PR！

---

**Made with ❤️ for OpenClaw users**
