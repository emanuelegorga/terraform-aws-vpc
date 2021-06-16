provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {}
}

data "terraform_remote_state" "network_configuration" {
  backend = "s3"

  config {
    bucket = var.remote_state_bucket
    key    = var.remote_state_key
    region = var.region
  }
}

resource "aws_security_group" "ec2_public_security_group" {
  name = "EC2-Public-SG"
  description = "Internet reaching access for EC2 instances"
  vpc_id = data.terraform_remote_state.network_configuration.vpc_id

  ingress {
    from_port = 80
    protocol = "TCP"
    to_port = 80
    cidr_blocks = [0.0.0.0/0]
  }

  ingress {
    from_port = 22
    protocol = "TCP"
    to_port = 22
    cidr_blocks = [2.44.140.117/32]
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = [0.0.0.0/0]
  }
}

resource "aws_security_group" "ec2_private_security_group" {
  name = "EC2-Private-SG"
  description = "Only allow public SG resources to access these instances"
  vpc_id = data.terraform_remote_state.network_configuration.vpc_id

  ingress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = [aws_security_group.ec2_public_security_group.id]
  }

  ingress {
    from_port = 80
    protocol = "TCP"
    to_port = 80
    cidr_blocks = [0.0.0.0/0]
    description = "Allow health checking for instances using this SG"
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = [0.0.0.0/0]
  }
}

resource "aws_security_group" "elb_security_group" {
  name = "ELB-SG"
  description = "ELB Security Group"
  vpc_id = data.terraform_remote_state.network_configuration.vpc_id

  ingress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = [0.0.0.0/0]
    description = "Allow web traffic to load balancer"
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = [0.0.0.0/0]
  }
}

resource "aws_iam_role" "ec2_iam_role" {
  name               = "EC2-IAM-Role"
  assume_role_policy = <<EOF
{
  "Version" : "2012-10-17",
  "Statement" : [
    {
      "Effect" : "Allow",
      "Principal" : {
        "Service" : ["ec2.amazonaws.com", "application-autoscaling.amazonaws.com"]
      },
      "Action" : "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ec2_iam_role_policy" {
  name   = "EC2-IAM-Policy"
  role   = aws_iam_role.ec2_iam_role.id
  policy = <<EOF
{
  "Version" : "2012-10-17",
  "Statement" : [
    {
      "Effect" : "Allow",
      "Action" : [
        "ec2:*",
        "elasticloadbalancing:*",
        "cloudwatch:*",
        "logs:*"
      ],
      "Resource" : "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "EC2-IAM-Instance-Profile"
  role = aws_iam_role.ec2_iam_role.name
}

data "aws_ami" "launch_configuration_ami" {
  most_recent = true

  filter {
    name = "owner-alias"
    values = [amazon]
  }

  owners = [amazon]
}




