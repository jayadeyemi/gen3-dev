# Resource Groups — KRO ResourceGraphDefinitions

KRO RGDs for the gen3-dev local CSOC. Deployed by ArgoCD via `kro-local-rgs` (wave 10).

## Naming

- Monolithic: `AwsGen3<Component><Version>Flat` (e.g. `AwsGen3Test1Flat`)
- Modular: `AwsGen3<Component><Version>` (e.g. `AwsGen3Foundation1`)
- Filename: `<lowercase>-rg.yaml`, metadata.name: lowercase no hyphens

## Production RGDs

### Monolithic (legacy/reference)

| RGD | Kind | Resources | Cost | Instantiated? |
|-----|------|-----------|------|---------------|
| `awsgen3infra1flat` | AwsGen3Infra1Flat | 31+ | ~$100+/mo | No (CRD only) |
| `awsgen3base1flat` | AwsGen3Base1Flat | 15 | ~$5/mo | No (CRD only) |
| `awsgen3network1flat` | AwsGen3Network1Flat | 9 | ~$37/mo | No (CRD only) |
| `awsgen3test1flat` | AwsGen3Test1Flat | 24 | ~$37/mo | **Yes** |

### Modular (7-tier architecture, Plan 02)

| Tier | RGD | Kind | Resources | Cost | Instantiated? |
|------|-----|------|-----------|------|---------------|
| 0 | `awsgen3foundation1` | AwsGen3Foundation1 | 16 + bridge | ~$37/mo | **Yes** |
| 1 | `awsgen3database1` | AwsGen3Database1 | 9 + bridge | ~$45-350/mo | No (needs password Secret) |
| 3 | `awsgen3compute1` | AwsGen3Compute1 | 6 + bridge | ~$350/mo | No (high cost) |

Cross-tier data flows via **bridge ConfigMaps** (not Secrets). Consumer tiers
read the bridge via `externalRef` (validated by KRO capability Tests 3/4/7).

## Capability Test RGDs

| # | Kind | File | ACK? | Tests |
|---|------|------|------|-------|
| 1 | KroForEachTest | `krotest01-foreach-rg.yaml` | No | forEach (single + cartesian) |
| 2 | KroIncludeWhenTest | `krotest02-includewhen-rg.yaml` | No | includeWhen conditional creation |
| 3 | KroBridgeProducer | `krotest03-bridge-producer-rg.yaml` | No | Bridge ConfigMap output |
| 4 | KroBridgeConsumer | `krotest04-bridge-consumer-rg.yaml` | No | externalRef bridge consumption |
| 5 | KroCELTest | `krotest05-cel-expressions-rg.yaml` | No | CEL ternary, string, math |
| 6 | KroTest06SgConditional | `krotest06-sg-conditional-rg.yaml` | Yes | Multi-SG Pattern A + includeWhen |
| 7a | KroTest07Producer | `krotest07a-cross-rgd-producer-rg.yaml` | Yes | Cross-RGD bridge with real ACK |
| 7b | KroTest07Consumer | `krotest07b-cross-rgd-consumer-rg.yaml` | Yes | SG-to-SG via bridge + externalRef |

Test instances are defined in `cluster-fleet/local-aws-dev/infrastructure.yaml`.

## Modifying RGDs

### Non-Breaking Changes (safe, fully automatic)

- Adding resources (with or without schema changes)
- Adding schema fields **with defaults**
- Modifying template values or CEL expressions
- Removing resources (KRO garbage-collects them)

Procedure: edit YAML → `git push` → ArgoCD auto-syncs → KRO reconciles all instances (~15s).

### Breaking Changes (blocked by KRO)

- Removing or renaming schema spec/status fields
- KRO rejects the CRD update: `breaking changes detected: Property X was removed`
- RGD goes **Inactive**; instances keep running but cannot be deleted (finalizer stuck)

**Recovery:**
```bash
# 1. Patch finalizers off stuck instances
kubectl patch <kind> <name> -n <ns> -p '{"metadata":{"finalizers":null}}' --type=merge
# 2. Delete instances
kubectl delete <kind> <name> -n <ns>
# 3. Delete the CRD (KRO recreates it from current RGD in ~10s)
kubectl delete crd <kind-plural>.kro.run
# 4. Re-sync instances
argocd app sync <instance-app> --force --prune
```

**Recommended:** Never remove schema fields. Version the RGD instead (v2 with new schema)
and migrate instances, then delete the old RGD.

## Creating a v2 Graph

1. Copy v1: `cp awsgen3test1flat-rg.yaml awsgen3test2flat-rg.yaml`
2. Update `metadata.name` → `awsgen3test2flat`
3. Update `kind` → `AwsGen3Test2Flat`
4. Make schema changes freely (new CRD, no breaking change risk)
5. Both v1 and v2 coexist as separate CRDs
