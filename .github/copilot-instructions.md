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
| opensearchservice | 1.2.2 | `opensearchservice.services.k8s.aws` |
| rds | 1.7.6 | `rds.services.k8s.aws` |
| s3 | 1.3.1 | `s3.services.k8s.aws` |
| secretsmanager | 1.2.1 | `secretsmanager.services.k8s.aws` |
| sqs | 1.4.1 | `sqs.services.k8s.aws` |

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
│       └── templates/     # RGD YAML files (4 production + 7 capability test RGDs)
│   └── cluster-fleet/
│       └── local-aws-dev/  # Per-cluster overrides + instance values (infrastructure.yaml)
├── config/              # Generated local.env (gitignored)
├── outputs/
│   └── plans/           # Architecture plans & RGD design docs
└── scripts/             # Kind orchestration scripts
    ├── kind-config.yaml
    ├── kind-local-test.sh
    └── lib-logging.sh
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

### AWS Account ID (Runtime Injection)
The AWS account ID is **never stored in git**. It is resolved at runtime via
`aws sts get-caller-identity` and injected into the **ArgoCD cluster Secret**
as the `aws_account_id` annotation (during both `install` and `inject-creds`
stages). ArgoCD propagates the value through the bootstrap chain:
1. **ArgoCD cluster Secret** — `aws_account_id` annotation
2. **ApplicationSet cluster generator** — exposes the annotation as a template variable
3. **Instances Helm chart** — receives it as a `helm.parameters` value (`awsAccountId`)
4. **Namespace annotation** — the chart applies `services.k8s.aws/owner-account-id`

RGDs read the account ID from the namespace annotation via:
```yaml
${spokeNamespace.metadata.annotations['services.k8s.aws/owner-account-id']}
```

## Security — Never Commit Secrets

**NEVER** commit the following to git:
- AWS Account IDs (12-digit numbers)
- AWS Access Key IDs (`AKIA...`)
- AWS Secret Access Keys
- Session tokens, passwords, API keys
- Private keys or certificates
- Any ARNs containing account IDs

Instead, use these patterns:
- **Runtime injection** — resolve via AWS CLI and inject as K8s annotations/Secrets
- **Gitignored files** — use `config/local.env` (already gitignored)
- **Placeholder values** — use `123456789012` for example account IDs in docs/plans
- **ExternalSecrets** — pull secrets from AWS Secrets Manager at runtime

The `.gitignore` covers: `*.ppk`, `*.pem`, `**/secrets/*`, `**/secrets.yaml`,
`**/variables.env`, `**/outputs/*`, `config/local.env`, `credentials`,
`*.credentials`, `.aws/`.

## ResourceGraphDefinitions (RGDs)

RGDs use versioned naming: modular tier graphs use
`AwsGen3<Component><Version>` (e.g., `AwsGen3Foundation2`).

### Modular RGDs (Plan 02 Revision 4 — Foundation-heavy architecture)

| Tier | Category | RGD / Chart | Kind | Status | Depends On | Cost |
|------|----------|-------------|------|--------|------------|------|
| 0 | Infra RGD | awsgen3foundation2 | AwsGen3Foundation2 | ✅ Built (31 resources) | — (standalone) | ~$37/mo |
| 1 | Infra RGD | awsgen3database2 | AwsGen3Database2 | ✅ Built (thin) | databasePrepBridge | ~$45-350/mo |
| 2 | Infra RGD | awsgen3search1 | AwsGen3Search1 | ✅ Built (thin) | searchPrepBridge + foundationBridge | ~$30-200/mo |
| 3 | Infra RGD | awsgen3compute2 | AwsGen3Compute2 | ✅ Built (Standard/Auto) | computePrepBridge + foundationBridge | ~$350/mo |
| 4 | Infra RGD | awsgen3appiam1 | AwsGen3AppIAM1 | ✅ Built | Foundation + Compute bridges | ~$5/mo |
| 5 | App RGD | awsgen3helm1 | AwsGen3Helm1 | ✅ Built | Foundation + Compute bridges | ~$0 (pods) |
| 6 | App RGD | awsgen3observability1 | AwsGen3Observability1 | ✅ Built | Compute bridge | ~$0-50/mo |
| 7 | Infra RGD | awsgen3advanced1 | AwsGen3Advanced1 | ⬜ Future | foundationBridge | ~$0-200/mo |

Foundation2 absorbs ALL prep infrastructure (SGs, IAM roles, DB subnets,
KMS keys) behind feature flags (`databaseEnabled`, `computeEnabled`,
`searchEnabled`). Tiers 1-3 become thin managed-service-only layers.
Creates up to 4 bridge ConfigMaps: `foundationBridge` (always) +
`databasePrepBridge`, `computePrepBridge`, `searchPrepBridge` (conditional).

Tiers 5 and 6 are RGD-managed ArgoCD Applications that deploy Helm charts
onto the spoke EKS cluster. Legacy monolithic and v1 modular RGDs have been
removed.

## KRO Capability Tests

All KRO feature-validation tests live in `argocd/charts/resource-groups/templates/`
and are ArgoCD-managed — no manual `kubectl apply`. Instances are declared in
`argocd/cluster-fleet/local-aws-dev/tests.yaml`.

| # | Kind | RGD file | Instance key(s) | Resources | AWS? |
|---|------|----------|-----------------|-----------|------|
| 1 | `KroForEachTest` | `krotest01-foreach-rg.yaml` | `kro-foreach-basic`, `kro-foreach-cartesian` | ConfigMaps | No |
| 2 | `KroIncludeWhenTest` | `krotest02-includewhen-rg.yaml` | `kro-includewhen-minimal`, `kro-includewhen-full` | ConfigMaps | No |
| 3 | `KroBridgeProducer` | `krotest03-bridge-producer-rg.yaml` | `kro-bridge-producer` | ConfigMaps + Secret | No |
| 4 | `KroBridgeConsumer` | `krotest04-bridge-consumer-rg.yaml` | `kro-bridge-consumer` | ConfigMaps | No |
| 5 | `KroCELTest` | `krotest05-cel-expressions-rg.yaml` | `kro-cel-dev`, `kro-cel-prod` | ConfigMaps | No |
| 6 | `KroTest06SgConditional` | `krotest06-sg-conditional-rg.yaml` | `kro-sg-base-only`, `kro-sg-all-features` | ACK EC2 | Yes |
| 7a | `KroTest07Producer` | `krotest07a-cross-rgd-producer-rg.yaml` | `kro-crossrgd-producer` | ACK EC2 | Yes |
| 7b | `KroTest07Consumer` | `krotest07b-cross-rgd-consumer-rg.yaml` | `kro-crossrgd-consumer` | ACK EC2 | Yes |
| 8 | `KroChainedOrValueTest` | `krotest08-chained-orvalue-rg.yaml` | `kro-chained-orvalue-*` | ConfigMaps | No |

**Key finding (Test 6)**: KRO cannot add conditional entries within a single
`SecurityGroup.spec.ingressRules` or `RouteTable.spec.routes` array. Use
**Pattern A** — multiple separate SG/RT resources with `includeWhen` — one per tier.

**Key finding (Test 7)**: Cross-RGD status values flow via bridge ConfigMap +
`externalRef`. Real AWS SG-to-SG rules use `spec.ingressRules[].userIDGroupPairs[].groupID`
set to `sg.status.id` read from the bridge.

**Key finding (Test 8)**: KRO v0.8.5 silently drops ANY expression/resource that
references an excluded (`includeWhen=false`) resource — even with `.?` optional
chaining + `.orValue()`. **Correct pattern**: conditional duplicate resources with
SAME Kubernetes name but opposite `includeWhen`, each referencing only co-included
resources. Validated with both variants producing correct bridge ConfigMaps.

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
| `02-modular-rgd-design.md` | Defines the 7-tier modular RGD architecture (Foundation → Database → Search → Compute → AppIAM → Advanced → Monitoring) |
| `03-kro-capability-test-report.md` | Test report for KRO capability validation (forEach, includeWhen, bridge ConfigMap, CEL, SG/RT conditional, cross-RGD status) |
| `04-modular-sg-routetable-design.md` | Patterns A–D analysis for SG/RT conditional entries; recommended Pattern A (multi-resource + includeWhen) for gen3-kro |

Consult these files before creating or modifying RGDs to ensure alignment
with the planned modular architecture.
