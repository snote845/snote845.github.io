# 快速创建新文章

## 使用方法

在项目根目录执行：

```bash
./tools/new-post.sh
```

## 功能说明

脚本会交互式地让你输入：

1. **文章标题** - 必填
2. **文章分类** - 必填，支持多个分类（用逗号分隔）
   - 例如: `iOS` 或 `iOS, 移动开发`
3. **文章标签** - 可选，多个标签用逗号或空格分隔
   - 例如: `iOS, Swift, Xcode`

## 脚本会自动

- ✓ 生成当前日期+时间戳的文件名 (格式: `YYYY-MM-DD-HHMMSS-title.md`)
- ✓ 创建对应的分类文件夹 (如果不存在)
- ✓ 生成文章 front matter 模板
- ✓ 询问是否在编辑器中打开新文件

## 示例

```
$ ./tools/new-post.sh
=== 创建新博客文章 ===

请输入文章标题: Swift 异步编程入门
请输入文章分类: iOS
请输入文章标签: iOS, Swift, 异步

✓ 文章创建成功！
  路径: /Users/gr/Documents/GitProject/snote845.github.io/_posts/iOS/2026-02-09-173045-Swift-异步编程入门.md

是否在编辑器中打开? (Y/n):
```

## 生成的文件模板

```yaml
---
excerpt: ###
layout: post
title: "文章标题"
date: 2026-02-09 17:30:00 +0800
categories: [分类1, 分类2]
tags: [标签1, 标签2]
---

文章内容写在这里...
```
