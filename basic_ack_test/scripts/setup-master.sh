#!/usr/bin/env bash
set -euo pipefail

# This script runs on your “master” EC2 instance.

# 1. Install container runtime (containerd) & prerequisites
#    Adapt for Amazon Linux 2 or Ubuntu as needed.
if command -v yum &>/dev/null; then
  # Amazon Linux 2
  sudo yum update -y
  sudo amazon-linux-extras install docker -y
  sudo systemctl enable docker && sudo systemctl start docker
  sudo yum install -y kubelet kubeadm kubectl
else
  # Ubuntu
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg lsb-release
  # Install containerd
  sudo apt-get install -y containerd
  sudo mkdir -p /etc/containerd
  sudo containerd config default | sudo tee /etc/containerd/config.toml
  sudo systemctl restart containerd
  # Install Kubernetes components
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | sudo apt-key add -
  echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update -y
  sudo apt-get install -y kubelet kubeadm kubectl
fi

# 2. Disable swap (required by kubeadm)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 3. Initialize the control-plane
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --upload-certs \
  --control-plane-endpoint "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):6443"

# 4. Set up kubectl for ec2-user or ubuntu
USER_HOME=$(eval echo "~$USER")
mkdir -p $USER_HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $USER_HOME/.kube/config
sudo chown $(id -u):$(id -g) $USER_HOME/.kube/config

# 5. Install a pod‑network add‑on (Calico)
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# 6. Save the “join” command for your worker node
kubeadm token create --print-join-command \
  | tee $USER_HOME/join-command.sh
chmod +x $USER_HOME/join-command.sh

echo "✅ Master setup complete. Worker join command saved to $USER_HOME/join-command.sh"
