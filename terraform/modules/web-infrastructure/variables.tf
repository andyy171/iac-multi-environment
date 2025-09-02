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
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
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
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access web server"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_cidr_blocks" {
  description = "List of CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production
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
  default     = false  # Set to true for production environments
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
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
}