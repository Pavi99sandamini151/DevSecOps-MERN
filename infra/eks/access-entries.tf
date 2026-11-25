# Allow jump host instance role to use kubectl/helm against the private API
resource "aws_eks_access_entry" "jump" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.jump.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "jump_admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.jump.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.jump]
}
