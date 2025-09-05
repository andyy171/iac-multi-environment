#!/bin/bash

# generate-inventory.sh - Generate Ansible inventory from Terraform output
# This script extracts Terraform outputs and creates Ansible inventory files

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"
INVENTORY_DIR="${ANSIBLE_DIR}/inventory"

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

# Show usage
show_usage() {
    echo "Usage: $0 [ENVIRONMENT] [OPTIONS]"
    echo ""
    echo "Generate Ansible inventory from Terraform outputs"
    echo ""
    echo "Arguments:"
    echo "  ENVIRONMENT    Environment name (dev, staging, prod, or all)"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verbose  Enable verbose output"
    echo "  -f, --format   Output format (ini, yaml, json) [default: ini]"
    echo "  -o, --output   Output directory [default: ansible/inventory]"
    echo ""
    echo "Examples:"
    echo "  $0 dev                    # Generate inventory for dev environment"
    echo "  $0 all                    # Generate inventory for all environments"
    echo "  $0 prod -f yaml           # Generate YAML format inventory"
    echo ""
}

# Parse command line arguments
parse_args() {
    ENVIRONMENT=""
    FORMAT="ini"
    OUTPUT_DIR="${INVENTORY_DIR}"
    VERBOSE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--format)
                FORMAT="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            *)
                if [[ -z "$ENVIRONMENT" ]]; then
                    ENVIRONMENT="$1"
                else
                    log_error "Unknown option: $1"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate environment
    if [[ -z "$ENVIRONMENT" ]]; then
        log_error "Environment is required"
        show_usage
        exit 1
    fi
    
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod|all)$ ]]; then
        log_error "Environment must be one of: dev, staging, prod, all"
        exit 1
    fi
    
    # Validate format
    if [[ ! "$FORMAT" =~ ^(ini|yaml|json)$ ]]; then
        log_error "Format must be one of: ini, yaml, json"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed"
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq for JSON processing."
        exit 1
    fi
    
    # Check if yq is installed (for YAML format)
    if [[ "$FORMAT" == "yaml" ]] && ! command -v yq &> /dev/null; then
        log_warning "yq is not installed. YAML output will be limited."
    fi
    
    log_success "Prerequisites check completed"
}

# Get Terraform output for an environment
get_terraform_output() {
    local env=$1
    local terraform_dir="${PROJECT_ROOT}/terraform/environments/${env}"
    
    if [[ ! -d "$terraform_dir" ]]; then
        log_error "Terraform directory not found: $terraform_dir"
        return 1
    fi
    
    log_info "Getting Terraform output for $env environment..."
    
    # Change to terraform directory
    cd "$terraform_dir"
    
    # Check if terraform state exists
    if ! terraform show &>/dev/null; then
        log_warning "No Terraform state found for $env environment"
        return 1
    fi
    
    # Get terraform output in JSON format
    terraform output -json
}

# Generate INI format inventory
generate_ini_inventory() {
    local env=$1
    local output_data=$2
    local output_file="${OUTPUT_DIR}/${env}.ini"
    
    log_info "Generating INI inventory for $env: $output_file"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Parse JSON output
    local public_ip
    local private_ip
    local instance_id
    local key_name
    
    public_ip=$(echo "$output_data" | jq -r '.public_ip.value // empty')
    private_ip=$(echo "$output_data" | jq -r '.private_ip.value // empty')
    instance_id=$(echo "$output_data" | jq -r '.instance_id.value // empty')
    key_name=$(echo "$output_data" | jq -r '.key_name.value // empty')
    
    if [[ -z "$public_ip" || "$public_ip" == "null" ]]; then
        log_warning "No public IP found for $env environment"
        return 1
    fi
    
    # Generate INI file
    cat > "$output_file" << EOF
# Ansible Inventory for $env environment
# Generated on $(date)

[web_servers]
${env}-web-server ansible_host=${public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/${key_name}.pem

[${env}]
${env}-web-server

[${env}:vars]
environment=${env}
instance_id=${instance_id}
private_ip=${private_ip}
ansible_ssh_common_args=-o StrictHostKeyChecking=no

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args=-o StrictHostKeyChecking=no
ansible_host_key_checking=False
EOF
    
    log_success "INI inventory generated: $output_file"
}

# Generate YAML format inventory
generate_yaml_inventory() {
    local env=$1
    local output_data=$2
    local output_file="${OUTPUT_DIR}/${env}.yml"
    
    log_info "Generating YAML inventory for $env: $output_file"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Parse JSON output
    local public_ip
    local private_ip
    local instance_id
    local key_name
    
    public_ip=$(echo "$output_data" | jq -r '.public_ip.value // empty')
    private_ip=$(echo "$output_data" | jq -r '.private_ip.value // empty')
    instance_id=$(echo "$output_data" | jq -r '.instance_id.value // empty')
    key_name=$(echo "$output_data" | jq -r '.key_name.value // empty')
    
    if [[ -z "$public_ip" || "$public_ip" == "null" ]]; then
        log_warning "No public IP found for $env environment"
        return 1
    fi
    
    # Generate YAML file
    cat > "$output_file" << EOF
---
# Ansible Inventory for $env environment
# Generated on $(date)

all:
  vars:
    ansible_python_interpreter: /usr/bin/python3
    ansible_ssh_common_args: -o StrictHostKeyChecking=no
    ansible_host_key_checking: false
  children:
    web_servers:
      hosts:
        ${env}-web-server:
          ansible_host: ${public_ip}
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/${key_name}.pem
          environment: ${env}
          instance_id: ${instance_id}
          private_ip: ${private_ip}
    ${env}:
      hosts:
        ${env}-web-server:
      vars:
        environment: ${env}
        instance_id: ${instance_id}
        private_ip: ${private_ip}
EOF
    
    log_success "YAML inventory generated: $output_file"
}

# Generate JSON format inventory
generate_json_inventory() {
    local env=$1
    local output_data=$2
    local output_file="${OUTPUT_DIR}/${env}.json"
    
    log_info "Generating JSON inventory for $env: $output_file"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Parse JSON output
    local public_ip
    local private_ip
    local instance_id
    local key_name
    
    public_ip=$(echo "$output_data" | jq -r '.public_ip.value // empty')
    private_ip=$(echo "$output_data" | jq -r '.private_ip.value // empty')
    instance_id=$(echo "$output_data" | jq -r '.instance_id.value // empty')
    key_name=$(echo "$output_data" | jq -r '.key_name.value // empty')
    
    if [[ -z "$public_ip" || "$public_ip" == "null" ]]; then
        log_warning "No public IP found for $env environment"
        return 1
    fi
    
    # Generate JSON file
    cat > "$output_file" << EOF
{
  "_meta": {
    "hostvars": {
      "${env}-web-server": {
        "ansible_host": "${public_ip}",
        "ansible_user": "ubuntu",
        "ansible_ssh_private_key_file": "~/.ssh/${key_name}.pem",
        "environment": "${env}",
        "instance_id": "${instance_id}",
        "private_ip": "${private_ip}"
      }
    }
  },
  "all": {
    "vars": {
      "ansible_python_interpreter": "/usr/bin/python3",
      "ansible_ssh_common_args": "-o StrictHostKeyChecking=no",
      "ansible_host_key_checking": false
    }
  },
  "web_servers": {
    "hosts": ["${env}-web-server"]
  },
  "${env}": {
    "hosts": ["${env}-web-server"],
    "vars": {
      "environment": "${env}",
      "instance_id": "${instance_id}",
      "private_ip": "${private_ip}"
    }
  }
}
EOF
    
    log_success "JSON inventory generated: $output_file"
}

# Generate inventory for a single environment
generate_inventory_for_env() {
    local env=$1
    
    log_info "Processing $env environment..."
    
    # Get Terraform output
    local output_data
    if ! output_data=$(get_terraform_output "$env"); then
        log_error "Failed to get Terraform output for $env"
        return 1
    fi
    
    if [[ -z "$output_data" ]]; then
        log_warning "No output data for $env environment"
        return 1
    fi
    
    # Generate inventory based on format
    case "$FORMAT" in
        ini)
            generate_ini_inventory "$env" "$output_data"
            ;;
        yaml)
            generate_yaml_inventory "$env" "$output_data"
            ;;
        json)
            generate_json_inventory "$env" "$output_data"
            ;;
    esac
}

# Generate combined inventory for all environments
generate_combined_inventory() {
    local output_file="${OUTPUT_DIR}/all.${FORMAT}"
    
    log_info "Generating combined inventory: $output_file"
    
    case "$FORMAT" in
        ini)
            generate_combined_ini_inventory
            ;;
        yaml)
            generate_combined_yaml_inventory
            ;;
        json)
            generate_combined_json_inventory
            ;;
    esac
}

# Generate combined INI inventory
generate_combined_ini_inventory() {
    local output_file="${OUTPUT_DIR}/all.ini"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    cat > "$output_file" << EOF
# Combined Ansible Inventory for all environments
# Generated on $(date)

[web_servers]
EOF
    
    # Add hosts from each environment
    for env in dev staging prod; do
        local terraform_dir="${PROJECT_ROOT}/terraform/environments/${env}"
        if [[ -d "$terraform_dir" ]]; then
            cd "$terraform_dir"
            if terraform show &>/dev/null; then
                local output_data
                output_data=$(terraform output -json 2>/dev/null || echo "{}")
                local public_ip
                public_ip=$(echo "$output_data" | jq -r '.public_ip.value // empty')
                local key_name
                key_name=$(echo "$output_data" | jq -r '.key_name.value // empty')
                
                if [[ -n "$public_ip" && "$public_ip" != "null" ]]; then
                    echo "${env}-web-server ansible_host=${public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/${key_name}.pem" >> "$output_file"
                fi
            fi
        fi
    done
    
    # Add group definitions
    cat >> "$output_file" << EOF

[dev]
dev-web-server

[staging]
staging-web-server

[prod]
prod-web-server

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args=-o StrictHostKeyChecking=no
ansible_host_key_checking=False
EOF
    
    log_success "Combined INI inventory generated: $output_file"
}

# Generate host summary
generate_host_summary() {
    log_info "Generating host summary..."
    
    local summary_file="${OUTPUT_DIR}/hosts_summary.txt"
    
    cat > "$summary_file" << EOF
# Host Summary
# Generated on $(date)

Environment | Host | Public IP | Instance ID | Status
-----------|------|-----------|-------------|--------
EOF
    
    for env in dev staging prod; do
        local terraform_dir="${PROJECT_ROOT}/terraform/environments/${env}"
        if [[ -d "$terraform_dir" ]]; then
            cd "$terraform_dir"
            if terraform show &>/dev/null; then
                local output_data
                output_data=$(terraform output -json 2>/dev/null || echo "{}")
                local public_ip
                local instance_id
                public_ip=$(echo "$output_data" | jq -r '.public_ip.value // "N/A"')
                instance_id=$(echo "$output_data" | jq -r '.instance_id.value // "N/A"')
                
                echo "${env} | ${env}-web-server | ${public_ip} | ${instance_id} | Active" >> "$summary_file"
            else
                echo "${env} | ${env}-web-server | N/A | N/A | No State" >> "$summary_file"
            fi
        else
            echo "${env} | ${env}-web-server | N/A | N/A | Not Found" >> "$summary_file"
        fi
    done
    
    log_success "Host summary generated: $summary_file"
    
    # Display summary
    if [[ "$VERBOSE" == "true" ]]; then
        echo ""
        log_info "Host Summary:"
        cat "$summary_file"
    fi
}

# Test connectivity to hosts
test_connectivity() {
    log_info "Testing SSH connectivity to hosts..."
    
    for env in dev staging prod; do
        local inventory_file="${OUTPUT_DIR}/${env}.${FORMAT}"
        if [[ -f "$inventory_file" ]]; then
            log_info "Testing connectivity to $env environment..."
            
            # Use ansible to test connectivity
            if command -v ansible &> /dev/null; then
                ansible all -i "$inventory_file" -m ping --one-line || log_warning "Failed to connect to $env hosts"
            else
                log_warning "Ansible not installed, skipping connectivity test"
            fi
        fi
    done
}

# Main execution
main() {
    log_info "Starting Ansible inventory generation..."
    
    # Parse arguments
    parse_args "$@"
    
    log_info "Environment: $ENVIRONMENT"
    log_info "Format: $FORMAT"
    log_info "Output Directory: $OUTPUT_DIR"
    
    # Check prerequisites
    check_prerequisites
    
    # Generate inventory
    if [[ "$ENVIRONMENT" == "all" ]]; then
        # Generate for all environments
        local success_count=0
        for env in dev staging prod; do
            if generate_inventory_for_env "$env"; then
                ((success_count++))
            fi
        done
        
        # Generate combined inventory if any environment succeeded
        if [[ $success_count -gt 0 ]]; then
            generate_combined_inventory
        fi
        
        log_info "Generated inventory for $success_count environments"
    else
        # Generate for single environment
        generate_inventory_for_env "$ENVIRONMENT"
    fi
    
    # Generate host summary
    generate_host_summary
    
    # Test connectivity if verbose mode
    if [[ "$VERBOSE" == "true" ]] && command -v ansible &> /dev/null; then
        test_connectivity
    fi
    
    log_success "Inventory generation completed!"
    echo ""
    echo "Generated files in $OUTPUT_DIR:"
    find "$OUTPUT_DIR" -type f -name "*.${FORMAT}" -o -name "*.txt" | sort
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi