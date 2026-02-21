#!/bin/bash
# OpenClaw Backup Toolkit - 通用手工备份脚本
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
BACKUP_DIR="${BACKUP_DIR:-$HOME/openclaw-backups}"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE:-$HOME/clawd}"
CONFIG_DIR="${OPENCLAW_CONFIG:-$HOME/.openclaw}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

# 颜色定义（检测终端是否支持颜色）
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

# 显示用法
show_usage() {
    echo "OpenClaw Backup Toolkit - 手工备份"
    echo ""
    echo "用法: $(basename $0) [选项] [备注]"
    echo ""
    echo "选项:"
    echo "  -h, --help       显示帮助"
    echo "  -q, --quick      仅备份 workspace（更快）"
    echo "  -c, --config     仅备份配置"
    echo "  -l, --list       列出最近的备份"
    echo "  -n, --name NAME  自定义备份文件名前缀"
    echo "  --cleanup        清理超过 $RETENTION_DAYS 天的旧备份"
    echo ""
    echo "示例:"
    echo "  $(basename $0)                    # 完整备份"
    echo "  $(basename $0) 更新技能前         # 带备注的备份"
    echo "  $(basename $0) -q                 # 快速备份（仅 workspace）"
    echo "  $(basename $0) -l                 # 查看备份列表"
    echo ""
}

# 清理旧备份
cleanup_old_backups() {
    echo "清理超过 $RETENTION_DAYS 天的旧备份..."
    
    local count=0
    if [ -d "$BACKUP_DIR" ]; then
        count=$(find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS | wc -l)
        find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete
    fi
    
    if [ "$count" -gt 0 ]; then
        echo "已清理 $count 个旧备份"
    else
        echo "没有需要清理的旧备份"
    fi
}

# 列出最近备份
list_backups() {
    echo "备份目录: $BACKUP_DIR"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR/*.tar.gz 2>/dev/null)" ]; then
        echo "暂无备份文件"
        return
    fi
    
    printf "%-25s %-12s %-10s %-30s\n" "时间" "类型" "大小" "文件名"
    echo "─────────────────────────────────────────────────────────────────────"
    
    ls -1t $BACKUP_DIR/*.tar.gz 2>/dev/null | head -20 | while read file; do
        local filename=$(basename "$file")
        local size=$(du -h "$file" 2>/dev/null | cut -f1)
        local mtime=$(stat -c "%y" "$file" 2>/dev/null | cut -d'.' -f1 || stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$file" 2>/dev/null)
        
        # 判断类型
        local type="其他"
        if [[ "$filename" == *"workspace"* ]]; then
            type="Workspace"
        elif [[ "$filename" == *"config"* ]]; then
            type="Config"
        elif [[ "$filename" == *"emergency"* ]]; then
            type="紧急备份"
        elif [[ "$filename" == *"manual"* ]]; then
            type="手工备份"
        elif [[ "$filename" == *"auto"* ]] || [[ "$filename" == *"openclaw-"* ]]; then
            type="自动备份"
        fi
        
        printf "%-25s %-12s %-10s %-30s\n" "$mtime" "$type" "$size" "$filename"
    done
    
    echo ""
    local total=$(ls -1 $BACKUP_DIR/*.tar.gz 2>/dev/null | wc -l)
    local total_size=$(du -sh $BACKUP_DIR 2>/dev/null | cut -f1)
    echo "共 $total 个备份，总大小: $total_size"
    echo ""
    echo "保留策略: 保留最近 $RETENTION_DAYS 天的备份"
}

# 执行备份
do_backup() {
    local prefix=$1
    local backup_type=$2
    local note=$3
    
    mkdir -p "$BACKUP_DIR"
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local date_str=$(date +%Y%m%d)
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "           开始备份 - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    echo "Workspace: $WORKSPACE_DIR"
    echo "Config:    $CONFIG_DIR"
    echo "备份目录:  $BACKUP_DIR"
    [ -n "$note" ] && echo "备注:      $note"
    echo ""
    
    local workspace_file=""
    local config_file=""
    local success_count=0
    
    # 备份 workspace
    if [ "$backup_type" = "full" ] || [ "$backup_type" = "quick" ]; then
        echo "📂 备份 Workspace..."
        
        if [ -n "$prefix" ]; then
            workspace_file="$BACKUP_DIR/${prefix}-workspace-${timestamp}.tar.gz"
        else
            workspace_file="$BACKUP_DIR/manual-workspace-${timestamp}.tar.gz"
        fi
        
        if tar czf "$workspace_file" \
            --exclude='node_modules' \
            --exclude='.git' \
            --exclude='backups' \
            --exclude='*.log' \
            -C "$WORKSPACE_DIR" . 2>/dev/null; then
            local ws_size=$(du -h "$workspace_file" | cut -f1)
            echo "  ✓ Workspace 备份成功: $(basename $workspace_file) (${ws_size})"
            success_count=$((success_count + 1))
        else
            echo "  ✗ Workspace 备份失败"
        fi
    fi
    
    # 备份 config
    if [ "$backup_type" = "full" ] || [ "$backup_type" = "config" ]; then
        echo "⚙️  备份 Config..."
        
        if [ -d "$CONFIG_DIR" ]; then
            if [ -n "$prefix" ]; then
                config_file="$BACKUP_DIR/${prefix}-config-${timestamp}.tar.gz"
            else
                config_file="$BACKUP_DIR/manual-config-${timestamp}.tar.gz"
            fi
            
            if tar czf "$config_file" -C "$(dirname $CONFIG_DIR)" "$(basename $CONFIG_DIR)" 2>/dev/null; then
            local cfg_size=$(du -h "$config_file" | cut -f1)
            echo "  ✓ Config 备份成功: $(basename $config_file) (${cfg_size})"
            success_count=$((success_count + 1))
            else
                echo "  ✗ Config 备份失败"
            fi
        else
            echo "  ⚠ Config 目录不存在，跳过"
        fi
    fi
    
    # 保存备注
    if [ -n "$note" ]; then
        local note_file="$BACKUP_DIR/README.txt"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $timestamp - $note" >> "$note_file"
    fi
    
    echo ""
    if [ $success_count -gt 0 ]; then
        echo "═══════════════════════════════════════════════════════════"
        echo "           ✓ 备份完成 ($success_count/2)"
        echo "═══════════════════════════════════════════════════════════"
    else
        echo "═══════════════════════════════════════════════════════════"
        echo "           ✗ 备份失败"
        echo "═══════════════════════════════════════════════════════════"
        return 1
    fi
    
    echo ""
    [ -n "$workspace_file" ] && echo "Workspace: $workspace_file"
    [ -n "$config_file" ] && echo "Config:    $config_file"
    echo ""
    echo "提示: 如需还原，请运行: $(dirname $0)/oc-restore.sh"
}

# 解析参数
PREFIX=""
NOTE=""
TYPE="full"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        --cleanup)
            cleanup_old_backups
            exit 0
            ;;
        -q|--quick)
            TYPE="quick"
            shift
            ;;
        -c|--config)
            TYPE="config"
            shift
            ;;
        -l|--list)
            list_backups
            exit 0
            ;;
        -n|--name)
            PREFIX="$2"
            shift 2
            ;;
        -*)
            echo "错误: 未知选项: $1"
            show_usage
            exit 1
            ;;
        *)
            NOTE="$1"
            shift
            ;;
    esac
done

# 执行备份
do_backup "$PREFIX" "$TYPE" "$NOTE"
