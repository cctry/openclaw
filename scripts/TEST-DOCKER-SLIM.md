# Quick Guide: Testing Docker Slim Images

This is a quick reference for testing the slim Docker image builds.

## Quick Commands

### Build

```bash
# Standard slim build
./scripts/docker-build-slim.sh

# With extra pruning (removes Slack/Line/Playwright/Canvas/PDF)
OPENCLAW_PRUNE_EXTRA=1 ./scripts/docker-build-slim.sh openclaw:slim-pruned

# Build specific tag
./scripts/docker-build-slim.sh openclaw:test-v1
```

### Analyze Size

```bash
# Detailed breakdown
./scripts/docker-image-analyze.sh openclaw:slim

# Just check size
docker images openclaw:slim
```

### Quick Smoke Test

```bash
# Test CLI
docker run --rm openclaw:slim node openclaw.mjs --version

# Test gateway start
docker run --rm -it -p 18789:18789 openclaw:slim \
  node openclaw.mjs gateway run --bind lan --port 18789 --allow-unconfigured
```

### Full Test Suite

```bash
# Set image to test
export OPENCLAW_IMAGE=openclaw:slim

# Run all Docker tests
pnpm test:docker:all

# Or run specific tests
pnpm test:docker:live-models      # Model tests
pnpm test:docker:live-gateway     # Gateway + agent
pnpm test:docker:onboard          # Onboarding flow
```

## Expected Results

### Size Targets

- **slim**: ~450-500MB (no extra pruning)
- **slim-pruned**: ~400-450MB (with OPENCLAW_PRUNE_EXTRA=1)

### Build Stages

The Dockerfile.slim uses 3 stages:

1. **builder** - Full Node.js + Bun, builds dist + UI
2. **prod-deps** - Installs production deps only, removes optional binaries
3. **runtime** - Minimal Node.js slim, copies artifacts from previous stages

## What Gets Pruned

### Standard Slim (OPENCLAW_PRUNE_EXTRA=0)

Always removed:
- `node-llama-cpp` (local LLM inference)
- `tensorflow` binaries
- CUDA/Vulkan binaries
- TypeScript compiler
- Source maps (`*.map`)
- Test directories
- Example directories

### Extra Pruning (OPENCLAW_PRUNE_EXTRA=1)

Additionally removes:
- `@slack/bolt`, `@slack/web-api` (Slack)
- `@line/bot-sdk` (LINE)
- `@larksuiteoapi/node-sdk` (Lark/Feishu)
- `playwright-core` (Browser automation)
- `@napi-rs/canvas` (Canvas rendering)
- `pdfjs-dist` (PDF parsing)

**Warning**: Only use extra pruning if you don't need these channels/features!

## Troubleshooting

### Image Too Large

1. Run analysis: `./scripts/docker-image-analyze.sh openclaw:slim`
2. Check for dev deps: Look for typescript, vitest, etc.
3. Review layer history: `docker history openclaw:slim`

### Missing Features

1. Check what was pruned:
   ```bash
   docker run --rm openclaw:slim ls /app/node_modules/.pnpm/ | grep <package>
   ```
2. Rebuild without OPENCLAW_PRUNE_EXTRA if needed

### Container Won't Start

1. Check logs: `docker logs <container>`
2. Run interactively: `docker run --rm -it openclaw:slim sh`
3. Verify Node.js: `docker run --rm openclaw:slim node --version`

## CI Workflow

Location: `.github/workflows/docker-slim-manual.yml`

Trigger: Manual workflow dispatch (Actions tab → Docker Slim Manual → Run workflow)

Builds:
- `ghcr.io/cctry/openclaw:slim-<SHA>`
- `ghcr.io/cctry/openclaw:slim-pruned-<SHA>`

Test CI images:
```bash
docker pull ghcr.io/cctry/openclaw:slim-<SHA>
OPENCLAW_IMAGE=ghcr.io/cctry/openclaw:slim-<SHA> pnpm test:docker:live-gateway
```

## Full Documentation

See: `docs/install/docker-slim-testing.md` or https://docs.openclaw.ai/install/docker-slim-testing
