# Runner EC2 configuration

Terraform module: [`infra/runner/`](../infra/runner/)

## Why a dedicated runner

Shared GitLab runners cannot safely expose your host Docker socket, and you do not want untrusted projects on an EC2 that also hosts SonarQube.

**Practice:** G2 (Docker executor + socket), tag `devsecops` isolation.

## What `infra/runner/install-tools.sh` installs

GitLab Runner, Docker, SonarQube (persistent volumes), AWS CLI, kubectl, eksctl, Terraform, Trivy, Helm, sonar-scanner, Cosign, OWASP Dependency-Check, Node.js 18, jq.

**Note:** CI jobs use the **Docker executor**, so host-installed CLIs are **not** visible inside job containers. App/infra jobs therefore use job images + `.ci-cache/` (see `docs/11` and `docs/16`). Host tools still help SSM debugging and SonarQube itself.

## IMDSv2 verification

**Why:** Force session tokens for instance metadata — mitigates SSRF credential theft (C10).

```bash
# Should fail / 401 without token
curl -s -o /dev/null -w "%{http_code}\n" http://169.254.169.254/latest/meta-data/
```

## SonarQube first login

**Why on the runner:** Self-hosted quality gate with low latency to CI; persistent volumes keep history (G10).

1. Open `http://<runner-ip>:9000`
2. Default `admin` / `admin` — change password immediately
3. Create projects: `three-tier-frontend`, `three-tier-backend`
4. Generate user token → GitLab `SONAR_TOKEN` (Masked + Protected)
5. Configure Quality Gate conditions (bugs/vulns/coverage as needed)

**CI reachability:** Jobs talk to Sonar on `http://127.0.0.1:9000` via Docker `--network host`. Do not rely on the public IP from inside job containers (SG / hairpin). Keep GitLab `SONAR_HOST_URL` for humans/docs if useful; scanner jobs override locally.

## Docker executor config

`/etc/gitlab-runner/config.toml` must mount the host Docker socket (required for SAST templates and docker build) — **G2**:

```toml
[[runners]]
  executor = "docker"
  [runners.docker]
    image = "docker:27"
    privileged = true
    volumes = ["/var/run/docker.sock:/var/run/docker.sock", "/cache"]
```

Use a client image whose API matches the host daemon (≥ 1.44 → `docker:27`).

## Security group

| Port | Source | Purpose |
|---|---|---|
| 22 | your IP | SSH (prefer SSM) |
| 9000 | your IP/VPN | SonarQube |
| egress all | — | tool downloads / AWS APIs |
