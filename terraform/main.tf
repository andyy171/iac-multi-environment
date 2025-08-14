
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  # Backend configuration - will be initialized separately
  backend "s3" {
    # Configuration will be provided via backend config files
  }
}

# AWS Provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "IaC-Multi-Environment"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.project_owner
      CreatedDate = formatdate("YYYY-MM-DD", timestamp())
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Local values for environment-specific configurations
locals {
  # Environment-specific CIDR blocks to avoid conflicts
  environment_cidrs = {
    dev = {
      vpc_cidr             = "10.0.0.0/16"
      public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
      private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]
    }
    staging = {
      vpc_cidr             = "10.1.0.0/16"
      public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
      private_subnet_cidrs = ["10.1.101.0/24", "10.1.102.0/24"]
    }
    prod = {
      vpc_cidr             = "10.2.0.0/16"
      public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24"]
      private_subnet_cidrs = ["10.2.101.0/24", "10.2.102.0/24"]
    }
  }

  # Environment-specific instance configurations
  instance_configs = {
    dev = {
      instance_type     = "t2.micro"
      min_instances     = 1
      max_instances     = 2
      desired_instances = 1
    }
    staging = {
      instance_type     = "t2.micro"  # Changed from t2.small for Free Tier
      min_instances     = 1
      max_instances     = 3
      desired_instances = 2
    }
    prod = {
      instance_type     = "t2.micro"  # Changed from t2.small for Free Tier
      min_instances     = 2
      max_instances     = 5
      desired_instances = 2
    }
  }

  # Common tags
  common_tags = {
    Project     = "IaC-Multi-Environment"
    Environment = var.environment
    Owner       = var.project_owner
    ManagedBy   = "Terraform"
    Workspace   = terraform.workspace
  }

  # Admin CIDR blocks for production SSH access
  admin_cidr_blocks = var.environment == "prod" ? var.admin_ssh_cidrs : ["0.0.0.0/0"]
}

# Networking Module
module "networking" {
  source = "./modules/networking"

  environment             = var.environment
  vpc_cidr               = local.environment_cidrs[var.environment].vpc_cidr
  public_subnet_count    = 2
  private_subnet_count   = 2
  public_subnet_cidrs    = local.environment_cidrs[var.environment].public_subnet_cidrs
  private_subnet_cidrs   = local.environment_cidrs[var.environment].private_subnet_cidrs
  admin_cidr_blocks      = local.admin_cidr_blocks
  common_tags            = local.common_tags
}

# Compute Module
module "compute" {
  source = "./modules/compute"
  
  depends_on = [module.networking]

  environment        = var.environment
  instance_type      = local.instance_configs[var.environment].instance_type
  public_key         = var.ssh_public_key
  security_group_ids = [module.networking.web_security_group_id]
  subnet_ids         = module.networking.public_subnet_ids
  
  min_instances     = local.instance_configs[var.environment].min_instances
  max_instances     = local.instance_configs[var.environment].max_instances
  desired_instances = local.instance_configs[var.environment].desired_instances
  
  common_tags = local.common_tags
}

# CloudWatch Dashboard for monitoring
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-infrastructure-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", module.compute.autoscaling_group_name],
            ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", module.compute.autoscaling_group_name],
            ["AWS/EC2", "NetworkOut", "AutoScalingGroupName", module.compute.autoscaling_group_name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "EC2 Metrics - ${var.environment}"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", module.compute.autoscaling_group_name],
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", module.compute.autoscaling_group_name],
            ["AWS/AutoScaling", "GroupTotalInstances", "AutoScalingGroupName", module.compute.autoscaling_group_name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Auto Scaling Group Metrics - ${var.environment}"
          period  = 300
        }
      }
    ]
  })

  tags = local.common_tags
}

# SNS Topic for alerts (optional)
resource "aws_sns_topic" "alerts" {
  count = var.enable_alerting ? 1 : 0
  
  name = "${var.environment}-infrastructure-alerts"

  tags = local.common_tags
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = var.enable_alerting ? 1 : 0

  alarm_name          = "${var.environment}-high-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]

  dimensions = {
    AutoScalingGroupName = module.compute.autoscaling_group_name
  }

  tags = local.common_tags
}

# S3 Bucket for application assets (optional)
resource "aws_s3_bucket" "app_assets" {
  count = var.create_s3_bucket ? 1 : 0
  
  bucket = "${var.environment}-app-assets-${random_string.suffix.result}"

  tags = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "app_assets" {
  count = var.create_s3_bucket ? 1 : 0
  
  bucket = aws_s3_bucket.app_assets[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_assets" {
  count = var.create_s3_bucket ? 1 : 0
  
  bucket = aws_s3_bucket.app_assets[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "app_assets" {
  count = var.create_s3_bucket ? 1 : 0
  
  bucket = aws_s3_bucket.app_assets[0].id
  
  versioning_configuration {
    status = "Enabled"
  }
}