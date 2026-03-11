---
applyTo: "argocd/charts/resource-groups/**,**/*-rg.yaml"
---

# KRO ResourceGraphDefinition Conventions

These rules apply when creating or editing RGD YAML files.

## Schema Declaration

Use the KRO DSL for field types:
```yaml
spec:
  fieldName: string | required=true
  fieldWithDefault: string | default="value"
  count: integer | default=1
  enabled: boolean | default=true
  items: "[]string | required=true"    # array types need quotes
```

## Status Propagation

Use optional chaining with `.orValue()` to avoid nil panics:
```yaml
status:
  someField: ${resource.status.?nested.?field.orValue("loading")}
  someArn: ${resource.status.?ackResourceMetadata.?arn.orValue("loading")}
```

## ACK Resources — readyWhen

Every ACK-managed resource must check **both** ARN presence and sync status:
```yaml
readyWhen:
  - ${resource.status.?ackResourceMetadata.?arn.orValue('null') != 'null'}
  - ${resource.status.?conditions.orValue([]).exists(c, c.type == "ACK.ResourceSynced" && c.status == "True")}
```

For KMS keys, also check enabled state:
```yaml
readyWhen:
  - ${resource.status.?keyID.orValue('null') != 'null'}
  - ${resource.status.?conditions.orValue([]).exists(c, c.type == "ACK.ResourceSynced" && c.status == "True")}
  - ${resource.status.?enabled.orValue(false) == true}
```

## ACK Resources — Required Annotations

Every ACK resource template must include these annotations
(matches gen3-kro's AwsGen3Infra1Flat pattern):
```yaml
metadata:
  annotations:
    services.k8s.aws/region: ${schema.spec.region}
    services.k8s.aws/adoption-policy: ${schema.spec.adoptionPolicy}
    services.k8s.aws/deletion-policy: ${schema.spec.deletionPolicy}
```

The schema should expose corresponding fields with defaults:
```yaml
region: string | default="us-east-1"
adoptionPolicy: string | default="adopt-or-create"
deletionPolicy: string | default="delete"
```

## includeWhen (Conditional Resources)

Use `includeWhen` for optional resources:
```yaml
- id: someResource
  includeWhen:
    - ${schema.spec.someFeatureEnabled == true}
```

## Resource Dependency Chain

KRO infers dependencies from CEL expressions. Reference a parent resource's
field in a child template to create an implicit dependency:
```yaml
# Child depends on namespace because it references namespace.metadata.name
namespace: ${namespace.metadata.name}
```

## Versioned Naming Convention

RGDs use versioned naming: monolithic = `AwsGen3<Component><Version>Flat`,
modular = `AwsGen3<Component><Version>` (no Flat suffix).

- metadata.name: lowercase, no hyphens (e.g., `awsgen3foundation1`)
- Kind: CamelCase (e.g., `AwsGen3Foundation1`)
- Filename: `<lowercase>-rg.yaml` (e.g., `awsgen3foundation1-rg.yaml`)

The version number enables creating v2, v3 graphs alongside existing ones.

## Cross-Tier Bridge Pattern

Modular RGDs communicate via bridge ConfigMaps (not Secrets):

```yaml
# Producer: conditional bridge ConfigMap
- id: foundationBridge
  includeWhen:
    - ${schema.spec.createBridgeSecret == true}
  template:
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: ${schema.spec.name}-foundation-bridge
    data:
      vpc-id: ${vpc.status.?vpcID}
```

```yaml
# Consumer: reads bridge via externalRef (cross-namespace)
- id: foundationBridge
  externalRef:
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: ${schema.spec.foundationBridgeName}
      namespace: ${schema.spec.foundationNamespace}
```

Bridge key naming: kebab-case (`vpc-id`, `nat-gateway-id`, `platform-key-arn`).
Access in templates: `${foundationBridge.data['vpc-id']}` (bracket notation for
hyphenated keys).

## gen3-kro Parity

When adapting resources from gen3-kro's AwsGen3Infra1Flat:
1. Keep the same resource `id` names where possible
2. Keep the same tag structure (`Name`, `Environment`, `ManagedBy`, `Project`)
3. Keep the same encryption/versioning settings on S3 buckets
4. Keep the same KMS key policies and IAM trust relationships
5. Simplify: remove cross-account trust (not needed for local)

## ArgoCD Annotations

Every RGD should include:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
    argocd.argoproj.io/sync-wave: "0"
```
