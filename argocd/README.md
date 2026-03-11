# ArgoCD — gen3-dev Local CSOC

This directory contains the ArgoCD-managed component stack for gen3-dev,
mirroring the structure of [gen3-kro](https://github.com/indiana-university/gen3-kro).

## Architecture

ArgoCD is the **only** component installed directly via Helm. Everything
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
            └─ AwsGen3Test1Flat instance (wave 30)
```

## Directory Structure

```
argocd/
├── addons/local/addons.yaml      # Component definitions (KRO, ACK ×7, RGDs)
├── bootstrap/
│   ├── local-addons.yaml         # Bootstrap ApplicationSet for addons
│   └── local-infra-instances.yaml # Bootstrap ApplicationSet for instances
├── charts/
│   ├── application-sets/         # Meta-chart: one ApplicationSet per addon
│   ├── instances/                # Renders KRO CRs from values
│   └── resource-groups/          # RGD templates
│       └── templates/
│           ├── awsgen3infra1flat-rg.yaml    # Full infra (31+ resources)
│           ├── awsgen3base1flat-rg.yaml     # Minimal foundation (15 resources)
│           ├── awsgen3network1flat-rg.yaml  # Network expansion (9 resources)
│           └── awsgen3test1flat-rg.yaml     # Low-cost test (24 resources)
└── cluster-fleet/
    └── local/
        ├── addons.yaml           # Cluster-level addon overrides
        └── infrastructure.yaml   # Instance values (test graph only)
```

## ResourceGraphDefinitions

| RGD | Kind | Resources | Instantiated? |
|-----|------|-----------|---------------|
| awsgen3infra1flat | AwsGen3Infra1Flat | 31+ | No (CRD only) |
| awsgen3base1flat | AwsGen3Base1Flat | 15 | No (CRD only) |
| awsgen3network1flat | AwsGen3Network1Flat | 9 | No (CRD only) |
| awsgen3test1flat | AwsGen3Test1Flat | 24 | **Yes** (~$37/month) |

## ACK Credentials

Kind has no OIDC provider, so IRSA is not available. ACK controllers use
a K8s Secret (`ack-aws-credentials`) in the `ack` namespace, injected by
`kind-local-test.sh inject-creds`. The `ignoreDifferences` field in
addons.yaml prevents ArgoCD from reverting the injected env vars.

After renewing AWS credentials: `bash scripts/kind-local-test.sh inject-creds`
