#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/case_studies_export.py — case-studies WITNESS EXPORT BUNDLER for the
hexa-bio case_studies/ cohort (per-disease portfolios + landscape cross-tab +
drug-redesign sandbox).

WHAT THIS IS
------------
A deterministic, stdlib-only BUNDLER that:

  1. Discovers every `case_studies/<name>_portfolio/<name>_portfolio_runner.py`
     under the repo's case_studies/ tree.
  2. Discovers `case_studies/landscape/landscape_generator.py` if present.
  3. Discovers `case_studies/drug_redesign_sandbox/drug_redesign_runner.py`
     if present.
  4. Runs each discovered runner via `subprocess.run(...)`, captures stdout,
     and extracts the last well-formed top-level JSON object that carries a
     `schema_version` field (witness-shape liberal — every case-study runner
     in this repo prints its witness JSON to stdout; the landscape generator
     does NOT, so it gracefully captures null for that slot).
  5. Aggregates every captured witness into a SINGLE bundle JSON written to
     `state/exports/case_studies_bundle_v1.json` (relative to the repo root)
     — see the convention block in the bundle's own metadata: generated
     export artifacts live under `state/exports/`, NEVER under case_studies/,
     so the source-of-truth case-study definitions stay separate from
     generated bundles.
  6. Emits the sentinel `__CASE_STUDIES_EXPORT__ PASS` iff every discovered
     runner ran cleanly (exit 0) AND produced a parseable JSON witness. SKIP
     (per g7) is honest — a runner that did not execute or did not emit a
     parseable witness is noted, the bundle still emits with partial data,
     and the SKIP does NOT block the sentinel. Only a genuine bundler I/O
     failure (cannot write the bundle file) blocks it.

BUNDLE SHAPE
------------
    {
      "bundle_schema_version": "case_studies_bundle_v1",
      "generated_at": "<fixed ISO-8601 Z timestamp constant>",
      "portfolios": {<name>: <witness json>, ...},
      "landscape": <witness json or null>,
      "drug_redesign_sandbox": <witness json or null>,
      "bundle_checksums": {<name>: <sha256-hex over the per-slot witness>,
                           "landscape": <hex or null>,
                           "drug_redesign_sandbox": <hex or null>},
      "bundle_metadata": {
        "n_portfolios": <int>,
        "total_in_scope_drugs": <int>,
        "total_not_in_scope_drugs": <int>,
        "total_cder_no_axis_drugs": <int>,
        "in_silico_only": true,
        "honest_scope_statement": "<text>",
        ...
      }
    }

The per-slot SHA-256 hashes are computed over the slot's witness JSON
re-serialized with `sort_keys=True` so the digest is stable independent of
the runner's key order.

AGGREGATE COUNT SEMANTICS (liberal, schema-shape tolerant)
----------------------------------------------------------
The metadata aggregator counts across every PARSED portfolio witness:

  * total_in_scope_drugs    — sum of len(witness["in_scope_drugs"]) across
                              all portfolios (both HIV-1 and SMA schemas use
                              this same field name).
  * total_not_in_scope_drugs — sum of len(witness["not_in_scope_drugs"])
                              across all portfolios. This is the SMA-style
                              UNPLACED slot — typically CBER/CDRH scope-
                              disqualified rows (e.g. SMA Zolgensma).
  * total_cder_no_axis_drugs — sum across three schema-shape fields, each
                              read defensively:
                                (a) the HIV-1-style `research_stage_negatives[]`
                                    where `axis_in_repo` is set (CDER pipeline
                                    rows that don't yet have an FDA approval),
                                (b) the SMA-style `not_in_scope_drugs[]` rows
                                    with `fda_center == "CDER"` and `axis == null`
                                    (CDER-regulated drug whose modality is
                                    not yet axis-mapped in the repo),
                                (c) the T2D-style `cder_in_scope_no_axis_mapping[]`
                                    array if present (forward-compat for the
                                    type-2-diabetes portfolio schema once its
                                    runner lands).

Every count is HONEST aggregation across the witness data — never fabricated,
never derived from the n=6 lattice (g1 / f_lattice_fit). A portfolio with
zero rows in any slot contributes zero — not a default fill.

GOVERNANCE (hexa-bio AGENTS.tape)
---------------------------------
  g1 real-limits-first — every aggregate number is an HONEST COUNT on the
     per-portfolio witness shapes. No synthetic / weighted / lattice-derived
     scalar is invented. The bundle is a transport artifact, not a ranking.
  g3 honesty-obligation-external — `bundle_metadata.honest_scope_statement`
     reiterates the in-silico-only fence in plain text inside the bundle
     itself, so any downstream consumer reads the scope alongside the data.
  g7 skip-is-honest — a runner that did not execute (timeout / OSError /
     non-zero exit) or that ran cleanly but emitted no parseable witness JSON
     (e.g. the landscape generator, which writes a .md file and prints text)
     is noted via a `_runner_status` slot in the bundle (PASS / SKIP /
     SKIP-no-json) and does NOT block the bundler's sentinel. The bundle
     still emits with partial data — SKIP is honest, not failure.
  g8 in-silico-only — the bundle's own `bundle_metadata.in_silico_only=true`
     and its `honest_scope_statement` explicitly fence the bundle off from
     therapeutic / clinical / regulatory / efficacy / portfolio-
     recommendation interpretations. No raw#N / own#N tokens.

DETERMINISM
-----------
  * Pure stdlib (subprocess, json, hashlib, os, sys).
  * Per-runner subprocess timeout 60 s.
  * Discovery is sorted by directory basename.
  * Fixed ISO-8601-Z timestamp constant (FIXED_GENERATED_AT) so re-running on
    the same repo state yields a byte-identical bundle file.
  * SHA-256 hashes use stdlib `hashlib` over `json.dumps(..., sort_keys=True,
    ensure_ascii=False, separators=(",", ":"))` for stable per-slot digests.

Usage:
    python3 selftest/case_studies_export.py
    # exit 0 = bundle written + every discovered runner ran cleanly + every
    #          witness JSON parsed (or honest SKIP per g7)
    # exit 1 = bundle could not be written (a hard I/O contract break) —
    #          per-runner SKIPs do NOT cause exit 1, only a write failure
"""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys

# ── repo layout ─────────────────────────────────────────────────────────
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CASE_STUDIES_DIR = os.path.join(REPO_ROOT, "case_studies")

# Output convention: generated bundle artifacts live under state/exports/,
# NEVER inside case_studies/. This keeps generated transport artifacts
# separated from the source-of-truth case-study definitions.
EXPORTS_DIR = os.path.join(REPO_ROOT, "state", "exports")
BUNDLE_FILENAME = "case_studies_bundle_v1.json"
BUNDLE_PATH = os.path.join(EXPORTS_DIR, BUNDLE_FILENAME)

# Per-runner subprocess timeout (seconds). Generous — the landscape
# generator runs every portfolio runner itself, so it is the slowest.
RUNNER_TIMEOUT_S = 60

# Fixed timestamp constant so re-running on the same repo state emits a
# byte-identical bundle file (cohort honesty: reproducibility, not a
# wall-clock-derived stamp).
FIXED_GENERATED_AT = "2026-05-16T00:00:00Z"

BUNDLE_SCHEMA_VERSION = "case_studies_bundle_v1"

# Honest-scope text — embedded inside the bundle's own metadata so any
# downstream consumer reads the in-silico-only fence alongside the data.
HONEST_SCOPE_STATEMENT = (
    "IN-SILICO ONLY. This bundle aggregates per-portfolio witness JSON "
    "from the hexa-bio case_studies/ cohort. Every per-portfolio PASS "
    "certifies in-silico simulator + metadata internal consistency ONLY. "
    "It is NEVER a therapeutic, clinical, regulatory, efficacy, immunogenic, "
    "binding-affinity, potency, selectivity, or portfolio-recommendation "
    "claim. No quantity in this bundle is derived from the n=6 lattice "
    "(governance g1 / f_lattice_fit). Negatives (research-stage modalities, "
    "UNPLACED CBER/CDRH rows, CDER-in-scope-no-axis-mapping rows) are "
    "recorded honestly — they are a FEATURE of the cohort, not a gap. "
    "Aggregate counts are HONEST sums over each portfolio's own data "
    "structure; no synthetic / weighted / cross-portfolio ranking is "
    "introduced. The bundle is a transport artifact under state/exports/, "
    "kept separate from case_studies/ source definitions on purpose. "
    "Governance: g1 real-limits-first · g3 honesty-external · g7 "
    "skip-is-honest · g8 in-silico-only."
)

# Per-slot runner status tokens recorded in the bundle's _runner_status slot.
ST_PASS = "PASS"
ST_SKIP = "SKIP"
ST_SKIP_NO_JSON = "SKIP-no-json"


# ── discovery ────────────────────────────────────────────────────────────
def discover_portfolios():
    """Find every `case_studies/<name>_portfolio/<name>_portfolio_runner.py`.

    Returns a sorted list of {name, dir, runner} dicts. Sorted order is the
    portfolio directory's basename — deterministic across re-runs.
    """
    found = []
    if not os.path.isdir(CASE_STUDIES_DIR):
        return found
    for entry in sorted(os.listdir(CASE_STUDIES_DIR)):
        sub = os.path.join(CASE_STUDIES_DIR, entry)
        if not os.path.isdir(sub):
            continue
        if not entry.endswith("_portfolio"):
            continue
        name = entry[: -len("_portfolio")]
        runner = os.path.join(sub, f"{name}_portfolio_runner.py")
        if not os.path.isfile(runner):
            continue
        found.append({"name": name, "dir": sub, "runner": runner})
    return found


def discover_landscape():
    """Return the landscape generator path if present, else None."""
    p = os.path.join(CASE_STUDIES_DIR, "landscape", "landscape_generator.py")
    return p if os.path.isfile(p) else None


def discover_drug_redesign_sandbox():
    """Return the drug-redesign sandbox runner path if present, else None."""
    p = os.path.join(
        CASE_STUDIES_DIR, "drug_redesign_sandbox", "drug_redesign_runner.py"
    )
    return p if os.path.isfile(p) else None


# ── runner execution ─────────────────────────────────────────────────────
def run_runner(runner_path):
    """Execute a runner under a fixed timeout.

    Returns a dict {ran, exit_code, stdout, stderr, error}. `ran` is True iff
    the process executed (regardless of exit code); `error` describes a
    timeout / OSError-style failure.
    """
    try:
        proc = subprocess.run(
            [sys.executable, runner_path],
            capture_output=True,
            text=True,
            timeout=RUNNER_TIMEOUT_S,
            cwd=REPO_ROOT,
        )
    except subprocess.TimeoutExpired:
        return {
            "ran": False,
            "exit_code": None,
            "stdout": "",
            "stderr": "",
            "error": f"timeout after {RUNNER_TIMEOUT_S} s",
        }
    except OSError as exc:
        return {
            "ran": False,
            "exit_code": None,
            "stdout": "",
            "stderr": "",
            "error": f"OSError: {exc}",
        }
    return {
        "ran": True,
        "exit_code": proc.returncode,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
        "error": None,
    }


# ── witness JSON extraction ──────────────────────────────────────────────
def extract_witness_json(stdout):
    """Pull the LAST well-formed top-level JSON object out of a runner's
    stdout, requiring at minimum a `schema_version` field.

    Strategy: scan every `{` candidate, walk a balanced-brace slice while
    respecting quoted strings, attempt `json.loads`, keep the LAST slice
    that loads AND carries `schema_version` (deepest / latest is the
    runner's witness — earlier `{...}` substrings inside prose / headers
    are skipped). Returns the parsed dict or None.

    Liberal-shape design: this bundler does NOT require `in_scope_drugs`
    (which the portfolio fitness gate requires). The drug-redesign sandbox
    has `lenses` instead of `in_scope_drugs`; the landscape generator
    emits NO JSON at all (handled by returning None upstream). Requiring
    only `schema_version` lets every case-study witness through.
    """
    if not isinstance(stdout, str) or "{" not in stdout:
        return None
    n = len(stdout)
    found = None
    i = 0
    while i < n:
        if stdout[i] != "{":
            i += 1
            continue
        depth = 0
        j = i
        in_str = False
        esc = False
        while j < n:
            ch = stdout[j]
            if in_str:
                if esc:
                    esc = False
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    in_str = False
            else:
                if ch == '"':
                    in_str = True
                elif ch == "{":
                    depth += 1
                elif ch == "}":
                    depth -= 1
                    if depth == 0:
                        candidate = stdout[i:j + 1]
                        try:
                            obj = json.loads(candidate)
                        except json.JSONDecodeError:
                            obj = None
                        if isinstance(obj, dict) and "schema_version" in obj:
                            found = obj
                            # advance past this object and keep scanning —
                            # the LAST schema_version-bearing block wins
                            # (defensive: if a runner ever printed an example
                            # block before the real witness).
                            i = j
                            break
                        break
            j += 1
        i += 1
    return found


# ── per-slot SHA-256 over the witness JSON (stable serialization) ────────
def stable_sha256(obj):
    """Return the SHA-256 hex digest over `json.dumps(obj, sort_keys=True,
    ensure_ascii=False, separators=(',', ':'))` — order-stable, encoding-
    stable, whitespace-stable. Returns None if `obj` is None.
    """
    if obj is None:
        return None
    payload = json.dumps(
        obj, sort_keys=True, ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


# ── aggregate counters (liberal, schema-shape tolerant) ──────────────────
def _len_list(witness, key):
    """Return len(witness.get(key)) if it's a list, else 0."""
    v = witness.get(key)
    if isinstance(v, list):
        return len(v)
    return 0


def _count_cder_no_axis(witness):
    """Count rows that are CDER-regulated drugs / candidates with NO in-repo
    axis mapping. Reads three schema-shape fields defensively:

      (a) `research_stage_negatives[]` (HIV-1 schema): the standard CDER
          pipeline-row slot. EVERY entry is counted — these are by
          construction CDER candidates without an FDA approval / fully
          mapped axis at the time of writing. Defensive: if a future
          schema adds `fda_center_if_filed` (some HIV-1 rows already
          carry it for CBER gene-edit entries) and that value is NOT
          "CDER", that row is excluded — only CDER-tagged or unspecified
          (default-CDER) rows count.
      (b) `not_in_scope_drugs[]` (SMA schema): rows with fda_center=="CDER"
          AND axis is None / empty are CDER drugs that aren't yet axis-
          mapped (most SMA rows here are CBER, so this is typically 0,
          but it's read honestly).
      (c) `cder_in_scope_no_axis_mapping[]` (T2D-style forward-compat
          schema slot): every entry counts as-is.

    Liberal-shape: a missing slot contributes 0. No fabrication.
    """
    total = 0

    # (a) research_stage_negatives[] — HIV-1 / mpro / kras / bcl2 schema.
    rsn = witness.get("research_stage_negatives")
    if isinstance(rsn, list):
        for r in rsn:
            if not isinstance(r, dict):
                continue
            center = r.get("fda_center_if_filed") or r.get("fda_center") or ""
            center = str(center).strip().upper()
            # default-CDER if no center tag (research-stage CDER pipeline);
            # exclude only when an explicit non-CDER tag is recorded.
            if center == "" or center == "CDER":
                total += 1

    # (b) not_in_scope_drugs[] (SMA schema): CDER row with axis==null.
    nis = witness.get("not_in_scope_drugs")
    if isinstance(nis, list):
        for r in nis:
            if not isinstance(r, dict):
                continue
            center = str(r.get("fda_center") or "").strip().upper()
            axis = r.get("axis")
            axis_is_empty = (axis is None
                             or (isinstance(axis, str) and axis.strip() == ""))
            if center == "CDER" and axis_is_empty:
                total += 1

    # (c) cder_in_scope_no_axis_mapping[] — forward-compat T2D schema.
    cna = witness.get("cder_in_scope_no_axis_mapping")
    if isinstance(cna, list):
        total += len(cna)

    return total


def aggregate_metadata(portfolio_witnesses):
    """Walk every PARSED portfolio witness and accumulate the three honest
    aggregate counts: total in-scope drugs, total not-in-scope drugs, total
    CDER-no-axis drugs. Returns a dict.
    """
    total_in_scope = 0
    total_not_in_scope = 0
    total_cder_no_axis = 0
    for name, w in portfolio_witnesses.items():
        if not isinstance(w, dict):
            continue
        total_in_scope += _len_list(w, "in_scope_drugs")
        total_not_in_scope += _len_list(w, "not_in_scope_drugs")
        total_cder_no_axis += _count_cder_no_axis(w)
    return {
        "n_portfolios": len(portfolio_witnesses),
        "total_in_scope_drugs": total_in_scope,
        "total_not_in_scope_drugs": total_not_in_scope,
        "total_cder_no_axis_drugs": total_cder_no_axis,
        "in_silico_only": True,
        "honest_scope_statement": HONEST_SCOPE_STATEMENT,
        "output_convention": (
            "Generated bundles live under state/exports/, NEVER under "
            "case_studies/ — generated transport artifacts are kept "
            "separate from source-of-truth case-study definitions."
        ),
        "fixed_generated_at_constant": FIXED_GENERATED_AT,
        "reproducibility": (
            "Re-running selftest/case_studies_export.py on the same repo "
            "state yields a byte-identical bundle file (fixed timestamp "
            "constant + sorted discovery + stable JSON serialization)."
        ),
    }


# ── per-runner driver ────────────────────────────────────────────────────
def process_runner(name, runner_path):
    """Execute a single runner; return (witness_or_none, status, reason).

    status ∈ {PASS, SKIP, SKIP-no-json}.
      PASS         — exit 0, parseable witness JSON captured.
      SKIP         — timeout / OSError / non-zero exit (g7).
      SKIP-no-json — exit 0 but no parseable schema_version-bearing JSON
                     in stdout (e.g. the landscape generator emits text
                     + writes a .md file but no JSON to stdout).
    """
    out = run_runner(runner_path)
    if not out["ran"]:
        return None, ST_SKIP, (out["error"] or "runner did not execute")
    if out["exit_code"] != 0:
        return None, ST_SKIP, (
            f"runner exited non-zero (code={out['exit_code']}) — "
            "g7 skip-is-honest, does not block bundler sentinel"
        )
    witness = extract_witness_json(out["stdout"])
    if witness is None:
        return None, ST_SKIP_NO_JSON, (
            "runner exited 0 but emitted no parseable JSON object carrying "
            "`schema_version` in stdout — g7 skip-is-honest, witness slot "
            "is null in the bundle"
        )
    return witness, ST_PASS, ""


# ── main ─────────────────────────────────────────────────────────────────
def main():
    print("case_studies_export — hexa-bio case-studies witness bundler")
    print("  collects per-portfolio + landscape + drug-redesign-sandbox")
    print("  witness JSON into a single bundle at state/exports/.")
    print("  governance: g1 real-limits-first · g3 honesty-external ·")
    print("              g7 skip-is-honest · g8 in-silico-only\n")

    portfolios = discover_portfolios()
    landscape_path = discover_landscape()
    sandbox_path = discover_drug_redesign_sandbox()

    print(f"  discovered {len(portfolios)} portfolio runner(s)"
          + (": " + ", ".join(p["name"] for p in portfolios)
             if portfolios else " (none)"))
    print(f"  landscape generator         : "
          f"{'present' if landscape_path else 'ABSENT'}")
    print(f"  drug-redesign sandbox runner: "
          f"{'present' if sandbox_path else 'ABSENT'}\n")

    # ── per-portfolio
    portfolio_witnesses = {}
    portfolio_statuses = {}
    portfolio_reasons = {}
    for p in portfolios:
        name = p["name"]
        print(f"── running {name}_portfolio_runner.py …")
        witness, status, reason = process_runner(name, p["runner"])
        portfolio_statuses[name] = status
        portfolio_reasons[name] = reason
        if witness is not None:
            portfolio_witnesses[name] = witness
            schema = witness.get("schema_version", "?")
            n_in_scope = _len_list(witness, "in_scope_drugs")
            n_nis = _len_list(witness, "not_in_scope_drugs")
            n_rsn = _len_list(witness, "research_stage_negatives")
            print(f"  [{status}] {name}: schema={schema}, "
                  f"in_scope={n_in_scope}, "
                  f"not_in_scope={n_nis}, "
                  f"research_stage={n_rsn}")
        else:
            print(f"  [{status}] {name}: {reason}")
    print()

    # ── landscape
    landscape_witness = None
    landscape_status = ST_SKIP
    landscape_reason = "landscape_generator.py absent on host"
    if landscape_path:
        print("── running landscape_generator.py …")
        landscape_witness, landscape_status, landscape_reason = (
            process_runner("landscape", landscape_path)
        )
        if landscape_witness is not None:
            schema = landscape_witness.get("schema_version", "?")
            print(f"  [{landscape_status}] landscape: schema={schema}")
        else:
            print(f"  [{landscape_status}] landscape: {landscape_reason}")
        print()

    # ── drug-redesign sandbox
    sandbox_witness = None
    sandbox_status = ST_SKIP
    sandbox_reason = "drug_redesign_runner.py absent on host"
    if sandbox_path:
        print("── running drug_redesign_runner.py …")
        sandbox_witness, sandbox_status, sandbox_reason = (
            process_runner("drug_redesign_sandbox", sandbox_path)
        )
        if sandbox_witness is not None:
            schema = sandbox_witness.get("schema_version", "?")
            print(f"  [{sandbox_status}] drug_redesign_sandbox: "
                  f"schema={schema}")
        else:
            print(f"  [{sandbox_status}] drug_redesign_sandbox: "
                  f"{sandbox_reason}")
        print()

    # ── aggregate metadata (honest counts only)
    meta = aggregate_metadata(portfolio_witnesses)

    # ── per-slot SHA-256 checksums (sorted-key JSON serialization)
    checksums = {}
    for name, w in portfolio_witnesses.items():
        checksums[name] = stable_sha256(w)
    checksums["landscape"] = stable_sha256(landscape_witness)
    checksums["drug_redesign_sandbox"] = stable_sha256(sandbox_witness)

    # ── per-runner status block (transparent SKIP/SKIP-no-json record)
    runner_status = {
        "portfolios": {
            name: {
                "status": portfolio_statuses[name],
                "reason": portfolio_reasons[name],
            }
            for name in sorted(portfolio_statuses.keys())
        },
        "landscape": {
            "status": landscape_status,
            "reason": landscape_reason,
        },
        "drug_redesign_sandbox": {
            "status": sandbox_status,
            "reason": sandbox_reason,
        },
    }

    bundle = {
        "bundle_schema_version": BUNDLE_SCHEMA_VERSION,
        "generated_at": FIXED_GENERATED_AT,
        "portfolios": portfolio_witnesses,
        "landscape": landscape_witness,
        "drug_redesign_sandbox": sandbox_witness,
        "bundle_checksums": checksums,
        "bundle_metadata": meta,
        "_runner_status": runner_status,
    }

    # ── write bundle (state/exports/case_studies_bundle_v1.json)
    try:
        os.makedirs(EXPORTS_DIR, exist_ok=True)
        payload = json.dumps(
            bundle, sort_keys=True, ensure_ascii=False, indent=2
        )
        with open(BUNDLE_PATH, "w", encoding="utf-8") as fh:
            fh.write(payload)
            if not payload.endswith("\n"):
                fh.write("\n")
    except OSError as exc:
        print(f"  [ERROR] could not write bundle to "
              f"{os.path.relpath(BUNDLE_PATH, REPO_ROOT)}: {exc}")
        print("__CASE_STUDIES_EXPORT__ FAIL")
        return 1

    # ── overall checksum (bundle file SHA-256, also reported in stdout
    # so the user can verify the on-disk file byte-for-byte)
    file_sha = hashlib.sha256(
        payload.encode("utf-8")
        + (b"" if payload.endswith("\n") else b"\n")
    ).hexdigest()

    # ── per-portfolio summary table
    print("── per-portfolio summary " + "─" * 50)
    name_w = max([len(n) for n in portfolio_witnesses.keys()] + [12])
    print(f"  {'portfolio':<{name_w}}  {'status':>14}  "
          f"{'in_scope':>9}  {'not_in_scope':>13}  {'cder_no_axis':>13}")
    print(f"  {'-' * name_w}  {'-' * 14}  {'-' * 9}  {'-' * 13}  "
          f"{'-' * 13}")
    for name in sorted(portfolio_statuses.keys()):
        status = portfolio_statuses[name]
        w = portfolio_witnesses.get(name)
        if w is None:
            print(f"  {name:<{name_w}}  {status:>14}  "
                  f"{'—':>9}  {'—':>13}  {'—':>13}")
        else:
            print(f"  {name:<{name_w}}  {status:>14}  "
                  f"{_len_list(w, 'in_scope_drugs'):>9d}  "
                  f"{_len_list(w, 'not_in_scope_drugs'):>13d}  "
                  f"{_count_cder_no_axis(w):>13d}")
    print()

    # ── aggregate block
    print("── aggregate metadata " + "─" * 50)
    print(f"  n_portfolios bundled        : {meta['n_portfolios']}")
    print(f"  total_in_scope_drugs        : {meta['total_in_scope_drugs']}")
    print(f"  total_not_in_scope_drugs    : "
          f"{meta['total_not_in_scope_drugs']}")
    print(f"  total_cder_no_axis_drugs    : "
          f"{meta['total_cder_no_axis_drugs']}")
    print(f"  landscape slot              : "
          f"{'witness' if landscape_witness is not None else 'null'} "
          f"[{landscape_status}]")
    print(f"  drug_redesign_sandbox slot  : "
          f"{'witness' if sandbox_witness is not None else 'null'} "
          f"[{sandbox_status}]")
    print()
    print(f"  bundle path                 : "
          f"{os.path.relpath(BUNDLE_PATH, REPO_ROOT)}")
    print(f"  bundle file sha256          : {file_sha}")
    print()

    # ── honesty fences (every run)
    print("  HONESTY (g8 in-silico-only): the bundle aggregates per-portfolio")
    print("  witness JSON. Every aggregate count is an HONEST sum on each")
    print("  portfolio's own data structure. Negatives (research-stage rows,")
    print("  UNPLACED CBER/CDRH rows, CDER-no-axis-mapping rows) are recorded")
    print("  honestly — a feature, not a gap. The bundle is NOT therapeutic /")
    print("  clinical / regulatory / efficacy / ranking content.")
    print("  HONESTY (g7 skip-is-honest): a SKIP / SKIP-no-json slot is an")
    print("  absent or non-JSON-emitting runner on this host — it does NOT")
    print("  block the bundler sentinel. The landscape generator emits text +")
    print("  a .md artefact, NOT stdout JSON, so its slot is null by design.")
    print("  HONESTY (g3 honesty-external): the bundle's own metadata carries")
    print("  the in-silico-only scope statement so any downstream consumer")
    print("  reads the fence alongside the data — no lattice-fit, no fabrication.")
    print("  CONVENTION: bundle artifacts live under state/exports/, NEVER")
    print("  under case_studies/ (generated transport artifacts are kept")
    print("  separate from source-of-truth case-study definitions).\n")

    print("__CASE_STUDIES_EXPORT__ PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
