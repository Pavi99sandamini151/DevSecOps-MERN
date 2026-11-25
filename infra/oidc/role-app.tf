# =============================================================================
# App CI IAM role (AWS_ROLE_ARN in GitLab)
# =============================================================================
# BEGINNER MAP
#   This role is what frontend/backend jobs assume via OIDC.
#   It can push to ECR and do light EKS describe — NOT create VPCs or delete EKS.
#   Infra Terraform uses a SEPARATE role (role-infra.tf) — least privilege (C2).
#
# WHY StringLike on gitlab.com:sub = …ref:main?
#   Feature branches / forks cannot steal this role even if they run CI.
# =============================================================================
resource "aws_iam_role" "gitlab_ci_app" {
  name = "gitlab-ci-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.gitlab.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "gitlab.com:aud" = var.gitlab_oidc_audience
        }
        StringLike = {
          "gitlab.com:sub" = local.sub_main
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "gitlab_ci_app" {
  name = "gitlab-ci-app-policy"
  role = aws_iam_role.gitlab_ci_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:ListImages",
          "ecr:DescribeImageScanFindings"
        ]
        Resource = [
          "arn:aws:ecr:${var.region}:*:repository/frontend",
          "arn:aws:ecr:${var.region}:*:repository/backend"
        ]
      },
      {
        Sid    = "EKSDescribe"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3StateRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::YOUR_TFSTATE_BUCKET",
          "arn:aws:s3:::YOUR_TFSTATE_BUCKET/*"
        ]
      }
    ]
  })
}
