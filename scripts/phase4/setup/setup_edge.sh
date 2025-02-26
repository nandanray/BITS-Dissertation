#!/bin/bash

# Setup edge namespace
kubectl create namespace edge-system

# Deploy edge components
kubectl apply -f config/edge/discovery.yaml
kubectl apply -f config/edge/distribution.yaml
kubectl apply -f config/edge/caching.yaml

# Setup service mesh
kubectl apply -f config/service-mesh/istio-operator.yaml
kubectl apply -f config/service-mesh/gateway.yaml
