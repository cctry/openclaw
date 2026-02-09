#!/bin/bash

# build the image
# docker build -f Dockerfile.slim -t openclaw:test-slim .

# Use a Docker volume for .openclaw to avoid host permission issues in Codespace

VOLUME_NAME="openclaw-test-data"

# Custom OpenAI-compatible API endpoint

# Create the volume if it doesn't exist
docker volume create "$VOLUME_NAME" || true

docker run --rm -p 18789:18789 \
--user root \
-e HOME=/root \
-e OPENCLAW_DEV=1 \
-e OPENCLAW_GATEWAY_MODE=local \
-e OPENCLAW_GATEWAY_TOKEN=test-token-12345 \
-e OPENAI_API_BASE="${OPENAI_API_BASE}" \
-e OPENAI_API_KEY="${OPENAI_API_KEY}" \
-e OPENAI_MODEL="${OPENAI_MODEL}" \
-v "$VOLUME_NAME:/root/.openclaw" \
-v "$(pwd)/openclaw.json:/root/.openclaw/openclaw.json" \
openclaw:test-slim \
node openclaw.mjs gateway --bind lan --port 18789

# GitHub Codespace will auto-forward port 18789
# Look for the port forwarding notification or check the Ports tab
# Access token: test-token-12345

# To approve devices (run in another terminal while gateway is running):
# 1. List pending devices:
#    docker exec -it $(docker ps -q --filter ancestor=openclaw:test-slim) node openclaw.mjs devices list
#
# 2. Approve a device (copy the Request ID from step 1):
#    docker exec -it $(docker ps -q --filter ancestor=openclaw:test-slim) node openclaw.mjs devices approve <requestId>
#
# 3. Refresh your browser and it should connect!

# Enable plugin
# docker exec -it $(docker ps -q --filter ancestor=openclaw:test-slim)   node openclaw.mjs plugins enable telegram
