#########################################
# main.tf
#########################################

# Provider setup
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "aws" {
  region = var.aws_region
}

#########################################
# Security Group
#########################################

resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP and SSH inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ⚠️ For testing; narrow to your IP in production
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

#########################################
# IAM Role + Policy + Instance Profile
#########################################

resource "aws_iam_role" "ec2_role" {
  name = "ec2-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "s3_access_policy" {
  name = "s3-access-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

#########################################
# S3 Bucket
#########################################

resource "aws_s3_bucket" "project_bucket" {
  bucket = "tech-challenge3-${random_id.bucket_id.hex}"

  tags = {
    Name = "tech-challenge3-bucket"
  }
}

resource "random_id" "bucket_id" {
  byte_length = 3
}

#########################################
# EC2 Instance
#########################################

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "default" {
  filter {
    name   = "availability-zone"
    values = ["us-east-2a"]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = data.aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # ✅ Associate existing key pair
  key_name = "Keypair1"

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install nginx -y
              systemctl start nginx
              systemctl enable nginx
              echo "<h1>Hello, World!</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "Tech-Challenge3-WebServer"
  }
}