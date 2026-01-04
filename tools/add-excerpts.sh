#!/bin/bash

# ================================================================
# 文章摘要自动生成脚本
# 功能：为博客文章自动添加 excerpt 字段
# ================================================================

# 配置
POSTS_DIR="_posts"
IMPORTANT_CATS=("android" "unity")  # 需要手动编写摘要的分类
EXCERPT_LENGTH=150  # 摘要长度（字数）

# 统计变量
count_total=0
count_updated=0
count_skipped=0
count_important=0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查是否在项目根目录
if [ ! -d "$POSTS_DIR" ]; then
    echo "错误：未找到 _posts 目录，请在项目根目录运行此脚本"
    exit 1
fi

# 提取摘要函数
extract_excerpt() {
    local content="$1"
    local length="$2"

    # 移除代码块
    content=$(echo "$content" | sed '/^```$/,/^```$/d')

    # 移除标题
    content=$(echo "$content" | sed 's/^#\+ .*$/ /g')

    # 移除图片和链接
    content=$(echo "$content" | sed 's/!\[.*\](.*)//g' | sed 's/\[.*\](.*)//g')

    # 移除空行并连接
    content=$(echo "$content" | tr '\n' ' ' | sed 's/  */ /g')

    # 去除首尾空格
    content=$(echo "$content" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # 截取指定长度
    content=$(echo "$content" | cut -c1-"$length")

    # 添加省略号
    if [ ${#content} -ge "$length" ]; then
        content="${content}..."
    fi

    echo "$content"
}

# 处理单个文章
process_post() {
    local file="$1"
    local filename
    filename=$(basename "$file")

    ((count_total++)) || true

    # 检查文件是否是 Markdown
    if [[ ! "$file" =~ \.md$ ]]; then
        return
    fi

    # 检查是否已有 excerpt
    if grep -q "^excerpt:" "$file"; then
        log_warn "跳过 $filename（已有摘要）"
        ((count_skipped++)) || true
        return
    fi

    # 提取分类
    local category=""
    category=$(grep "^categories:" "$file" -A 3 | grep "^\s*-" | head -1 | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/"//g' | sed 's/,.*//' || echo "")

    # 检查是否是重要分类
    local is_important=false
    for cat in "${IMPORTANT_CATS[@]}"; do
        if [[ "$category" == "$cat" ]]; then
            is_important=true
            break
        fi
    done

    if [ "$is_important" = true ]; then
        log_warn "跳过 $filename（重要分类，建议手动编写摘要）"
        ((count_important++)) || true
        return
    fi

    # 提取文章正文（front matter 之后的内容）
    local content=""
    local in_front_matter=true

    while IFS= read -r line; do
        if [[ "$line" =~ ^---$ ]]; then
            if [ "$in_front_matter" = true ]; then
                in_front_matter=false
                continue
            fi
        fi

        if [ "$in_front_matter" = false ]; then
            content="$content"$'\n'"$line"
            # 只取前 1000 字符
            if [ ${#content} -gt 1000 ]; then
                break
            fi
        fi
    done < "$file"

    # 生成摘要
    local new_excerpt
    new_excerpt=$(extract_excerpt "$content" "$EXCERPT_LENGTH")

    if [ -z "$new_excerpt" ] || [ ${#new_excerpt} -lt 20 ]; then
        log_warn "跳过 $filename（无法生成有效摘要）"
        ((count_skipped++)) || true
        return
    fi

    # 更新文件
    log_info "处理 $filename"
    log_step "摘要: $new_excerpt"

    # 在 front matter 之后添加 excerpt
    local temp_file
    temp_file=$(mktemp)
    local front_matter_ended=false

    while IFS= read -r line; do
        echo "$line" >> "$temp_file"

        if [[ "$line" =~ ^---$ ]] && [ "$front_matter_ended" = false ]; then
            if grep -q "^---$" "$temp_file" | tail -n 1; then
                # 这是第二个 ---，在它之前插入 excerpt
                sed -i.bak '$ d' "$temp_file" 2>/dev/null || rm "${temp_file}.bak"
                echo "excerpt: $new_excerpt" >> "$temp_file"
                echo "---" >> "$temp_file"
                front_matter_ended=true
            fi
        fi
    done < "$file"

    # 替换原文件
    mv "$temp_file" "$file"
    ((count_updated++)) || true
}

# 主函数
main() {
    log_info "开始处理文章摘要..."
    log_info "重要分类（需手动编写摘要）: ${IMPORTANT_CATS[*]}"
    log_info "摘要长度: $EXCERPT_LENGTH 字"
    echo

    # 查找并处理所有 Markdown 文章
    local file
    while IFS= read -r -d '' file; do
        process_post "$file"
        echo
    done < <(find "$POSTS_DIR" -type f -name "*.md" -print0)

    # 输出统计
    echo "==============================================="
    log_info "处理完成！"
    echo "总计文章: $count_total"
    echo -e "${GREEN}已更新: $count_updated${NC}"
    echo -e "${YELLOW}需手动编写: $count_important${NC}"
    echo -e "${YELLOW}已跳过: $count_skipped${NC}"
    echo "==============================================="

    if [ "$count_important" -gt 0 ]; then
        echo
        log_warn "建议为以下分类的文章手动编写摘要："
        for cat in "${IMPORTANT_CATS[@]}"; do
            echo "  - $cat"
        done
    fi
}

# 运行主函数
main
