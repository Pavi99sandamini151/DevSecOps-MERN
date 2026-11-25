resource "aws_iam_instance_profile" "instance-profile" {
  name = "devsecops-runner-instance-profile"
  role = aws_iam_role.iam-role.name
}

# SSM Session Manager access (prefer over SSH)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.iam-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
