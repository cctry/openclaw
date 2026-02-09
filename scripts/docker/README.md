# Docker Slim Image Testing - Quick Reference

This is a quick reference for testing the OpenClaw Docker slim image. For full documentation, see [docs/help/testing-docker-slim.md](../docs/help/testing-docker-slim.md).

## Quick Start

```bash
# 1. Build the image
./scripts/docker-build-slim.sh openclaw:slim

# 2. Run automated tests
./scripts/test-docker-slim.sh openclaw:slim

# 3. Analyze the image
./scripts/docker-image-analyze.sh openclaw:slim
```

## Build Variants

### Standard Slim (default)
```bash
./scripts/docker-build-slim.sh openclaw:slim
```
Target: < 500MB  
Keeps: All core channel SDKs  
Use case: General deployment

### Pruned Slim (minimal)
```bash
OPENCLAW_PRUNE_EXTRA=1 ./scripts/docker-build-slim.sh openclaw:slim-pruned
```
Target: < 400MB  
Removes: Optional SDKs (Slack, LINE, Lark, Playwright, Canvas, PDF)  
Use case: Single-channel VPS or minimal deployment

## Test Scripts

| Script | Purpose | Duration |
|--------|---------|----------|
| `test-docker-slim.sh` | 12 smoke tests (CLI, deps, runtime) | ~30s |
| `docker-image-analyze.sh` | Size breakdown and recommendations | ~10s |
| `docker-build-slim.sh` | Build with validation | ~5-10min |

## Common Test Patterns

### Interactive Shell
```bash
docker run -it --rm openclaw:slim sh
```

### Gateway Test
```bash
docker run -d --name test-gateway \
  -e OPENCLAW_GATEWAY_TOKEN=test \
  openclaw:slim \
  node openclaw.mjs gateway --allow-unconfigured --bind lan

docker logs test-gateway
docker stop test-gateway && docker rm test-gateway
```

### With Config Mount
```bash
docker run -it --rm \
  -v ~/.openclaw:/home/node/.openclaw:ro \
  openclaw:slim \
  node openclaw.mjs config show
```

## GitHub Actions

Workflow: `.github/workflows/docker-slim-manual.yml`

To trigger:
1. Go to Actions tab
2. Select "Docker Slim Manual"
3. Click "Run workflow"

Images pushed to:
- `ghcr.io/<owner>/<repo>:slim-<sha>`
- `ghcr.io/<owner>/<repo>:slim-pruned-<sha>`

## Troubleshooting

### Image too large
```bash
# Check for dev dependencies
docker run --rm openclaw:slim \
  sh -c 'find /app/node_modules -name typescript -o -name vitest'

# Should return nothing
```

### Missing runtime dependencies
```bash
# Check if it was pruned
docker run --rm openclaw:slim \
  ls /app/node_modules/.pnpm | grep <package-name>
```

### Can't start gateway
```bash
# Check logs
docker run --rm openclaw:slim \
  node openclaw.mjs gateway --allow-unconfigured 2>&1 | head -50
```

## Performance Targets

| Metric | Target | Command |
|--------|--------|---------|
| Image size | < 500MB | `docker images openclaw:slim` |
| Build time (no cache) | < 10min | `time ./scripts/docker-build-slim.sh` |
| Build time (cached) | < 3min | `time ./scripts/docker-build-slim.sh` |
| Container startup | < 3s | See docs |

## Related Files

- **Dockerfile**: `Dockerfile.slim`
- **Build script**: `scripts/docker-build-slim.sh`
- **Test script**: `scripts/test-docker-slim.sh`
- **Analyze script**: `scripts/docker-image-analyze.sh`
- **Workflow**: `.github/workflows/docker-slim-manual.yml`
- **Full docs**: `docs/help/testing-docker-slim.md`

## Documentation Links

- Full guide: https://docs.openclaw.ai/help/testing-docker-slim
- General testing: https://docs.openclaw.ai/help/testing
- Docker install: https://docs.openclaw.ai/install/docker
- Submitting issues: https://docs.openclaw.ai/help/submitting-an-issue
