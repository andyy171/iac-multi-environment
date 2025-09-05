#!/bin/bash

# init-backend.sh - Initialize Terraform backend infrastructure
# This script creates S3 buckets and DynamoDB table for Terraform state management

set -e  # Exit on any error
set -u  # Exit on undefined variables

# Configuration
PROJECT_NAME="iac-multi-env"
AWS_REGION=${AWS_REGION:-"ap-southeast-1"}
ENVIRONMENTS=("dev" "staging" "prod")
DYNAMODB_TABLE="terraform-state-lock"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if AWS credentials are configured
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials are not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Check if jq is installed (optional but helpful)
    if ! command -v jq &> /dev/null; then
        log_warning "jq is not installed. JSON output will not be formatted."
    fi
    
    log_success "Prerequisites check completed"
}

# Get AWS account ID
get_account_id() {
    aws sts get-caller-identity --query Account --output text
}

# Create S3 bucket for Terraform state
create_s3_bucket() {
    local environment=$1
    local account_id=$2
    local bucket_name="${PROJECT_NAME}-terraform-state-${environment}-${account_id}"
    
    log_info "Creating S3 bucket: ${bucket_name}"
    
    # Check if bucket already exists
    if aws s3 ls "s3://${bucket_name}" 2>/dev/null; then
        log_warning "S3 bucket ${bucket_name} already exists"
        return 0
    fi
    
    # Create bucket
    if [ "${AWS_REGION}" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "${bucket_name}" \
            --region "${AWS_REGION}"
    else
        aws s3api create-bucket \
            --bucket "${bucket_name}" \
            --region "${AWS_REGION}" \
            --create-bucket-configuration LocationConstraint="${AWS_REGION}"
    fi
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "${bucket_name}" \
        --versioning-configuration Status=Enabled
    
    # Enable server-side encryption
    aws s3api put-bucket-encryption \
        --bucket "${bucket_name}" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket "${bucket_name}" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    # Add lifecycle policy to delete incomplete multipart uploads
    aws s3api put-bucket-lifecycle-configuration \
        --bucket "${bucket_name}" \
        --lifecycle-configuration '{
            "Rules": [
                {
                    "ID": "DeleteIncompleteMultipartUploads",
                    "Status": "Enabled",
                    "AbortIncompleteMultipartUpload": {
                        "DaysAfterInitiation": 7
                    }
                }
            ]
        }'
    
    # Add tags
    aws s3api put-bucket-tagging \
        --bucket "${bucket_name}" \
        --tagging '{
            "TagSet": [
                {
                    "Key": "Environment",
                    "Value": "'${environment}'"
                },
                {
                    "Key": "Project",
                    "Value": "'${PROJECT_NAME}'"
                },
                {
                    "Key": "ManagedBy",
                    "Value": "terraform"
                },
                {
                    "Key": "Purpose",
                    "Value": "terraform-state"
                }
            ]
        }'
    
    log_success "S3 bucket ${bucket_name} created successfully"
    echo "${bucket_name}"
}

# Create DynamoDB table for state locking
create_dynamodb_table() {
    log_info "Creating DynamoDB table: ${DYNAMODB_TABLE}"
    
    # Check if table already exists
    if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" &>/dev/null; then
        log_warning "DynamoDB table ${DYNAMODB_TABLE} already exists"
        return 0
    fi
    
    # Create table
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions \
            AttributeName=LockID,AttributeType=S \
        --key-schema \
            AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput \
            ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --tags \
            Key=Environment,Value=shared \
            Key=Project,Value="${PROJECT_NAME}" \
            Key=ManagedBy,Value=terraform \
            Key=Purpose,Value=state-locking
    
    # Wait for table to be created
    log_info "Waiting for DynamoDB table to be active..."
    aws dynamodb wait table-exists --table-name "${DYNAMODB_TABLE}"
    
    log_success "DynamoDB table ${DYNAMODB_TABLE} created successfully"
}

# Generate backend configuration files
generate_backend_configs() {
    local account_id=$1
    
    log_info "Generating backend configuration files..."
    
    for env in "${ENVIRONMENTS[@]}"; do
        local bucket_name="${PROJECT_NAME}-terraform-state-${env}-${account_id}"
        local backend_file="terraform/environments/${env}/backend.tf"
        
        # Create directory if it doesn't exist
        mkdir -p "terraform/environments/${env}"
        
        cat > "${backend_file}" << EOF
# backend.tf - Terraform backend configuration for ${env} environment
# This file is auto-generated by init-backend.sh

terraform {
  backend "s3" {
    bucket         = "${bucket_name}"
    key            = "terraform.tfstate"
    region         = "${AWS_REGION}"
    dynamodb_table = "${DYNAMODB_TABLE}"
    encrypt        = true
    
    # Prevent accidental state file deletion
    skip_region_validation      = false
    skip_credentials_validation = false
    skip_metadata_api_check     = false
  }
}
EOF
        
        log_success "Backend configuration created: ${backend_file}"
    done
}

# Create example tfvars files if they don't exist
create_example_tfvars() {
    log_info "Creating example terraform.tfvars files..."
    
    for env in "${ENVIRONMENTS[@]}"; do
        local tfvars_file="terraform/environments/${env}/terraform.tfvars"
        
        if [ ! -f "${tfvars_file}" ]; then
            # Set environment-specific configurations
            local instance_type="t2.micro"
            local use_elastic_ip="false"
            local enable_encryption="false"
            
            case $env in
                "staging")
                    instance_type="t3.small"
                    use_elastic_ip="false"
                    enable_encryption="true"
                    ;;
                "prod")
                    instance_type="t3.small"
                    use_elastic_ip="true"
                    enable_encryption="true"
                    ;;
            esac
            
            cat > "${tfvars_file}" << EOF
# terraform.tfvars - Variables for ${env} environment

environment     = "${env}"
project_name    = "${PROJECT_NAME}"
region          = "${AWS_REGION}"

# Network Configuration
vpc_cidr           = "10.${env == "dev" && echo "0" || env == "staging" && echo "1" || echo "2"}.0.0/16"
public_subnet_cidr = "10.${env == "dev" && echo "0" || env == "staging" && echo "1" || echo "2"}.1.0/24"

# Instance Configuration
instance_type    = "${instance_type}"
key_name         = "iac-demo-key"
root_volume_size = 8

# Security Configuration
allowed_cidr_blocks = ["0.0.0.0/0"]  # Restrict this in production
ssh_cidr_blocks     = ["0.0.0.0/0"]  # Restrict this in production

# Feature Flags
use_elastic_ip      = ${use_elastic_ip}
enable_encryption   = ${enable_encryption}
enable_vpc_flow_logs = false
enable_s3_logging    = false

# Additional Tags
tags = {
  CostCenter = "${env}"
  Owner      = "infrastructure-team"
}
EOF
            log_success "Created ${tfvars_file}"
        else
            log_warning "${tfvars_file} already exists, skipping"
        fi
    done
}

# Main execution
main() {
    log_info "Starting Terraform backend initialization..."
    log_info "Project: ${PROJECT_NAME}"
    log_info "Region: ${AWS_REGION}"
    log_info "Environments: ${ENVIRONMENTS[*]}"
    
    # Check prerequisites
    check_prerequisites
    
    # Get AWS account ID
    local account_id
    account_id=$(get_account_id)
    log_info "AWS Account ID: ${account_id}"
    
    # Create DynamoDB table for state locking
    create_dynamodb_table
    
    # Create S3 buckets for each environment
    local buckets=()
    for env in "${ENVIRONMENTS[@]}"; do
        bucket_name=$(create_s3_bucket "${env}" "${account_id}")
        buckets+=("${bucket_name}")
    done
    
    # Generate backend configuration files
    generate_backend_configs "${account_id}"
    
    # Create example tfvars files
    create_example_tfvars
    
    # Summary
    echo ""
    log_success "Backend initialization completed successfully!"
    echo ""
    echo "Created resources:"
    echo "  DynamoDB Table: ${DYNAMODB_TABLE}"
    for bucket in "${buckets[@]}"; do
        echo "  S3 Bucket: ${bucket}"
    done
    echo ""
    echo "Backend configuration files created:"
    for env in "${ENVIRONMENTS[@]}"; do
        echo "  terraform/environments/${env}/backend.tf"
    done
    echo ""
    echo "Next steps:"
    echo "1. Review and customize the terraform.tfvars files in each environment"
    echo "2. Run 'terraform init' in each environment directory"
    echo "3. Run 'terraform plan' to review the infrastructure changes"
    echo "4. Run 'terraform apply' to create the infrastructure"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi