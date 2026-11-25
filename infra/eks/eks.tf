# =============================================================================
# EKS control plane
# =============================================================================
# BEGINNER MAP
#   aws_eks_cluster = the managed Kubernetes API server (control plane).
#   Worker nodes are separate (see node-group.tf).
#
# WHY endpoint_public_access = false?
#   Nobody on the internet can hit the API. Only the jump host SG can (C10).
#   That is why kubectl from your laptop times out — use SSM → jump instead.
#
# WHY encryption_config on "secrets"?
#   etcd stores Kubernetes Secrets. KMS encrypts them at rest so a stolen etcd
#   snapshot is not plain-text passwords.
# =============================================================================
resource "aws_security_group" "eks_cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS cluster security group"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-cluster-sg" }
}

# Private API: allow kubectl/helm from jump host (fixes dial tcp :443 i/o timeout)
resource "aws_security_group_rule" "cluster_api_from_jump" {
  type                     = "ingress"
  description              = "Jump host to EKS API"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.jump.id
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  # Control plane logging (sec-eks-logs)
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  # Encrypt Kubernetes Secrets at rest in etcd (sec-kms-etcd)
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_cloudwatch_log_group.eks_cluster
  ]
}

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 30
}

# OIDC provider for IRSA (ALB controller, etc.)
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}
