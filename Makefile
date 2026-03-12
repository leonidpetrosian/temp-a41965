# Variables
BINARY_DIR=build
DEPLOYMENTS_DIR=deployments
TERRAFORM_DIR=$(DEPLOYMENTS_DIR)/terraform
PACKER_DIR=$(DEPLOYMENTS_DIR)/packer
VAGRANT_DIR=$(DEPLOYMENTS_DIR)/vagrant
GO_CMD=go
TF_CMD=terraform

.PHONY: all deps build infra-init infra-apply infra-destroy vagrant-up vagrant-destroy packer-init packer-build-local packer-build-gcp clean help

# Default target
all: help

# Packer operations
packer-init:
	@echo "Initializing Packer..."
	cd $(PACKER_DIR) && packer init .

packer-build-local: build-linux
	@echo "Building local image with Packer (Vagrant)..."
	cd $(PACKER_DIR) && packer build -only=source.vagrant.vpn .

packer-build-gcp: build-linux
	@echo "Building GCP image with Packer..."
	cd $(PACKER_DIR) && packer build -only=source.googlecompute.vpn .

# Install Go dependencies
deps:
	@echo "Installing dependencies..."
	$(GO_CMD) mod download
	$(GO_CMD) mod tidy

# Build all applications
build:
	@echo "Building applications..."
	mkdir -p $(BINARY_DIR)
	$(GO_CMD) build -v -o $(BINARY_DIR)/agent ./cmd/agent
	$(GO_CMD) build -v -o $(BINARY_DIR)/server ./cmd/server

# Build all applications for Linux (Vagrant/VM)
build-linux:
	@echo "Building applications for Linux..."
	mkdir -p $(BINARY_DIR)
	GOOS=linux GOARCH=amd64 $(GO_CMD) build -v -o $(BINARY_DIR)/agent ./cmd/agent
	GOOS=linux GOARCH=amd64 $(GO_CMD) build -v -o $(BINARY_DIR)/server ./cmd/server

# Initialize Terraform
infra-init:
	@echo "Initializing infrastructure..."
	cd $(TERRAFORM_DIR) && $(TF_CMD) init

# Apply Terraform infrastructure
infra-apply:
	@echo "Applying infrastructure..."
	cd $(TERRAFORM_DIR) && $(TF_CMD) apply

# Destroy Terraform infrastructure
infra-destroy:
	@echo "Destroying infrastructure..."
	cd $(TERRAFORM_DIR) && $(TF_CMD) destroy

# Vagrant operations
vagrant-up: build-linux
	cd $(VAGRANT_DIR) && vagrant up

vagrant-destroy:
	cd $(VAGRANT_DIR) && vagrant destroy -f

# Remove build artifacts
clean:
	@echo "Cleaning up..."
	rm -rf $(BINARY_DIR)

# Show help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  deps           Install Go dependencies"
	@echo "  build          Build agent and server binaries locally"
	@echo "  build-linux    Build agent and server binaries for Linux/AMD64"
	@echo "  vagrant-up     Build for Linux and start Vagrant VM"
	@echo "  vagrant-destroy Destroy Vagrant VM"
	@echo "  infra-init     Initialize Terraform in $(TERRAFORM_DIR)/"
	@echo "  infra-apply    Apply Terraform infrastructure"
	@echo "  infra-destroy  Destroy Terraform infrastructure"
	@echo "  packer-init    Initialize Packer"
	@echo "  packer-build-local Build local VM image (Vagrant)"
	@echo "  packer-build-gcp   Build GCP cloud image"
	@echo "  clean          Remove build artifacts"
	@echo "  help           Show this help message"
