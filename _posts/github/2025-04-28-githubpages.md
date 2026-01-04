---
excerpt: # Github Pages1. [注册 github 账户 ](https://github.com/)2. 搜索 chirpy主题的仓库 3. [按照 chirpy 文档进行设置](https://chirpy.cotes.page/posts/getting-started/)4. 拉取到本地...
layout: post
title: "Github Pages"
date: 2025-04-28 19:00:00 +0800
categories: [github, Github Pages]
tags: [github, chirpy, 博客]
---

# Github Pages
1. [注册 github 账户 ](https://github.com/)
2. 搜索 chirpy主题的仓库 
3. [按照 chirpy 文档进行设置](https://chirpy.cotes.page/posts/getting-started/)
4. 拉取到本地进行本地部署
5. 部署脚本

```bash
bash tools/run.sh
```
7. 修改配置\_config.yaml
   1. avatar 头像可设置本地或链接，如本地图片可将图片放在 assets 文件夹中，比如avatar: /assets/images/icon.png
   2. url:配置你的 github 地址即可
   3. name:名字
   4. email:邮箱
   5. links:github 链接即可或其他可关联的地址
8. 添加文章
   1. 找到\_posts 文件夹
   2. 创建YYYY-MM-DD-title.md格式的文件
   3. 博客文章模板可参考如下

```md
---
layout: post
title: "Android Robust"
date: 2025-04-28 10:00:00 +0800
categories: [Android, 热修复]
tags: [Android, Robust, 热修复]
---

文章内容...
```
9. 保存发布提交即可



