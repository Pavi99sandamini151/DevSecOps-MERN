# =============================================================================
# Backend API image (Node / Express)
# =============================================================================
# BEGINNER MAP
#   1) Patched node:22-alpine + apk upgrade (OS CVEs).
#   2) npm ci --omit=dev with package.json overrides for nested HIGH CVEs.
#   3) Remove bundled npm/corepack — not needed at runtime; Trivy was failing
#      on pacote/sigstore inside the npm CLI itself.
#   4) Run as uid 1000 (`node`) to match k8s securityContext.
# =============================================================================

FROM node:22-alpine@sha256:1314fb30ec37592d5845e5a160d522c0e680972aa534549940b8d73bde88481a

WORKDIR /usr/src/app

RUN apk update && apk upgrade --no-cache

COPY package*.json ./
RUN npm ci --omit=dev \
  && npm cache clean --force \
  && rm -rf /usr/local/lib/node_modules/npm \
            /usr/local/lib/node_modules/corepack \
            /root/.npm \
  && rm -f /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack

COPY . .
RUN chown -R node:node /usr/src/app

USER node
EXPOSE 3500 9090

CMD ["node", "-r", "./tracing.js", "index.js"]
