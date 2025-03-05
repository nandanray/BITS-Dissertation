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

# Improved namespace creation with explicit error handling
echo "Creating wasm-system namespace..."
if ! kubectl create namespace wasm-system; then
    # Check if namespace already exists
    if kubectl get namespace wasm-system >/dev/null 2>&1; then
        log_warning "Namespace 'wasm-system' already exists"
    else
        log_error "Failed to create namespace 'wasm-system'"
    fi
else
    log_success "Namespace 'wasm-system' created successfully"
fi

# Verify namespace was created and is visible
if ! kubectl get namespace wasm-system >/dev/null 2>&1; then
    log_error "Cannot verify 'wasm-system' namespace after creation"
fi

# Verify required files exist for CRDs and controller
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

# Create default runtime if not present
if ! kubectl get wasmruntime default-wasm-runtime -n wasm-system &>/dev/null; then
    echo "No default runtime found. Creating minimal default runtime..."
    cat > "${RUNTIME_DIR}/default-runtime.yaml" << EOF
apiVersion: wasm.bits-dissertation.io/v1alpha1
kind: WasmRuntime
metadata:
  name: default-wasm-runtime
  namespace: wasm-system
spec: {}
EOF
    echo "Applying minimal default WasmRuntime..."
    kubectl apply -f "${RUNTIME_DIR}/default-runtime.yaml" || {
        log_warning "Failed to apply minimal WasmRuntime. Continuing without creating a default runtime..."
    }
else
    echo "Default WasmRuntime already exists. Skipping creation."
fi

# Deploy the CSV Filter web application
echo "Deploying CSV Filter web application..."
kubectl apply -f "${CONFIG_DIR}/function/csv-filter.yaml" || log_error "Failed to deploy CSV Filter function"

# Fallback Deployment for CSV Filter web application if controller doesn't create it
echo "Creating fallback deployment for CSV Filter web application..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: csv-filter
  namespace: wasm-system
  labels:
    app: csv-filter
    wasmfunction: csv-filter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: csv-filter
  template:
    metadata:
      labels:
        app: csv-filter
        wasmfunction: csv-filter
    spec:
      containers:
      - name: csv-filter
        image: nandanray/csv-filter:latest
        ports:
        - containerPort: 80
EOF

echo "Waiting for CSV Filter web application to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/csv-filter -n wasm-system || log_error "CSV Filter web application failed to become ready"

log_success "CSV Filter web application deployed successfully!"
echo "To test the web app, run a port-forward:"
echo "kubectl port-forward deployment/csv-filter 8081:80 -n wasm-system"
