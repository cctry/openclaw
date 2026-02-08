#!/usr/bin/env bash
# Docker Image Size Analyzer for OpenClaw
# Usage: ./scripts/docker-image-analyze.sh [IMAGE_NAME]
#
# This script analyzes a Docker image and provides a detailed breakdown of:
# - Layer sizes and commands
# - Directory sizes inside the container
# - Largest npm packages
# - Recommendations for size reduction

set -euo pipefail

IMAGE_NAME="${1:-openclaw:analyze}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Docker Image Size Analyzer${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if image exists
if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo -e "${RED}Error: Image '$IMAGE_NAME' not found${NC}"
    echo "Build it first: docker build -t $IMAGE_NAME ."
    exit 1
fi

# Get total image size
TOTAL_SIZE=$(docker images "$IMAGE_NAME" --format "{{.Size}}")
echo -e "${GREEN}Total Image Size:${NC} ${YELLOW}$TOTAL_SIZE${NC}"
echo ""

# Layer analysis
echo -e "${BLUE}Top 15 Largest Layers:${NC}"
echo "----------------------------------------"
docker history "$IMAGE_NAME" --no-trunc --format "{{.Size}}\t{{.CreatedBy}}" 2>/dev/null | \
grep -v "^0B" | \
sort -hr | \
head -15 | \
while IFS=$'\t' read -r size cmd; do
    # Truncate long commands
    cmd_short=$(echo "$cmd" | cut -c1-80)
    if [ ${#cmd} -gt 80 ]; then
        cmd_short="${cmd_short}..."
    fi
    printf "%-10s %s\n" "$size" "$cmd_short"
done
echo ""

# Directory sizes inside container
echo -e "${BLUE}Directory Sizes Inside Container:${NC}"
echo "----------------------------------------"
docker run --rm "$IMAGE_NAME" sh -c '
  echo "Key directories:"
  for dir in /app/node_modules /app/dist /app/extensions; do
    if [ -d "$dir" ]; then
      size=$(du -sh "$dir" 2>/dev/null | cut -f1)
      printf "%-12s %s\n" "$size" "$dir"
    fi
  done
  echo ""
  echo "System directories:"
  for dir in /usr/local/lib/node_modules /root/.bun /usr/lib /var/cache; do
    if [ -d "$dir" ]; then
      size=$(du -sh "$dir" 2>/dev/null | cut -f1)
      printf "%-12s %s\n" "$size" "$dir"
    fi
  done
' 2>/dev/null || echo "(Could not analyze - container may not have du command)"
echo ""

# Largest npm packages (pnpm-specific)
echo -e "${BLUE}Top 20 Largest npm Packages:${NC}"
echo "----------------------------------------"
docker run --rm "$IMAGE_NAME" sh -c '
  if [ -d /app/node_modules/.pnpm ]; then
    du -sh /app/node_modules/.pnpm/* 2>/dev/null | sort -hr | head -20
  else
    du -sh /app/node_modules/* 2>/dev/null | sort -hr | head -20
  fi
' 2>/dev/null || echo "(Could not analyze)"
echo ""

# Dev vs Prod dependencies analysis
echo -e "${BLUE}Dev Dependencies Analysis:${NC}"
echo "----------------------------------------"
docker run --rm "$IMAGE_NAME" sh -c '
  dev_deps="typescript oxlint vitest esbuild rolldown tsdown node-llama-cpp"
  total_dev=0
  for pkg in $dev_deps; do
    size=$(du -sh /app/node_modules/.pnpm/*"$pkg"* 2>/dev/null | awk "{sum+=\$1} END {print sum}" || echo 0)
    if [ -n "$size" ] && [ "$size" != "0" ]; then
      echo "  ${pkg}: found"
    fi
  done
' 2>/dev/null || echo "(Could not analyze)"
echo ""

# Size breakdown summary
echo -e "${BLUE}Size Breakdown Summary:${NC}"
echo "----------------------------------------"
docker run --rm "$IMAGE_NAME" sh -c '
  # Get sizes in MB for comparison
  nm_size=$(du -sm /app/node_modules 2>/dev/null | cut -f1 || echo 0)
  dist_size=$(du -sm /app/dist 2>/dev/null | cut -f1 || echo 0)
  ext_size=$(du -sm /app/extensions 2>/dev/null | cut -f1 || echo 0)

  total=$((nm_size + dist_size + ext_size))

  echo "node_modules:  ${nm_size}MB"
  echo "dist:          ${dist_size}MB"
  echo "extensions:    ${ext_size}MB"
  echo "-------------------"
  echo "App total:     ~${total}MB"
' 2>/dev/null || echo "(Could not analyze)"
echo ""

# Recommendations
echo -e "${BLUE}Recommendations:${NC}"
echo "----------------------------------------"
echo "1. Use multi-stage build to separate build and runtime"
echo "2. Install only root package prod deps (pnpm --filter openclaw...)"
echo "3. Install only production dependencies in final stage"
echo "4. Remove optional heavy deps: node-llama-cpp/CUDA/musl artifacts"
echo "5. Use --chown flag in COPY instead of separate RUN chown"
echo "6. Remove Bun from runtime if not needed"
echo "7. For single-channel VPS use, try OPENCLAW_PRUNE_EXTRA=1 in Dockerfile.slim (also prunes playwright-core/pdfjs/canvas)"
echo ""
echo -e "${GREEN}Run ./scripts/docker-build-slim.sh to build an optimized image${NC}"
