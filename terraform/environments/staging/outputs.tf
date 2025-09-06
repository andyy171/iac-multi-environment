output "vpc_id" {
  description = "ID of the VPC"
  value       = module.web_infrastructure.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.web_infrastructure.vpc_cidr_block
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.web_infrastructure.public_subnet_id
}

output "public_subnet_cidr_block" {
  description = "CIDR block of the public subnet"
  value       = module.web_infrastructure.public_subnet_cidr_block
}

output "security_group_id" {
  description = "ID of the web security group"
  value       = module.web_infrastructure.security_group_id
}

# Instance outputs
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = module.web_infrastructure.instance_id
}

output "instance_arn" {
  description = "ARN of the EC2 instance"
  value       = module.web_infrastructure.instance_arn
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.web_infrastructure.public_ip
}

output "private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = module.web_infrastructure.private_ip
}

output "public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = module.web_infrastructure.public_dns
}

# Access information
output "web_url" {
  description = "URL to access the web server"
  value       = module.web_infrastructure.web_url
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = module.web_infrastructure.ssh_command
}

# Environment information
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "availability_zone" {
  description = "Availability zone of the EC2 instance"
  value       = module.web_infrastructure.availability_zone
}

output "key_name" {
  description = "Name of the key pair used"
  value       = var.key_name
}

# Ansible inventory output
output "ansible_inventory" {
  description = "Ansible inventory information"
  value       = module.web_infrastructure.ansible_inventory
  sensitive   = false
}

# Resource summary for monitoring
output "resource_summary" {
  description = "Summary of created resources"
  value = {
    environment     = var.environment
    region         = var.region
    vpc_id         = module.web_infrastructure.vpc_id
    instance_id    = module.web_infrastructure.instance_id
    instance_type  = var.instance_type
    public_ip      = module.web_infrastructure.public_ip
    created_at     = timestamp()
    cost_center    = "staging"
    managed_by     = "terraform"
  }
}

# Staging specific outputs
output "staging_info" {
  description = "Staging environment specific information"
  value = {
    testing_features = {
      elastic_ip_enabled      = var.use_elastic_ip
      encryption_enabled      = var.enable_encryption
      vpc_flow_logs_enabled   = var.enable_vpc_flow_logs
      s3_logging_enabled      = var.enable_s3_logging
    }
    environment_purpose = {
      environment = "pre-production"
      team        = "staging-team"
      purpose     = "integration-testing-and-qa"
      sla         = "business-hours"
    }
    promotion_ready = {
      security_tested = var.enable_encryption
      logging_tested  = var.enable_s3_logging
      monitoring_tested = var.enable_vpc_flow_logs
    }
  }
}

# Testing endpoints
output "testing_endpoints" {
  description = "Endpoints for testing"
  value = {
    web_server    = module.web_infrastructure.web_url
    health_check  = "${module.web_infrastructure.web_url}/health"
    api_endpoint  = "${module.web_infrastructure.web_url}/api"
    ssh_access    = module.web_infrastructure.ssh_command
  }
}