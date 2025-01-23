# Phase 1: Development Environment Setup

## Purpose
Establishes the foundational development environment for the WebAssembly Edge Computing platform, including all necessary tools, runtimes, and monitoring systems.

## Scripts

### install_dependencies.sh
Sets up base system requirements:
- System packages (curl, wget, git, build-essential)
- Docker installation and configuration
- kubectl installation and setup
- k3d cluster management tool
- Helm package manager

### setup_kubernetes.sh
Configures the development Kubernetes environment:
- Creates k3d cluster with configured resources
- Sets up Prometheus/Grafana monitoring stack
- Configures cluster networking
- Sets up persistent volumes
- Validates cluster health

### setup_wasm.sh
Prepares WebAssembly development environment:
- Installs Wasmtime runtime
- Configures WasmEdge environment
- Sets up WASI SDK
- Validates Wasm toolchain

## Configuration Files
```
/config
├── kubernetes/
│   ├── cluster-config.yaml
│   └── monitoring/
│       ├── prometheus-values.yaml
│       └── grafana-values.yaml
└── wasm/
    └── runtime-config.yaml
```

## Dependencies
- Linux-based operating system
- Root/sudo access
- Internet connection
- Minimum 8GB RAM
- 20GB free disk space

## Usage
```bash
# 1. Install dependencies
sudo ./install_dependencies.sh

# 2. Setup Kubernetes cluster
./setup_kubernetes.sh

# 3. Configure WebAssembly environment
./setup_wasm.sh

# Verify installation
kubectl get nodes
kubectl get pods -n monitoring
wasmedge --version
wasmtime --version
```

## Validation
Each script includes comprehensive error handling and validation steps.
Check logs in `/var/log/wasm-edge/` for troubleshooting.
