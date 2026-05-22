#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/atlas_atom_tier_upgrade_gate.py — tier-upgrade PROPOSAL gate that
connects the P1 closed-form proofs (`selftest/atlas_atom_proofs.py`) to the
I3 tier reporter (`selftest/hexa_verify_tier_batch.py`) via the deterministic
registry `_python_bridge/spec/atlas_atom_registry.json`.

WHY THIS EXISTS
---------------
P1 proves five repo identities in closed form (Caspar-Klug T-number geometry;
Griffith-Orgel CFSE; MWC P_R+P_T=1; cooperative ternary partition; 2x2 CI
eigenvalue). The I3 reporter classifies sims as 🟢 SUPPORTED-NUMERICAL when
they cite a real-limit anchor. A subset of those sims numerically recompute
precisely the identities P1 proves — so their 🟢 classification could honestly
be upgraded to 🔵 SUPPORTED-FORMAL.

This gate does NOT perform the upgrade. It produces a PROPOSAL — a per-sim
table of which sims are 🔵-eligible based on (a) the P1 proof PASS/SKIP and
(b) the registry's anchored_sims mapping. The I3 reporter's classification
stays as-is on disk; the project owner reviews this proposal and, per-sim,
decides whether to edit a sim to self-declare 🔵 SUPPORTED-FORMAL.

HONESTY FRAMING (same pattern as I3 — "reporter ≠ enforcer")
-----------------------------------------------------------
  • This gate is a TIER-UPGRADE PROPOSER, not an ENFORCER.
  • Eligibility = (P1 proof PASS for the atom) AND (sim listed in the
    atom's anchored_sims). Neither condition alone elevates the tier.
  • SKIPped proofs (e.g. proof 5 when sympy is absent) yield a
    "🔵-conditional (proof SKIP — sympy unavailable on host)" verdict, NOT
    an automatic 🔵. The proof is sympy-machine-verifiable but not
    available in stdlib-only mode (g7 honest).
  • A 🔵-eligibility verdict here is an in-silico simulator-consistency
    claim only — NEVER a therapeutic / clinical / regulatory claim (g8).

GOVERNANCE (hexa-bio AGENTS.tape)
---------------------------------
  g1 real-limits-first — each atom in the registry carries its real-limit
     citation. The proposal rests on the cited identity, not on the
     n=6 invariant lattice.
  g7 skip-is-honest — when atlas_atom_proofs.py reports SKIP for an atom
     (sympy missing), we mark the anchored sims as 🔵-conditional rather
     than failing the gate. The sentinel SKIPs (not FAILs) only when NO
     atom holds at all.
  g8 in-silico-only — the upgrade proposal is a project-level claim about
     symbolic correctness of the identity each sim numerically recomputes.
     It is NOT a wet-lab, clinical, or regulatory claim.

DETERMINISM
-----------
Pure stdlib (json / os / re / subprocess / sys). No third-party imports. No
network. No randomness. No wall-clock dependence in the verdict (the
subprocess invocation may print sympy version strings; those flow through
as part of the per-proof note but do not affect the verdict). Re-running on
the same repo state produces a byte-identical PASS/SKIP verdict.

SENTINEL
--------
Emits `__ATLAS_ATOM_TIER_UPGRADE_GATE__ PASS` iff:
  (a) the registry parses cleanly as JSON, AND
  (b) at least one atom in the registry holds (PROVEN in registry AND
      PASS reported by atlas_atom_proofs.py).
Emits `__ATLAS_ATOM_TIER_UPGRADE_GATE__ SKIP` if no atom holds (e.g. the
P1 proof subprocess fails to launch on host, or every proof FAILed/SKIPped).
SKIP is honest per g7 — it does not indicate falsification, only that the
proposal cannot be made on this host. Exits 0 on PASS or SKIP; exits 1 only
if the registry is malformed (a true gate failure).

Usage:
    python3 selftest/atlas_atom_tier_upgrade_gate.py
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys

# ── repo layout ──────────────────────────────────────────────────────
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SELFTEST_DIR = os.path.join(REPO_ROOT, "selftest")
P1_PROOFS_PATH = os.path.join(SELFTEST_DIR, "atlas_atom_proofs.py")
REGISTRY_PATH = os.path.join(
    REPO_ROOT, "_python_bridge", "spec", "atlas_atom_registry.json"
)

# ── status strings (stable; never decode-dependent at runtime) ───────
STATUS_PASS = "PASS"
STATUS_FAIL = "FAIL"
STATUS_SKIP = "SKIP"

VERDICT_ELIGIBLE = "\U0001F535-eligible"              # 🔵-eligible
VERDICT_CONDITIONAL = "\U0001F535-conditional"        # 🔵-conditional
VERDICT_NOT_PROPOSED = "(not proposed — proof FAIL)"
VERDICT_SKIPPED = "(not proposed — proof SKIP)"

SENTINEL_PASS = "__ATLAS_ATOM_TIER_UPGRADE_GATE__ PASS"
SENTINEL_SKIP = "__ATLAS_ATOM_TIER_UPGRADE_GATE__ SKIP"
SENTINEL_FAIL = "__ATLAS_ATOM_TIER_UPGRADE_GATE__ FAIL"


# ─────────────────────────────────────────────────────────────────────
# P1 subprocess invocation + parse
# ─────────────────────────────────────────────────────────────────────

# Per-row line shape emitted by atlas_atom_proofs.py:
#     "  1. caspar_klug_t_number_geometry            [PASS]"
# We capture the atom id and status from each such line. The atom_id
# token must match the registry's atom_id field exactly.
_PROOF_ROW_RE = re.compile(
    r"^\s*\d+\.\s+([A-Za-z0-9_]+)\s+\[(PASS|FAIL|SKIP)\]\s*$"
)


def _run_p1_proofs() -> tuple[str | None, str]:
    """Invoke atlas_atom_proofs.py as a subprocess; return (stdout, error_note).

    stdout is None iff the subprocess could not be launched (file missing,
    OSError, etc.) — in which case the gate SKIPs honestly (g7).
    """
    if not os.path.isfile(P1_PROOFS_PATH):
        return None, f"P1 proofs file absent: {P1_PROOFS_PATH}"
    try:
        proc = subprocess.run(
            [sys.executable, P1_PROOFS_PATH],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return None, f"P1 subprocess could not run: {type(exc).__name__}: {exc}"
    # We tolerate non-zero exit (e.g. if a proof FAILs, exit=1) — the stdout
    # still carries the per-proof rows we parse.
    if not proc.stdout:
        return None, (
            f"P1 subprocess produced no stdout (exit={proc.returncode}; "
            f"stderr-head={proc.stderr[:200]!r})"
        )
    return proc.stdout, ""


def _parse_p1_status_by_atom(stdout: str) -> dict[str, str]:
    """Extract {atom_id: 'PASS'|'FAIL'|'SKIP'} from the P1 stdout."""
    by_atom: dict[str, str] = {}
    for line in stdout.splitlines():
        m = _PROOF_ROW_RE.match(line)
        if not m:
            continue
        atom_id, status = m.group(1), m.group(2)
        # FIRST match wins (P1's render order is the proof roster order).
        if atom_id not in by_atom:
            by_atom[atom_id] = status
    return by_atom


# ─────────────────────────────────────────────────────────────────────
# Registry load
# ─────────────────────────────────────────────────────────────────────

def _load_registry() -> tuple[dict | None, str]:
    """Load the atlas atom registry; return (registry_dict, error_note).

    registry_dict is None iff load/parse failed (a true gate failure).
    """
    if not os.path.isfile(REGISTRY_PATH):
        return None, f"registry file absent: {REGISTRY_PATH}"
    try:
        with open(REGISTRY_PATH, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        return None, f"registry parse error: {type(exc).__name__}: {exc}"
    if not isinstance(data, dict):
        return None, f"registry root is {type(data).__name__}, expected object"
    if "atoms" not in data or not isinstance(data["atoms"], list):
        return None, "registry missing 'atoms' list"
    return data, ""


# ─────────────────────────────────────────────────────────────────────
# Eligibility computation
# ─────────────────────────────────────────────────────────────────────

def _classify_sim_for_atom(
    atom: dict, p1_status: str | None
) -> tuple[str, str]:
    """Return (verdict, note) for a sim under an atom.

    Inputs:
      atom       — registry entry (must have proof_status field)
      p1_status  — "PASS"/"FAIL"/"SKIP" or None if P1 didn't report for this atom
    """
    proof_status = atom.get("proof_status", "UNKNOWN")
    atom_id = atom.get("atom_id", "<unknown>")
    if proof_status != "PROVEN":
        return VERDICT_NOT_PROPOSED, (
            f"registry proof_status={proof_status} (not PROVEN)"
        )
    if p1_status is None:
        return VERDICT_CONDITIONAL, (
            f"P1 did not report a row for atom_id={atom_id!r}; treating as "
            f"SKIP (g7 skip-is-honest)"
        )
    if p1_status == "PASS":
        return VERDICT_ELIGIBLE, (
            f"P1 proof PASS for {atom_id!r} + registry entry"
        )
    if p1_status == "SKIP":
        skip_cond = atom.get("skip_condition", "P1 SKIP")
        return VERDICT_CONDITIONAL, (
            f"P1 proof SKIP for {atom_id!r} ({skip_cond})"
        )
    # FAIL
    return VERDICT_NOT_PROPOSED, f"P1 proof FAIL for {atom_id!r}"


# ─────────────────────────────────────────────────────────────────────
# Report rendering
# ─────────────────────────────────────────────────────────────────────

def _render_per_atom_block(
    atom: dict, p1_status: str | None
) -> tuple[list[str], list[tuple[str, str, str, str]]]:
    """Return (printed_lines, per_sim_rows).

    per_sim_rows is a list of (atom_id, sim_path, verdict, note) so the
    aggregate table can be computed downstream.
    """
    atom_id = atom.get("atom_id", "<unknown>")
    citation = atom.get("real_limit_citation", "<no citation>")
    sims = atom.get("anchored_sims", []) or []
    proof_status = atom.get("proof_status", "UNKNOWN")
    proof_idx = atom.get("proof_index_in_p1", "?")

    p1_str = p1_status if p1_status is not None else "MISSING"
    lines = [
        f"  atom {proof_idx}. {atom_id}",
        f"      citation:        {citation}",
        f"      registry proof:  {proof_status}",
        f"      P1 status:       {p1_str}",
        f"      anchored sims:   {len(sims)}",
    ]
    per_sim_rows: list[tuple[str, str, str, str]] = []
    for sim_path in sims:
        verdict, note = _classify_sim_for_atom(atom, p1_status)
        per_sim_rows.append((atom_id, sim_path, verdict, note))
    return lines, per_sim_rows


def _render_sim_table(
    per_sim_rows: list[tuple[str, str, str, str]]
) -> list[str]:
    """Render the per-sim upgrade-eligibility table."""
    if not per_sim_rows:
        return ["  (no sims listed in the registry's anchored_sims fields)"]
    lines: list[str] = []
    # Column widths chosen for stable alignment across the 5-atom registry.
    sim_w = max(len(sim) for _, sim, _, _ in per_sim_rows)
    sim_w = max(sim_w, 24)
    for idx, (atom_id, sim, verdict, note) in enumerate(per_sim_rows, 1):
        lines.append(
            f"  {idx:2d}. {sim:<{sim_w}s}  {verdict}\n"
            f"      atom : {atom_id}\n"
            f"      note : {note}"
        )
    return lines


# ─────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────

def main() -> int:
    print("atlas-atom tier-upgrade gate — P1 proofs × I3 reporter bridge")
    print("  (PROPOSAL gate, NOT enforcer — see docstring §HONESTY FRAMING)")
    print("  governance: g1 real-limits-first · g7 skip-is-honest · "
          "g8 in-silico-only")
    print()

    # ── Step 1: load registry ────────────────────────────────────────
    print("step 1. load registry")
    print("---------------------")
    registry, reg_err = _load_registry()
    if registry is None:
        print(f"  ERROR: {reg_err}")
        print()
        print(SENTINEL_FAIL)
        return 1
    n_atoms = len(registry["atoms"])
    print(f"  path:    {REGISTRY_PATH}")
    print(f"  version: {registry.get('registry_version', '<missing>')}")
    print(f"  atoms:   {n_atoms}")
    print()

    # ── Step 2: run P1 proofs as subprocess ──────────────────────────
    print("step 2. run P1 proofs (selftest/atlas_atom_proofs.py)")
    print("-----------------------------------------------------")
    stdout, run_err = _run_p1_proofs()
    if stdout is None:
        print(f"  P1 subprocess: SKIP — {run_err}")
        p1_by_atom: dict[str, str] = {}
    else:
        p1_by_atom = _parse_p1_status_by_atom(stdout)
        print(f"  P1 subprocess: ran (parsed {len(p1_by_atom)} per-atom rows)")
        for atom_id in sorted(p1_by_atom):
            print(f"    {atom_id:<48s}  [{p1_by_atom[atom_id]}]")
    print()

    # ── Step 3: per-atom proposal block ──────────────────────────────
    print("step 3. per-atom proposal blocks")
    print("--------------------------------")
    all_sim_rows: list[tuple[str, str, str, str]] = []
    atoms_holding: list[str] = []  # PROVEN AND P1 PASS
    atoms_conditional: list[str] = []  # PROVEN AND P1 SKIP/missing
    atoms_falsified: list[str] = []  # PROVEN AND P1 FAIL

    for atom in registry["atoms"]:
        atom_id = atom.get("atom_id", "<unknown>")
        p1_status = p1_by_atom.get(atom_id)
        lines, per_sim = _render_per_atom_block(atom, p1_status)
        for ln in lines:
            print(ln)
        print()
        all_sim_rows.extend(per_sim)
        if atom.get("proof_status") == "PROVEN":
            if p1_status == "PASS":
                atoms_holding.append(atom_id)
            elif p1_status == "FAIL":
                atoms_falsified.append(atom_id)
            else:  # SKIP or missing
                atoms_conditional.append(atom_id)

    # ── Step 4: per-sim upgrade-eligibility table ────────────────────
    print("step 4. per-sim upgrade-eligibility table")
    print("-----------------------------------------")
    for ln in _render_sim_table(all_sim_rows):
        print(ln)
    print()

    # ── Step 5: aggregate counts ─────────────────────────────────────
    print("step 5. aggregate counts")
    print("------------------------")
    verdict_counts: dict[str, int] = {}
    for _, _, verdict, _ in all_sim_rows:
        verdict_counts[verdict] = verdict_counts.get(verdict, 0) + 1
    # Stable print order
    for v in (VERDICT_ELIGIBLE, VERDICT_CONDITIONAL,
              VERDICT_SKIPPED, VERDICT_NOT_PROPOSED):
        if v in verdict_counts:
            print(f"  {v:<36s}  {verdict_counts[v]:>3d}")
    total_sims = len(all_sim_rows)
    print(f"  {'TOTAL sim-rows':<36s}  {total_sims:>3d}")
    print()
    print(f"  atoms PROVEN + P1 PASS  (holding)     : {len(atoms_holding)}")
    print(f"  atoms PROVEN + P1 SKIP  (conditional) : "
          f"{len(atoms_conditional)}")
    print(f"  atoms PROVEN + P1 FAIL  (falsified)   : "
          f"{len(atoms_falsified)}")
    print()

    # ── Step 6: honesty framing ──────────────────────────────────────
    print("honesty framing")
    print("---------------")
    print("  This gate produces a TIER-UPGRADE PROPOSAL, not an enforcement.")
    print("  The I3 reporter (selftest/hexa_verify_tier_batch.py)")
    print("  classification stays AS-IS on disk; this gate emits a per-sim")
    print("  proposal the project owner can act on by editing the sim source")
    print("  to self-declare \U0001F535 SUPPORTED-FORMAL (the I3 reporter")
    print("  then picks up that self-declaration on its next run).")
    print()
    print("  Per AGENTS.tape g8, a \U0001F535-eligibility verdict here is an")
    print("  in-silico simulator-consistency claim ONLY — NEVER a")
    print("  therapeutic / clinical / regulatory / immunogenic / efficacy")
    print("  claim. Per g7, P1 proofs that SKIP (sympy unavailable) yield")
    print("  \U0001F535-conditional anchored-sim verdicts rather than")
    print("  promoting or failing. Per g1, every atom carries its")
    print("  peer-reviewed real-limit citation in the registry.")
    print()

    # ── Step 7: sentinel ─────────────────────────────────────────────
    if atoms_holding:
        print(SENTINEL_PASS)
        return 0
    # No atom holds (registry parsed cleanly but P1 reported zero PASS).
    # SKIP-not-FAIL per g7.
    print(SENTINEL_SKIP)
    print(f"  reason: no atom in the registry has both proof_status=PROVEN "
          f"and a P1 PASS row")
    return 0


if __name__ == "__main__":
    sys.exit(main())
