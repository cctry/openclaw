# Docker Image Size Optimization Summary

## Problem
The runtime Docker image contained the `@napi-rs/canvas` dependency with large native binaries (skia), causing:
- Image layer extraction requiring >700MB
- VPS disk space issues
- Unnecessary bloat for users who don't need PDF extraction

## Solution

### 1. Dependency Management
- Moved `@napi-rs/canvas` from `peerDependencies` to `optionalDependencies`
- The code already handles missing canvas gracefully via lazy loading in `src/media/input-files.ts`

### 2. Image Variants

#### Slim Image (Default) - `ghcr.io/cctry/openclaw:slim` or `:latest`
- **Size**: ~400-500MB compressed
- **Base**: `node:20-slim` (down from `node:22-bookworm`)
- **Excludes**: Canvas and related native dependencies
- **Use case**: Core gateway/agent functionality without PDF image extraction
- **Build**: `docker build -f Dockerfile .`

#### Full Image - `ghcr.io/cctry/openclaw:full`
- **Size**: ~800MB+ compressed
- **Base**: `node:20-slim`
- **Includes**: Canvas for PDF image extraction
- **Use case**: When PDF image extraction is required
- **Build**: `docker build -f Dockerfile.full .`

### 3. Build Optimizations
- Strict multi-stage build
- Builder stage: All dependencies for compilation
- Runtime stage: Production dependencies only
- Explicit canvas removal in slim variant
- Clean up pnpm store and apt cache
- Show node_modules size during build for visibility

### 4. CI/CD Updates
- `docker-ghcr.yml`: Builds both slim and full variants for amd64
- `docker-release.yml`: Multi-platform builds (amd64 + arm64) for both variants
- `docker-analyze-deps.yml`: Manual workflow to analyze dependencies

### 5. Available Tags
- `latest` / `slim` - Latest slim build from main (default)
- `full` - Latest full build from main
- `v{version}` / `v{version}-slim` - Version-tagged slim image
- `v{version}-full` - Version-tagged full image

## Testing

To test locally:

```bash
# Build and test slim image
docker build -t openclaw:test-slim -f Dockerfile .
docker run --rm openclaw:test-slim node openclaw.mjs --version

# Build and test full image
docker build -t openclaw:test-full -f Dockerfile.full .
docker run --rm openclaw:test-full node openclaw.mjs --version
```

## Migration Guide

### For Users Currently Using `latest`
No changes needed. The `latest` tag now points to the slim variant, which is sufficient for most use cases.

### For Users Needing PDF Extraction
Switch to the full image:
```bash
docker pull ghcr.io/cctry/openclaw:full
```

## Size Comparison

| Variant | Base Image | Size (Compressed) | Canvas Included |
|---------|-----------|-------------------|-----------------|
| Before | node:22-bookworm | ~1.5GB+ | Yes |
| Slim (new default) | node:20-slim | ~400-500MB | No |
| Full | node:20-slim | ~800MB | Yes |

**Space Saved**: ~1GB+ for slim variant, ~700MB for full variant vs original
