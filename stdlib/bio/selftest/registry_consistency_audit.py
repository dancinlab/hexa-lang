#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/registry_consistency_audit.py — registry-vs-spec consistency.

Audits `state/discovery_absorption/registry.jsonl` against the lived
schema files under `<verb>/spec/*.schema.json`. For each row whose
`schema` field matches a spec schema's `const`, validate the row using
`selftest/json_schema_validator.py`.

PASS criterion: all rows whose schema is covered by a spec validate;
unschema'd rows (legacy or session-internal kinds) are reported but
not failed.

Per cross-cutting Require (R5) raw 9 hexa-only: **Python stdlib only.**

Usage:

    python3 selftest/registry_consistency_audit.py
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO_ROOT, "selftest"))
import json_schema_validator as v  # noqa: E402

REGISTRY_PATH = os.path.join(REPO_ROOT, "state", "discovery_absorption", "registry.jsonl")
SPEC_DIRS = [
    os.path.join(REPO_ROOT, "weave", "spec"),
    os.path.join(REPO_ROOT, "nanobot", "spec"),
    os.path.join(REPO_ROOT, "ribozyme", "spec"),
    os.path.join(REPO_ROOT, "virocapsid", "spec"),
    os.path.join(REPO_ROOT, "selftest", "spec"),
]


def load_specs() -> dict:
    """Map: const-string → schema dict."""
    by_const = {}
    for d in SPEC_DIRS:
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            if not fn.endswith(".schema.json"):
                continue
            path = os.path.join(d, fn)
            try:
                with open(path, "r", encoding="utf-8") as fh:
                    s = json.load(fh)
            except (OSError, json.JSONDecodeError):
                continue
            schema_prop = (s.get("properties") or {}).get("schema") or {}
            const = schema_prop.get("const")
            if const:
                by_const[const] = (s, path)
    return by_const


def main(argv):
    p = argparse.ArgumentParser(description="Registry-vs-spec consistency audit")
    p.add_argument("--emit", action="store_true")
    p.add_argument("--summary", action="store_true")
    p.add_argument("--verbose", action="store_true")
    args = p.parse_args(argv)

    specs_by_const = load_specs()
    sys.stderr.write(f"loaded {len(specs_by_const)} schema(s) with const tag:\n")
    for const, (_, path) in specs_by_const.items():
        sys.stderr.write(f"  {const}  ({os.path.relpath(path, REPO_ROOT)})\n")

    n_total = 0
    n_covered = 0
    n_uncovered = 0
    n_pass = 0
    n_fail = 0
    fail_details = []
    uncovered_schemas = {}

    if not os.path.exists(REGISTRY_PATH):
        sys.stderr.write("error: no registry\n")
        return 2

    with open(REGISTRY_PATH, "r", encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, start=1):
            line = line.strip()
            if not line:
                continue
            n_total += 1
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                n_fail += 1
                fail_details.append({"line": lineno, "schema": "?", "errors": ["invalid JSON"]})
                continue
            schema_tag = row.get("schema") or "?"
            if schema_tag not in specs_by_const:
                n_uncovered += 1
                uncovered_schemas[schema_tag] = uncovered_schemas.get(schema_tag, 0) + 1
                continue
            n_covered += 1
            spec, _ = specs_by_const[schema_tag]
            errs = v.validate(row, spec)
            if errs:
                n_fail += 1
                fail_details.append({"line": lineno, "schema": schema_tag, "errors": errs[:5]})
            else:
                n_pass += 1

    overall = n_fail == 0
    audited_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    witness = {
        "schema": "raw_77_registry_consistency_audit_v1",
        "audited_at": audited_at,
        "audit_kind": "registry_vs_spec_validation",
        "n_total_rows": n_total,
        "n_covered_by_spec": n_covered,
        "n_uncovered_by_spec": n_uncovered,
        "n_validate_pass": n_pass,
        "n_validate_fail": n_fail,
        "uncovered_schema_tags": uncovered_schemas,
        "fail_details": fail_details[:20],
        "specs_loaded": list(specs_by_const.keys()),
        "overall_pass": overall,
        "raw_91_c3_disclose": (
            "Validates registry rows against spec schemas where the spec "
            "exists with a const-tagged schema field. Uncovered rows "
            "(legacy or session-internal kinds without spec files) are "
            "reported but not failed. Validator subset: type / required / "
            "properties / enum / const / pattern / min(Items|Length) / "
            "format=date-time / additionalProperties."
        ),
        "raw_77_append_only": True,
        "witness_ref": "state/discovery_absorption/registry.jsonl#raw_77_registry_consistency_audit_v1",
    }

    if args.emit:
        with open(REGISTRY_PATH, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(witness, ensure_ascii=False, sort_keys=True) + "\n")
        sys.stderr.write(f"emitted 1 witness row -> {REGISTRY_PATH}\n")

    if args.summary:
        print(json.dumps(witness, sort_keys=True, indent=2))
    else:
        sys.stderr.write(
            f"\nregistry: total={n_total} covered={n_covered} uncovered={n_uncovered} "
            f"pass={n_pass} fail={n_fail}  overall={'PASS' if overall else 'FAIL'}\n"
        )
        if uncovered_schemas:
            sys.stderr.write("uncovered schema tags:\n")
            for tag, n in sorted(uncovered_schemas.items()):
                sys.stderr.write(f"  {n:6d}  {tag}\n")
        if fail_details:
            sys.stderr.write(f"\nfailures ({len(fail_details)}):\n")
            for f in fail_details[:5]:
                sys.stderr.write(f"  line {f['line']} schema={f['schema']}: {f['errors']}\n")

    return 0 if overall else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
