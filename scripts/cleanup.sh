set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --environment <env>  Cleanup specific environment (dev|staging|prod)"
    echo "  --all               Cleanup all environments"
    echo "  --force             Skip confirmation prompts"
    echo "  --keep-backend      Keep S3 buckets and DynamoDB table"
    echo "  --help              Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --environment dev"
    echo "  $0 --all --force"
    echo "  $0 --all --keep-backend"
    exit 1
}

cleanup_environment() {
    local env=$1
    local force=${2:-false}
    
    print_status "Cleaning up $env environment..."
    
    if [ ! -d "terraform/environments/$env" ]; then
        print_warning "Environment $env does not exist."
        return 0
    fi
    
    cd "terraform/environments/$env"
    
    # Check if terraform is initialized
    if [ ! -d ".terraform" ]; then
        print_status "Initializing Terraform..."
        terraform init
    fi
    
    # Check if there are resources to destroy
    if ! terraform plan -destroy -detailed-exitcode &>/dev/null; then
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            print_success "No resources to destroy in $env environment."
            cd - > /dev/null
            return 0
        elif [ $exit_code -ne 2 ]; then
            print_error "Failed to plan destroy for $env environment."
            cd - > /dev/null
            return 1
        fi
    fi
    
    if [ "$force" = false ]; then
        echo
        print_warning "This will destroy ALL resources in the $env environment!"
        terraform plan -destroy
        echo
        read -p "Are you sure you want to destroy the $env environment? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Cleanup cancelled by user."
            cd - > /dev/null
            return 1
        fi
    fi
    
    print_status "Destroying resources in $env environment..."
    if terraform destroy -auto-approve; then
        print_success "Resources destroyed in $env environment."
    else
        print_error "Failed to destroy resources in $env environment."
        cd - > /dev/null
        return 1
    fi
    
    cd - > /dev/null
    
    # Clean up generated inventory files
    if [ -f "ansible/inventory/$env.ini" ]; then
        rm "ansible/inventory/$env.ini"
        print_status "Removed Ansible inventory for $env environment."
    fi
    
    if [ -f "ansible/inventory/$env.json" ]; then
        rm "ansible/inventory/$env.json"
        print_status "Removed Ansible JSON inventory for $env environment."
    fi
}

cleanup_backend() {
    local force=${1:-false}
    
    print_status "Cleaning up Terraform backend resources..."
    
    if [ "$force" = false ]; then
        echo
        print_warning "This will delete S3 buckets and DynamoDB table used for Terraform state!"
        print_warning "Make sure all environments are destroyed first."
        echo
        read -p "Are you sure you want to cleanup backend resources? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Backend cleanup cancelled by user."
            return 1
        fi
    fi
    
    local project_name="iac-multi-env"
    local aws_region="ap-south-1"
    local environments=("dev" "staging" "prod")
    
    # Delete S3 buckets
    for env in "${environments[@]}"; do
        local bucket_name="${project_name}-terraform-state-${env}-${aws_region}"
        
        if aws s3 ls "s3://${bucket_name}" &>/dev/null; then
            print_status "Emptying and deleting S3 bucket: $bucket_name"
            
            # Empty the bucket first
            aws s3 rm "s3://${bucket_name}" --recursive
            
            # Delete all versions (if versioning is enabled)
            aws s3api delete-objects \
                --bucket "$bucket_name" \
                --delete "$(aws s3api list-object-versions \
                --bucket "$bucket_name" \
                --query '{Objects: Versions[].{Key: Key, VersionId: VersionId}}' \
                --max-items 1000)" 2>/dev/null || true
            
            # Delete delete markers
            aws s3api delete-objects \
                --bucket "$bucket_name" \
                --delete "$(aws s3api list-object-versions \
                --bucket "$bucket_name" \
                --query '{Objects: DeleteMarkers[].{Key: Key, VersionId: VersionId}}' \
                --max-items 1000)" 2>/dev/null || true
            
            # Delete the bucket
            aws s3 rb "s3://${bucket_name}"
            
            print_success "Deleted S3 bucket: $bucket_name"
        else
            print_status "S3 bucket $bucket_name does not exist."
        fi
    done
    
    # Delete DynamoDB table
    local table_name="${project_name}-terraform-locks"
    
    if aws dynamodb describe-table --table-name "$table_name" &>/dev/null; then
        print_status "Deleting DynamoDB table: $table_name"
        aws dynamodb delete-table --table-name "$table_name"
        
        print_status "Waiting for DynamoDB table deletion..."
        aws dynamodb wait table-not-exists --table-name "$table_name"
        
        print_success "Deleted DynamoDB table: $table_name"
    else
        print_status "DynamoDB table $table_name does not exist."
    fi
    
    print_success "Backend cleanup completed."
}

list_resources() {
    print_status "Listing current resources across all environments..."
    echo
    
    local environments=("dev" "staging" "prod")
    local total_resources=0
    
    for env in "${environments[@]}"; do
        echo -e "${BLUE}=== $env Environment ===${NC}"
        
        if [ ! -d "terraform/environments/$env" ]; then
            echo "  Environment not found"
            continue
        fi
        
        cd "terraform/environments/$env"
        
        if [ ! -d ".terraform" ]; then
            echo "  Not initialized"
            cd - > /dev/null
            continue
        fi
        
        # Check if state file exists
        if ! terraform show &>/dev/null; then
            echo "  No resources found"
            cd - > /dev/null
            continue
        fi
        
        # List resources
        local resources=$(terraform state list 2>/dev/null | wc -l)
        total_resources=$((total_resources + resources))
        
        if [ $resources -gt 0 ]; then
            echo "  Resources: $resources"
            terraform state list | sed 's/^/    /'
            
            # Get key outputs if available
            if terraform output public_ip &>/dev/null; then
                echo "  Public IP: $(terraform output -raw public_ip)"
                echo "  Web URL: $(terraform output -raw web_url)"
            fi
        else
            echo "  No resources found"
        fi
        
        cd - > /dev/null
        echo
    done
    
    echo -e "${BLUE}=== Summary ===${NC}"
    echo "Total resources across all environments: $total_resources"
    
    if [ $total_resources -gt 0 ]; then
        print_warning "Found $total_resources resources that can be cleaned up."
    else
        print_success "No resources found to clean up."
    fi
}

main() {
    local environment=""
    local all=false
    local force=false
    local keep_backend=false
    local list_only=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --environment)
                environment=$2
                shift 2
                ;;
            --all)
                all=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --keep-backend)
                keep_backend=true
                shift
                ;;
            --list)
                list_only=true
                shift
                ;;
            --help)
                usage
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Validate arguments
    if [[ -n "$environment" && "$all" = true ]]; then
        print_error "Cannot specify both --environment and --all"
        exit 1
    fi
    
    if [[ -z "$environment" && "$all" = false && "$list_only" = false ]]; then
        print_error "Must specify --environment, --all, or --list"
        usage
    fi
    
    if [[ -n "$environment" && ! "$environment" =~ ^(dev|staging|prod)$ ]]; then
        print_error "Invalid environment. Must be: dev, staging, or prod"
        exit 1
    fi
    
    # Check prerequisites
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed."
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured."
        exit 1
    fi
    
    echo -e "${BLUE}=== Infrastructure Cleanup ===${NC}"
    echo
    
    if [ "$list_only" = true ]; then
        list_resources
        exit 0
    fi
    
    # Cleanup specific environment
    if [[ -n "$environment" ]]; then
        if ! cleanup_environment "$environment" "$force"; then
            print_error "Failed to cleanup $environment environment."
            exit 1
        fi
        print_success "Cleanup completed for $environment environment."
        exit 0
    fi
    
    # Cleanup all environments
    if [ "$all" = true ]; then
        local environments=("dev" "staging" "prod")
        local failed_environments=()
        
        for env in "${environments[@]}"; do
            if ! cleanup_environment "$env" "$force"; then
                failed_environments+=("$env")
                print_error "Failed to cleanup $env environment."
            fi
        done
        
        if [ ${#failed_environments[@]} -gt 0 ]; then
            print_error "Failed to cleanup environments: ${failed_environments[*]}"
            print_warning "Backend cleanup skipped due to failures."
            exit 1
        fi
        
        print_success "All environments cleaned up successfully."
        
        # Cleanup backend if requested
        if [ "$keep_backend" = false ]; then
            if ! cleanup_backend "$force"; then
                print_error "Failed to cleanup backend resources."
                exit 1
            fi
        else
            print_status "Backend resources kept as requested."
        fi
        
        print_success "Complete cleanup finished!"
    fi
}

main "$@"

---

#!/bin/bash
# terraform/scripts/generate-inventory.sh - Generate Ansible inventory from Terraform outputs

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    echo "Usage: $0 <environment>"
    echo
    echo "Generate Ansible inventory files from Terraform outputs"
    echo
    echo "Arguments:"
    echo "  environment    Environment name (dev, staging, prod)"
    echo
    echo "Examples:"
    echo "  $0 dev"
    echo "  $0 staging"
    exit 1
}

generate_inventory() {
    local env=$1
    
    print_status "Generating Ansible inventory for $env environment..."
    
    # Check if environment directory exists
    if [ ! -d "terraform/environments/$env" ]; then
        print_error "Environment directory not found: terraform/environments/$env"
        return 1
    fi
    
    cd "terraform/environments/$env"
    
    # Check if terraform is initialized and state exists
    if [ ! -d ".terraform" ]; then
        print_error "Terraform not initialized in $env environment. Run 'terraform init' first."
        cd - > /dev/null
        return 1
    fi
    
    if ! terraform show &>/dev/null; then
        print_error "No Terraform state found for $env environment. Run 'terraform apply' first."
        cd - > /dev/null
        return 1
    fi
    
    # Get outputs
    local public_ip instance_id ssh_command
    
    if ! public_ip=$(terraform output -raw public_ip 2>/dev/null); then
        print_error "Could not get public_ip output from Terraform state."
        cd - > /dev/null
        return 1
    fi
    
    if ! instance_id=$(terraform output -raw instance_id 2>/dev/null); then
        print_error "Could not get instance_id output from Terraform state."
        cd - > /dev/null
        return 1
    fi
    
    if ! ssh_command=$(terraform output -raw ssh_command 2>/dev/null); then
        print_error "Could not get ssh_command output from Terraform state."
        cd - > /dev/null
        return 1
    fi
    
    cd - > /dev/null
    
    # Create inventory directory if it doesn't exist
    mkdir -p ansible/inventory
    
    # Generate INI format inventory
    cat > "ansible/inventory/$env.ini" << EOF
# Auto-generated Ansible inventory for $env environment
# Generated on: $(date)
# Instance ID: $instance_id

[$env-web]
$public_ip ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/iac-demo-key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[web_servers]
$public_ip

[$env]
$public_ip

[all:vars]
env=$env
instance_id=$instance_id
ansible_python_interpreter=/usr/bin/python3
EOF

    # Generate JSON format inventory
    cat > "ansible/inventory/$env.json" << EOF
{
    "_meta": {
        "hostvars": {
            "$public_ip": {
                "ansible_user": "ubuntu",
                "ansible_ssh_private_key_file": "~/.ssh/iac-demo-key.pem",
                "ansible_ssh_common_args": "-o StrictHostKeyChecking=no",
                "env": "$env",
                "instance_id": "$instance_id",
                "ansible_python_interpreter": "/usr/bin/python3"
            }
        }
    },
    "${env}-web": {
        "hosts": ["$public_ip"]
    },
    "web_servers": {
        "hosts": ["$public_ip"]
    },
    "$env": {
        "hosts": ["$public_ip"]
    }
}
EOF

    # Create host_vars directory and file
    mkdir -p "ansible/inventory/host_vars"
    cat > "ansible/inventory/host_vars/$public_ip.yml" << EOF
---
# Host-specific variables for $public_ip ($env environment)
ansible_user: ubuntu
ansible_ssh_private_key_file: ~/.ssh/iac-demo-key.pem
ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

# Environment and instance details
env: $env
instance_id: $instance_id
public_ip: $public_ip

# SSH connection details
ssh_command: "$ssh_command"
EOF

    print_success "Inventory files generated:"
    echo "  - ansible/inventory/$env.ini"
    echo "  - ansible/inventory/$env.json"
    echo "  - ansible/inventory/host_vars/$public_ip.yml"
    
    # Test connectivity
    print_status "Testing SSH connectivity..."
    if ssh -i ~/.ssh/iac-demo-key.pem -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$public_ip "echo 'SSH test successful'" 2>/dev/null; then
        print_success "SSH connectivity test passed."
    else
        print_error "SSH connectivity test failed. The instance might not be ready yet."
        echo "Try running the test again in a few minutes:"
        echo "  ssh -i ~/.ssh/iac-demo-key.pem -o StrictHostKeyChecking=no ubuntu@$public_ip"
        return 1
    fi
    
    # Test Ansible connectivity
    if command -v ansible &> /dev/null; then
        print_status "Testing Ansible connectivity..."
        cd ansible
        if ansible -i "inventory/$env.ini" "$env-web" -m ping; then
            print_success "Ansible connectivity test passed."
        else
            print_error "Ansible connectivity test failed."
            cd - > /dev/null
            return 1
        fi
        cd - > /dev/null
    else
        print_status "Ansible not found. Skipping connectivity test."
    fi
    
    return 0
}

main() {
    local environment=""
    
    # Parse arguments
    if [[ $# -eq 0 ]]; then
        print_error "Environment is required."
        usage
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            dev|staging|prod)
                environment=$1
                shift
                ;;
            --help)
                usage
                ;;
            *)
                print_error "Unknown argument: $1"
                usage
                ;;
        esac
    done
    
    if [[ -z "$environment" ]]; then
        print_error "Environment is required."
        usage
    fi
    
    echo -e "${BLUE}=== Ansible Inventory Generator ===${NC}"
    echo
    
    if ! generate_inventory "$environment"; then
        print_error "Failed to generate inventory for $environment environment."
        exit 1
    fi
    
    echo
    print_success "Inventory generation completed successfully!"
    echo
    print_status "Next steps:"
    echo "1. Run Ansible playbook:"
    echo "   cd ansible"
    echo "   ansible-playbook -i inventory/$environment.ini playbooks/site.yml -e \"env=$environment\""
    echo
    echo "2. Or test individual commands:"
    echo "   ansible -i ansible/inventory/$environment.ini web_servers -m ping"
    echo "   ansible -i ansible/inventory/$environment.ini web_servers -a \"uptime\""
}

main "$@"