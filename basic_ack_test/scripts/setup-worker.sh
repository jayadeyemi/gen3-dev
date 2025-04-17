#!/usr/bin/env bash
set -euo pipefail

# This script runs on your “worker” EC2 instance.
# It expects that you've copied join-command.sh from the master into the same dir.

# 1. Install container runtime & prerequisites (same as master)
if command -v yum &>/dev/null; then
  sudo yum update -y
  sudo amazon-linux-extras install docker -y
  sudo systemctl enable docker && sudo systemctl start docker
  sudo yum install -y kubelet kubeadm kubectl
else
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg lsb-release
  sudo apt-get install -y containerd
  sudo mkdir -p /etc/containerd && \
    sudo containerd config default | sudo tee /etc/containerd/config.toml
  sudo systemctl restart containerd
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | sudo apt-key add -
  echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update -y
  sudo apt-get install -y kubelet kubeadm kubectl
fi

# 2. Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 3. Join the cluster
if [[ ! -f join-command.sh ]]; then
  echo "ERROR: join-command.sh not found in $(pwd)"
  exit 1
fi

sudo bash ./join-command.sh

echo "✅ Worker joined the cluster!"
