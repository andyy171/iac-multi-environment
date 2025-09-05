terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region

  # Default tags to apply to all resources
  default_tags {
    tags = {
      Environment   = var.environment
      Project       = var.project_name
      ManagedBy     = "terraform"
      Owner         = "infrastructure-team"
      CostCenter    = var.environment == "prod" ? "production" : "development"
      BackupPolicy  = var.environment == "prod" ? "daily" : "none"
      CreatedBy     = "terraform-module"
      Module        = "web-infrastructure"
    }
  }
}

provider "random" {

}

provider "local" {

}

provider "template" {
    
}