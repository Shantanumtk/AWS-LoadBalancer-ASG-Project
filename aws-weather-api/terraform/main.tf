terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# -------------------------------------------------------------------
# Locals: names, CIDRs, AZs (AS-IS)
# -------------------------------------------------------------------
locals {
  # Names (as in your SOP)
  vpc_name              = "wl-vpc"
  igw_name              = "wl-igw"
  eip_nat_a_name        = "wl-eip-nat-a"
  natgw_a_name          = "wl-natgw-a"
  rtb_public_name       = "wl-rtb-public"
  rtb_private_a_name    = "wl-rtb-private-a"
  rtb_private_b_name    = "wl-rtb-private-b"
  subnet_public_a_name  = "wl-subnet-public-a"
  subnet_public_b_name  = "wl-subnet-public-b"
  subnet_private_a_name = "wl-subnet-private-a"
  subnet_private_b_name = "wl-subnet-private-b"
  sg_alb_name           = "wl-sg-alb"
  sg_ec2_name           = "wl-sg-ec2"
  role_ssm_name         = "wl-role-ec2-ssm"
  lt_name               = "wl-lt"
  tg_name               = "wl-tg-5000"
  lb_name               = "wl-alb"
  asg_name              = "wl-asg"

  # CIDRs (as-is)
  vpc_cidr              = "10.20.0.0/16"
  subnet_public_a_cidr  = "10.20.1.0/24"
  subnet_public_b_cidr  = "10.20.2.0/24"
  subnet_private_a_cidr = "10.20.11.0/24"
  subnet_private_b_cidr = "10.20.12.0/24"

  # AZs (as-is)
  az_a = "us-east-1a"
  az_b = "us-east-1b"
}

# -------------------------------------------------------------------
# Networking: VPC, IGW, Subnets, NAT, Routes
# -------------------------------------------------------------------
resource "aws_vpc" "wl" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = local.vpc_name }
}

resource "aws_internet_gateway" "wl" {
  vpc_id = aws_vpc.wl.id
  tags   = { Name = local.igw_name }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.wl.id
  cidr_block              = local.subnet_public_a_cidr
  availability_zone       = local.az_a
  map_public_ip_on_launch = true
  tags                    = { Name = local.subnet_public_a_name }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.wl.id
  cidr_block              = local.subnet_public_b_cidr
  availability_zone       = local.az_b
  map_public_ip_on_launch = true
  tags                    = { Name = local.subnet_public_b_name }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.wl.id
  cidr_block        = local.subnet_private_a_cidr
  availability_zone = local.az_a
  tags              = { Name = local.subnet_private_a_name }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.wl.id
  cidr_block        = local.subnet_private_b_cidr
  availability_zone = local.az_b
  tags              = { Name = local.subnet_private_b_name }
}

# NAT (in public-a)
resource "aws_eip" "nat_a" {
  domain = "vpc"
  tags   = { Name = local.eip_nat_a_name }
}

resource "aws_nat_gateway" "a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = local.natgw_a_name }
  depends_on    = [aws_internet_gateway.wl]
}

# Route tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.wl.id
  tags   = { Name = local.rtb_public_name }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.wl.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.wl.id
  tags   = { Name = local.rtb_private_a_name }
}

resource "aws_route" "private_a_default" {
  route_table_id         = aws_route_table.private_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.a.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.wl.id
  tags   = { Name = local.rtb_private_b_name }
}

resource "aws_route" "private_b_default" {
  route_table_id         = aws_route_table.private_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.a.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}

# -------------------------------------------------------------------
# Security Groups
# -------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = local.sg_alb_name
  description = "ALB SG"
  vpc_id      = aws_vpc.wl.id

  ingress {
    description = "HTTP from anywhere"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = local.sg_alb_name }
}

resource "aws_security_group" "ec2" {
  name        = local.sg_ec2_name
  description = "EC2 SG"
  vpc_id      = aws_vpc.wl.id

  ingress {
    description     = "App from ALB"
    protocol        = "tcp"
    from_port       = 5000
    to_port         = 5000
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = local.sg_ec2_name }
}

# -------------------------------------------------------------------
# IAM: SSM role + instance profile
# -------------------------------------------------------------------
resource "aws_iam_role" "ssm" {
  name = local.role_ssm_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = local.role_ssm_name
  role = aws_iam_role.ssm.name
}

# -------------------------------------------------------------------
# AMI: Ubuntu 24.04 LTS (amd64) via SSM Parameter
# -------------------------------------------------------------------
data "aws_ssm_parameter" "ubuntu_2404_amd64" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.ubuntu_2404_amd64.value]
  }
}

# -------------------------------------------------------------------
# ALB + Target Group + Listener
# -------------------------------------------------------------------
resource "aws_lb_target_group" "wl" {
  name        = local.tg_name
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.wl.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    timeout             = 5
    matcher             = "200"
  }

  tags = { Name = local.tg_name }
}

resource "aws_lb" "wl" {
  name               = local.lb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  tags               = { Name = local.lb_name }
}

resource "aws_lb_listener" "wl_http" {
  load_balancer_arn = aws_lb.wl.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wl.arn
  }
}

# -------------------------------------------------------------------
# Launch Template (Ubuntu 24.04 + user_data.sh)
# -------------------------------------------------------------------
resource "aws_launch_template" "wl" {
  name          = local.lt_name
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  iam_instance_profile {
    name = aws_iam_instance_profile.ssm.name
  }

  vpc_security_group_ids = [aws_security_group.ec2.id]
  user_data              = base64encode(file("${path.module}/user_data.sh"))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = local.lt_name }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = local.lt_name }
  }
}

# -------------------------------------------------------------------
# Auto Scaling Group + Target Tracking (ALB RequestCountPerTarget = 50)
# -------------------------------------------------------------------
resource "aws_autoscaling_group" "wl" {
  name                      = local.asg_name
  desired_capacity          = 2
  min_size                  = 1
  max_size                  = 4
  vpc_zone_identifier       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.wl.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.wl.arn]

  tag {
    key                 = "Name"
    value               = local.asg_name
    propagate_at_launch = true
  }

  depends_on = [aws_lb_listener.wl_http]
}

resource "aws_autoscaling_policy" "tt_reqcount" {
  name                   = "${local.asg_name}-tt-reqcount"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.wl.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      # Format: app/<alb-name>/<alb-id>/targetgroup/<tg-name>/<tg-id>
      resource_label = "${aws_lb.wl.arn_suffix}/${aws_lb_target_group.wl.arn_suffix}"
    }
    target_value              = 50
  }
}
