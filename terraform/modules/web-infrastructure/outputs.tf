output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "public_subnet_cidr_block" {
  description = "CIDR block of the public subnet"
  value       = aws_subnet.public.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "security_group_id" {
  description = "ID of the web security group"
  value       = aws_security_group.web.id
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "instance_arn" {
  description = "ARN of the EC2 instance"
  value       = aws_instance.web.arn
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = var.use_elastic_ip ? aws_eip.web[0].public_ip : aws_instance.web.public_ip
}

output "private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.web.private_ip
}

output "public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.web.public_dns
}

output "web_url" {
  description = "URL to access the web server"
  value       = "http://${var.use_elastic_ip ? aws_eip.web[0].public_ip : aws_instance.web.public_ip}"
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${var.use_elastic_ip ? aws_eip.web[0].public_ip : aws_instance.web.public_ip}"
}

output "availability_zone" {
  description = "Availability zone of the EC2 instance"
  value       = aws_instance.web.availability_zone
}

output "key_name" {
  description = "Name of the key pair used"
  value       = aws_instance.web.key_name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

# Outputs for Ansible dynamic inventory
output "ansible_inventory" {
  description = "Ansible inventory information"
  value = {
    hosts = {
      "${var.environment}-web" = {
        ansible_host         = var.use_elastic_ip ? aws_eip.web[0].public_ip : aws_instance.web.public_ip
        ansible_user         = "ubuntu"
        ansible_ssh_private_key_file = "~/.ssh/${var.key_name}.pem"
        environment          = var.environment
        instance_id          = aws_instance.web.id
        private_ip           = aws_instance.web.private_ip
      }
    }
    groups = {
      web_servers = ["${var.environment}-web"]
      "${var.environment}" = ["${var.environment}-web"]
      all = {
        vars = {
          ansible_ssh_common_args = "-o StrictHostKeyChecking=no"
        }
      }
    }
  }
}

# Output for monitoring and logging
output "resource_summary" {
  description = "Summary of created resources"
  value = {
    environment    = var.environment
    region        = var.region
    vpc_id        = aws_vpc.main.id
    instance_id   = aws_instance.web.id
    instance_type = aws_instance.web.instance_type
    public_ip     = var.use_elastic_ip ? aws_eip.web[0].public_ip : aws_instance.web.public_ip
    created_at    = timestamp()
  }
}