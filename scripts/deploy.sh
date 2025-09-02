set -euo pipefail

# Colors
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
    echo "Usage: $0 <environment> [options]"
    echo
    echo "Environments:"
    echo "  dev, staging, prod"
    echo
    echo "Options:"
    echo "  --plan-only      Only run terraform plan"
    echo "  --skip-ansible   Skip Ansible configuration"
    echo "  --auto-approve   Skip confirmation prompts"
    echo "  --help          Show this help message"
    echo
    echo "Examples:"
    echo "  $0 dev"
    echo "  $0 staging --plan-only"
    echo "  $0 prod --auto-approve"
    exit 1
}

deploy_terraform() {
    local env=$1
    local plan_only=${2:-false}
    local auto_approve=${3:-false}
    
    print_status "Deploying Terraform infrastructure for $env environment..."
    
    cd "terraform/environments/$env"
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan
    print_status "Planning Terraform deployment..."
    terraform plan -out=tfplan
    
    if [ "$plan_only" = true ]; then
        print_success "Plan completed. Use 'terraform apply tfplan' to apply changes."
        return 0
    fi
    
    # Apply
    if [ "$auto_approve" = false ]; then
        echo
        read -p "Do you want to apply these changes? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Deployment cancelled by user."
            return 1
        fi
    fi
    
    print_status "Applying Terraform changes..."
    terraform apply tfplan
    
    print_success "Terraform deployment completed for $env environment."
    
    # Get outputs
    echo
    print_status "Terraform Outputs:"
    terraform output
    
    cd - > /dev/null
}

configure_ansible() {
    local env=$1
    
    print_status "Configuring application with Ansible for $env environment..."
    
    # Generate inventory
    print_status "Generating Ansible inventory..."
    cd "terraform/environments/$env"
    
    local public_ip=$(terraform output -raw public_ip)
    local instance_id=$(terraform output -raw instance_id)
    
    cd - > /dev/null
    
    # Create inventory file
    cat > "ansible/inventory/$env.ini" << EOF
[$env-web]
$public_ip ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/iac-demo-key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[web_servers]
$public_ip

[$env]
$public_ip

[all:vars]
env=$env
instance_id=$instance_id
EOF

    # Wait for instance to be ready
    print_status "Waiting for instance to be ready..."
    local max_attempts=20
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if ssh -i ~/.ssh/iac-demo-key.pem -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$public_ip "echo 'SSH ready'" &>/dev/null; then
            print_success "SSH connection established."
            break
        else
            print_status "Attempt $attempt/$max_attempts - Waiting for SSH..."
            sleep 15
            ((attempt++))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_error "Failed to establish SSH connection after $max_attempts attempts."
        return 1
    fi
    
    # Run Ansible playbook
    cd ansible
    print_status "Running Ansible playbook..."
    
    export ANSIBLE_HOST_KEY_CHECKING=False
    ansible-playbook \
        -i "inventory/$env.ini" \
        -e "env=$env" \
        -e "app_name=iac-multi-env" \
        playbooks/site.yml \
        --timeout 300
    
    cd - > /dev/null
    
    print_success "Ansible configuration completed."
}

health_check() {
    local env=$1
    
    print_status "Performing health check..."
    
    cd "terraform/environments/$env"
    local public_ip=$(terraform output -raw public_ip)
    cd - > /dev/null
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        print_status "Health check attempt $attempt/$max_attempts..."
        
        if curl -f --connect-timeout 10 --max-time 30 "http://$public_ip" &>/dev/null; then
            print_success "Health check passed!"
            echo
            print_status "Web server is accessible at: http://$public_ip"
            
            # Show web content
            echo
            print_status "Web server response:"
            curl -s "http://$public_ip" | grep -o "Hello from [^<]*" || echo "Custom content displayed"
            
            return 0
        else
            print_warning "Health check failed, retrying in 10 seconds..."
            sleep 10
            ((attempt++))
        fi
    done
    
    print_error "Health check failed after $max_attempts attempts."
    return 1
}

main() {
    local environment=""
    local plan_only=false
    local skip_ansible=false
    local auto_approve=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            dev|staging|prod)
                environment=$1
                shift
                ;;
            --plan-only)
                plan_only=true
                shift
                ;;
            --skip-ansible)
                skip_ansible=true
                shift
                ;;
            --auto-approve)
                auto_approve=true
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
    
    # Validate environment
    if [[ -z "$environment" ]]; then
        print_error "Environment is required."
        usage
    fi
    
    if [[ ! "$environment" =~ ^(dev|staging|prod)$ ]]; then
        print_error "Invalid environment. Must be: dev, staging, or prod"
        exit 1
    fi
    
    # Check prerequisites
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed."
        exit 1
    fi
    
    if [ "$skip_ansible" = false ] && ! command -v ansible &> /dev/null; then
        print_error "Ansible is not installed."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured."
        exit 1
    fi
    
    echo -e "${BLUE}=== Deploying $environment Environment ===${NC}"
    echo
    
    # Deploy infrastructure
    if ! deploy_terraform "$environment" "$plan_only" "$auto_approve"; then
        print_error "Terraform deployment failed."
        exit 1
    fi
    
    if [ "$plan_only" = true ]; then
        exit 0
    fi
    
    # Configure application
    if [ "$skip_ansible" = false ]; then
        if ! configure_ansible "$environment"; then
            print_error "Ansible configuration failed."
            exit 1
        fi
        
        # Health check
        if ! health_check "$environment"; then
            print_warning "Health check failed, but deployment might still be successful."
        fi
    fi
    
    echo
    print_success "Deployment completed successfully!"
    echo
    print_status "Summary:"
    cd "terraform/environments/$environment"
    echo "  Environment: $environment"
    echo "  Instance ID: $(terraform output -raw instance_id)"
    echo "  Public IP: $(terraform output -raw public_ip)"
    echo "  Web URL: $(terraform output -raw web_url)"
    echo "  SSH Command: $(terraform output -raw ssh_command)"
}

main "$@"