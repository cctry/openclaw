---
summary: "How to test Docker slim images locally and via GitHub Actions"
read_when:
  - Testing Docker image size optimizations
  - Validating multi-stage Docker builds
  - Running Docker image before deployment
title: "Testing Docker Slim Images"
---

# Testing Docker Slim Images

This guide covers how to test the optimized Docker image built with `Dockerfile.slim`. The slim image uses multi-stage builds to reduce the final image size to under 500MB while maintaining full functionality.

## Quick Start

Build and test locally:

```bash
# Build the slim image
./scripts/docker-build-slim.sh openclaw:slim

# Analyze the image size
./scripts/docker-image-analyze.sh openclaw:slim

# Run basic smoke test
docker run --rm openclaw:slim node openclaw.mjs --version

# Run interactive shell
docker run -it --rm openclaw:slim sh
```

## Local Testing

### 1. Build the Image

Use the build script which handles all build arguments:

```bash
# Standard build (keeps core channel SDKs)
./scripts/docker-build-slim.sh openclaw:slim

# Aggressive prune (removes optional SDKs for smaller size)
OPENCLAW_PRUNE_EXTRA=1 ./scripts/docker-build-slim.sh openclaw:slim-pruned
```

The script will:
- Build using `Dockerfile.slim`
- Show the final image size
- Compare against the 500MB target
- Provide next steps for analysis

### 2. Analyze Image Size

Run the analyzer to understand what's taking up space:

```bash
./scripts/docker-image-analyze.sh openclaw:slim
```

This shows:
- **Layer sizes** - which Dockerfile commands contribute most
- **Directory sizes** - breakdown of `/app/node_modules`, `/app/dist`, `/app/extensions`
- **Largest packages** - top 20 npm packages by size
- **Dev dependencies** - whether dev-only packages leaked into production
- **Size breakdown** - node_modules vs dist vs extensions

Key metrics to check:
- Total image size should be < 500MB
- node_modules should be the largest component (typically 200-350MB)
- No dev dependencies like `typescript`, `vitest`, `oxlint` should appear
- Dist should be relatively small (10-30MB)

### 3. Functional Testing

#### Basic CLI Smoke Test

Verify the CLI works:

```bash
# Version check
docker run --rm openclaw:slim node openclaw.mjs --version

# Help output
docker run --rm openclaw:slim node openclaw.mjs --help

# Config validation
docker run --rm openclaw:slim node openclaw.mjs doctor --help
```

#### Gateway Smoke Test

Test the gateway server:

```bash
# Start gateway in background
docker run -d \
  --name openclaw-gateway-test \
  -e OPENCLAW_GATEWAY_TOKEN=test-token-123 \
  openclaw:slim \
  node openclaw.mjs gateway --allow-unconfigured --bind lan

# Check if it's running
docker logs openclaw-gateway-test

# Health check (should show gateway info)
docker exec openclaw-gateway-test node openclaw.mjs health || echo "Expected to fail without full config"

# Cleanup
docker stop openclaw-gateway-test
docker rm openclaw-gateway-test
```

#### Interactive Testing

Launch an interactive shell to manually test:

```bash
docker run -it --rm openclaw:slim sh

# Inside container:
# Check Node version
node --version

# Check installed binaries
ls -lah /app/dist/

# Check node_modules size
du -sh /app/node_modules

# Test CLI
node openclaw.mjs --version
node openclaw.mjs models list --help

# Exit when done
exit
```

#### Volume Mount Testing

Test with mounted configuration (closer to production):

```bash
# Create test config directory
mkdir -p /tmp/openclaw-test-config

# Run with mounted config
docker run -it --rm \
  -v /tmp/openclaw-test-config:/home/node/.openclaw \
  openclaw:slim \
  node openclaw.mjs config init --help

# Cleanup
rm -rf /tmp/openclaw-test-config
```

### 4. Build Variant Comparison

Compare standard vs pruned builds:

```bash
# Build both variants
./scripts/docker-build-slim.sh openclaw:slim
OPENCLAW_PRUNE_EXTRA=1 ./scripts/docker-build-slim.sh openclaw:slim-pruned

# Compare sizes
docker images | grep openclaw

# Analyze both
./scripts/docker-image-analyze.sh openclaw:slim > /tmp/slim-analysis.txt
./scripts/docker-image-analyze.sh openclaw:slim-pruned > /tmp/slim-pruned-analysis.txt

# Compare analyses
diff /tmp/slim-analysis.txt /tmp/slim-pruned-analysis.txt
```

The pruned variant removes additional channel-specific SDKs:
- `@larksuiteoapi/node-sdk` (Feishu/Lark)
- `@line/bot-sdk` (LINE)
- `@slack/bolt` and `@slack/web-api` (Slack)
- `playwright-core` (WhatsApp Web automation)
- `@napi-rs/canvas` (image generation)
- `pdfjs-dist` (PDF processing)

Use the pruned variant if you're only using a subset of channels.

## GitHub Actions Testing

The repository includes a manual workflow for building and pushing slim images to GitHub Container Registry.

### Trigger the Workflow

1. Go to the GitHub repository
2. Navigate to **Actions** → **Docker Slim Manual**
3. Click **Run workflow**
4. Wait for the build to complete

The workflow will:
- Build two variants (slim and slim-pruned)
- Push to `ghcr.io/<owner>/<repo>:slim-<sha>` and `ghcr.io/<owner>/<repo>:slim-pruned-<sha>`
- Show image tags in the workflow summary

### Pull and Test Built Images

After the workflow completes:

```bash
# Login to GHCR (requires GitHub token with packages:read permission)
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Get the SHA from the workflow summary (short SHA, 7 characters)
SHA="abc1234"  # Replace with actual SHA from workflow

# Pull the image
docker pull ghcr.io/cctry/openclaw:slim-$SHA

# Test it
docker run --rm ghcr.io/cctry/openclaw:slim-$SHA node openclaw.mjs --version

# Analyze it
./scripts/docker-image-analyze.sh ghcr.io/cctry/openclaw:slim-$SHA
```

### Modifying the Workflow

The workflow is at `.github/workflows/docker-slim-manual.yml`. Key configuration:

```yaml
build-args: |
  OPENCLAW_PRUNE_EXTRA=${{ matrix.prune_extra }}

matrix:
  include:
    - variant: slim
      prune_extra: "0"
      docker_tag_prefix: slim
    - variant: slim-pruned
      prune_extra: "1"
      docker_tag_prefix: slim-pruned
```

To add more variants, extend the matrix. To change platforms:

```yaml
platforms: linux/amd64,linux/arm64  # Multi-arch build
```

Note: Multi-arch builds take longer but work on more platforms.

## Troubleshooting

### Image Size Too Large

If the image exceeds 500MB:

1. **Check for dev dependencies:**
   ```bash
   docker run --rm openclaw:slim sh -c 'find /app/node_modules -name "typescript" -o -name "vitest" -o -name "oxlint"'
   ```
   Should return nothing. If found, the production install leaked dev deps.

2. **Identify largest packages:**
   ```bash
   ./scripts/docker-image-analyze.sh openclaw:slim | grep "Top 20 Largest"
   ```
   Look for unexpected large packages.

3. **Check pruning worked:**
   ```bash
   docker run --rm openclaw:slim sh -c 'ls /app/node_modules/.pnpm/*node-llama-cpp* 2>/dev/null || echo "Correctly pruned"'
   ```

4. **Verify multi-stage separation:**
   ```bash
   docker run --rm openclaw:slim sh -c 'which bun'
   ```
   Should fail - Bun is only in the builder stage.

### Runtime Errors

If the container fails to start:

1. **Check Node version:**
   ```bash
   docker run --rm openclaw:slim node --version
   ```
   Should be Node 22+.

2. **Verify dist files exist:**
   ```bash
   docker run --rm openclaw:slim ls -lah /app/dist/
   ```

3. **Check permissions:**
   ```bash
   docker run --rm openclaw:slim id
   ```
   Should run as user `node` (uid 1000), not root.

4. **View logs:**
   ```bash
   docker run --rm openclaw:slim node openclaw.mjs gateway --allow-unconfigured 2>&1 | head -50
   ```

### Missing Dependencies

If runtime features are broken:

1. **Check if SDK was pruned:**
   Review `Dockerfile.slim` lines 69-78 for the `OPENCLAW_PRUNE_EXTRA` block.

2. **Verify it's a prod dependency:**
   ```bash
   grep -A 50 '"dependencies"' package.json | grep <package-name>
   ```

3. **Test with standard slim first:**
   If only fails with `slim-pruned`, the package was aggressively pruned.

## Performance Benchmarking

### Build Time

Measure build performance:

```bash
time ./scripts/docker-build-slim.sh openclaw:slim
```

Typical times:
- Full build (no cache): 5-10 minutes
- With layer cache: 1-3 minutes
- With GitHub Actions cache: 2-5 minutes

### Image Pull Time

Measure download performance:

```bash
docker rmi openclaw:slim 2>/dev/null
time docker pull ghcr.io/cctry/openclaw:slim-$SHA
```

Target: < 2 minutes on typical broadband (50 Mbps+).

### Container Startup

Measure time from `docker run` to gateway ready:

```bash
time docker run --rm \
  -e OPENCLAW_GATEWAY_TOKEN=bench \
  openclaw:slim \
  timeout 5 node openclaw.mjs gateway --allow-unconfigured --bind lan || true
```

Target: < 3 seconds to start.

## Integration with Existing Tests

The Docker slim image is compatible with existing Docker test infrastructure:

### Use Slim Image in Docker Tests

Modify test scripts to use the slim image:

```bash
# In scripts/test-live-models-docker.sh or similar
export OPENCLAW_DOCKER_IMAGE="${OPENCLAW_DOCKER_IMAGE:-openclaw:slim}"

docker run --rm \
  -v "$HOME/.openclaw:/home/node/.openclaw:ro" \
  -v "$HOME/.profile:/home/node/.profile:ro" \
  "$OPENCLAW_DOCKER_IMAGE" \
  bash -lc "pnpm test:live"
```

### Run Existing Docker Test Suites

```bash
# Build slim first
./scripts/docker-build-slim.sh openclaw:slim

# Set as default for tests
export OPENCLAW_DOCKER_IMAGE=openclaw:slim

# Run existing Docker tests
pnpm test:docker:onboard
pnpm test:docker:gateway-network
pnpm test:docker:qr
```

These tests validate:
- Onboarding wizard works
- Gateway networking (WebSocket/HTTP)
- QR code terminal rendering
- Plugin loading

## Next Steps

After validating the slim image:

1. **Update documentation** if you changed the Dockerfile
2. **Tag for release** when ready for production:
   ```bash
   docker tag openclaw:slim openclaw:stable
   docker tag openclaw:slim openclaw:v2026.2.6
   ```
3. **Update deployment configs** (docker-compose, Kubernetes, etc.)
4. **Monitor production** for any runtime issues

## Related Documentation

- [Testing](/help/testing) - Full testing suite overview
- [VPS Deployment](/vps) - Using Docker images on VPS
- [Platforms](/platforms/index) - Platform-specific deployment guides

## Feedback

If you discover issues or have suggestions for the slim image:

- Check existing issues: [GitHub Issues](https://github.com/openclaw/openclaw/issues)
- Create new issue: [Submitting an Issue](/help/submitting-an-issue)
- Submit improvements: [Submitting a PR](/help/submitting-a-pr)
