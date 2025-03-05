#!/bin/bash
set -e

# Color coding for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo "Testing WebAssembly HTTP Server..."

# Wait for pod to be ready
echo "Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod -l app=hello-wasm -n wasm-system --timeout=60s

# Get NodePort
NODE_PORT=$(kubectl get svc hello-wasm -n wasm-system -o jsonpath='{.spec.ports[0].nodePort}')
echo "Service exposed on port: $NODE_PORT"

# Test the HTTP endpoint
echo "Testing HTTP endpoint..."
response=$(curl -s http://localhost:$NODE_PORT)
echo "Response: $response"

if [[ "$response" == *"Hello from WebAssembly!"* ]]; then
    log_success "Test completed successfully!"
else
    log_error "Test failed! Unexpected response"
fi 