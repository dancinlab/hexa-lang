#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
weave_coating_geometric_only_emitter.py
=======================================

LVAD scenario ⑥ · WEAVE coating · **geometric-only** candidate-sheet emitter
with a hardened **hemocompatibility-refusal guard**.

The point of this emitter is the OPPOSITE of clinical readiness: it consumes
existing cage-assembly JSONL events (geometric / thermodynamic substrate
output) and emits a candidate sheet for hand-off to *external* surface-
chemistry collaborators. It REFUSES to emit if any input row contains
fields that would smuggle a hemocompatibility / thromboresistance claim
into the geometric layer.

Governance anchors (AGENTS.tape, project SSOT):
  - g1   real-limits-first
  - g3   honesty-obligation-external
  - g8   in-silico-only-claim-scope         (PRIMARY refusal anchor)
  - f2   wet-lab-clinical-claim-from-in-silico  (PRIMARY refusal anchor)
  - g11  vendored-snapshots-readonly        (we never edit substrate output)

Scope (what this emitter is):
  * Filter cage-assembly rows by Caspar-Klug T-number ∈ {1, 3, 4}.
  * Stamp every emitted row with a `provenance` field that explicitly says
    surface-chemistry validation is OUTSIDE this repo and that the row is
    NOT a hemocompatibility claim.
  * Selftest with a synthetic 3-row fixture written to /tmp.

Scope (what this emitter is NOT):
  * NOT a hemocompatibility prediction.
  * NOT a thromboresistance score.
  * NOT a ζ-potential / Vroman-effect / ISO 10993-4 surrogate.
  * NOT a re-implementation of the cage simulator — it only consumes its
    output (g11 read-only).

Exit code:
  0  on PASS-path (emit succeeded)        — prints "__WEAVE_GEOMETRIC_ONLY__ PASS"
  2  on refusal-path (overclaim guard)    — prints "__WEAVE_GEOMETRIC_ONLY__ REFUSED"
  1  on any other unexpected error
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any, Iterable

# ---------------------------------------------------------------------------
# Refusal guard — fields that would indicate a hemocompatibility / thrombo-
# resistance claim has already been smuggled into the upstream cage-assembly
# JSONL. If ANY appear in ANY row, we FAIL LOUDLY citing g8/f2.
# ---------------------------------------------------------------------------

_FORBIDDEN_EXACT = {
    "hemocompatibility_score",
    "hemocompatibility",
    "thromboresistance",
    "thromboresistance_score",
    "thromboresistance_index",
    "antithrombotic_score",
    "antithrombogenicity",
    "iso_10993_4_score",
    "iso10993_4_score",
    "platelet_activation_score",
    "fibrinogen_adsorption_score",
    "vroman_score",
    "zeta_potential_pass",
    "clinical_readiness_score",
}

# regex catches any field starting with the listed prefixes (e.g.
# `thromboresistance_v1`, `thromboresistance_estimate_mPa`)
_FORBIDDEN_PREFIX_RE = re.compile(
    r"^("
    r"thromboresistance_"
    r"|hemocompatibility_"
    r"|antithrombotic_"
    r"|antithrombogenicity_"
    r"|iso_?10993_?4_"
    r"|platelet_activation_"
    r"|fibrinogen_adsorption_"
    r"|clinical_readiness_"
    r"|hemocompat_"
    r")",
    re.IGNORECASE,
)


def _is_forbidden_field(key: str) -> bool:
    """True if a field name implies a hemocompatibility/thrombo claim."""
    if key in _FORBIDDEN_EXACT:
        return True
    if _FORBIDDEN_PREFIX_RE.match(key):
        return True
    return False


class OverclaimRefusal(Exception):
    """Raised when input rows contain hemocompatibility-claim fields."""


# ---------------------------------------------------------------------------
# IO
# ---------------------------------------------------------------------------

DEFAULT_INPUT_PATH = (
    Path(__file__).resolve().parent.parent
    / "_python_bridge"
    / "module"
    / "runs"
    / "cage_assembly_events.jsonl"
)

LVAD_RELEVANT_T_NUMBERS = {1, 3, 4}

PROVENANCE_STAMP = (
    "WEAVE geometric-only · surface-chemistry validation OUTSIDE repo · "
    "NOT a hemocompatibility claim"
)


def _read_jsonl(path: Path) -> list[dict[str, Any]]:
    """Read newline-delimited JSON. Tolerates blank lines."""
    rows: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as fh:
        for line_no, raw in enumerate(fh, start=1):
            line = raw.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(
                    f"{path}:{line_no}: invalid JSON ({exc.msg})"
                ) from exc
            if not isinstance(obj, dict):
                raise ValueError(
                    f"{path}:{line_no}: expected JSON object, got {type(obj).__name__}"
                )
            rows.append(obj)
    return rows


def _read_stdin_jsonl() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line_no, raw in enumerate(sys.stdin, start=1):
        line = raw.strip()
        if not line:
            continue
        obj = json.loads(line)
        if not isinstance(obj, dict):
            raise ValueError(
                f"<stdin>:{line_no}: expected JSON object, got {type(obj).__name__}"
            )
        rows.append(obj)
    return rows


# ---------------------------------------------------------------------------
# Core transform
# ---------------------------------------------------------------------------


def _scan_for_overclaim(rows: Iterable[dict[str, Any]]) -> list[tuple[int, str]]:
    """Return list of (row_index, offending_field) found across all rows."""
    hits: list[tuple[int, str]] = []
    for idx, row in enumerate(rows):
        for key in row.keys():
            if _is_forbidden_field(str(key)):
                hits.append((idx, key))
    return hits


def _filter_by_t_number(rows: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for row in rows:
        t = row.get("t_number")
        # Accept ints; reject strings/floats silently — the upstream cage
        # simulator emits integers per Caspar-Klug T = h² + hk + k².
        if isinstance(t, bool):  # bool is a subclass of int — exclude
            continue
        if isinstance(t, int) and t in LVAD_RELEVANT_T_NUMBERS:
            out.append(row)
    return out


def _stamp_row(row: dict[str, Any]) -> dict[str, Any]:
    """Return a new dict = row + provenance stamp + scope refusals."""
    stamped = dict(row)  # shallow copy — we don't mutate input
    stamped["provenance"] = PROVENANCE_STAMP
    stamped["scope"] = "geometric_only"
    stamped["surface_chemistry_validated"] = False
    stamped["hemocompatibility_claim"] = False
    stamped["governance_anchors"] = ["g1", "g3", "g8", "f2", "g11"]
    return stamped


def emit_candidate_sheet(
    rows: list[dict[str, Any]],
    source: str,
) -> dict[str, Any]:
    """Pure function: rows -> candidate-sheet JSON. Raises OverclaimRefusal."""
    hits = _scan_for_overclaim(rows)
    if hits:
        sample = ", ".join(f"row#{i}.{k}" for i, k in hits[:5])
        more = "" if len(hits) <= 5 else f" (+{len(hits) - 5} more)"
        raise OverclaimRefusal(
            "REFUSAL: input rows contain hemocompatibility / thromboresistance "
            "fields that would smuggle a clinical claim into a geometric-only "
            "emitter. This emitter enforces AGENTS.tape g8 (in-silico-only-"
            "claim-scope) and f2 (wet-lab-clinical-claim-from-in-silico). "
            f"Offending: {sample}{more}. "
            "Remediation: strip these fields upstream — surface chemistry / "
            "ISO 10993-4 validation lives OUTSIDE this repo."
        )

    filtered = _filter_by_t_number(rows)
    stamped = [_stamp_row(r) for r in filtered]
    sheet = {
        "emitter": "weave_coating_geometric_only_emitter",
        "emitter_version": "0.1.0",
        "source": source,
        "n_input_rows": len(rows),
        "n_emitted_rows": len(stamped),
        "filter": {
            "t_number_in": sorted(LVAD_RELEVANT_T_NUMBERS),
        },
        "provenance": PROVENANCE_STAMP,
        "scope": "geometric_only",
        "governance_anchors": ["g1", "g3", "g8", "f2", "g11"],
        "refuses_to_imply": [
            "hemocompatibility",
            "thromboresistance",
            "ISO 10993-4 readiness",
            "ζ-potential threshold",
            "Vroman-effect surrogacy",
        ],
        "rows": stamped,
    }
    return sheet


# ---------------------------------------------------------------------------
# Selftest
# ---------------------------------------------------------------------------


def _write_fixture(path: Path) -> None:
    """3-row synthetic fixture covering PASS-path filtering behavior.

    Rows:
      0  T=1 (kept)
      1  T=3 (kept)
      2  T=7 (filtered out — not LVAD-relevant)
    """
    rows = [
        {
            "event": "cage_assembled",
            "t_number": 1,
            "subunit_count": 60,
            "delta_g_kcal_per_mol_per_subunit": -8.4,
            "shell_radius_nm": 12.5,
        },
        {
            "event": "cage_assembled",
            "t_number": 3,
            "subunit_count": 180,
            "delta_g_kcal_per_mol_per_subunit": -10.2,
            "shell_radius_nm": 19.0,
        },
        {
            "event": "cage_assembled",
            "t_number": 7,  # filtered (not in {1,3,4})
            "subunit_count": 420,
            "delta_g_kcal_per_mol_per_subunit": -11.1,
            "shell_radius_nm": 31.5,
        },
    ]
    with path.open("w", encoding="utf-8") as fh:
        for row in rows:
            fh.write(json.dumps(row) + "\n")


def _selftest() -> int:
    ts = int(time.time())
    fixture = Path(f"/tmp/lvad_weave_fixture_{ts}.jsonl")
    _write_fixture(fixture)
    print(f"[selftest] wrote fixture: {fixture}")

    # ----- PASS path -----
    rows = _read_jsonl(fixture)
    assert len(rows) == 3, f"expected 3 input rows, got {len(rows)}"
    sheet = emit_candidate_sheet(rows, source=str(fixture))
    assert sheet["n_input_rows"] == 3
    assert sheet["n_emitted_rows"] == 2, (
        f"expected 2 emitted rows (T=1 and T=3), got {sheet['n_emitted_rows']}"
    )
    for row in sheet["rows"]:
        assert row["provenance"] == PROVENANCE_STAMP
        assert row["t_number"] in LVAD_RELEVANT_T_NUMBERS
        assert row["surface_chemistry_validated"] is False
        assert row["hemocompatibility_claim"] is False
    print("[selftest] PASS-path: 3 input → 2 emitted (T=1, T=3); T=7 filtered.")
    print(
        f"[selftest] provenance stamp present on every emitted row: "
        f"{PROVENANCE_STAMP!r}"
    )

    # ----- REFUSAL path -----
    poisoned = rows + [
        {
            "event": "cage_assembled",
            "t_number": 4,
            "subunit_count": 240,
            "delta_g_kcal_per_mol_per_subunit": -10.8,
            "shell_radius_nm": 22.0,
            # this field MUST trigger the refusal guard (f2/g8):
            "hemocompatibility_score": 0.91,
        },
    ]
    refused = False
    try:
        emit_candidate_sheet(poisoned, source="<selftest-poisoned>")
    except OverclaimRefusal as exc:
        refused = True
        print(f"[selftest] REFUSAL-path fired as required: {exc}")
    assert refused, "REFUSAL-path FAILED to fire on poisoned input"

    # Also check the prefix regex catches a non-exact match:
    refused_prefix = False
    poisoned_prefix = [
        {"t_number": 1, "thromboresistance_estimate_mPa": 12.3},
    ]
    try:
        emit_candidate_sheet(poisoned_prefix, source="<selftest-prefix>")
    except OverclaimRefusal as exc:
        refused_prefix = True
        print(f"[selftest] REFUSAL-path (prefix) fired as required: {exc}")
    assert refused_prefix, "REFUSAL-path (prefix regex) FAILED to fire"

    print("__WEAVE_GEOMETRIC_ONLY__ PASS")
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _build_argparser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description=(
            "WEAVE coating geometric-only candidate-sheet emitter "
            "with hemocompatibility-refusal guard (g8/f2)."
        ),
    )
    p.add_argument(
        "--input",
        type=str,
        default=None,
        help=(
            "Path to cage-assembly JSONL events. "
            f"Default: {DEFAULT_INPUT_PATH} (if it exists). "
            "Use '-' to read from stdin."
        ),
    )
    p.add_argument(
        "--out",
        type=str,
        default=None,
        help="Path to write candidate-sheet JSON. Default: stdout.",
    )
    p.add_argument(
        "--selftest",
        action="store_true",
        help="Run selftest with synthetic 3-row fixture and exit.",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    args = _build_argparser().parse_args(argv)

    if args.selftest:
        return _selftest()

    # Resolve input source
    if args.input == "-":
        rows = _read_stdin_jsonl()
        source = "<stdin>"
    else:
        if args.input is not None:
            in_path = Path(args.input)
        else:
            in_path = DEFAULT_INPUT_PATH
        if not in_path.exists():
            print(
                f"ERROR: input not found: {in_path}\n"
                "Hint: pass --input <path> or pipe JSONL on stdin with --input -, "
                "or run --selftest to verify emitter behavior.",
                file=sys.stderr,
            )
            return 1
        rows = _read_jsonl(in_path)
        source = str(in_path)

    try:
        sheet = emit_candidate_sheet(rows, source=source)
    except OverclaimRefusal as exc:
        print(str(exc), file=sys.stderr)
        print("__WEAVE_GEOMETRIC_ONLY__ REFUSED", file=sys.stderr)
        return 2

    payload = json.dumps(sheet, indent=2, sort_keys=True)
    if args.out:
        Path(args.out).write_text(payload + "\n", encoding="utf-8")
        print(f"wrote: {args.out}")
    else:
        print(payload)

    print("__WEAVE_GEOMETRIC_ONLY__ PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
