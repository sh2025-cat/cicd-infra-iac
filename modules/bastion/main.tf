# ===========================================
# Bastion Host Module
# ===========================================

# TLS Private Key 생성
resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# AWS Key Pair 생성
resource "aws_key_pair" "bastion" {
  key_name   = "${var.name_prefix}-bastion-key"
  public_key = tls_private_key.bastion.public_key_openssh

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-key"
  })
}

# Private Key를 로컬에 저장
resource "local_file" "private_key" {
  content         = tls_private_key.bastion.private_key_pem
  filename        = "${var.private_key_path}/bastion-key.pem"
  file_permission = "0400"
}

# 최신 Amazon Linux 2 AMI 조회
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Bastion Host EC2 Instance
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.bastion.key_name
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y mysql
              EOF

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion"
  })
}

# Elastic IP for Bastion
resource "aws_eip" "bastion" {
  count    = var.allocate_eip ? 1 : 0
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-eip"
  })
}
