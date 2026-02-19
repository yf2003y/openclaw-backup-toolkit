#!/bin/bash
# OpenClaw Backup Toolkit - 通用还原脚本
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
TEMP_DIR="/tmp/openclaw-restore-$$"

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

# 清理函数
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# 显示标题
show_header() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "           OpenClaw Backup Toolkit - 一键还原"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Workspace: $WORKSPACE_DIR"
    echo "Config:    $CONFIG_DIR"
    echo "备份目录:  $BACKUP_DIR"
    echo ""
}

# 列出可用备份
list_backups() {
    echo "📦 可用备份列表："
    echo ""
    
    local workspace_backups=($(ls -1t "$BACKUP_DIR"/*workspace*.tar.gz 2>/dev/null || true))
    local config_backups=($(ls -1t "$BACKUP_DIR"/*config*.tar.gz 2>/dev/null || true))
    
    if [ ${#workspace_backups[@]} -eq 0 ] && [ ${#config_backups[@]} -eq 0 ]; then
        echo "❌ 未找到任何备份文件！"
        echo "备份目录: $BACKUP_DIR"
        exit 1
    fi
    
    echo "Workspace 备份:"
    echo "───────────────────────────────────────────────────────────"
    local idx=1
    for backup in "${workspace_backups[@]}"; do
        local filename=$(basename "$backup")
        local size=$(du -h "$backup" 2>/dev/null | cut -f1)
        local date_str=$(echo "$filename" | grep -oE '[0-9]{8}' || echo "unknown")
        local formatted_date="${date_str:0:4}-${date_str:4:2}-${date_str:6:2}"
        
        printf "  [%d] %s (%s, %s)\n" "$idx" "$filename" "$formatted_date" "$size"
        echo "$idx|$backup" >> "$TEMP_DIR/workspace_map.txt"
        ((idx++))
    done
    
    echo ""
    echo "Config 备份:"
    echo "───────────────────────────────────────────────────────────"
    idx=1
    for backup in "${config_backups[@]}"; do
        local filename=$(basename "$backup")
        local size=$(du -h "$backup" 2>/dev/null | cut -f1)
        local date_str=$(echo "$filename" | grep -oE '[0-9]{8}' || echo "unknown")
        local formatted_date="${date_str:0:4}-${date_str:4:2}-${date_str:6:2}"
        
        printf "  [%d] %s (%s, %s)\n" "$idx" "$filename" "$formatted_date" "$size"
        echo "$idx|$backup" >> "$TEMP_DIR/config_map.txt"
        ((idx++))
    done
    
    echo ""
}

# 创建紧急备份
create_emergency_backup() {
    echo "⚠️  正在创建当前状态紧急备份..."
    
    local emergency_timestamp=$(date +%Y%m%d-%H%M%S)
    local emergency_workspace="$BACKUP_DIR/emergency-workspace-before-restore-${emergency_timestamp}.tar.gz"
    local emergency_config="$BACKUP_DIR/emergency-config-before-restore-${emergency_timestamp}.tar.gz"
    
    # 备份当前 workspace
    if tar czf "$emergency_workspace" \
        --exclude='node_modules' \
        --exclude='.git' \
        --exclude='backups' \
        -C "$WORKSPACE_DIR" . 2>/dev/null; then
        echo "  ✓ 紧急 Workspace 备份: $(basename "$emergency_workspace")"
    else
        echo "  ✗ Workspace 紧急备份失败"
        return 1
    fi
    
    # 备份当前 config
    if [ -d "$CONFIG_DIR" ]; then
        if tar czf "$emergency_config" -C "$(dirname $CONFIG_DIR)" "$(basename $CONFIG_DIR)" 2>/dev/null; then
            echo "  ✓ 紧急 Config 备份: $(basename "$emergency_config")"
        else
            echo "  ✗ Config 紧急备份失败"
            return 1
        fi
    fi
    
    echo "  紧急备份已保存，如需回滚请使用这些文件"
}

# 还原 workspace
restore_workspace() {
    local backup_file=$1
    
    echo ""
    echo "📂 开始还原 Workspace..."
    
    mkdir -p "$TEMP_DIR/workspace"
    
    # 解压备份
    if tar xzf "$backup_file" -C "$TEMP_DIR/workspace"; then
        echo "  ✓ 备份文件解压成功"
    else
        echo "  ✗ 备份文件解压失败！"
        return 1
    fi
    
    # 保存重要的当前文件
    echo "  🧹 清理当前 workspace..."
    mkdir -p "$TEMP_DIR/preserve"
    [ -d "$WORKSPACE_DIR/backups" ] && cp -r "$WORKSPACE_DIR/backups" "$TEMP_DIR/preserve/" 2>/dev/null || true
    [ -d "$WORKSPACE_DIR/scripts" ] && cp -r "$WORKSPACE_DIR/scripts" "$TEMP_DIR/preserve/" 2>/dev/null || true
    
    # 清理并还原
    find "$WORKSPACE_DIR" -mindepth 1 -maxdepth 1 ! -name 'backups' ! -name 'scripts' -exec rm -rf {} + 2>/dev/null || true
    
    # 复制备份内容
    cp -r "$TEMP_DIR/workspace/"* "$WORKSPACE_DIR/" 2>/dev/null || true
    cp -r "$TEMP_DIR/workspace/".* "$WORKSPACE_DIR/" 2>/dev/null || true
    
    # 恢复保留的文件
    [ -d "$TEMP_DIR/preserve/backups" ] && cp -r "$TEMP_DIR/preserve/backups" "$WORKSPACE_DIR/"
    [ -d "$TEMP_DIR/preserve/scripts" ] && cp -r "$TEMP_DIR/preserve/scripts" "$WORKSPACE_DIR/"
    
    echo "  ✓ Workspace 还原完成"
}

# 还原 config
restore_config() {
    local backup_file=$1
    
    echo ""
    echo "⚙️  开始还原 Config..."
    
    # 删除当前 config
    if [ -d "$CONFIG_DIR" ]; then
        rm -rf "$CONFIG_DIR"
    fi
    
    # 解压备份
    if tar xzf "$backup_file" -C "$(dirname $CONFIG_DIR)"; then
        echo "  ✓ Config 还原完成"
    else
        echo "  ✗ Config 还原失败！"
        return 1
    fi
}

# 验证还原结果
verify_restore() {
    echo ""
    echo "🔍 验证还原结果..."
    
    local errors=0
    
    # 检查关键文件
    local key_files=("SOUL.md" "AGENTS.md" "USER.md")
    for file in "${key_files[@]}"; do
        if [ -f "$WORKSPACE_DIR/$file" ]; then
            echo "  ✓ $file 存在"
        else
            echo "  ✗ $file 缺失！"
            ((errors++))
        fi
    done
    
    # 检查 config
    if [ -d "$CONFIG_DIR" ] && [ -f "$CONFIG_DIR/openclaw.json" ]; then
        echo "  ✓ Config 目录正常"
    else
        echo "  ✗ Config 目录异常！"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo "           ✨ 所有检查通过，还原成功！"
        echo "═══════════════════════════════════════════════════════════"
        return 0
    else
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo "           ⚠️  发现 $errors 个问题，请检查"
        echo "═══════════════════════════════════════════════════════════"
        return 1
    fi
}

# 自动匹配备份
auto_match_backup() {
    local target_backup=$1
    local target_date=$(echo "$target_backup" | grep -oE '[0-9]{8}' || echo "")
    
    if [[ "$target_backup" == *"workspace"* ]]; then
        # 找对应的 config
        ls -1t "$BACKUP_DIR"/*config*${target_date}*.tar.gz 2>/dev/null | head -1
    else
        # 找对应的 workspace
        ls -1t "$BACKUP_DIR"/*workspace*${target_date}*.tar.gz 2>/dev/null | head -1
    fi
}

# 主流程
main() {
    mkdir -p "$TEMP_DIR"
    > "$TEMP_DIR/workspace_map.txt"
    > "$TEMP_DIR/config_map.txt"
    
    show_header
    
    # 检查备份目录
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "❌ 备份目录不存在: $BACKUP_DIR"
        exit 1
    fi
    
    # 显示备份列表
    list_backups
    
    # 选择模式
    echo "请选择还原模式："
    echo "  [1] 交互式选择备份（推荐）"
    echo "  [2] 自动选择最新备份"
    echo "  [3] 取消"
    echo ""
    read -p "请输入选项 [1-3]: " mode
    
    local workspace_backup=""
    local config_backup=""
    
    case $mode in
        1)
            echo ""
            read -p "请选择 Workspace 备份序号: " ws_idx
            workspace_backup=$(grep "^${ws_idx}|" "$TEMP_DIR/workspace_map.txt" | cut -d'|' -f2)
            
            if [ -z "$workspace_backup" ]; then
                echo "❌ 无效的 Workspace 备份序号"
                exit 1
            fi
            
            # 尝试自动匹配同批次 config
            local matched_config=$(auto_match_backup "$workspace_backup")
            if [ -n "$matched_config" ]; then
                echo "✅ 自动匹配到 Config 备份: $(basename "$matched_config")"
                read -p "是否使用该配置? [Y/n]: " use_matched
                if [[ "$use_matched" =~ ^[Nn]$ ]]; then
                    read -p "请选择 Config 备份序号: " cfg_idx
                    config_backup=$(grep "^${cfg_idx}|" "$TEMP_DIR/config_map.txt" | cut -d'|' -f2)
                else
                    config_backup="$matched_config"
                fi
            else
                read -p "请选择 Config 备份序号: " cfg_idx
                config_backup=$(grep "^${cfg_idx}|" "$TEMP_DIR/config_map.txt" | cut -d'|' -f2)
            fi
            ;;
        2)
            workspace_backup=$(ls -1t "$BACKUP_DIR"/*workspace*.tar.gz 2>/dev/null | head -1)
            config_backup=$(ls -1t "$BACKUP_DIR"/*config*.tar.gz 2>/dev/null | head -1)
            
            echo ""
            echo "将还原以下最新备份："
            echo "  Workspace: $(basename "$workspace_backup")"
            echo "  Config: $(basename "$config_backup")"
            echo ""
            ;;
        3)
            echo "已取消"
            exit 0
            ;;
        *)
            echo "❌ 无效选项"
            exit 1
            ;;
    esac
    
    # 确认
    if [ ! -f "$workspace_backup" ] || [ ! -f "$config_backup" ]; then
        echo "❌ 备份文件不存在"
        exit 1
    fi
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  ⚠️  警告：还原将覆盖当前 OpenClaw 的所有数据！          ║"
    echo "║                                                          ║"
    echo "║  当前 session、配置、记忆文件将被替换为备份版本          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "备份文件："
    echo "  Workspace: $(basename "$workspace_backup")"
    echo "  Config: $(basename "$config_backup")"
    echo ""
    read -p "确认继续? 输入 'RESTORE' 确认: " confirm
    
    if [ "$confirm" != "RESTORE" ]; then
        echo "已取消还原"
        exit 0
    fi
    
    # 执行还原
    create_emergency_backup
    restore_workspace "$workspace_backup"
    restore_config "$config_backup"
    verify_restore
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "后续步骤："
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "1. 重启 OpenClaw gateway 以应用配置更改："
    echo "   $(dirname $0)/oc-start.sh"
    echo ""
    echo "2. 如需回滚，紧急备份位于："
    echo "   $BACKUP_DIR/emergency-*-before-restore-*.tar.gz"
    echo ""
}

# 运行
main "$@"
