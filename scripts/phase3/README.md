<div align="center">
  <img src="../../docs/assets/icons/kubernetes.png" alt="Kubernetes" width="150"/>
  <h1>Phase 3: Kubernetes Integration</h1>

  [![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
  [![Operators](https://img.shields.io/badge/operators-red.svg?style=flat&logo=kubernetes&logoColor=white)](https://operatorhub.io/)
</div>

## Purpose
Implements custom Kubernetes operators and controllers for managing WebAssembly functions, including deployment, scaling, and routing capabilities.

## 🔧 Custom Resources

### 📦 Custom Resource Definitions
- 🎯 WasmFunction CRD
- ⚙️ WasmRuntime CRD
- 🔄 FunctionTrigger CRD
- 🌐 FunctionRoute CRD

### ☸️ Kubernetes Operators
- 🚀 Function Deployment
- 🔄 Runtime Management
- ⚖️ Auto-scaling
- 🌐 Routing
- 💓 Health Checks

## Scripts

### setup_operators.sh
Deploys and configures Kubernetes operators:
- Creates operator namespace
- Installs Custom Resource Definitions
- Sets up RBAC rules
- Deploys custom operators:
  - Function deployment operator
  - Runtime management operator
  - Scaling operator
- Implements health checks

## Configuration Files
```
/config
├── crds/
│   ├── function-crd.yaml
│   ├── runtime-crd.yaml
│   └── route-crd.yaml
├── rbac/
│   ├── role.yaml
│   └── binding.yaml
└── operators/
    ├── function-operator.yaml
    ├── runtime-operator.yaml
    └── scaling-operator.yaml
```

## Dependencies
- Phase 1 & 2 completion
- Functioning runtime environment
- cert-manager installation
- Kubernetes cluster admin access

## 🎯 Implementation
```bash
./setup_operators.sh
```

## Usage
```bash
# Deploy operators
./setup_operators.sh

# Verify operator deployment
kubectl get pods -n wasm-operators
kubectl get crds | grep wasm
```

## 📊 Monitoring
- 📈 Resource utilization
- 🔄 Scaling metrics
- ⚡ Performance data
