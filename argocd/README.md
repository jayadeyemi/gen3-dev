# ArgoCD — gen3-dev Local CSOC

ArgoCD-managed component stack for gen3-dev, mirroring
[gen3-kro](https://github.com/indiana-university/gen3-kro).

## Architecture

ArgoCD is the only component installed directly via Helm. Everything
else is deployed through the bootstrap ApplicationSet chain:

```
kind-local-test.sh install
  └─ Helm installs ArgoCD
  └─ Creates cluster Secret (fleet_member: control-plane)
  └─ Applies bootstrap ApplicationSets
       └─ local-addons → application-sets chart
            └─ KRO controller (wave -30)
            └─ ACK controllers ×9 (wave 1)
            └─ kro-local-rgs RGDs (wave 10)
       └─ local-infra-instances → directory source
            └─ KRO instances (wave 30)
```

## Directory Structure

```
argocd/
├── addons/local/addons.yaml        # Component definitions (KRO, ACK ×9, RGDs)
├── bootstrap/
│   ├── local-addons.yaml           # Bootstrap ApplicationSet for addons
│   └── local-infra-instances.yaml  # Bootstrap ApplicationSet for instances
├── charts/
│   ├── application-sets/           # Meta-chart: one ApplicationSet per addon
│   └── resource-groups/            # RGD templates (9 modular + 1 monolithic + 8 test)
└── cluster-fleet/
    └── local-aws-dev/
        ├── infrastructure/         # Production KRO CR instances (one file per tier)
        └── tests/                  # KRO capability test instances
```

## ResourceGraphDefinitions

### Modular RGDs (7-tier architecture)

| Tier | RGD | Kind | Resources | Instantiated? |
|------|-----|------|-----------|---------------|
| 0 | awsgen3foundation1 | AwsGen3Foundation1 | 16 + bridge | **Yes** (~$37/mo) |
| 1 | awsgen3database1 | AwsGen3Database1 | 9 + bridge | No (needs password Secret) |
| 2 | awsgen3search1 | AwsGen3Search1 | 4 + bridge | No |
| 3 | awsgen3compute2 | AwsGen3Compute2 | 3 + bridge | No (high cost) |
| 4 | awsgen3appiam1 | AwsGen3AppIAM1 | TBD + bridge | No |
| 5 | awsgen3helm1 | AwsGen3Helm1 | TBD | No |
| 6 | awsgen3observability1 | AwsGen3Observability1 | TBD | No |

### Monolithic RGD (reference)

| RGD | Kind | Resources | Instantiated? |
|-----|------|-----------|---------------|
| awsgen3infra1flat | AwsGen3Infra1Flat | 31+ | No (CRD only) |

### Capability Test RGDs (Tests 1-8)

8 test RGDs validating KRO features: forEach, includeWhen, bridge ConfigMap,
externalRef, CEL expressions, multi-SG Pattern A, cross-RGD status flow,
and chained orValue. See `charts/resource-groups/README.md` for details.

## Auto-Sync Configuration

| App | Auto-Sync | Prune | Self-Heal |
|-----|-----------|-------|-----------|
| `kro-local-rgs-*` (RGDs) | Yes | Yes | Yes |
| `*-infra-instance` (instances) | Yes | Yes | No |

Non-breaking RGD changes flow automatically: `git push` → ArgoCD syncs →
KRO reconciles all instances (~15s). No manual intervention needed.

## ACK Credentials

Kind has no OIDC provider, so IRSA is not available. ACK controllers use
a K8s Secret (`ack-aws-credentials`) in the `ack` namespace, injected by
`kind-local-test.sh inject-creds`.

After renewing AWS credentials: `bash scripts/kind-local-test.sh inject-creds`
