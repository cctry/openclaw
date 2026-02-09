#!/usr/bin/env bash
# Quick smoke test for Docker slim image
# Usage: ./scripts/test-docker-slim.sh [IMAGE_NAME]
#
# This script runs a series of quick validation tests on the slim Docker image

set -euo pipefail

IMAGE_NAME="${1:-openclaw:slim}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Docker Slim Image Smoke Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Testing image: ${YELLOW}$IMAGE_NAME${NC}"
echo ""

# Check if image exists
if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo -e "${RED}Error: Image '$IMAGE_NAME' not found${NC}"
    echo "Build it first: ./scripts/docker-build-slim.sh $IMAGE_NAME"
    exit 1
fi

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

run_test() {
    local test_name="$1"
    local test_cmd="$2"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    echo -n "Test $TESTS_TOTAL: $test_name... "
    
    if eval "$test_cmd" &>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "Running smoke tests..."
echo ""

# Test 1: Node version
run_test "Node version check" \
    "docker run --rm $IMAGE_NAME node --version | grep -q '^v22'"

# Test 2: CLI version
run_test "CLI version command" \
    "docker run --rm $IMAGE_NAME node openclaw.mjs --version"

# Test 3: CLI help
run_test "CLI help command" \
    "docker run --rm $IMAGE_NAME node openclaw.mjs --help | grep -q 'OpenClaw'"

# Test 4: User is non-root
run_test "Running as non-root user" \
    "docker run --rm $IMAGE_NAME id -u | grep -q '^1000$'"

# Test 5: Dist directory exists
run_test "Built artifacts exist" \
    "docker run --rm $IMAGE_NAME test -d /app/dist"

# Test 6: Node modules exist
run_test "Production dependencies exist" \
    "docker run --rm $IMAGE_NAME test -d /app/node_modules"

# Test 7: No dev dependencies (TypeScript)
run_test "No TypeScript in prod" \
    "! docker run --rm $IMAGE_NAME sh -c 'find /app/node_modules -name typescript' 2>/dev/null | grep -q typescript"

# Test 8: No dev dependencies (Vitest)
run_test "No Vitest in prod" \
    "! docker run --rm $IMAGE_NAME sh -c 'find /app/node_modules -name vitest' 2>/dev/null | grep -q vitest"

# Test 9: No Bun in runtime (build-only)
run_test "No Bun in runtime" \
    "! docker run --rm $IMAGE_NAME which bun 2>/dev/null"

# Test 10: Gateway command exists
run_test "Gateway command available" \
    "docker run --rm $IMAGE_NAME node openclaw.mjs gateway --help | grep -q 'gateway'"

# Test 11: Config init command
run_test "Config init command available" \
    "docker run --rm $IMAGE_NAME node openclaw.mjs config --help | grep -q 'config'"

# Test 12: Models command
run_test "Models command available" \
    "docker run --rm $IMAGE_NAME node openclaw.mjs models --help | grep -q 'models'"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Show image size
SIZE=$(docker images "$IMAGE_NAME" --format "{{.Size}}")
echo -e "Image size: ${YELLOW}$SIZE${NC}"
echo ""

echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC} / $TESTS_TOTAL"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
fi
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Analyze image details: ./scripts/docker-image-analyze.sh $IMAGE_NAME"
    echo "  2. Run interactive shell: docker run -it --rm $IMAGE_NAME sh"
    echo "  3. Test with config mount: docker run -it --rm -v ~/.openclaw:/home/node/.openclaw:ro $IMAGE_NAME node openclaw.mjs config show"
    echo ""
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    echo ""
    echo "Debugging steps:"
    echo "  1. Check logs: docker run --rm $IMAGE_NAME node openclaw.mjs --version 2>&1"
    echo "  2. Inspect container: docker run -it --rm $IMAGE_NAME sh"
    echo "  3. Rebuild: ./scripts/docker-build-slim.sh $IMAGE_NAME"
    echo ""
    exit 1
fi
