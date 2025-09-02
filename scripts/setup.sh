
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="iac-multi-env"
AWS_REGION="ap-south-1"
KEY_NAME="iac-demo-key"

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws-cli")
    fi
    
    if ! command -v python3 &> /dev/null; then
        missing_tools+=("python3")
    fi
    
    if ! command -v pip3 &> /dev/null; then
        missing_tools+=("pip3")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_status "Please install the missing tools and run this script again."
        exit 1
    fi
    
    print_success "All prerequisites are installed."
}

setup_python_environment() {
    print_status "Setting up Python virtual environment..."
    
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        print_success "Virtual environment created."
    fi
    
    source venv/bin/activate
    pip install --upgrade pip
    
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
        print_success "Python dependencies installed."
    else
        print_warning "requirements.txt not found. Installing basic requirements..."
        pip install ansible boto3 botocore
    fi
}

check_aws_credentials() {
    print_status "Checking AWS credentials..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured or invalid."
        print_status "Please run 'aws configure' to set up your credentials."
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local region=$(aws configure get region)
    
    print_success "AWS credentials valid. Account: $account_id, Region: $region"
}

create_ssh_key() {
    print_status "Setting up SSH key pair..."
    
    if [ ! -f "$HOME/.ssh/${KEY_NAME}.pem" ]; then
        ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/${KEY_NAME}" -N "" -C "iac-demo@$(hostname)"
        mv "$HOME/.ssh/${KEY_NAME}" "$HOME/.ssh/${KEY_NAME}.pem"
        chmod 600 "$HOME/.ssh/${KEY_NAME}.pem"
        
        print_status "Importing public key to AWS..."
        aws ec2 import-key-pair \
            --key-name "$KEY_NAME" \
            --public-key-material "fileb://$HOME/.ssh/${KEY_NAME}.pub" \
            --region "$AWS_REGION" || {
                print_warning "Key pair might already exist in AWS."
            }
        
        print_success "SSH key pair created and imported to AWS."
    else
        print_success "SSH key pair already exists."
    fi
}

setup_terraform_backend() {
    print_status "Setting up Terraform backend..."
    
    local environments=("dev" "staging" "prod")
    
    for env in "${environments[@]}"; do
        local bucket_name="${PROJECT_NAME}-terraform-state-${env}-${AWS_REGION}"
        
        # Create S3 bucket if it doesn't exist
        if ! aws s3 ls "s3://${bucket_name}" &> /dev/null; then
            print_status "Creating S3 bucket: $bucket_name"
            
            if [ "$AWS_REGION" = "us-east-1" ]; then
                aws s3 mb "s3://${bucket_name}"
            else
                aws s3 mb "s3://${bucket_name}" --region "$AWS_REGION"
            fi
            
            # Enable versioning
            aws s3api put-bucket-versioning \
                --bucket "$bucket_name" \
                --versioning-configuration Status=Enabled
            
            # Enable encryption
            aws s3api put-bucket-encryption \
                --bucket "$bucket_name" \
                --server-side-encryption-configuration '{
                    "Rules": [{
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "AES256"
                        }
                    }]
                }'
            
            # Block public access
            aws s3api put-public-access-block \
                --bucket "$bucket_name" \
                --public-access-block-configuration \
                    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
            
            print_success "S3 bucket created: $bucket_name"
        else
            print_success "S3 bucket already exists: $bucket_name"
        fi
    done
    
    # Create DynamoDB table for state locking
    local table_name="${PROJECT_NAME}-terraform-locks"
    
    if ! aws dynamodb describe-table --table-name "$table_name" &> /dev/null; then
        print_status "Creating DynamoDB table: $table_name"
        
        aws dynamodb create-table \
            --table-name "$table_name" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
            --region "$AWS_REGION"
        
        print_status "Waiting for DynamoDB table to be active..."
        aws dynamodb wait table-exists --table-name "$table_name"
        
        print_success "DynamoDB table created: $table_name"
    else
        print_success "DynamoDB table already exists: $table_name"
    fi
}

create_project_structure() {
    print_status "Creating project structure..."
    
    local directories=(
        "terraform/modules/web-infrastructure"
        "terraform/environments/dev"
        "terraform/environments/staging"
        "terraform/environments/prod"
        "terraform/scripts"
        "ansible/playbooks"
        "ansible/roles/nginx/tasks"
        "ansible/roles/nginx/templates"
        "ansible/roles/nginx/handlers"
        "ansible/roles/nginx/vars"
        "ansible/inventory/group_vars"
        ".github/workflows"
        "scripts"
        "docs"
        "docs/diagrams"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
    done
    
    print_success "Project structure created."
}

create_environment_configs() {
    print_status "Creating environment-specific configurations..."
    
    local environments=("dev" "staging" "prod")
    local vpc_cidrs=("10.0.0.0/16" "10.1.0.0/16" "10.2.0.0/16")
    local subnet_cidrs=("10.0.1.0/24" "10.1.1.0/24" "10.2.1.0/24")
    
    for i in "${!environments[@]}"; do
        local env="${environments[$i]}"
        local vpc_cidr="${vpc_cidrs[$i]}"
        local subnet_cidr="${subnet_cidrs[$i]}"
        local bucket_name="${PROJECT_NAME}-terraform-state-${env}-${AWS_REGION}"
        
        # Create variables.tf for each environment
        cat > "terraform/environments/$env/variables.tf" << EOF
# Auto-generated by setup script

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "$env"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "$PROJECT_NAME"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "$AWS_REGION"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "$vpc_cidr"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "$subnet_cidr"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of the AWS key pair"
  type        = string
  default     = "$KEY_NAME"
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access web server"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_cidr_blocks" {
  description = "List of CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 8
}

variable "use_elastic_ip" {
  description = "Whether to allocate an Elastic IP"
  type        = bool
  default     = false
}
EOF

        # Create backend.tf for each environment
        cat > "terraform/environments/$env/backend.tf" << EOF
# Auto-generated by setup script

terraform {
  backend "s3" {
    bucket         = "$bucket_name"
    key            = "$env/terraform.tfstate"
    region         = "$AWS_REGION"
    dynamodb_table = "$PROJECT_NAME-terraform-locks"
    encrypt        = true
  }
}
EOF

        # Create outputs.tf for each environment
        cat > "terraform/environments/$env/outputs.tf" << EOF
# Auto-generated by setup script

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.web_infrastructure.vpc_id
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = module.web_infrastructure.instance_id
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.web_infrastructure.public_ip
}

output "web_url" {
  description = "URL to access the web server"
  value       = module.web_infrastructure.web_url
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = module.web_infrastructure.ssh_command
}

output "ansible_inventory" {
  description = "Ansible inventory information"
  value       = module.web_infrastructure.ansible_inventory
  sensitive   = true
}
EOF
    done
    
    print_success "Environment configurations created."
}

create_ansible_config() {
    print_status "Creating Ansible configuration..."
    
    cat > "ansible/ansible.cfg" << EOF
[defaults]
host_key_checking = False
inventory = inventory/
roles_path = roles/
stdout_callback = yaml
callback_whitelist = profile_tasks
forks = 10
timeout = 30

[ssh_connection]
ssh_args = -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
pipelining = True
EOF

    # Create group_vars files
    for env in dev staging prod; do
        cat > "ansible/inventory/group_vars/$env.yml" << EOF
---
# $env environment variables
env: $env
app_name: $PROJECT_NAME
nginx_port: 80
project_name: $PROJECT_NAME

# Environment-specific configurations
EOF
        
        case $env in
            "dev")
                echo "debug_mode: true" >> "ansible/inventory/group_vars/$env.yml"
                echo "log_level: debug" >> "ansible/inventory/group_vars/$env.yml"
                ;;
            "staging")
                echo "debug_mode: false" >> "ansible/inventory/group_vars/$env.yml"
                echo "log_level: info" >> "ansible/inventory/group_vars/$env.yml"
                ;;
            "prod")
                echo "debug_mode: false" >> "ansible/inventory/group_vars/$env.yml"
                echo "log_level: warn" >> "ansible/inventory/group_vars/$env.yml"
                ;;
        esac
    done
    
    cat > "ansible/inventory/group_vars/all.yml" << EOF
---
# Global variables for all environments
ansible_user: ubuntu
ansible_ssh_private_key_file: ~/.ssh/$KEY_NAME.pem
ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

# Common packages
common_packages:
  - curl
  - wget
  - unzip
  - git
  - htop
  - tree
  - vim

# Nginx configuration
nginx_worker_processes: auto
nginx_worker_connections: 1024
nginx_keepalive_timeout: 65
EOF

    print_success "Ansible configuration created."
}

create_requirements_file() {
    print_status "Creating requirements.txt..."
    
    cat > "requirements.txt" << EOF
# Ansible and related packages
ansible>=7.0.0
ansible-lint>=6.0.0

# AWS SDK for Python
boto3>=1.26.0
botocore>=1.29.0

# Additional utilities
PyYAML>=6.0
Jinja2>=3.1.0
requests>=2.28.0
EOF

    print_success "requirements.txt created."
}

create_gitignore() {
    print_status "Creating .gitignore..."
    
    cat > ".gitignore" << EOF
# Terraform
*.tfstate
*.tfstate.*
*.tfvars
.terraform/
.terraform.lock.hcl
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
share/python-wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Virtual environments
venv/
env/
ENV/
env.bak/
venv.bak/

# Ansible
*.retry
ansible.log
.vault_pass

# SSH Keys
*.pem
*.key
id_rsa*

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# Logs
*.log
logs/

# Temporary files
*.tmp
*.temp
.cache/

# AWS
.aws/
EOF

    print_success ".gitignore created."
}

show_next_steps() {
    print_success "Setup completed successfully!"
    echo
    echo -e "${GREEN}Next Steps:${NC}"
    echo "1. Activate the Python virtual environment:"
    echo -e "   ${BLUE}source venv/bin/activate${NC}"
    echo
    echo "2. Verify your AWS configuration:"
    echo -e "   ${BLUE}aws sts get-caller-identity${NC}"
    echo
    echo "3. Initialize Terraform for an environment:"
    echo -e "   ${BLUE}cd terraform/environments/dev${NC}"
    echo -e "   ${BLUE}terraform init${NC}"
    echo
    echo "4. Plan and apply your infrastructure:"
    echo -e "   ${BLUE}terraform plan${NC}"
    echo -e "   ${BLUE}terraform apply${NC}"
    echo
    echo "5. Configure the application with Ansible:"
    echo -e "   ${BLUE}cd ../../../ansible${NC}"
    echo -e "   ${BLUE}ansible-playbook -i inventory/dev.ini playbooks/site.yml -e \"env=dev\"${NC}"
    echo
    echo "6. Set up GitHub Actions by adding these secrets to your repository:"
    echo -e "   ${YELLOW}AWS_ACCESS_KEY_ID${NC} - Your AWS access key ID"
    echo -e "   ${YELLOW}AWS_SECRET_ACCESS_KEY${NC} - Your AWS secret access key"
    echo -e "   ${YELLOW}SSH_PRIVATE_KEY${NC} - Content of ~/.ssh/$KEY_NAME.pem"
    echo
    echo -e "${GREEN}For detailed instructions, check the README.md file.${NC}"
}

main() {
    echo -e "${BLUE}=== IaC Multi-Environment Setup Script ===${NC}"
    echo
    
    check_prerequisites
    setup_python_environment
    check_aws_credentials
    create_ssh_key
    create_project_structure
    setup_terraform_backend
    create_environment_configs
    create_ansible_config
    create_requirements_file
    create_gitignore
    
    show_next_steps
}

# Run main function
main "$@"