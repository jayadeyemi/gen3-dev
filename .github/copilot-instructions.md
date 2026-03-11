# gen3-dev — Copilot Custom Instructions

> Auto-loaded for **every** Copilot interaction in this workspace.

## Project Identity

gen3-dev is a **local CSOC** (Central Security Operations Center) — a
Kind cluster on the developer's laptop that manages **real AWS resources**
via [KRO](https://kro.run) (Kube Resource Orchestrator) and
[ACK](https://aws-controllers-k8s.github.io/community/) (AWS Controllers for
Kubernetes).

gen3-dev mirrors [gen3-kro](https://github.com/indiana-university/gen3-kro)'s
CSOC EKS cluster but runs locally. Both repos manage real AWS infrastructure;
gen3-kro does it from EKS via IRSA, gen3-dev does it from Kind via mounted
MFA-assumed-role credentials.

The two repos share the same structural conventions (directory layout, sync-wave
ordering, ACK annotation patterns, ArgoCD chart structure) so that
ResourceGraphDefinitions authored here can be promoted to gen3-kro with minimal
change.

## Technology Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| KRO | 0.8.5 | Graph-based K8s resource orchestrator |
| ACK controllers (7) | various | Kubernetes-native AWS resource management (→ real AWS) |
| ArgoCD | 7.7.16 | GitOps delivery |
| Kind | 0.27.0 | Local K8s cluster (the "local CSOC") |
| AWS CLI | 2.x | AWS API access + credential validation |
| kubectl | 1.35.1 | Cluster CLI |
| Helm | 3.16.1 | Package manager |

### ACK Controllers (active in local)

| Controller | Chart Version | ACK API Group |
|------------|--------------|---------------|
| ec2 | 1.9.2 | `ec2.services.k8s.aws` |
| eks | 1.11.1 | `eks.services.k8s.aws` |
| iam | 1.6.1 | `iam.services.k8s.aws` |
| kms | 1.2.1 | `kms.services.k8s.aws` |
| rds | 1.7.6 | `rds.services.k8s.aws` |
| s3 | 1.3.1 | `s3.services.k8s.aws` |
| secretsmanager | 1.2.1 | `secretsmanager.services.k8s.aws` |

## Directory Layout

```
gen3-dev/
├── .devcontainer/       # DevContainer config (mounts ~/.aws/eks-devcontainer + ~/.gen3-dev)
├── .github/
│   ├── copilot-instructions.md      # This file (always-on)
│   └── instructions/                # Targeted instruction files
├── argocd/
│   ├── addons/local/    # Addon definitions (consumed by application-sets chart)
│   ├── bootstrap/       # Bootstrap ApplicationSets (applied by kind-local-test.sh)
│   ├── charts/
│   │   ├── application-sets/  # Meta-chart: creates per-addon ApplicationSets
│   │   ├── instances/         # Renders KRO Custom Resources from values
│   │   └── resource-groups/
│   │       └── templates/     # RGD YAML files (4 graphs)
│   └── cluster-fleet/
│       └── local/       # Per-cluster overrides + instance values
├── config/              # Generated local.env (gitignored)
├── outputs/
│   └── plans/           # Architecture plans & RGD design docs
├── scripts/             # Kind orchestration scripts
│   ├── kind-config.yaml
│   ├── kind-local-test.sh
│   └── lib-logging.sh
└── tests/local/         # Test instances + validation
    └── validate-rgd.sh
```

## Coding Conventions

### Shell Scripts
- Always use `set -euo pipefail`
- Source `scripts/lib-logging.sh` for consistent logging
- Use the flag-based orchestration pattern (see `kind-local-test.sh`)
- Quote all variables: `"${var}"` not `$var`

### KRO ResourceGraphDefinitions
- Use the KRO DSL: `string | required=true`, `integer | default=1`, `boolean | default=true`
- Status fields use optional chaining: `${resource.status.?field.orValue("loading")}`
- ACK readyWhen always checks both ARN and `ACK.ResourceSynced`:
  ```yaml
  readyWhen:
    - ${resource.status.?ackResourceMetadata.?arn.orValue('null') != 'null'}
    - ${resource.status.?conditions.orValue([]).exists(c, c.type == "ACK.ResourceSynced" && c.status == "True")}
  ```
- Always include ACK annotations on AWS resources:
  ```yaml
  annotations:
    services.k8s.aws/region: ${schema.spec.region}
    services.k8s.aws/adoption-policy: ${schema.spec.adoptionPolicy}
    services.k8s.aws/deletion-policy: ${schema.spec.deletionPolicy}
  ```

### Sync-Wave Ordering
All components follow gen3-kro's ArgoCD sync-wave ordering:
- Wave -30: KRO controller (must exist before RGDs)
- Wave -20: Bootstrap ApplicationSet
- Wave 1: ACK controllers (→ real AWS APIs)
- Wave 10: ResourceGraphDefinitions (via kro-local-rgs)
- Wave 30: KRO instances (infrastructure CRs)

### Bootstrap Pattern (mirrors gen3-kro)
ArgoCD is the **only** component installed directly via Helm.
Everything else is deployed through the ApplicationSet bootstrap chain:
1. `kind-local-test.sh install` → Helm installs ArgoCD
2. Creates ArgoCD cluster Secret (fleet_member: control-plane)
3. Applies bootstrap ApplicationSets (local-addons, local-infra-instances)
4. ArgoCD reconciles: application-sets chart → per-addon ApplicationSets → Applications

### AWS Credentials (Local CSOC)
In gen3-kro, ACK uses **IRSA** (IAM Roles for Service Accounts) on EKS.
In gen3-dev, ACK uses a **K8s Secret** (`ack-aws-credentials`) injected
from the mounted `~/.aws/credentials` file. Credentials are MFA-assumed-role
(Tier 1) written by `mfa-session.sh` on the host.

No `endpoint_url` override — ACK controllers talk directly to real AWS APIs.

Run `kind-local-test.sh inject-creds` after renewing credentials.

## ResourceGraphDefinitions (RGDs)

All RGDs use versioned naming: `AwsGen3<Component><Version>Flat`.

| RGD | Kind | Resources | Purpose |
|-----|------|-----------|---------|
| awsgen3infra1flat | AwsGen3Infra1Flat | 31+ | Full gen3 infrastructure (copied from gen3-kro) |
| awsgen3base1flat | AwsGen3Base1Flat | 15 | Minimal foundation: VPC + networking + KMS + IAM + S3 |
| awsgen3network1flat | AwsGen3Network1Flat | 9 | Network expansion: NAT + EIP + DB subnets + SGs |
| awsgen3test1flat | AwsGen3Test1Flat | 24 | Low-cost test graph (~$37/month, no EKS/Aurora) |

Only the **test graph** (AwsGen3Test1Flat) is instantiated. The other RGDs are
registered as CRDs but not deployed as instances.

## Relationship to gen3-kro

When creating or modifying resources, keep parity with gen3-kro:
- Same ACK annotation patterns
- Same Helm chart structure under `argocd/charts/`
- Same sync-wave ordering
- Same KRO schema conventions (field types, status propagation, readyWhen/includeWhen)
- Simplified: no IRSA, no multi-account trust, no Terraform layer

## Architecture Plans (`outputs/plans/`)

All architecture plans and RGD design documents live in `outputs/plans/`.
When creating new plans, follow the numbered prefix convention:

| File | Purpose |
|------|---------|
| `01-gen3-infrastructure-component-map.md` | Maps all Gen3 services, AWS infrastructure components, dependencies, and cost drivers |
| `02-modular-rgd-design.md` | Defines the 6-tier modular RGD architecture (Foundation → Database → Search → Compute → AppIAM → Advanced) |

Consult these files before creating or modifying RGDs to ensure alignment
with the planned modular architecture.
