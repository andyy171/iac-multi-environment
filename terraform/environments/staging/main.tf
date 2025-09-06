terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = "staging"
      Project     = var.project_name
      ManagedBy   = "terraform"
      Owner       = "staging-team"
      CostCenter  = "staging"
    }
  }
}

# Call the web infrastructure module
module "web_infrastructure" {
  source = "../../modules/web-infrastructure"

  # Basic Configuration
  environment  = var.environment
  project_name = var.project_name
  region       = var.region

  # Network Configuration
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr

  # Instance Configuration
  instance_type    = var.instance_type
  key_name         = var.key_name
  root_volume_size = var.root_volume_size

  # Security Configuration
  allowed_cidr_blocks = var.allowed_cidr_blocks
  ssh_cidr_blocks     = var.ssh_cidr_blocks

  # Feature Flags - Staging environment with some production-like features
  use_elastic_ip       = var.use_elastic_ip
  enable_nat_gateway   = false  # Not needed for single instance
  enable_vpc_flow_logs = var.enable_vpc_flow_logs
  enable_network_acl   = false  # Keep simple for staging
  enable_load_balancer = false  # Not needed for single instance
  enable_database      = false  # Not needed for basic web server
  enable_encryption    = var.enable_encryption
  enable_s3_logging    = var.enable_s3_logging

  # Additional tags
  tags = var.tags
}