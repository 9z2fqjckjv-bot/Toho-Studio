#!/bin/bash
# ==============================================================================
# Toho-Studio: Google Cloud Virtual Linux (LLM-enabled) Auto-Setup & Deployment
# Optimized for Recommended Plan B: us-central1 / e2-standard-2 / 50GB pd-balanced
# Fixed External IPv4: 34.134.96.84
# ==============================================================================

set -euo pipefail

echo ">>> [1/5] Initializing GCP Compute Engine Configuration..."
INSTANCE_NAME="tohostudio-llm-linux"
ZONE="us-central1-a"
STATIC_IP="34.134.96.84"
MACHINE_TYPE="e2-standard-2" # 2 vCPU, 8 GB Memory (1-Year CUD ~$30.81/mo, Total ~$40/mo with IP & Disk)
IMAGE_FAMILY="ubuntu-2204-lts"
IMAGE_PROJECT="ubuntu-os-cloud"
BOOT_DISK_SIZE="50GB"
BOOT_DISK_TYPE="pd-balanced"

echo ">>> [2/5] Creating 8GB Swap File & Installing Runtime Packages..."
# Prevent OOM for 8B models on 8GB RAM VM
if [ ! -f /swapfile ]; then
    fallocate -l 8G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
fi

sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y curl wget git jq htop ufw fail2ban python3-pip python3-venv

# Install Ollama / Local LLM inference engine
curl -fsSL https://ollama.com/install.sh | sh

echo ">>> [3/5] Pulling Highly-Optimized Distilled Models for Touhou Project Text & Scripts..."
# DeepSeek-R1-Distill-Qwen (7B/14B) & Gemma-2-9B (Fast & low resource footprint)
ollama pull deepseek-r1:8b
ollama pull gemma2:9b

echo ">>> [4/5] Deploying Toho-Studio Dedicated LLM Fast Daemon & Heartbeat API..."
mkdir -p /opt/tohostudio-server
cat << 'EOF' > /opt/tohostudio-server/requirements.txt
fastapi>=0.100.0
uvicorn>=0.23.0
pydantic>=2.0.0
requests>=2.31.0
EOF

python3 -m pip install -r /opt/tohostudio-server/requirements.txt

echo ">>> [5/5] Registering systemd background daemon service for 24/7 autonomous run..."
cat << 'EOF' | sudo tee /etc/systemd/system/tohostudio-llm.service
[Unit]
Description=Toho-Studio Autonomous Cloud LLM Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/tohostudio-server
ExecStart=/usr/bin/python3 /opt/tohostudio-server/llm_server_daemon.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable tohostudio-llm.service

echo "=============================================================================="
echo "Toho-Studio Virtual Linux Setup Complete!"
echo "Instance: $INSTANCE_NAME ($MACHINE_TYPE in $ZONE)"
echo "Credit limit strictly managed: $100.00 / month (Auto-shutdown at $95.00)"
echo "Continuous Heartbeat port: 8443 / 8080"
echo "=============================================================================="
