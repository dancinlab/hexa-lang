#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
json_schema_validator.py — stdlib JSON Schema (draft-07 subset) validator.

Why this exists: cross-cutting Require (R5) raw 9 hexa-only mandates Python
stdlib only — no `jsonschema` pip package. Several .schema.json files now
exist in the repo (weave/, nanobot/, ribozyme/, virocapsid/ spec dirs) and
need a validation path. This module implements just the subset of draft-07
features used by those schemas:

    type, required, properties, additionalProperties, enum, const,
    pattern (re.search), minimum, exclusiveMinimum, maximum,
    exclusiveMaximum, minItems, items, minLength, maxLength, format
    (date-time only — best-effort).

Anything not listed is permissive (does not fail validation) so the
validator stays forward-compatible with future schema additions but
catches the structural errors that matter today.

Usage as library:

    from json_schema_validator import validate
    errors = validate(instance, schema)
    if errors: ...

Usage as CLI:

    python3 selftest/json_schema_validator.py <schema.json> <instance.json>
    cat instance.jsonl | python3 selftest/json_schema_validator.py \
        --schema <schema.json> --jsonl
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime

ISO_DATETIME_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})$")


_TYPE_TO_PY = {
    "string": str,
    "integer": int,
    "number": (int, float),
    "boolean": bool,
    "array": list,
    "object": dict,
    "null": type(None),
}


def _check_type(instance, type_spec) -> bool:
    if type_spec is None:
        return True
    if isinstance(type_spec, list):
        return any(_check_type(instance, t) for t in type_spec)
    py = _TYPE_TO_PY.get(type_spec)
    if py is None:
        return True
    if type_spec == "integer" and isinstance(instance, bool):
        return False
    if type_spec == "boolean" and not isinstance(instance, bool):
        return False
    if type_spec == "number" and isinstance(instance, bool):
        return False
    return isinstance(instance, py)


def validate(instance, schema, path: str = "$") -> list[str]:
    """Return list of error strings. Empty list = valid."""
    errs: list[str] = []
    if not isinstance(schema, dict):
        return errs

    type_spec = schema.get("type")
    if type_spec is not None and not _check_type(instance, type_spec):
        errs.append(f"{path}: expected type {type_spec!r}, got {type(instance).__name__}")
        return errs  # Type failure cascades, abort sub-checks.

    if "const" in schema and instance != schema["const"]:
        errs.append(f"{path}: const mismatch (expected {schema['const']!r}, got {instance!r})")

    if "enum" in schema and instance not in schema["enum"]:
        errs.append(f"{path}: enum mismatch (got {instance!r})")

    if isinstance(instance, str):
        if "pattern" in schema and not re.search(schema["pattern"], instance):
            errs.append(f"{path}: pattern mismatch (got {instance!r}, pattern {schema['pattern']!r})")
        if "minLength" in schema and len(instance) < schema["minLength"]:
            errs.append(f"{path}: minLength {schema['minLength']} (got {len(instance)})")
        if "maxLength" in schema and len(instance) > schema["maxLength"]:
            errs.append(f"{path}: maxLength {schema['maxLength']} (got {len(instance)})")
        fmt = schema.get("format")
        if fmt == "date-time":
            if not (ISO_DATETIME_RE.match(instance) or _try_iso(instance)):
                errs.append(f"{path}: format date-time mismatch (got {instance!r})")

    if isinstance(instance, (int, float)) and not isinstance(instance, bool):
        if "minimum" in schema and instance < schema["minimum"]:
            errs.append(f"{path}: minimum {schema['minimum']} (got {instance})")
        if "exclusiveMinimum" in schema and instance <= schema["exclusiveMinimum"]:
            errs.append(f"{path}: exclusiveMinimum {schema['exclusiveMinimum']} (got {instance})")
        if "maximum" in schema and instance > schema["maximum"]:
            errs.append(f"{path}: maximum {schema['maximum']} (got {instance})")
        if "exclusiveMaximum" in schema and instance >= schema["exclusiveMaximum"]:
            errs.append(f"{path}: exclusiveMaximum {schema['exclusiveMaximum']} (got {instance})")

    if isinstance(instance, list):
        if "minItems" in schema and len(instance) < schema["minItems"]:
            errs.append(f"{path}: minItems {schema['minItems']} (got {len(instance)})")
        if "maxItems" in schema and len(instance) > schema["maxItems"]:
            errs.append(f"{path}: maxItems {schema['maxItems']} (got {len(instance)})")
        item_schema = schema.get("items")
        if item_schema is not None:
            for i, el in enumerate(instance):
                errs.extend(validate(el, item_schema, f"{path}[{i}]"))

    if isinstance(instance, dict):
        required = schema.get("required") or []
        for r in required:
            if r not in instance:
                errs.append(f"{path}.{r}: required property missing")
        properties = schema.get("properties") or {}
        for k, sub_schema in properties.items():
            if k in instance:
                errs.extend(validate(instance[k], sub_schema, f"{path}.{k}"))
        if schema.get("additionalProperties") is False:
            extras = set(instance.keys()) - set(properties.keys())
            for e in extras:
                errs.append(f"{path}.{e}: additional property not allowed")

    return errs


def _try_iso(s: str) -> bool:
    try:
        datetime.fromisoformat(s.replace("Z", "+00:00"))
        return True
    except (ValueError, TypeError):
        return False


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description="stdlib JSON Schema (draft-07 subset) validator")
    p.add_argument("schema", nargs="?", help="Path to schema JSON file (or use --schema).")
    p.add_argument("instance", nargs="?", help="Path to instance JSON file. If omitted, reads stdin.")
    p.add_argument("--schema", dest="schema_flag", help="Path to schema JSON file.")
    p.add_argument("--jsonl", action="store_true", help="Treat stdin as one JSON object per line; validate each.")
    args = p.parse_args(argv)

    schema_path = args.schema_flag or args.schema
    if not schema_path:
        sys.stderr.write("error: schema path required\n")
        return 2
    with open(schema_path, "r", encoding="utf-8") as fh:
        schema = json.load(fh)

    if args.jsonl:
        n_total = 0
        n_fail = 0
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            n_total += 1
            try:
                instance = json.loads(line)
            except json.JSONDecodeError as e:
                sys.stderr.write(f"line {n_total}: invalid JSON ({e})\n")
                n_fail += 1
                continue
            errs = validate(instance, schema)
            if errs:
                n_fail += 1
                sys.stderr.write(f"line {n_total}: {len(errs)} error(s)\n")
                for e in errs:
                    sys.stderr.write(f"  {e}\n")
        sys.stdout.write(f"total={n_total} pass={n_total - n_fail} fail={n_fail}\n")
        return 0 if n_fail == 0 else 1

    if args.instance:
        with open(args.instance, "r", encoding="utf-8") as fh:
            instance = json.load(fh)
    else:
        instance = json.load(sys.stdin)
    errs = validate(instance, schema)
    if errs:
        for e in errs:
            sys.stderr.write(e + "\n")
        sys.stdout.write(f"FAIL: {len(errs)} error(s)\n")
        return 1
    sys.stdout.write("PASS\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
