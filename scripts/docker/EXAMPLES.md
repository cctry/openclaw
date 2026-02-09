# Docker Slim Testing Examples

This file contains example workflows for testing the OpenClaw Docker slim image in different scenarios.

## Example 1: First-time Build and Test

```bash
#!/bin/bash
# Complete workflow for building and testing a new slim image

set -e

# 1. Build the image
echo "Building slim image..."
./scripts/docker-build-slim.sh openclaw:slim

# 2. Run automated smoke tests
echo "Running smoke tests..."
./scripts/test-docker-slim.sh openclaw:slim

# 3. Analyze size breakdown
echo "Analyzing image..."
./scripts/docker-image-analyze.sh openclaw:slim

# 4. Manual functional test
echo "Testing CLI version..."
docker run --rm openclaw:slim node openclaw.mjs --version

echo "All tests passed!"
```

## Example 2: Compare Standard vs Pruned

```bash
#!/bin/bash
# Build both variants and compare

set -e

# Build standard
./scripts/docker-build-slim.sh openclaw:slim

# Build pruned
OPENCLAW_PRUNE_EXTRA=1 ./scripts/docker-build-slim.sh openclaw:slim-pruned

# Compare sizes
echo "Size comparison:"
docker images | grep openclaw | grep slim

# Test both
./scripts/test-docker-slim.sh openclaw:slim
./scripts/test-docker-slim.sh openclaw:slim-pruned

# Analyze difference
echo "Standard packages:"
docker run --rm openclaw:slim du -sh /app/node_modules/.pnpm/*slack* 2>/dev/null || echo "None"

echo "Pruned packages:"
docker run --rm openclaw:slim-pruned du -sh /app/node_modules/.pnpm/*slack* 2>/dev/null || echo "None (pruned)"
```

## Example 3: Test with Real Config

```bash
#!/bin/bash
# Test with mounted OpenClaw configuration

set -e

# Build
./scripts/docker-build-slim.sh openclaw:slim

# Create test config
TEST_DIR="/tmp/openclaw-test-$$"
mkdir -p "$TEST_DIR"

# Test config initialization
docker run --rm \
  -v "$TEST_DIR:/home/node/.openclaw" \
  openclaw:slim \
  sh -c "echo 'Testing config mount' && ls -la /home/node/.openclaw"

# Test with real config (if available)
if [ -d "$HOME/.openclaw" ]; then
  echo "Testing with real config..."
  docker run --rm \
    -v "$HOME/.openclaw:/home/node/.openclaw:ro" \
    openclaw:slim \
    node openclaw.mjs models list 2>&1 | head -20
fi

# Cleanup
rm -rf "$TEST_DIR"
```

## Example 4: Gateway Integration Test

```bash
#!/bin/bash
# Test gateway server functionality

set -e

IMAGE="openclaw:slim"
CONTAINER_NAME="openclaw-gateway-test-$$"

# Build
./scripts/docker-build-slim.sh "$IMAGE"

# Start gateway
echo "Starting gateway..."
docker run -d \
  --name "$CONTAINER_NAME" \
  -e OPENCLAW_GATEWAY_TOKEN=test-token-123 \
  -e NODE_ENV=production \
  "$IMAGE" \
  node openclaw.mjs gateway --allow-unconfigured --bind lan

# Wait for startup
sleep 3

# Check logs
echo "Gateway logs:"
docker logs "$CONTAINER_NAME" 2>&1 | tail -20

# Test health endpoint (expected to fail without full config)
echo "Testing health check..."
docker exec "$CONTAINER_NAME" node openclaw.mjs health || echo "Expected: health check requires configuration"

# Check process
echo "Gateway process:"
docker exec "$CONTAINER_NAME" ps aux | grep node

# Cleanup
echo "Cleaning up..."
docker stop "$CONTAINER_NAME"
docker rm "$CONTAINER_NAME"

echo "Gateway test complete!"
```

## Example 5: CI/CD Integration

```bash
#!/bin/bash
# Example CI pipeline for Docker slim image

set -e

# Environment variables (set in CI)
: "${GITHUB_SHA:=$(git rev-parse HEAD)}"
: "${SHORT_SHA:=${GITHUB_SHA:0:7}}"
: "${REGISTRY:=ghcr.io}"
: "${IMAGE_NAME:=openclaw/openclaw}"

# Build
echo "Building image for CI..."
docker build \
  -f Dockerfile.slim \
  -t "${REGISTRY}/${IMAGE_NAME}:slim-${SHORT_SHA}" \
  --build-arg OPENCLAW_PRUNE_EXTRA=0 \
  .

# Test
echo "Running smoke tests..."
./scripts/test-docker-slim.sh "${REGISTRY}/${IMAGE_NAME}:slim-${SHORT_SHA}"

# Size validation
echo "Validating size..."
SIZE_MB=$(docker images "${REGISTRY}/${IMAGE_NAME}:slim-${SHORT_SHA}" --format "{{.Size}}" | grep -oE '^[0-9]+')
if [ "$SIZE_MB" -gt 500 ]; then
  echo "ERROR: Image size ${SIZE_MB}MB exceeds 500MB limit"
  exit 1
fi

# Push (if authenticated)
if [ -n "$GITHUB_TOKEN" ]; then
  echo "Pushing to registry..."
  echo "$GITHUB_TOKEN" | docker login "$REGISTRY" -u "$GITHUB_ACTOR" --password-stdin
  docker push "${REGISTRY}/${IMAGE_NAME}:slim-${SHORT_SHA}"
  echo "Pushed: ${REGISTRY}/${IMAGE_NAME}:slim-${SHORT_SHA}"
fi
```

## Example 6: Debugging Image Issues

```bash
#!/bin/bash
# Debug workflow when tests fail

set -e

IMAGE="${1:-openclaw:slim}"

echo "=== Debugging Docker Image ==="
echo "Image: $IMAGE"
echo ""

# Check if image exists
if ! docker image inspect "$IMAGE" &>/dev/null; then
  echo "ERROR: Image not found. Build it first:"
  echo "  ./scripts/docker-build-slim.sh $IMAGE"
  exit 1
fi

# Show image details
echo "Image size:"
docker images "$IMAGE" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
echo ""

# Check Node version
echo "Node version:"
docker run --rm "$IMAGE" node --version
echo ""

# Check user
echo "Running as user:"
docker run --rm "$IMAGE" id
echo ""

# Check OpenClaw CLI
echo "OpenClaw version:"
docker run --rm "$IMAGE" node openclaw.mjs --version || echo "FAILED"
echo ""

# Check directory structure
echo "Directory structure:"
docker run --rm "$IMAGE" sh -c "
  echo '/app:'
  ls -lah /app | head -20
  echo ''
  echo '/app/dist:'
  ls -lah /app/dist | head -10
  echo ''
  echo 'node_modules size:'
  du -sh /app/node_modules
"
echo ""

# Check for dev dependencies
echo "Checking for dev dependencies (should be empty):"
docker run --rm "$IMAGE" sh -c '
  find /app/node_modules -maxdepth 3 -name typescript -o -name vitest -o -name oxlint
' || echo "None found (good)"
echo ""

# Interactive shell for manual inspection
echo "Launching interactive shell..."
echo "Commands to try:"
echo "  - node openclaw.mjs --help"
echo "  - ls -la /app/"
echo "  - du -sh /app/node_modules/.pnpm/* | sort -hr | head -20"
echo "  - exit"
echo ""
docker run -it --rm "$IMAGE" sh
```

## Example 7: Automated Regression Testing

```bash
#!/bin/bash
# Run full regression suite on slim image

set -e

IMAGE="${1:-openclaw:slim}"

echo "Running regression tests on $IMAGE"
echo ""

# Build if not exists
if ! docker image inspect "$IMAGE" &>/dev/null; then
  echo "Building image..."
  ./scripts/docker-build-slim.sh "$IMAGE"
fi

# 1. Smoke tests
echo "1. Running smoke tests..."
./scripts/test-docker-slim.sh "$IMAGE"
echo ""

# 2. CLI commands
echo "2. Testing CLI commands..."
COMMANDS=(
  "--version"
  "--help"
  "config --help"
  "gateway --help"
  "models --help"
  "health --help"
)

for cmd in "${COMMANDS[@]}"; do
  echo "  Testing: openclaw $cmd"
  docker run --rm "$IMAGE" node openclaw.mjs $cmd >/dev/null 2>&1 || echo "  FAILED: $cmd"
done
echo ""

# 3. Size check
echo "3. Size validation..."
SIZE=$(docker images "$IMAGE" --format "{{.Size}}")
echo "  Image size: $SIZE"
./scripts/docker-image-analyze.sh "$IMAGE" | grep -A 5 "Size Breakdown Summary"
echo ""

# 4. Startup time
echo "4. Startup time test..."
time docker run --rm "$IMAGE" node openclaw.mjs --version >/dev/null
echo ""

echo "All regression tests completed!"
```

## Running Examples

To run any example:

```bash
# Copy the example to a file
cat > test-example.sh << 'EOF'
# ... paste example here ...
EOF

# Make executable
chmod +x test-example.sh

# Run it
./test-example.sh
```

Or run directly:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/openclaw/openclaw/main/scripts/docker/examples.md | sed -n '/Example 1/,/```$/p' | tail -n +3 | head -n -1)"
```

## Related Documentation

- Full testing guide: [docs/help/testing-docker-slim.md](../../docs/help/testing-docker-slim.md)
- Quick reference: [scripts/docker/README.md](README.md)
- Main testing docs: [docs/help/testing.md](../../docs/help/testing.md)
