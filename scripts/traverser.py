
####################################################################
'''
python traverser-2.py "temp" "export_yaml"
'''
#####################################################################
import sys, os
import shutil
import re
import yaml



source = sys.argv[1] if len(sys.argv) > 1 else "temp"
yaml_exec_tree = sys.argv[2] if len(sys.argv) > 2 else "helm"
yaml_exec_source= os.path.join(source,"tf_files/aws/commons")



# Enable debug output
DEBUG = 0  # Set to True to enable debug output

# Toggle debug output
def debug_print(*args, **kwargs):
    """Helper to print debug messages when DEBUG is enabled."""
    if DEBUG:
        print(*args, **kwargs)


def strip_parent_refs(path: str) -> str:
    """
    Remove all occurrences of '../' or '..\\' segments from a file path string.
    """
    result = re.sub(r'\.{2}[\\/]+', '', path)
    return result


def find_sources(node):
    """
    Iteratively search for all 'source' keys in the loaded YAML structure.
    """
    sources = []
    stack = [node]
    while stack:
        current = stack.pop()
        if isinstance(current, dict):
            for k, v in current.items():
                if k == 'source':
                    # debug_print(f"DEBUG: Found 'source' key with value: {v}")
                    sources.append(v)
                elif isinstance(v, (dict, list)):
                    stack.append(v)
        elif isinstance(current, list):
            for item in current:
                if isinstance(item, (dict, list)):
                    stack.append(item)
    return sources


def traverse_path(destination_path, current_path, path, source_list, destination_list):
    # debug_print(f"DEBUG: traverse_path called with destination_path={destination_path}, path={path}")
    if not path or destination_path is None:
        # debug_print("DEBUG: Invalid path or destination_path is None; returning")
        return None
    
    root = os.path.join(current_path, path)
    new_path = strip_parent_refs(path)

    destination_path = os.path.join(destination_path, new_path)
    # print(f"DEBUG: Current working directory: {root}")
    if not os.path.exists(root):
        # debug_print(f"DEBUG: Path does not exist (path={os.path.join(root, path)} returning")
        return None
    
    for file in os.listdir(root):
        file_path = os.path.join(root, file)
        os.makedirs(destination_path, exist_ok=True)
        shutil.copy2(file_path, destination_path)

        if not file.endswith(('.yaml', '.yml')):
            continue
        source_list.append(root)
        destination_list.append(destination_path)


        # debug_print(f"DEBUG: Processing file during traverse: {file_path}")
        
        with open(file_path, 'r') as f:
            try:
                data = yaml.safe_load(f)
            except yaml.YAMLError as e:
                # debug_print(f"DEBUG: YAML parse error in")
                print(f"ERROR: YAML parse error in {file_path}: {e}")
                break

        # print(f"DEBUG: 2Destination path: {destination_path}")
        found = find_sources(data)
        for val in found:
            if isinstance(val, list):
                continue
            # debug_print(f"DEBUG: Found nested source to traverse: {full_source}")
            if os.path.exists(os.path.join(root, val)):
                traverse_path(destination_path, root, val, source_list, destination_list)
            else:
                return None
    return None


def main(start_path, destination_path):
    start_path = os.path.abspath(start_path)
    destination_path = os.path.abspath(destination_path)
    # debug_print(f"DEBUG: Starting main with start_path={start_path}, destination_path={destination_path}")

    source_list = []
    destination_list = []
    
    os.makedirs(destination_path, exist_ok=True)
    # debug_print(f"DEBUG: Ensured destination_root exists: {destination_path}")

    for root_file in os.listdir(start_path):
        # debug_print(f"DEBUG: Checking file: {root_file}")
        if not root_file.endswith(('.yaml', '.yml')):
            # debug_print(f"DEBUG: Skipping non-YAML file: {root_file}")
            continue
        base_name = os.path.splitext(root_file)[0]
        
        if base_name.endswith('.tf'):
            base_name = base_name[:-3]
        # debug_print(f"DEBUG: Derived base_name: {base_name}")

        dest_subfolder = os.path.join(destination_path, base_name)
        if base_name not in ['locals', 'output', 'resource', 'terraform', 'variable']:
            os.makedirs(dest_subfolder, exist_ok=True)
        # debug_print(f"DEBUG: Created dest_subfolder: {dest_subfolder}")

        src_file = os.path.join(start_path, root_file)
        # debug_print(f"DEBUG: Copying root file {src_file} to {destination_path}")
        shutil.copy2(src_file, destination_path)
        source_list.append(start_path)
        destination_list.append(dest_subfolder)

        try:
            with open(src_file, 'r') as f:
                data = yaml.safe_load(f)
                # debug_print(f"DEBUG: Loaded YAML data for root_file: {data}")
        except yaml.YAMLError as e:
            # debug_print(f"DEBUG: YAML parse error in {src_file}: {e}")
            continue

        found = find_sources(data)
        # debug_print(f"DEBUG: Sources found in {root_file}: {found}")

        for val in found:
            if isinstance(val, list):
                continue
            source_path = os.path.join(start_path, val)
            # debug_print(f"DEBUG: Handling source value: {source_path}")

            # shutil.copy2(source_path, dest_subfolder)

            traverse_path(dest_subfolder, start_path, val, source_list, destination_list)

    # # Final reporting
    # debug_print("DEBUG: Final source_list and destination_list:")

main(yaml_exec_source, yaml_exec_tree)

