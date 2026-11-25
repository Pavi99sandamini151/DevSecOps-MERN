resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.ami.image_id
  instance_type          = var.instance_type
  key_name               = var.key-name != "" ? var.key-name : null
  subnet_id              = aws_subnet.public-subnet.id
  vpc_security_group_ids = [aws_security_group.security-group.id]
  iam_instance_profile   = aws_iam_instance_profile.instance-profile.name

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
    encrypted   = true
  }

  # Enforce IMDSv2 (sec-imdsv2)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  user_data = file("${path.module}/install-tools.sh")

  tags = {
    Name = var.instance-name
  }
}

output "runner_public_ip" {
  value = aws_instance.ec2.public_ip
}

output "runner_instance_id" {
  value = aws_instance.ec2.id
}

output "sonarqube_url" {
  value = "http://${aws_instance.ec2.public_ip}:9000"
}
