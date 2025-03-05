#!/bin/bash
set -e

# Color coding for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

echo "=== Setting up WebAssembly Runtime Environment ==="

# Install Rust using rustup
if ! command -v rustc &> /dev/null; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    # Source the cargo environment
    source "$HOME/.cargo/env"
    # Verify installation
    if ! command -v rustc &> /dev/null; then
        log_error "Failed to install Rust. Please install manually from https://rustup.rs/"
    fi
fi

# Add wasm32-unknown-unknown target
echo "Adding WebAssembly target..."
rustup target add wasm32-unknown-unknown

# Install wasm-pack
echo "Installing wasm-pack..."
curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh

# Verify wasm-pack installation
if ! command -v wasm-pack &> /dev/null; then
    log_error "Failed to install wasm-pack"
fi

# Run the initial setup if not already done
if [ ! -d "src/hello_wasm" ]; then
    echo "Running initial setup..."
    ./setup.sh
fi

# Build the WebAssembly module
echo "Building WebAssembly module..."
cd build
chmod +x build.sh
./build.sh || log_error "Failed to build WebAssembly module"

# Verify the build artifacts
if [ ! -f "hello_wasm_bg.wasm" ] || [ ! -f "hello_wasm.js" ]; then
    log_error "Build artifacts not found"
fi

# Deploy to Kubernetes
echo "Deploying to Kubernetes..."
cd ../deploy/scripts
chmod +x deploy.sh
./deploy.sh || log_error "Failed to deploy to Kubernetes"

# Wait for deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/hello-wasm -n wasm-system || {
    echo "Deployment failed to become ready. Checking status..."
    echo "Pod status:"
    kubectl get pods -n wasm-system -l app=hello-wasm
    echo "Pod logs:"
    POD=$(kubectl get pods -n wasm-system -l app=hello-wasm -o jsonpath='{.items[0].metadata.name}')
    kubectl logs -n wasm-system $POD
    log_error "Deployment failed to become ready"
}

log_success "WebAssembly Runtime setup completed successfully!"
echo "To test the deployment, run:"
echo "chmod +x test.sh && ./test.sh"