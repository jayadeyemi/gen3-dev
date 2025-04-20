ack-deploy-system/
├── README.md
├── values.yaml
├── deploy.sh
└── scripts/
    ├── lib/
    │   └── common.sh
    ├── etc/
    │   ├── config.sh
    │   └── release.sh
    ├── eks-bootstrap.sh
    └── managed-bootstrap.sh

    # ACK + Helm Deployment System

This project automates IRSA bootstrap and Helm‑based deployment of AWS Controllers for Kubernetes (ACK) in either **EKS** or **managed** (local) modes.

## Prerequisites
- Bash >= 4
- AWS CLI v2
- eksctl (for EKS mode)
- helm v3
- yq (YAML parser)

## Usage
1. Edit `values.yaml` to configure your cluster, OIDC, and controllers.
2. `chmod +x deploy.sh`
3. `./deploy.sh [--mode eks|managed]`

---