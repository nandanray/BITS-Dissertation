#!/bin/bash

# Source user's bashrc to ensure proper environment
if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
fi

# Set token file location
TOKEN_FILE="$HOME/.kube/dashboard/token.txt"

# Check if token file exists and regenerate if needed
if [ ! -f "$TOKEN_FILE" ]; then
    echo "Token file not found. Regenerating token..."
    mkdir -p "$HOME/.kube/dashboard"
    TOKEN=$(kubectl -n kubernetes-dashboard create token admin-user --duration=999999h)
    echo "$TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
fi

# Function to check if port is in use
check_port() {
    local port=$1
    if lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null ; then
        return 0
    else
        return 1
    fi
}

# Find available port
PORT=8001
while check_port "$PORT"; do
    PORT=$((PORT + 1))
done

clear
echo "Starting Kubernetes Dashboard..."
echo ""
echo "Dashboard will be available at:"
echo "http://localhost:$PORT/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo ""
echo "Use this token to log in:"
echo "----------------"
if [ -f "$TOKEN_FILE" ]; then
    cat "$TOKEN_FILE"
else
    echo "Error: Token file not found at $TOKEN_FILE"
    exit 1
fi
echo "----------------"
echo ""
echo "Token is saved in: $TOKEN_FILE"
echo ""
echo "Press Ctrl+C to stop the dashboard"
echo ""
echo "Starting proxy..."
kubectl proxy --port="$PORT"
