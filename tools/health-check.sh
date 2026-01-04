#!/bin/bash

# ================================================================
# 博客健康检查脚本
# 功能：检查博客网站的可用性、性能和配置
# ================================================================

# 配置
SITE_URL="${SITE_URL:-http://localhost:4000}"
TIMEOUT=10
MAX_SIZE_MB=100  # 最大文件大小限制（MB）

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 统计
checks_passed=0
checks_failed=0
checks_warned=0

# 日志函数
log_pass() {
    echo -e "${GREEN}[✓]${NC} $1"
    ((checks_passed++))
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    ((checks_warned++))
}

log_fail() {
    echo -e "${RED}[✗]${NC} $1"
    ((checks_failed++))
}

log_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# 检查网站可访问性
check_website() {
    echo -e "\n${BLUE}=== 网站可访问性检查 ===${NC}"

    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$SITE_URL" 2>/dev/null)

    if [ "$response" = "200" ]; then
        log_pass "网站可访问 (HTTP $response)"
    elif [ -n "$response" ]; then
        log_fail "网站返回错误状态码: HTTP $response"
    else
        log_fail "网站无法访问"
    fi
}

# 检查 SSL 证书（HTTPS）
check_ssl() {
    echo -e "\n${BLUE}=== SSL 证书检查 ===${NC}"

    if [[ "$SITE_URL" =~ ^https:// ]]; then
        local domain
        domain=$(echo "$SITE_URL" | sed 's|https://||' | sed 's|/.*||')

        if echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | grep -q "Verify return code"; then
            log_pass "SSL 证书有效"
        else
            log_fail "SSL 证书无效或即将过期"
        fi
    else
        log_warn "未使用 HTTPS"
    fi
}

# 检查关键文件
check_files() {
    echo -e "\n${BLUE}=== 文件结构检查 ===${NC}"

    local required_files=(
        "_config.yml"
        "_data/locales/zh-CN.yml"
        "robots.txt"
        ".editorconfig"
    )

    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            log_pass "文件存在: $file"
        else
            log_fail "文件缺失: $file"
        fi
    done
}

# 检查文章质量
check_posts() {
    echo -e "\n${BLUE}=== 文章质量检查 ===${NC}"

    local total_posts=0
    local with_excerpt=0
    local with_images=0

    while IFS= read -r -d '' file; do
        ((total_posts++)) || true

        # 检查摘要
        if grep -q "^excerpt:" "$file"; then
            ((with_excerpt++)) || true
        fi

        # 检查图片
        if grep -q "!\[.*\](" "$file"; then
            ((with_images++)) || true
        fi
    done < <(find _posts -type f -name "*.md" -print0)

    if [ $total_posts -gt 0 ]; then
        local excerpt_percent=$((with_excerpt * 100 / total_posts))
        local images_percent=$((with_images * 100 / total_posts))

        log_info "总文章数: $total_posts"
        log_info "有摘要: $with_excerpt ($excerpt_percent%)"

        if [ $excerpt_percent -lt 50 ]; then
            log_warn "超过一半的文章缺少摘要"
        else
            log_pass "文章摘要覆盖率良好"
        fi

        log_info "有图片: $with_images ($images_percent%)"

        if [ $images_percent -lt 20 ]; then
            log_warn "文章图片覆盖率较低"
        else
            log_pass "文章图片覆盖率良好"
        fi
    else
        log_warn "未找到文章"
    fi
}

# 检查配置
check_config() {
    echo -e "\n${BLUE}=== 配置检查 ===${NC}"

    # 检查语言配置
    if grep -q "^lang: zh-CN" _config.yml; then
        log_pass "语言配置正确 (zh-CN)"
    else
        log_warn "语言配置可能不正确"
    fi

    # 检查 URL 配置
    if grep -q "^url:.*https" _config.yml; then
        log_pass "URL 配置正确 (HTTPS)"
    else
        log_fail "URL 配置可能不正确"
    fi

    # 检查 PWA 配置
    if grep -q "^pwa:" _config.yml && grep -A2 "^pwa:" _config.yml | grep -q "enabled: true"; then
        log_pass "PWA 已启用"
    else
        log_warn "PWA 未启用"
    fi

    # 检查评论配置
    if grep -q "^comments:" _config.yml && grep -A2 "^comments:" _config.yml | grep -q "provider:"; then
        log_pass "评论系统已配置"
    else
        log_warn "评论系统未配置"
    fi
}

# 检查磁盘空间
check_disk() {
    echo -e "\n${BLUE}=== 磁盘空间检查 ===${NC}"

    local usage
    usage=$(df . | tail -1 | awk '{print $5}' | sed 's/%//')

    log_info "磁盘使用率: ${usage}%"

    if [ "$usage" -lt 70 ]; then
        log_pass "磁盘空间充足"
    elif [ "$usage" -lt 85 ]; then
        log_warn "磁盘使用率较高"
    else
        log_fail "磁盘空间不足"
    fi
}

# 检查构建状态
check_build() {
    echo -e "\n${BLUE}=== 构建检查 ===${NC}"

    if [ -d "_site" ]; then
        log_pass "构建目录存在"

        # 检查关键输出文件
        local output_files=(
            "_site/index.html"
            "_site/sitemap.xml"
            "_site/feed.xml"
            "_site/assets/js/data/search.json"
        )

        for file in "${output_files[@]}"; do
            if [ -f "$file" ]; then
                log_pass "构建输出: $(basename $file)"
            else
                log_fail "构建缺失: $(basename $file)"
            fi
        done
    else
        log_fail "构建目录不存在，请运行 'jekyll build'"
    fi
}

# 主函数
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   博客健康检查${NC}"
    echo -e "${BLUE}   网址: $SITE_URL${NC}"
    echo -e "${BLUE}========================================${NC}"

    check_disk
    check_files
    check_config
    check_posts
    check_build
    check_website
    check_ssl

    # 输出总结
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}   检查总结${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}[✓] 通过: $checks_passed${NC}"
    echo -e "${YELLOW}[⚠] 警告: $checks_warned${NC}"
    echo -e "${RED}[✗] 失败: $checks_failed${NC}"
    echo -e "${BLUE}========================================${NC}"

    if [ $checks_failed -gt 0 ]; then
        exit 1
    fi
}

main
