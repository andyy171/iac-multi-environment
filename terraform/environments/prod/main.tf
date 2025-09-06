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
      Environment = "prod"
      Project     = var.project_name
      ManagedBy   = "terraform"
      Owner       = "production-team"
      CostCenter  = "production"
      Criticality = "high"
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

  # Feature Flags 
  use_elastic_ip       = var.use_elastic_ip
  enable_nat_gateway   = var.enable_nat_gateway
  enable_vpc_flow_logs = var.enable_vpc_flow_logs
  enable_network_acl   = var.enable_network_acl
  enable_load_balancer = var.enable_load_balancer
  enable_database      = var.enable_database
  enable_encryption    = var.enable_encryption
  enable_s3_logging    = var.enable_s3_logging

  # Production-specific configurations
  database_port      = var.database_port
  custom_dns_servers = var.custom_dns_servers

  # Additional tags
  tags = var.tags
}