#!/usr/bin/env python3
"""
post-proc.py
---------------------
Delete the literal "- " that begins a YAML line, while preserving indentation.

Usage examples
==============

# Walk a folder, copy to a destination, and process specific files:

python post-proc.py source_folder dest_folder file1.yaml file2.yml

# Only process files (current folder walk with '.') and copy them into a dest:

python post-proc.py . dest_folder config1.yaml config2.yml

# Walk a folder only (no explicit file list):
python post-proc.py source_folder dest_folder
"""

from pathlib import Path
import argparse
import sys
import shutil
from typing import Iterable

# ────────────────────────────────────────────────────────────────────────────────
# Core helpers
# ────────────────────────────────────────────────────────────────────────────────
def _strip_dash(line: str) -> str:
    """Return the line unchanged unless its first non-blank characters are '- '."""
    leading = len(line) - len(line.lstrip(" "))  # count leading spaces
    body = line[leading:]
    if body.startswith("- "):
        return " " * leading + body[2:]
    return line


def _process_one(path: Path) -> None:
    """Read → modify → write a single file (silently skips non-existent paths)."""
    if not path.is_file():
        return  # skip

    try:
        original = path.read_text(encoding="utf-8").splitlines(keepends=True)
    except UnicodeDecodeError:
        # print(f"[WARN] {path} is not a UTF-8 text file – skipped", file=sys.stderr)
        return

    updated = [_strip_dash(l) for l in original]
    if updated != original:
        path.write_text("".join(updated), encoding="utf-8")
        # print(f"[INFO] cleaned → {path.as_posix()}")


def _process_many(paths: Iterable[Path]) -> None:
    for p in paths:
        _process_one(p)


def _walk_and_process(root: Path) -> None:
    """Recursively process every *.yaml / *.yml file beneath *root*."""
    if not root.exists():
        # print(f"[WARN] directory '{root}' not found – walk skipped", file=sys.stderr)
        return
    _process_many(root.rglob("*.yaml"))
    _process_many(root.rglob("*.yml"))


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Copy source tree, then remove leading '- ' from YAML in dest folder and optional file list."
    )
    ap.add_argument(
        'source',
        help="Relative path to source directory to copy from."
    )
    ap.add_argument(
        'dest',
        help="Relative path to destination directory to copy into and process."
    )
    ap.add_argument(
        'files',
        nargs='*',
        help="Optional list of YAML file paths (relative to current folder) to copy and process in dest.",
        default=[]
    )
    args = ap.parse_args()

    # Resolve paths
    source_path = Path(args.source).expanduser().resolve()
    dest_path = Path(args.dest).expanduser().resolve()

    # Copy entire source tree into dest (create if needed)
    try:
        shutil.copytree(source_path, dest_path, dirs_exist_ok=True)
        print(f"[INFO] copied source '{source_path}' → dest '{dest_path}'")
    except Exception as e:
        print(f"[ERROR] failed to copy tree: {e}", file=sys.stderr)
        sys.exit(1)

    # Process explicit file list: copy each file to dest and then process
    if args.files:
        file_paths = []
        for p in args.files:
            src_file = Path(p).expanduser().resolve()
            rel = src_file.relative_to(source_path)
            dst_file = dest_path / rel
            dst_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src_file, dst_file)
            print(f"[INFO] copied file '{src_file}' → '{dst_file}'")
            file_paths.append(dst_file)
        _process_many(file_paths)

    # Walk dest directory and process all YAML/YML
    _walk_and_process(dest_path)


if __name__ == "__main__":
    main()
