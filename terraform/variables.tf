
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-1"
  
  validation {
    condition = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in valid format (e.g., ap-southeast-1)."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_owner" {
  description = "Owner of the project for tagging"
  type        = string
  default     = "DevOps-Team"
}

variable "ssh_public_key" {
  description = "SSH public key content for EC2 instances"
  type        = string
  
  validation {
    condition     = can(regex("^ssh-(rsa|ed25519|ecdsa)", var.ssh_public_key))
    error_message = "SSH public key must be in valid format."
  }
}

variable "admin_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access in production"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Should be restricted in production
  
  validation {
    condition     = length(var.admin_ssh_cidrs) > 0
    error_message = "At least one admin CIDR block must be specified."
  }
}

variable "enable_alerting" {
  description = "Enable CloudWatch alarms and SNS notifications"
  type        = bool
  default     = false
}

variable "create_s3_bucket" {
  description = "Create S3 bucket for application assets"
  type        = bool
  default     = false
}

# Environment-specific overrides
variable "custom_instance_type" {
  description = "Override default instance type for environment"
  type        = string
  default     = ""
}

variable "custom_min_instances" {
  description = "Override default minimum instances"
  type        = number
  default     = 0
}

variable "custom_max_instances" {
  description = "Override default maximum instances"
  type        = number
  default     = 0
}

variable "custom_desired_instances" {
  description = "Override default desired instances"
  type        = number
  default     = 0
}

# Backup configuration
variable "enable_backups" {
  description = "Enable automated backups for EBS volumes"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "Backup retention days must be between 1 and 365."
  }
}

# Network configuration overrides
variable "custom_vpc_cidr" {
  description = "Override default VPC CIDR for environment"
  type        = string
  default     = ""
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = false
}

# Monitoring configuration
variable "monitoring_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 7
  
  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.monitoring_retention_days)
    error_message = "Monitoring retention days must be a valid CloudWatch Logs retention value."
  }
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for EC2 instances"
  type        = bool
  default     = false
}

# Cost optimization
variable "enable_spot_instances" {
  description = "Use Spot instances for cost optimization (not recommended for prod)"
  type        = bool
  default     = false
}

variable "spot_max_price" {
  description = "Maximum price for Spot instances"
  type        = string
  default     = "0.01"
}

# Application configuration
variable "app_port" {
  description = "Application port number"
  type        = number
  default     = 3000
  
  validation {
    condition     = var.app_port > 1024 && var.app_port < 65536
    error_message = "Application port must be between 1024 and 65535."
  }
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/health"
}

# Feature flags
variable "enable_load_balancer" {
  description = "Create Application Load Balancer"
  type        = bool
  default     = false
}

variable "enable_auto_scaling" {
  description = "Enable auto scaling based on metrics"
  type        = bool
  default     = true
}

variable "enable_ssl_certificate" {
  description = "Create and attach SSL certificate"
  type        = bool
  default     = false
}

# Domain configuration
variable "domain_name" {
  description = "Domain name for the application (optional)"
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for domain"
  type        = string
  default     = ""
}

# Security configuration
variable "enable_waf" {
  description = "Enable AWS WAF for additional security"
  type        = bool
  default     = false
}

variable "allowed_countries" {
  description = "List of country codes allowed to access the application"
  type        = list(string)
  default     = ["US", "CA", "GB", "AU", "VN"]  # Add VN for Vietnam
}

# Database configuration (for future extensions)
variable "enable_database" {
  description = "Create RDS database instance"
  type        = bool
  default     = false
}

variable "database_engine" {
  description = "Database engine (mysql, postgresql, etc.)"
  type        = string
  default     = "mysql"
}

variable "database_instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.micro"
}