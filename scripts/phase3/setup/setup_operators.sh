#!/bin/bash

# Create operator namespace
kubectl create namespace wasm-operators

# Deploy CRDs
kubectl apply -f config/crds/
kubectl apply -f config/rbac/
kubectl apply -f config/manager/

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml

# Deploy operators
kubectl apply -f config/operators/function-operator.yaml
kubectl apply -f config/operators/runtime-operator.yaml
kubectl apply -f config/operators/scaling-operator.yaml
