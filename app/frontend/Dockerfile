# =============================================================================
# Frontend production image (multi-stage)
# =============================================================================
# BEGINNER MAP
#   Stage "build"  → CRA build (react-scripts) → static files in /build.
#   Stage final    → install ONLY `serve` (with overrides) + static files.
#                    Then DELETE the bundled npm CLI so Trivy does not fail on
#                    npm's own deps (pacote / sigstore / ip-address).
#
# WHY strip npm from the runtime image?
#   node:*-alpine ships npm. Trivy node-pkg scans every package.json in the
#   image — including /usr/local/lib/node_modules/npm. We never call npm at
#   runtime, so removing it shrinks the attack surface and clears false-ish CVEs.
# =============================================================================

FROM node:22-alpine@sha256:1314fb30ec37592d5845e5a160d522c0e680972aa534549940b8d73bde88481a AS build
WORKDIR /usr/src/app
RUN apk update && apk upgrade --no-cache
COPY package*.json ./
RUN npm ci
COPY . .
# CRA bakes REACT_APP_BACKEND_URL into the JS here. The pod env in
# k8s/frontend/deployment.yaml is too late — this image only serves static files.
RUN npm run build

FROM node:22-alpine@sha256:1314fb30ec37592d5845e5a160d522c0e680972aa534549940b8d73bde88481a
WORKDIR /usr/src/app

RUN apk update && apk upgrade --no-cache

# Minimal runtime package — not the CRA package.json (avoids shipping react-scripts)
COPY serve-package.json package.json
RUN npm install --omit=dev \
  && npm cache clean --force \
  && rm -rf /usr/local/lib/node_modules/npm \
            /usr/local/lib/node_modules/corepack \
            /root/.npm \
  && rm -f /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack

COPY --from=build --chown=node:node /usr/src/app/build ./build
RUN chown -R node:node /usr/src/app

USER node
EXPOSE 3000
# Use the local bin — global npm install is gone on purpose
CMD ["./node_modules/.bin/serve", "-s", "build", "-l", "3000"]
