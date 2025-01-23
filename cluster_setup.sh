#!/bin/bash

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Additional configuration variables
KUBERNETES_VERSION="1.24.0"
CNI_PROVIDER="flannel"  # Options: flannel, calico, weave
CONTAINER_RUNTIME="containerd"  # Options: containerd, docker
MONITORING_ENABLED=true
DASHBOARD_ENABLED=true

# Function to print colored messages
print_message() {
    echo -e "${2}${1}${NC}"
}

# Function to prompt for yes/no confirmation
confirm() {
    read -p "$1 (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Function to check system requirements
check_requirements() {
    print_message "Checking system requirements..." $YELLOW
    
    # Check CPU cores
    CPU_CORES=$(nproc)
    if [ $CPU_CORES -lt 2 ]; then
        print_message "Error: At least 2 CPU cores required. Found: $CPU_CORES" $RED
        exit 1
    fi

    # Check RAM
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    if [ $TOTAL_RAM -lt 2 ]; then
        print_message "Error: At least 2GB RAM required. Found: ${TOTAL_RAM}GB" $RED
        exit 1
    fi

    # Check disk space
    DISK_SPACE=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ ${DISK_SPACE%.*} -lt 20 ]; then
        print_message "Error: At least 20GB free disk space required. Found: ${DISK_SPACE}GB" $RED
        exit 1
    fi
}

# Function to configure system settings
configure_system() {
    print_message "Configuring system settings..." $YELLOW
    
    # Disable swap
    sudo swapoff -a
    sudo sed -i '/swap/d' /etc/fstab

    # Enable kernel modules
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
overlay
EOF
    sudo modprobe br_netfilter
    sudo modprobe overlay

    # Configure sysctl parameters
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
    sudo sysctl --system
}

# Welcome message
print_message "Welcome to Single Node Kubernetes Cluster Setup Script" $GREEN
print_message "This script will help you set up a single node Kubernetes cluster on Ubuntu 24.04" $YELLOW

# Get user inputs
read -p "Enter pod network CIDR (default: 10.244.0.0/16): " POD_CIDR
POD_CIDR=${POD_CIDR:-"10.244.0.0/16"}

read -p "Enter API server advertise address (default: $(hostname -I | awk '{print $1}')): " API_ADDR
API_ADDR=${API_ADDR:-$(hostname -I | awk '{print $1}')}

# Update system
print_message "\nUpdating system packages..." $YELLOW
sudo apt update && sudo apt upgrade -y

# Install Docker
print_message "\nInstalling Docker..." $YELLOW
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker

# Enhanced Kubernetes installation
install_kubernetes() {
    print_message "Installing Kubernetes version $KUBERNETES_VERSION..." $YELLOW
    sudo apt install -y apt-transport-https ca-certificates curl
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt update
    sudo apt install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl

    # Install specific version if requested
    if [ ! -z "$KUBERNETES_VERSION" ]; then
        sudo apt install -y kubelet=$KUBERNETES_VERSION-00 kubeadm=$KUBERNETES_VERSION-00 kubectl=$KUBERNETES_VERSION-00
    fi
}

# Initialize cluster
print_message "\nInitializing Kubernetes cluster..." $YELLOW
sudo kubeadm init --pod-network-cidr=$POD_CIDR --apiserver-advertise-address=$API_ADDR

# Setup kubeconfig
print_message "\nSetting up kubeconfig..." $YELLOW
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install CNI (Flannel)
print_message "\nInstalling Flannel CNI..." $YELLOW
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Ask if user wants to allow scheduling on master node
if confirm "Do you want to allow workloads to run on the master node?"; then
    print_message "\nRemoving master node taint..." $YELLOW
    kubectl taint nodes --all node-role.kubernetes.io/master-
    kubectl taint nodes --all node-role.kubernetes.io/control-plane-
fi

# Function to install monitoring tools
install_monitoring() {
    if [ "$MONITORING_ENABLED" = true ]; then
        print_message "Installing monitoring tools..." $YELLOW
        kubectl apply -f https://github.com/prometheus-operator/kube-prometheus/releases/latest/download/setup.yaml
        kubectl apply -f https://github.com/prometheus-operator/kube-prometheus/releases/latest/download/prometheus.yaml
        kubectl apply -f https://github.com/prometheus-operator/kube-prometheus/releases/latest/download/alertmanager.yaml
        kubectl apply -f https://github.com/prometheus-operator/kube-prometheus/releases/latest/download/grafana.yaml
    fi
}

# Function to install Kubernetes Dashboard
install_dashboard() {
    if [ "$DASHBOARD_ENABLED" = true ]; then
        print_message "Installing Kubernetes Dashboard..." $YELLOW
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended.yaml
        
        # Create admin user and get token
        kubectl create serviceaccount dashboard-admin
        kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=default:dashboard-admin
        print_message "Dashboard token:" $GREEN
        kubectl create token dashboard-admin
    fi
}

# Verify installation
print_message "\nVerifying installation..." $YELLOW
kubectl get nodes
kubectl get pods --all-namespaces

print_message "\nKubernetes cluster setup completed successfully!" $GREEN
print_message "You can now start deploying your applications." $GREEN

# Main execution flow
main() {
    print_message "Starting Kubernetes cluster setup..." $GREEN
    check_requirements
    configure_system
    install_kubernetes
    install_monitoring
    install_dashboard
    
    print_message "Setup completed! Cluster is ready for use." $GREEN
    kubectl cluster-info
}

main
