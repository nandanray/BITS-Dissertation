#!/bin/bash

set -e

# Color coding for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

echo "=== Setting up WebAssembly Development Environment ==="

# Configuration
WASI_VERSION="14"
WASMEDGE_VERSION="0.11.2"
INSTALL_DIR="/opt/wasm-tools"

# Create installation directory
sudo mkdir -p "$INSTALL_DIR"
sudo chown $USER:$USER "$INSTALL_DIR"

# Install Wasmtime
echo "=== Installing Wasmtime ==="
if ! command -v wasmtime &> /dev/null; then
    log_info "Downloading Wasmtime..."
    curl https://wasmtime.dev/install.sh -sSf | bash || log_error "Wasmtime installation failed"
    # Verify installation
    wasmtime --version || log_error "Wasmtime verification failed"
    log_success "Wasmtime installed successfully"
else
    log_info "Wasmtime already installed: $(wasmtime --version)"
fi

# Install WasmEdge
echo "=== Installing WasmEdge ==="
if ! command -v wasmedge &> /dev/null; then
    log_info "Downloading WasmEdge..."
    curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | \
    VERSION="$WASMEDGE_VERSION" bash || log_error "WasmEdge installation failed"
    # Verify installation
    wasmedge --version || log_error "WasmEdge verification failed"
    log_success "WasmEdge installed successfully"
else
    log_info "WasmEdge already installed: $(wasmedge --version)"
fi

# Install WASI SDK
echo "=== Installing WASI SDK ==="
WASI_SDK_URL="https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-${WASI_VERSION}/wasi-sdk-${WASI_VERSION}.0-linux.tar.gz"
WASI_SDK_DIR="$INSTALL_DIR/wasi-sdk"

if [ ! -d "$WASI_SDK_DIR" ]; then
    log_info "Downloading WASI SDK..."
    wget "$WASI_SDK_URL" -O /tmp/wasi-sdk.tar.gz || log_error "Failed to download WASI SDK"
    
    log_info "Extracting WASI SDK..."
    tar xvf /tmp/wasi-sdk.tar.gz -C /tmp || log_error "Failed to extract WASI SDK"
    
    log_info "Installing WASI SDK..."
    sudo mv /tmp/wasi-sdk-${WASI_VERSION}.0 "$WASI_SDK_DIR" || log_error "Failed to install WASI SDK"
    
    # Cleanup
    rm /tmp/wasi-sdk.tar.gz
    
    # Add to PATH
    echo "export WASI_SDK_PATH=$WASI_SDK_DIR" >> ~/.bashrc
    log_success "WASI SDK installed successfully"
else
    log_info "WASI SDK already installed in $WASI_SDK_DIR"
fi

# Verify all installations
echo "=== Verifying Installations ==="
echo "Wasmtime version: $(wasmtime --version)"
echo "WasmEdge version: $(wasmedge --version)"
echo "WASI SDK path: $WASI_SDK_DIR"

# Create test Wasm file
echo "=== Testing WebAssembly Setup ==="
cat > /tmp/test.wat <<EOL
(module
  (func (export "answer") (result i32)
    i32.const 42))
EOL

log_info "Testing Wasmtime..."
wat2wasm /tmp/test.wat -o /tmp/test.wasm
wasmtime /tmp/test.wasm --invoke answer || log_error "Wasmtime test failed"

log_info "Testing WasmEdge..."
wasmedge /tmp/test.wasm || log_error "WasmEdge test failed"

log_success "WebAssembly development environment setup completed successfully!"
echo "==============================================="
echo "Installation Directory: $INSTALL_DIR"
echo "WASI SDK Version: $WASI_VERSION"
echo "WasmEdge Version: $WASMEDGE_VERSION"
echo "==============================================="
