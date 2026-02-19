#!/bin/bash
# OpenClaw 交互式还原工具 (通用版本)
# 自动读取配置文件，适配任意 OpenClaw 安装

set -e

# 查找配置文件
CONFIG_FILE="${OPENCLAW_BACKUP_CONFIG:-$HOME/.openclaw-backup.conf}"

# 加载配置
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# 使用配置或默认值
BACKUP_DIR="${BACKUP_DIR:-$HOME/clawd/backups}"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE:-$HOME/clawd}"
CONFIG_DIR="${OPENCLAW_CONFIG:-$HOME/.openclaw}"
EMERGENCY_DIR="$BACKUP_DIR/emergency"

# 显示标题
show_header() {
    echo "══════════════════════════════════════════════════════════"
    echo "           OpenClaw 交互式还原工具"
    echo ""
    echo "  选择备份时间点，一键还原 Workspace 和 Config"
    echo "══════════════════════════════════════════════════════════"
    echo ""
}

# 按时间点分组显示
list_by_timestamp() {
    echo "📦 按时间点分组显示备份..."
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR/*.tar.gz 2>/dev/null)" ]; then
        echo "❌ 没有找到备份文件"
        exit 1
    fi
    
    # 清理临时文件
    rm -f /tmp/backup_selection.txt
    
    echo "═══════════════════════════════════════════════════════════════════════"
    printf "  %-4s │ %-19s │ %-4s │ %-9s │ %-7s │ %s\n" "编号" "备份时间" "批次" "Workspace" "Config" "状态"
    echo "═══════════════════════════════════════════════════════════════════════"
    
    local idx=1
    # 查找所有配对
    ls -1t $BACKUP_DIR/openclaw-workspace-*.tar.gz 2>/dev/null | while read ws_file; do
        local ws_name=$(basename "$ws_file")
        # 从文件名提取日期、批次、时间
        if [[ "$ws_name" =~ openclaw-workspace-([0-9]{8})-batch([0-9]+)-([0-9]{6})\.tar\.gz ]]; then
            local date_part="${BASH_REMATCH[1]}"
            local batch="${BASH_REMATCH[2]}"
            local time_part="${BASH_REMATCH[3]}"
            
            local formatted_date="${date_part:0:4}-${date_part:4:2}-${date_part:6:2}"
            local formatted_time="${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"
            local datetime="${formatted_date} ${formatted_time}"
            
            # 查找对应的 config 文件
            local cfg_file="$BACKUP_DIR/openclaw-config-${date_part}-batch${batch}-${time_part}.tar.gz"
            
            local ws_size=$(du -h "$ws_file" 2>/dev/null | cut -f1)
            local cfg_size="-"
            local status="W"
            
            if [ -f "$cfg_file" ]; then
                cfg_size=$(du -h "$cfg_file" 2>/dev/null | cut -f1)
                status="WC"
            fi
            
            printf "  %-4d │ %-19s │ %-4s │ %-9s │ %-7s │ %s\n" "$idx" "$datetime" "$batch" "$ws_size" "$cfg_size" "$status"
            
            # 保存选择信息
            echo "$idx|$date_part|$batch|$time_part|$ws_file|$cfg_file" >> /tmp/backup_selection.txt
            
            ((idx++))
        fi
    done
    
    echo "═══════════════════════════════════════════════════════════════════════"
    echo "说明: W=Workspace备份, C=Config备份"
    echo ""
}

# 创建紧急备份
create_emergency_backup() {
    echo "⚠️  创建紧急备份（还原前自动保存当前状态）..."
    
    mkdir -p "$EMERGENCY_DIR"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    # 紧急备份 workspace
    local ws_emergency="$EMERGENCY_DIR/emergency-workspace-before-restore-${timestamp}.tar.gz"
    if tar czf "$ws_emergency" --exclude='node_modules' --exclude='.git' --exclude='backups' -C "$WORKSPACE_DIR" . 2>/dev/null; then
        local ws_size=$(du -h "$ws_emergency" | cut -f1)
        echo "  ✅ Workspace 紧急备份: ${ws_size}"
    else
        echo "  ❌ Workspace 紧急备份失败"
    fi
    
    # 紧急备份 config
    local cfg_emergency="$EMERGENCY_DIR/emergency-config-before-restore-${timestamp}.tar.gz"
    if [ -d "$CONFIG_DIR" ]; then
        if tar czf "$cfg_emergency" -C ~ $(basename "$CONFIG_DIR") 2>/dev/null; then
            local cfg_size=$(du -h "$cfg_emergency" | cut -f1)
            echo "  ✅ Config 紧急备份: ${cfg_size}"
        else
            echo "  ❌ Config 紧急备份失败"
        fi
    fi
    
    echo ""
}

# 执行还原
do_restore() {
    local selection_file=$1
    local restore_ws=$2
    local restore_cfg=$3
    
    if [ ! -f "$selection_file" ]; then
        echo "❌ 备份列表不存在，请先选择备份"
        return 1
    fi
    
    echo "请输入要还原的编号（或输入 0 取消）："
    echo -n "> "
    read -r choice
    
    if [ "$choice" = "0" ] || [ -z "$choice" ]; then
        echo "已取消还原"
        return 0
    fi
    
    # 查找选中的备份
    local selected_line=$(grep "^$choice|" "$selection_file" 2>/dev/null || echo "")
    
    if [ -z "$selected_line" ]; then
        echo "❌ 无效的编号"
        return 1
    fi
    
    # 解析选中的备份信息
    IFS='|' read -r idx date_part batch time_part ws_file cfg_file <<< "$selected_line"
    
    # 显示确认信息
    echo ""
    echo "══════════════════════════════════════════════════════════"
    echo "⚠️  即将执行还原操作"
    echo ""
    
    if [ "$restore_ws" = "true" ] && [ -n "$ws_file" ] && [ -f "$ws_file" ]; then
        echo "  Workspace: $(basename $ws_file)"
    fi
    
    if [ "$restore_cfg" = "true" ] && [ -n "$cfg_file" ] && [ -f "$cfg_file" ]; then
        echo "  Config:    $(basename $cfg_file)"
    fi
    
    echo ""
    echo "警告：还原将覆盖当前文件！"
    echo "是否继续？"
    echo ""
    echo "  输入 yes 确认还原"
    echo "  输入 no 或按回车取消"
    echo ""
    echo -n "> "
    read -r confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "已取消还原"
        return 0
    fi
    
    # 创建紧急备份
    create_emergency_backup
    
    # 执行还原
    echo ""
    echo "══════════════════════════════════════════════════════════"
    echo "🔄 开始还原..."
    echo ""
    
    local success=true
    
    # 还原 Workspace
    if [ "$restore_ws" = "true" ] && [ -n "$ws_file" ] && [ -f "$ws_file" ]; then
        echo "📂 还原 Workspace..."
        
        # 先清理 workspace 目录（保留 backups 目录）
        find "$WORKSPACE_DIR" -maxdepth 1 -not -path "$WORKSPACE_DIR" -not -path "*/backups" -exec rm -rf {} + 2>/dev/null || true
        
        if tar xzf "$ws_file" -C "$WORKSPACE_DIR" 2>/dev/null; then
            echo "  ✅ Workspace 还原成功"
        else
            echo "  ❌ Workspace 还原失败"
            success=false
        fi
    elif [ "$restore_ws" = "true" ]; then
        echo "  ⚠️  未找到 Workspace 备份文件"
    fi
    
    # 还原 Config
    if [ "$restore_cfg" = "true" ] && [ -n "$cfg_file" ] && [ -f "$cfg_file" ]; then
        echo "⚙️  还原 Config..."
        
        # 先备份当前 config
        if [ -d "$CONFIG_DIR" ]; then
            rm -rf "$CONFIG_DIR.bak"
            mv "$CONFIG_DIR" "$CONFIG_DIR.bak"
        fi
        
        if tar xzf "$cfg_file" -C ~ 2>/dev/null; then
            echo "  ✅ Config 还原成功"
            rm -rf "$CONFIG_DIR.bak"
        else
            echo "  ❌ Config 还原失败"
            if [ -d "$CONFIG_DIR.bak" ]; then
                mv "$CONFIG_DIR.bak" "$CONFIG_DIR"
            fi
            success=false
        fi
    elif [ "$restore_cfg" = "true" ]; then
        echo "  ⚠️  未找到 Config 备份文件"
    fi
    
    echo ""
    if [ "$success" = "true" ]; then
        echo "╔══════════════════════════════════════════════════════════╗"
        echo "║  ✅ 还原完成！                                           ║"
        echo "╚══════════════════════════════════════════════════════════╝"
    else
        echo "╔══════════════════════════════════════════════════════════╗"
        echo "║  ⚠️  还原完成，但部分操作失败                            ║"
        echo "╚══════════════════════════════════════════════════════════╝"
    fi
    
    echo ""
    echo "💡 提示："
    echo "  - 紧急备份已保存到: $EMERGENCY_DIR"
    echo "  - 建议重启 OpenClaw 以确保配置生效"
    echo ""
}

# 显示菜单
show_menu() {
    echo "══════════════════════════════════════════════════════════"
    echo "  请选择操作："
    echo ""
    echo "  1. 查看所有备份列表（详细）"
    echo "  2. 按时间点查看备份（推荐）"
    echo "  3. 还原到指定时间点"
    echo "  4. 仅还原 Workspace"
    echo "  5. 仅还原 Config"
    echo "  6. 查看最新备份"
    echo "  q. 退出"
    echo ""
    echo "══════════════════════════════════════════════════════════"
    echo ""
}

# 显示最新备份
show_latest() {
    echo "📦 最新的5个备份："
    echo ""
    
    printf "%-40s %-10s %-20s\n" "文件名" "大小" "时间"
    echo "─────────────────────────────────────────────────────────"
    
    ls -1t $BACKUP_DIR/*.tar.gz 2>/dev/null | head -5 | while read file; do
        local filename=$(basename "$file")
        local size=$(du -h "$file" 2>/dev/null | cut -f1)
        local mtime=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$file" 2>/dev/null || stat -c "%y" "$file" 2>/dev/null | cut -d'.' -f1)
        printf "%-40s %-10s %-20s\n" "$filename" "$size" "$mtime"
    done
    
    echo ""
}

# 清理临时文件
cleanup() {
    rm -f /tmp/backup_selection.txt
}

# 主程序
main() {
    trap cleanup EXIT
    
    show_header
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "❌ 备份目录不存在: $BACKUP_DIR"
        echo ""
        echo "提示：你可以通过以下方式指定备份目录："
        echo "  1. 创建配置文件 ~/.openclaw-backup.conf"
        echo "  2. 设置环境变量: export BACKUP_DIR=/your/backup/path"
        echo "  3. 先运行 ./install.sh 进行安装"
        exit 1
    fi
    
    while true; do
        show_menu
        echo -n "> "
        read -r choice
        
        case $choice in
            1)
                echo ""
                ls -1t $BACKUP_DIR/*.tar.gz 2>/dev/null | head -20 | while read f; do echo "  $(basename $f)"; done
                echo ""
                echo "按回车键返回菜单..."
                read
                ;;
            2)
                echo ""
                rm -f /tmp/backup_selection.txt
                list_by_timestamp
                echo "按回车键返回菜单..."
                read
                ;;
            3)
                echo ""
                rm -f /tmp/backup_selection.txt
                list_by_timestamp
                echo ""
                do_restore /tmp/backup_selection.txt true true
                echo "按回车键返回菜单..."
                read
                ;;
            4)
                echo ""
                rm -f /tmp/backup_selection.txt
                list_by_timestamp
                echo ""
                echo "将只还原 Workspace（保留当前 Config）"
                do_restore /tmp/backup_selection.txt true false
                echo "按回车键返回菜单..."
                read
                ;;
            5)
                echo ""
                rm -f /tmp/backup_selection.txt
                list_by_timestamp
                echo ""
                echo "将只还原 Config（保留当前 Workspace）"
                do_restore /tmp/backup_selection.txt false true
                echo "按回车键返回菜单..."
                read
                ;;
            6)
                echo ""
                show_latest
                echo "按回车键返回菜单..."
                read
                ;;
            q|Q|quit|exit)
                echo "再见！"
                exit 0
                ;;
            *)
                echo "无效选项，请重新选择"
                sleep 1
                ;;
        esac
        
        echo ""
    done
}

# 参数处理
if [ $# -gt 0 ]; then
    case $1 in
        -l|--list)
            rm -f /tmp/backup_selection.txt
            list_by_timestamp
            exit 0
            ;;
        -h|--help)
            show_header
            echo "用法: $(basename $0) [选项]"
            echo ""
            echo "选项:"
            echo "  -l, --list     按时间点列出备份"
            echo "  -h, --help     显示帮助"
            echo ""
            echo "环境变量:"
            echo "  BACKUP_DIR              备份目录"
            echo "  OPENCLAW_WORKSPACE      Workspace 目录"
            echo "  OPENCLAW_CONFIG         Config 目录"
            echo "  OPENCLAW_BACKUP_CONFIG  配置文件路径"
            echo ""
            echo "不带参数运行将进入交互式菜单"
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            echo "使用 -h 查看帮助"
            exit 1
            ;;
    esac
fi

main
