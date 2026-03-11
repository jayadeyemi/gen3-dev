# Resource Groups — KRO ResourceGraphDefinitions

This chart contains KRO ResourceGraphDefinitions (RGDs) for the gen3-dev
local CSOC. Deployed by ArgoCD via the `kro-local-rgs` addon (wave 10).

## Naming Convention

All RGDs use versioned naming: `AwsGen3<Component><Version>Flat`

The version number enables creating v2, v3 graphs alongside existing ones
without breaking backward compatibility.

## RGDs

### AwsGen3Infra1Flat (v1 — Full Infrastructure)
- **File:** `awsgen3infra1flat-rg.yaml`
- **Resources:** 31+ (VPC, EKS, Aurora, KMS, IAM, S3, security groups, etc.)
- **Copied from:** gen3-kro (exact copy for parity)
- **Cost:** ~$100+/month (EKS + Aurora)

### AwsGen3Base1Flat (v1 — Minimal Foundation)
- **File:** `awsgen3base1flat-rg.yaml`
- **Resources:** 15 (VPC, IGW, subnets, KMS keys, IAM roles, S3 buckets)
- **Purpose:** Minimal foundation that AwsGen3Network1Flat can expand upon

### AwsGen3Network1Flat (v1 — Network Expansion)
- **File:** `awsgen3network1flat-rg.yaml`
- **Resources:** 9 (EIP, NAT, DB subnets, security groups, DB subnet group)
- **Purpose:** Adds NAT + DB layer to an existing AwsGen3Base1Flat

### AwsGen3Test1Flat (v1 — Low-Cost Test)
- **File:** `awsgen3test1flat-rg.yaml`
- **Resources:** 24 (all low-cost components from Infra1Flat)
- **Purpose:** Validates full KRO→ACK→AWS pattern without expensive compute
- **Cost:** ~$37/month (no EKS cluster, no Aurora)
- **Status:** Only graph with an active instance

## Creating a v2 Graph

To create version 2 of any graph:
1. Copy the v1 file: `cp awsgen3test1flat-rg.yaml awsgen3test2flat-rg.yaml`
2. Update `metadata.name` to `awsgen3test2flat`
3. Update `kind` to `AwsGen3Test2Flat`
4. Make your changes
5. Both v1 and v2 can coexist as separate CRDs
