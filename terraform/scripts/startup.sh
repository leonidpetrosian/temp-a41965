#!/bin/bash
# VPN Node Agent Startup Script

# 1. Update and Install Dependencies
apt-get update
apt-get install -y wireguard-tools iptables git wget

# 2. Enable IPv4 Forwarding (Critical for VPN)
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# 3. Setup basic NAT (Masquerade)
# Assuming 'eth0' is the public interface and 'wg0' is the tunnel
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
# Make iptables persistent
apt-get install -y iptables-persistent
iptables-save > /etc/iptables/rules.v4

# 4. Install Go (Minimal version for agent)
VERSION="1.21.0"
wget https://go.dev/dl/go${VERSION}.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go${VERSION}.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# 5. Setup Project & Build Agent
# Note: In production, you would pull from a private repo or download a release binary.
# For POC, we clones the repo (assuming it is public or ssh keys are set).
mkdir -p /opt/vpn
cd /opt/vpn

# [PLACEHOLDER] Clone your repository here:
git clone https://github.com/leonidpetrosian/temp-a41965.git .

# Since we are in a local dev environment, as a POC, we will just create 
# a placeholder service that expects the code to be available at /opt/vpn
# Or we can use Terraform to upload the code.

# 6. Create wg0 interface (empty for now, agent will fill it)
ip link add dev wg0 type wireguard
ip address add dev wg0 10.8.0.1/24
ip link set up dev wg0

# 7. Create Systemd Service for Agent
cat <<EOF > /etc/systemd/system/vpn-agent.service
[Unit]
Description=VPN Node Agent
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/vpn
Environment="PATH=/usr/local/go/bin:/usr/bin:/bin"
ExecStart=/usr/local/go/bin/go run cmd/agent/*.go
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
# systemctl enable vpn-agent
# systemctl start vpn-agent
