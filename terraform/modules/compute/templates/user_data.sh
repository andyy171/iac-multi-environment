
set -e

# Variables from Terraform
ENVIRONMENT="${environment}"
REGION="${region}"

# Update system
apt-get update -y
apt-get upgrade -y

# Install essential packages
apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    htop \
    jq \
    python3 \
    python3-pip \
    python3-venv \
    awscli \
    amazon-cloudwatch-agent

# Install Docker (for future container workloads)
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install Node.js (for modern web applications)
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Create application directory structure
mkdir -p /opt/app/{logs,config,scripts}
chown -R ubuntu:ubuntu /opt/app

# Install and configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "metrics": {
        "namespace": "IaC-MultiEnv/$ENVIRONMENT",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60,
                "resources": ["*"],
                "totalcpu": false
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": ["*"]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": ["*"]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            },
            "swap": {
                "measurement": [
                    "swap_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/nginx/access.log*",
                        "log_group_name": "/aws/ec2/$ENVIRONMENT/web",
                        "log_stream_name": "{instance_id}/nginx/access.log",
                        "multiline_start_pattern": "^\\\\d{1,3}\\\\.\\\\d{1,3}\\\\.\\\\d{1,3}\\\\.\\\\d{1,3}"
                    },
                    {
                        "file_path": "/var/log/nginx/error.log*",
                        "log_group_name": "/aws/ec2/$ENVIRONMENT/web",
                        "log_stream_name": "{instance_id}/nginx/error.log"
                    },
                    {
                        "file_path": "/opt/app/logs/application.log*",
                        "log_group_name": "/aws/ec2/$ENVIRONMENT/web",
                        "log_stream_name": "{instance_id}/application.log"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch agent
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Create a simple health check endpoint
cat > /opt/app/health.sh << 'EOF'
#!/bin/bash
# Simple health check script

echo "Content-Type: application/json"
echo ""

# Check system resources
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
memory_usage=$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}')
disk_usage=$(df -h / | awk 'NR==2{printf "%s", $5}' | sed 's/%//')

# Check Nginx status
if systemctl is-active --quiet nginx; then
    nginx_status="healthy"
else
    nginx_status="unhealthy"
fi

# Generate timestamp
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Output JSON health status
cat << JSON
{
    "status": "$nginx_status",
    "timestamp": "$timestamp",
    "environment": "$ENVIRONMENT",
    "instance_id": "$(curl -s http://169.254.169.254/latest/meta-data/instance-id)",
    "region": "$REGION",
    "system_metrics": {
        "cpu_usage_percent": "$cpu_usage",
        "memory_usage_percent": "$memory_usage",
        "disk_usage_percent": "$disk_usage"
    }
}
JSON
EOF

chmod +x /opt/app/health.sh

# Create a systemd service for health monitoring
cat > /etc/systemd/system/app-health.service << EOF
[Unit]
Description=Application Health Monitor
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=/opt/app/health.sh
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Enable health monitoring service
systemctl daemon-reload
systemctl enable app-health.service

# Create log rotation for application logs
cat > /etc/logrotate.d/app-logs << EOF
/opt/app/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
    su ubuntu ubuntu
}
EOF

# Set up automatic security updates
echo 'Unattended-Upgrade::Automatic-Reboot "false";' > /etc/apt/apt.conf.d/50unattended-upgrades
systemctl enable unattended-upgrades

# Create a startup script that runs after boot
cat > /opt/app/scripts/startup.sh << 'EOF'
#!/bin/bash
# Post-boot startup script

# Log startup
echo "$(date): Instance startup initiated" >> /opt/app/logs/startup.log

# Update instance tags with current status
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 create-tags --region $REGION --resources $INSTANCE_ID --tags Key=Status,Value=Ready || true

echo "$(date): Instance startup completed" >> /opt/app/logs/startup.log
EOF

chmod +x /opt/app/scripts/startup.sh

# Add startup script to crontab
echo "@reboot /opt/app/scripts/startup.sh" | crontab -