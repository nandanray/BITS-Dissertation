#!/bin/bash

# Create namespace for Wasm runtime
kubectl create namespace wasm-system

# Apply runtime CRDs
kubectl apply -f config/crds/wasm-runtime.yaml
kubectl apply -f config/crds/wasm-function.yaml

# Deploy runtime controller
kubectl apply -f config/controller/runtime-controller.yaml

# Setup monitoring
kubectl apply -f config/monitoring/runtime-metrics.yaml
