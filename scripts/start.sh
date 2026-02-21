#!/bin/bash
# OpenClaw Backup Toolkit - 通用启动与诊断脚本
# 自动读取配置文件，适配任意 OpenClaw 安装

set -e

# 查找配置文件
CONFIG_FILE="${OPENCLAW_BACKUP_CONFIG:-$HOME/.openclaw-backup.conf}"

# 加载配置
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "错误: 未找到配置文件 $CONFIG_FILE"
    echo "请先运行 install.sh 进行安装"
    exit 1
fi

# 使用配置或默认值
WORKSPACE_DIR="${OPENCLAW_WORKSPACE:-$HOME/clawd}"
CONFIG_DIR="${OPENCLAW_CONFIG:-$HOME/.openclaw}"
OPENCLAW_CLI="${OPENCLAW_CLI:-openclaw}"
LOG_DIR="$CONFIG_DIR/logs"

# 颜色定义
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' NC=''
fi

# 状态计数
ERRORS=0
WARNINGS=0

print_status() {
    local status=$1
    local message=$2
    case $status in
        ok) echo -e "${GREEN}✓${NC} $message" ;;
        warn) echo -e "${YELLOW}⚠${NC} $message"; ((WARNINGS++)) || true ;;
        error) echo -e "${RED}✗${NC} $message"; ((ERRORS++)) || true ;;
        info) echo -e "${BLUE}ℹ${NC} $message" ;;
        step) echo -e "\n${CYAN}▶ $message${NC}" ;;
    esac
}

show_header() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "           OpenClaw Backup Toolkit - 启动与诊断"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
}

# 检查 CLI
check_cli() {
    print_status step "检查 OpenClaw CLI"
    
    if command -v "$OPENCLAW_CLI" &> /dev/null || [ -x "$OPENCLAW_CLI" ]; then
        local version=$($OPENCLAW_CLI --version 2>/dev/null | head -1 || echo "未知")
        print_status ok "CLI 已安装: $version"
        return 0
    else
        print_status error "未找到 openclaw 命令: $OPENCLAW_CLI"
        return 1
    fi
}

# 检查配置
check_config() {
    print_status step "检查配置文件"
    
    if [ ! -d "$CONFIG_DIR" ]; then
        print_status error "配置目录不存在: $CONFIG_DIR"
        return 1
    fi
    
    print_status ok "配置目录存在"
    
    if [ -f "$CONFIG_DIR/openclaw.json" ]; then
        print_status ok "配置文件存在: openclaw.json"
        
        # 检查 JSON 格式
        if python3 -m json.tool "$CONFIG_DIR/openclaw.json" > /dev/null 2>&1 || \
           jq . "$CONFIG_DIR/openclaw.json" > /dev/null 2>&1; then
            print_status ok "openclaw.json 格式有效"
        else
            print_status warn "openclaw.json 可能格式有误"
        fi
    else
        print_status warn "配置文件缺失: openclaw.json"
    fi
}

# 检查工作目录
check_workspace() {
    print_status step "检查工作目录"
    
    if [ ! -d "$WORKSPACE_DIR" ]; then
        print_status error "工作目录不存在: $WORKSPACE_DIR"
        return 1
    fi
    
    print_status ok "工作目录存在"
    
    local key_files=("SOUL.md" "AGENTS.md" "USER.md")
    for file in "${key_files[@]}"; do
        if [ -f "$WORKSPACE_DIR/$file" ]; then
            print_status ok "核心文件存在: $file"
        else
            print_status warn "核心文件缺失: $file"
        fi
    done
}

# 检查运行状态
check_running() {
    print_status step "检查运行状态"
    
    local pid=$(pgrep -f "openclaw.*gateway" | head -1)
    
    if [ -n "$pid" ]; then
        print_status ok "Gateway 正在运行 (PID: $pid)"
        return 0
    else
        print_status warn "Gateway 未运行"
        return 1
    fi
}

# 启动 Gateway
start_gateway() {
    print_status step "启动 Gateway"
    
    if pgrep -f "openclaw.*gateway" > /dev/null; then
        print_status info "Gateway 已在运行，执行重启..."
        $OPENCLAW_CLI gateway restart
    else
        print_status info "正在启动 Gateway..."
        $OPENCLAW_CLI gateway start
    fi
    
    print_status info "等待服务启动 (3秒)..."
    sleep 3
    
    if pgrep -f "openclaw.*gateway" > /dev/null; then
        print_status ok "Gateway 启动成功"
        return 0
    else
        print_status error "Gateway 启动失败"
        return 1
    fi
}

# 检查日志
check_logs() {
    print_status step "检查日志"
    
    if [ ! -d "$LOG_DIR" ]; then
        print_status warn "日志目录不存在"
        return
    fi
    
    if [ -f "$LOG_DIR/gateway.log" ]; then
        local recent_errors=$(tail -100 "$LOG_DIR/gateway.log" 2>/dev/null | grep -ic "error\|fatal\|panic" || echo "0")
        if [ "$recent_errors" -gt 0 ]; then
            print_status warn "最近日志中发现 $recent_errors 个错误"
            echo ""
            echo "最近的错误:"
            tail -50 "$LOG_DIR/gateway.log" | grep -i "error\|fatal\|panic" | tail -3 | sed 's/^/  /'
        else
            print_status ok "近期日志无错误"
        fi
    fi
}

# 显示修复建议
show_fixes() {
    if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo "           ✅ 所有检查通过！服务运行正常"
        echo "═══════════════════════════════════════════════════════════"
        return
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "           🔧 修复建议"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    if [ $ERRORS -gt 0 ]; then
        echo "发现 $ERRORS 个错误:"
        echo ""
        echo "1. 如果 Gateway 无法启动，尝试:"
        echo "   $OPENCLAW_CLI gateway stop"
        echo "   sleep 2"
        echo "   $OPENCLAW_CLI gateway start"
        echo ""
        echo "2. 检查配置文件格式:"
        echo "   cat $CONFIG_DIR/openclaw.json | python3 -m json.tool"
        echo ""
        echo "3. 查看详细日志:"
        echo "   tail -100 $LOG_DIR/gateway.log"
        echo ""
        echo "4. 如果配置损坏，尝试还原备份:"
        echo "   $(dirname $0)/oc-restore.sh"
        echo ""
    fi
}

# 显示最终状态
show_final_status() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    
    if pgrep -f "openclaw.*gateway" > /dev/null; then
        local pid=$(pgrep -f "openclaw.*gateway" | head -1)
        echo -e "${GREEN}● Gateway 运行中${NC} (PID: $pid)"
    else
        echo -e "${RED}● Gateway 未运行${NC}"
    fi
    
    echo ""
    echo "快捷命令:"
    echo "  查看状态   : $OPENCLAW_CLI status"
    echo "  查看日志   : tail -f $LOG_DIR/gateway.log"
    echo "  重启服务   : $OPENCLAW_CLI gateway restart"
    echo "  停止服务   : $OPENCLAW_CLI gateway stop"
    echo "  还原配置   : $(dirname $0)/oc-restore.sh"
    echo ""
}

# 主流程
main() {
    show_header
    
    check_cli || return 1
    check_config
    check_workspace
    
    local was_running=false
    check_running && was_running=true
    
    # 询问启动
    echo ""
    if [ "$was_running" = true ]; then
        read -p "Gateway 已在运行。是否重启? [y/N]: " restart
        if [[ "$restart" =~ ^[Yy]$ ]]; then
            start_gateway
        fi
    else
        read -p "是否启动 Gateway? [Y/n]: " start
        if [[ ! "$start" =~ ^[Nn]$ ]]; then
            start_gateway
        fi
    fi
    
    check_logs
    show_fixes
    show_final_status
}

# 快速启动
quick_start() {
    show_header
    check_cli && check_config && check_workspace && start_gateway && show_final_status
}

# 仅检查
do_check() {
    show_header
    check_cli
    check_config
    check_workspace
    check_running
    check_logs
    show_fixes
    show_final_status
}

# 处理参数
case "${1:-}" in
    -h|--help)
        echo "OpenClaw Backup Toolkit - 启动与诊断"
        echo ""
        echo "用法: $(basename $0) [选项]"
        echo ""
        echo "选项:"
        echo "  -h, --help     显示帮助"
        echo "  -s, --start    自动启动（不询问）"
        echo "  -r, --restart  自动重启（不询问）"
        echo "  -c, --check    仅检查，不启动"
        echo ""
        ;;
    -s|--start|-r|--restart)
        quick_start
        ;;
    -c|--check)
        do_check
        ;;
    *)
        main
        ;;
esac
