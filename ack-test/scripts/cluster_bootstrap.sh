#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"
source "$(dirname "$0")/scripts/etc/config.sh"

MODE="${MODE:-single}"  # default to single-node unless explicitly overridden
log INFO "Cluster bootstrap mode: $MODE"

if [[ "$MODE" == "eks" ]]; then
  log INFO "Provisioning or validating EKS cluster: $CLUSTER_NAME"

  if ! aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" &>/dev/null; then
    log INFO "Creating new EKS cluster..."
    eksctl create cluster \
      --name "$CLUSTER_NAME" \
      --region "$AWS_REGION" \
      --nodes 2 \
      --with-oidc \
      --managed
  else
    log INFO "EKS cluster already exists"
  fi
  log INFO "Configuring kubectl for EKS cluster"
  aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

  log INFO "Installing Helm"
  if ! command -v helm &>/dev/null; then
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod +x get_helm.sh && ./get_helm.sh
  fi
  log INFO "EKS setup complete"
else
  log INFO "Installing single-node Kubernetes (Ubuntu or Amazon Linux)"

  if [[ "$ID" == "amzn" || "$ID_LIKE" =~ rhel ]]; then
    DISTRO="amzn"
  elif [[ "$ID" == "debian" ]]; then
    DISTRO="debian"
  else
    echo "Unsupported distro: $ID"
    exit 1
  fi

  if [[ "$DISTRO" == "amzn" ]]; then
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    sudo systemctl enable --now docker
    sudo yum install -y kubelet kubeadm kubectl
  else
    sudo apt-get update -y
    sudo apt-get install -y containerd 
    sudo mkdir -p /etc/containerd
    sudo containerd config default | sudo tee /etc/containerd/config.toml
    sudo systemctl enable --now containerd
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | \
      sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | \
      sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    sudo systemctl enable --now kubelet
  fi

  sudo swapoff -a
  sudo sed -i.bak '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
  sudo modprobe br_netfilter
  cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward                = 1
EOF
  sudo sysctl --system

  LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 || echo "127.0.0.1")
  sudo kubeadm init --pod-network-cidr=192.168.0.0/16 \
    --upload-certs \
    --control-plane-endpoint "${LOCAL_IP}:6443"

  mkdir -p "$HOME/.kube"
  sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
  sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

  kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
  kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod +x get_helm.sh
  ./get_helm.sh
  rm get_helm.sh

  log INFO "Single-node Kubernetes setup complete"
fi
