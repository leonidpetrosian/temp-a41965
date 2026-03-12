packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/googlecompute"
    }
    vagrant = {
      version = ">= 1.0.3"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}

source "googlecompute" "vpn" {
  project_id          = var.project_id
  source_image_family = "ubuntu-2204-lts"
  zone                = var.zone
  ssh_username        = var.ssh_username
  image_name          = "vpn-node-{{timestamp}}"
  image_description   = "VPN Node Image built with Packer"
  image_family        = "vpn-node"
}

source "vagrant" "vpn" {
  source_path = "ubuntu/jammy64"
  provider    = "virtualbox"
  add_force   = true
  communicator = "ssh"
}

build {
  sources = [
    "source.googlecompute.vpn",
    "source.vagrant.vpn"
  ]

  # Create directories
  provisioner "shell" {
    inline = [
      "sudo mkdir -p /opt/vpn/bin",
      "sudo chown -R $USER:$USER /opt/vpn"
    ]
  }

  # Upload binaries
  provisioner "file" {
    source      = "../../build/agent"
    destination = "/opt/vpn/bin/agent"
  }

  provisioner "file" {
    source      = "../../build/server"
    destination = "/opt/vpn/bin/server"
  }

  # Run startup script
  provisioner "shell" {
    script = "../scripts/startup.sh"
    execute_command = "sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
  }

  # Cleanup and final checks
  provisioner "shell" {
    inline = [
      "echo 'Image build complete!'"
    ]
  }
}
