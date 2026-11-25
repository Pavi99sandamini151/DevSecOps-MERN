# =============================================================================
# Infra CI IAM role (AWS_INFRA_ROLE_ARN in GitLab)
# =============================================================================
# BEGINNER MAP
#   Only Terraform jobs (ci/infra.gitlab-ci.yml) assume this role.
#   It can manage VPC/EKS/etc. App docker-build jobs must NEVER use it (C2).
#   Same OIDC trust as the app role: only main branch of this project (C3).
# =============================================================================
resource "aws_iam_role" "gitlab_ci_infra" {
  name = "gitlab-ci-infra-role"

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
          # Restrict to main; job-level naming is enforced in CI (tf-apply)
          "gitlab.com:sub" = local.sub_main
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "gitlab_ci_infra" {
  name = "gitlab-ci-infra-policy"
  role = aws_iam_role.gitlab_ci_infra.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSFull"
        Effect = "Allow"
        Action = ["eks:*"]
        Resource = "*"
      },
      {
        Sid    = "EC2Networking"
        Effect = "Allow"
        Action = [
          "ec2:*Vpc*",
          "ec2:*Subnet*",
          "ec2:*Gateway*",
          "ec2:*Route*",
          "ec2:*SecurityGroup*",
          "ec2:*NetworkAcl*",
          "ec2:*Address*",
          "ec2:*NatGateway*",
          "ec2:*LaunchTemplate*",
          "ec2:*Instance*",
          "ec2:Describe*",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:RunInstances",
          "ec2:CreateFlowLogs",
          "ec2:DeleteFlowLogs",
          "ec2:*VpcEndpoint*"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMScoped"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:PassRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:ListInstanceProfiles",
          "iam:TagInstanceProfile",
          "iam:UntagInstanceProfile",
          "iam:GetOpenIDConnectProvider",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "*"
      },
      {
        Sid    = "TFState"
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          "arn:aws:s3:::YOUR_TFSTATE_BUCKET",
          "arn:aws:s3:::YOUR_TFSTATE_BUCKET/*",
          "arn:aws:s3:::devsecops-*",
          "arn:aws:s3:::devsecops-*/*"
        ]
      },
      {
        Sid    = "ECRManage"
        Effect = "Allow"
        Action = ["ecr:*"]
        Resource = "*"
      },
      {
        # Required for aws_ecr_registry_scanning_configuration scan_type = ENHANCED
        Sid    = "Inspector2ForECR"
        Effect = "Allow"
        Action = [
          "inspector2:Enable",
          "inspector2:Disable",
          "inspector2:List*",
          "inspector2:Get*",
          "inspector2:BatchGet*",
          "inspector2:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid    = "KMS"
        Effect = "Allow"
        Action = ["kms:*"]
        Resource = "*"
      },
      {
        Sid    = "CloudTrail"
        Effect = "Allow"
        Action = ["cloudtrail:*", "logs:*", "cloudwatch:*"]
        Resource = "*"
      },
      {
        Sid    = "WAF"
        Effect = "Allow"
        Action = ["wafv2:*"]
        Resource = "*"
      },
      {
        Sid    = "Autoscaling"
        Effect = "Allow"
        Action = ["autoscaling:*", "elasticloadbalancing:*"]
        Resource = "*"
      },
      {
        Sid      = "STS"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      }
    ]
  })
}
