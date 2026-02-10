#!/bin/bash

# 快速创建新博客文章脚本
# 使用方法: ./tools/new-post.sh

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POSTS_DIR="$PROJECT_ROOT/_posts"

# 获取当前日期和时间
CURRENT_DATE=$(date +"%Y-%m-%d")
CURRENT_TIME=$(date +"%H:%M:%S")
# 文件名时间戳 (用于同一天创建多篇文章时避免重名)
TIME_STAMP=$(date +"%H%M%S")

echo -e "${GREEN}=== 创建新博客文章 ===${NC}"
echo ""

# 输入文章标题
read -p "请输入文章标题: " TITLE
if [ -z "$TITLE" ]; then
    echo "标题不能为空！"
    exit 1
fi

# 输入分类
read -p "请输入文章分类 (如: iOS, Android, Unity, 多个分类用逗号分隔): " CATEGORY_INPUT
if [ -z "$CATEGORY_INPUT" ]; then
    echo "分类不能为空！"
    exit 1
fi

# 处理分类数组
IFS=',' read -ra CATEGORIES <<< "$CATEGORY_INPUT"
PRIMARY_CATEGORY="${CATEGORIES[0]}"
CATEGORY_DIR="$POSTS_DIR/$PRIMARY_CATEGORY"

# 创建分类目录
mkdir -p "$CATEGORY_DIR"

# 输入标签
read -p "请输入文章标签 (多个标签用逗号或空格分隔): " TAGS_INPUT
if [ -z "$TAGS_INPUT" ]; then
    TAGS="[$PRIMARY_CATEGORY]"
else
    # 处理标签，替换空格为逗号
    TAGS_INPUT=$(echo "$TAGS_INPUT" | tr ' ' ',')
    IFS=',' read -ra TAG_ARRAY <<< "$TAGS_INPUT"
    TAGS="["
    first=true
    for tag in "${TAG_ARRAY[@]}"; do
        if [ "$first" = true ]; then
            TAGS+="$tag"
            first=false
        else
            TAGS+=", $tag"
        fi
    done
    TAGS+="]"
fi

# 构建分类 YAML
CATEGORIES_YAML="["
first=true
for cat in "${CATEGORIES[@]}"; do
    cat=$(echo "$cat" | xargs) # 去除空格
    if [ "$first" = true ]; then
        CATEGORIES_YAML+="$cat"
        first=false
    else
        CATEGORIES_YAML+=", $cat"
    fi
done
CATEGORIES_YAML+="]"

# 生成文件名 (YYYY-MM-DD-HHMMSS-title.md)
SLUG=$(echo "$TITLE" | sed 's/[^a-zA-Z0-9\u4e00-\u9fa5]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
FILE_NAME="${CURRENT_DATE}-${TIME_STAMP}-${SLUG}.md"
FILE_PATH="$CATEGORY_DIR/$FILE_NAME"

# 检查文件是否已存在
if [ -f "$FILE_PATH" ]; then
    echo -e "${YELLOW}警告: 文件已存在: $FILE_PATH${NC}"
    read -p "是否覆盖? (y/N): " OVERWRITE
    if [ "$OVERWRITE" != "y" ] && [ "$OVERWRITE" != "Y" ]; then
        echo "已取消"
        exit 0
    fi
fi

# 生成文章内容
cat > "$FILE_PATH" << EOF
---
excerpt: ###
layout: post
title: "${TITLE}"
date: ${CURRENT_DATE} ${CURRENT_TIME} +0800
categories: ${CATEGORIES_YAML}
tags: ${TAGS}
---


EOF

echo ""
echo -e "${GREEN}✓ 文章创建成功！${NC}"
echo "  路径: $FILE_PATH"
echo ""

# 询问是否在编辑器中打开
read -p "是否在编辑器中打开? (Y/n): " OPEN_EDITOR
if [ "$OPEN_EDITOR" != "n" ] && [ "$OPEN_EDITOR" != "N" ]; then
    # 尝试使用 VSCode
    if command -v code &> /dev/null; then
        code "$FILE_PATH"
    elif command -v vim &> /dev/null; then
        vim "$FILE_PATH"
    else
        echo "请手动打开文件: $FILE_PATH"
    fi
fi

echo ""
echo -e "${GREEN}开始写作吧！${NC}"
