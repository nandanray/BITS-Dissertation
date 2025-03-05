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
    # Stop k3s if it's running
    if systemctl is-active --quiet k3s; then
        echo "Stopping existing k3s service..."
        sudo systemctl stop k3s
    fi

    # Remove existing k3s installation if present
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

# Add this function at the start of the file, after the other function definitions
verify_and_create_token() {
    local token_dir="$HOME/.kube/dashboard"
    local token_file="$token_dir/token.txt"
    
    # Create directory if it doesn't exist
    mkdir -p "$token_dir"
    
    # Try to generate token for admin-user first
    if TOKEN=$(kubectl -n kubernetes-dashboard create token admin-user --duration=999999h 2>/dev/null); then
        echo "Token generated for admin-user"
    else
        # Fallback to default service account
        echo "Generating token for default service account..."
        if ! TOKEN=$(kubectl -n default create token default --duration=999999h); then
            log_error "Failed to generate token for default service account"
        fi
    fi
    
    # Save token
    echo "Saving token to $token_file"
    echo "$TOKEN" > "$token_file" || log_error "Failed to save token"
    chmod 600 "$token_file" || log_error "Failed to set token file permissions"
    
    # Verify token file
    if [ ! -r "$token_file" ]; then
        log_error "Token file not created or not readable"
    fi
    
    echo "Token successfully created and saved to: $token_file"
    return 0
}

# Add this function at the start with other functions
verify_cluster_access() {
    # Try to access the cluster
    if ! kubectl get nodes >/dev/null 2>&1; then
        echo "Cluster access failed. Attempting to fix..."
        
        # Check if k3s is running
        if ! systemctl is-active --quiet k3s; then
            sudo systemctl start k3s
            sleep 5
        fi
        
        # Regenerate kubeconfig
        sudo k3s kubectl config view --raw > ~/.kube/config
        sudo chown $(id -u):$(id -g) ~/.kube/config
        sudo chmod 600 ~/.kube/config
        
        # Try again
        if ! kubectl get nodes >/dev/null 2>&1; then
            echo "Debug information:"
            echo "K3s status:"
            sudo systemctl status k3s
            echo "K3s logs:"
            sudo journalctl -u k3s -n 50
            echo "Kubeconfig:"
            kubectl config view
            log_error "Still unable to access cluster"
        fi
    fi
}

echo "=== Setting up Kubernetes Cluster for Wasm Edge Computing ==="

# Clean up any existing k3s installation
check_and_cleanup_k3s

# Free up required ports
free_up_ports 80
free_up_ports 8080
free_up_ports 6443  # Kubernetes API server port

# Check and free port 6443 (Kubernetes API server port)
if sudo lsof -i :6443 >/dev/null 2>&1; then
    echo "Port 6443 is in use. Attempting to free it..."
    sudo kill -9 $(sudo lsof -t -i:6443)
    sleep 2
fi

# Cluster configuration
CLUSTER_NAME="wasm-edge-cluster"
AGENT_COUNT=1
HTTP_PORT=80
ALT_HTTP_PORT=8081
LB_PORT_80="80:${HTTP_PORT}@loadbalancer"
LB_PORT_8080="8080:8080@loadbalancer"

# Clean up existing cluster if it exists
cleanup_k3d_cluster "$CLUSTER_NAME"

# Install k3s with some basic configurations
echo "Installing k3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --tls-san=$(hostname)" sh -

# Wait for the service to start
sleep 5

# Check if k3s is running
if ! systemctl is-active --quiet k3s; then
    echo "Failed to start k3s"
    exit 1
fi

# Set up kubectl config
echo "Setting up kubectl configuration..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
sudo chmod 600 ~/.kube/config

# Set KUBECONFIG environment variable
export KUBECONFIG=~/.kube/config

# Create a copy of kubeconfig with proper settings
cat <<EOF > ~/.kube/config
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /var/lib/rancher/k3s/server/tls/server-ca.crt
    server: https://127.0.0.1:6443
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: default
  user:
    client-certificate: /var/lib/rancher/k3s/server/tls/client-admin.crt
    client-key: /var/lib/rancher/k3s/server/tls/client-admin.key
EOF

# Stop k3s first
sudo systemctl stop k3s

# Remove existing kubeconfig
rm -f ~/.kube/config

# Create .kube directory if it doesn't exist
mkdir -p ~/.kube

# Copy the k3s.yaml file to your kubeconfig
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# Set the correct ownership to your user (replace $USER with your username if needed)
sudo chown $USER:$USER ~/.kube/config

# Set proper permissions
sudo chmod 600 ~/.kube/config

# Also ensure the certificate files are readable by your user
sudo chmod 644 /var/lib/rancher/k3s/server/tls/server-ca.crt
sudo chmod 644 /var/lib/rancher/k3s/server/tls/client-admin.crt
sudo chmod 644 /var/lib/rancher/k3s/server/tls/client-admin.key

# Start k3s again
sudo systemctl start k3s

# Wait a few seconds
sleep 5

# Export KUBECONFIG environment variable
export KUBECONFIG=~/.kube/config

# Wait for cluster access
echo "Waiting for cluster access..."
for i in $(seq 1 30); do
    if kubectl cluster-info >/dev/null 2>&1; then
        break
    fi
    echo "Waiting for cluster... attempt $i/30"
    sleep 2
done

# Verify cluster access
if ! kubectl cluster-info; then
    echo "Debug information:"
    echo "Checking kubeconfig:"
    kubectl config view
    echo "Checking certificates:"
    ls -l /var/lib/rancher/k3s/server/tls/
    echo "Checking k3s logs:"
    sudo journalctl -u k3s -n 50
    log_error "Failed to access cluster after waiting"
fi

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

# Wait for node to be ready
echo "Waiting for node to be ready..."
kubectl wait --for=condition=ready nodes --all --timeout=60s

# Verify cluster access
kubectl cluster-info
kubectl get nodes

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

echo "=== Setting up Kubernetes Dashboard ==="

# Install Kubernetes Dashboard
echo "Installing Kubernetes Dashboard..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml || log_error "Failed to install Kubernetes Dashboard"

# Verify dashboard pods are created
echo "Verifying dashboard installation..."
kubectl get pods -n kubernetes-dashboard
kubectl get svc -n kubernetes-dashboard

# Create dashboard admin user
echo "Creating dashboard admin user..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# Create cluster role binding
echo "Creating cluster role binding..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# Wait for dashboard to be ready
echo "Waiting for Kubernetes Dashboard to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=kubernetes-dashboard -n kubernetes-dashboard --timeout=120s || log_error "Kubernetes Dashboard failed to become ready"
kubectl create namespace wasm-system

# Verify and create token
verify_and_create_token

# Create the start-dashboard script in the current directory
cp "$(dirname "$0")/start-dashboard.sh" ./start-dashboard
chmod +x ./start-dashboard

log_success "Kubernetes Dashboard installed successfully!"
echo "====================================="
echo "To access the dashboard:"
echo "1. Run: ./start-dashboard"
echo "2. Wait for the proxy to start"
echo "3. Open the URL provided in your browser"
echo "4. Use the token from: $HOME/.kube/dashboard/token.txt"
echo ""
echo "Your token is:"
echo "----------------"
cat "$HOME/.kube/dashboard/token.txt"
echo "----------------"
echo "====================================="

# Test dashboard access
echo "Testing dashboard access..."
if ! curl -s http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/ >/dev/null 2>&1; then
    echo "Note: Dashboard will be accessible after running ./start-dashboard"
fi

log_success "Setup completed successfully!"

./start-dashboard

# Then use this function after k3s installation and before proceeding with other operations:
#verify_cluster_access