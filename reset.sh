#!/bin/bash

echo "Stopping and removing k3s..."
sudo systemctl stop k3s || true
sudo /usr/local/bin/k3s-uninstall.sh || true

echo "Removing kubeconfig and dashboard files..."
rm -rf ~/.kube
sudo rm -f /etc/rancher/k3s/k3s.yaml
rm -f ./start-dashboard

# Clean up k3d resources if they exist
if command -v k3d &> /dev/null; then
    k3d cluster delete wasm-edge-cluster 2>/dev/null || true
fi

echo "Cleanup complete!"



#Resource tagging
#sudo systemctl stop streamlit-dashboard
#Trades and taints tolerance
#switch to k3s
#Openelb for cluster load balancing
#Make a rust based kubernetes dashboard
#http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/