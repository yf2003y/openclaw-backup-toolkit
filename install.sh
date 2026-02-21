#!/bin/bash
# OpenClaw Backup Toolkit - 通用安装脚本
# 自动检测并配置备份工具

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_NAME="OpenClaw Backup Toolkit"
CONFIG_FILE="$HOME/.openclaw-backup.conf"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 打印函数
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_ok() { echo -e "${GREEN}✓${NC} $1"; }
print_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_step() { echo -e "\n${CYAN}▶ $1${NC}"; }

# 显示标题
show_header() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║           OpenClaw Backup Toolkit 安装程序               ║"
    echo "║                                                          ║"
    echo "║  通用备份/还原/启动工具包                                ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检测 OpenClaw 配置目录
detect_openclaw_config() {
    local possible_paths=(
        "$HOME/.openclaw"
        "$HOME/.config/openclaw"
        "/opt/openclaw"
        "/usr/local/etc/openclaw"
    )
    
    for path in "${possible_paths[@]}"; do
        if [ -d "$path" ] && [ -f "$path/openclaw.json" ]; then
            echo "$path"
            return 0
        fi
    done
    
    # 尝试从环境变量或进程查找
    local config_from_process=$(pgrep -a openclaw 2>/dev/null | grep -oE '\-\-config [^ ]+' | head -1 | cut -d' ' -f2)
    if [ -n "$config_from_process" ] && [ -d "$config_from_process" ]; then
        echo "$config_from_process"
        return 0
    fi
    
    return 1
}

# 检测 OpenClaw Workspace
detect_openclaw_workspace() {
    local possible_paths=(
        "$HOME/clawd"
        "$HOME/openclaw"
        "$HOME/.openclaw/workspace"
        "/opt/openclaw/workspace"
    )
    
    for path in "${possible_paths[@]}"; do
        if [ -d "$path" ] && [ -f "$path/SOUL.md" ]; then
            echo "$path"
            return 0
        fi
    done
    
    # 尝试从配置文件读取
    local config_dir=$(detect_openclaw_config)
    if [ -n "$config_dir" ] && [ -f "$config_dir/workspace-state.json" ]; then
        local workspace=$(grep -oE '"path"[^,]*' "$config_dir/workspace-state.json" 2>/dev/null | head -1 | cut -d'"' -f4)
        if [ -n "$workspace" ] && [ -d "$workspace" ]; then
            echo "$workspace"
            return 0
        fi
    fi
    
    return 1
}

# 检测 openclaw CLI
detect_openclaw_cli() {
    if command -v openclaw &> /dev/null; then
        which openclaw
        return 0
    fi
    
    local possible_paths=(
        "/opt/homebrew/bin/openclaw"
        "/usr/local/bin/openclaw"
        "/usr/bin/openclaw"
        "$HOME/.local/bin/openclaw"
    )
    
    for path in "${possible_paths[@]}"; do
        if [ -x "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# 生成配置文件
generate_config() {
    local config_dir=$1
    local workspace_dir=$2
    local cli_path=$3
    local backup_dir=$4
    
    cat > "$CONFIG_FILE" << EOF
# OpenClaw Backup Toolkit 配置文件
# 生成时间: $(date)

# OpenClaw 配置目录（包含 openclaw.json）
OPENCLAW_CONFIG="$config_dir"

# OpenClaw Workspace 目录（包含 SOUL.md 等）
OPENCLAW_WORKSPACE="$workspace_dir"

# OpenClaw CLI 路径
OPENCLAW_CLI="$cli_path"

# 备份存储目录
BACKUP_DIR="$backup_dir"

# 备份保留天数（超过将自动清理）
BACKUP_RETENTION_DAYS=7

# 定时备份间隔（小时）
SCHEDULE_INTERVAL_HOURS=4

# 时区
TIMEZONE="Asia/Shanghai"
EOF
    
    print_ok "配置文件已生成: $CONFIG_FILE"
}

# 安装脚本
install_scripts() {
    print_step "安装脚本"
    
    local install_dir="$HOME/.local/bin"
    
    # 询问安装目录
    read -p "安装目录 [$install_dir]: " custom_dir
    if [ -n "$custom_dir" ]; then
        install_dir="$custom_dir"
    fi
    
    mkdir -p "$install_dir"
    
    # 安装脚本
    local scripts=("backup.sh" "restore.sh" "start.sh" "healthcheck.sh")
    for script in "${scripts[@]}"; do
        if [ -f "$SCRIPT_DIR/scripts/$script" ]; then
            cp "$SCRIPT_DIR/scripts/$script" "$install_dir/oc-$script"
            chmod +x "$install_dir/oc-$script"
            print_ok "已安装: oc-$script"
        fi
    done
    
    # 创建快捷命令
    cat > "$install_dir/oc-backup" << 'EOF'
#!/bin/bash
# OpenClaw Backup Toolkit 快捷入口
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && dirname "$0")"
exec "$SCRIPT_DIR/.local/bin/oc-backup.sh" "$@"
EOF
    chmod +x "$install_dir/oc-backup"
    
    print_info "脚本已安装到: $install_dir"
    
    # 检查 PATH
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        print_warn "$install_dir 不在 PATH 中"
        echo "请添加以下行到你的 ~/.bashrc 或 ~/.zshrc:"
        echo "  export PATH=\"\$PATH:$install_dir\""
    fi
}

# 创建定时任务
setup_cron() {
    print_step "设置定时备份"
    
    read -p "是否启用自动定时备份? [Y/n]: " enable_cron
    if [[ "$enable_cron" =~ ^[Nn]$ ]]; then
        print_info "跳过定时备份设置"
        return
    fi
    
    # 检查 openclaw cron 是否可用
    if command -v openclaw &> /dev/null; then
        print_info "使用 OpenClaw 内置 cron 功能"
        
        # 创建定时备份任务
        local cron_job=$(cat <<EOF
{
  "name": "OpenClaw Auto Backup (Toolkit)",
  "schedule": {"kind": "cron", "expr": "0 */4 * * *", "tz": "Asia/Shanghai"},
  "payload": {"kind": "agentTurn", "message": "执行自动备份任务", "model": "moonshot/kimi-k2.5", "timeoutSeconds": 120},
  "sessionTarget": "isolated",
  "enabled": true,
  "notify": false
}
EOF
)
        print_info "请手动添加以下 cron 任务:"
        echo "$cron_job"
        echo ""
        echo "命令: openclaw cron add"
    else
        print_info "使用系统 cron"
        
        # 添加系统 cron 任务
        local cron_line="0 */4 * * * $HOME/.local/bin/oc-auto-backup.sh >> $HOME/.openclaw-backup.log 2>&1"
        
        # 检查是否已存在
        if crontab -l 2>/dev/null | grep -q "oc-auto-backup"; then
            print_warn "定时任务已存在"
        else
            (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
            print_ok "定时任务已添加"
        fi
    fi
}

# 验证安装
verify_installation() {
    print_step "验证安装"
    
    local errors=0
    
    # 检查配置文件
    if [ -f "$CONFIG_FILE" ]; then
        print_ok "配置文件存在"
        source "$CONFIG_FILE"
    else
        print_error "配置文件不存在"
        ((errors++)) || true
    fi
    
    # 检查目录
    if [ -d "$OPENCLAW_CONFIG" ]; then
        print_ok "配置目录: $OPENCLAW_CONFIG"
    else
        print_error "配置目录不存在: $OPENCLAW_CONFIG"
        ((errors++)) || true
    fi
    
    if [ -d "$OPENCLAW_WORKSPACE" ]; then
        print_ok "Workspace 目录: $OPENCLAW_WORKSPACE"
    else
        print_error "Workspace 目录不存在: $OPENCLAW_WORKSPACE"
        ((errors++)) || true
    fi
    
    if [ -d "$BACKUP_DIR" ]; then
        print_ok "备份目录: $BACKUP_DIR"
    else
        print_warn "备份目录不存在，将自动创建"
        mkdir -p "$BACKUP_DIR"
    fi
    
    # 测试备份
    print_info "测试备份功能..."
    if "$HOME/.local/bin/oc-backup.sh" -q "安装测试" > /dev/null 2>&1; then
        print_ok "备份功能正常"
    else
        print_error "备份功能异常"
        ((errors++)) || true
    fi
    
    if [ $errors -eq 0 ]; then
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✅ 安装成功！                                           ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
        return 0
    else
        echo ""
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  ⚠️ 安装完成，但有 $errors 个问题需要修复                ║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
        return 1
    fi
}

# 显示使用说明
show_usage() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo -e "${CYAN}安装完成！使用方法：${NC}"
    echo ""
    echo "快捷命令:"
    echo "  oc-backup.sh              # 手工备份"
    echo "  oc-backup.sh -l           # 查看备份列表"
    echo "  oc-restore.sh             # 一键还原"
    echo "  oc-start.sh               # 启动并诊断"
    echo "  oc-healthcheck.sh         # 健康检查"
    echo ""
    echo "配置文件: $CONFIG_FILE"
    echo "备份目录: $BACKUP_DIR"
    echo ""
    echo "快速开始:"
    echo "  1. 测试备份: oc-backup.sh '测试备份'"
    echo "  2. 查看状态: oc-start.sh --check"
    echo "  3. 阅读文档: cat $SCRIPT_DIR/README.md"
    echo ""
}

# 主流程
main() {
    show_header
    
    print_step "检测 OpenClaw 环境"
    
    # 自动检测配置目录
    local config_dir=$(detect_openclaw_config)
    if [ -n "$config_dir" ]; then
        print_ok "检测到配置目录: $config_dir"
    else
        print_warn "未自动检测到配置目录"
        read -p "请输入 OpenClaw 配置目录: " config_dir
    fi
    
    # 自动检测 Workspace
    local workspace_dir=$(detect_openclaw_workspace)
    if [ -n "$workspace_dir" ]; then
        print_ok "检测到 Workspace: $workspace_dir"
    else
        print_warn "未自动检测到 Workspace"
        read -p "请输入 OpenClaw Workspace 目录: " workspace_dir
    fi
    
    # 检测 CLI
    local cli_path=$(detect_openclaw_cli)
    if [ -n "$cli_path" ]; then
        print_ok "检测到 CLI: $cli_path"
    else
        print_warn "未检测到 openclaw CLI"
        cli_path="openclaw"
    fi
    
    # 设置备份目录
    local default_backup="${workspace_dir}/backups"
    read -p "备份存储目录 [$default_backup]: " backup_dir
    backup_dir="${backup_dir:-$default_backup}"
    
    # 生成配置
    print_step "生成配置文件"
    generate_config "$config_dir" "$workspace_dir" "$cli_path" "$backup_dir"
    
    # 安装脚本
    install_scripts
    
    # 设置定时任务
    setup_cron
    
    # 验证
    verify_installation
    
    # 显示使用说明
    show_usage
}

# 运行安装
main "$@"
