#############################################
# Builder Stage: Install dependencies and build
#############################################
FROM node:22-bookworm AS builder

# Enable corepack for pnpm support
RUN corepack enable

WORKDIR /app

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# Copy package files for dependency installation
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

# Install all dependencies (including devDependencies for build)
RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Build the application
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# Prune development dependencies to keep only production deps
RUN pnpm install --prod --frozen-lockfile

#############################################
# Runtime Stage: Minimal production image
#############################################
FROM node:22-slim AS runtime

# Install only essential runtime dependencies
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

RUN corepack enable

WORKDIR /app

# Copy production dependencies from builder
COPY --from=builder /app/node_modules ./node_modules

# Copy only essential runtime files (no docs, README, changelog, assets)
# These files save ~16MB+ in the final image
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/openclaw.mjs ./openclaw.mjs
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/extensions ./extensions
COPY --from=builder /app/skills ./skills
COPY --from=builder /app/LICENSE ./LICENSE

ENV NODE_ENV=production

# Create necessary directories for runtime
RUN mkdir -p /home/node/.openclaw /home/node/.openclaw/workspace && \
    chown -R node:node /app /home/node/.openclaw

# Security hardening: Run as non-root user
# The node:22-slim image includes a 'node' user (uid 1000)
# This reduces the attack surface by preventing container escape via root privileges
USER node

# Start gateway server with default config.
# Binds to loopback (127.0.0.1) by default for security.
#
# For container platforms requiring external health checks:
#   1. Set OPENCLAW_GATEWAY_TOKEN or OPENCLAW_GATEWAY_PASSWORD env var
#   2. Override CMD: ["node","openclaw.mjs","gateway","--allow-unconfigured","--bind","lan"]
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
