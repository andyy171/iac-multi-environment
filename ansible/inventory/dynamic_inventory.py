#!/usr/bin/env python3
"""
Dynamic Inventory Script for Ansible
Generates inventory from Terraform state files
"""

import json
import sys
import os
import subprocess
import argparse
import boto3
from typing import Dict, List, Any, Optional
import logging

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class TerraformInventory:
    """
    Generate Ansible inventory from Terraform state
    """
    
    def __init__(self):
        self.inventory = {
            '_meta': {
                'hostvars': {}
            }
        }
        self.project_root = self._find_project_root()
        self.terraform_environments = ['dev', 'staging', 'prod']
        
    def _find_project_root(self) -> str:
        """Find the project root directory"""
        current_dir = os.path.dirname(os.path.abspath(__file__))
        while current_dir != '/':
            if os.path.exists(os.path.join(current_dir, 'terraform')):
                return current_dir
            current_dir = os.path.dirname(current_dir)
        
        # Fallback to relative path
        return os.path.join(os.path.dirname(__file__), '..', '..')
    
    def _run_terraform_command(self, env: str, command: List[str]) -> Optional[Dict]:
        """Run terraform command and return JSON output"""
        terraform_dir = os.path.join(self.project_root, 'terraform', 'environments', env)
        
        if not os.path.exists(terraform_dir):
            logger.warning(f"Terraform directory not found: {terraform_dir}")
            return None
            
        try:
            # Change to terraform directory
            old_cwd = os.getcwd()
            os.chdir(terraform_dir)
            
            # Run terraform command
            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                check=True
            )
            
            os.chdir(old_cwd)
            
            if result.stdout:
                return json.loads(result.stdout)
            return {}
            
        except subprocess.CalledProcessError as e:
            logger.warning(f"Terraform command failed for {env}: {e}")
            return None
        except json.JSONDecodeError as e:
            logger.warning(f"Failed to parse Terraform output for {env}: {e}")
            return None
        except Exception as e:
            logger.warning(f"Unexpected error for {env}: {e}")
            return None
        finally:
            # Ensure we return to original directory
            try:
                os.chdir(old_cwd)
            except:
                pass
    
    def _get_terraform_outputs(self, env: str) -> Optional[Dict]:
        """Get terraform outputs for an environment"""
        return self._run_terraform_command(env, ['terraform', 'output', '-json'])
    
    def _check_terraform_state(self, env: str) -> bool:
        """Check if terraform state exists for an environment"""
        result = self._run_terraform_command(env, ['terraform', 'show', '-json'])
        return result is not None and result.get('values') is not None
    
    def _get_ec2_instances_from_aws(self, region: str = 'ap-southeast-1') -> List[Dict]:
        """Get EC2 instances directly from AWS API as fallback"""
        try:
            ec2 = boto3.client('ec2', region_name=region)
            response = ec2.describe_instances(
                Filters=[
                    {
                        'Name': 'tag:Project',
                        'Values': ['iac-multi-environment']
                    },
                    {
                        'Name': 'instance-state-name',
                        'Values': ['running', 'pending']
                    }
                ]
            )
            
            instances = []
            for reservation in response['Reservations']:
                for instance in reservation['Instances']:
                    instances.append(instance)
            
            return instances
            
        except Exception as e:
            logger.warning(f"Failed to get EC2 instances from AWS: {e}")
            return []
    
    def _extract_host_info_from_terraform(self, env: str, outputs: Dict) -> Optional[Dict]:
        """Extract host information from terraform outputs"""
        try:
            # Try to get values from terraform outputs
            public_ip = outputs.get('public_ip', {}).get('value')
            private_ip = outputs.get('private_ip', {}).get('value')
            instance_id = outputs.get('instance_id', {}).get('value')
            key_name = outputs.get('key_name', {}).get('value')
            
            if not public_ip:
                logger.warning(f"No public IP found for {env} environment")
                return None
            
            host_info = {
                'ansible_host': public_ip,
                'ansible_user': 'ubuntu',
                'ansible_ssh_private_key_file': f'~/.ssh/{key_name}.pem',
                'environment': env,
                'private_ip': private_ip,
                'instance_id': instance_id,
                'key_name': key_name,
                'ansible_ssh_common_args': '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
            }
            
            return host_info
            
        except Exception as e:
            logger.error(f"Error extracting host info for {env}: {e}")
            return None
    
    def _extract_host_info_from_ec2(self, instance: Dict) -> Optional[Dict]:
        """Extract host information from EC2 instance data"""
        try:
            # Get environment from tags
            env = None
            key_name = instance.get('KeyName', 'iac-demo-key')
            
            for tag in instance.get('Tags', []):
                if tag['Key'] == 'Environment':
                    env = tag['Value']
                    break
            
            if not env:
                return None
            
            public_ip = instance.get('PublicIpAddress')
            private_ip = instance.get('PrivateIpAddress')
            instance_id = instance.get('InstanceId')
            
            if not public_ip:
                return None
            
            host_info = {
                'ansible_host': public_ip,
                'ansible_user': 'ubuntu',
                'ansible_ssh_private_key_file': f'~/.ssh/{key_name}.pem',
                'environment': env,
                'private_ip': private_ip,
                'instance_id': instance_id,
                'key_name': key_name,
                'ansible_ssh_common_args': '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null',
                'source': 'aws-api'
            }
            
            return host_info
            
        except Exception as e:
            logger.error(f"Error extracting host info from EC2: {e}")
            return None
    
    def _add_host_to_inventory(self, env: str, host_info: Dict):
        """Add host to inventory"""
        hostname = f"{env}-web-server"
        
        # Add to _meta.hostvars
        self.inventory['_meta']['hostvars'][hostname] = host_info
        
        # Add to web_servers group
        if 'web_servers' not in self.inventory:
            self.inventory['web_servers'] = {
                'hosts': [],
                'vars': {}
            }
        self.inventory['web_servers']['hosts'].append(hostname)
        
        # Add to environment-specific group
        if env not in self.inventory:
            self.inventory[env] = {
                'hosts': [],
                'vars': {
                    'environment': env
                }
            }
        self.inventory[env]['hosts'].append(hostname)
        
        # Add to all group
        if 'all' not in self.inventory:
            self.inventory['all'] = {
                'vars': {
                    'ansible_python_interpreter': '/usr/bin/python3',
                    'ansible_ssh_common_args': '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null',
                    'ansible_host_key_checking': False
                }
            }
    
    def generate_inventory(self, specific_env: Optional[str] = None) -> Dict:
        """Generate complete inventory"""
        environments = [specific_env] if specific_env else self.terraform_environments
        
        hosts_found = 0
        
        for env in environments:
            logger.info(f"Processing {env} environment...")
            
            # Try to get info from Terraform first
            if self._check_terraform_state(env):
                outputs = self._get_terraform_outputs(env)
                if outputs:
                    host_info = self._extract_host_info_from_terraform(env, outputs)
                    if host_info:
                        self._add_host_to_inventory(env, host_info)
                        hosts_found += 1
                        logger.info(f"Added {env} host from Terraform state")
                        continue
            
            logger.warning(f"No Terraform state found for {env}, trying AWS API...")
        
        # Fallback: Try to get instances directly from AWS
        if hosts_found == 0:
            logger.info("Trying to get instances from AWS API as fallback...")
            ec2_instances = self._get_ec2_instances_from_aws()
            
            for instance in ec2_instances:
                host_info = self._extract_host_info_from_ec2(instance)
                if host_info:
                    env = host_info['environment']
                    if not specific_env or env == specific_env:
                        self._add_host_to_inventory(env, host_info)
                        hosts_found += 1
                        logger.info(f"Added {env} host from AWS API")
        
        logger.info(f"Total hosts found: {hosts_found}")
        return self.inventory
    
    def get_host_vars(self, hostname: str) -> Dict:
        """Get variables for a specific host"""
        return self.inventory['_meta']['hostvars'].get(hostname, {})


class EC2Inventory:
    """
    Alternative inventory using AWS EC2 tags
    """
    
    def __init__(self, region: str = 'ap-southeast-1'):
        self.region = region
        self.inventory = {
            '_meta': {
                'hostvars': {}
            }
        }
    
    def generate_inventory(self) -> Dict:
        """Generate inventory from EC2 tags"""
        try:
            ec2 = boto3.client('ec2', region_name=self.region)
            
            # Get instances with our project tag
            response = ec2.describe_instances(
                Filters=[
                    {
                        'Name': 'tag:Project',
                        'Values': ['iac-multi-environment']
                    },
                    {
                        'Name': 'instance-state-name',
                        'Values': ['running']
                    }
                ]
            )
            
            for reservation in response['Reservations']:
                for instance in reservation['Instances']:
                    self._process_instance(instance)
            
            return self.inventory
            
        except Exception as e:
            logger.error(f"Failed to generate EC2 inventory: {e}")
            return self.inventory
    
    def _process_instance(self, instance: Dict):
        """Process a single EC2 instance"""
        try:
            # Extract tags
            tags = {tag['Key']: tag['Value'] for tag in instance.get('Tags', [])}
            
            environment = tags.get('Environment')
            if not environment:
                return
            
            hostname = f"{environment}-{tags.get('Name', 'unknown')}"
            public_ip = instance.get('PublicIpAddress')
            
            if not public_ip:
                return
            
            # Host variables
            host_vars = {
                'ansible_host': public_ip,
                'ansible_user': 'ubuntu',
                'ansible_ssh_private_key_file': f"~/.ssh/{instance.get('KeyName', 'iac-demo-key')}.pem",
                'private_ip': instance.get('PrivateIpAddress'),
                'instance_id': instance.get('InstanceId'),
                'instance_type': instance.get('InstanceType'),
                'availability_zone': instance.get('Placement', {}).get('AvailabilityZone'),
                'environment': environment,
                'tags': tags,
                'ansible_ssh_common_args': '-o StrictHostKeyChecking=no'
            }
            
            # Add to hostvars
            self.inventory['_meta']['hostvars'][hostname] = host_vars
            
            # Add to groups
            self._add_to_group('all', hostname)
            self._add_to_group('web_servers', hostname)
            self._add_to_group(environment, hostname)
            
            # Add to instance type group
            instance_type = instance.get('InstanceType', 'unknown')
            self._add_to_group(f"type_{instance_type.replace('.', '_')}", hostname)
            
        except Exception as e:
            logger.error(f"Error processing instance: {e}")
    
    def _add_to_group(self, group_name: str, hostname: str):
        """Add host to a group"""
        if group_name not in self.inventory:
            self.inventory[group_name] = {'hosts': []}
        
        if hostname not in self.inventory[group_name]['hosts']:
            self.inventory[group_name]['hosts'].append(hostname)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Dynamic Inventory for Ansible')
    parser.add_argument('--list', action='store_true', help='List all hosts')
    parser.add_argument('--host', help='Get variables for specific host')
    parser.add_argument('--env', help='Filter by environment (dev/staging/prod)')
    parser.add_argument('--source', choices=['terraform', 'ec2'], default='terraform',
                       help='Inventory source (default: terraform)')
    parser.add_argument('--region', default='ap-southeast-1', help='AWS region')
    parser.add_argument('--verbose', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        if args.source == 'terraform':
            inventory_generator = TerraformInventory()
        else:
            inventory_generator = EC2Inventory(region=args.region)
        
        if args.list:
            if args.source == 'terraform':
                inventory = inventory_generator.generate_inventory(args.env)
            else:
                inventory = inventory_generator.generate_inventory()
            print(json.dumps(inventory, indent=2))
        
        elif args.host:
            if args.source == 'terraform':
                inventory_generator.generate_inventory()
                host_vars = inventory_generator.get_host_vars(args.host)
            else:
                inventory_generator.generate_inventory()
                host_vars = inventory_generator.inventory['_meta']['hostvars'].get(args.host, {})
            print(json.dumps(host_vars, indent=2))
        
        else:
            parser.print_help()
            sys.exit(1)
    
    except Exception as e:
        logger.error(f"Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()