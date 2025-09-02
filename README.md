# IaC Multi-Environment on AWS
## Project Overview
This project demonstrates Infrastructure as Code (IaC) best practices by deploying a multi-environment (dev, staging, prod) web application infrastructure on AWS. Each environment runs an independent Nginx web server that displays environment-specific content, fully automated through CI/CD pipelines.
**Tools and Technology**
- Infrastructure Provisioning: Terraform
- Configuration Management: Ansible
- CI/CD Pipeline: GitHub Actions
- Cloud Provider: AWS (Free Tier)
- Web Server: Nginx
- State Management: AWS S3 + DynamoDB
- Version Control: Git/GitHub

---

## Project Structure
```
iac-multi-env/
├── .github/
│   └── workflows/
│       ├── ci-cd.yml                    # Main CI/CD pipeline
│       ├── terraform-plan.yml           # PR validation
│       └── cleanup.yml                  # Resource cleanup
├── terraform/
│   ├── environments/
│   │   ├── dev/
│   │   │   ├── main.tf                 # Dev environment config
│   │   │   ├── terraform.tfvars        # Dev variables
│   │   │   └── backend.tf              # Dev state backend
│   │   ├── staging/
│   │   │   ├── main.tf
│   │   │   ├── terraform.tfvars
│   │   │   └── backend.tf
│   │   └── prod/
│   │       ├── main.tf
│   │       ├── terraform.tfvars
│   │       └── backend.tf
│   ├── modules/
│   │   └── web-infrastructure/
│   │       ├── main.tf                 # Main infrastructure resources
│   │       ├── variables.tf            # Input variables
│   │       ├── outputs.tf              # Output values
│   │       ├── security.tf             # Security groups & rules
│   │       ├── networking.tf           # VPC, subnets, routes
│   │       └── versions.tf             # Provider versions
│   └── scripts/
│       ├── init-backend.sh             # S3 bucket creation
│       └── generate-inventory.sh       # Ansible inventory generator
├── ansible/
│   ├── playbooks/
│   │   ├── site.yml                    # Main playbook
│   │   ├── nginx.yml                   # Nginx installation
│   │   └── monitoring.yml              # Basic monitoring setup
│   ├── inventory/
│   │   ├── group_vars/
│   │   │   ├── all.yml                 # Global variables
│   │   │   ├── dev.yml                 # Dev-specific vars
│   │   │   ├── staging.yml             # Staging-specific vars
│   │   │   └── prod.yml                # Prod-specific vars
│   │   └── dynamic_inventory.py        # Dynamic inventory script
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
- Terraform: >= 1.5.0
- Ansible: >= 2.15.0
- Python: >= 3.8
- AWS CLI: >= 2.0
- Git: >= 2.30

**AWS Requirements**
- AWS Account with appropriate permissions
- IAM user with programmatic access
- AWS CLI configured with credentials
- Required AWS permissions for EC2, VPC, S3, DynamoDB, and IAM

**System Requirements**
- OS: Linux, macOS, or Windows (WSL recommended)
- RAM: Minimum 4GB
- Storage: 2GB free space
- Network: Internet access for downloading packages

## Installation and Setup
1. Clone the Repository
bashgit clone https://github.com/andyy171/iac-multi-environment.git
cd iac-multi-environment
2. Install Required Tools
On Ubuntu/Debian:
```bash
sudo apt update # Update package list
```
### Install Python and pip
```
sudo apt install python3 python3-pip python3-venv -y
```
### Install Terraform
```
wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
unzip terraform_1.5.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```
### Install AWS CLI
```
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```
### Verify installations
```
terraform --version
aws --version
python3 --version
```
3. Configure AWS Credentials
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
4. Generate SSH Key Pair
```bash
# Generate new SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/iac-demo-key -N ""

# Import public key to AWS (replace ap-south-1 with your region)
aws ec2 import-key-pair \
    --key-name iac-demo-key \
    --public-key-material fileb://~/.ssh/iac-demo-key.pub \
    --region ap-south-1
```
5. Set Up Python Virtual Environment (for Ansible)
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
1. Backend Configuration
Before running Terraform, you need to create S3 buckets for state storage:
```bash
# Run the backend initialization script
./scripts/init-backend.sh

# This will create:
# - S3 buckets for each environment
# - DynamoDB table for state locking
```
2. Environment Variables
Update the terraform.tfvars files in each environment directory:
terraform/environments/dev/terraform.tfvars:
```
hclenvironment     = "dev"
region         = "ap-south-1"
instance_type  = "t2.micro"
key_name       = "iac-demo-key"
allowed_cidr   = ["0.0.0.0/0"]  # Restrict this in production
```
3. GitHub Secrets Configuration
Add the following secrets to your GitHub repository (Settings → Secrets and variables → Actions):
```
AWS_ACCESS_KEY_ID: Your AWS access key
AWS_SECRET_ACCESS_KEY: Your AWS secret key
SSH_PRIVATE_KEY: Content of your private key file (~/.ssh/iac-demo-key)
```
---
## How to Run
Manual Deployment
1. Deploy Infrastructure with Terraform
```bash
# Navigate to desired environment
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the changes
terraform apply -auto-approve

# Get the outputs
terraform output
Example output:
instance_id = "i-1234567890abcdef0"
public_ip = "13.232.xxx.xxx"
web_url = "http://13.232.xxx.xxx"
```
2. Configure Application with Ansible
```bash
# Generate dynamic inventory
cd ../../../
./terraform/scripts/generate-inventory.sh dev

# Run Ansible playbook
cd ansible
ansible-playbook -i inventory/dev.ini playbooks/site.yml -e "env=dev"
```
3. Test the Deployment
```bash
# Test web server response
curl http://$(cd terraform/environments/dev && terraform output -raw public_ip)

# Expected output: "Hello from dev environment!"
```
### Automated Deployment via GitHub Actions
1. Trigger Pipeline
```bash
git add .
git commit -m "Deploy infrastructure"
git push origin main
The CI/CD pipeline will automatically trigger changes and deploy the infrastructure.
```
2. Deploy only a specific environment:
```bash
# Using manual script
./scripts/deploy.sh dev

# Using GitHub Actions (create a tag)
git tag deploy-dev
git push origin deploy-dev
```
3. Cleanup Resources
```bash
# Manual cleanup for specific environment
cd terraform/environments/dev
terraform destroy -auto-approve

# Or use cleanup script for all environments
./scripts/cleanup.sh
```