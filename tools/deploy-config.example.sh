#!/bin/bash
# ================================================================
# 阿里云服务器部署配置文件
# ================================================================
# 重要提示：
# 1. 复制此文件为 deploy-config.sh（已在 .gitignore 中）
# 2. 填写您的实际配置信息
# 3. deploy-config.sh 包含敏感信息，不会被提交到 Git
# ================================================================

# ================================================================
# GitHub 仓库配置
# ================================================================
export GITHUB_REPO="YOUR_USERNAME/YOUR_REPO"
export GITHUB_BRANCH="main"  # 从 main 分支拉取
export GITHUB_URL="https://github.com/${GITHUB_REPO}.git"

# ================================================================
# 服务器部署配置
# ================================================================
export DEPLOY_DIR="/var/www/blog"           # 网站部署目录

# Web 运行用户（根据操作系统自动检测）
# Ubuntu/Debian: www-data
# CentOS/RHEL: nginx
# 如果为空，脚本会自动检测
export WEB_USER=""                          # 留空自动检测，或手动指定
export WEB_GROUP=""                         # 留空自动检测，或手动指定

# ================================================================
# 域名配置
# ================================================================
export DOMAIN_NAME="your-domain.com"        # 主域名
export SERVER_NAME="www.your-domain.com your-domain.com"  # Nginx server_name

# ================================================================
# 服务器连接配置
# ================================================================
export SERVER_HOST="YOUR_SERVER_IP"          # 公网 IP
export SERVER_USER="root"                    # SSH 登录用户
export SERVER_PORT="22"                      # SSH 端口

# ================================================================
# 私有网络配置（可选，用于内网通信）
# ================================================================
export PRIVATE_IP="YOUR_PRIVATE_IP"           # 私有 IP

# ================================================================
# 自动更新配置
# ================================================================
export AUTO_UPDATE_ENABLED="true"           # 是否启用自动更新
export AUTO_UPDATE_SCHEDULE="0 2 * * 1"     # 每周一凌晨 2 点
export UPDATE_LOG_FILE="/var/log/blog-update.log"
export LOCK_FILE="/var/run/blog-update.lock"

# ================================================================
# SSL/HTTPS 配置
# ================================================================
export SSL_ENABLED="true"                    # 是否启用 HTTPS
export SSL_CERT_PATH="/etc/nginx/ssl/${DOMAIN_NAME}.crt"
export SSL_KEY_PATH="/etc/nginx/ssl/${DOMAIN_NAME}.key"
export LETS_ENCRYPT_EMAIL="your-email@example.com"  # Let's Encrypt 证书邮箱

# ================================================================
# Nginx 配置
# ================================================================
export NGINX_SITE_CONF="/etc/nginx/conf.d/blog.conf"
export NGINX_PORT="80"                       # HTTP 端口
export NGINX_SSL_PORT="443"                  # HTTPS 端口

# ================================================================
# Jekyll 配置
# ================================================================
export JEKYLL_ENV="production"
export BUNDLE_INSTALL_FLAGS="--without development"

# ================================================================
# 通知配置（可选）
# ================================================================
export WEBHOOK_URL=""                        # Webhook 通知 URL
export NOTIFICATION_EMAIL=""                 # 通知邮箱
export ENABLE_SLACK_NOTIFICATION="false"
export SLACK_WEBHOOK_URL=""

# ================================================================
# 备份配置（可选）
# ================================================================
export BACKUP_ENABLED="true"
export BACKUP_DIR="/var/backups/blog"
export BACKUP_RETENTION_DAYS="30"

# ================================================================
# 监控配置（可选）
# ================================================================
export HEALTH_CHECK_ENABLED="true"
export HEALTH_CHECK_URL="http://localhost"
export HEALTH_CHECK_INTERVAL="60"            # 健康检查间隔（秒）

# ================================================================
# 性能优化配置
# ================================================================
export ENABLE_GZIP="true"                    # 启用 Gzip 压缩
export ENABLE_Brotli="false"                 # 启用 Brotli 压缩
export CACHE_STATIC_ENABLED="true"           # 启用静态资源缓存
export CACHE_MAX_AGE="30d"                   # 缓存时间

# ================================================================
# 安全配置
# ================================================================
export ENABLE_SECURITY_HEADERS="true"        # 启用安全头
export HSTS_ENABLED="true"                   # 启用 HSTS
export ENABLE_CSP="false"                    # 启用内容安全策略

# ================================================================
# 自定义脚本路径
# ================================================================
export PRE_UPDATE_SCRIPT=""                  # 更新前执行的脚本
export POST_UPDATE_SCRIPT=""                 # 更新后执行的脚本
export PRE_BUILD_SCRIPT=""                   # 构建前执行的脚本
export POST_BUILD_SCRIPT=""                  # 构建后执行的脚本
