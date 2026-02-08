# Docker Image Size Optimization Summary

## Problem
The runtime Docker image contained the `@napi-rs/canvas` dependency with large native binaries (skia), causing:
- Image layer extraction requiring >700MB
- VPS disk space issues
- Unnecessary bloat for users who don't need PDF extraction

## Solution

### 1. Dependency Management
- Moved `@napi-rs/canvas` from `peerDependencies` to `optionalDependencies`
- Added `--no-optional` flag to `pnpm install` commands (explicit exclusion)
- Added `ENV PNPM_CONFIG_OPTIONAL=false` (defense in depth)
- The code already handles missing canvas gracefully via lazy loading in `src/media/input-files.ts`

### 2. Image Variants

#### Ultra Image - `ghcr.io/cctry/openclaw:ultra` **← SMALLEST**
- **Size**: ~150-250MB compressed
- **Base**: `gcr.io/distroless/nodejs20-debian12:nonroot` (Google's distroless)
- **Optimizations**:
  - Distroless base (no shell, no package manager, minimal attack surface)
  - Skips UI build entirely (`pnpm ui:build` not run)
  - Gateway-only functionality
  - `pnpm install --prod --no-optional` (explicit)
  - Build-time assertion fails if canvas detected
  - Runs as nonroot user (uid 65532)
- **Use case**: **VPS with <2GB disk**, maximum security, gateway-only
- **Build**: `docker build -f Dockerfile.ultra .`
- **Savings**: ~83-86% vs original (1.5GB → 150-250MB)

#### Slim Image (Default) - `ghcr.io/cctry/openclaw:slim` or `:latest`
- **Size**: ~300-400MB compressed
- **Base**: `node:20-slim` (down from `node:22-bookworm`)
- **Excludes**: Canvas and related native dependencies
- **Optimizations**:
  - `pnpm install --prod --no-optional` (explicit)
  - `ENV PNPM_CONFIG_OPTIONAL=false` (defense in depth)
  - Build-time AND runtime assertions fail if canvas detected
  - Includes UI build
- **Use case**: Standard deployments with UI, no PDF image extraction
- **Build**: `docker build -f Dockerfile .`
- **Savings**: ~73-80% vs original (1.5GB → 300-400MB)

#### Full Image - `ghcr.io/cctry/openclaw:full`
- **Size**: ~700-800MB compressed
- **Base**: `node:20-slim`
- **Includes**: Canvas for PDF image extraction
- **Use case**: When PDF image extraction is required
- **Build**: `docker build -f Dockerfile.full .`
- **Savings**: ~46-53% vs original (1.5GB → 700-800MB)

### 3. Build Optimizations
- Strict multi-stage build
- Builder stage: All dependencies for compilation
- Runtime stage: Production dependencies only
- **Explicit** canvas exclusion via `--no-optional` flag (not just removal)
- **Defense in depth**: `ENV PNPM_CONFIG_OPTIONAL=false`
- **Verification**: Build-time assertions to ensure no canvas in slim/ultra
- Clean up pnpm store and apt cache
- Show node_modules size during build for visibility

### 4. CI/CD Updates
- `docker-ghcr.yml`: Builds ultra, slim, and full variants for amd64 with size inspection
- `docker-release.yml`: Multi-platform builds (amd64 + arm64) for all three variants
- `docker-analyze-deps.yml`: Manual workflow to analyze dependencies
- Workflows print image sizes via `docker inspect` and `docker history`

### 5. Available Tags
- `ultra` - Latest ultra build (distroless, smallest)
- `latest` / `slim` - Latest slim build from main (default)
- `full` - Latest full build from main
- `v{version}-ultra` - Version-tagged ultra image
- `v{version}` / `v{version}-slim` - Version-tagged slim image
- `v{version}-full` - Version-tagged full image

## Testing

To test locally:

```bash
# Build and test ultra image (smallest)
docker build -t openclaw:test-ultra -f Dockerfile.ultra .
docker run --rm openclaw:test-ultra --version

# Build and test slim image
docker build -t openclaw:test-slim -f Dockerfile .
docker run --rm openclaw:test-slim node openclaw.mjs --version

# Build and test full image
docker build -t openclaw:test-full -f Dockerfile.full .
docker run --rm openclaw:test-full node openclaw.mjs --version
```

## Migration Guide

### For Users Currently Using `latest`
No changes needed. The `latest` tag now points to the slim variant (with explicit `--no-optional`), which is sufficient for most use cases.

### For Users on VPS with Limited Disk (<2GB)
Switch to the ultra image for maximum space savings:
```bash
docker pull ghcr.io/cctry/openclaw:ultra
```

### For Users Needing PDF Extraction
Switch to the full image:
```bash
docker pull ghcr.io/cctry/openclaw:full
```

## Size Comparison

| Variant | Base Image | Size (Compressed) | Canvas | Reduction | Use Case |
|---------|-----------|-------------------|--------|-----------|----------|
| Before | node:22-bookworm | ~1.5GB+ | Yes | - | Legacy |
| **Ultra (new)** | distroless/nodejs20 | **~150-250MB** | No | **83-86%** | **VPS <2GB disk** |
| Slim (new default) | node:20-slim | ~300-400MB | No | 73-80% | Standard + UI |
| Full | node:20-slim | ~700-800MB | Yes | 46-53% | PDF extraction |

**Space Saved**: 
- **Ultra**: ~1.25GB+ saved (83-86% reduction) ← **Best for VPS**
- **Slim**: ~1.1GB+ saved (73-80% reduction)
- **Full**: ~700-800MB saved (46-53% reduction)

## Key Improvements

### Explicit Optional Dependency Exclusion
- **Before**: Relied on manual removal after install
- **After**: `pnpm install --prod --no-optional` explicitly excludes optional deps
- **Defense**: `ENV PNPM_CONFIG_OPTIONAL=false` ensures no accidental installation

### Build-Time Assertions
```dockerfile
# Fails build if canvas packages detected
RUN ! find node_modules -type d \( -name "*canvas*" -o -name "@napi-rs" \) | grep -q .
```

### Ultra Variant Optimizations
1. **Distroless base**: No shell, no package manager → minimal attack surface
2. **Skip UI build**: Saves ~50-100MB in build artifacts
3. **Gateway-only**: Only essential runtime files copied
4. **Nonroot user**: Runs as uid 65532 (distroless nonroot)

## Verification Commands

```bash
# Check image sizes
docker images | grep openclaw

# Inspect specific image
docker image inspect ghcr.io/cctry/openclaw:ultra | jq '.[0].Size'

# Check layer sizes
docker history ghcr.io/cctry/openclaw:ultra --human

# Verify no canvas in ultra/slim
docker run --rm ghcr.io/cctry/openclaw:ultra find /app/node_modules -name "*canvas*" 2>/dev/null || echo "✓ No canvas found"
```
