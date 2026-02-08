# VPS 部署指南 (VPS Deployment Guide)

本指南说明如何在 VPS 上使用预构建的 Docker 镜像部署 OpenClaw。

## 系统要求

- **操作系统**: Ubuntu 18.04 或更高版本
- **Docker**: 20.10 或更高版本
- **docker-compose**: 1.17.1 或更高版本
- **架构**: linux/amd64
- **磁盘空间**: 至少 2GB 可用空间用于 Docker 镜像和数据

## 镜像构建

GitHub Actions 会在以下情况下自动构建并推送 Docker 镜像到 GHCR:

1. 推送到 `main` 分支时
2. 创建 tag（格式：`v*`）时

镜像地址：`ghcr.io/cctry/openclaw:latest` (或使用特定的版本标签)

### 镜像优化特性

- **多阶段构建**: 使用 builder 和 runtime 两个阶段
- **精简基础镜像**: runtime 阶段使用 `node:22-slim` 而非完整版本
- **最小化依赖**: 只包含生产运行时必需的依赖
- **无构建缓存**: 不包含任何构建工具、测试数据或 git 历史
- **非 root 用户**: 使用 `node` 用户运行，提高安全性
- **平台**: 仅构建 linux/amd64 以节省时间和空间

## VPS 部署步骤

### 1. 准备 VPS 环境

确保已安装 Docker 和 docker-compose：

```bash
# 检查 Docker 版本
docker --version

# 检查 docker-compose 版本
docker-compose --version
```

### 2. 创建部署目录

```bash
mkdir -p ~/openclaw-deploy
cd ~/openclaw-deploy
```

### 3. 下载 docker-compose 配置

```bash
# 下载 VPS 专用的 docker-compose 配置
curl -o docker-compose.yml https://raw.githubusercontent.com/cctry/openclaw/main/docker-compose.vps.yml
```

### 4. 配置环境变量

创建 `.env` 文件：

```bash
cat > .env << 'EOF'
# Gateway 配置
OPENCLAW_GATEWAY_TOKEN=your-secure-token-here
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_BRIDGE_PORT=18790
OPENCLAW_GATEWAY_BIND=lan

# AI 服务配置（根据需要填写）
CLAUDE_AI_SESSION_KEY=
CLAUDE_WEB_SESSION_KEY=
CLAUDE_WEB_COOKIE=
EOF
```

**重要**: 请修改 `OPENCLAW_GATEWAY_TOKEN` 为一个安全的随机字符串。

### 5. 拉取并运行

```bash
# 拉取最新镜像
docker-compose pull

# 启动服务（后台运行）
docker-compose up -d

# 查看日志
docker-compose logs -f openclaw-gateway
```

### 6. 验证部署

```bash
# 检查容器状态
docker-compose ps

# 测试 gateway 端口
curl http://localhost:18789
```

## 运行 CLI 命令

使用 `docker run` 命令临时运行 CLI：

```bash
# 运行 agent 命令
docker run --rm -it \
  -e OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN \
  -v openclaw_openclaw-config:/home/node/.openclaw \
  ghcr.io/cctry/openclaw:latest agent --message "hello"

# 发送消息
docker run --rm -it \
  -e OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN \
  -v openclaw_openclaw-config:/home/node/.openclaw \
  ghcr.io/cctry/openclaw:latest message send --to +1234567890 --message "Test"

# 查看帮助
docker run --rm ghcr.io/cctry/openclaw:latest --help
```

**注意**: 
- 端口默认绑定到 `127.0.0.1`（localhost），只允许本地访问。
- 如需外部访问，请修改 `.env` 文件中的端口配置或在 `docker-compose.yml` 中移除 `127.0.0.1:` 前缀（不推荐用于生产环境）。

## 镜像更新

当有新版本时，执行以下命令更新：

```bash
cd ~/openclaw-deploy

# 拉取最新镜像
docker-compose pull

# 重启服务
docker-compose up -d

# 查看日志确认启动成功
docker-compose logs -f openclaw-gateway
```

## 使用特定版本

如果需要使用特定版本而非 `latest`，可以修改 docker-compose.yml 中的镜像标签：

```yaml
image: ghcr.io/cctry/openclaw:v2026.2.6-3  # 使用特定版本
```

或者在 .env 文件中设置：

```bash
echo "OPENCLAW_IMAGE=ghcr.io/cctry/openclaw:v2026.2.6-3" >> .env
```

## 常见问题

### 1. 镜像拉取失败

如果是私有仓库，需要先登录 GHCR：

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

**可用镜像标签**:
- `latest` - 最新 main 分支构建
- `sha-abc1234` - 特定 commit SHA
- `v2026.2.6-3` - 版本标签（当创建 tag 时）

### 2. docker-compose 版本兼容性

本配置兼容 docker-compose 1.17.1+：
- 使用 version 3.3 语法
- 移除了 `init: true`（1.17.1 不支持）
- 使用命名卷 (named volumes)

### 3. 磁盘空间不足

清理旧的 Docker 镜像和容器：

```bash
# 停止并删除容器
docker-compose down

# 清理未使用的镜像
docker image prune -a

# 重新拉取和启动
docker-compose pull
docker-compose up -d
```

### 3. 端口被占用

修改 `.env` 文件中的端口配置：

```bash
OPENCLAW_GATEWAY_PORT=18790  # 更改为其他可用端口
```

### 4. 权限问题

确保 Docker volumes 有正确的权限：

```bash
# 查看 volumes
docker volume ls

# 如有必要，重新创建 volumes
docker-compose down -v
docker-compose up -d
```

## 生产环境建议

1. **使用固定版本标签**: 不要在生产环境使用 `latest` 标签
2. **定期备份**: 备份 Docker volumes 中的配置和数据
3. **监控日志**: 设置日志轮转以避免磁盘空间问题
4. **安全加固**: 
   - 使用强密码作为 GATEWAY_TOKEN
   - 配置防火墙规则
   - 定期更新镜像和系统

## 镜像大小对比

- **优化前** (单阶段构建，node:22-bookworm): ~1.5GB+
- **优化后** (多阶段构建，node:22-slim，移除文档/资源): ~750MB-900MB

具体大小取决于依赖和构建产物。通过以下优化措施实现显著减小：
- 多阶段构建分离构建和运行时
- 使用 slim 基础镜像
- 移除不必要的文档、README、资源文件 (~16MB)
- 移除 Bun 安装（供应链风险降低，构建更快）

## 技术细节

### Dockerfile 优化措施

1. **多阶段构建**:
   - Builder 阶段: 安装所有依赖并构建应用
   - Runtime 阶段: 只复制必要的生产文件

2. **依赖优化**:
   - 在 builder 中安装完整依赖
   - 构建后运行 `pnpm install --prod` 清理开发依赖
   - 只复制生产依赖到 runtime 阶段

3. **基础镜像**:
   - Builder: `node:22-bookworm` (完整工具链)
   - Runtime: `node:22-slim` (最小化运行时)

4. **缓存清理**:
   - 清理 apt 缓存 (`rm -rf /var/lib/apt/lists/*`)
   - 不包含 git 历史、测试数据等

5. **文件瘦身**:
   - 移除运行时不需要的文档 (docs/ ~14MB)
   - 移除 README、CHANGELOG、资源图片 (~2.8MB)
   - 总计节省 ~16MB+

6. **供应链安全**:
   - 移除不必要的 Bun 安装（curl | bash 风险）
   - 仅使用 pnpm 进行构建

7. **安全性**:
   - 非 root 用户运行 (node:node, uid 1000)
   - 最小化攻击面

## 支持

如有问题，请访问:
- [项目主页](https://github.com/openclaw/openclaw)
- [文档站点](https://docs.openclaw.ai)
- [Discord 社区](https://discord.gg/clawd)
