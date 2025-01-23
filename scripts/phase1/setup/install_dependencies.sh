#!/bin/bash

set -e  # Exit on error

# Color coding for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

echo "=== Starting Development Environment Setup ==="
echo "This script will install all necessary dependencies for the Wasm Edge Computing project"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
fi

echo "=== Installing System Dependencies ==="
apt-get update || log_error "Failed to update package list"
apt-get install -y curl wget git build-essential || log_error "Failed to install basic dependencies"
log_success "Basic dependencies installed"

echo "=== Installing Docker ==="
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh || log_error "Docker installation failed"
    usermod -aG docker $SUDO_USER || log_error "Failed to add user to docker group"
    log_success "Docker installed successfully"
else
    echo "Docker already installed"
fi

echo "=== Installing kubectl ==="
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl || log_error "kubectl installation failed"
    log_success "kubectl installed successfully"
else
    echo "kubectl already installed"
fi

echo "=== Installing k3d ==="
if ! command -v k3d &> /dev/null; then
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash || log_error "k3d installation failed"
    log_success "k3d installed successfully"
else
    echo "k3d already installed"
fi

echo "=== Installing Helm ==="
if ! command -v helm &> /dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash || log_error "Helm installation failed"
    log_success "Helm installed successfully"
else
    echo "Helm already installed"
fi

log_success "All dependencies installed successfully!"
echo "Please log out and log back in for docker group changes to take effect"
