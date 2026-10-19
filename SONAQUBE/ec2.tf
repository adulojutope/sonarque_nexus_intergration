provider "aws" {
  region  = "us-east-1"
  profile = "chris"
}

variable "my_ip_cidr" {
  description = "CIDR allowed to reach SSH and SonarQube. Use YOUR.IP/32 when possible."
  default     = "0.0.0.0/0"
}

# default vpc (adopts the existing one)
resource "aws_default_vpc" "default_vpc" {
  tags = { Name = "default vpc" }
}

data "aws_availability_zones" "available_zones" {}

# default subnet (adopts the existing one)
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]
  tags              = { Name = "default subnet" }
}

resource "aws_security_group" "ec2_security_group_sonarqube" {
  name        = "ec2-security-group-sonarqube"
  description = "allow access on ports 9000 and 22"
  vpc_id      = aws_default_vpc.default_vpc.id

  ingress {
    description = "sonarqube access"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sonarqube server security group" }
}

# Ubuntu 22.04 (jammy), pinned
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "ec2_instance" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.medium" # 4 GB RAM, the minimum I'd use
  subnet_id                   = aws_default_subnet.default_az1.id
  vpc_security_group_ids      = [aws_security_group.ec2_security_group_sonarqube.id]
  associate_public_ip_address = true
  key_name                    = "demo1"

  # replace() strips Windows CRLF line endings
  user_data                   = replace(file("${path.module}/install_sonarqube.sh"), "\r\n", "\n")
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = { Name = "sonarqube_server" }
}

output "website_url" {
  value = "http://${aws_instance.ec2_instance.public_dns}:9000"
}