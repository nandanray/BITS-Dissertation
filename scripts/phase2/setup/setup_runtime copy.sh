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

# Create runtime directory if it doesn't exist
RUNTIME_DIR="${CONFIG_DIR}/runtime"
mkdir -p "${RUNTIME_DIR}"

# Check if a default runtime already exists
if ! kubectl get wasmruntime default-wasm-runtime -n wasm-system &>/dev/null; then
    echo "No default runtime found. Attempting to create a minimal one..."
    
    # Create a minimal WasmRuntime with empty spec
    cat > "${RUNTIME_DIR}/default-runtime.yaml" << EOF
apiVersion: wasm.bits-dissertation.io/v1alpha1
kind: WasmRuntime
metadata:
  name: default-wasm-runtime
  namespace: wasm-system
spec: {}
EOF
    
    # Apply the default runtime
    echo "Applying minimal default WasmRuntime..."
    kubectl apply -f "${RUNTIME_DIR}/default-runtime.yaml" || {
        log_warning "Failed to apply minimal WasmRuntime. Checking CRD for required fields..."
        
        # Try to get schema information from the CRD
        kubectl get crd wasmruntimes.wasm.bits-dissertation.io -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec}' > /tmp/wasmruntime-schema.json
        echo "WasmRuntime schema saved to /tmp/wasmruntime-schema.json"
        log_warning "Please check this file to determine the required fields and update your script accordingly."
        log_warning "Continuing without creating a default runtime..."
    }
else
    echo "Default WasmRuntime already exists. Skipping creation."
fi

log_success "WebAssembly runtime environment setup completed successfully!"

# Deploy hello world wasm function
echo "Deploying hello world wasm function..."
kubectl apply -f "${CONFIG_DIR}/function/hello-world.yaml" || log_error "Failed to deploy hello world wasm function"


# Create manual deployment as a fallback since controller isn't creating it
echo "Creating fallback deployment for hello-world function..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
  namespace: wasm-system
  labels:
    app: hello-world
    wasmfunction: hello-world
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
        wasmfunction: hello-world
    spec:
      containers:
      - name: hello-world
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

echo "Waiting for hello world function to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/hello-world -n wasm-system || log_error "Hello world function failed to become ready"

log_success "Hello world function deployed successfully!"
echo "You can access the function using:"
echo "kubectl port-forward deployment/hello-world 8081:8080 -n wasm-system"