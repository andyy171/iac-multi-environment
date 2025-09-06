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
  sensitive   = true  # Mark as sensitive for production
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
  sensitive   = true  # Mark as sensitive for production
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

# Ansible inventory output (masked for production)
output "ansible_inventory" {
  description = "Ansible inventory information"
  value       = module.web_infrastructure.ansible_inventory
  sensitive   = true  # Mark as sensitive for production
}

# Resource summary for monitoring
output "resource_summary" {
  description = "Summary of created resources"
  value = {
    environment       = var.environment
    region           = var.region
    vpc_id           = module.web_infrastructure.vpc_id
    instance_id      = module.web_infrastructure.instance_id
    instance_type    = var.instance_type
    elastic_ip       = var.use_elastic_ip
    encryption       = var.enable_encryption
    created_at       = timestamp()
    cost_center      = "production"
    managed_by       = "terraform"
    backup_required  = true
    monitoring_level = "detailed"
  }
}

# Production specific outputs
output "production_info" {
  description = "Production environment specific information"
  value = {
    security_features = {
      elastic_ip_enabled       = var.use_elastic_ip
      encryption_enabled       = var.enable_encryption
      vpc_flow_logs_enabled    = var.enable_vpc_flow_logs
      network_acl_enabled      = var.enable_network_acl
      s3_logging_enabled       = var.enable_s3_logging
      load_balancer_enabled    = var.enable_load_balancer
    }
    compliance_info = {
      environment     = "production"
      team           = "production-team"
      purpose        = "production-workload"
      sla            = "24x7"
      criticality    = "high"
      backup_policy  = "daily"
      retention      = "90-days"
    }
    operational_readiness = {
      monitoring_enabled    = true
      logging_enabled      = var.enable_s3_logging
      encryption_enabled   = var.enable_encryption
      network_security     = var.enable_network_acl
      disaster_recovery    = var.use_elastic_ip
    }
  }
}

# Production monitoring endpoints
output "monitoring_endpoints" {
  description = "Production monitoring and health check endpoints"
  value = {
    primary_endpoint    = module.web_infrastructure.web_url
    health_check       = "${module.web_infrastructure.web_url}/health"
    metrics_endpoint   = "${module.web_infrastructure.web_url}/metrics"
    status_endpoint    = "${module.web_infrastructure.web_url}/status"
  }
}

# Security and compliance outputs
output "security_summary" {
  description = "Security configuration summary for compliance reporting"
  value = {
    vpc_security = {
      vpc_flow_logs = var.enable_vpc_flow_logs
      network_acls  = var.enable_network_acl
      encryption    = var.enable_encryption
    }
    instance_security = {
      security_groups_configured = true
      encrypted_storage          = var.enable_encryption
      key_pair_authentication    = true
      iam_role_assigned         = true
    }
    network_security = {
      public_ip_protection = var.use_elastic_ip
      restricted_ssh       = length(var.ssh_cidr_blocks) > 0
      https_enabled        = true
    }
    logging_and_monitoring = {
      cloudwatch_logs = true
      vpc_flow_logs   = var.enable_vpc_flow_logs
      s3_logging      = var.enable_s3_logging
    }
  }
}