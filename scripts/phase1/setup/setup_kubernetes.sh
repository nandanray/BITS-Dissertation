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
AGENT_COUNT=3
MEMORY="4GB"
PORTS="8080:80@loadbalancer"

echo "Creating k3d cluster with following configuration:"
echo "- Name: $CLUSTER_NAME"
echo "- Agents: $AGENT_COUNT"
echo "- Memory: $MEMORY"
echo "- Ports: $PORTS"

# Check if cluster already exists
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    log_error "Cluster $CLUSTER_NAME already exists. Please delete it first with: k3d cluster delete $CLUSTER_NAME"
fi

# Create cluster with resource limits
k3d cluster create "$CLUSTER_NAME" \
    --agents "$AGENT_COUNT" \
    --memory "$MEMORY" \
    --port "$PORTS" \
    --wait || log_error "Failed to create cluster"

log_success "Kubernetes cluster created successfully"

echo "=== Setting up Monitoring Stack ==="

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || log_error "Failed to add Prometheus repo"
helm repo add grafana https://grafana.github.io/helm-charts || log_error "Failed to add Grafana repo"
helm repo update || log_error "Failed to update Helm repos"

# Create monitoring namespace
kubectl create namespace monitoring || log_error "Failed to create monitoring namespace"

# Install Prometheus with custom values
echo "Installing Prometheus..."
helm install prometheus prometheus-community/prometheus \
    --namespace monitoring \
    --set server.persistentVolume.size=10Gi \
    --set alertmanager.persistentVolume.size=5Gi || log_error "Failed to install Prometheus"

# Install Grafana with custom values
echo "Installing Grafana..."
helm install grafana grafana/grafana \
    --namespace monitoring \
    --set persistence.enabled=true \
    --set persistence.size=5Gi \
    --set adminPassword=admin123 || log_error "Failed to install Grafana"

# Wait for pods to be ready
echo "Waiting for monitoring stack to be ready..."
kubectl wait --for=condition=ready pod -l app=prometheus --timeout=300s -n monitoring
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --timeout=300s -n monitoring

# Get Grafana admin password
GRAFANA_PASSWORD=$(kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode)

log_success "Monitoring stack installed successfully!"
echo "====================================="
echo "Grafana URL: http://localhost:80"
echo "Grafana Admin User: admin"
echo "Grafana Admin Password: $GRAFANA_PASSWORD"
echo "====================================="

# Verify installation
echo "Verifying installation..."
kubectl get pods -n monitoring
kubectl get svc -n monitoring

log_success "Kubernetes cluster setup completed successfully!"
