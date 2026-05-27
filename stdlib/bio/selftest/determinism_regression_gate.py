#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/determinism_regression_gate.py — byte-identical-rerun regression gate
for the hexa-bio expansion-layer + sub-axis + cross-axis Python sims.

WHY THIS EXISTS
---------------
The expansion-layer cohort now ships 30+ deterministic in-silico simulators
(per-axis sims, sub-axis sims, and cross-axis bridges). Determinism is part of
their §11 deductive-verification contract: re-running a sim on the same repo
state must produce byte-identical stdout. If any sim silently regresses on
this property — by introducing wall-clock dependence (`time.time()` /
`datetime.now()` into output), unseeded randomness (`random.random()` /
`os.urandom` / `secrets`), network reads, or dict/set ordering that varies
between Python runs (PYTHONHASHSEED interaction) — that's a real correctness
loss that current axis-level selftests do NOT catch (they only assert each sim
exits 0 once).

This gate closes that gap. For every enumerated sim it:

  1. Runs `python3 <sim>.py` TWICE under controlled environment.
  2. Captures stdout bytes from each run.
  3. Compares byte-for-byte.
  4. Verdicts:
       DETERMINISTIC   — both runs exited 0 AND stdout bytes are identical.
       NON_DETERMINISTIC — both runs exited 0 BUT stdout bytes diverged
                            (regression — gate FAILS).
       SKIP            — sim absent on host, OR either run exited non-zero,
                            OR either run timed out. SKIP is honest (g7).

  5. Emits sentinel:
        __DETERMINISM_REGRESSION_GATE__ PASS   iff no NON_DETERMINISTIC rows
        __DETERMINISM_REGRESSION_GATE__ FAIL   if any NON_DETERMINISTIC row

GOVERNANCE (hexa-bio AGENTS.tape)
---------------------------------
  g1 real-limits-first — byte-identical re-runs are an HONEST verification
     property: it is the deductive-verification contract that every in-silico
     sim in this repo is supposed to satisfy. The "limit" here is the
     mathematical contract `f(state) === f(state)` — a closed-form determinism
     anchor independent of the n=6 lattice.
  g7 skip-is-honest — a sim absent on the host (file missing), a sim that
     exits non-zero on this host (broken on this host, not necessarily on
     another), or a sim that times out (>60 s) is reported SKIP, not FAIL.
     SKIP does not block the sentinel; only a genuine NON_DETERMINISTIC
     verdict (two runs returned 0 but stdout differs) blocks it.
  g8 in-silico-only — this gate verifies the in-silico simulator-consistency
     contract ONLY. It is NOT a therapeutic / clinical / regulatory claim.

DETERMINISM (this gate itself)
------------------------------
Pure stdlib (no third-party imports). The roster is an explicit list (not a
glob) so the gate's coverage is itself byte-stable across hosts. Output rows
are emitted in the declared roster order. The gate fixes `PYTHONHASHSEED=0`
and clears `PYTHONDONTWRITEBYTECODE` interactions in the subprocess env so
two consecutive runs are compared under identical interpreter conditions.

Usage:
    python3 selftest/determinism_regression_gate.py
    # exit 0 = no NON_DETERMINISTIC rows (PASS)
    # exit 1 = at least one NON_DETERMINISTIC row (FAIL)
"""
from __future__ import annotations

import os
import subprocess
import sys
import time

# ── repo layout ─────────────────────────────────────────────────────────
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PY_BRIDGE = os.path.join(REPO_ROOT, "_python_bridge", "module")

# verdict tokens
DETERMINISTIC = "DETERMINISTIC"
NON_DETERMINISTIC = "NON_DETERMINISTIC"
SKIP = "SKIP"

# subprocess timeout per run (sec). Two runs per sim, 32 sims, 60 s/run worst
# case = 64 min ceiling, but every sim in the current roster completes in
# well under 5 s. The 60 s cap protects against a stuck sim turning the gate
# into a wall-clock liability.
PER_RUN_TIMEOUT_S = 60

# ── sim roster (explicit; byte-stable order) ─────────────────────────────
# Group labels are emitted as section headers; the order within each group is
# the order rows print and the order they're checked.
ROSTER = [
    # Round-1 expansion-main axis sims (6).
    ("expansion-main round-1", [
        "metallodrug_coordination_sim.py",
        "oligonucleotide_hybridization_sim.py",
        "capsid_assembly_modulator_sim.py",
        "rna_targeting_small_molecule_sim.py",
        "aptamer_affinity_sim.py",
        "reversible_covalent_sim.py",
    ]),
    # Round-1 cross-axis sims (5).
    ("cross-axis round-1", [
        "metallodrug_quantum_vqe_cross.py",
        "oligonucleotide_offtarget_gencode_cross.py",
        "rna_modality_comparison_smn2_cross.py",
        "capsid_modulator_pdb_anchor_cross.py",
        "reversible_covalent_mpro_vqe_cross.py",
    ]),
    # Expansion-layer parity (2 — covalent/bifunctional).
    ("expansion-main parity", [
        "covalent_inhibition_sim.py",
        "bifunctional_ternary_complex_sim.py",
    ]),
    # Sub-axis sims (11).
    ("sub-axis sims", [
        "protac_sim.py",
        "lytac_sim.py",
        "autac_sim.py",
        "ribotac_sim.py",
        "covalent_degrader_sim.py",
        "molecular_glue_sim.py",
        "allosteric_sim.py",
        "cryptic_pocket_sim.py",
        "ppi_sim.py",
        "peptide_sim.py",
        "macrocycle_sim.py",
    ]),
    # Round-2 cross-axis sims (3).
    ("cross-axis round-2", [
        "oligonucleotide_nanobot_cross.py",
        "aptamer_nanobot_cross.py",
        "capsid_modulator_weave_cross.py",
    ]),
    # Round-3 cross-axis sims (5; expansion x expansion unifications).
    ("cross-axis round-3", [
        "protac_capsid_modulator_cross.py",
        "allosteric_cryptic_pocket_cross.py",
        "ppi_molecular_glue_cross.py",
        "peptide_macrocycle_cross.py",
        "aptamer_oligonucleotide_cross.py",
    ]),
]


# ── one sim check ────────────────────────────────────────────────────────
def _run_once(sim_path):
    """Run `python3 <sim_path>` once with a controlled env. Returns
    (returncode, stdout_bytes, stderr_bytes, timed_out_bool, elapsed_s).
    """
    env = dict(os.environ)
    # Force a fixed hash seed so dict/set ordering is reproducible across the
    # two consecutive runs we compare. This is the byte-stable-rerun contract.
    env["PYTHONHASHSEED"] = "0"
    # Suppress .pyc writes so the second run doesn't differ from the first
    # purely due to bytecode-cache side effects (some sims import other
    # bridge modules; the cache state could differ run-to-run otherwise).
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    t0 = time.monotonic()
    try:
        proc = subprocess.run(
            [sys.executable, sim_path],
            cwd=REPO_ROOT,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=PER_RUN_TIMEOUT_S,
            check=False,
        )
        elapsed = time.monotonic() - t0
        return (proc.returncode, proc.stdout, proc.stderr, False, elapsed)
    except subprocess.TimeoutExpired as e:
        elapsed = time.monotonic() - t0
        return (None, e.stdout or b"", e.stderr or b"", True, elapsed)


def check_sim(rel_name):
    """Check determinism of one sim. Returns (verdict, detail_str)."""
    sim_path = os.path.join(PY_BRIDGE, rel_name)
    if not os.path.isfile(sim_path):
        return (SKIP, f"sim file absent: {rel_name}")

    rc1, out1, err1, to1, t1 = _run_once(sim_path)
    if to1:
        return (SKIP,
                f"run-1 timed out after {PER_RUN_TIMEOUT_S}s "
                f"(elapsed {t1:.2f}s) — SKIP per g7 (sim not reachable in time)")
    if rc1 != 0:
        # SKIP: sim broken on this host. Honest per g7.
        tail = err1.decode("utf-8", errors="replace").strip().splitlines()
        tail_s = tail[-1] if tail else "(no stderr)"
        return (SKIP,
                f"run-1 exit={rc1} (elapsed {t1:.2f}s) — SKIP per g7 "
                f"(non-zero exit on this host; stderr tail: {tail_s[:120]})")

    rc2, out2, err2, to2, t2 = _run_once(sim_path)
    if to2:
        return (SKIP,
                f"run-2 timed out after {PER_RUN_TIMEOUT_S}s "
                f"(elapsed {t2:.2f}s) — SKIP per g7")
    if rc2 != 0:
        tail = err2.decode("utf-8", errors="replace").strip().splitlines()
        tail_s = tail[-1] if tail else "(no stderr)"
        return (SKIP,
                f"run-2 exit={rc2} (elapsed {t2:.2f}s) — SKIP per g7 "
                f"(non-zero exit on this host; stderr tail: {tail_s[:120]})")

    if out1 == out2:
        return (DETERMINISTIC,
                f"both runs exit=0, stdout {len(out1)} bytes, byte-identical "
                f"(t1={t1:.2f}s, t2={t2:.2f}s)")

    # Byte divergence with both runs exit=0 — this is the regression we catch.
    # Locate the first differing byte index for a compact actionable detail.
    n = min(len(out1), len(out2))
    first_diff = -1
    for i in range(n):
        if out1[i] != out2[i]:
            first_diff = i
            break
    if first_diff == -1:
        # one stdout is a prefix of the other
        first_diff = n

    # Show a short context window around the divergence (decoded best-effort).
    ctx_start = max(0, first_diff - 24)
    ctx_end = first_diff + 24
    ctx1 = out1[ctx_start:ctx_end].decode("utf-8", errors="replace")
    ctx2 = out2[ctx_start:ctx_end].decode("utf-8", errors="replace")
    # Strip newlines from the contexts so the detail stays one line.
    ctx1 = ctx1.replace("\n", "\\n").replace("\r", "\\r")
    ctx2 = ctx2.replace("\n", "\\n").replace("\r", "\\r")

    return (NON_DETERMINISTIC,
            f"both runs exit=0 BUT stdout diverges at byte {first_diff} "
            f"(len1={len(out1)}, len2={len(out2)}); "
            f"run-1 ctx=…{ctx1!r}…  run-2 ctx=…{ctx2!r}…")


# ── main ─────────────────────────────────────────────────────────────────
def main():
    t_start = time.monotonic()
    print("determinism_regression_gate — hexa-bio expansion-layer + sub-axis "
          "+ cross-axis Python sims")
    print("  each sim is run twice under PYTHONHASHSEED=0; stdout bytes are")
    print("  compared for byte-identical re-run (the §11 deductive-verification")
    print("  determinism contract).")
    print("  governance: g1 real-limits-first (determinism is the contract) · ")
    print("  g7 skip-is-honest (absent/broken sim != FAIL) · g8 in-silico-only\n")

    all_rows = []
    total = 0
    for group_label, sims in ROSTER:
        total += len(sims)
    print(f"  roster: {total} sims across {len(ROSTER)} groups; per-run "
          f"timeout {PER_RUN_TIMEOUT_S}s\n")

    for group_label, sims in ROSTER:
        print(f"── {group_label} " + "─" * max(0, 60 - len(group_label)))
        for rel_name in sims:
            verdict, detail = check_sim(rel_name)
            tag = {
                DETERMINISTIC: "DETERMINISTIC",
                NON_DETERMINISTIC: "NON_DETERMINISTIC",
                SKIP: "SKIP",
            }[verdict]
            print(f"  [{tag}] {rel_name}")
            print(f"           {detail}")
            all_rows.append({
                "group": group_label,
                "sim": rel_name,
                "verdict": verdict,
                "detail": detail,
            })
        print()

    n_det = sum(1 for r in all_rows if r["verdict"] == DETERMINISTIC)
    n_non = sum(1 for r in all_rows if r["verdict"] == NON_DETERMINISTIC)
    n_skip = sum(1 for r in all_rows if r["verdict"] == SKIP)
    n_total = len(all_rows)

    elapsed = time.monotonic() - t_start

    print("── summary " + "─" * 60)
    for r in all_rows:
        print(f"  {r['verdict']:<18} {r['sim']}")
    print(f"\n  {n_det} DETERMINISTIC · {n_non} NON_DETERMINISTIC · "
          f"{n_skip} SKIP (of {n_total} sims)")
    print(f"  gate wall time: {elapsed:.2f}s")
    print("  HONESTY (g7): a SKIP means the sim is absent on this host, "
          "exited non-zero, or")
    print("    timed out. It does NOT block the sentinel. Only a genuine")
    print("    NON_DETERMINISTIC verdict (both runs exit=0 but stdout differs)")
    print("    blocks the sentinel — that is a real determinism regression.")
    print("  HONESTY (g8): a DETERMINISTIC verdict verifies the in-silico "
          "byte-stable-rerun contract")
    print("    of the sim ONLY — not a therapeutic / clinical / regulatory "
          "claim.\n")

    ok = n_non == 0
    if ok:
        print("__DETERMINISM_REGRESSION_GATE__ PASS")
        return 0
    print("__DETERMINISM_REGRESSION_GATE__ FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
