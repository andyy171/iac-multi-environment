terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "iac-terraform-state-dev-ap-south-1"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "iac-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "iac-multi-env"
      ManagedBy   = "terraform"
      Owner       = "devops-team"
    }
  }
}

# Call the main infrastructure module
module "web_infrastructure" {
  source = "../../modules/web-infrastructure"

  environment            = var.environment
  project_name          = var.project_name
  region                = var.region
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidr    = var.public_subnet_cidr
  instance_type         = var.instance_type
  key_name              = var.key_name
  allowed_cidr_blocks   = var.allowed_cidr_blocks
  ssh_cidr_blocks       = var.ssh_cidr_blocks
  root_volume_size      = var.root_volume_size
  use_elastic_ip        = var.use_elastic_ip

  tags = {
    CostCenter = "development"
    AutoShutdown = "enabled"
  }
}