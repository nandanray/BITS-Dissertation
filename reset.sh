#!/bin/bash

k3d cluster delete wasm-edge-cluster
sudo systemctl stop streamlit-dashboard.service
kubectl get wasmfunctions.wasm.bits-dissertation.io -n wasm-system
kubectl port-forward deployment/hello-world 8081:80 -n wasm-system
kubectl delete deployment hello-world -n wasm-system
kubectl delete deployment my-new-deployment -n default
kubectl delete service nginx -n default
kubectl delete all --all -n default
kubectl delete namespace wasm-system
kubectl delete deployments --all --all-namespaces



#Resource tagging
#Trades and taints tolerance
#switch to k3s
#Openelb for cluster load balancing
#Make a rust based kubernetes dashboard