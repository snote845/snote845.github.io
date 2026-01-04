#!/bin/bash

# ================================================================
# 图片优化脚本
# 功能：批量转换图片为 WebP 格式并压缩
# 依赖：cwebp (webp), mozjpeg (jpegoptim), pngquant (可选)
# ================================================================

# 配置
ASSETS_DIR="assets"
QUALITY=80  # WebP 质量 (0-100)
BACKUP=true  # 是否备份原图

# 统计
count_total=0
count_converted=0
count_skipped=0

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    local missing=()

    if ! command -v cwebp &> /dev/null; then
        missing+=("cwebp (webp)")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "缺少依赖: ${missing[*]}"
        echo
        echo "安装方法："
        echo "  macOS: brew install webp"
        echo "  Ubuntu/Debian: sudo apt install webp"
        echo "  CentOS/RHEL: sudo yum install libwebp-tools"
        exit 1
    fi
}

# 转换单个图片
convert_image() {
    local file="$1"
    local filename
    filename=$(basename "$file")

    ((count_total++)) || true

    # 检查是否已是 WebP
    if [[ "$file" =~ \.webp$ ]]; then
        ((count_skipped++)) || true
        return
    fi

    # 生成 WebP 文件路径
    local webp_file="${file%.*}.webp"

    # 如果 WebP 已存在且较新，跳过
    if [ -f "$webp_file" ] && [ "$webp_file" -nt "$file" ]; then
        ((count_skipped++)) || true
        return
    fi

    log_info "转换: $filename"

    # 转换为 WebP
    if cwebp -q "$QUALITY" "$file" -o "$webp_file" 2>/dev/null; then
        # 显示文件大小对比
        local original_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        local webp_size=$(stat -f%z "$webp_file" 2>/dev/null || stat -c%s "$webp_file" 2>/dev/null)
        local savings=$((100 - (webp_size * 100 / original_size)))

        echo "  原始: $(numfmt --to=iec --suffix=B $original_size 2>/dev/null || echo ${original_size}B)"
        echo "  WebP: $(numfmt --to=iec --suffix=B $webp_size 2>/dev/null || echo ${webp_size}B) (节省 ${savings}%)"

        ((count_converted++)) || true

        # 可选：删除原图
        if [ "$BACKUP" = false ]; then
            rm "$file"
            log_warn "已删除原图: $filename"
        fi
    else
        log_error "转换失败: $filename"
    fi
}

# 主函数
main() {
    log_info "图片优化开始..."
    log_info "质量: $QUALITY"
    log_info "目录: $ASSETS_DIR"
    echo

    check_dependencies

    # 查找所有图片文件
    local file
    while IFS= read -r -d '' file; do
        # 跳过 WebP 文件（会由原文件转换）
        if [[ ! "$file" =~ \.webp$ ]]; then
            convert_image "$file"
            echo
        fi
    done < <(find "$ASSETS_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) -print0)

    # 输出统计
    echo "==============================================="
    log_info "优化完成！"
    echo "总计图片: $count_total"
    echo -e "${GREEN}已转换: $count_converted${NC}"
    echo -e "${YELLOW}已跳过: $count_skipped${NC}"
    echo "==============================================="
}

main
