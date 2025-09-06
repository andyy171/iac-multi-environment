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
    cost_center    = "development"
    managed_by     = "terraform"
  }
}

# Development specific outputs
output "dev_info" {
  description = "Development environment specific information"
  value = {
    cost_optimization = {
      elastic_ip_enabled    = var.use_elastic_ip
      nat_gateway_enabled   = false
      vpc_flow_logs_enabled = var.enable_vpc_flow_logs
      encryption_enabled    = var.enable_encryption
    }
    access_info = {
      environment = "development"
      team        = "development-team"
      purpose     = "development and testing"
    }
  }
}