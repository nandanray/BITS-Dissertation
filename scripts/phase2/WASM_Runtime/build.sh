#!/bin/bash
set -e

# Color coding for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    log_error "Please do not run this script as root or with sudo"
fi

echo "Building WebAssembly module..."

# Source cargo environment if exists
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

# Verify Rust installation
if ! command -v rustc &> /dev/null; then
    log_error "Rust not found. Please run ./setup.sh first"
fi

# Add wasm32-unknown-unknown target
rustup target add wasm32-unknown-unknown

# Clean any previous builds
rm -rf src/hello_wasm/target

# Compile to WebAssembly
cd src/hello_wasm
cargo build --target wasm32-unknown-unknown --release

# Copy the wasm file to build directory
mkdir -p ../../build
cp target/wasm32-unknown-unknown/release/hello_wasm.wasm ../../build/

log_success "Build completed successfully!" 