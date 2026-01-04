#!/bin/bash

# ================================================================
# 博客自动更新脚本（阿里云服务器版）
# 功能：每周从 GitHub main 分支拉取最新代码并重新构建
# ================================================================

set -e

# ================================================================
# 配置加载
# ================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-config.sh"

# 如果配置文件不存在，使用默认值
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "[WARN] 配置文件不存在: $CONFIG_FILE，使用默认值"
    GITHUB_REPO="snote845/snote845.github.io"
    GITHUB_BRANCH="main"
    DEPLOY_DIR="/var/www/blog"
    WEB_USER="nginx"
    UPDATE_LOG_FILE="/var/log/blog-update.log"
    LOCK_FILE="/var/run/blog-update.lock"
fi

# ================================================================
# 日志函数
# ================================================================
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg"
    [ -n "$UPDATE_LOG_FILE" ] && echo "$msg" >> "$UPDATE_LOG_FILE"
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo "$msg" >&2
    [ -n "$UPDATE_LOG_FILE" ] && echo "$msg" >> "$UPDATE_LOG_FILE"
}

log_info() {
    log "[INFO] $1"
}

log_success() {
    log "[SUCCESS] $1"
}

# ================================================================
# 锁文件检查
# ================================================================
check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
            log_error "更新脚本正在运行中（PID: $pid），跳过本次执行"
            exit 1
        else
            log "发现残留的锁文件，正在清理..."
            rm -f "$LOCK_FILE"
        fi
    fi

    # 创建锁文件
    echo $$ > "$LOCK_FILE"

    # 确保脚本退出时清理锁文件
    trap 'rm -f "$LOCK_FILE"' EXIT
}

# ================================================================
# 更新前检查
# ================================================================
pre_update_check() {
    log_info "执行更新前检查..."

    # 检查磁盘空间
    local disk_usage
    disk_usage=$(df "$DEPLOY_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        log_error "磁盘空间不足（使用率: ${disk_usage}%），停止更新"
        exit 1
    fi
    log "磁盘空间使用率: ${disk_usage}% - 正常"

    # 执行自定义的更新前脚本（如果配置了）
    if [ -n "$PRE_UPDATE_SCRIPT" ] && [ -x "$PRE_UPDATE_SCRIPT" ]; then
        log_info "执行自定义更新前脚本: $PRE_UPDATE_SCRIPT"
        "$PRE_UPDATE_SCRIPT" || {
            log_error "更新前脚本执行失败"
            exit 1
        }
    fi
}

# ================================================================
# 拉取最新代码
# ================================================================
pull_latest_code() {
    log_info "从 GitHub 拉取最新代码（分支: $GITHUB_BRANCH）..."

    cd "$DEPLOY_DIR" || {
        log_error "无法进入部署目录: $DEPLOY_DIR"
        exit 1
    }

    # 记录当前 commit hash
    local old_commit
    old_commit=$(git rev-parse HEAD)

    # 拉取最新代码
    git fetch origin "$GITHUB_BRANCH" || {
        log_error "Git fetch 失败"
        exit 1
    }

    # 检查是否有更新
    local new_commit
    new_commit=$(git rev-parse origin/"$GITHUB_BRANCH")

    if [ "$old_commit" = "$new_commit" ]; then
        log "没有新的更新，当前已是最新版本"
        exit 0
    fi

    log_info "发现新版本，正在更新..."
    log "旧版本: $old_commit"
    log "新版本: $new_commit"

    # 切换到最新的 commit
    git checkout -f "$new_commit" || {
        log_error "Git checkout 失败"
        exit 1
    }

    log_success "代码已更新到最新版本"
}

# ================================================================
# 安装/更新依赖
# ================================================================
install_dependencies() {
    log_info "检查并安装 Ruby 依赖..."

    cd "$DEPLOY_DIR" || exit 1

    # 使用 bundle install 安装依赖
    if bundle install ${BUNDLE_INSTALL_FLAGS:---without development} >> "$UPDATE_LOG_FILE" 2>&1; then
        log_success "依赖安装完成"
    else
        log_error "依赖安装失败"
        exit 1
    fi
}

# ================================================================
# 构建网站
# ================================================================
build_site() {
    log_info "开始构建网站..."

    cd "$DEPLOY_DIR" || exit 1

    # 执行自定义的构建前脚本（如果配置了）
    if [ -n "$PRE_BUILD_SCRIPT" ] && [ -x "$PRE_BUILD_SCRIPT" ]; then
        log_info "执行自定义构建前脚本: $PRE_BUILD_SCRIPT"
        "$PRE_BUILD_SCRIPT" || {
            log_error "构建前脚本执行失败"
            exit 1
        }
    fi

    # 使用生产环境变量构建
    export JEKYLL_ENV=${JEKYLL_ENV:-production}

    if bundle exec jekyll build >> "$UPDATE_LOG_FILE" 2>&1; then
        log_success "网站构建完成"
    else
        log_error "网站构建失败，查看日志: $UPDATE_LOG_FILE"
        exit 1
    fi

    # 执行自定义的构建后脚本（如果配置了）
    if [ -n "$POST_BUILD_SCRIPT" ] && [ -x "$POST_BUILD_SCRIPT" ]; then
        log_info "执行自定义构建后脚本: $POST_BUILD_SCRIPT"
        "$POST_BUILD_SCRIPT" || {
            log_error "构建后脚本执行失败"
            exit 1
        }
    fi
}

# ================================================================
# 设置文件权限
# ================================================================
set_permissions() {
    log_info "设置文件权限..."

    # 确保 _site 目录属于 Web 用户
    chown -R "${WEB_USER}:${WEB_GROUP}" "$DEPLOY_DIR/_site" || {
        log_error "无法设置文件权限"
        exit 1
    }

    # 设置正确的文件权限
    find "$DEPLOY_DIR/_site" -type d -exec chmod 755 {} \;
    find "$DEPLOY_DIR/_site" -type f -exec chmod 644 {} \;

    log_success "文件权限设置完成"
}

# ================================================================
# 重载 Nginx（如果需要）
# ================================================================
reload_nginx() {
    if command -v nginx &> /dev/null; then
        log_info "测试 Nginx 配置..."
        if nginx -t >> "$UPDATE_LOG_FILE" 2>&1; then
            log_info "重载 Nginx..."
            nginx -s reload || log_error "Nginx 重载失败"
        else
            log_error "Nginx 配置测试失败，跳过重载"
        fi
    fi
}

# ================================================================
# 健康检查
# ================================================================
health_check() {
    if [ "${HEALTH_CHECK_ENABLED:-false}" = "true" ]; then
        log_info "执行健康检查..."

        local url="${HEALTH_CHECK_URL:-http://localhost}"
        local response
        response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

        if [ "$response" = "200" ]; then
            log_success "健康检查通过 (HTTP $response)"
        else
            log_error "健康检查失败 (HTTP $response)"
            return 1
        fi
    fi
}

# ================================================================
# 发送通知
# ================================================================
send_notification() {
    local status="$1"
    local message="$2"

    # Webhook 通知
    if [ -n "$WEBHOOK_URL" ]; then
        log_info "发送 Webhook 通知..."
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"status\": \"$status\", \"message\": \"$message\", \"timestamp\": \"$(date -Iseconds)\"}" \
            >> "$UPDATE_LOG_FILE" 2>&1
    fi

    # Slack 通知
    if [ "${ENABLE_SLACK_NOTIFICATION:-false}" = "true" ] && [ -n "$SLACK_WEBHOOK_URL" ]; then
        log_info "发送 Slack 通知..."
        curl -X POST "$SLACK_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"$status: $message\"}" \
            >> "$UPDATE_LOG_FILE" 2>&1
    fi
}

# ================================================================
# 备份（可选）
# ================================================================
backup_site() {
    if [ "${BACKUP_ENABLED:-false}" = "true" ]; then
        log_info "创建备份..."

        local backup_dir="${BACKUP_DIR:-/var/backups/blog}"
        local retention_days="${BACKUP_RETENTION_DAYS:-30}"

        mkdir -p "$backup_dir"

        local backup_file="$backup_dir/blog-$(date +%Y%m%d-%H%M%S).tar.gz"

        if tar -czf "$backup_file" -C "$DEPLOY_DIR" _site >> "$UPDATE_LOG_FILE" 2>&1; then
            log_success "备份创建成功: $backup_file"

            # 清理旧备份
            find "$backup_dir" -name "blog-*.tar.gz" -mtime +$retention_days -delete
            log "已清理 $retention_days 天前的旧备份"
        else
            log_error "备份创建失败"
        fi
    fi
}

# ================================================================
# 主函数
# ================================================================
main() {
    log "=================================================="
    log "博客自动更新开始"
    log "=================================================="

    check_lock
    pre_update_check

    # 创建备份（如果启用）
    backup_site

    # 执行更新流程
    pull_latest_code
    install_dependencies
    build_site
    set_permissions
    reload_nginx

    # 健康检查
    if health_check; then
        log_success "博客更新完成并正常运行"
        send_notification "success" "博客已成功更新到最新版本"
    else
        log_error "博客更新后健康检查失败"
        send_notification "error" "博客更新后健康检查失败，请检查日志"
        exit 1
    fi

    # 执行自定义的更新后脚本（如果配置了）
    if [ -n "$POST_UPDATE_SCRIPT" ] && [ -x "$POST_UPDATE_SCRIPT" ]; then
        log_info "执行自定义更新后脚本: $POST_UPDATE_SCRIPT"
        "$POST_UPDATE_SCRIPT" || log_error "更新后脚本执行失败"
    fi

    log "=================================================="
    log "更新流程完成"
    log "=================================================="
}

# 运行主函数
main "$@"
