variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"

  validation {
    condition     = var.environment == "prod"
    error_message = "This configuration is only for prod environment."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "iac-multi-environment"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"

  validation {
    condition = can(regex("^[a-z]+-[a-z]+-[0-9]$", var.region))
    error_message = "Region must be a valid AWS region format."
  }
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.2.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.2.1.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "Public subnet CIDR must be a valid IPv4 CIDR block."
  }
}

# Instance Configuration
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"

  validation {
    condition = contains([
      "t3.small", "t3.medium", "t3.large",
      "c5.large", "c5.xlarge",
      "m5.large", "m5.xlarge"
    ], var.instance_type)
    error_message = "Instance type must be appropriate for production workloads."
  }
}

variable "key_name" {
  description = "Name of the AWS key pair to use for EC2 instances"
  type        = string

  validation {
    condition     = length(var.key_name) > 0
    error_message = "Key name cannot be empty."
  }
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 10 && var.root_volume_size <= 100
    error_message = "Root volume size must be between 10 and 100 GB for production."
  }
}

# Security Configuration
variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access web server"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Should be restricted in production

  validation {
    condition = alltrue([
      for cidr in var.allowed_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All CIDR blocks must be valid IPv4 CIDR blocks."
  }
}

variable "ssh_cidr_blocks" {
  description = "List of CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # MUST be restricted in production

  validation {
    condition = alltrue([
      for cidr in var.ssh_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All SSH CIDR blocks must be valid IPv4 CIDR blocks."
  }
}

# Advanced Network Configuration
variable "custom_dns_servers" {
  description = "List of custom DNS servers"
  type        = list(string)
  default     = null

  validation {
    condition = var.custom_dns_servers == null ? true : alltrue([
      for dns in var.custom_dns_servers : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", dns))
    ])
    error_message = "All DNS servers must be valid IPv4 addresses."
  }
}

# Feature Flags - Production settings
variable "use_elastic_ip" {
  description = "Whether to allocate an Elastic IP for the instance"
  type        = bool
  default     = true  
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway for private subnets"
  type        = bool
  default     = false  # Can be enabled if private subnets are used
}

variable "enable_encryption" {
  description = "Whether to enable KMS encryption"
  type        = bool
  default     = true  # Required for production
}

variable "enable_vpc_flow_logs" {
  description = "Whether to enable VPC Flow Logs"
  type        = bool
  default     = true  # Required for production monitoring
}

variable "enable_network_acl" {
  description = "Whether to create custom Network ACLs"
  type        = bool
  default     = true  # Additional security layer
}

variable "enable_s3_logging" {
  description = "Whether to create S3 bucket for logging"
  type        = bool
  default     = true  # Required for production logging
}

variable "enable_load_balancer" {
  description = "Whether to create an Application Load Balancer"
  type        = bool
  default     = false  # Can be enabled for high availability
}

variable "enable_database" {
  description = "Whether to create database security group"
  type        = bool
  default     = false  # Can be enabled if database is needed
}

variable "database_port" {
  description = "Database port number"
  type        = number
  default     = 3306

  validation {
    condition     = var.database_port > 0 && var.database_port <= 65535
    error_message = "Database port must be between 1 and 65535."
  }
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {
    CostCenter      = "production"
    Owner           = "production-team"
    Purpose         = "production-workload"
    Criticality     = "high"
    BackupPolicy    = "daily"
    MonitoringLevel = "detailed"
    ComplianceScope = "required"
  }

  validation {
    condition     = can(keys(var.tags))
    error_message = "Tags must be a valid map of strings."
  }
}