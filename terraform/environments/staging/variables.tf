variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"

  validation {
    condition     = var.environment == "staging"
    error_message = "This configuration is only for staging environment."
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
  default     = "10.1.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.1.1.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "Public subnet CIDR must be a valid IPv4 CIDR block."
  }
}

# Instance Configuration
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"

  validation {
    condition     = contains(["t2.micro", "t2.small", "t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "Instance type must be a valid small to medium instance type."
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
  default     = 10

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 50
    error_message = "Root volume size must be between 8 and 50 GB."
  }
}

# Security Configuration
variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access web server"
  type        = list(string)
  default     = ["0.0.0.0/0"]

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
  default     = ["0.0.0.0/0"]  # Should be restricted in production

  validation {
    condition = alltrue([
      for cidr in var.ssh_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All SSH CIDR blocks must be valid IPv4 CIDR blocks."
  }
}

# Feature Flags
variable "use_elastic_ip" {
  description = "Whether to allocate an Elastic IP for the instance"
  type        = bool
  default     = false
}

variable "enable_encryption" {
  description = "Whether to enable KMS encryption"
  type        = bool
  default     = true  # Enable encryption in staging to test production setup
}

variable "enable_vpc_flow_logs" {
  description = "Whether to enable VPC Flow Logs"
  type        = bool
  default     = true  # Enable for testing
}

variable "enable_s3_logging" {
  description = "Whether to create S3 bucket for logging"
  type        = bool
  default     = true  # Enable for testing
}

# Additional tags
variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {
    CostCenter = "staging"
    Owner      = "staging-team"
    Purpose    = "pre-production-testing"
  }

  validation {
    condition     = can(keys(var.tags))
    error_message = "Tags must be a valid map of strings."
  }
}