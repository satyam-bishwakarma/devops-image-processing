terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "region" {
  type    = string
  default = "ap-southeast-2"
}

variable "instance_type" {
  type    = string
  default = "c7i-flex.large"
}

provider "aws" {
  region              = var.region
  allowed_account_ids = ["936990071991"]

  default_tags {
    tags = {
      Project   = "devops-image-processing"
      ManagedBy = "terraform"
    }
  }
}

data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/noble/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

data "aws_partition" "current" {}

resource "aws_vpc" "project" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "project" {
  vpc_id     = aws_vpc.project.id
  cidr_block = "10.20.1.0/24"
}

resource "aws_internet_gateway" "project" {
  vpc_id = aws_vpc.project.id
}

resource "aws_route_table" "project" {
  vpc_id = aws_vpc.project.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.project.id
  }
}

resource "aws_route_table_association" "project" {
  subnet_id      = aws_subnet.project.id
  route_table_id = aws_route_table.project.id
}

resource "aws_security_group" "node" {
  for_each    = toset(["automation", "cluster"])
  name_prefix = "image-processing-${each.key}-"
  description = "Image processing ${each.key} hosts"
  vpc_id      = aws_vpc.project.id
}

resource "aws_vpc_security_group_egress_rule" "outbound" {
  for_each          = aws_security_group.node
  security_group_id = each.value.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "cluster_peer" {
  for_each = {
    api     = { protocol = "tcp", port = 6443 }
    kubelet = { protocol = "tcp", port = 10250 }
    flannel = { protocol = "udp", port = 8472 }
  }

  security_group_id            = aws_security_group.node["cluster"].id
  referenced_security_group_id = aws_security_group.node["cluster"].id
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.port
  to_port                      = each.value.port
}

resource "aws_vpc_security_group_ingress_rule" "automation_to_api" {
  security_group_id            = aws_security_group.node["cluster"].id
  referenced_security_group_id = aws_security_group.node["automation"].id
  ip_protocol                  = "tcp"
  from_port                    = 6443
  to_port                      = 6443
}

resource "aws_iam_role" "ec2_ssm" {
  name = "image-processing-ec2-ssm"
  path = "/devops-image-processing/"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "image-processing-ec2-ssm"
  path = "/devops-image-processing/"
  role = aws_iam_role.ec2_ssm.name
}

resource "aws_instance" "project" {
  for_each = {
    automation = "automation"
    k3s-server = "cluster"
    k3s-worker = "cluster"
  }

  ami                         = data.aws_ssm_parameter.ubuntu.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.project.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.node[each.value].id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "image-processing-${each.key}" }

  depends_on = [aws_iam_role_policy_attachment.ec2_ssm, aws_route_table_association.project]
}

output "hosts" {
  value = {
    for name, host in aws_instance.project : name => {
      instance_id = host.id
      private_ip  = host.private_ip
    }
  }
}

resource "aws_iam_role_policy" "k3s_join_token" {
  name = "image-processing-k3s-join-token"
  role = aws_iam_role.ec2_ssm.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ssm:GetParameter"
      Resource = "arn:${data.aws_partition.current.partition}:ssm:${var.region}:936990071991:parameter/devops-image-processing/k3s/join-token"
    }]
  })
}
