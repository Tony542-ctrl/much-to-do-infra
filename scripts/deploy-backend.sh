#!/bin/bash
set -euo pipefail

# =============================================
# Much-to-Do Backend — Rolling Deployment Script
# =============================================
# Usage: ./deploy-backend.sh <binary_path> <bastion_ip> <private_key_path> <ec2_ip_1> <ec2_ip_2>
#
# This script:
# 1. Copies the new binary to each EC2 instance via the bastion
# 2. Stops the service, replaces binary, starts the service
# 3. Waits for the health check to pass before moving to the next instance

BINARY_PATH="$1"
BASTION_IP="$2"
KEY_PATH="$3"
shift 3
EC2_IPS=("$@")

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
HEALTH_ENDPOINT="/health"
HEALTH_PORT="8080"
MAX_RETRIES=30
RETRY_INTERVAL=10

deploy_to_instance() {
  local target_ip="$1"
  echo "=========================================="
  echo "Deploying to instance: $target_ip"
  echo "=========================================="

  # Step 1: Copy binary to bastion, then from bastion to target
  echo "[1/4] Uploading binary via bastion..."
  scp $SSH_OPTS -i "$KEY_PATH" "$BINARY_PATH" "ec2-user@$BASTION_IP:/tmp/much-to-do"

  ssh $SSH_OPTS -i "$KEY_PATH" "ec2-user@$BASTION_IP" \
    "scp $SSH_OPTS -i ~/.ssh/deploy-key /tmp/much-to-do ec2-user@$target_ip:/tmp/much-to-do"

  # Step 2: Stop service, replace binary, start service
  echo "[2/4] Stopping service and replacing binary..."
  ssh $SSH_OPTS -i "$KEY_PATH" "ec2-user@$BASTION_IP" \
    "ssh $SSH_OPTS -i ~/.ssh/deploy-key ec2-user@$target_ip 'sudo systemctl stop much-to-do && sudo cp /tmp/much-to-do /opt/much-to-do/bin/much-to-do && sudo chmod +x /opt/much-to-do/bin/much-to-do && sudo systemctl start much-to-do'"

  # Step 3: Wait for health check
  echo "[3/4] Waiting for health check to pass..."
  local retries=0
  while [ $retries -lt $MAX_RETRIES ]; do
    local status
    status=$(ssh $SSH_OPTS -i "$KEY_PATH" "ec2-user@$BASTION_IP" \
      "ssh $SSH_OPTS -i ~/.ssh/deploy-key ec2-user@$target_ip 'curl -s -o /dev/null -w \"%{http_code}\" http://localhost:$HEALTH_PORT$HEALTH_ENDPOINT'" 2>/dev/null || echo "000")

    if [ "$status" = "200" ]; then
      echo "[4/4] ✅ Instance $target_ip is healthy!"
      return 0
    fi

    retries=$((retries + 1))
    echo "  Health check attempt $retries/$MAX_RETRIES — status: $status, retrying in ${RETRY_INTERVAL}s..."
    sleep $RETRY_INTERVAL
  done

  echo "❌ ERROR: Instance $target_ip failed health check after $MAX_RETRIES attempts!"
  exit 1
}

# --- Main: Rolling deploy across all instances ---
echo "Starting rolling deployment..."
echo "Binary: $BINARY_PATH"
echo "Bastion: $BASTION_IP"
echo "Targets: ${EC2_IPS[*]}"
echo ""

for ip in "${EC2_IPS[@]}"; do
  deploy_to_instance "$ip"
  echo ""
done

echo "=========================================="
echo "🎉 Rolling deployment complete!"
echo "=========================================="
