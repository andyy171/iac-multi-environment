variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_count" {
  description = "Number of public subnets to create"
  type        = number
  default     = 2
  
  validation {
    condition     = var.public_subnet_count >= 1 && var.public_subnet_count <= 4
    error_message = "Public subnet count must be between 1 and 4."
  }
}

variable "private_subnet_count" {
  description = "Number of private subnets to create"
  type        = number
  default     = 2
  
  validation {
    condition     = var.private_subnet_count >= 0 && var.private_subnet_count <= 4
    error_message = "Private subnet count must be between 0 and 4."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24"]
  
  validation {
    condition     = length(var.public_subnet_cidrs) >= 1
    error_message = "At least one public subnet CIDR must be provided."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24", "10.0.104.0/24"]
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks for admin access (production SSH restriction)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Should be restricted in production
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "IaC-Multi-Environment"
    ManagedBy   = "Terraform"
    Owner       = "DevOps-Team"
  }
}