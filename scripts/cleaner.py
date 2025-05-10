#!/usr/bin/env python3

import os
import shutil
import argparse
import stat
import sys

def on_rm_error(func, path, exc_info):
    """
    Error handler for shutil.rmtree.
    If the removal fails due to read-only file, make it writable and retry.
    """
    # Is the error an access error?
    if not os.access(path, os.W_OK):
        # Make the file writable
        os.chmod(path, stat.S_IWRITE)
        # Retry the removal
        func(path)
    else:
        # Re-raise the exception if it's not a permission issue
        raise

def delete_paths(paths):
    """
    For each relative path in `paths`, resolve to absolute,
    then remove the file or directory (including read-only) if it exists.
    """
    for rel in paths:
        abs_path = os.path.abspath(rel)
        if os.path.isfile(abs_path):
            try:
                os.chmod(abs_path, stat.S_IWRITE)
                os.remove(abs_path)
                print(f"Deleted file: {rel}")
            except Exception as e:
                print(f"[Error deleting file {rel}]: {e}", file=sys.stderr)
        elif os.path.isdir(abs_path):
            try:
                # rmtree with onerror to handle read-only files
                shutil.rmtree(abs_path, onerror=on_rm_error)
                print(f"Deleted directory: {rel}")
            except Exception as e:
                print(f"[Error deleting directory {rel}]: {e}", file=sys.stderr)
        else:
            print(f"[Not found] {rel}")

def main():
    parser = argparse.ArgumentParser(
        description="Delete files or directories by relative path (force-removes read-only)"
    )
    parser.add_argument(
        'paths',
        nargs='+',
        help='One or more relative file or directory paths to delete'
    )
    args = parser.parse_args()
    delete_paths(args.paths)

if __name__ == "__main__":
    main()
