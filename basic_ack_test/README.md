# my-ack-project

## Overview
Deploy ACK service controllers (S3 & EC2) with custom reconcile intervals,
and your AWS resources (Bucket & VPC) in one Helm chart.

## Prerequisites
- **Helm 3.8+**  
- **kubectl** configured to your cluster  
- **AWS CLI** with appropriate permissions  
- (production deployments) **Linux EC2** with a Kubernetes cluster (EKS or self‑managed) having two nodes  
- (local deployments) **Minikube** installed

## Prerequisites
- A Kubernetes cluster (for local testing, you can use [kind](https://kind.sigs.k8s.io/) or [minikube]).
- `kubectl` configured to interact with your cluster.
- AWS CLI installed and configured with credentials that have the necessary permissions.
- ACK controllers for the S3 and EC2 (VPC) services installed on your cluster. Follow the ACK documentation to install these controllers.

## Local Testing with Minikube
```bash
# 1. Start a 2‑node cluster:
minikube start --nodes=2

# 2. Label the nodes:
NODE_S3=$(kubectl get nodes -o name | sed -n '2p' | cut -d/ -f2)
NODE_VPC=$(kubectl get nodes -o name | sed -n '3p' | cut -d/ -f2)
NODE_S3=$NODE_S3 NODE_VPC=$NODE_VPC ./scripts/label-nodes.sh

# 3. Deploy the resources:
chmod +x scripts/label-nodes.sh scripts/deploy.sh
./scripts/deploy.sh

# 4. Verify the deployment:
kubectl get deployments -A
kubectl get buckets -A
kubectl get vpcs -A
kubectl get pods -A
kubectl get events -A
```

## Production Deployment on EC2
```bash
# 2. Label the nodes:
kubectl label node minikube-1 role=s3
kubectl label node minikube-2 role=vpc
# 3. Deploy the resources:
chmod +x scripts/label-nodes.sh scripts/deploy.sh
./scripts/deploy.sh
# 4. Verify the deployment:
kubectl get deployments -A
kubectl get buckets -A
kubectl get vpcs -A
kubectl get pods -A
kubectl get events -A
```

## Bootstrap Kubernetes Cluster on Production EC2

These scripts will install and configure a two‑node Kubernetes cluster using kubeadm.

### 1. Launch Two EC2 Instances
- One instance tagged/assigned as **master**, the other as **worker**.
- Security Group must allow:
  - TCP 6443 (Kubernetes API)
  - UDP 10250-10252 (kubelet, control‑plane components)
  - Calico ports (per Calico docs)
  - SSH (22)

### 2. On the Master Instance
```bash
git clone https://…/my-ack-project.git
cd my-ack-project/scripts
chmod +x setup-master.sh
sudo ./setup-master.sh

## Notes
- **IAM Permissions:** Make sure that the EC2 instance, and the ACK controller pods, have the proper IAM permissions to create AWS resources like S3 buckets and VPCs.
- **ACK Controller Configuration:** The ACK controllers are not typically bound to a particular node. If you require specific node scheduling for the controllers, modify the deployment manifests of the ACK controllers to include node selectors or affinities as needed.
- **Resource Modifications:** Customize resource parameters in the YAML files to suit your production environment.

---

## Final Remarks
This solution provides a modular approach to deploying AWS resources using ACK on a Kubernetes cluster. You can adjust the configurations, resource specifications, and deployment procedures based on your environment and production requirements.

Please let me know if you need further clarifications or additional modifications, Jimi.
