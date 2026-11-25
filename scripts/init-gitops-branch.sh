#!/usr/bin/env bash
# Create and push the gitops branch (G8 / C1)
set -euo pipefail

git checkout main
git pull --ff-only origin main || true
git checkout -B gitops
git push -u origin gitops
echo "gitops branch created and pushed. ArgoCD should watch targetRevision: gitops"
