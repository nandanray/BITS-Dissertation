#!/bin/bash

set -e

# Color coding for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Function to check and stop existing k3s
check_and_cleanup_k3s() {
    if systemctl is-active --quiet k3s; then
        echo "Stopping existing k3s service..."
        sudo systemctl stop k3s
    fi
    if [ -f "/usr/local/bin/k3s-uninstall.sh" ]; then
        echo "Removing existing k3s installation..."
        sudo /usr/local/bin/k3s-uninstall.sh
    fi
}

# Function to check and free up ports
free_up_ports() {
    local port=$1
    echo "Checking port $port..."
    if sudo lsof -i ":$port" >/dev/null 2>&1; then
        echo "Port $port is in use. Attempting to free it up..."
        # Try to identify and stop the service using the port
        if sudo netstat -tulpn | grep ":$port" | grep "apache2" >/dev/null 2>&1; then
            echo "Stopping Apache2 service..."
            sudo systemctl stop apache2
        elif sudo netstat -tulpn | grep ":$port" | grep "nginx" >/dev/null 2>&1; then
            echo "Stopping Nginx service..."
            sudo systemctl stop nginx
        else
            # If specific service not identified, try to kill the process
            local pid=$(sudo lsof -t -i":$port")
            if [ ! -z "$pid" ]; then
                echo "Killing process using port $port (PID: $pid)..."
                sudo kill -9 $pid
            fi
        fi
        sleep 2
        if sudo lsof -i ":$port" >/dev/null 2>&1; then
            log_error "Failed to free up port $port"
        else
            log_success "Successfully freed up port $port"
        fi
    else
        echo "Port $port is available"
    fi
}

# Function to check and delete existing k3d cluster
cleanup_k3d_cluster() {
    local cluster_name=$1
    if k3d cluster list | grep -q "$cluster_name"; then
        echo "Deleting existing k3d cluster: $cluster_name..."
        k3d cluster delete "$cluster_name"
        sleep 2
    fi
}

echo "=== Setting up Kubernetes Cluster for Wasm Edge Computing ==="

# Clean up any existing k3s installation
check_and_cleanup_k3s

# Free up required ports
free_up_ports 80
free_up_ports 8080
free_up_ports 6443  # Kubernetes API server port

# Cluster configuration
CLUSTER_NAME="wasm-edge-cluster"
AGENT_COUNT=1
HTTP_PORT=80
ALT_HTTP_PORT=8081
LB_PORT_80="80:${HTTP_PORT}@loadbalancer"
LB_PORT_8080="8080:8080@loadbalancer"

# Clean up existing cluster if it exists
cleanup_k3d_cluster "$CLUSTER_NAME"

# Check if port 80 is still in use after cleanup attempt
if netstat -tulnp | grep -q ":${HTTP_PORT}"; then
    echo -e "${RED}Port ${HTTP_PORT} is still in use. Using alternative port ${ALT_HTTP_PORT}...${NC}"
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

# Check core components with improved waiting
echo "Checking core components..."
echo "Waiting for CoreDNS pods to be created..."
ATTEMPTS=0
MAX_ATTEMPTS=30
while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    if kubectl get pods -n kube-system -l k8s-app=kube-dns 2>/dev/null | grep -q "coredns"; then
        break
    fi
    ATTEMPTS=$((ATTEMPTS + 1))
    echo "Waiting for CoreDNS pods to be created... (Attempt $ATTEMPTS/$MAX_ATTEMPTS)"
    sleep 5
done

if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
    echo "Debug information:"
    echo "Pods in kube-system namespace:"
    kubectl get pods -n kube-system
    echo "Events in kube-system namespace:"
    kubectl get events -n kube-system
    log_error "CoreDNS pods were not created within the timeout period"
fi

echo "Waiting for CoreDNS to be ready..."
if ! kubectl wait --for=condition=ready -n kube-system pod -l k8s-app=kube-dns --timeout=120s; then
    echo "Debug information:"
    echo "CoreDNS pods status:"
    kubectl get pods -n kube-system -l k8s-app=kube-dns
    echo "CoreDNS pods logs:"
    kubectl logs -n kube-system -l k8s-app=kube-dns
    echo "CoreDNS pods description:"
    kubectl describe pods -n kube-system -l k8s-app=kube-dns
    log_error "CoreDNS failed to become ready"
fi

log_success "CoreDNS is ready"

# Verify DNS resolution is working
echo "Verifying DNS resolution..."
timeout=120  # Increased timeout
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if kubectl run -it --rm --restart=Never dns-test --image=busybox:1.28 \
        --command -- nslookup kubernetes.default >/dev/null 2>&1; then
        log_success "DNS resolution working"
        break
    fi
    
    sleep 5
    elapsed=$((elapsed + 5))
    echo "Waiting for DNS to be ready... ($elapsed/$timeout seconds)"
done

if [ $elapsed -ge $timeout ]; then
    echo "Debug information:"
    echo "DNS test pod logs:"
    kubectl run -it --rm --restart=Never dns-test --image=busybox:1.28 \
        --command -- nslookup kubernetes.default
    echo "CoreDNS pods status:"
    kubectl get pods -n kube-system -l k8s-app=kube-dns
    log_error "DNS resolution check failed"
fi

log_success "Cluster core components are ready"

# Verify k3s server is operational
echo "Verifying k3s server status..."
if ! timeout 60 kubectl get --raw "/readyz" >/dev/null 2>&1; then
    log_error "k3s server is not healthy"
fi

log_success "k3s server is operational"

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
