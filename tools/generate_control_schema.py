#!/usr/bin/env python3
"""
Generate Ruflet control schema registry from local Flet Python sources.

Usage:
  python3 tools/generate_control_schema.py > packages/ruflet/lib/ruflet_ui/ruflet/ui/control_schema_registry.rb
"""

from __future__ import annotations

import ast
import re
from pathlib import Path


REPO = Path.home() / ".pub-cache" / "git"


class ClassInfo:
    __slots__ = ("name", "bases", "fields", "control_name", "family")

    def __init__(self, name: str, bases: list[str], fields: set[str], control_name: str | None, family: str):
        self.name = name
        self.bases = bases
        self.fields = fields
        self.control_name = control_name
        self.family = family


def family_from_path(path: Path) -> str:
    p = path.as_posix()
    if "/controls/cupertino/" in p:
        return "cupertino"
    if "/controls/material/" in p:
        return "material"
    return "shared"


def find_flet_repo_root() -> Path:
    matches = sorted(REPO.glob("flet-*/sdk/python/packages"), reverse=True)
    if not matches:
        raise RuntimeError("Could not find local flet git checkout under ~/.pub-cache/git")
    return matches[0]


def read_py_files(root: Path) -> list[Path]:
    if not root.exists():
        return []
    return [p for p in root.rglob("*.py") if p.is_file()]


def decorator_control_name(deco: ast.AST) -> str | None:
    if isinstance(deco, ast.Name) and deco.id == "control":
        return None
    if isinstance(deco, ast.Call):
        func = deco.func
        func_name = None
        if isinstance(func, ast.Name):
            func_name = func.id
        elif isinstance(func, ast.Attribute):
            func_name = func.attr
        if func_name == "control":
            if deco.args and isinstance(deco.args[0], ast.Constant) and isinstance(deco.args[0].value, str):
                return deco.args[0].value
            return None
    return None


def base_name(node: ast.AST) -> str | None:
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Attribute):
        return node.attr
    if isinstance(node, ast.Subscript):
        return base_name(node.value)
    return None


def parse_classes(files: list[Path]) -> dict[str, ClassInfo]:
    classes: dict[str, ClassInfo] = {}
    for file in files:
        try:
            tree = ast.parse(file.read_text(encoding="utf-8"))
        except Exception:
            continue
        for node in tree.body:
            if not isinstance(node, ast.ClassDef):
                continue
            control_name = None
            for d in node.decorator_list:
                name = decorator_control_name(d)
                if name is not None:
                    control_name = name
                    break
            fields = set()
            for stmt in node.body:
                if isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name):
                    fields.add(stmt.target.id)
            bases = [b for b in (base_name(b) for b in node.bases) if b]
            classes[node.name] = ClassInfo(node.name, bases, fields, control_name, family_from_path(file))
    return classes


def collect_fields(classes: dict[str, ClassInfo], cls_name: str, memo: dict[str, set[str]], stack: set[str] | None = None) -> set[str]:
    if cls_name in memo:
        return memo[cls_name]
    if stack is None:
        stack = set()
    if cls_name in stack:
        return set()
    stack.add(cls_name)
    info = classes.get(cls_name)
    if not info:
        return set()
    out = set(info.fields)
    for b in info.bases:
        out |= collect_fields(classes, b, memo, stack)
    memo[cls_name] = out
    stack.remove(cls_name)
    return out


def ruby_array(items: list[str]) -> str:
    return "[" + ", ".join(f'"{item}"' for item in items) + "]"


def compact(value: str) -> str:
    return value.replace("_", "").lower()


def snake_from_camel(name: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()


def build_schema() -> dict[str, dict[str, object]]:
    packages_root = find_flet_repo_root()
    flet_dir = packages_root / "flet" / "src" / "flet" / "controls"
    camera_dir = packages_root / "flet-camera" / "src" / "flet_camera"

    files = read_py_files(flet_dir) + read_py_files(camera_dir)
    classes = parse_classes(files)
    memo: dict[str, set[str]] = {}

    schema: dict[str, dict[str, object]] = {}
    for ci in classes.values():
        if not ci.control_name:
            continue

        all_fields = collect_fields(classes, ci.name, memo)
        props = sorted(
            field
            for field in all_fields
            if not field.startswith("_") and field != "ref"
        )
        events = sorted(field[3:] for field in props if field.startswith("on_"))
        props = [field for field in props if not field.startswith("on_")]

        value = {"wire": ci.control_name, "props": props, "events": events, "family": ci.family}
        schema[compact(ci.control_name)] = value
        schema[snake_from_camel(ci.control_name)] = value

    if "filepicker" in schema:
        schema["file_picker"] = schema["filepicker"]
    if "radiogroup" in schema:
        schema["radio_group"] = schema["radiogroup"]
    if "alertdialog" in schema:
        schema["alert_dialog"] = schema["alertdialog"]
    if "snackbar" in schema:
        schema["snack_bar"] = schema["snackbar"]
    if "bottomsheet" in schema:
        schema["bottom_sheet"] = schema["bottomsheet"]

    return schema


def emit_ruby(schema: dict[str, dict[str, object]]) -> str:
    lines = [
        "# frozen_string_literal: true",
        "",
        "module Ruflet",
        "  module UI",
        "    module ControlSchemaRegistry",
        "      CONTROL_SCHEMAS = {",
    ]

    for key in sorted(schema.keys()):
        value = schema[key]
        props = ruby_array(value["props"])  # type: ignore[arg-type]
        events = ruby_array(value["events"])  # type: ignore[arg-type]
        wire = value["wire"]  # type: ignore[assignment]
        lines.append(f'        "{key}" => {{ "wire" => "{wire}", "props" => {props}, "events" => {events} }},')

    lines += [
        "      }.freeze",
        "",
        "      module_function",
        "",
        "      def for_type(type)",
        "        key = type.to_s.downcase",
        "        CONTROL_SCHEMAS[key] || CONTROL_SCHEMAS[key.delete(\"_\")]",
        "      end",
        "    end",
        "  end",
        "end",
        "",
    ]
    return "\n".join(lines)


if __name__ == "__main__":
    print(emit_ruby(build_schema()))
