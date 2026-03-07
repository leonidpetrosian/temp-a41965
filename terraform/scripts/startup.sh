#!/bin/bash
# VPN Node Agent Startup Script

# 1. Update and Install Dependencies
export DEBIAN_FRONTEND=noninteractive
apt-get update
# Pre-configure iptables-persistent to avoid interactive prompts
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt-get install -y wireguard-tools iptables iptables-persistent git wget curl postgresql postgresql-contrib

# 2. Enable IPv4 Forwarding (Mandatory for VPN)
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-vpn.conf
sysctl -p /etc/sysctl.d/99-vpn.conf

# 3. Configure NAT (Masquerade)
PRIMARY_IF=$(ip route | grep default | awk '{print $5}' | head -n1)
iptables -t nat -A POSTROUTING -o "$PRIMARY_IF" -j MASQUERADE
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

# 3a. Initialize WireGuard wg0 Interface
if ! ip link show wg0 &> /dev/null; then
    ip link add dev wg0 type wireguard
    ip address add 10.8.0.1/24 dev wg0
    ip link set up dev wg0
fi

# 4. (Go is no longer required on the VM as we use pre-built binaries)
# GO_VERSION="1.22.1"
# if ! command -v go &> /dev/null; then
#     wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
#     rm -rf /usr/local/go && tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
#     rm go${GO_VERSION}.linux-amd64.tar.gz
# fi

# 5. Setup Postgres
sudo -u postgres psql -c "CREATE DATABASE vpn;"
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'password';"

# Initial Migration SQL Snippet
sudo -u postgres psql -d vpn -c "
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS nodes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    public_ip VARCHAR(255) NOT NULL,
    public_key VARCHAR(255) NOT NULL,
    listen_port INTEGER DEFAULT 51820,
    region VARCHAR(255),
    last_seen TIMESTAMP WITH TIME ZONE,
    status VARCHAR(255) DEFAULT 'offline'
);

CREATE TABLE IF NOT EXISTS peers (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    node_id INTEGER NOT NULL REFERENCES nodes(id),
    internal_ip VARCHAR(255) UNIQUE NOT NULL,
    public_key VARCHAR(255) NOT NULL,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
"

# 6. Prepare Application Directory
mkdir -p /opt/vpn
cd /opt/vpn

# 7. Create Systemd Service for Server
cat <<EOF > /etc/systemd/system/vpn-server.service
[Unit]
Description=VPN Control Plane Server
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/vpn
Environment="PATH=/usr/bin:/bin"
ExecStart=/opt/vpn/bin/server
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 8. Create Systemd Service for Agent
cat <<EOF > /etc/systemd/system/vpn-agent.service
[Unit]
Description=VPN Node Agent
After=network.target vpn-server.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/vpn
Environment="PATH=/usr/bin:/bin"
ExecStart=/opt/vpn/bin/agent
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 9. Start/Restart the services
systemctl daemon-reload
systemctl enable postgresql vpn-server vpn-agent
systemctl restart postgresql vpn-server vpn-agent
