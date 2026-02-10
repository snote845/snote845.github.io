#!/bin/bash

# Jekyll 博客自动部署脚本
# 用于在阿里云服务器上部署和配置博客

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数（先定义，以便后续使用）
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-config.sh"

# 配置变量 - 默认值
GITHUB_REPO="snote845/snote845.github.io"
GITHUB_BRANCH="develop"  # 或 "main"
DEPLOY_DIR="/var/www/blog"
WEB_USER="www-data"  # 根据系统调整，CentOS 使用 nginx，Ubuntu 使用 www-data
DOMAIN_NAME=""  # 你的域名，例如 blog.example.com

# 从配置文件加载配置（如果存在）
if [ -f "$CONFIG_FILE" ]; then
    log_info "从配置文件加载设置: $CONFIG_FILE"
    source "$CONFIG_FILE"
fi

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "请使用 root 权限运行此脚本"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        log_info "检测到操作系统: $OS $OS_VERSION"
    else
        log_error "无法检测操作系统"
        exit 1
    fi

    # 自动检测 Web 用户（如果配置文件中未指定）
    if [ -z "$WEB_USER" ]; then
        if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
            WEB_USER="www-data"
            WEB_GROUP="www-data"
            log_info "自动设置 Web 用户: www-data (Ubuntu/Debian)"
        elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "almalinux" ] || [ "$OS" = "rocky" ]; then
            WEB_USER="nginx"
            WEB_GROUP="nginx"
            log_info "自动设置 Web 用户: nginx (CentOS/RHEL)"
        else
            # 默认使用 www-data
            WEB_USER="www-data"
            WEB_GROUP="www-data"
            log_warn "未知操作系统，默认使用 Web 用户: www-data"
        fi
    fi

    # 验证用户是否存在
    if ! id "$WEB_USER" &>/dev/null; then
        log_error "用户 $WEB_USER 不存在"
        log_error "请在配置文件中设置正确的 WEB_USER"
        exit 1
    fi

    log_info "Web 运行用户: $WEB_USER"
}

# 安装依赖
install_dependencies() {
    log_info "开始安装依赖..."
    
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        apt-get update
        apt-get install -y git curl build-essential ruby-full ruby-dev zlib1g-dev \
            nginx bundler nodejs npm
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
        yum install -y git curl gcc gcc-c++ make ruby ruby-devel zlib-devel \
            nginx nodejs npm
        gem install bundler
    else
        log_error "不支持的操作系统: $OS"
        exit 1
    fi
    
    log_info "依赖安装完成"
}

# 配置 SSH 密钥
setup_ssh_key() {
    log_info "配置 SSH 密钥..."
    
    SSH_DIR="$HOME/.ssh"
    if [ ! -d "$SSH_DIR" ]; then
        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
    fi
    
    # 检查是否已有 SSH 密钥
    if [ ! -f "$SSH_DIR/id_rsa" ]; then
        log_warn "未找到 SSH 密钥，正在生成..."
        ssh-keygen -t rsa -b 4096 -C "deploy@$(hostname)" -f "$SSH_DIR/id_rsa" -N ""
        log_info "SSH 公钥已生成:"
        cat "$SSH_DIR/id_rsa.pub"
        log_warn "请将上述公钥添加到 GitHub: https://github.com/settings/keys"
        read -p "按回车键继续..."
    else
        log_info "SSH 密钥已存在"
    fi
    
    # 配置 SSH 以使用密钥
    if [ ! -f "$SSH_DIR/config" ]; then
        cat > "$SSH_DIR/config" << EOF
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
EOF
        chmod 600 "$SSH_DIR/config"
    fi
    
    log_info "SSH 配置完成"
}

# 克隆或更新仓库
setup_repository() {
    log_info "设置代码仓库..."
    
    if [ ! -d "$DEPLOY_DIR" ]; then
        mkdir -p "$DEPLOY_DIR"
        log_info "克隆仓库..."
        git clone -b "$GITHUB_BRANCH" "git@github.com:$GITHUB_REPO.git" "$DEPLOY_DIR"
    else
        log_info "仓库已存在，跳过克隆"
    fi
    
    # 设置正确的权限
    chown -R "$WEB_USER:$WEB_USER" "$DEPLOY_DIR"
    log_info "代码仓库设置完成"
}

# 安装 Jekyll 依赖
install_jekyll() {
    log_info "安装 Jekyll 和依赖..."

    cd "$DEPLOY_DIR"

    # 生成 Gemfile.lock（如果不存在）
    if [ ! -f "Gemfile.lock" ]; then
        log_info "生成 Gemfile.lock..."
        bundle lock
    fi

    # 配置 bundle（替代废弃的 --deployment 标志）
    bundle config set --local deployment 'true'
    bundle config set --local without 'development test'

    # 以 web 用户身份安装依赖
    log_info "以 $WEB_USER 用户身份安装 gems..."
    sudo -u "$WEB_USER" bash << EOF
cd "$DEPLOY_DIR"
export HOME="\$HOME/.gem"
export PATH="\$HOME/bin:\$PATH"
bundle install
EOF

    log_info "Jekyll 依赖安装完成"
}

# 构建网站
build_site() {
    log_info "构建网站..."
    
    cd "$DEPLOY_DIR"
    
    # 切换到正确的用户
    sudo -u "$WEB_USER" bash << EOF
cd "$DEPLOY_DIR"
export PATH="\$HOME/.gem/ruby/*/bin:\$PATH"
bundle exec jekyll build
EOF
    
    log_info "网站构建完成"
}

# 配置 Nginx
configure_nginx() {
    log_info "配置 Nginx..."
    
    NGINX_CONFIG="/etc/nginx/sites-available/blog"
    
    # Ubuntu/Debian 使用 sites-available
    if [ -d "/etc/nginx/sites-available" ]; then
        cat > "$NGINX_CONFIG" << EOF
server {
    listen 80;
    server_name ${DOMAIN_NAME:-_};
    root $DEPLOY_DIR/_site;
    index index.html;

    # 日志
    access_log /var/log/nginx/blog_access.log;
    error_log /var/log/nginx/blog_error.log;

    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;

    # 静态文件缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # 主配置
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # 禁止访问隐藏文件
    location ~ /\. {
        deny all;
    }
}
EOF
        # 创建符号链接
        if [ ! -L "/etc/nginx/sites-enabled/blog" ]; then
            ln -s "$NGINX_CONFIG" /etc/nginx/sites-enabled/blog
        fi
    else
        # CentOS/RHEL 使用 conf.d
        cat > "/etc/nginx/conf.d/blog.conf" << EOF
server {
    listen 80;
    server_name ${DOMAIN_NAME:-_};
    root $DEPLOY_DIR/_site;
    index index.html;

    access_log /var/log/nginx/blog_access.log;
    error_log /var/log/nginx/blog_error.log;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;

    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location ~ /\. {
        deny all;
    }
}
EOF
    fi
    
    # 测试 Nginx 配置
    nginx -t
    
    # 启动并设置开机自启
    systemctl enable nginx
    systemctl restart nginx
    
    log_info "Nginx 配置完成"
}

# 设置自动更新脚本
setup_auto_update() {
    log_info "设置自动更新..."
    
    UPDATE_SCRIPT="/usr/local/bin/blog-update.sh"
    
    cat > "$UPDATE_SCRIPT" << 'SCRIPT_EOF'
#!/bin/bash
# 博客自动更新脚本

set -e

DEPLOY_DIR="/var/www/blog"
WEB_USER="www-data"
GITHUB_BRANCH="develop"
LOG_FILE="/var/log/blog-update.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "开始更新博客..."

cd "$DEPLOY_DIR"

# 切换到正确的用户执行
sudo -u "$WEB_USER" bash << EOF
cd "$DEPLOY_DIR"
git fetch origin
if [ \$(git rev-parse HEAD) != \$(git rev-parse origin/$GITHUB_BRANCH) ]; then
    log "检测到更新，开始拉取..."
    git pull origin $GITHUB_BRANCH
    export PATH="\$HOME/.gem/ruby/*/bin:\$PATH"
    bundle install --deployment --without development test
    bundle exec jekyll build
    log "更新完成"
else
    log "没有更新"
fi
EOF

log "更新脚本执行完成"
SCRIPT_EOF
    
    chmod +x "$UPDATE_SCRIPT"
    
    # 设置 cron 任务（每周一凌晨 2 点执行）
    CRON_JOB="0 2 * * 1 $UPDATE_SCRIPT"
    
    # 检查是否已存在
    (crontab -l 2>/dev/null | grep -v "$UPDATE_SCRIPT"; echo "$CRON_JOB") | crontab -
    
    log_info "自动更新已配置（每周一凌晨 2 点执行）"
    log_info "更新脚本位置: $UPDATE_SCRIPT"
    log_info "日志文件位置: /var/log/blog-update.log"
}

# 主函数
main() {
    log_info "开始部署 Jekyll 博客..."
    
    check_root
    detect_os
    install_dependencies
    setup_ssh_key
    setup_repository
    install_jekyll
    build_site
    configure_nginx
    setup_auto_update
    
    log_info "部署完成！"
    log_info "网站目录: $DEPLOY_DIR"
    log_info "网站文件: $DEPLOY_DIR/_site"
    log_warn "请确保已将 SSH 公钥添加到 GitHub"
    log_warn "如需配置 HTTPS，请使用 Let's Encrypt 或其他 SSL 证书"
}

# 执行主函数
main

