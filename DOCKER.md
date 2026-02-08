# Docker 部署说明 / Docker Deployment Guide

[English](#english) | [中文](#chinese)

---

## English

### Quick Start

This repository provides optimized Docker images built via GitHub Actions and published to GitHub Container Registry (GHCR).

**Image Location**: `ghcr.io/cctry/openclaw:latest`

#### Prerequisites

- Docker 20.10+
- docker-compose 1.17.1+ (for compose deployment)
- Platform: linux/amd64

#### Pull and Run

```bash
# Pull the latest image
docker pull ghcr.io/cctry/openclaw:latest

# Run with default settings
docker run -d \
  -e OPENCLAW_GATEWAY_TOKEN=your-secure-token \
  -p 18789:18789 \
  -v openclaw-config:/home/node/.openclaw \
  ghcr.io/cctry/openclaw:latest
```

#### Using docker-compose

1. Download the VPS-optimized compose file:
   ```bash
   curl -o docker-compose.yml https://raw.githubusercontent.com/cctry/openclaw/main/docker-compose.vps.yml
   ```

2. Create a `.env` file with your configuration
3. Deploy:
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

For detailed instructions, see: [docs/deploy/vps-deployment.md](docs/deploy/vps-deployment.md)

### Image Optimization

The Docker image uses a multi-stage build to minimize size:

- **Builder stage**: Full Node.js environment with build tools
- **Runtime stage**: Minimal `node:22-slim` base with only production dependencies

**Size comparison**:
- Before: ~1.5GB+ (single-stage, node:22-bookworm)
- After: ~750MB-900MB (multi-stage, node:22-slim, no docs/assets)

### Automatic Builds

Images are automatically built and pushed to GHCR when:
- Code is pushed to the `main` branch → `latest` tag
- Version tags are created (e.g., `v2026.2.6`) → version-specific tags

Workflow file: `.github/workflows/docker-ghcr.yml`

---

## Chinese

### 快速开始

本仓库通过 GitHub Actions 构建优化的 Docker 镜像，并发布到 GitHub Container Registry (GHCR)。

**镜像地址**: `ghcr.io/cctry/openclaw:latest`

#### 系统要求

- Docker 20.10+
- docker-compose 1.17.1+ (compose 部署时需要)
- 平台: linux/amd64

#### 拉取并运行

```bash
# 拉取最新镜像
docker pull ghcr.io/cctry/openclaw:latest

# 使用默认设置运行
docker run -d \
  -e OPENCLAW_GATEWAY_TOKEN=your-secure-token \
  -p 18789:18789 \
  -v openclaw-config:/home/node/.openclaw \
  ghcr.io/cctry/openclaw:latest
```

#### 使用 docker-compose

1. 下载 VPS 优化的 compose 配置文件:
   ```bash
   curl -o docker-compose.yml https://raw.githubusercontent.com/cctry/openclaw/main/docker-compose.vps.yml
   ```

2. 创建 `.env` 文件配置环境变量
3. 部署:
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

详细说明请参考: [docs/deploy/vps-deployment.md](docs/deploy/vps-deployment.md)

### 镜像优化

Docker 镜像使用多阶段构建以最小化体积:

- **Builder 阶段**: 完整的 Node.js 环境和构建工具
- **Runtime 阶段**: 最小化的 `node:22-slim` 基础镜像，仅包含生产依赖

**体积对比**:
- 优化前: ~1.5GB+ (单阶段构建, node:22-bookworm)
- 优化后: ~750MB-900MB (多阶段构建, node:22-slim, 移除文档/资源)

### 自动构建

在以下情况下，镜像会自动构建并推送到 GHCR:
- 代码推送到 `main` 分支 → `latest` 标签
- 创建版本 tag (例如 `v2026.2.6`) → 对应版本标签

工作流文件: `.github/workflows/docker-ghcr.yml`

### 技术特性

1. **多阶段构建**
   - Builder: 完整工具链，用于编译和构建
   - Runtime: 精简运行时，只包含必需依赖

2. **体积优化**
   - 使用 node:22-slim 作为运行时基础镜像
   - 仅复制生产依赖和构建产物
   - 移除文档、README、资源文件 (~16MB)
   - 清理 apt 缓存和临时文件

3. **供应链安全**
   - 移除不必要的 Bun 安装
   - 避免 curl | bash 供应链风险
   - 仅使用 pnpm 进行构建

4. **运行安全**
   - 非 root 用户运行 (node:node, uid 1000)
   - 最小化攻击面

4. **兼容性**
   - 支持 docker-compose 1.17.1+
   - 仅构建 linux/amd64 平台

---

## Building Locally

If you want to build the image locally:

```bash
# Build the image
docker build -t openclaw:local .

# Run it
docker run -d \
  -e OPENCLAW_GATEWAY_TOKEN=your-token \
  -p 18789:18789 \
  openclaw:local
```

## Support

- [Documentation](https://docs.openclaw.ai)
- [GitHub Repository](https://github.com/openclaw/openclaw)
- [Discord Community](https://discord.gg/clawd)
