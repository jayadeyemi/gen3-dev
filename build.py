#!/usr/bin/env python3
from pathlib import Path
import os

# Base directories
scripts_dir = "scripts"
base_dir = os.path.abspath("aws")
# remove base_dir from path to avoid conflicts with the build script
if base_dir in os.sys.path:
    os.sys.path.remove(base_dir)

# Override stubs containers
chart_overrides = {}
values_overrides = {}
template_overrides = {}
helper_overrides = {}
description_overrides = {}
readme_overrides = {}
notes_overrides = {}

# List of controllers\
controllers = [
    'acks',
    'network',
]

# Helper functions
def add_chart_stub(overrides: dict, controller: str, stub: str):
    """
    Add or overwrite the Chart.yaml stub for `controller`.
    """
    action = "Overriding" if controller in overrides else "Adding"
    print(f"{action} Chart stub for '{controller}'")
    overrides[controller] = stub


def add_values_stub(overrides: dict, controller: str, stub: str):
    """
    Add or overwrite the values.yaml stub for `controller`.
    """
    action = "Overriding" if controller in overrides else "Adding"
    print(f"{action} values stub for '{controller}'")
    overrides[controller] = stub

def add_description_stub(overrides: dict, controller: str, stub: str):
    """
    Add or overwrite the description for `controller`.
    """
    action = "Overriding" if controller in overrides else "Adding"
    print(f"{action} description for '{controller}'")
    overrides[controller] = stub

def add_helper_stub(overrides: dict, controller: str, filename: str, stub: str):
    """
    Add or overwrite the helper stub for `controller`.
    """
    if controller not in overrides:
        overrides[controller] = {}
    action = "Overriding" if filename in overrides[controller] else "Adding"
    print(f"{action} helper stub for '{controller}/{filename}'")
    overrides[controller][filename] = stub

def add_template_stub(templates: dict, controller: str, filename: str, stub: str):
    """
    Add or overwrite the template stub `filename` under `controller`.
    """
    if controller not in templates:
        templates[controller] = {}
    action = "Overriding" if filename in templates[controller] else "Adding"
    print(f"{action} template stub for '{controller}/{filename}'")
    templates[controller][filename] = stub

def add_readme_stub(overrides: dict, controller: str, stub: str):
    """
    Add or overwrite the README stub for `controller`.
    """
    action = "Overriding" if controller in overrides else "Adding"
    print(f"{action} values stub for '{controller}'")
    overrides[controller] = stub

def add_notes_stub(overrides: dict, controller: str, filename: str, stub: str):
    """
    Add or overwrite the NOTES.txt stub for `controller`.
    """
    if controller not in overrides:
        overrides[controller] = {}
    action = "Overriding" if filename in overrides[controller] else "Adding"
    print(f"{action} NOTES.txt stub for '{controller}/{filename}'")
    overrides[controller][filename] = stub

# Shared namespace for executing per-controller scripts
shared_ns = {
    "__name__": "__main__",
    "chart_overrides": {},
    "values_overrides": {},
    "template_overrides": {},
    "description_overrides": {},
    "helper_overrides": {},
    "readme_overrides": {},
    "notes_overrides": {},
    "add_chart_stub": add_chart_stub,
    "add_values_stub": add_values_stub,
    "add_template_stub": add_template_stub,
    "add_description_stub": add_description_stub,
    "add_helper_stub": add_helper_stub,
    "add_readme_stub": add_readme_stub,
    "add_notes_stub": add_notes_stub
}

# Load and execute each build script into shared_ns
build_dir = Path(scripts_dir) / "build"
script_paths = [build_dir / f"{controller}.py" for controller in controllers]

for script in sorted(script_paths, key=lambda p: p.name):
    code = compile(script.read_text(encoding="utf-8"), str(script), "exec")
    exec(code, shared_ns)


# Merge shared results into top-level overrides and descriptions
chart_overrides.update(shared_ns["chart_overrides"])
values_overrides.update(shared_ns["values_overrides"])
template_overrides.update(shared_ns["template_overrides"])
description_overrides.update(shared_ns["description_overrides"])
helper_overrides.update(shared_ns["helper_overrides"])
readme_overrides.update(shared_ns["readme_overrides"])
notes_overrides.update(shared_ns["notes_overrides"])

# 2) Populate subcharts with Chart.yaml, values.yaml, and templates
def populate_subcharts(chart_defs, values_defs, template_files, helper_files,
                       readme_files, notes_files, names, base):
    for name in names:
        chart_dir = Path(base) / name
        if not chart_dir.exists():
            os.makedirs(chart_dir, exist_ok=True)

        # Chart.yaml
        chart_content = chart_defs.get(name)
        if chart_content:
            (chart_dir / "Chart.yaml").write_text(chart_content.lstrip() + "\n", encoding="utf-8")
            print(f"✏️  Wrote Chart.yaml for {name}")
        else:
            # Fallback stub
            default_desc = description_overrides.get(name, "No description available.")
            fallback = f"apiVersion: v2\nname: {name}\ndescription: {default_desc}\ntype: application\nversion: 0.1.0\nappVersion: \"latest\"\n"
            add_chart_stub(chart_overrides, name, fallback)
            (chart_dir / "Chart.yaml").write_text(fallback, encoding="utf-8")
            print(f"✏️  Wrote fallback Chart.yaml for {name}")

        # values.yaml
        vals = values_defs.get(name)
        if not vals:
            vals = f"# default values for {name}\nenabled: false\n# TODO: fill in specific settings\n"
            add_values_stub(values_overrides, name, vals)
        (chart_dir / "values.yaml").write_text(vals.lstrip() + "\n", encoding="utf-8")
        print(f"✏️  Wrote values.yaml for {name}")
        
        # README.md
        readme = readme_files.get(name)
        if readme:
            (chart_dir / "README.md").write_text(readme.lstrip() + "\n", encoding="utf-8")
            

        # templates
        templates = template_files.get(name, {})
  
        tpl_dir = chart_dir / "templates"
        for fname, content in templates.items():
            os.makedirs(os.path.join(chart_dir, "templates"), exist_ok=True)
            (tpl_dir / fname).write_text(content.lstrip() + "\n", encoding="utf-8")
            print(f"✏️  Wrote templates/{fname} for {name}")

        # helpers
        helpers = helper_files.get(name, {})
        for fname, content in helpers.items():
            os.makedirs(os.path.join(chart_dir, "templates"), exist_ok=True)
            (tpl_dir / fname).write_text(content.lstrip() + "\n", encoding="utf-8")
            print(f"✏️  Wrote templates/{fname} for {name}")

        # NOTES.txt
        notes = notes_files.get(name, {})
        for fname, content in notes.items():
            os.makedirs(os.path.join(chart_dir, "templates"), exist_ok=True)
            (tpl_dir / fname).write_text(content.lstrip() + "\n", encoding="utf-8")
            print(f"✏️  Wrote templates/{fname} for {name}")

        



# Execute bootstrapping and populationootstrap_subcharts(controllers, base_dir)
populate_subcharts(chart_overrides, values_overrides, template_overrides, helper_overrides,
    readme_overrides, notes_overrides, controllers, base_dir)
