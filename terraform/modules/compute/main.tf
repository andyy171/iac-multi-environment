# Data source for latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Data source for current AWS region
data "aws_region" "current" {}

# Data source for current AWS caller identity
data "aws_caller_identity" "current" {}

# Key Pair for EC2 instances
resource "aws_key_pair" "main" {
  key_name   = "${var.environment}-keypair"
  public_key = var.public_key

  tags = merge(var.common_tags, {
    Name = "${var.environment}-keypair"
  })
}

# Launch Template for Auto Scaling 
resource "aws_launch_template" "web" {
  name_prefix   = "${var.environment}-web-"
  description   = "Launch template for ${var.environment} web servers"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.main.key_name

  vpc_security_group_ids = var.security_group_ids

  # User data script for initial setup
  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh", {
    environment = var.environment
    region     = data.aws_region.current.name
  }))

  # Instance metadata service configuration
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  # EBS configuration
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_type           = var.root_volume_type
      volume_size           = var.root_volume_size
      delete_on_termination = true
      encrypted             = true
    }
  }

  # Network interface configuration
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups            = var.security_group_ids
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.common_tags, {
      Name        = "${var.environment}-web-instance"
      Environment = var.environment
      Ansible     = "web"
      Backup      = var.environment == "prod" ? "enabled" : "disabled"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.common_tags, {
      Name        = "${var.environment}-web-volume"
      Environment = var.environment
    })
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-web-launch-template"
  })
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  name                = "${var.environment}-web-asg"
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = var.target_group_arns
  health_check_type   = length(var.target_group_arns) > 0 ? "ELB" : "EC2"
  health_check_grace_period = 300

  min_size         = var.min_instances
  max_size         = var.max_instances
  desired_capacity = var.desired_instances

  # Launch template configuration
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  # Instance refresh configuration
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup       = 300
    }
  }

  # Tags for ASG and instances
  dynamic "tag" {
    for_each = merge(var.common_tags, {
      Name        = "${var.environment}-web-asg"
      Environment = var.environment
    })

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes       = [desired_capacity]
  }
}

# CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "web" {
  name              = "/aws/ec2/${var.environment}/web"
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(var.common_tags, {
    Name = "${var.environment}-web-logs"
  })
}

# IAM Role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "${var.environment}-ec2-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.environment}-ec2-role"
  })
}

# IAM Policy for EC2 instances
resource "aws_iam_role_policy" "ec2_policy" {
  name = "${var.environment}-ec2-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.web.arn,
          "${aws_cloudwatch_log_group.web.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = merge(var.common_tags, {
    Name = "${var.environment}-ec2-profile"
  })
}