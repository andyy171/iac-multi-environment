variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
  
  validation {
    condition = can(regex("^(t2\\.(nano|micro|small|medium|large)|t3\\.(nano|micro|small|medium|large)|t3a\\.(nano|micro|small|medium|large))$", var.instance_type))
    error_message = "Instance type must be a valid t2, t3, or t3a instance type for Free Tier compatibility."
  }
}

variable "public_key" {
  description = "SSH public key content for EC2 key pair"
  type        = string
  
  validation {
    condition     = can(regex("^ssh-(rsa|ed25519|ecdsa)", var.public_key))
    error_message = "Public key must be in valid SSH format (ssh-rsa, ssh-ed25519, or ssh-ecdsa)."
  }
}

variable "security_group_ids" {
  description = "List of security group IDs to associate with instances"
  type        = list(string)
  
  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "At least one security group ID must be provided."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs for Auto Scaling Group"
  type        = list(string)
  
  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet ID must be provided."
  }
}

variable "target_group_arns" {
  description = "List of target group ARNs for Auto Scaling Group (optional)"
  type        = list(string)
  default     = []
}

variable "min_instances" {
  description = "Minimum number of instances in Auto Scaling Group"
  type        = number
  default     = 1
  
  validation {
    condition     = var.min_instances >= 0 && var.min_instances <= 10
    error_message = "Minimum instances must be between 0 and 10."
  }
}

variable "max_instances" {
  description = "Maximum number of instances in Auto Scaling Group"
  type        = number
  default     = 3
  
  validation {
    condition     = var.max_instances >= 1 && var.max_instances <= 10
    error_message = "Maximum instances must be between 1 and 10."
  }
}

variable "desired_instances" {
  description = "Desired number of instances in Auto Scaling Group"
  type        = number
  default     = 1
  
  validation {
    condition     = var.desired_instances >= 1 && var.desired_instances <= 10
    error_message = "Desired instances must be between 1 and 10."
  }
}

variable "root_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3"
  
  validation {
    condition     = contains(["gp2", "gp3"], var.root_volume_type)
    error_message = "Root volume type must be gp2 or gp3."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "Root volume size must be between 8 and 100 GB."
  }
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring for instances"
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = "Enable automated backups for production environments"
  type        = bool
  default     = false
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

# Environment-specific configurations
variable "instance_config" {
  description = "Environment-specific instance configurations"
  type = map(object({
    instance_type     = string
    min_instances     = number
    max_instances     = number
    desired_instances = number
    enable_monitoring = bool
    enable_backup     = bool
  }))
  
  default = {
    dev = {
      instance_type     = "t2.micro"
      min_instances     = 1
      max_instances     = 2
      desired_instances = 1
      enable_monitoring = false
      enable_backup     = false
    }
    staging = {
      instance_type     = "t2.small"
      min_instances     = 1
      max_instances     = 3
      desired_instances = 2
      enable_monitoring = true
      enable_backup     = true
    }
    prod = {
      instance_type     = "t2.small"
      min_instances     = 2
      max_instances     = 5
      desired_instances = 2
      enable_monitoring = true
      enable_backup     = true
    }
  }
}