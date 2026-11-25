region        = "us-east-1"
vpc-name      = "devsecops-runner-vpc"
igw-name      = "devsecops-runner-igw"
subnet-name   = "devsecops-runner-subnet"
rt-name       = "devsecops-runner-rt"
sg-name       = "devsecops-runner-sg"
instance-name = "devsecops-gitlab-runner"
key-name      = "" # SSM only — no EC2 key pair
iam-role      = "devsecops-runner-role"
instance_type = "t3.large" # 2 vCPU (was t3.xlarge/4) — frees quota for 2nd EKS node
# Replace with your public IP/32 before apply (SonarQube :9000). Documentation range only.
allowed_cidr = "203.0.113.10/32"
