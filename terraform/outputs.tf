# Environment Information
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "terraform_workspace" {
  description = "Terraform workspace"
  value       = terraform.workspace
}

# Networking Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.networking.vpc_cidr
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "web_security_group_id" {
  description = "ID of the web security group"
  value       = module.networking.web_security_group_id
}

# Compute Outputs
output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.compute.autoscaling_group_name
}

output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = module.compute.launch_template_id
}

output "key_pair_name" {
  description = "Name of the EC2 Key Pair"
  value       = module.compute.key_pair_name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group"
  value       = module.compute.cloudwatch_log_group_name
}

# Monitoring Outputs
output "cloudwatch_dashboard_url" {
  description = "URL to CloudWatch Dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "sns_topic_arn" {
  description = "ARN of SNS topic for alerts"
  value       = var.enable_alerting ? aws_sns_topic.alerts[0].arn : null
}

# S3 Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket for app assets"
  value       = var.create_s3_bucket ? aws_s3_bucket.app_assets[0].bucket : null
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for app assets"
  value       = var.create_s3_bucket ? aws_s3_bucket.app_assets[0].arn : null
}

# Ansible Integration Outputs
output "ansible_inventory_info" {
  description = "Information for Ansible dynamic inventory"
  value = {
    environment            = var.environment
    aws_region            = var.aws_region
    autoscaling_group_name = module.compute.autoscaling_group_name
    key_pair_name         = module.compute.key_pair_name
    security_group_id     = module.networking.web_security_group_id
    subnet_ids            = module.networking.public_subnet_ids
    vpc_id               = module.networking.vpc_id
    tags = {
      Environment = var.environment
      Ansible     = "web"
      Project     = "IaC-Multi-Environment"
    }
  }
  sensitive = false
}

# Connection Information for External Tools
output "connection_info" {
  description = "Connection information for external tools"
  value = {
    ssh_user              = "ubuntu"
    ssh_key_name          = module.compute.key_pair_name
    security_group_id     = module.networking.web_security_group_id
    app_port             = var.app_port
    health_check_path    = var.health_check_path
  }
  sensitive = false
}

# Infrastructure Summary
output "infrastructure_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    environment     = var.environment
    region         = var.aws_region
    vpc_cidr       = module.networking.vpc_cidr
    instance_count = local.instance_configs[var.environment].desired_instances
    instance_type  = local.instance_configs[var.environment].instance_type
    created_at     = timestamp()
  }
}

# URLs and Endpoints
output "application_urls" {
  description = "Application access URLs (will be available after instances are running)"
  value = {
    note = "Instance public IPs will be available after deployment. Use 'aws ec2 describe-instances' or Ansible dynamic inventory to get actual IPs."
    health_check_path = var.health_check_path
    expected_port     = "80"
  }
}

# Cost Estimation Information
output "cost_estimation" {
  description = "Estimated monthly cost information"
  value = {
    note         = "Estimates based on AWS Free Tier usage"
    instances    = "${local.instance_configs[var.environment].desired_instances} x ${local.instance_configs[var.environment].instance_type}"
    storage      = "20 GB EBS per instance"
    data_transfer = "1 GB outbound per month (Free Tier)"
    estimated_monthly_cost = var.environment == "dev" ? "$0-5" : var.environment == "staging" ? "$10-20" : "$20-40"
  }
}