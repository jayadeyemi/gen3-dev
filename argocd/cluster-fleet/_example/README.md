# Cluster Fleet Examples

> **Note**: These files use the Helm values format (`instances:` map) — an
> alternate format for reference. The active deployment pattern uses individual
> standalone CR YAML files per tier in `cluster-fleet/local-aws-dev/infrastructure/`,
> applied directly by the `local-infra-instances` ApplicationSet (directory source).

## Helm Values Examples

- **`-tested`**: Validated on real AWS infrastructure. Values match actual deployments.
- **`-untested`**: Freshly created templates. Not yet validated — use as starting points.

## Available Examples

| File | Description | Tiers | Cost | Status |
|------|-------------|-------|------|--------|
| `infrastructure-local-aws-dev-tested.yaml` | Full 7-tier modular deployment (local CSOC) | 0-6 | ~$460+/mo | Tested |
| `infrastructure-spoke1-tested.yaml` | Monolithic AwsGen3Infra1Flat (CSOC EKS) | All-in-one | ~$100+/mo | Tested |
| `infrastructure-foundation-only-untested.yaml` | Minimum viable: Foundation only | 0 | ~$37/mo | Untested |
| `infrastructure-foundation-database-untested.yaml` | Foundation + Aurora database | 0, 1 | ~$82-387/mo | Untested |
| `infrastructure-multi-spoke-untested.yaml` | Two spokes from one CSOC | 0 (×2) | ~$74+/mo | Untested |

## Usage

1. To add a new tier, create a standalone YAML file in:
   ```
   cluster-fleet/local-aws-dev/infrastructure/<name>.yaml
   ```

2. Update the spec values (names, CIDRs, bucket names, regions) for your environment.

3. Ensure all prerequisites for each tier are met (see tier YAML file headers).

4. Push to trigger ArgoCD sync — the `local-infra-instances` ApplicationSet
   applies all YAML files in the `infrastructure/` directory automatically.

## CIDR Planning

When deploying multiple spokes, use non-overlapping ranges:

| Spoke | VPC CIDR | Private Subnets | Public Subnets | DB Subnets |
|-------|----------|-----------------|----------------|------------|
| spoke1 | 10.1.0.0/16 | 10.1.0.0/20, 10.1.16.0/20 | 10.1.240.0/24, 10.1.241.0/24 | 10.1.32.0/24, 10.1.33.0/24 |
| spoke2 | 10.2.0.0/16 | 10.2.0.0/20, 10.2.16.0/20 | 10.2.240.0/24, 10.2.241.0/24 | 10.2.32.0/24, 10.2.33.0/24 |
| spoke3 | 10.3.0.0/16 | 10.3.0.0/20, 10.3.16.0/20 | 10.3.240.0/24, 10.3.241.0/24 | 10.3.32.0/24, 10.3.33.0/24 |
