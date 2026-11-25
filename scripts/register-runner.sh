#!/usr/bin/env bash
# =============================================================================
# Register GitLab Runner on the runner EC2
# =============================================================================
# BEGINNER MAP
#   GitLab needs a machine that will RUN your jobs. That machine is the "runner".
#   This script tells gitlab-runner on the EC2: "here is my auth token, use the
#   Docker executor, mount the host Docker socket, default image = docker:27".
#
# WHY our own runner (not shared GitLab.com runners)?
#   - We mount /var/run/docker.sock to build images and start SonarQube (G2).
#   - Shared runners will not give you that socket safely.
#   - We isolate untrusted projects away from this EC2.
#
# HOW (do this once after Terraform creates the runner EC2)
#   1) GitLab → Settings → CI/CD → Runners → New project runner
#      - Tag: devsecops
#      - Untagged jobs: OFF (only tagged jobs land here)
#   2) Copy the authentication token (starts with glrt-)
#   3) SSM into the runner EC2
#   4) export RUNNER_AUTH_TOKEN=glrt-...
#   5) ./scripts/register-runner.sh
#
# NOTE about glrt- tokens
#   Tag-list / run-untagged / locked are set in the GitLab UI when you create
#   the runner. Do NOT pass --tag-list here — the new token API ignores/rejects it.
# =============================================================================
set -euo pipefail

GITLAB_URL="${GITLAB_URL:-https://gitlab.com}"
RUNNER_TOKEN="${RUNNER_AUTH_TOKEN:?Set RUNNER_AUTH_TOKEN from GitLab → Settings → CI/CD → Runners}"

# docker:27 client speaks API >= 1.44 — required by modern Docker Engine on the host.
# docker:24 fails with "client version too old" against current dockerd.
sudo gitlab-runner register \
  --non-interactive \
  --url "$GITLAB_URL" \
  --token "$RUNNER_TOKEN" \
  --executor "docker" \
  --docker-image "docker:27" \
  --docker-privileged \
  --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
  --description "devsecops-runner"

# Pick up the new config.toml and prove the runner can talk to GitLab
sudo gitlab-runner restart
sudo gitlab-runner verify
echo "Runner registered with tag: devsecops (Docker executor)"
