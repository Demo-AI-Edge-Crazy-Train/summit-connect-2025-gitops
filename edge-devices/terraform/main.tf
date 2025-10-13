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

##
## Variables
##

variable "machine_count" {
  type    = number
  default = 1
}

variable "tag_name" {
  type    = string
  default = "crazy-train-lab"
}

variable "route53_zone" {
  type = string
}

##
## Common resources
##

resource "aws_vpc" "common" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.tag_name
  }
}

resource "aws_internet_gateway" "common" {
  vpc_id = aws_vpc.common.id
  tags = {
    Name = var.tag_name
  }
}

resource "aws_key_pair" "admin" {
  key_name   = "crazy-train-lab"
  public_key = file("~/.ssh/id_ed25519.pub")
  tags = {
    Name = var.tag_name
  }
}

resource "aws_subnet" "common" {
  vpc_id                  = aws_vpc.common.id
  cidr_block              = "172.16.10.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.tag_name}-common"
  }
}

resource "aws_route_table" "common" {
  vpc_id = aws_vpc.common.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.common.id
  }

  tags = {
    Name = "${var.tag_name}-common"
  }
}

resource "aws_route_table_association" "common" {
  subnet_id      = aws_subnet.common.id
  route_table_id = aws_route_table.common.id
}

##
## Bastion host
##

data "aws_ami" "rhel" {
  most_recent = true

  filter {
    name   = "name"
    values = ["RHEL-9.6.0_HVM-*-arm64-*-Hourly2-GP3"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  owners = ["309956199498"] # amazon
}

resource "aws_security_group" "lab_bastion" {
  vpc_id = aws_vpc.common.id

  ingress {
    description = "Incoming SSH connection"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Incoming HTTP connection"
    from_port   = 9090
    to_port     = 9090
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
    Name = "${var.tag_name}-bastion"
  }
}

resource "aws_instance" "lab_bastion" {
  ami                         = data.aws_ami.rhel.id
  instance_type               = "m6g.large"
  key_name                    = aws_key_pair.admin.key_name
  subnet_id                   = aws_subnet.common.id
  depends_on                  = [aws_internet_gateway.common]
  vpc_security_group_ids      = [aws_security_group.lab_bastion.id]
  user_data                   = filebase64("cloud-init/user-data.yaml")
  associate_public_ip_address = true

  credit_specification {
    cpu_credits = "unlimited"
  }

  root_block_device {
    volume_size = 100
  }

  tags = {
    Name = "${var.tag_name}-bastion"
  }
}

resource "aws_eip" "lab_bastion" {
  instance = aws_instance.lab_bastion.id
  vpc      = true

  tags = {
    Name = var.tag_name
  }
}

data "aws_route53_zone" "lab_zone" {
  name         = var.route53_zone
  private_zone = false
}

resource "aws_route53_record" "lab_bastion" {
  zone_id = data.aws_route53_zone.lab_zone.zone_id
  name    = "crazy-train-lab.${var.route53_zone}"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.lab_bastion.public_ip]
}

output "public_ip" {
  value = aws_instance.lab_bastion.public_ip
}

output "domain_name" {
  value = aws_route53_record.lab_bastion.fqdn
}

##
## Edge devices
##

data "aws_ami" "bootc_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["crazy-train-lab-edge-device-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  owners = ["self"]
}

resource "aws_subnet" "edge_devices" {
  vpc_id     = aws_vpc.common.id
  cidr_block = "172.16.20.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.tag_name}-edge-devices"
  }
}

resource "aws_route_table" "edge_devices" {
  vpc_id = aws_vpc.common.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.edge_devices.id
  }

  tags = {
    Name = "${var.tag_name}-edge-devices"
  }
}

resource "aws_route_table_association" "edge_devices" {
  subnet_id      = aws_subnet.edge_devices.id
  route_table_id = aws_route_table.edge_devices.id
}

resource "aws_nat_gateway" "edge_devices" {
  allocation_id = aws_eip.edge_devices.id
  subnet_id     = aws_subnet.common.id

  tags = {
    Name = "${var.tag_name}-edge-devices"
  }

  depends_on = [aws_internet_gateway.common]
}

resource "aws_eip" "edge_devices" {
  vpc      = true

  tags = {
    Name = "${var.tag_name}-edge-devices"
  }
}

resource "aws_security_group" "edge_device" {
  vpc_id = aws_vpc.common.id

  ingress {
    description = "Incoming SSH connection"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/16"]
  }

  egress {
    description = "Outgoing connections"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tag_name}-edge-device"
  }
}

resource "aws_instance" "edge_device" {
  ami                         = data.aws_ami.bootc_ami.id
  instance_type               = "m6g.large"
  subnet_id                   = aws_subnet.edge_devices.id
  vpc_security_group_ids      = [aws_security_group.edge_device.id]
  associate_public_ip_address = false
  depends_on                  = [aws_internet_gateway.common]

  credit_specification {
    cpu_credits = "unlimited"
  }

  root_block_device {
    volume_size = 50
  }

  tags = {
    Name = "${var.tag_name}-edge-device-${count.index + 1}"
  }

  count = var.machine_count
}

output "edge_devices_ip" {
  value = aws_instance.edge_device.*.private_ip
}
