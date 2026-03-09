#!/usr/bin/env python3
"""
Generate per-control Ruby classes from local Flet Python sources.

Output:
- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/shared/<type>_control.rb
- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/material/<type>_control.rb
- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/cupertino/<type>_control.rb
- packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/ruflet_controls.rb
- packages/ruflet/lib/ruflet_ui/ruflet/ui/services/ruflet/<type>_control.rb
- packages/ruflet/lib/ruflet_ui/ruflet/ui/services/ruflet_services.rb
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

OUT_SHARED_DIR = Path("packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/shared")
OUT_MATERIAL_DIR = Path("packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/materials")
OUT_CUPERTINO_DIR = Path("packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/cupertinos")
LEGACY_OUT_CONTROLS_DIR = Path("packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/ruflet")
OUT_SERVICES_DIR = Path("packages/ruflet/lib/ruflet_ui/ruflet/ui/services/ruflet")
CONTROLS_INDEX_FILE = Path("packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/ruflet_controls.rb")
SHARED_CONTROLS_INDEX_FILE = Path("packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/shared/ruflet_controls.rb")
MATERIAL_CONTROLS_INDEX_FILE = Path("packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/materials/ruflet_controls.rb")
CUPERTINO_CONTROLS_INDEX_FILE = Path("packages/ruflet/lib/ruflet_ui/ruflet/ui/controls/cupertinos/ruflet_controls.rb")
SERVICES_INDEX_FILE = Path("packages/ruflet/lib/ruflet_ui/ruflet/ui/services/ruflet_services.rb")

SERVICE_WIRES = {
    "Accelerometer",
    "Barometer",
    "Battery",
    "Camera",
    "Clipboard",
    "Connectivity",
    "FilePicker",
    "Gyroscope",
    "HapticFeedback",
    "Magnetometer",
    "ScreenBrightness",
    "Screenshot",
    "SemanticsService",
    "ShakeDetector",
    "Share",
    "SharedPreferences",
    "StoragePaths",
    "UrlLauncher",
    "UserAccelerometer",
    "Wakelock",
}


def snake_from_camel(name: str) -> str:
    s1 = re.sub(r"(.)([A-Z][a-z]+)", r"\1_\2", name)
    return re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s1).lower()


def compact(name: str) -> str:
    return name.replace("_", "").lower()


def class_name_for_wire(wire: str) -> str:
    parts = re.split(r"[^A-Za-z0-9]+", wire)
    if len(parts) == 1 and parts[0]:
        parts = re.findall(r"[A-Z]+(?=[A-Z][a-z]|$)|[A-Z]?[a-z]+|\d+", parts[0]) or [parts[0]]
    cname = "".join(p[:1].upper() + p[1:] for p in parts if p)
    return f"{cname}Control"


def ruby_array(items: list[str]) -> str:
    return "[" + ", ".join(f'\"{v}\"' for v in items) + "]"


def class_file_lines(
    class_name: str,
    canonical_type: str,
    wire: str,
    props: list[str],
    events: list[str],
    *,
    category: str,
) -> list[str]:
    lines = []
    lines.append("# frozen_string_literal: true")
    lines.append("")
    lines.append("module Ruflet")
    lines.append("  module UI")
    if category == "service":
        lines.append("    module Services")
        lines.append("      module RufletServicesComponents")
    else:
        lines.append("    module Controls")
        lines.append("      module RufletComponents")
    lines.append(f"        class {class_name} < Ruflet::Control")
    lines.append(f'          TYPE = "{canonical_type}".freeze')
    lines.append(f'          WIRE = "{wire}".freeze')
    lines.append("")
    signature = ", ".join(["id: nil"] + [f"{p}: nil" for p in props] + [f"on_{e}: nil" for e in events])
    lines.append(f"          def initialize({signature})")
    lines.append("            props = {}")
    for prop in props:
        lines.append(f"            props[:{prop}] = {prop} unless {prop}.nil?")
    for event in events:
        lines.append(f"            props[:on_{event}] = on_{event} unless on_{event}.nil?")
    lines.append("            super(type: TYPE, id: id, **props)")
    lines.append("          end")
    lines.append("        end")
    lines.append("      end")
    lines.append("    end")
    lines.append("  end")
    lines.append("end")
    lines.append("")
    return lines


def build_index_file(
    index_file: Path,
    namespace_parts: list[str],
    component_module: str,
    require_prefix: str,
    index_requires: list[str],
    map_entries: list[tuple[str, str]],
) -> None:
    lines = []
    lines.append("# frozen_string_literal: true")
    lines.append("")
    for req in sorted(set(index_requires)):
        if require_prefix:
            lines.append(f'require_relative "{require_prefix}/{req}"')
        else:
            lines.append(f'require_relative "{req}"')
    lines.append("")
    lines.append("module Ruflet")
    lines.append("  module UI")
    indent = "    "
    for part in namespace_parts:
        lines.append(f"{indent}module {part}")
        indent += "  "
    lines.append(f"{indent}module_function")
    lines.append("")
    lines.append(f"{indent}CLASS_MAP = {{")
    for key, class_name in sorted(map_entries):
        lines.append(f'{indent}  "{key}" => {component_module}::{class_name},')
    lines.append(f"{indent}}}.freeze")
    for _ in namespace_parts:
        indent = indent[:-2]
        lines.append(f"{indent}end")
    lines.append("  end")
    lines.append("end")
    lines.append("")
    index_file.write_text("\n".join(lines), encoding="utf-8")


def build():
    sys.path.insert(0, str(Path(__file__).parent))
    from generate_control_schema import build_schema  # noqa: PLC0415

    schema = build_schema()
    entries = [
        (key, value["wire"], list(value["props"]), list(value["events"]), value.get("family", "shared"))
        for key, value in schema.items()
    ]

    by_wire = {}
    for key, wire, props, events, family in entries:
        row = by_wire.setdefault(wire, {"keys": set(), "props": set(), "events": set(), "family": family})
        row["keys"].add(key)
        row["props"].update(props)
        row["events"].update(e[3:] if e.startswith("on_") else e for e in events)
        if row["family"] == "shared" and family in ("material", "cupertino"):
            row["family"] = family

    OUT_SHARED_DIR.mkdir(parents=True, exist_ok=True)
    OUT_MATERIAL_DIR.mkdir(parents=True, exist_ok=True)
    OUT_CUPERTINO_DIR.mkdir(parents=True, exist_ok=True)
    OUT_SERVICES_DIR.mkdir(parents=True, exist_ok=True)
    SHARED_CONTROLS_INDEX_FILE.parent.mkdir(parents=True, exist_ok=True)
    MATERIAL_CONTROLS_INDEX_FILE.parent.mkdir(parents=True, exist_ok=True)
    CUPERTINO_CONTROLS_INDEX_FILE.parent.mkdir(parents=True, exist_ok=True)

    controls_requires: list[str] = []
    controls_map_entries: list[tuple[str, str]] = []
    shared_expected_files: set[str] = set()
    material_expected_files: set[str] = set()
    cupertino_expected_files: set[str] = set()
    shared_controls_map_entries: list[tuple[str, str]] = []
    material_controls_map_entries: list[tuple[str, str]] = []
    cupertino_controls_map_entries: list[tuple[str, str]] = []

    services_requires: list[str] = []
    services_map_entries: list[tuple[str, str]] = []
    services_expected_files: set[str] = set()

    for wire in sorted(by_wire.keys()):
        row = by_wire[wire]
        keys = sorted(row["keys"])
        props = sorted(p for p in row["props"] if p and not p.startswith("_"))
        events = sorted(e for e in row["events"] if e)
        family = row.get("family", "shared")

        snake = snake_from_camel(wire)
        compact_wire = compact(wire)
        canonical_type = compact_wire if compact_wire in row["keys"] else (snake if snake in row["keys"] else keys[0])

        class_name = class_name_for_wire(wire)
        file_name = f"{canonical_type}_control.rb"
        is_service = wire in SERVICE_WIRES
        if is_service:
            out_dir = OUT_SERVICES_DIR
            require_prefix = "ruflet"
        elif family == "material":
            out_dir = OUT_MATERIAL_DIR
            require_prefix = "materials"
        elif family == "cupertino":
            out_dir = OUT_CUPERTINO_DIR
            require_prefix = "cupertinos"
        else:
            out_dir = OUT_SHARED_DIR
            require_prefix = "shared"
        category = "service" if is_service else "control"

        if is_service:
            services_expected_files.add(file_name)
        else:
            if family == "material":
                material_expected_files.add(file_name)
            elif family == "cupertino":
                cupertino_expected_files.add(file_name)
            else:
                shared_expected_files.add(file_name)

        (out_dir / file_name).write_text(
            "\n".join(class_file_lines(class_name, canonical_type, wire, props, events, category=category)),
            encoding="utf-8",
        )

        if is_service:
            services_requires.append(file_name[:-3])
        else:
            controls_requires.append(f"{require_prefix}/{file_name[:-3]}")

        for key in keys:
            if is_service:
                services_map_entries.append((key, class_name))
            else:
                controls_map_entries.append((key, class_name))
                if family == "material":
                    material_controls_map_entries.append((key, class_name))
                elif family == "cupertino":
                    cupertino_controls_map_entries.append((key, class_name))
                else:
                    shared_controls_map_entries.append((key, class_name))

    for existing in OUT_SHARED_DIR.glob("*.rb"):
        if existing.name not in shared_expected_files or existing.name == "ruflet_controls.rb":
            existing.unlink()
    for existing in OUT_MATERIAL_DIR.glob("*.rb"):
        if existing.name not in material_expected_files or existing.name == "ruflet_controls.rb":
            existing.unlink()
    for existing in OUT_CUPERTINO_DIR.glob("*.rb"):
        if existing.name not in cupertino_expected_files or existing.name == "ruflet_controls.rb":
            existing.unlink()
    for existing in OUT_SERVICES_DIR.glob("*.rb"):
        if existing.name not in services_expected_files:
            existing.unlink()
    for existing in LEGACY_OUT_CONTROLS_DIR.glob("*.rb"):
        existing.unlink()

    build_index_file(
        CONTROLS_INDEX_FILE,
        ["Controls", "RufletControls"],
        "RufletComponents",
        "",
        controls_requires,
        controls_map_entries,
    )
    build_index_file(
        SHARED_CONTROLS_INDEX_FILE,
        ["Controls", "Shared", "RufletControls"],
        "RufletComponents",
        "",
        [f[:-3] for f in sorted(shared_expected_files)],
        shared_controls_map_entries,
    )
    build_index_file(
        MATERIAL_CONTROLS_INDEX_FILE,
        ["Controls", "Materials", "RufletControls"],
        "RufletComponents",
        "",
        [f[:-3] for f in sorted(material_expected_files)],
        material_controls_map_entries,
    )
    build_index_file(
        CUPERTINO_CONTROLS_INDEX_FILE,
        ["Controls", "Cupertinos", "RufletControls"],
        "RufletComponents",
        "",
        [f[:-3] for f in sorted(cupertino_expected_files)],
        cupertino_controls_map_entries,
    )
    build_index_file(
        SERVICES_INDEX_FILE,
        ["Services", "RufletServices"],
        "RufletServicesComponents",
        "ruflet",
        services_requires,
        services_map_entries,
    )
    print(
        f"Wrote {CONTROLS_INDEX_FILE} ({len(shared_expected_files) + len(material_expected_files) + len(cupertino_expected_files)} controls) and "
        f"{SERVICES_INDEX_FILE} ({len(services_expected_files)} services); "
        f"material={len(material_controls_map_entries)} cupertino={len(cupertino_controls_map_entries)} "
        f"shared={len(shared_controls_map_entries)} aliases"
    )


if __name__ == "__main__":
    build()
