#!/bin/bash

# Setup security components
kubectl create namespace security-system

# Deploy security policies
kubectl apply -f config/security/network-policies.yaml
kubectl apply -f config/security/pod-security-policies.yaml

# Setup authentication
kubectl apply -f config/auth/oauth2-proxy.yaml
kubectl apply -f config/auth/cert-manager.yaml

# Setup audit logging
kubectl apply -f config/monitoring/audit-policy.yaml
