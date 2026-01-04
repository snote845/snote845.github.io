#!/bin/bash
# ================================================================
# 本地开发调试脚本
# 用途：本地运行 Jekyll 开发服务器进行调试
# ================================================================

set -e

# 配置
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-4000}"
PROD=false
LIVE_RELOAD=true

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 帮助信息
show_help() {
    echo -e "${BLUE}本地开发调试脚本${NC}"
    echo
    echo "用法:"
    echo "  bash $0 [选项]"
    echo
    echo "选项:"
    echo "  -p, --port PORT      端口（默认: 4000）"
    echo "  -H, --host HOST      主机（默认: 127.0.0.1）"
    echo "  -P, --production     生产模式构建"
    echo "  -l, --livereload     启用实时重载（默认）"
    echo "  -h, --help           显示此帮助信息"
    echo
    echo "示例:"
    echo "  bash $0                    # 开发模式（默认）"
    echo "  bash $0 -p 4001            # 指定端口"
    echo "  bash $0 -P                 # 生产模式构建"
    echo
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -H|--host)
            HOST="$2"
            shift 2
            ;;
        -P|--production)
            PROD=true
            shift
            ;;
        -l|--livereload)
            LIVE_RELOAD=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${YELLOW}未知选项: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 检查依赖
check_dependencies() {
    echo -e "${GREEN}检查依赖...${NC}"

    if ! command -v bundle &> /dev/null; then
        echo "错误: 未安装 bundler"
        echo "请运行: gem install bundler"
        exit 1
    fi

    if ! command -v ruby &> /dev/null; then
        echo "错误: 未安装 ruby"
        exit 1
    fi

    echo "依赖检查完成 ✓"
}

# 安装 gems
install_gems() {
    echo -e "${GREEN}安装/更新 gems...${NC}"
    bundle install
}

# 开发模式运行
run_dev() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  启动 Jekyll 开发服务器${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "主机: $HOST"
    echo -e "端口: $PORT"
    echo -e "模式: 开发"
    echo -e "URL:  http://$HOST:$PORT"
    echo -e "${BLUE}========================================${NC}"
    echo

    bundle exec jekyll serve \
        --host "$HOST" \
        --port "$PORT" \
        --livereload \
        --incremental
}

# 生产模式构建
run_prod() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  生产模式构建${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo

    # 清理旧构建
    echo -e "${YELLOW}清理旧构建...${NC}"
    rm -rf _site .jekyll-cache

    # 构建
    echo -e "${GREEN}开始构建...${NC}"
    JEKYLL_ENV=production bundle exec jekyll build

    echo
    echo -e "${GREEN}构建完成！${NC}"
    echo -e "构建产物: _site/"
    echo
    echo -e "${BLUE}========================================${NC}"
}

# 主函数
main() {
    check_dependencies
    install_gems

    if [ "$PROD" = true ]; then
        run_prod
    else
        run_dev
    fi
}

main
