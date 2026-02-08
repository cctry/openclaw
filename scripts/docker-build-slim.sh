#!/usr/bin/env bash
# Build optimized Docker image for OpenClaw
# Usage: ./scripts/docker-build-slim.sh [tag]
#
# This builds a minimal Docker image (~500MB target) using multi-stage build

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

TAG="${1:-openclaw:slim}"
DOCKERFILE="${ROOT_DIR}/Dockerfile.slim"
PRUNE_EXTRA="${OPENCLAW_PRUNE_EXTRA:-0}"

echo "Building optimized Docker image..."
echo "  Tag: $TAG"
echo "  Dockerfile: $DOCKERFILE"
echo "  OPENCLAW_PRUNE_EXTRA: $PRUNE_EXTRA"
echo ""

# Build with progress
docker build \
  -f "$DOCKERFILE" \
  -t "$TAG" \
  --build-arg "OPENCLAW_PRUNE_EXTRA=$PRUNE_EXTRA" \
  --progress=plain \
  "$ROOT_DIR"

echo ""
echo "Build complete!"
echo ""

# Show size
SIZE=$(docker images "$TAG" --format "{{.Size}}")
echo "Final image size: $SIZE"
echo ""

# Parse size and normalize to MB without requiring bc.
SIZE_VALUE=$(printf '%s' "$SIZE" | grep -oE '^[0-9]+([.][0-9]+)?' || echo "0")
SIZE_UNIT=$(printf '%s' "$SIZE" | grep -oE '[A-Za-z]+$' || echo "MB")
SIZE_MB=$(awk -v value="$SIZE_VALUE" -v unit="$SIZE_UNIT" '
  BEGIN {
    if (unit == "GB") { print value * 1024; exit }
    if (unit == "MB") { print value; exit }
    if (unit == "kB" || unit == "KB") { print value / 1024; exit }
    print value
  }
')

if awk -v mb="$SIZE_MB" 'BEGIN { exit !(mb < 500) }'; then
  echo "Target achieved: Image is under 500MB."
else
  printf 'Target not met: %.2fMB (goal: <500MB).\n' "$SIZE_MB"
fi

echo ""
echo "To analyze the image in detail, run:"
echo "  ./scripts/docker-image-analyze.sh $TAG"
echo ""
echo "To run the container:"
echo "  docker run -it --rm $TAG"
