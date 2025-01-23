<div align="center">
  <img src="../../docs/assets/icons/setup.png" alt="Setup" width="150"/>
  <h1>Phase 1: Development Environment Setup</h1>

  [![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
  [![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
  [![WebAssembly](https://img.shields.io/badge/webassembly-654FF0.svg?style=flat&logo=webassembly&logoColor=white)](https://webassembly.org/)
</div>

## 🛠️ Setup Scripts

### 📦 install_dependencies.sh
<details>
<summary>System Dependencies Installation</summary>

- 🐋 Docker Engine
- ☸️ kubectl
- 🚢 k3d
- ⎈ Helm
- 🔧 Build essentials
</details>

### ☸️ setup_kubernetes.sh
<details>
<summary>Kubernetes Cluster Setup</summary>

- 🔄 k3d cluster creation
- 📊 Prometheus monitoring
- 📈 Grafana dashboards
- 🔍 Health checks
</details>

### 🟪 setup_wasm.sh
<details>
<summary>WebAssembly Environment</summary>

- 🔮 Wasmtime runtime
- 🌐 WasmEdge setup
- 🛠️ WASI SDK
- ✅ Environment validation
</details>

## 📝 Prerequisites
- 💻 Linux-based OS
- 🔑 Root access
- 🌐 Internet connection
- 💾 8GB+ RAM
- 💽 20GB+ storage

## 🚀 Quick Start
```bash
# Run the setup scripts in order
sudo ./install_dependencies.sh
./setup_kubernetes.sh
./setup_wasm.sh
```

## 🔍 Validation
```bash
# Verify installations
docker --version
kubectl version
k3d --version
helm version
wasmtime --version
wasmedge --version
```

## 📚 Documentation
- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [WebAssembly Documentation](https://webassembly.org/)
