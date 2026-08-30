#!/bin/bash
set -euxo pipefail

# =============================================
# Much-to-Do Backend — EC2 User Data Bootstrap
# =============================================
# This script runs on first boot to:
# 1. Install Go and build tools
# 2. Clone and build the backend binary
# 3. Configure environment variables
# 4. Set up systemd service
# 5. Install and configure CloudWatch Agent

APP_DIR="/opt/much-to-do"
BIN_DIR="$APP_DIR/bin"
LOG_DIR="$APP_DIR/logs"
GO_VERSION="1.25.1"

# --- System Updates ---
dnf update -y
dnf install -y git tar gzip

# --- Add swap space (t3.micro has only 1GB RAM, Go build needs more) ---
dd if=/dev/zero of=/swapfile bs=1M count=2048
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile swap swap defaults 0 0' >> /etc/fstab

# --- Install Go ---
cd /tmp
curl -LO "https://go.dev/dl/go$${GO_VERSION}.linux-amd64.tar.gz"
rm -rf /usr/local/go
tar -C /usr/local -xzf "go$${GO_VERSION}.linux-amd64.tar.gz"
export PATH=$PATH:/usr/local/go/bin
echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile.d/golang.sh

# --- Create app directories ---
mkdir -p "$BIN_DIR" "$LOG_DIR"

# --- Clone and build the backend ---
export HOME=/root
export GOMODCACHE=/root/go/pkg/mod
cd /tmp
git clone --branch feature/full-stack --depth 1 https://github.com/Innocent9712/much-to-do.git
cd much-to-do/Server/MuchToDo
/usr/local/go/bin/go build -o "$BIN_DIR/much-to-do" ./cmd/api/main.go
cp -r docs "$APP_DIR/docs" 2>/dev/null || true

# --- Clean up build artifacts to free disk space ---
rm -rf /tmp/much-to-do /root/go/pkg/mod /tmp/go*.tar.gz

# --- Write environment file ---
cat > "$APP_DIR/.env" <<'ENVFILE'
PORT=${backend_port}
MONGO_URI=${mongo_uri}
DB_NAME=${db_name}
JWT_SECRET_KEY=${jwt_secret_key}
JWT_EXPIRATION_HOURS=${jwt_expiration_hours}
ENABLE_CACHE=true
REDIS_ADDR=${redis_addr}
REDIS_PASSWORD=
ALLOWED_ORIGINS=${allowed_origins}
COOKIE_DOMAINS=${cookie_domains}
SECURE_COOKIE=true
LOG_LEVEL=INFO
LOG_FORMAT=json
ENVFILE

chmod 600 "$APP_DIR/.env"

# --- Create systemd service ---
cat > /etc/systemd/system/much-to-do.service <<'SERVICEFILE'
[Unit]
Description=Much-to-Do Backend API
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=ec2-user
Group=ec2-user
WorkingDirectory=/opt/much-to-do
ExecStart=/opt/much-to-do/bin/much-to-do
EnvironmentFile=/opt/much-to-do/.env
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=much-to-do

[Install]
WantedBy=multi-user.target
SERVICEFILE

# Fix ownership
chown -R ec2-user:ec2-user "$APP_DIR"

# Enable and start the service
systemctl daemon-reload
systemctl enable much-to-do
systemctl start much-to-do

# --- Install Amazon CloudWatch Agent ---
dnf install -y amazon-cloudwatch-agent

# --- Configure CloudWatch Agent ---
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONFIG'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "journald": {
        "units": [
          {
            "unit_name": "much-to-do.service",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 14
          }
        ]
      }
    },
    "force_flush_interval": 15
  }
}
CWCONFIG

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

systemctl enable amazon-cloudwatch-agent

echo ">>> Much-to-Do bootstrap complete! <<<"
