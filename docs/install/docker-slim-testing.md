---
summary: "Testing guide for the slim Docker image builds"
read_when:
  - Testing Docker image size reductions
  - Validating slim image functionality
  - Running Docker build tests
title: "Docker Slim Image Testing"
---

# Docker Slim Image Testing

This guide covers how to test the new slim Docker image builds (`Dockerfile.slim`) designed to reduce image size to under 500MB.

## Quick Start

### Build the Slim Image

Use the provided build script to build the optimized image:

```bash
./scripts/docker-build-slim.sh
```

This script:
- Builds the multi-stage Dockerfile.slim
- Sets `OPENCLAW_PRUNE_EXTRA=0` by default (standard slim build)
- Reports final image size
- Checks if size target (<500MB) is achieved

### Build with Extra Pruning

For even smaller images (single-channel VPS use cases), enable aggressive pruning:

```bash
OPENCLAW_PRUNE_EXTRA=1 ./scripts/docker-build-slim.sh openclaw:slim-pruned
```

This additionally removes:
- Slack SDKs (`@slack/bolt`, `@slack/web-api`)
- Line SDK (`@line/bot-sdk`)
- Lark/Feishu SDK (`@larksuiteoapi/node-sdk`)
- Playwright (`playwright-core`)
- Canvas native bindings (`@napi-rs/canvas`)
- PDF.js (`pdfjs-dist`)

**Warning**: Only use `OPENCLAW_PRUNE_EXTRA=1` if you don't need these channels/features.

## Image Size Analysis

### Basic Size Check

After building, check the size:

```bash
docker images openclaw:slim
```

### Detailed Analysis

Use the analysis script to get a breakdown:

```bash
./scripts/docker-image-analyze.sh openclaw:slim
```

This provides:
- Total image size
- Top 15 largest layers
- Directory sizes inside the container
- Top 20 largest npm packages
- Dev dependencies check
- Size breakdown summary
- Optimization recommendations

## Functional Testing

### 1. Basic Container Start Test

Verify the container starts and the CLI is accessible:

```bash
# Start the container
docker run -d --name openclaw-slim-test openclaw:slim

# Check if it's running
docker ps | grep openclaw-slim-test

# Test CLI access
docker exec openclaw-slim-test node openclaw.mjs --version

# Clean up
docker stop openclaw-slim-test
docker rm openclaw-slim-test
```

### 2. Gateway Start Test

Test that the gateway can start:

```bash
# Run gateway in foreground (Ctrl+C to stop)
docker run --rm -it \
  -p 18789:18789 \
  openclaw:slim \
  node openclaw.mjs gateway run --bind lan --port 18789 --allow-unconfigured

# Or run in background
docker run -d --name openclaw-gateway-test \
  -p 18789:18789 \
  openclaw:slim \
  node openclaw.mjs gateway run --bind lan --port 18789 --allow-unconfigured

# Check logs
docker logs openclaw-gateway-test

# Test health endpoint
curl http://localhost:18789/health

# Clean up
docker stop openclaw-gateway-test
docker rm openclaw-gateway-test
```

### 3. Live Model Tests (with credentials)

Run the standard Docker live tests using the slim image:

```bash
# Set the image to test
export OPENCLAW_IMAGE=openclaw:slim

# Run live model tests
pnpm test:docker:live-models

# Or run gateway live tests
pnpm test:docker:live-gateway
```

These tests mount your local config (`~/.openclaw/`) and run the full test suite inside the container.

### 4. Onboarding Test

Test the full onboarding flow:

```bash
export OPENCLAW_IMAGE=openclaw:slim
pnpm test:docker:onboard
```

### 5. Complete Test Suite

Run all Docker tests with the slim image:

```bash
export OPENCLAW_IMAGE=openclaw:slim
pnpm test:docker:all
```

This runs:
- `test:docker:live-models` - Direct model tests
- `test:docker:live-gateway` - Gateway + agent tests
- `test:docker:onboard` - Onboarding wizard
- `test:docker:gateway-network` - Multi-container networking
- `test:docker:qr` - QR code import
- `test:docker:doctor-switch` - Doctor command tests
- `test:docker:plugins` - Plugin loading tests

## Manual Verification Checklist

When testing a new slim build, verify:

- [ ] Image size is under 500MB (or 400MB for slim-pruned)
- [ ] Container starts without errors
- [ ] CLI commands work (`openclaw --version`, `openclaw config list`)
- [ ] Gateway starts and binds to port
- [ ] Gateway health endpoint responds
- [ ] At least one model provider works (if you have keys)
- [ ] File operations work (read/write in workspace)
- [ ] Extensions load correctly

## CI Testing (GitHub Actions)

The `.github/workflows/docker-slim-manual.yml` workflow builds both variants:

1. **slim** - Standard optimized build (`OPENCLAW_PRUNE_EXTRA=0`)
2. **slim-pruned** - Aggressive pruning (`OPENCLAW_PRUNE_EXTRA=1`)

To trigger the workflow:
1. Go to Actions tab in GitHub
2. Select "Docker Slim Manual" workflow
3. Click "Run workflow"
4. Wait for build to complete
5. Check workflow summary for image details

The built images are pushed to:
- `ghcr.io/cctry/openclaw:slim-<SHA>`
- `ghcr.io/cctry/openclaw:slim-pruned-<SHA>`

### Pull and Test CI Images

```bash
# Get the short SHA from the workflow run
SHORT_SHA=abc1234

# Pull the image
docker pull ghcr.io/cctry/openclaw:slim-$SHORT_SHA

# Test it
docker run --rm ghcr.io/cctry/openclaw:slim-$SHORT_SHA node openclaw.mjs --version

# Run full tests
OPENCLAW_IMAGE=ghcr.io/cctry/openclaw:slim-$SHORT_SHA pnpm test:docker:live-gateway
```

## Comparing Image Sizes

Compare the slim build against the standard build:

```bash
# Build standard image
docker build -t openclaw:standard -f Dockerfile .

# Build slim image
./scripts/docker-build-slim.sh openclaw:slim

# Compare sizes
docker images | grep "openclaw"
```

Expected results:
- Standard: ~800-1000MB
- Slim: ~450-500MB
- Slim-pruned: ~400-450MB

## Troubleshooting

### Image Too Large

If the image exceeds 500MB:

1. Run the analysis script to identify heavy packages:
   ```bash
   ./scripts/docker-image-analyze.sh openclaw:slim
   ```

2. Check for dev dependencies that shouldn't be in production:
   ```bash
   docker run --rm openclaw:slim sh -c \
     'du -sh /app/node_modules/.pnpm/*typescript* /app/node_modules/.pnpm/*vitest* 2>/dev/null || echo "None found"'
   ```

3. Verify multi-stage build is working:
   ```bash
   docker history openclaw:slim --no-trunc
   ```

### Missing Dependencies

If a feature doesn't work in the slim image:

1. Check if it was pruned by `OPENCLAW_PRUNE_EXTRA`:
   ```bash
   docker run --rm openclaw:slim sh -c 'ls -la /app/node_modules/.pnpm/ | grep slack'
   ```

2. If needed, rebuild without extra pruning:
   ```bash
   OPENCLAW_PRUNE_EXTRA=0 ./scripts/docker-build-slim.sh
   ```

### Container Won't Start

1. Check logs:
   ```bash
   docker logs <container-name>
   ```

2. Try running interactively:
   ```bash
   docker run --rm -it openclaw:slim sh
   ```

3. Verify the node binary and dependencies:
   ```bash
   docker run --rm openclaw:slim sh -c 'which node && node --version'
   ```

## Performance Testing

### Startup Time

Measure how quickly the gateway starts:

```bash
time docker run --rm openclaw:slim \
  node openclaw.mjs gateway run --allow-unconfigured --bind loopback --port 18789 &
# Wait for startup logs, then Ctrl+C
```

### Memory Usage

Monitor memory consumption:

```bash
docker run -d --name openclaw-slim-mem-test \
  --memory="512m" \
  openclaw:slim \
  node openclaw.mjs gateway run --allow-unconfigured --bind lan --port 18789

# Monitor stats
docker stats openclaw-slim-mem-test

# Clean up
docker stop openclaw-slim-mem-test
docker rm openclaw-slim-mem-test
```

## Best Practices

1. **Always test both variants**:
   - Test `slim` (standard) for general use
   - Test `slim-pruned` only if you know your channel requirements

2. **Run full test suite**:
   - Don't just check the size
   - Verify functionality with `pnpm test:docker:all`

3. **Document pruned features**:
   - If you add more pruning rules, document what gets removed
   - Update the warning in this guide

4. **Monitor in production**:
   - Track actual memory usage
   - Watch for missing dependency errors
   - Verify all your channels still work

## See Also

- [Docker Installation Guide](/install/docker)
- [Testing Guide](/help/testing)
- Build script: `scripts/docker-build-slim.sh`
- Analysis script: `scripts/docker-image-analyze.sh`
- Dockerfile: `Dockerfile.slim`
- GitHub workflow: `.github/workflows/docker-slim-manual.yml`
