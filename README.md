# gen3-dev

**Local CSOC** (Central Security Operations Center) —
a Kind cluster on the developer's laptop that manages **real AWS resources**
via [KRO](https://kro.run) and [ACK](https://aws-controllers-k8s.github.io/community/).

gen3-dev mirrors [gen3-kro](https://github.com/indiana-university/gen3-kro)'s
CSOC EKS cluster but runs locally. Both repos manage real AWS infrastructure;
gen3-kro does it from EKS via IRSA, gen3-dev does it from Kind via mounted
MFA-assumed-role credentials.

## Quick Start

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Docker Desktop | latest | [docker.com](https://www.docker.com/products/docker-desktop/) |
| AWS CLI | 2.x | [aws.amazon.com](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Kind | 0.27.0 | `go install sigs.k8s.io/kind@v0.27.0` |
| kubectl | 1.35.1 | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| Helm | 3.16.1 | [helm.sh](https://helm.sh/docs/intro/install/) |

### AWS Credentials

ACK controllers talk directly to **real AWS APIs**. Credentials are
MFA-assumed-role, written by `mfa-session.sh` on the host:

```bash
# On the host — renew MFA session
bash scripts/mfa-session.sh <MFA_CODE>

# Inside the container — inject refreshed creds into the Kind cluster
bash scripts/kind-local-test.sh inject-creds
```

### One-Command Setup

```bash
# Create cluster + install full stack + inject creds + run tests
bash scripts/kind-local-test.sh create install inject-creds test
```

### Step-by-Step

```bash
# 1. Create the Kind cluster
bash scripts/kind-local-test.sh create

# 2. Install the component stack (KRO → ACK → ArgoCD → RGDs)
bash scripts/kind-local-test.sh install

# 3. Inject AWS credentials into the cluster
bash scripts/kind-local-test.sh inject-creds

# 4. Connect to ArgoCD UI
bash scripts/kind-local-test.sh connect
# → Open http://localhost:8080 (admin / <generated password>)

# 5. Run validation tests
bash scripts/kind-local-test.sh test

# 6. Check status
bash scripts/kind-local-test.sh status

# 7. Tear down
bash scripts/kind-local-test.sh destroy
```

### DevContainer (VS Code)

Open the repo in VS Code and select **Reopen in Container**. The DevContainer:
- Builds from the included `Dockerfile`
- Mounts `~/.aws/eks-devcontainer` for AWS credentials
- Mounts `~/.gen3-dev` for dedicated kubeconfig
- Sets `AWS_PROFILE=csoc` and `KUBECONFIG=~/.gen3-dev/kubeconfig`

## Component Stack

Installed in sync-wave order (matching gen3-kro's ArgoCD addons):

| Wave | Component | Version | Purpose |
|------|-----------|---------|---------|
| -30 | KRO | 0.8.5 | Graph-based resource orchestrator |
| 1 | ACK ec2 | 1.9.2 | EC2 controller → real AWS |
| 1 | ACK eks | 1.11.1 | EKS controller → real AWS |
| 1 | ACK iam | 1.6.1 | IAM controller → real AWS |
| 1 | ACK kms | 1.2.1 | KMS controller → real AWS |
| 1 | ACK rds | 1.7.6 | RDS controller → real AWS |
| 1 | ACK s3 | 1.3.1 | S3 controller → real AWS |
| 1 | ACK secretsmanager | 1.2.1 | SecretsManager controller → real AWS |
| 5 | ArgoCD | 7.7.16 | GitOps delivery |
| 10 | RGDs | — | ResourceGraphDefinition chart |

## Testing Tiers

### Tier 1 — K8s Smoke (no ACK required)

Pure Kubernetes resources testing the KRO engine:
```
Namespace → ConfigMap → Deployment → Service
```

```bash
./tests/local/validate-rgd.sh smoke
```

### Tier 2 — AWS Storage (ACK + real AWS)

ACK-managed AWS resources against real AWS APIs:
```
KMS Keys (×2) + IAM Roles (×2) → S3 Buckets (×3)
```

```bash
./tests/local/validate-rgd.sh storage
```

### Run All Tiers

```bash
./tests/local/validate-rgd.sh all
```

## Directory Structure

```
gen3-dev/
├── .devcontainer/           # VS Code DevContainer
├── .github/
│   ├── copilot-instructions.md    # Always-on Copilot context
│   └── instructions/              # Targeted instruction files
├── argocd/
│   ├── addons/local/        # Component stack documentation
│   ├── bootstrap/           # Reference ApplicationSet
│   └── charts/resource-groups/
│       └── templates/       # KRO RGD YAML files
├── config/                  # Generated local.env (gitignored)
├── scripts/                 # Kind orchestration
└── tests/local/             # Test instances + validation
```

## Relationship to gen3-kro

| Aspect | gen3-kro | gen3-dev |
|--------|----------|----------|
| Cluster | EKS (real AWS) | Kind (local) |
| AWS APIs | Real (via IRSA) | Real (via mounted creds) |
| ACK auth | IRSA | K8s Secret (`ack-aws-credentials`) |
| Bootstrap | 3-layer ApplicationSet | Direct Helm installs |
| RGDs | Full AwsGen3Infra1Flat (1874 lines) | Adapted subset (S3+KMS+IAM) |
| Directory layout | ✓ Same structure | ✓ Same structure |
| Sync-wave ordering | ✓ Same waves | ✓ Same waves |
| ACK annotations | ✓ Same pattern | ✓ Same pattern |

## License

See [LICENSE](LICENSE).
