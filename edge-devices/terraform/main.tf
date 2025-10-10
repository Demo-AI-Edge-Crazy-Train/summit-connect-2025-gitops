terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.34.0"
    }
  }
}

provider "aws" {
  region = "eu-west-3"
}

provider "aws" {
  region = "us-east-1"
  alias  = "aws-us"
}

data "aws_ami" "fedora" {
  provider    = aws.aws-us
  most_recent = true

  filter {
    name   = "name"
    values = ["Fedora-Cloud-Base-36*x86_64-hvm-*-gp2-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["125523088429"] # Fedora
}

resource "aws_ami_copy" "lab_ami" {
  name              = "Fedora-Cloud-Base-36.x86_64-hvm-eu-west-3-gp2-0"
  description       = "A copy of Fedora-Cloud-Base-36-20221013.0.x86_64-hvm-us-east-1-gp2-0"
  source_ami_id     = data.aws_ami.fedora.id
  source_ami_region = "us-east-1"

  tags = {
    Name = "crazy-train-edge-lab"
  }
}

resource "aws_vpc" "lab_vpc" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "crazy-train-edge-lab"
  }
}

resource "aws_subnet" "lab_subnet" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "172.16.10.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "crazy-train-edge-lab"
  }
}

resource "aws_route_table" "lab_route" {
  vpc_id = aws_vpc.lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_gw.id
  }

  tags = {
    Name = "crazy-train-edge-lab"
  }
}

resource "aws_route_table_association" "lab_rta" {
  subnet_id      = aws_subnet.lab_subnet.id
  route_table_id = aws_route_table.lab_route.id
}

resource "aws_security_group" "lab_podman" {
  vpc_id = aws_vpc.lab_vpc.id

  ingress {
    description = "Incoming SSH connection"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outgoing connections"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "crazy-train-edge-lab"
  }
}

resource "aws_internet_gateway" "lab_gw" {
  vpc_id = aws_vpc.lab_vpc.id
  tags = {
    Name = "crazy-train-edge-lab"
  }
}

resource "aws_key_pair" "admin" {
  key_name   = "lab-podman-nmasse@redhat.com"
  public_key = file("~/.ssh/id_ed25519.pub")
  tags = {
    Name = "crazy-train-edge-lab"
  }
}

resource "aws_instance" "lab_podman" {
  ami                         = aws_ami_copy.lab_ami.id
  instance_type               = "m5a.4xlarge"
  key_name                    = aws_key_pair.admin.key_name
  subnet_id                   = aws_subnet.lab_subnet.id
  depends_on                  = [aws_internet_gateway.lab_gw]
  vpc_security_group_ids      = [aws_security_group.lab_podman.id]
  user_data                   = filebase64("cloud-init/user-data.yaml.gz")
  associate_public_ip_address = true

  credit_specification {
    cpu_credits = "unlimited"
  }

  root_block_device {
    volume_size = 100
  }

  tags = {
    Name = "crazy-train-edge-lab"
  }
}

output "public_ip" {
  value = aws_instance.lab_podman.public_ip
}
