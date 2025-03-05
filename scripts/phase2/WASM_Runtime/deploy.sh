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

# Get the script's directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create namespace if it doesn't exist
echo "Creating wasm-system namespace..."
kubectl create namespace wasm-system 2>/dev/null || true

# Check if WebAssembly file exists
WASM_FILE="${SCRIPT_DIR}/build/hello_wasm.wasm"
if [ ! -f "$WASM_FILE" ]; then
    log_error "WebAssembly file not found at: $WASM_FILE. Please run ./build.sh first"
fi

# Create a temporary file for the modified yaml
TMP_YAML=$(mktemp)

# Convert wasm file to base64 and create the complete yaml
echo "Converting WebAssembly module to base64..."
WASM_BASE64=$(base64 -w 0 "$WASM_FILE")

# Create the complete yaml with the base64 content
echo "Creating Kubernetes manifests..."
cat "${SCRIPT_DIR}/k8s/hello-wasm.yaml" | \
    awk -v wasm="$WASM_BASE64" '
    /module.wasm: '\'\''/ {
        print "  module.wasm: " wasm
        next
    }
    { print }
    ' > "$TMP_YAML"

# Apply the modified yaml
echo "Applying Kubernetes manifests..."
kubectl apply -f "$TMP_YAML"

# Clean up
rm "$TMP_YAML"

# Wait for deployment
echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/hello-wasm -n wasm-system --timeout=60s || {
    log_error "Deployment failed. Checking pod status..."
    kubectl get pods -n wasm-system
    kubectl describe deployment hello-wasm -n wasm-system
    exit 1
}

log_success "Deployment completed successfully!"
echo "To test the deployment, run: ./test.sh" 