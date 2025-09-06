variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
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
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "Must be a valid IPv4 CIDR block."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"

  validation {
    condition     = contains(["t2.micro", "t2.small", "t3.micro", "t3.small"], var.instance_type)
    error_message = "Instance type must be a valid free tier or small instance type."
  }
}

variable "key_name" {
  description = "Name of the AWS key pair to use for EC2 instances"
  type        = string

  validation {
    condition     = length(var.key_name) > 0
    error_message = "Key name must not be empty."
  }
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access web server"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_cidr_blocks" {
  description = "List of CIDR blocks allowed for SSH access. Restrict this in production."
  type        = list(string)
  default     = []  # Empty by default for security

  validation {
    condition = var.environment != "prod" || (
      length(var.ssh_cidr_blocks) > 0 &&
      alltrue([for cidr in var.ssh_cidr_blocks : cidr != "0.0.0.0/0"])
    )
    error_message = "For production, SSH access must be restricted to specific CIDR blocks (not 0.0.0.0/0)."
  }
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 30
    error_message = "Root volume size must be between 8 and 30 GB."
  }
}

variable "use_elastic_ip" {
  description = "Whether to allocate an Elastic IP for the instance"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway for private subnets"
  type        = bool
  default     = false
}

variable "enable_vpc_flow_logs" {
  description = "Whether to enable VPC Flow Logs"
  type        = bool
  default     = false
}

variable "enable_network_acl" {
  description = "Whether to create custom Network ACLs"
  type        = bool
  default     = false
}

variable "custom_dns_servers" {
  description = "List of custom DNS servers"
  type        = list(string)
  default     = null
}

variable "custom_port" {
  description = "Custom port to allow in security group"
  type        = number
  default     = null

  validation {
    condition     = var.custom_port == null || (var.custom_port > 0 && var.custom_port <= 65535)
    error_message = "Custom port must be a valid port number between 1 and 65535."
  }
}

variable "enable_load_balancer" {
  description = "Whether to create an Application Load Balancer"
  type        = bool
  default     = false
}

variable "enable_database" {
  description = "Whether to create database security group"
  type        = bool
  default     = false
}

variable "database_port" {
  description = "Database port number"
  type        = number
  default     = 3306

  validation {
    condition     = var.database_port > 0 && var.database_port <= 65535
    error_message = "Database port must be a valid port number between 1 and 65535."
  }
}

variable "enable_encryption" {
  description = "Whether to enable KMS encryption"
  type        = bool
  default     = true
}

variable "enable_s3_logging" {
  description = "Whether to create S3 bucket for logging"
  type        = bool
  default     = false
}

# Local values for computed configurations
locals {
  common_tags = merge(
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
      CreatedAt   = formatdate("YYYY-MM-DD", timestamp())
    },
    var.tags
  )
  
  # Automatically set EIP usage based on environment
  use_elastic_ip_final = var.use_elastic_ip ? var.use_elastic_ip : var.environment == "prod"
  
  # Automatically set NAT Gateway based on environment
  enable_nat_gateway_final = var.environment == "prod" ? true : var.enable_nat_gateway
}