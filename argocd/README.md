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
            └─ ACK controllers ×7 (wave 1)
            └─ kro-local-rgs RGDs (wave 10)
       └─ local-infra-instances → instances chart
            └─ KRO instances (wave 15-30)
```

## Directory Structure

```
argocd/
├── addons/local/addons.yaml        # Component definitions (KRO, ACK ×7, RGDs)
├── bootstrap/
│   ├── local-addons.yaml           # Bootstrap ApplicationSet for addons
│   └── local-infra-instances.yaml  # Bootstrap ApplicationSet for instances
├── charts/
│   ├── application-sets/           # Meta-chart: one ApplicationSet per addon
│   ├── instances/                  # Renders KRO CRs from values
│   └── resource-groups/            # RGD templates (4 production + 7 test)
└── cluster-fleet/
    └── local-aws-dev/
        ├── addons.yaml             # Cluster-level addon overrides
        └── infrastructure.yaml     # Instance values (test + foundation)
```

## ResourceGraphDefinitions

### Production RGDs

| RGD | Kind | Resources | Instantiated? |
|-----|------|-----------|---------------|
| awsgen3infra1flat | AwsGen3Infra1Flat | 31+ | No (CRD only) |
| awsgen3base1flat | AwsGen3Base1Flat | 15 | No (CRD only) |
| awsgen3network1flat | AwsGen3Network1Flat | 9 | No (CRD only) |
| awsgen3test1flat | AwsGen3Test1Flat | 24 | **Yes** (~$37/mo) |
| awsgen3foundation1 | AwsGen3Foundation1 | 16 + bridge | **Yes** (~$37/mo) |
| awsgen3database1 | AwsGen3Database1 | 9 + bridge | No (needs password Secret) |
| awsgen3compute1 | AwsGen3Compute1 | 6 + bridge | No (high cost) |

### Capability Test RGDs (Tests 1-7b)

7 test RGDs validating KRO features: forEach, includeWhen, bridge ConfigMap,
externalRef, CEL expressions, multi-SG Pattern A, and cross-RGD status flow.
See `charts/resource-groups/README.md` for details.

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
