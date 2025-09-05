data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = merge(local.common_tags, {
    Name = "${var.environment}-vpc"
    Type = "VPC"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.environment}-igw"
    Type = "InternetGateway"
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.environment}-public-subnet-1"
    Type = "Public"
    Tier = "Web"
  })
}

# Additional public subnet for high availability 
resource "aws_subnet" "public_secondary" {
  count                   = length(data.aws_availability_zones.available.names) > 1 ? 1 : 0
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.environment}-public-subnet-2"
    Type = "Public"
    Tier = "Web"
  })
}

# Private Subnet 
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10)
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(local.common_tags, {
    Name = "${var.environment}-private-subnet-1"
    Type = "Private"
    Tier = "Database"
  })
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-public-rt"
    Type = "RouteTable"
    Tier = "Public"
  })
}

# Route Table Association for Primary Public Subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Route Table Association for Secondary Public Subnet
resource "aws_route_table_association" "public_secondary" {
  count          = length(aws_subnet.public_secondary)
  subnet_id      = aws_subnet.public_secondary[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway for Private Subnets 
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.environment}-nat-eip"
    Type = "EIP"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public.id

  tags = merge(local.common_tags, {
    Name = "${var.environment}-nat-gateway"
    Type = "NATGateway"
  })

  depends_on = [aws_internet_gateway.main]
}

# Route Table for Private Subnets
resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway ? 1 : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-private-rt"
    Type = "RouteTable"
    Tier = "Private"
  })
}

# Route Table Association for Private Subnet
resource "aws_route_table_association" "private" {
  count          = var.enable_nat_gateway ? 1 : 0
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private[0].id
}

# VPC Flow Logs 
resource "aws_flow_log" "vpc_flow_log" {
  count                = var.enable_vpc_flow_logs ? 1 : 0
  iam_role_arn         = aws_iam_role.flow_log[0].arn
  log_destination      = aws_cloudwatch_log_group.vpc_flow_log[0].arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
  log_destination_type = "cloud-watch-logs"

  tags = merge(local.common_tags, {
    Name = "${var.environment}-vpc-flow-log"
    Type = "FlowLog"
  })
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  count             = var.enable_vpc_flow_logs ? 1 : 0
  name              = "/aws/vpc/flowlogs/${var.environment}"
  retention_in_days = 14

  tags = merge(local.common_tags, {
    Name = "${var.environment}-vpc-flow-log-group"
    Type = "LogGroup"
  })
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_log" {
  count = var.enable_vpc_flow_logs ? 1 : 0
  name  = "${var.environment}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.environment}-vpc-flow-log-role"
    Type = "IAMRole"
  })
}

# IAM Policy for VPC Flow Logs
resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_vpc_flow_logs ? 1 : 0
  name  = "${var.environment}-vpc-flow-log-policy"
  role  = aws_iam_role.flow_log[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Network ACL for additional security (optional)
resource "aws_network_acl" "main" {
  count  = var.enable_network_acl ? 1 : 0
  vpc_id = aws_vpc.main.id

  # Allow HTTP traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Allow HTTPS traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow SSH traffic (restrict in production)
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  # Allow return traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow all outbound traffic
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-main-nacl"
    Type = "NetworkACL"
  })
}

# Associate Network ACL with public subnet
resource "aws_network_acl_association" "public" {
  count          = var.enable_network_acl ? 1 : 0
  network_acl_id = aws_network_acl.main[0].id
  subnet_id      = aws_subnet.public.id
}

# DHCP Options Set (optional)
resource "aws_vpc_dhcp_options" "main" {
  count               = var.custom_dns_servers != null ? 1 : 0
  domain_name_servers = var.custom_dns_servers
  domain_name         = "${var.environment}.local"

  tags = merge(local.common_tags, {
    Name = "${var.environment}-dhcp-options"
    Type = "DHCPOptions"
  })
}

resource "aws_vpc_dhcp_options_association" "main" {
  count           = var.custom_dns_servers != null ? 1 : 0
  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.main[0].id
}