# 阿里云服务器自动部署工具

## 📁 文件说明

### 核心部署文件（在服务器上使用）

| 文件 | 用途 | 说明 |
|------|------|------|
| [`deploy.sh`](deploy.sh) | 首次部署 | 在服务器上首次部署博客时执行 |
| [`auto-update.sh`](auto-update.sh) | 自动更新 | 每周从 GitHub 拉取最新代码并构建 |
| [`health-check.sh`](health-check.sh) | 健康检查 | 检查网站运行状态 |

### 配置文件

| 文件 | 用途 | Git 状态 |
|------|------|----------|
| [`deploy-config.example.sh`](deploy-config.example.sh) | 配置模板 | ✅ 已提交 |
| `deploy-config.sh` | 实际配置 | 🔒 `.gitignore` 保护 |

### 辅助工具（本地使用）

| 文件 | 用途 |
|------|------|
| [`dev.sh`](dev.sh) | 本地开发调试 |
| [`add-excerpts.sh`](add-excerpts.sh) | 文章摘要生成 |
| [`optimize-images.sh`](optimize-images.sh) | 图片 WebP 转换 |

---

## 🚀 快速开始

### 1. 本地准备配置

```bash
cd tools
cp deploy-config.example.sh deploy-config.sh
vim deploy-config.sh  # 填写服务器信息
```

### 2. 上传到服务器

```bash
scp tools/deploy-config.sh root@YOUR_SERVER_IP:/var/www/blog/tools/
```

### 3. 服务器首次部署

```bash
ssh root@YOUR_SERVER_IP
cd /var/www/blog/tools
bash deploy.sh
```

### 4. 配置自动更新

```bash
# 在服务器上编辑 crontab
crontab -e

# 添加每周一凌晨2点执行
0 2 * * 1 cd /var/www/blog/tools && bash auto-update.sh >> /var/log/blog-update.log 2>&1
```

---

## 💻 本地开发调试

### 方法一：使用标准 Jekyll 命令

```bash
# 开发模式（支持热重载）
bundle install
bundle exec jekyll serve

# 生产模式构建
JEKYLL_ENV=production bundle exec jekyll build

# 生产模式运行
JEKYLL_ENV=production bundle exec jekyll serve
```

### 方法二：使用便捷脚本

```bash
# 开发模式（默认）
./tools/dev.sh

# 指定端口
./tools/dev.sh -p 4001

# 生产模式构建
./tools/dev.sh -P
```

**说明**：
- GitHub Actions 部署**不依赖**任何本地脚本
- 删除 `run.sh` 不影响 CI/CD
- 使用标准 Jekyll 命令即可本地调试

---

### 必填配置项

在 `deploy-config.sh` 中填写：

```bash
export GITHUB_REPO="YOUR_USERNAME/YOUR_REPO"
export GITHUB_BRANCH="main"                    # 使用 main 分支
export SERVER_HOST="YOUR_SERVER_IP"            # 服务器公网IP
export PRIVATE_IP="YOUR_PRIVATE_IP"            # 私有IP
export DOMAIN_NAME="your-domain.com"           # 域名
export WEB_USER="nginx"                        # CentOS 使用 nginx
export LETS_ENCRYPT_EMAIL="your-email@example.com"  # SSL证书邮箱
```

### 自动更新流程

```
每周一凌晨 2:00
  ↓
检查更新（比较 commit hash）
  ↓（有新提交）
拉取代码 → 安装依赖 → Jekyll 构建 → 设置权限 → Nginx 重载 → 健康检查
```

---

## 📊 监控命令

```bash
# 查看更新日志
tail -f /var/log/blog-update.log

# 查看 Nginx 日志
tail -f /var/log/nginx/blog-access.log
tail -f /var/log/nginx/blog-error.log

# 手动触发更新
cd /var/www/blog/tools && bash auto-update.sh

# 健康检查
bash health-check.sh
```

---

## ⚠️ 注意事项

1. **配置安全**：`deploy-config.sh` 包含敏感信息，已在 `.gitignore` 中，不会被提交
2. **分支选择**：当前配置从 `main` 分支拉取，如需修改请编辑配置文件
3. **权限设置**：确保 Web 用户（nginx）对 `_site` 目录有读取权限
4. **SSL证书**：使用 Let's Encrypt 免费证书，记得配置自动续期

---

## 🔗 相关链接

- 仓库：https://github.com/YOUR_USERNAME/YOUR_REPO
- 服务器：阿里云 ECS (YOUR_SERVER_IP)
- 域名：your-domain.com
