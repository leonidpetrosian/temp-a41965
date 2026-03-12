# Deploying VPN Nodes to Google Cloud

This directory contains the infrastructure-as-code required to provision VPN Node servers on GCP.

## Prerequisites
1.  [Terraform](https://www.terraform.io/downloads.html) installed.
2.  [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installed and authenticated (`gcloud auth application-default login`).
3.  A GCP Project ID.

## 1. Configuration
Create a `terraform.tfvars` file (optional, or pass variables during apply):
```hcl
project_id   = "your-project-id"
region       = "us-east1"
machine_type = "e2-micro"
```

## 2. Deployment
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## 3. What the Startup Script does:
The [startup.sh](scripts/startup.sh) script automatically:
- Installs `wireguard-tools` and `iptables`.
- **Enables IPv4 Forwarding**: Required to route client traffic to the internet.
- **Configures NAT (Masquerade)**: Translates the internal tunnel IPs (`10.8.0.x`) to the public IP of the VM.
- **Installs Go**: To build and run the Node Agent.
- **Systemd Service**: Configures the agent to start automatically on boot.

## 4. Security Note
By default, the Terraform script:
- Opens `UDP:51820` for WireGuard.
- Opens `TCP:22` for SSH.
- Enables `can_ip_forward = true` on the compute instance, which is mandatory for VPN traffic in GCP.
