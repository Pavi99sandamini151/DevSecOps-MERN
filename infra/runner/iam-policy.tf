# Scoped runner IAM — no AdministratorAccess (sec-iam-scope)
# Actual AWS work in CI uses OIDC roles (gitlab-ci-app-role / gitlab-ci-infra-role).
# This instance profile is for local debugging / SSM / reading TF state only.

resource "aws_iam_policy" "runner_scoped" {
  name        = "devsecops-runner-scoped-policy"
  description = "Minimal permissions for GitLab Runner EC2 host"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
        Resource = "*"
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
        Sid    = "TFStateS3"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::YOUR_TFSTATE_BUCKET",
          "arn:aws:s3:::YOUR_TFSTATE_BUCKET/*"
        ]
      },
      {
        Sid      = "AssumeRole"
        Effect   = "Allow"
        Action   = ["sts:AssumeRole", "sts:GetCallerIdentity"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "iam-policy" {
  role       = aws_iam_role.iam-role.name
  policy_arn = aws_iam_policy.runner_scoped.arn
}
