# Design decisions — why + practice

This page records **why** each major choice was made and which **practice** it follows.
Use it when explaining the stack in interviews or onboarding.

| Code | Practice (short) |
|---|---|
| C1 | GitOps — desired state in git; CD reconciles cluster |
| C2 | Least privilege — separate IAM roles for app vs infra CI |
| C3 | OIDC federation — no long-lived AWS access keys in CI |
| C4 | Shift-left security — SAST/secrets/deps/image scans fail the pipeline |
| C5 | Immutable artifacts — ECR tags never overwritten; Cosign attest |
| C6 | Loop prevention — `[skip ci]` on gitops manifest commits |
| C7 | Manual gates for destructive / costly infra (`tf-apply` / `tf-destroy`) |
| C8 | Path filters on jobs — only rebuild what changed |
| C9 | Fail-closed security — `allow_failure: false` on scanners |
| C10 | Defense in depth — private EKS, WAF, NetworkPolicy, Kyverno, non-root |
| G2 | Docker executor + socket — required for Docker build & GitLab security templates |
| G10 | Persistent SonarQube volumes — analysis history survives runner reboot |

---

## Architecture & branching

### Separate `main` (code/CI) and `gitops` (deploy)

- **Why:** Keeps application PRs reviewable without mixing generated image-tag commits. ArgoCD only watches deployable manifests.
- **Practice:** C1 GitOps + C6 loop prevention (`[skip ci]` on gitops pushes).

### ArgoCD over `kubectl apply` from CI

- **Why:** CI should build/push/sign; cluster state should converge from git (audit trail, drift detection, self-heal).
- **Practice:** C1; sync `prune: false` so a bad sync cannot wipe unrelated resources.

---

## Identity & AWS access

### GitLab OIDC → two IAM roles

- **Why:** Static `AWS_ACCESS_KEY_ID` in GitLab is a high-value secret that rarely rotates. OIDC issues a short-lived JWT per job.
- **Practice:** C3 OIDC; C2 least privilege — `AWS_ROLE_ARN` (ECR/app) vs `AWS_INFRA_ROLE_ARN` (Terraform).

### Trust limited to `ref:main`

- **Why:** Forks / feature branches cannot assume the production roles.
- **Practice:** C2 / C3 — condition on `gitlab.com:sub` project path + branch.

---

## Runner & SonarQube

### Dedicated tagged runner (`devsecops`), not shared runners

- **Why:** Shared runners cannot mount the host Docker socket reliably, and you do not want untrusted projects on your EC2.
- **Practice:** G2 Docker executor; tag isolation.

### SonarQube on the runner host (port 9000)

- **Why:** Self-hosted quality gate without depending on SonarCloud; same machine as CI for low latency.
- **Practice:** G10 persistent volumes; SG locked to your IP (C10).

### Jobs reach Sonar via Docker host network (`127.0.0.1:9000`)

- **Why:** GitLab **project** `SONAR_HOST_URL` (public IP) overrides job YAML and times out from inside job containers (SG / hairpin NAT).
- **Practice:** Prefer host-local reachability for co-located services; do not rely on public IP from sibling containers.

### Docker client image `docker:27` (not `24`)

- **Why:** Host Docker Engine requires API ≥ 1.44; `docker:24` client fails with “client version too old”.
- **Practice:** Keep client/daemon API compatible.

---

## CI pipeline design

### Infra jobs only on `infra/**` changes (or `RUN_INFRA=true`)

- **Why:** Manual `tf-init` used to block **every** app pipeline (stage ordering). App pushes must not wait on Terraform.
- **Practice:** C7 + C8; empty stages are skipped when no infra jobs are created.

### App job variables under `.frontend_rules` / `.backend_rules` (not file top-level)

- **Why:** GitLab merges include-level `variables:`; last include wins. Backend overwrote `APP_DIR`, so frontend Trivy scanned the backend.
- **Practice:** Scope variables to the job/template that owns them (C8 correctness).

### `needs: []` on early app/security jobs

- **Why:** Even if a leftover manual infra job appears, Sonar/OWASP/Trivy/SAST can start immediately.
- **Practice:** Explicit DAG over implicit stage waits.

### Tool downloads cached under `.ci-cache/`

- **Why:** Fresh Docker job containers have no host tools; re-downloading OWASP/Trivy/Cosign/Terraform every pipeline wastes 10–30+ minutes.
- **Practice:** Cache immutable tool versions; still allow NVD/Trivy DB incremental updates.

### OWASP Dependency-Check 12.x + 60m timeout + `--nvdValidForHours`

- **Why:** 10.0.4 hit NVD URL column bugs; first NVD sync is large. Reuse DB for a week after a good sync.
- **Practice:** C4 shift-left; pin fixed tool versions.

### Trivy `--exit-code 1` for CRITICAL/HIGH + `--ignore-unfixed`

- **Why:** Fail the pipeline on actionable vulns; ignore findings with no upstream fix (noise).
- **Practice:** C4 / C9 fail-closed.

### Cosign keyless + Kyverno verify

- **Why:** Prove images were signed in CI without managing Cosign private keys in GitLab.
- **Practice:** C5 immutable/signed supply chain; C10 admission control.

### ECR immutable tags = `$CI_PIPELINE_IID`

- **Why:** `latest` is mutable and breaks provenance; pipeline IID is stable and unique per pipeline.
- **Practice:** C5.

---

## Cluster / runtime

### Private EKS + jump host (SSM)

- **Why:** No public API endpoint reduces attack surface; SSM avoids SSH keys in the wild.
- **Practice:** C10 defense in depth.

### WAFv2 on ALB, NetworkPolicies, non-root, PDBs

- **Why:** Layered controls — edge, east-west, container, availability.
- **Practice:** C10.

---

## What we deliberately do **not** do

| Anti-pattern | Why avoided |
|---|---|
| Long-lived AWS keys in GitLab | Secret sprawl; C3 |
| Auto `tf-apply` on every push | Accidental cluster changes; C7 |
| Scanning/deploying from `main` manifests only | Mixes code review with deploy noise; C1 |
| `allow_failure: true` on scanners | Creates a false sense of security; C9 |
| Commenting app `frontend`/`backend` **source** (JS/JSX) for CI rationale | Keep app code clean; beginner teach-comments live in `docs/`, `ci/*.yml`, Dockerfiles, and scripts |
