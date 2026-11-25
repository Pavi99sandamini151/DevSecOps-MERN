#!/bin/bash
# =============================================================================
# Bootstrap tools on the GitLab Runner EC2 (user-data / SSM)
# =============================================================================
# BEGINNER MAP
#   This script runs ONCE on the runner EC2 (or when you re-bootstrap it).
#   It installs everything a human operator + the GitLab Runner service need:
#     - Docker            → so the Docker executor can start job containers
#     - gitlab-runner     → the agent that polls GitLab for jobs
#     - SonarQube         → long-lived quality-gate server on :9000
#     - CLIs              → kubectl, terraform, helm, … for YOU over SSM
#
# IMPORTANT mental model
#   Tools installed HERE live on the HOST.
#   CI *jobs* still start in fresh Docker containers and do NOT see these
#   binaries automatically. Job containers get tools via:
#     - their `image:` (e.g. aquasec/trivy), or
#     - downloads into `.ci-cache/` (see ci/tools-cache.gitlab-ci.yml).
#   Host tools are for SSM debugging and for services like SonarQube.
#
# PRACTICE
#   G2  — Docker + socket for executor jobs
#   G10 — SonarQube named volumes survive reboot
#   C10 — pair with IMDSv2 + tight SG on :9000 (only your IP)
# =============================================================================
set -euxo pipefail

# Ubuntu 22.04 — GitLab Runner EC2 bootstrap
export DEBIAN_FRONTEND=noninteractive

# ----- Base OS packages -----
apt-get update -y
apt-get install -y openjdk-17-jre openjdk-17-jdk curl unzip wget gnupg lsb-release \
  apt-transport-https ca-certificates jq software-properties-common

# ----- Docker (required by GitLab Docker executor — G2) -----
# Jobs use this daemon via the mounted socket /var/run/docker.sock
apt-get install -y docker.io
systemctl enable --now docker
usermod -aG docker ubuntu
# Lab convenience: allow non-root docker. Tighten for stricter environments.
chmod 666 /var/run/docker.sock || true

# ----- GitLab Runner binary + service user -----
# This is the agent that heartbeats to gitlab.com and starts job containers.
curl -L --output /usr/local/bin/gitlab-runner \
  https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64
chmod +x /usr/local/bin/gitlab-runner
useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash || true
usermod -aG docker gitlab-runner
gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner || true
gitlab-runner start || true

# ----- SonarQube (co-located quality gate — G10) -----
# Named volumes keep analysis history across container recreate / reboot.
# CI jobs reach this via --network host → http://127.0.0.1:9000
docker volume create sonarqube_data || true
docker volume create sonarqube_logs || true
docker volume create sonarqube_extensions || true
docker rm -f sonarqube 2>/dev/null || true
docker run -d \
  --name sonarqube \
  --restart=always \
  -p 9000:9000 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_logs:/opt/sonarqube/logs \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  sonarqube:lts-community

# ----- AWS CLI v2 (SSM / ECR / EKS from the host) -----
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -qo /tmp/awscliv2.zip -d /tmp
/tmp/aws/install --update
rm -rf /tmp/aws /tmp/awscliv2.zip

# ----- kubectl (talk to the cluster from SSM; jump host is preferred for private API) -----
curl -LO "https://dl.k8s.io/release/v1.28.4/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# ----- eksctl (IRSA / addon helpers used in docs and post-setup) -----
curl --silent --location \
  "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" \
  | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin/

# ----- Terraform (optional host copy for manual infra debug) -----
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update -y
apt-get install -y terraform

# ----- Trivy (host copy for SSM; CI jobs use image or .ci-cache binary) -----
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" \
  | tee -a /etc/apt/sources.list.d/trivy.list
apt-get update -y
apt-get install -y trivy

# ----- Helm (install charts during eks-post-setup / debugging) -----
snap install helm --classic || curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ----- Sonar Scanner CLI (host debug; CI prefers the scanner Docker image) -----
SONAR_SCANNER_VERSION=5.0.1.3006
wget -q "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux.zip" -O /tmp/sonar-scanner.zip
unzip -qo /tmp/sonar-scanner.zip -d /opt
ln -sfn "/opt/sonar-scanner-${SONAR_SCANNER_VERSION}-linux/bin/sonar-scanner" /usr/local/bin/sonar-scanner
rm -f /tmp/sonar-scanner.zip

# ----- Cosign (host copy for SSM verify; CI caches its own binary — C5) -----
COSIGN_VERSION=v2.4.1
curl -sL "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64" \
  -o /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign

# ----- OWASP Dependency-Check (host copy; CI uses .ci-cache + DC 12.x — C4) -----
DC_VERSION=12.1.0
wget -q "https://github.com/jeremylong/DependencyCheck/releases/download/v${DC_VERSION}/dependency-check-${DC_VERSION}-release.zip" \
  -O /tmp/dependency-check.zip
unzip -qo /tmp/dependency-check.zip -d /opt
ln -sfn /opt/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check
rm -f /tmp/dependency-check.zip

# ----- Node.js 18 (npm audit / local debugging on the runner) -----
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# ----- Sanity check: print versions so bootstrap logs prove success -----
echo "=== Tool versions ==="
java -version || true
docker --version || true
gitlab-runner --version || true
aws --version || true
kubectl version --client || true
eksctl version || true
terraform version || true
trivy --version || true
helm version || true
cosign version || true
sonar-scanner --version || true
dependency-check --version || true
jq --version || true
node --version || true
