#!/bin/bash

set -e

# Color coding for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

echo "=== Setting up WebAssembly Runtime Environment ==="

# Create namespace for Wasm runtime if it doesn't exist
echo "Creating wasm-system namespace..."
kubectl create namespace wasm-system 2>/dev/null || true

# Verify required files exist
for file in crds/wasm-runtime.yaml crds/wasm-function.yaml controller/runtime-controller.yaml; do
    if [ ! -f "${CONFIG_DIR}/${file}" ]; then
        log_error "Required file ${file} not found in ${CONFIG_DIR}"
    fi
done

# Apply runtime CRDs
echo "Applying WebAssembly CRDs..."
kubectl apply -f "${CONFIG_DIR}/crds/wasm-runtime.yaml" || log_error "Failed to apply wasm-runtime CRD"
kubectl apply -f "${CONFIG_DIR}/crds/wasm-function.yaml" || log_error "Failed to apply wasm-function CRD"

# Deploy runtime controller
echo "Deploying runtime controller..."
kubectl apply -f "${CONFIG_DIR}/controller/runtime-controller.yaml" || log_error "Failed to deploy runtime controller"

# Wait for controller to be ready
echo "Waiting for runtime controller to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/wasm-runtime-controller -n wasm-system || log_error "Runtime controller failed to become ready"

# Verify CRDs are available
echo "Verifying CRD installation..."
kubectl get crd wasmruntimes.wasm.bits-dissertation.io >/dev/null || log_error "WasmRuntime CRD not found"
kubectl get crd wasmfunctions.wasm.bits-dissertation.io >/dev/null || log_error "WasmFunction CRD not found"

log_success "WebAssembly runtime environment setup completed successfully!"
