from __future__ import annotations
####################################################################
'''
python tf2yaml-1.py "dest_dir" "source_dir"
'''
####################################################################
import sys

temp_yaml_conv_path = sys.argv[1] if len(sys.argv) > 1 else "temp"

#!/usr/bin/env python3
"""
Terraform (.tf) → YAML converter – *Notebook‑Optional* Edition v2.0
=================================================================
Key changes compared with v1.4
-----------------------------
1. **Headless / non‑interactive mode**
   * Pass `--auto` (or set env `TFYAML_AUTO=1`) to run the walk without *any*
     prompts. Every matching *.tf* file is converted and **immediately written**
     to disk (and optionally to a Jupyter notebook).

2. **Live console output**
   * HCL and generated YAML for each file are still pretty‑printed to the
     terminal using *Rich* so you can watch the conversion in real time.

3. **Per‑file YAML‑emitter overrides**
   * Supply one or more `--override PATTERN:KEY=VAL` arguments to override
     *ruamel.yaml* emitter settings for files whose *basename* matches
     the glob‑style `PATTERN`.
   * Example – wider line‑width for `variables.tf`, four‑space mapping indents
     everywhere else:

     ```bash
     python tf_yaml_converter_auto.py ./gen3-terraform/tf_files export_yaml \
       --auto --override "variables.tf:width=120" \
       --override "*:indent_mapping=4"
     ```

4. **CLI based on argparse** – clearer, safer, script‑friendly.

Tested on Python 3.9+, nbformat 5.9+, rich 13+, python‑hcl2, ruamel.yaml.
"""
import argparse
import importlib
import json
import os
import pathlib
from contextlib import suppress
from dataclasses import dataclass, field, replace
from datetime import datetime
from fnmatch import fnmatch
from typing import Any, Callable, Dict, Mapping, MutableMapping, Sequence, Tuple

import hcl2  # type: ignore
import nbformat as nbf
from rich.console import Console
from rich.syntax import Syntax
from ruamel.yaml import YAML, safe_load as yaml_load

console = Console()
os.makedirs(temp_yaml_conv_path, exist_ok=True)
# ---------------------------------------------------------------------------
# YAML‑emitter configuration dataclass
# ---------------------------------------------------------------------------

@dataclass
class YAMLCfg:
    indent_mapping: int = 2
    indent_sequence: int = 2
    indent_offset: int = 2
    width: int = 100_000
    allow_unicode: bool = True
    explicit_start: bool = True
    explicit_end: bool = False
    preserve_quotes: bool = True
    default_flow_style: bool = False
    sort_keys: bool = False

    def make(self) -> YAML:
        y = YAML()
        y.indent(self.indent_mapping, self.indent_sequence, self.indent_offset)
        y.width = self.width
        y.allow_unicode = self.allow_unicode
        y.explicit_start = self.explicit_start
        y.explicit_end = self.explicit_end
        y.preserve_quotes = self.preserve_quotes
        y.default_flow_style = self.default_flow_style
        with suppress(AttributeError):
            y.sort_base_mapping_type_on_output = self.sort_keys  # type: ignore[attr-defined]
        return y

# ---------------------------------------------------------------------------
# Session configuration
# ---------------------------------------------------------------------------

FilterFn = Callable[[MutableMapping[str, Any]], None]
PostProcFn = Callable[[str], str]


def _nop_filter(_: MutableMapping[str, Any]) -> None:  # placeholder
    return None


def _nop_postproc(txt: str) -> str:  # default
    return txt


@dataclass
class SessionCfg:
    yaml_cfg: YAMLCfg = field(default_factory=YAMLCfg)
    encoding: str = "utf-8"

    include_globs: Sequence[str] = ("*.tf",)
    exclude_globs: Sequence[str] = ()

    # Notebook
    notebook_path: pathlib.Path = pathlib.Path("converted_tf.ipynb")
    write_notebook: bool = True
    overwrite_nb: bool = True

    # Disk
    export_root: pathlib.Path = pathlib.Path("temp")
    overwrite_files: bool = True
    backup: bool = True

    # Runtime
    auto: bool = True
    enable_console: bool = False

    # Overrides
    overrides: list[Tuple[str, Dict[str, str]]] = field(default_factory=list)  # (glob, {k:v})
    perfile_cfg: Dict[str, Dict[str, Any]] = field(default_factory=dict)       # rel → {k:v, postproc:name}

    # Filters / post-processors
    filters: Dict[str, FilterFn] = field(default_factory=lambda: {"drop_backend": _nop_filter})
    postprocs: Dict[str, PostProcFn] = field(default_factory=lambda: {"noop": _nop_postproc})

# ---------------------------------------------------------------------------
# Misc helpers
# ---------------------------------------------------------------------------

def _cast(cur_val: Any, new_val: str) -> Any:
    if isinstance(cur_val, bool):
        return new_val.lower() in {"1", "true", "yes", "y"}
    if isinstance(cur_val, int):
        return int(new_val)
    return new_val


def _apply_updates(cfg: YAMLCfg, upd: Dict[str, Any]) -> YAMLCfg:
    valid = {k: _cast(getattr(cfg, k), str(v)) for k, v in upd.items() if hasattr(cfg, k)}
    return replace(cfg, **valid)

# ---------------------------------------------------------------------------
# Notebook helpers
# ---------------------------------------------------------------------------

def _ensure_nb(sess: SessionCfg) -> nbf.NotebookNode:
    if not sess.write_notebook:
        return nbf.v4.new_notebook()
    if sess.notebook_path.exists() and not sess.overwrite_nb:
        return nbf.read(sess.notebook_path, as_version=4)
    nb = nbf.v4.new_notebook()
    nb.cells.append(nbf.v4.new_markdown_cell("## Converted Terraform files"))
    return nb


def _save_nb(nb: nbf.NotebookNode, sess: SessionCfg) -> None:
    if sess.write_notebook:
        nbf.write(nb, sess.notebook_path)

# ---------------------------------------------------------------------------
# HCL ↦ YAML helpers
# ---------------------------------------------------------------------------

def load_hcl(p: pathlib.Path, enc: str) -> str:
    return p.read_text(encoding=enc)


def parse_hcl(txt: str) -> Dict[str, Any]:
    return hcl2.loads(txt)


def to_yaml(obj: Mapping[str, Any], cfg: YAMLCfg) -> str:
    from io import StringIO
    buf = StringIO()
    cfg.make().dump(obj, buf)
    return buf.getvalue()

# Built‑in filter example

def drop_backend(obj: MutableMapping[str, Any]) -> None:
    if "terraform" in obj:
        tf = obj["terraform"]
        if isinstance(tf, list):
            tf[:] = [b for b in tf if not b.get("backend")]
        elif isinstance(tf, dict):
            tf.pop("backend", None)

# ---------------------------------------------------------------------------
# Config selection for each file
# ---------------------------------------------------------------------------

def _pick_cfg(rel: str, tf_path: pathlib.Path, sess: SessionCfg) -> Tuple[YAMLCfg, PostProcFn]:
    # 1. explicit per‑file mapping
    if rel in sess.perfile_cfg:
        meta = sess.perfile_cfg[rel].copy()
        post_name = meta.pop("postproc", "noop")
        return _apply_updates(sess.yaml_cfg, meta), sess.postprocs.get(post_name, _nop_postproc)
    # 2. first matching glob override
    cfg = sess.yaml_cfg
    for pat, upd in sess.overrides:
        if fnmatch(tf_path.name, pat):
            cfg = _apply_updates(cfg, upd)
            break
    return cfg, _nop_postproc

# ---------------------------------------------------------------------------
# File writer
# ---------------------------------------------------------------------------

def _write_yaml(sess: SessionCfg, root: pathlib.Path, tf_path: pathlib.Path, text: str) -> None:
    out_path = sess.export_root / tf_path.relative_to(root).with_suffix(".yaml")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if out_path.exists() and not sess.overwrite_files and sess.backup:
        ts = datetime.now().strftime("%Y%m%d%H%M%S")
        out_path.rename(out_path.with_suffix(out_path.suffix + f".{ts}.bak"))
    out_path.write_text(text, encoding=sess.encoding)
    
    if sess.enable_console:
        console.print(f"[green]✓[/] {out_path}")

# ---------------------------------------------------------------------------
# Core walk logic
# ---------------------------------------------------------------------------

def walk(start: os.PathLike | str, sess: SessionCfg) -> None:
    root = pathlib.Path(start).expanduser().resolve()
    if sess.enable_console:
        console.rule(f"[bright_cyan]Walking {root}")

    files = [p for p in root.rglob("*")
             if p.is_file() and any(p.match(g) for g in sess.include_globs)
             and not any(p.match(g) for g in sess.exclude_globs)]
    if not files:
        if sess.enable_console:
            console.print("[yellow]No *.tf files found")
        return

    nb = _ensure_nb(sess)
    if sess.write_notebook:
        toc = nb.cells[0]

    for tf in sorted(files):
        rel = str(tf.relative_to(root))
        if sess.enable_console:
            console.rule(rel)
            console.print(Syntax(load_hcl(tf, sess.encoding), "hcl", line_numbers=True))
        try:
            obj = parse_hcl(load_hcl(tf, sess.encoding))
        except Exception as exc:
            if sess.enable_console:
                console.print(f"[red]Parse error:[/] {exc}")
            continue

        for fn in sess.filters.values():
            fn(obj)

        cfg, post = _pick_cfg(rel, tf, sess)
        yaml_txt = post(to_yaml(obj, cfg))
        if sess.enable_console:
            console.print(Syntax(yaml_txt, "yaml", line_numbers=True))

        if sess.auto:
            _write_yaml(sess, root, tf, yaml_txt)
            if sess.write_notebook:
                toc.source += f"\n* `{rel}`"
                nb.cells.append(nbf.v4.new_markdown_cell(f"### {tf.name}"))
                nb.cells.append(nbf.v4.new_code_cell(f"yaml_text = '''\n{yaml_txt}'''"))
        else:
            from rich.prompt import Prompt
            choice = Prompt.ask("[y] write | [s] skip | [q] quit", choices=["y", "s", "q"], default="y")
            if choice == "q":
                break
            if choice == "s":
                continue
            _write_yaml(sess, root, tf, yaml_txt)
            if sess.write_notebook:
                toc.source += f"\n* `{rel}`"
                nb.cells.append(nbf.v4.new_markdown_cell(f"### {tf.name}"))
                nb.cells.append(nbf.v4.new_code_cell(f"yaml_text = '''\n{yaml_txt}'''"))

    _save_nb(nb, sess)

# ---------------------------------------------------------------------------
# CLI helpers
# ---------------------------------------------------------------------------

def _parse_override(val: str) -> Tuple[str, Dict[str, str]]:
    if ":" not in val:
        raise argparse.ArgumentTypeError("override must be PATTERN:key=val[,k=v]")
    pat, rest = val.split(":", 1)
    kv: Dict[str, str] = {}
    for item in rest.split(","):
        if "=" not in item:
            raise argparse.ArgumentTypeError("each override needs key=val")
        k, v = item.split("=", 1)
        kv[k.strip()] = v.strip()
    return pat, kv


def _load_cfg_file(fp: str | None) -> Dict[str, Dict[str, Any]]:
    if not fp:
        return {}
    p = pathlib.Path(fp).expanduser().resolve()
    if not p.exists():
        raise FileNotFoundError(p)
    if p.suffix.lower() in {".yml", ".yaml"}:
        yaml = YAML(typ="safe")
        data = yaml.load(p.read_text())  # type: ignore[arg-type]
    elif p.suffix.lower() == ".json":
        data = json.loads(p.read_text())
    else:
        raise ValueError("cfg-file must be .yaml/.yml or .json")
    if not isinstance(data, dict):
        raise ValueError("cfg-file root must be a mapping")
    return {str(k): v for k, v in data.items() if isinstance(v, dict)}


def _load_postproc(spec: str) -> Tuple[str, PostProcFn]:
    if "=" not in spec or ":" not in spec:
        raise argparse.ArgumentTypeError("add-postproc must be NAME=module:func")
    name, ref = spec.split("=", 1)
    mod_name, func_name = ref.split(":", 1)
    mod = importlib.import_module(mod_name)
    func = getattr(mod, func_name)
    if not callable(func):
        raise ValueError(f"Postproc {func_name} in {mod_name} is not callable")
    return name.strip(), func  # type: ignore[return-value]

# ---------------------------------------------------------------------------
# Entry-point
# ---------------------------------------------------------------------------

def main() -> None:
    """
    Parse CLI flags, build a SessionCfg, then run `walk()`.
    Executable without arguments – defaults to:
        start_path   = current working directory (“.”)
        export_root  = ./export_yaml
    """

    ap = argparse.ArgumentParser(
        prog="tf2yaml1",
        description="Recursively convert *.tf → YAML (with per-file tweaks)."
    )


    # ──Positional── where to start the walk ──────────────────────
    ap.add_argument(
        "start_path",
        nargs="?", 
        default="gen3-terraform/tf_files",
        help="Root directory to search for *.tf files (default: current directory)"
    )

    # ──Positional── Where to write the converted YAML tree ───────────────────
    ap.add_argument(
        "export_root",
        default=temp_yaml_conv_path,
        nargs="?",
        metavar="DIR",
        help="Destination folder for the YAML tree (default: %(default)s)"
    )
    
    # ── Per-file config map ──────────────────────────────────────
    ap.add_argument(
        "--cfg-file",
        default="",
        metavar="",
        help="YAML/JSON map: RELATIVE_TF_PATH → { emitter overrides, postproc }"
    )

    # ── Glob-level emitter overrides ─────────────────────────────
    ap.add_argument(
        "--override",
        action="append",
        default=[],
        metavar="PATTERN:key=val[,k=v]",
        help="Glob-pattern emitter overrides (may be repeated)"
    )

    # ── Custom post-processors (dynamic import) ──────────────────
    ap.add_argument(
        "--add-postproc",
        action="append",
        default=[],
        metavar="NAME=module:function",
        help="Register a callable and expose it as NAME for per-file use"
    )

    # ── Runtime behaviour flags ──────────────────────────────────
    ap.add_argument("--auto",        action="store_true", help="Run headless (no prompts)")
    ap.add_argument("--overwrite",   action="store_true", help="Overwrite existing YAML files")
    ap.add_argument("--disable-notebook", "--no-notebook",
                    dest="no_notebook", action="store_true",
                    help="Do not generate a Jupyter notebook summary")

    # ── Include / exclude patterns ───────────────────────────────
    ap.add_argument("--include", action="append", metavar="GLOB",
                    help="Additional include globs for *.tf discovery")
    ap.add_argument("--exclude", action="append", metavar="GLOB",
                    help="Exclude globs")

    args = ap.parse_args()

    # ── Build the SessionCfg ─────────────────────────────────────
    sess = SessionCfg(
        export_root=pathlib.Path(args.export_root).expanduser().resolve(),
        overwrite_files=args.overwrite,
        write_notebook=not args.no_notebook,
        auto=args.auto,
    )

    # Include / exclude lists
    if args.include:
        sess.include_globs = tuple(args.include)
    if args.exclude:
        sess.exclude_globs = tuple(args.exclude)

    # Register built-in (or user-removed) filters
    sess.filters["drop_backend"] = drop_backend

    # Per-file config map (highest priority)
    sess.perfile_cfg = _load_cfg_file(args.cfg_file)

    # Glob-level emitter overrides
    sess.overrides = [_parse_override(o) for o in (args.override or [])]

    # Custom post-processors
    for spec in args.add_postproc or []:
        name, fn = _load_postproc(spec)
        sess.postprocs[name] = fn

    # ── Go! ───────────────────────────────────────────────────────
    walk(args.start_path, sess)


if __name__ == "__main__":
    main()




