provider "google" {
  project = var.project_id
  region  = var.region
}

# 1. Network Setup
resource "google_compute_network" "vpn_network" {
  name                    = "vpn-network"
  auto_create_subnetworks = true
}

# 2. Firewall Rules
# Allow WireGuard (Default 51820 UDP)
resource "google_compute_firewall" "allow_wireguard" {
  name    = "allow-wireguard"
  network = google_compute_network.vpn_network.name

  allow {
    protocol = "udp"
    ports    = ["51820"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Allow SSH for management
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpn_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# 3. Compute Instance (VPN Node)
resource "google_compute_instance" "vpn_node" {
  name         = "vpn-node-us-east"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    network = google_compute_network.vpn_network.name
    access_config {
      # This provides a public IP
    }
  }

  metadata_startup_script = file("${path.module}/../scripts/startup.sh")

  tags = ["wireguard", "vpn"]

  # Enable IP Forwarding on the instance
  can_ip_forward = true
}

output "node_public_ip" {
  value = google_compute_instance.vpn_node.network_interface[0].access_config[0].nat_ip
}
