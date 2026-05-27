#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/schema_const_audit.py — schema-const propagation audit (REPORTER).

WHY THIS EXISTS
---------------
The repo's honesty discipline relies on a small set of fields being
STRUCTURALLY enforced as JSON-Schema `const` values, not just typed. The
gold-standard pattern is in `case_studies/sma_portfolio/portfolio_v1.schema.json`:

    "axis":             {"type": "null"}            # const-typed: only null
    "in_scope":         {"type": "boolean", "const": false}
    "reported_not_run": {"type": "boolean", "const": true}
    "in_silico_only":   {"type": "boolean", "const": true}

A schema validator REJECTS witnesses that try to flip `axis: null` to a real
axis string for an UNPLACED CBER drug, or `in_scope: false` to `true` for a
research-stage modality. Plain `"type": "boolean"` does not catch that — a
witness writer could silently emit `in_silico_only: false` and the schema
would pass. So the const constraint is the load-bearing honesty enforcer.

A3 (`rna_modality_comparison_smn2_cross_v1`) and G4
(`peptide_macrocycle_cross_v1`) and G5 (`aptamer_oligonucleotide_cross_v1`)
extend the same pattern to cross-axis modality comparisons, where
`comparison_is_ranking: const false` and `signals_commensurable: const false`
are the structural guarantees that the cross is descriptive, not a ranking.

This audit reports per-schema:
  1. honesty fields that ARE const-enforced (good),
  2. honesty fields that are TYPED-ONLY (could-be-const gap),
  3. aggregate counts so a future targeted fix can close gaps.

THIS IS A REPORTER, NOT AN ENFORCER (echoing the I3/K2 reporter pattern).
TYPED-ONLY findings are NAMED, never FAILED. The sentinel
`__SCHEMA_CONST_AUDIT__ PASS` fires iff:
  - the directory walk completed without an OS error, AND
  - every discovered *.schema.json parsed as valid JSON.
A schema that legitimately has zero honesty fields is fine (e.g. a pure
output-shape schema for a non-honesty witness).

GOVERNANCE (hexa-bio AGENTS.tape)
---------------------------------
  g1 real-limits-first — the audit anchors on the JSON-Schema spec itself
     (a "real limit" of the validator: presence/absence of a `const` keyword
     under a property). No lattice arithmetic, no derivation.
  g3 honesty-obligation-external — the value of this audit is in NAMING
     gaps honestly. A TYPED-ONLY honesty field is not "wrong" — it is a
     legitimate gap a future targeted fix can close. The audit refuses to
     declare a schema "wrong" because some honesty fields are typed-only.
  g7 skip-is-honest — schemas absent from disk are SKIP, not FAIL. The
     directory walk only inspects what is present.
  g8 in-silico-only — a PASS here verifies the audit ran cleanly over the
     present in-silico schema corpus ONLY. It is NEVER a therapeutic /
     clinical / regulatory / efficacy claim, and it is NOT a claim that
     every honesty field WILL eventually be const-enforced — only that the
     current state is faithfully reported.

DETERMINISM
-----------
Pure stdlib (json, os, re, sys). No third-party imports. No network access.
No random / wall-clock dependence. Re-running this gate on the same repo
state produces byte-identical output, modulo dict-iteration order which is
guarded by sorted() on every level.

Usage:
    python3 selftest/schema_const_audit.py
    # exit 0 = walk completed cleanly + every schema parsed as JSON
    # exit 1 = OS walk error OR at least one schema failed to parse
"""
from __future__ import annotations

import json
import os
import re
import sys


# ── repo layout ─────────────────────────────────────────────────────────
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Directories that hold canonical schemas the audit walks. Anything under
# these paths matching `*.schema.json` is in scope. Anything elsewhere is
# out-of-scope (vendored .venv, worktree copies, third-party packages).
SCHEMA_SEARCH_DIRS = [
    "_python_bridge/spec",
    "case_studies",          # */portfolio_v1.schema.json
    "bifunctional/spec",
    "covalent/spec",
    "metallodrug/spec",
    "nanobot/spec",
    "oligonucleotide/spec",
    "ribozyme/spec",
    "synbio/spec",
    "virocapsid/spec",
    "weave/spec",
    "selftest/spec",
]

# Path-segment filters that exclude noise (worktree copies, vendored, venv).
EXCLUDE_SEGMENTS = (
    "/.claude/",
    "/.git/",
    "/.venv/",
    "/node_modules/",
    "/__pycache__/",
)

# ── honesty field registry ─────────────────────────────────────────────
# These field names are the audit's "honesty vocabulary." A schema is
# inspected for the presence of any of these as a property name; each
# occurrence is classified CONST vs TYPED-ONLY. Comparison is case-insensitive
# on the field name. The list is the union of names actually used across
# the gold-standard schemas (sma/hiv1 portfolios; A3/G4/G5 cross schemas)
# plus the broader honesty vocabulary documented in AGENTS.tape g1/g3/g8.
HONESTY_FIELDS = (
    # gold-standard portfolio/UNPLACED handling
    "in_scope",
    "reported_not_run",
    "in_silico_only",
    "all_three_drugs_fda_approved",
    "both_drugs_fda_approved",
    "both_modalities_fda_approved",
    "both_modalities_have_fda_precedent",
    "unplaced_handling_is_honest",
    "no_lattice_derivation",
    "scope_is_one_disease_pilot",
    "one_disease_pilot_not_200_disease_remap",
    "research_stage_negatives_listed_honestly",
    "core_5_unchanged",
    "no_fork_of_sister_sims",
    # comparison / cross-axis honesty
    "comparison_is_ranking",
    "signals_commensurable",
    "cross_is_three_axis",
    "cross_is_not_a_new_axis",
    "creates_a_new_axis",
    "modality_interchangeability_claim",
    "illustrative_only",
    "not_a_redesign_recommendation",
    # universal honesty disclaimers
    "not_an_efficacy_ranking",
    "not_a_superiority_claim",
    "not_a_clinical_claim",
    "not_a_portfolio_recommendation",
    "fda_approved",
    # UNPLACED axis handling (sma portfolio's `axis: null` const-typed gate)
    "axis",
)

# Honesty-field names are stored canonical-lower for comparison; the print
# layer preserves the original casing seen in the schema.
HONESTY_FIELDS_LC = {name.lower() for name in HONESTY_FIELDS}

# `axis` is ambiguous — in a placed/in-scope drug it is a real string axis
# ("VIROCAPSID"), in an UNPLACED CBER drug it is the const-null honesty gate.
# The audit only counts `axis` as a honesty field when its declaration is
# `"type": "null"` (the UNPLACED gold-standard pattern). Otherwise `axis` is
# a regular content field and is ignored. This matches the SMA portfolio
# schema's split between in_scope_drugs.axis (real string) and
# not_in_scope_drugs.axis (const-typed null).
AXIS_HONESTY_GATE = "axis"

# Verdict tokens
V_CONST = "CONST"
V_TYPED_ONLY = "TYPED-ONLY"


# ── schema discovery ────────────────────────────────────────────────────
def discover_schemas(repo_root):
    """Walk every SCHEMA_SEARCH_DIR under repo_root and yield absolute
    paths to `*.schema.json` files, skipping EXCLUDE_SEGMENTS.

    Yields paths in sorted order (deterministic). A search directory that
    does not exist on disk is silently skipped — honest g7 SKIP, not FAIL.
    """
    out = []
    for rel in SCHEMA_SEARCH_DIRS:
        base = os.path.join(repo_root, rel)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            # prune excluded directories from the walk in place
            dirnames[:] = sorted(
                d for d in dirnames
                if not any(seg.strip("/") == d for seg in EXCLUDE_SEGMENTS))
            normalised = dirpath.replace(os.sep, "/")
            if any(seg in normalised + "/" for seg in EXCLUDE_SEGMENTS):
                continue
            for name in sorted(filenames):
                if name.endswith(".schema.json"):
                    out.append(os.path.join(dirpath, name))
    return sorted(set(out))


# ── property-tree walk ──────────────────────────────────────────────────
def is_const_enforced(prop_decl):
    """Return True iff the property declaration enforces a const value.

    Two acceptable structural patterns count as CONST:

      (a) explicit `const` keyword:
            {"type": "boolean", "const": true}
            {"const": false}
            {"type": "string", "const": "CDER"}

      (b) `"type": "null"` (the SMA portfolio's UNPLACED axis pattern —
          a null-typed field has exactly one legal value, namely null,
          which is structurally indistinguishable from `"const": null`).

    Anything else — including `enum: [...]` with multiple options, plain
    `"type": "boolean"`, or a bare `{"type": "string"}` — is TYPED-ONLY.
    `enum` with a single member would also be const-equivalent, but is
    not idiomatic in this repo's schemas and is conservatively classed
    TYPED-ONLY here (a future tightening could promote single-member enums
    to CONST without false-positives).
    """
    if not isinstance(prop_decl, dict):
        return False
    if "const" in prop_decl:
        return True
    t = prop_decl.get("type")
    if t == "null":
        return True
    # `"type": ["null"]` (single-member list) also collapses to null-only
    if isinstance(t, list) and len(t) == 1 and t[0] == "null":
        return True
    return False


def _walk_properties(node, path_prefix, sink):
    """Recursively walk a JSON-Schema node looking for `properties` and
    `definitions` blocks. For every property whose name (case-insensitive)
    is in HONESTY_FIELDS_LC, record a (field_name, breadcrumb, verdict)
    tuple into `sink`.

    Special case: `axis` only counts when its declaration is null-typed
    (the UNPLACED honesty gate). A `axis: {"type": "string"}` declaration
    is a real content field and is ignored — counting it would generate
    false-positive TYPED-ONLY noise on every in_scope_drugs entry.
    """
    if isinstance(node, dict):
        # `properties` block — inspect each child property
        if "properties" in node and isinstance(node["properties"], dict):
            for prop_name in sorted(node["properties"].keys()):
                prop_decl = node["properties"][prop_name]
                if prop_name.lower() in HONESTY_FIELDS_LC:
                    if prop_name.lower() == AXIS_HONESTY_GATE:
                        # axis only counts when null-typed (UNPLACED gate)
                        if not isinstance(prop_decl, dict):
                            pass
                        else:
                            t = prop_decl.get("type")
                            null_typed = (
                                t == "null"
                                or (isinstance(t, list)
                                    and len(t) == 1 and t[0] == "null"))
                            if null_typed or ("const" in prop_decl
                                              and prop_decl.get("const") is None):
                                verdict = V_CONST
                                sink.append((
                                    prop_name,
                                    path_prefix + "." + prop_name,
                                    verdict,
                                ))
                        # otherwise skip — real axis string, not the
                        # UNPLACED honesty gate.
                    else:
                        verdict = (V_CONST if is_const_enforced(prop_decl)
                                   else V_TYPED_ONLY)
                        sink.append((
                            prop_name,
                            path_prefix + "." + prop_name,
                            verdict,
                        ))
                # recurse into the property declaration
                _walk_properties(prop_decl,
                                 path_prefix + "." + prop_name, sink)
        # `definitions` block — recurse with /defs/<name> prefix
        if "definitions" in node and isinstance(node["definitions"], dict):
            for def_name in sorted(node["definitions"].keys()):
                _walk_properties(
                    node["definitions"][def_name],
                    path_prefix + "/defs/" + def_name,
                    sink)
        # other keywords that nest a sub-schema
        for key in ("items", "additionalProperties", "if", "then", "else",
                    "contains", "not", "propertyNames"):
            if key in node and isinstance(node[key], (dict, list)):
                _walk_properties(node[key],
                                 path_prefix + "/" + key, sink)
        # array-of-schema keywords
        for key in ("allOf", "anyOf", "oneOf"):
            if key in node and isinstance(node[key], list):
                for idx, sub in enumerate(node[key]):
                    _walk_properties(sub,
                                     path_prefix + f"/{key}[{idx}]", sink)
    elif isinstance(node, list):
        for idx, sub in enumerate(node):
            _walk_properties(sub, path_prefix + f"[{idx}]", sink)


def audit_schema(schema_path):
    """Parse one schema file and return (ok, error_msg, findings).

    findings is a list of (field_name, breadcrumb, verdict) tuples sorted
    by (verdict-priority, field_name, breadcrumb) for deterministic output.
    CONST comes before TYPED-ONLY so the table reads good-first.
    """
    try:
        with open(schema_path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError) as e:
        return False, f"{type(e).__name__}: {e}", []

    findings = []
    _walk_properties(data, "$", findings)

    # dedup — a field may be re-visited if the same property name appears
    # at multiple breadcrumb paths (legitimate; e.g. honesty.in_silico_only
    # at top-level AND modality_row.in_silico_only via $ref). We keep each
    # distinct breadcrumb so the table is faithful.
    seen = set()
    deduped = []
    for triple in findings:
        if triple not in seen:
            seen.add(triple)
            deduped.append(triple)

    deduped.sort(key=lambda t: (0 if t[2] == V_CONST else 1, t[0], t[1]))
    return True, "", deduped


# ── reporting ──────────────────────────────────────────────────────────
def _shorten(s, width):
    if s is None:
        return ""
    s = str(s)
    return s if len(s) <= width else s[:width - 1] + "…"


def render_schema_block(rel_path, findings):
    """Render one schema's per-field table. Called once per schema with
    at least one honesty-field finding."""
    print(f"  {rel_path}")
    if not findings:
        print("    (no honesty fields found — out-of-scope for this audit)")
        return
    # column widths
    w_field = max([len("field")] + [len(f[0]) for f in findings])
    w_verdict = max([len("verdict")] + [len(f[2]) for f in findings])
    w_field = min(w_field, 38)
    w_verdict = min(w_verdict, 12)
    breadcrumb_w = 56

    header = (f"    {'field':<{w_field}}  {'verdict':<{w_verdict}}  "
              f"breadcrumb")
    rule = ("    " + "-" * w_field + "  " + "-" * w_verdict
            + "  " + "-" * 10)
    print(header)
    print(rule)
    for field_name, breadcrumb, verdict in findings:
        print(f"    {_shorten(field_name, w_field):<{w_field}}  "
              f"{verdict:<{w_verdict}}  "
              f"{_shorten(breadcrumb, breadcrumb_w)}")


def render_gap_summary(per_schema):
    """Render the cross-schema gap summary — schemas with at least one
    TYPED-ONLY honesty field, listed for a future targeted fix."""
    gaps = []
    for rel, findings in per_schema:
        typed_only = [f for f in findings if f[2] == V_TYPED_ONLY]
        if typed_only:
            gaps.append((rel, typed_only))
    if not gaps:
        print("  (no TYPED-ONLY honesty fields found across the audited "
              "schema set)")
        return
    for rel, typed_only in gaps:
        fields = sorted({f[0] for f in typed_only})
        print(f"  {rel}")
        for f in fields:
            print(f"      could-be-const: {f}")


# ── main ───────────────────────────────────────────────────────────────
def main():
    print("schema_const_audit — hexa-bio schema-const propagation audit "
          "(REPORTER, not enforcer)")
    print("  walks the canonical *.schema.json corpus, classifies each")
    print("  honesty field as CONST (structurally enforced) or TYPED-ONLY")
    print("  (typed but not const-enforced — a could-be-const gap).")
    print("  governance: g1 real-limits-first (validator semantics) ·")
    print("              g3 honest gap-naming (no inflation) ·")
    print("              g7 skip-is-honest (absent schema dirs SKIP) ·")
    print("              g8 in-silico-only scope\n")

    # ── discover ───────────────────────────────────────────────────────
    try:
        schemas = discover_schemas(REPO_ROOT)
    except OSError as e:
        print(f"  [ERROR] schema directory walk failed: "
              f"{type(e).__name__}: {e}")
        print("__SCHEMA_CONST_AUDIT__ FAIL")
        return 1

    print(f"  discovered {len(schemas)} *.schema.json under "
          f"{len(SCHEMA_SEARCH_DIRS)} canonical search dirs\n")

    # ── audit each schema ──────────────────────────────────────────────
    per_schema = []        # [(rel_path, findings)]
    parse_errors = []      # [(rel_path, msg)]
    for path in schemas:
        rel = os.path.relpath(path, REPO_ROOT)
        ok, err, findings = audit_schema(path)
        if not ok:
            parse_errors.append((rel, err))
            continue
        per_schema.append((rel, findings))

    # ── parse-error reporting (these block the sentinel) ──────────────
    if parse_errors:
        print("── PARSE ERRORS " + "─" * 60)
        for rel, err in parse_errors:
            print(f"  [FAIL] {rel}")
            print(f"         {err}")
        print()

    # ── per-schema honesty-field tables ────────────────────────────────
    schemas_with_honesty = [
        (rel, f) for (rel, f) in per_schema if f
    ]
    schemas_without_honesty = [
        rel for (rel, f) in per_schema if not f
    ]

    print(f"── per-schema honesty-field tables "
          f"({len(schemas_with_honesty)} schemas with ≥1 honesty field) "
          + "─" * 6)
    for rel, findings in sorted(schemas_with_honesty):
        render_schema_block(rel, findings)
        print()
    if not schemas_with_honesty:
        print("  (none — no honesty fields found in the corpus)\n")

    # ── schemas with no honesty fields ────────────────────────────────
    print(f"── schemas with no honesty fields "
          f"({len(schemas_without_honesty)} schemas — legitimately "
          "out-of-scope) " + "─" * 6)
    for rel in sorted(schemas_without_honesty)[:8]:
        print(f"  {rel}")
    if len(schemas_without_honesty) > 8:
        print(f"  … and {len(schemas_without_honesty) - 8} more")
    print()

    # ── could-be-const gap summary ─────────────────────────────────────
    print("── could-be-const gap summary " + "─" * 50)
    print("  schemas with at least one TYPED-ONLY honesty field — these")
    print("  are HONEST GAPS a future targeted fix can close (g3). They")
    print("  are NOT failures; the audit is a REPORTER, not an enforcer.")
    print()
    render_gap_summary(sorted(schemas_with_honesty))
    print()

    # ── aggregate counts ───────────────────────────────────────────────
    n_const = 0
    n_typed = 0
    for rel, findings in per_schema:
        for _, _, verdict in findings:
            if verdict == V_CONST:
                n_const += 1
            elif verdict == V_TYPED_ONLY:
                n_typed += 1

    print("── aggregate counts " + "─" * 55)
    print(f"  schemas covered                : {len(per_schema)}")
    print(f"  schemas with honesty fields    : "
          f"{len(schemas_with_honesty)}")
    print(f"  schemas with NO honesty fields : "
          f"{len(schemas_without_honesty)}  (out-of-scope, fine)")
    print(f"  CONST honesty-field declarations    : {n_const}")
    print(f"  TYPED-ONLY honesty-field declarations: {n_typed}  "
          f"(could-be-const gap candidates)")
    if parse_errors:
        print(f"  PARSE-ERROR schemas                 : "
              f"{len(parse_errors)}  (blocks sentinel)")
    print()

    # ── honesty notes ──────────────────────────────────────────────────
    print("── honesty (g3 honest reporting · reporter ≠ enforcer) "
          + "─" * 15)
    print("  TYPED-ONLY is a GAP, not a FAILURE. A typed honesty field is")
    print("  not 'wrong' — the schema simply does not yet structurally")
    print("  enforce the value via `const`. A future targeted fix can add")
    print("  `\"const\": true` (or false / null) one schema at a time. The")
    print("  audit names the gap so the fix is small and obvious.")
    print()
    print("  The `axis` field is only counted when null-typed (the SMA")
    print("  portfolio's UNPLACED CBER-drug gold-standard pattern). Real")
    print("  string axes (\"VIROCAPSID\", \"WEAVE\") are intentional content,")
    print("  not honesty gates, and are NOT counted as could-be-const gaps.")
    print()
    print("  Single-member `enum: [\"X\"]` declarations are structurally")
    print("  const-equivalent but conservatively classed TYPED-ONLY here.")
    print("  A future tightening could promote them to CONST; the current")
    print("  classification stays on the safe side (no false PASS).")
    print()
    print("  (g8) A PASS here verifies the audit ran cleanly on the present")
    print("  in-silico schema corpus ONLY. It is NEVER a therapeutic /")
    print("  clinical / regulatory / efficacy claim, and it is NOT a claim")
    print("  that the schemas currently flagged TYPED-ONLY will or should")
    print("  all become CONST — only that the present state is faithfully")
    print("  named so future targeted work is informed.")
    print()

    # ── sentinel ───────────────────────────────────────────────────────
    if parse_errors:
        print("__SCHEMA_CONST_AUDIT__ FAIL")
        return 1
    print("__SCHEMA_CONST_AUDIT__ PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
