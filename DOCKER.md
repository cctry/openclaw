# Docker 部署说明 / Docker Deployment Guide

[English](#english) | [中文](#chinese)

---

## English

### Quick Start

This repository provides optimized Docker images built via GitHub Actions and published to GitHub Container Registry (GHCR).

**Image Variants**:
- `ghcr.io/cctry/openclaw:ultra` - **Ultra-minimal** (~150-250MB, distroless, gateway-only, no UI, no optional deps) **← Recommended for VPS with limited disk**
- `ghcr.io/cctry/openclaw:latest` or `ghcr.io/cctry/openclaw:slim` - **Slim image** (default, ~300-400MB, no PDF extraction, includes UI)
- `ghcr.io/cctry/openclaw:full` - **Full image** (~700-800MB, includes canvas for PDF image extraction)

#### Prerequisites

- Docker 20.10+
- docker-compose 1.17.1+ (for compose deployment)
- Platform: linux/amd64 or linux/arm64

#### Pull and Run (Ultra - Gateway Only, Smallest)

For VPS with limited disk space (< 2GB):

```bash
# Pull the ultra-minimal image
docker pull ghcr.io/cctry/openclaw:ultra

# Run gateway only (no UI, distroless base)
docker run -d \
  -e OPENCLAW_GATEWAY_TOKEN=your-secure-token \
  -p 18789:18789 \
  -v openclaw-config:/home/nonroot/.openclaw \
  ghcr.io/cctry/openclaw:ultra
```

**Note**: Ultra variant uses distroless base and runs as uid 65532 (nonroot). Config directory is `/home/nonroot/.openclaw`.

#### Pull and Run (Slim - Default)

Balanced option with UI support:

```bash
# Pull the latest slim image (default)
docker pull ghcr.io/cctry/openclaw:latest

# Run with default settings
docker run -d \
  -e OPENCLAW_GATEWAY_TOKEN=your-secure-token \
  -p 18789:18789 \
  -v openclaw-config:/home/node/.openclaw \
  ghcr.io/cctry/openclaw:latest
```

#### Pull and Run (Full - with PDF extraction)

If you need PDF image extraction features:

```bash
# Pull the full image (includes canvas)
docker pull ghcr.io/cctry/openclaw:full

# Run with full features
docker run -d \
  -e OPENCLAW_GATEWAY_TOKEN=your-secure-token \
  -p 18789:18789 \
  -v openclaw-config:/home/node/.openclaw \
  ghcr.io/cctry/openclaw:full
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

**Security Note**: Ports are bound to `127.0.0.1` (localhost) by default for security.

**CLI Usage**: Use `docker run --rm -it -e OPENCLAW_GATEWAY_TOKEN=... -v openclaw_openclaw-config:/home/node/.openclaw ghcr.io/cctry/openclaw:latest <command>` for one-off CLI commands.

For detailed instructions, see: [docs/deploy/vps-deployment.md](docs/deploy/vps-deployment.md)

### Image Optimization

The Docker image uses a strict multi-stage build and includes three variants optimized for different use cases:

#### Ultra Image - `ghcr.io/cctry/openclaw:ultra` **← SMALLEST**

- **Base**: `gcr.io/distroless/nodejs20-debian12:nonroot` (Google's distroless, no shell)
- **Builder stage**: Full build tools, skip UI build
- **Runtime stage**: Gateway-only, no UI assets, no optional dependencies
- **Size**: ~150-250MB compressed
- **Optimizations**:
  - Distroless base (no package manager, no shell, minimal attack surface)
  - Skips UI build (`pnpm ui:build` not run)
  - `--no-optional` flag ensures canvas never installed
  - `ENV PNPM_CONFIG_OPTIONAL=false` for defense in depth
  - Build-time assertion: fails if canvas packages detected
  - Runs as nonroot user (uid 65532)
- **Use case**: **VPS with limited disk (<2GB)**, gateway-only deployments, maximum security

#### Slim Image (Default) - `ghcr.io/cctry/openclaw:slim` or `:latest`

- **Base**: `node:20-slim`
- **Builder stage**: Full build tools, includes UI build
- **Runtime stage**: Minimal with production dependencies only
- **Excludes**: `@napi-rs/canvas` and all optional dependencies
- **Size**: ~300-400MB compressed
- **Optimizations**:
  - `--no-optional` flag ensures canvas never installed
  - `ENV PNPM_CONFIG_OPTIONAL=false` for defense in depth
  - Build-time and runtime assertions: fails if canvas detected
  - Explicit verification in both builder and runtime stages
  - Shows component sizes during build
- **Use case**: Standard deployments with UI, no PDF image extraction

#### Full Image - `ghcr.io/cctry/openclaw:full`

- Same optimized build process as slim
- **Includes**: `@napi-rs/canvas` for PDF image extraction
- **Size**: ~700-800MB compressed
- **Use case**: When you need PDF image extraction features

**Size comparison**:
- Before optimization: ~1.5GB+ (single-stage, node:22-bookworm, includes canvas)
- Ultra image: ~150-250MB (distroless, no UI, no optional) **← 83-86% reduction**
- Slim image: ~300-400MB (node:20-slim, with UI, no optional) **← 73-80% reduction**
- Full image: ~700-800MB (node:20-slim, with UI and canvas) **← 46-53% reduction**

**Key optimizations**:
- Ultra: Distroless base + skip UI build + no optional deps
- All variants: `pnpm install --prod --no-optional` (explicit)
- All variants: `ENV PNPM_CONFIG_OPTIONAL=false` (defense in depth)
- Slim/Ultra: Build-time assertions to verify no canvas
- Changed from `node:22-bookworm` to `node:20-slim` (slim/full)
- Strict production-only dependency installation
- Removed build cache and pnpm store in runtime
- Cleaned up apt lists and cache

### Automatic Builds

Images are automatically built and pushed to GHCR when:
- Code is pushed to the `main` branch → `latest`, `slim`, `ultra`, and `full` tags
- Version tags are created (e.g., `v2026.2.6`) → version-specific tags with `-ultra`, `-slim` and `-full` variants

**Available tags**:
- `ultra` - Latest ultra-minimal build (distroless, gateway-only)
- `latest` / `slim` - Latest slim build from main (default)
- `full` - Latest full build from main
- `v{version}-ultra` - Version-tagged ultra image
- `v{version}` / `v{version}-slim` - Version-tagged slim image
- `v{version}-full` - Version-tagged full image
- `{branch}-ultra`, `{branch}-slim`, `{branch}-full` - Branch-specific builds

**Image inspection**: Workflows automatically print image sizes and layer information to help monitor optimization.

Workflow files: 
- `.github/workflows/docker-ghcr.yml` (single platform, amd64, with size inspection)
- `.github/workflows/docker-release.yml` (multi-platform, amd64 + arm64, all variants)

---

## Chinese

### 快速开始

本仓库通过 GitHub Actions 构建优化的 Docker 镜像，并发布到 GitHub Container Registry (GHCR)。

**镜像变体**:
- `ghcr.io/cctry/openclaw:ultra` - **超精简** (~150-250MB，distroless，仅网关，无 UI，无可选依赖) **← VPS 磁盘有限推荐**
- `ghcr.io/cctry/openclaw:latest` 或 `ghcr.io/cctry/openclaw:slim` - **精简镜像** (默认，~300-400MB，无 PDF 提取，含 UI)
- `ghcr.io/cctry/openclaw:full` - **完整镜像** (~700-800MB，包含 canvas 用于 PDF 图像提取)

#### 系统要求

- Docker 20.10+
- docker-compose 1.17.1+ (compose 部署时需要)
- 平台: linux/amd64 或 linux/arm64

#### 拉取并运行 (超精简版 - 仅网关，最小)

VPS 磁盘有限 (< 2GB) 时推荐:

```bash
# 拉取超精简镜像
docker pull ghcr.io/cctry/openclaw:ultra

# 仅运行网关（无 UI，distroless 基础）
docker run -d \
  -e OPENCLAW_GATEWAY_TOKEN=your-secure-token \
  -p 18789:18789 \
  -v openclaw-config:/home/nonroot/.openclaw \
  ghcr.io/cctry/openclaw:ultra
```

**注意**：Ultra 变体使用 distroless 基础镜像，以 uid 65532 (nonroot) 运行。配置目录为 `/home/nonroot/.openclaw`。

#### 拉取并运行 (精简版 - 默认)

平衡选项，支持 UI:

```bash
# 拉取最新精简镜像 (默认)
docker pull ghcr.io/cctry/openclaw:latest

# 使用默认设置运行
docker run -d \
  -e OPENCLAW_GATEWAY_TOKEN=your-secure-token \
  -p 18789:18789 \
  -v openclaw-config:/home/node/.openclaw \
  ghcr.io/cctry/openclaw:latest
```

#### 拉取并运行 (完整版 - 含 PDF 提取)

如果需要 PDF 图像提取功能:

```bash
# 拉取完整镜像 (包含 canvas)
docker pull ghcr.io/cctry/openclaw:full

# 使用完整功能运行
docker run -d \
  -e OPENCLAW_GATEWAY_TOKEN=your-secure-token \
  -p 18789:18789 \
  -v openclaw-config:/home/node/.openclaw \
  ghcr.io/cctry/openclaw:full
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
- 代码推送到 `main` 分支 → `latest`、`slim` 和 `full` 标签
- 创建版本 tag (例如 `v2026.2.6`) → 对应版本标签，带 `-slim` 和 `-full` 变体

**可用标签**:
- `latest` / `slim` - 主分支的最新精简构建
- `full` - 主分支的最新完整构建
- `v{version}` / `v{version}-slim` - 版本标记的精简镜像
- `v{version}-full` - 版本标记的完整镜像
- `{branch}-slim`, `{branch}-full` - 分支特定构建

工作流文件:
- `.github/workflows/docker-ghcr.yml` (单平台, amd64)
- `.github/workflows/docker-release.yml` (多平台, amd64 + arm64)

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

If you want to build the images locally:

### Ultra Image (smallest, gateway-only)

```bash
# Build the ultra image (distroless, no UI, no canvas)
docker build -t openclaw:ultra -f Dockerfile.ultra .

# Run it (note: nonroot user, different config path)
docker run -d \
  -e OPENCLAW_GATEWAY_TOKEN=your-token \
  -p 18789:18789 \
  -v openclaw-config:/home/nonroot/.openclaw \
  openclaw:ultra
```

### Slim Image (default)

```bash
# Build the slim image (no canvas)
docker build -t openclaw:slim -f Dockerfile .

# Run it
docker run -d \
  -e OPENCLAW_GATEWAY_TOKEN=your-token \
  -p 18789:18789 \
  openclaw:slim
```

### Full Image (with canvas)

```bash
# Build the full image (with canvas)
docker build -t openclaw:full -f Dockerfile.full .

# Run it
docker run -d \
  -e OPENCLAW_GATEWAY_TOKEN=your-token \
  -p 18789:18789 \
  openclaw:full
```

## Support

- [Documentation](https://docs.openclaw.ai)
- [GitHub Repository](https://github.com/openclaw/openclaw)
- [Discord Community](https://discord.gg/clawd)
