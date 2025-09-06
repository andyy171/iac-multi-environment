# IaC Multi-Environment on AWS
## Project Overview
This project demonstrates an Infrastructure as Code (IaC) practice by deploying a multi-environment (dev, staging, prod) web application infrastructure on AWS. Each environment runs an independent Nginx web server with environment-specific configurations, security hardening, monitoring, and backup solutions, all fully automated through CI/CD pipelines.
**Tools and Technology**
- **Infrastructure Provisioning**: Terraform
- **Configuration Management**: Ansible
- **CI/CD Pipeline**: GitHub Actions
- **Cloud Provider**: AWS (Free Tier)
- **Web Server**: Nginx
- **State Management**: AWS S3 + DynamoDB
- **Version Control**: Git/GitHub
- **Monitoring**: CloudWatch

---

## Project Structure
```
iac-multi-env/
├── .github/
│   └── workflows/
│       ├── ci-cd.yml                    # Main CI/CD pipeline
│       ├── terraform-plan.yml           # PR validation & security scanning
│       └── cleanup.yml                  # Resource cleanup
├── terraform/
│   ├── environments/
│   │   ├── dev/
│   │   │   ├── main.tf                 # Dev environment config
│   │   │   ├── variables.tf            # Dev variables with validation
│   │   │   ├── outputs.tf              # Comprehensive outputs
│   │   │   ├── terraform.tfvars        # Dev-specific values
│   │   │   └── backend.tf              # Dev state backend (auto-generated)
│   │   ├── staging/
│   │   │   ├── main.tf                 # Staging environment config
│   │   │   ├── variables.tf            # Staging variables
│   │   │   ├── outputs.tf              # Staging outputs
│   │   │   ├── terraform.tfvars        # Staging-specific values
│   │   │   └── backend.tf              # Staging state backend (auto-generated)
│   │   └── prod/
│   │       ├── main.tf                 # Production environment config
│   │       ├── variables.tf            # Production variables
│   │       ├── outputs.tf              # Production outputs with security
│   │       ├── terraform.tfvars        # Production-specific values
│   │       └── backend.tf              # Production state backend (auto-generated
│   ├── modules/
│   │   └── web-infrastructure/
│   │       ├── main.tf                 # Core infrastructure resources
│   │       ├── variables.tf            # Input variables with validation
│   │       ├── outputs.tf              # Comprehensive output values
│   │       ├── security.tf             # Security groups, KMS, IAM, S3
│   │       ├── networking.tf           # VPC, subnets, NAT, Flow Logs
│   │       └── versions.tf             # Provider version constraints
│   └── scripts/
│       ├── init-backend.sh             # Automated S3 & DynamoDB setup
│       └── generate-inventory.sh       # Dynamic Ansible inventory
├── ansible/
│   ├── playbooks/
│   │   ├── site.yml                    # Main orchestration playbook
│   │   ├── base-system.yml             # Base system configuration
│   │   ├── nginx.yml                   # Nginx installation & hardening
│   │   ├── security.yml                # Security hardening & compliance
│   │   ├── monitoring.yml              # Monitoring & alerting setup
│   │   ├── logging.yml                 # Centralized logging
│   │   ├── backup.yml                  # Backup & disaster recovery
│   │   ├── health-check.yml            # Health verification tasks
│   │   └── deploy.yml                  # Complete deployment workflow
│   ├── inventory/
│   │   ├── group_vars/
│   │   │   ├── all.yml                 # Global variables & defaults
│   │   │   ├── dev.yml                 # Dev-specific configuration
│   │   │   ├── staging.yml             # Staging-specific configuration
│   │   │   └── prod.yml                # Production-specific configuration
│   │   └── dynamic_inventory.py        # Dynamic inventory with fallback
│   ├── roles/
│   │   └── nginx/
│   │       ├── tasks/main.yml
│   │       ├── templates/
│   │       │   └── index.html.j2
│   │       ├── handlers/main.yml
│   │       └── vars/main.yml
│   └── ansible.cfg                     # Ansible configuration
├── scripts/
│   ├── setup.sh                        # Initial project setup
│   ├── deploy.sh                       # Manual deployment script
│   └── cleanup.sh                      # Resource cleanup script
├── docs/
│   ├── architecture.md                 # Architecture documentation
│   ├── troubleshooting.md              # Common issues & solutions
│   └── diagrams/
│       └── infrastructure.png          # Architecture diagram
├── .gitignore
├── .pre-commit-config.yaml             # Pre-commit hooks
├── requirements.txt                    # Python dependencies
└── README.md                           # This file
```
---

## Prerequisites
**Required Software and Versions**
- **Terraform:** >= 1.5.0
- **Ansible:** >= 2.15.0
- **Python:** >= 3.8
- **AWS CLI:** >= 2.0
- **Git:** >= 2.30
- **jq**: >= 1.6 (for JSON processing)

**AWS Requirements**
- AWS Account with appropriate permissions
- IAM user with programmatic access
- AWS CLI configured with credentials
- Required AWS permissions for:
  - EC2 (instances, security groups, key pairs)
  - VPC (networks, subnets, internet gateways)
  - S3 (buckets, objects)
  - DynamoDB (tables)
  - IAM (roles, policies)
  - CloudWatch (logs, metrics)
  - KMS (keys, encryption)

**System Requirements**
- OS: Linux, macOS, or Windows (WSL recommended)
- RAM: Minimum 4GB
- Storage: 2GB free space
- Network: Internet access for downloading packages

---

## Installation and Setup

### 1. Clone the Repository
```bash
git clone https://github.com/andyy171/iac-multi-environment.git
cd iac-multi-environment
```

### 2. Install Required Tools

**On Ubuntu/Debian:**
```bash
# Update package list
sudo apt update

# Install Python and pip
sudo apt install python3 python3-pip python3-venv jq unzip curl wget -y

# Install Terraform
wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
unzip terraform_1.5.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
chmod +x /usr/local/bin/terraform

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installations
terraform --version
aws --version
python3 --version
jq --version
```

**On macOS:**
```bash
# Using Homebrew
brew install terraform awscli python3 jq
```

### 3. Configure AWS Credentials
```bash
# Configure AWS CLI
aws configure

# Enter your credentials:
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region name: ap-southeast-1
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

### 4. Generate SSH Key Pair
```bash
# Generate new SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/iac-demo-key -N ""

# Import public key to AWS (replace with your region)
aws ec2 import-key-pair \
    --key-name iac-demo-key \
    --public-key-material fileb://~/.ssh/iac-demo-key.pub \
    --region ap-southeast-1

# Set proper permissions
chmod 600 ~/.ssh/iac-demo-key
chmod 644 ~/.ssh/iac-demo-key.pub
```

### 5. Set Up Python Virtual Environment
```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # On Linux/macOS
# venv\Scripts\activate     # On Windows

# Install Python dependencies
pip install -r requirements.txt

# Verify Ansible installation
ansible --version
```


---

## Configuration

### 1. Backend Configuration
Initialize Terraform state management:
```bash
# Run the backend initialization script
chmod +x terraform/scripts/init-backend.sh
./terraform/scripts/init-backend.sh

# This creates:
# - S3 buckets for each environment state storage
# - DynamoDB table for state locking
# - Backend configuration files
# - Example terraform.tfvars files
```

### 2. Environment-Specific Configuration
Update the `terraform.tfvars` files in each environment directory to match your requirements:

**terraform/environments/dev/terraform.tfvars:**
```hcl
environment     = "dev"
region          = "ap-southeast-1"
instance_type   = "t2.micro"
key_name        = "iac-demo-key"
allowed_cidr_blocks = ["0.0.0.0/0"]  # Restrict in production
```

**terraform/environments/prod/terraform.tfvars:**
```hcl
environment     = "prod"
region          = "ap-southeast-1"
instance_type   = "t3.medium"
key_name        = "iac-demo-key"
use_elastic_ip  = true
enable_encryption = true
allowed_cidr_blocks = ["YOUR_OFFICE_IP/32"]  # Restrict appropriately
```

### 3. GitHub Secrets Configuration
Add the following secrets to your GitHub repository (Settings → Secrets and variables → Actions):
```
AWS_ACCESS_KEY_ID: Your AWS access key
AWS_SECRET_ACCESS_KEY: Your AWS secret key
SSH_PRIVATE_KEY: Content of ~/.ssh/iac-demo-key
INFRACOST_API_KEY: (Optional) For cost estimation
```

---

## How to Run

### Manual Deployment

#### 1. Deploy Infrastructure with Terraform
```bash
# Navigate to desired environment
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Plan the deployment (review changes)
terraform plan

# Apply the changes
terraform apply

# Get the outputs
terraform output

# Example output:
# instance_id = "i-1234567890abcdef0"
# public_ip = "13.232.xxx.xxx"
# web_url = "http://13.232.xxx.xxx"
# ssh_command = "ssh -i ~/.ssh/iac-demo-key.pem ubuntu@13.232.xxx.xxx"
```

#### 2. Configure Application with Ansible
```bash
# Generate dynamic inventory
cd ../../../
chmod +x terraform/scripts/generate-inventory.sh
./terraform/scripts/generate-inventory.sh dev

# Run Ansible playbook
cd ansible
ansible-playbook -i inventory/dev.ini playbooks/site.yml -e "env=dev"

# Or run specific playbooks
ansible-playbook -i inventory/dev.ini playbooks/security.yml
ansible-playbook -i inventory/dev.ini playbooks/monitoring.yml
```

#### 3. Test the Deployment
```bash
# Get the public IP
PUBLIC_IP=$(cd terraform/environments/dev && terraform output -raw public_ip)

# Test web server response
curl http://$PUBLIC_IP

# Test health endpoint
curl http://$PUBLIC_IP/health

# Test status endpoint
curl http://$PUBLIC_IP/status

# Expected output for main page:
# "Welcome to dev environment!"
```

### Automated Deployment via GitHub Actions

#### 1. Trigger Pipeline
```bash
git add .
git commit -m "Deploy infrastructure"
git push origin main

# The CI/CD pipeline will automatically:
# - Validate Terraform configurations
# - Run security scans
# - Plan infrastructure changes
# - Deploy to environments (if configured)
```

#### 2. Environment-Specific Deployment
```bash
# Using manual deployment script
chmod +x scripts/deploy.sh
./scripts/deploy.sh dev

# Using GitHub Actions (create environment-specific tags)
git tag deploy-dev-v1.0
git push origin deploy-dev-v1.0
```

### Health Checks and Monitoring
```bash
# Run health checks
ansible-playbook -i inventory/dev.ini playbooks/health-check.yml

# Check system monitoring
ssh -i ~/.ssh/iac-demo-key ubuntu@$PUBLIC_IP
sudo /opt/webapp/scripts/system-monitor.sh

# View logs
tail -f /var/log/iac-multi-environment/application.log
```

### Backup and Recovery
```bash
# Manual backup
ansible-playbook -i inventory/dev.ini playbooks/backup.yml

# Test backup restoration
ansible-playbook -i inventory/dev.ini playbooks/backup.yml --tags restore

# View backup status
ssh -i ~/.ssh/iac-demo-key ubuntu@$PUBLIC_IP
ls -la /opt/webapp/backups/
```

---

## Resource Cleanup

### Individual Environment Cleanup
```bash
# Manual cleanup for specific environment
cd terraform/environments/dev
terraform destroy -auto-approve

# Or use Ansible for graceful shutdown
cd ../../ansible
ansible-playbook -i inventory/dev.ini playbooks/site.yml --tags cleanup
```

### Complete Infrastructure Cleanup
```bash
# Use the cleanup script for all environments
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh

# Or use GitHub Actions cleanup workflow
# Go to Actions → Cleanup Resources → Run workflow
```

### Backend Cleanup (Complete Reset)
```bash
# This removes ALL Terraform state - USE WITH EXTREME CAUTION
./terraform/scripts/init-backend.sh --cleanup-all
```

---

## Troubleshooting

### Common Issues

#### 1. Terraform Issues
```bash
# State lock issues
terraform force-unlock LOCK_ID

# Backend configuration issues
terraform init -reconfigure

# Module issues
terraform get -update
```

#### 2. Ansible Issues
```bash
# Connection issues
ansible all -i inventory/dev.ini -m ping

# SSH key issues
ssh-add ~/.ssh/iac-demo-key
ansible-playbook --private-key ~/.ssh/iac-demo-key ...

# Inventory issues
./terraform/scripts/generate-inventory.sh dev --verbose
```

#### 3. AWS Issues
```bash
# Credential issues
aws sts get-caller-identity

# Region issues
aws configure set region ap-southeast-1

# Permission issues
aws iam get-user
```

---

## Environment Specifications

| Feature | Dev | Staging | Production |
|---------|-----|---------|------------|
| Instance Type | t2.micro | t3.small | t3.medium |
| Elastic IP | No | No | Yes |
| Encryption | No | Yes | Yes |
| VPC Flow Logs | No | Yes | Yes |
| S3 Logging | No | Yes | Yes |
| Monitoring | Basic | Standard | Detailed |
| Backup | No | Weekly | Daily |
| Security | Basic | Medium | High |
| SSL/TLS | Optional | Optional | Required |
| Auto-Scaling | No | No | Optional |


---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---