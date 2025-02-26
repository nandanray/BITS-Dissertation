#!/bin/bash

set -e

# Color coding for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo "=== Setting up Kubernetes Cluster for Wasm Edge Computing ==="

# Cluster configuration
CLUSTER_NAME="wasm-edge-cluster"
AGENT_COUNT=1
HTTP_PORT=80
ALT_HTTP_PORT=8081
LB_PORT_80="80:${HTTP_PORT}@loadbalancer"
LB_PORT_8080="8080:8080@loadbalancer"

# Check if port 80 is in use
if netstat -tulnp | grep -q ":${HTTP_PORT}"; then
    echo -e "${RED}Port ${HTTP_PORT} is already in use. Please stop the service using it or use an alternative port.${NC}"
    echo -e "Trying alternative port ${ALT_HTTP_PORT}..."
    HTTP_PORT=$ALT_HTTP_PORT
    LB_PORT_80="80:${HTTP_PORT}@loadbalancer"
fi

echo "Creating k3d cluster with following configuration:"
echo "- Name: $CLUSTER_NAME"
echo "- Agents: $AGENT_COUNT"
echo "- Ports: ${HTTP_PORT} and 8080 mapped to loadbalancer"

# Create minimal cluster with resource limits
k3d cluster create "$CLUSTER_NAME" \
    --agents "$AGENT_COUNT" \
    -p "$LB_PORT_80" \
    -p "$LB_PORT_8080" \
    --k3s-arg "--disable=traefik,servicelb,metrics-server@server:*" \
    --image rancher/k3s:v1.26.7-k3s1 \
    --timeout 120s \
    --kubeconfig-update-default \
    --servers 1 \
    --servers-memory "1024m" \
    --agents-memory "1024m" || log_error "Failed to create cluster"

# Wait for cluster access (simplified)
echo "Waiting for cluster access..."
for i in $(seq 1 30); do
    if kubectl cluster-info >/dev/null 2>&1; then
        break
    fi
    echo "Waiting for cluster... attempt $i/30"
    sleep 2
done

if ! kubectl cluster-info >/dev/null 2>&1; then
    log_error "Failed to access cluster after waiting"
fi

log_success "Kubernetes cluster created successfully"

# Simplified node readiness check
echo "Waiting for nodes..."
kubectl wait --for=condition=ready nodes --all --timeout=60s || log_error "Nodes failed to become ready"

log_success "Nodes are ready"

# Basic cluster verification
kubectl get nodes || log_error "Cannot get cluster nodes"

# Check core components
echo "Checking core components..."
if ! kubectl wait --for=condition=ready -n kube-system pod -l k8s-app=kube-dns --timeout=60s; then
    log_error "CoreDNS is not ready"
fi

log_success "Cluster core components are ready"

# Verify k3s server is operational
echo "Verifying k3s server status..."
if ! timeout 60 kubectl get --raw "/readyz" >/dev/null 2>&1; then
    log_error "k3s server is not healthy"
fi

log_success "k3s server is operational"

# Verify DNS resolution is working
echo "Verifying DNS resolution..."
timeout=60
elapsed=0
while true; do
    if [ $elapsed -gt $timeout ]; then
        log_error "DNS resolution check failed"
    fi
    
    if kubectl run -it --rm --restart=Never dns-test --image=busybox:1.28 \
        --command -- nslookup kubernetes.default >/dev/null 2>&1; then
        echo "DNS resolution working"
        break
    fi
    
    sleep 5
    elapsed=$((elapsed + 5))
    echo "Waiting for DNS to be ready... ($elapsed/$timeout seconds)"
done

echo "=== Setting up Metrics Server ==="
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml || log_error "Failed to install Metrics Server"

# Wait for Metrics Server to be ready
echo "Waiting for Metrics Server to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=300s || log_error "Metrics Server failed to become ready"

echo "=== Setting up Monitoring Dashboard ==="

# Ensure python3-venv is installed
if ! dpkg -l | grep -q python3-venv; then
    echo "Installing python3-venv..."
    sudo apt-get update
    sudo apt-get install -y python3-venv || log_error "Failed to install python3-venv"
fi

# Create a virtual environment for the Streamlit dashboard
python3 -m venv /home/nandan/CodeIT/Personal/BITS-Dissertation/scripts/phase1/setup/venv || log_error "Failed to create virtual environment"

# Activate the virtual environment and install Streamlit and Kubernetes Python client
source /home/nandan/CodeIT/Personal/BITS-Dissertation/scripts/phase1/setup/venv/bin/activate
pip install streamlit kubernetes pandas || log_error "Failed to install Streamlit and Kubernetes Python client"
deactivate

# Create a systemd service for the Streamlit dashboard
cat <<EOF | sudo tee /etc/systemd/system/streamlit-dashboard.service
[Unit]
Description=Streamlit Dashboard
After=network.target

[Service]
User=$USER
WorkingDirectory=/home/nandan/CodeIT/Personal/BITS-Dissertation/scripts/phase1/setup
ExecStart=/home/nandan/CodeIT/Personal/BITS-Dissertation/scripts/phase1/setup/venv/bin/streamlit run /home/nandan/CodeIT/Personal/BITS-Dissertation/scripts/phase1/setup/monitoring_dashboard.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start the Streamlit service
sudo systemctl daemon-reload
sudo systemctl start streamlit-dashboard.service
sudo systemctl enable streamlit-dashboard.service

log_success "Monitoring dashboard set up successfully!"
echo "====================================="
echo "Streamlit Dashboard URL: http://localhost:8501"
echo "====================================="

# Verify installation
sudo systemctl status streamlit-dashboard.service

log_success "Kubernetes cluster setup completed successfully!"
