# Security Group for Web Server
resource "aws_security_group" "web" {
  name_prefix = "${var.environment}-web-sg-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for ${var.environment} web servers"

  tags = merge(local.common_tags, {
    Name = "${var.environment}-web-sg"
    Type = "SecurityGroup"
    Tier = "Web"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP access
resource "aws_security_group_rule" "web_http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  description       = "HTTP access from allowed CIDR blocks"
  security_group_id = aws_security_group.web.id
}

# HTTPS access
resource "aws_security_group_rule" "web_https_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  description       = "HTTPS access from allowed CIDR blocks"
  security_group_id = aws_security_group.web.id
}

# SSH access
resource "aws_security_group_rule" "web_ssh_ingress" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.ssh_cidr_blocks
  description       = "SSH access from allowed CIDR blocks"
  security_group_id = aws_security_group.web.id
}

# Custom port access 
resource "aws_security_group_rule" "web_custom_ingress" {
  count             = var.custom_port != null ? 1 : 0
  type              = "ingress"
  from_port         = var.custom_port
  to_port           = var.custom_port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  description       = "Custom port access"
  security_group_id = aws_security_group.web.id
}

# All outbound traffic
resource "aws_security_group_rule" "web_all_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "All outbound traffic"
  security_group_id = aws_security_group.web.id
}

# Security Group for Application Load Balancer (if used)
resource "aws_security_group" "alb" {
  count       = var.enable_load_balancer ? 1 : 0
  name_prefix = "${var.environment}-alb-sg-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for ${var.environment} Application Load Balancer"

  tags = merge(local.common_tags, {
    Name = "${var.environment}-alb-sg"
    Type = "SecurityGroup"
    Tier = "LoadBalancer"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ALB HTTP access
resource "aws_security_group_rule" "alb_http_ingress" {
  count             = var.enable_load_balancer ? 1 : 0
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  description       = "HTTP access to ALB"
  security_group_id = aws_security_group.alb[0].id
}

# ALB HTTPS access
resource "aws_security_group_rule" "alb_https_ingress" {
  count             = var.enable_load_balancer ? 1 : 0
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  description       = "HTTPS access to ALB"
  security_group_id = aws_security_group.alb[0].id
}

# ALB to Web Server communication
resource "aws_security_group_rule" "alb_to_web_egress" {
  count                    = var.enable_load_balancer ? 1 : 0
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web.id
  description              = "ALB to web servers"
  security_group_id        = aws_security_group.alb[0].id
}

# Web server access from ALB
resource "aws_security_group_rule" "web_from_alb_ingress" {
  count                    = var.enable_load_balancer ? 1 : 0
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb[0].id
  description              = "Web server access from ALB"
  security_group_id        = aws_security_group.web.id
}

# Security Group for Database (RDS)
resource "aws_security_group" "database" {
  count       = var.enable_database ? 1 : 0
  name_prefix = "${var.environment}-db-sg-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for ${var.environment} database servers"

  tags = merge(local.common_tags, {
    Name = "${var.environment}-db-sg"
    Type = "SecurityGroup"
    Tier = "Database"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Database access from web servers
resource "aws_security_group_rule" "db_from_web_ingress" {
  count                    = var.enable_database ? 1 : 0
  type                     = "ingress"
  from_port                = var.database_port
  to_port                  = var.database_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web.id
  description              = "Database access from web servers"
  security_group_id        = aws_security_group.database[0].id
}

# KMS Key for encryption
resource "aws_kms_key" "main" {
  count                   = var.enable_encryption ? 1 : 0
  description             = "KMS key for ${var.environment} environment encryption"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  enable_key_rotation     = var.environment == "prod" ? true : false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "EnableServiceAccess"
        Effect = "Allow"
        Principal = {
          Service = [
            "ec2.amazonaws.com",
            "rds.amazonaws.com",
            "s3.amazonaws.com"
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.environment}-kms-key"
    Type = "KMSKey"
  })
}

# KMS Key Alias
resource "aws_kms_alias" "main" {
  count         = var.enable_encryption ? 1 : 0
  name          = "alias/${var.environment}-${var.project_name}"
  target_key_id = aws_kms_key.main[0].key_id
}

# IAM Role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.environment}-ec2-role"
    Type = "IAMRole"
  })
}

# IAM Policy for EC2 instances
resource "aws_iam_role_policy" "ec2_policy" {
  name = "${var.environment}-ec2-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-*/*"
        ]
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = merge(local.common_tags, {
    Name = "${var.environment}-ec2-profile"
    Type = "IAMInstanceProfile"
  })
}

# CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/${var.environment}/application"
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(local.common_tags, {
    Name = "${var.environment}-app-log-group"
    Type = "LogGroup"
  })
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# S3 Bucket for storing logs and backups
resource "aws_s3_bucket" "logs" {
  count  = var.enable_s3_logging ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-logs-${random_id.bucket_suffix.hex}"

  tags = merge(local.common_tags, {
    Name = "${var.environment}-logs-bucket"
    Type = "S3Bucket"
  })
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "logs" {
  count  = var.enable_s3_logging ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count  = var.enable_s3_logging ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.enable_encryption ? aws_kms_key.main[0].arn : null
      sse_algorithm     = var.enable_encryption ? "aws:kms" : "AES256"
    }
    bucket_key_enabled = var.enable_encryption
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "logs" {
  count  = var.enable_s3_logging ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  count  = var.enable_s3_logging ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  rule {
    id     = "log_retention"
    status = "Enabled"

    expiration {
      days = var.environment == "prod" ? 90 : 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}