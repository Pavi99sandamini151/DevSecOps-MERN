# GitLab CI pipelines (beginner walkthrough)

See also [`16-design-decisions.md`](./16-design-decisions.md) for the full why/practice catalog.

Teaching comments also live **inside** the YAML/scripts themselves
(`.gitlab-ci.yml`, `ci/*.yml`, Dockerfiles, `scripts/*`). Read those files top-to-bottom —
every stage has a "BEGINNER MAP / WHAT / WHY" block.

## Big picture in one sentence

On every push to `main` that touches the app, we **scan → build → push → sign → tell GitOps**.
ArgoCD (not CI) is what actually changes the cluster.

```
code push (main)
  → Sonar + quality gate
  → OWASP + npm audit
  → Trivy filesystem
  → docker build
  → ECR push (tag = pipeline IID)
  → Trivy image + Cosign sign
  → commit new image to `gitops` branch  [skip ci]
       ↓
ArgoCD notices gitops change → rolls out pods
```

## Root `.gitlab-ci.yml`

**What:** Declares global `stages`, includes local CI files + GitLab security templates, hardens `secret_detection` / `semgrep-sast`.

**Why:** One entrypoint for the whole DevSecOps pipeline; security templates need a Docker executor (G2).

**Practice:** C4 / C9 — scanners use `allow_failure: false` and `tags: [devsecops]`. Path filters live on **jobs**, not on `include:` (C8).

### Why so many stages?

Stages are the columns in the GitLab UI. We keep infra stages (`init`…`destroy`) and app stages in one list so one project has one pipeline view. Empty infra stages disappear when no infra jobs are created.

## Include layout

| File | Role | Beginner tip |
|---|---|---|
| `ci/tools-cache.gitlab-ci.yml` | Shared tool versions + `.ci-cache/` paths | Jobs start empty — cache stops re-downloading tools |
| `ci/infra.gitlab-ci.yml` | Terraform for `infra/eks` (gated) | Only appears when infra changes |
| `ci/frontend.gitlab-ci.yml` | React DevSecOps chain | Path-filtered to `app/frontend/**` |
| `ci/backend.gitlab-ci.yml` | API DevSecOps chain | Path-filtered to `app/backend/**` |
| GitLab Secret-Detection / SAST | Built-in analyzers | Overridden to `tags: [devsecops]` + fail-closed |

## Frontend / backend stages (detail)

| Stage | What a beginner should picture | Why it exists | Practice |
|---|---|---|---|
| `sonarqube-analysis` | A code review bot reads your source | Catch bugs/smells before packaging | C4 |
| `quality-gate` | Wait until Sonar says PASS or FAIL | "Scan finished" ≠ "quality OK" | C4 / C9 |
| `owasp-dependency-check` | Check npm libs against known CVEs | Most vulns come from dependencies | C4 |
| `trivy-file-scan` | Scan lockfiles / source tree | Fail before wasting a docker build | C4 / C9 |
| `docker-build` | Bake a container image | Reproducible runtime artifact | C5 |
| `ecr-push` | Upload image tagged with pipeline IID | Immutable tags (never `latest`) | C5 |
| `trivy-image-scan` | Scan the *pushed* image layers | Base OS CVEs appear only here | C4 / C9 |
| `image-sign` | Cosign keyless signature | Kyverno can refuse unsigned images | C5 / C10 |
| `update-manifest` | Rewrite Deployment image on `gitops` | CD from git, not from CI kubectl | C1 / C6 |

### Important implementation notes (gotchas we already hit)

- **Job-scoped variables** (`APP_DIR`, `SONAR_PROJECT_KEY`, …) live under `.frontend_rules` / `.backend_rules`. Top-level include variables collide (last wins) and caused frontend jobs to scan backend paths.
- **Sonar from CI** starts/uses the host `sonarqube` container and scans with `--network host` → `http://127.0.0.1:9000` (public `SONAR_HOST_URL` times out from job net).
- **Tool caches** under `.ci-cache/` avoid re-downloading Trivy/Cosign/OWASP/Terraform every run.
- Early jobs use `needs: []` so they are not blocked by manual Terraform jobs.
- Frontend `npm audit` uses `--omit=dev` because CRA/`react-scripts` stays in `devDependencies` and never ships in the multi-stage image.
- Dockerfiles reuse the image's `node` user (uid 1000) — do not `addgroup -g 1000`.

## Infinite loop prevention (C6)

Manifest commit message includes `[skip ci]` and pushes to **`gitops`** only.
Without `[skip ci]`, the push would start another pipeline → another manifest commit → forever.

## Infra stages (`ci/infra.gitlab-ci.yml`)

```
tf-init (manual) → tf-validate → tf-plan → tf-apply (manual) / tf-destroy (manual)
```

**Why gated:** Terraform apply/destroy is costly and destructive (C7). App pushes must not wait on `tf-init`.

**When jobs appear:**

- `main` + changes under `infra/**` or `ci/infra.gitlab-ci.yml`, or
- **Run pipeline** with variable `RUN_INFRA=true`

**Auth:** `AWS_INFRA_ROLE_ARN` via OIDC (C2 / C3).

**Image:** `ubuntu:24.04` + cached official Terraform/AWS CLI binaries (Alpine HashiCorp images break AWS CLI / entrypoint).

## How to read the comments in the repo

| Location | What the comments teach |
|---|---|
| `.gitlab-ci.yml` | Stage list meaning + security template overrides |
| `ci/frontend.gitlab-ci.yml` / `ci/backend.gitlab-ci.yml` | Each job: WHAT it does, WHY that order, common pitfalls |
| `ci/infra.gitlab-ci.yml` | Manual gates, OIDC bootstrap, plan→apply safety |
| `ci/tools-cache.gitlab-ci.yml` | Why job containers need `.ci-cache/` |
| `app/*/Dockerfile` | Multi-stage / non-root / digest pinning |
| `scripts/*.sh` / `infra/runner/install-tools.sh` | Operator runbooks step-by-step |

App **source** (`index.js`, React components) stays free of CI commentary on purpose —
rationale lives in `docs/` + infra/CI/Dockerfiles so application code stays readable.
