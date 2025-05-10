#!/usr/bin/env python3
"""
Recursively combine all YAML “blocks” in a folder into one file,
inlining any `source: <subdir>` references as nested blocks.
"""

import os
import sys
import yaml
from yaml.resolver import BaseResolver
from collections.abc import Mapping

# ───────────────────────────────────────────────────────────
# 1. Loader → collect duplicate keys into lists
# ───────────────────────────────────────────────────────────
class MultiValueLoader(yaml.SafeLoader):
    """YAML loader that puts duplicate mapping keys into Python lists."""
    pass

def construct_mapping(loader, node, deep=True):
    mapping = {}
    for key_node, val_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        val = loader.construct_object(val_node, deep=deep)
        if key in mapping:
            if isinstance(mapping[key], list):
                mapping[key].append(val)
            else:
                mapping[key] = [mapping[key], val]
        else:
            mapping[key] = val
    return mapping

MultiValueLoader.add_constructor(
    BaseResolver.DEFAULT_MAPPING_TAG,
    construct_mapping,
)

# ───────────────────────────────────────────────────────────
# 2. Merge helpers (deep-merge dicts & lists)
# ───────────────────────────────────────────────────────────
def merge_values(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        return merge_dicts(a, b)
    if isinstance(a, list) and isinstance(b, list):
        return a + b
    if isinstance(a, list):
        return a + [b]
    if isinstance(b, list):
        return [a] + b
    # scalar vs scalar → list
    return [a, b]

def merge_dicts(target: dict, incoming: dict) -> dict:
    for k, v in incoming.items():
        if k in target:
            target[k] = merge_values(target[k], v)
        else:
            target[k] = v
    return target

# ───────────────────────────────────────────────────────────
# 3. Load & merge a single YAML file (all docs in it)
# ───────────────────────────────────────────────────────────
def load_and_merge_yaml(path: str) -> dict:
    with open(path, 'r', encoding='utf-8') as fh:
        docs = yaml.load_all(fh, Loader=MultiValueLoader)
        merged = {}
        for doc in docs:
            if isinstance(doc, dict):
                merge_dicts(merged, doc)
    return merged

# ───────────────────────────────────────────────────────────
# 4. Combine every YAML file in a folder, inline “source:” keys
# ───────────────────────────────────────────────────────────
def combine_folder(folder: str) -> dict:
    # 4.1 Merge all .yaml/.yml files at this level
    combined = {}
    for fn in os.listdir(folder):
        if fn.lower().endswith(('.yaml', '.yml')):
            full = os.path.join(folder, fn)
            merge_dicts(combined, load_and_merge_yaml(full))

    # 4.2 Recursively inline any `source: subdir` entries
    def inline_sources(node: Mapping, base: str):
        # Only dicts can carry a `source:` key
        if not isinstance(node, dict):
            return
        if 'source' in node and isinstance(node['source'], str):
            sub = os.path.normpath(os.path.join(base, node['source']))
            if os.path.isdir(sub):
                # recurse and merge
                nested = combine_folder(sub)
                # remove the scalar source key
                node.pop('source')
                # merge each nested key into our node
                for k, v in nested.items():
                    if k in node:
                        node[k] = merge_values(node[k], v)
                    else:
                        node[k] = v
        # dive deeper
        for v in list(node.values()):
            if isinstance(v, dict):
                inline_sources(v, base)
            elif isinstance(v, list):
                for item in v:
                    if isinstance(item, dict):
                        inline_sources(item, base)

    inline_sources(combined, folder)
    return combined

# ───────────────────────────────────────────────────────────
# 5. CLI entrypoint
# ───────────────────────────────────────────────────────────
def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <source_dir> <output_file.yaml>")
        sys.exit(1)

    src_dir = os.path.join(os.path.abspath(sys.argv[1]), "tf_files", "aws", "commons")
    out_file = os.path.abspath(sys.argv[2])

    if not os.path.isdir(src_dir):
        sys.exit(f"[Error] '{src_dir}' is not a directory")

    result = combine_folder(src_dir)

    # dump without sorting keys, preserving insertion order
    with open(out_file, 'w', encoding='utf-8') as fh:
        yaml.safe_dump(result, fh, sort_keys=False)
    print(f"Combined YAML from '{src_dir}' → {out_file}")
if __name__ == '__main__':
    main()
