#!/bin/bash

echo "=== Checking k3s service status ==="
sudo systemctl status k3s

echo -e "\n=== Checking k3s service logs ==="
sudo journalctl -xeu k3s.service

echo -e "\n=== Checking system requirements ==="
echo "Memory:"
free -h

echo -e "\nCPU:"
nproc

echo -e "\nDisk Space:"
df -h /

echo -e "\n=== Checking port availability ==="
echo "Port 6443:"
sudo lsof -i :6443

echo -e "\nPort 10250:"
sudo lsof -i :10250 