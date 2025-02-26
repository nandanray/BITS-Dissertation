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

echo "=== Setting up WebAssembly Operators ==="

# Create directories if they don't exist
mkdir -p "${CONFIG_DIR}"/{crds,rbac,operators}

# Create operator namespace
kubectl create namespace wasm-operators 2>/dev/null || true

# Create service account
kubectl create serviceaccount wasm-operator -n wasm-operators 2>/dev/null || true

# Install cert-manager
echo "Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml

# Wait for cert-manager to be ready
echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=120s || log_error "cert-manager failed to become ready"

# Apply CRDs and RBAC
echo "Applying CRDs and RBAC..."
kubectl apply -f "${CONFIG_DIR}/crds/" || log_error "Failed to apply CRDs"
kubectl apply -f "${CONFIG_DIR}/rbac/" || log_error "Failed to apply RBAC"

# Deploy operators
echo "Deploying operators..."
kubectl apply -f "${CONFIG_DIR}/operators/" || log_error "Failed to deploy operators"

# Wait for operators to be ready
echo "Waiting for operators to be ready..."
kubectl wait --for=condition=available deployment/wasm-function-operator -n wasm-operators --timeout=60s || log_error "Operators failed to become ready"

log_success "WebAssembly operators setup completed successfully!"

# Show operator status
echo "=== Operator Status ==="
kubectl get pods -n wasm-operators
