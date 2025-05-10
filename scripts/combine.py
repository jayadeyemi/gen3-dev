#!/usr/bin/env python3
"""
Merge every resource.yaml / locals.yaml under a source tree,
    • keep duplicate keys as sequences
    • deep‑merge everything
    • order the inner resource mapping by RESOURCES_ORDER
and write the results to an output directory.
"""

import os
import sys
import yaml

# ───────────────────────────────────────────────────────────
# 1. Custom loader  →  collect duplicate keys into lists
# ───────────────────────────────────────────────────────────
class MultiValueLoader(yaml.SafeLoader):
    """YAML loader that puts duplicate keys into lists."""
    pass


def construct_mapping(loader, node, deep=True):
    mapping = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        val = loader.construct_object(value_node, deep=deep)

        if key in mapping:                      # duplicate!
            if isinstance(mapping[key], list):
                mapping[key].append(val)
            else:
                mapping[key] = [mapping[key], val]
        else:
            mapping[key] = val
    return mapping


# Register the constructor for **all** mappings
MultiValueLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
    construct_mapping,
)

# ───────────────────────────────────────────────────────────
# 2. Desired ordering of second‑level resource keys
# ───────────────────────────────────────────────────────────
RESOURCES_ORDER = [
    ['aws_key_pair'],
    ['aws_wafv2_web_acl'],
    ['aws_autoscaling_group'],
    ['aws_cloudtrail'],
    ['aws_elasticsearch_domain'],
    ['aws_launch_template'],
    ['aws_route53_zone'],
    ['aws_secretsmanager_secret', 'aws_secretsmanager_secret_version'],
    ['aws_sqs_queue', 'aws_sqs_queue_policy'],
    ['aws_sns_topic', 'aws_sns_topic_policy', 'aws_sns_topic_subscription'],
    ['aws_kms_alias', 'aws_kms_grant', 'aws_kms_key'],
    ['aws_db_instance', 'aws_db_parameter_group', 'aws_db_subnet_group'],
    ['aws_cloudwatch_log_group', 'aws_cloudwatch_log_resource_policy',
     'aws_cloudwatch_log_subscription_filter'],
    ['aws_iam_access_key', 'aws_iam_instance_profile', 'aws_iam_policy',
     'aws_iam_role', 'aws_iam_role_policy', 'aws_iam_role_policy_attachment',
     'aws_iam_service_linked_role', 'aws_iam_user', 'aws_iam_user_policy'],
    ['aws_s3_bucket', 'aws_s3_bucket_lifecycle_configuration',
     'aws_s3_bucket_logging', 'aws_s3_bucket_notification',
     'aws_s3_bucket_ownership_controls', 'aws_s3_bucket_policy',
     'aws_s3_bucket_public_access_block',
     'aws_s3_bucket_server_side_encryption_configuration',
     'aws_s3_bucket_versioning'],
    ['aws_vpc', 'aws_security_group', 'aws_subnet',
     'aws_vpc_ipv4_cidr_block_association', 'aws_vpc_peering_connection',
     'aws_default_route_table', 'aws_eip', 'aws_internet_gateway',
     'aws_nat_gateway', 'aws_route', 'aws_main_route_table_association',
     'aws_route_table', 'aws_flow_log'],
]

TARGET_FILES = {
    'flat': 'resource.yaml',
}

# ───────────────────────────────────────────────────────────
# 3. Merge helpers
# ───────────────────────────────────────────────────────────
def merge_values(a, b):
    """Combine two YAML values without losing information."""
    if isinstance(a, dict) and isinstance(b, dict):
        merge_dicts(a, b)              # merge in‑place
        return a
    if isinstance(a, list) and isinstance(b, list):
        return a + b
    if isinstance(a, list):
        return a + [b]
    if isinstance(b, list):
        return [a] + b
    return [a, b]                      # scalar vs scalar → list


def merge_dicts(target: dict, incoming: dict) -> dict:
    """Recursively merge `incoming` into `target`."""
    for k, v in incoming.items():
        if k in target:
            target[k] = merge_values(target[k], v)
        else:
            target[k] = v
    return target


# ───────────────────────────────────────────────────────────
# 4. Load, deep‑merge, and order helpers
# ───────────────────────────────────────────────────────────
def load_and_merge_yaml(path: str) -> dict:
    with open(path, 'r', encoding='utf-8') as fh:
        docs = yaml.load_all(fh, Loader=MultiValueLoader)
        merged = {}
        for doc in docs:
            if isinstance(doc, dict):
                merge_dicts(merged, doc)
    return merged


def collect_and_merge(root: str, filename: str) -> dict:
    combined = {}
    for dirpath, _, files in os.walk(root):
        if filename in files:
            merge_dicts(combined, load_and_merge_yaml(os.path.join(dirpath, filename)))
    return combined


def sort_by_resource_order(tree: dict) -> dict:
    """Return a new dict whose keys follow RESOURCES_ORDER first."""
    flat_order = [k for group in RESOURCES_ORDER for k in group]
    ordered = {k: tree[k] for k in flat_order if k in tree}
    # Append anything that wasn’t in RESOURCES_ORDER
    for k, v in tree.items():
        if k not in ordered:
            ordered[k] = v
    return ordered


def write_output(tree: dict, out_dir: str, tag: str) -> str:
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, f"{tag}.yaml")

    if tag == 'resource':
        if isinstance(tree.get('resource'), dict):
            tree['resource'] = sort_by_resource_order(tree['resource'])
        else:
            tree = sort_by_resource_order(tree)

    with open(out_path, 'w', encoding='utf-8') as fh:
        yaml.safe_dump(tree, fh, sort_keys=False)
    return out_path


# ───────────────────────────────────────────────────────────
# 5. Main
# ───────────────────────────────────────────────────────────
def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(f"Usage: {sys.argv[0]} <source_dir> <dest_dir>")

    src, dst = sys.argv[1], sys.argv[2]
    if not os.path.isdir(src):
        sys.exit(f"[Error] Source '{src}' is not a directory.")

    for tag, fname in TARGET_FILES.items():
        print(f"→ Merging all '{fname}' under '{src}' …")
        merged = collect_and_merge(src, fname)
        if not merged:
            print(f"   [No data found in any '{fname}']")
            continue
        out = write_output(merged, dst, tag)
        print(f"   Wrote {len(merged)} top‑level keys → {out}")


if __name__ == '__main__':
    main()
