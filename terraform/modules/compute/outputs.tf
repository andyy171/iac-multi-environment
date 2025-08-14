
output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = aws_launch_template.web.id
}

output "launch_template_arn" {
  description = "ARN of the Launch Template"
  value       = aws_launch_template.web.arn
}

output "launch_template_latest_version" {
  description = "Latest version of the Launch Template"
  value       = aws_launch_template.web.latest_version
}

output "autoscaling_group_id" {
  description = "ID of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.id
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.arn
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}

output "key_pair_name" {
  description = "Name of the EC2 Key Pair"
  value       = aws_key_pair.main.key_name
}

output "key_pair_arn" {
  description = "ARN of the EC2 Key Pair"
  value       = aws_key_pair.main.arn
}

output "iam_role_arn" {
  description = "ARN of the IAM role for EC2 instances"
  value       = aws_iam_role.ec2_role.arn
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "iam_instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = aws_iam_instance_profile.ec2_profile.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.web.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.web.arn
}

# Data source outputs for Ansible integration
output "ami_id" {
  description = "ID of the AMI used for instances"
  value       = data.aws_ami.ubuntu.id
}

output "ami_name" {
  description = "Name of the AMI used for instances"
  value       = data.aws_ami.ubuntu.name
}

# Instance configuration for external tools
output "instance_config" {
  description = "Instance configuration details for external tools"
  value = {
    instance_type       = var.instance_type
    key_pair_name      = aws_key_pair.main.key_name
    security_group_ids = var.security_group_ids
    subnet_ids         = var.subnet_ids
    min_instances      = var.min_instances
    max_instances      = var.max_instances
    desired_instances  = var.desired_instances
    ami_id            = data.aws_ami.ubuntu.id
  }
  sensitive = false
}

# Ansible inventory information
output "ansible_info" {
  description = "Information needed for Ansible dynamic inventory"
  value = {
    environment                = var.environment
    autoscaling_group_name     = aws_autoscaling_group.web.name
    key_pair_name             = aws_key_pair.main.key_name
    cloudwatch_log_group_name = aws_cloudwatch_log_group.web.name
    tags = {
      Environment = var.environment
      Ansible     = "web"
      Project     = "IaC-Multi-Environment"
    }
  }
  sensitive = false
}