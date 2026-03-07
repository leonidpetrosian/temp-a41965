# Variables
BINARY_DIR=bin
TERRAFORM_DIR=terraform
GO_CMD=go
TF_CMD=terraform

.PHONY: all deps build infra-init infra-apply infra-destroy clean help

# Default target
all: help

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
	cd $(TERRAFORM_DIR) && vagrant up

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
	@echo "  infra-init     Initialize Terraform in $(TERRAFORM_DIR)/"
	@echo "  infra-apply    Apply Terraform infrastructure"
	@echo "  infra-destroy  Destroy Terraform infrastructure"
	@echo "  clean          Remove build artifacts"
	@echo "  help           Show this help message"
