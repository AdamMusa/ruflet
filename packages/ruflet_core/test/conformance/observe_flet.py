#!/usr/bin/env python3
import json
import sys


def normalize(value):
    if value is None or isinstance(value, (bool, int, float, str)):
        return value
    if isinstance(value, dict):
        return {str(k): normalize(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [normalize(v) for v in value]
    if hasattr(value, "__dict__"):
        values = getattr(value, "_values", None)
        if isinstance(values, dict):
            return normalize(values)
        return {
            str(k).lstrip("_"): normalize(v)
            for k, v in vars(value).items()
            if not callable(v) and not k.startswith("__")
        }
    return str(value)


def observe_case(ft, case):
    cls = getattr(ft, case["python_class"])
    props = case.get("props", {})
    try:
        control = cls(**props)
    except Exception as exc:
        return {
            "name": case["name"],
            "status": "error",
            "error_class": exc.__class__.__name__,
            "error_message": str(exc),
        }

    observed = {}
    for prop in props:
        observed[prop] = normalize(getattr(control, prop, None))

    return {
        "name": case["name"],
        "status": "ok",
        "class": control.__class__.__name__,
        "props": observed,
    }


def main():
    with open(sys.argv[1], "r", encoding="utf-8") as file:
        data = json.load(file)

    import flet as ft

    result = {
        "flet_version": getattr(ft, "__version__", "unknown"),
        "cases": [observe_case(ft, case) for case in data["cases"]],
    }
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
