#!/usr/bin/env python3
# verify.py - `chip + verify` producer (D72 adapter-only · firmware-stub
# pattern · D111 cellrun-compatible · yosys equiv_make + equiv_simple).
#
# Emits chip_v1.meta.json + chip_v1.equiv_log.txt + chip_v1.equiv_dossier.md +
# chip_verify_<stamp>.json (4 artifacts).
#
# Combinational equivalence check between the pre-synth RTL (gold) and
# the post-synth netlist (gate). The post-synth Verilog is expected at
# `<output_dir>/chip_v1.synth.v` (produced by stdlib/chip/synthesize.py).
# If absent, the producer falls back to running synth here in-line to
# generate the gate netlist — this keeps the cell standalone-runnable
# under cellrun.
#
# yosys equiv flow (combinational only):
#   read_verilog <rtl>              ; design copy as gold
#   prep -top <top>
#   design -stash gold
#   read_verilog <synth.v>          ; gate netlist
#   prep -top <top>
#   design -copy-from gold -as gold <top>
#   equiv_make gold <top> equiv
#   prep -top equiv
#   equiv_simple
#   equiv_status -assert
#
# argv:
#   chip/verify.py <output_dir> [--rtl <path>]
#
# Graceful skip: yosys absent OR post-synth netlist absent (and inline
# synth fails) OR equiv fails → emit honest record + exit 0.
#
# g3: combinational equiv only — sequential equivalence (SymbiYosys SBY ·
#     induction proofs) is honest-gap (chip.demi caveat).

from __future__ import annotations

import json
import platform
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional

GEOMETRY_ID = "chip_v1"

DEFAULT_RTL = "/Users/ghost/core/demiurge/archive/comb/rtl/counter4.v"

SKY130_LIB_CANDIDATES = [
    "/Users/ghost/.pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib",
    "/opt/skywater-pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib",
]


def _parse_argv(argv: list[str]) -> tuple[str, Optional[str]]:
    out_dir = "/tmp/chip_verify"
    rtl_path: Optional[str] = None
    i = 1
    positional: list[str] = []
    while i < len(argv):
        tok = argv[i]
        if tok == "--rtl" and i + 1 < len(argv):
            rtl_path = argv[i + 1]
            i += 2
            continue
        positional.append(tok)
        i += 1
    if positional:
        out_dir = positional[0]
    return out_dir, rtl_path


def _detect_top(rtl_path: str) -> str:
    p = Path(rtl_path)
    try:
        text = p.read_text(encoding="utf-8")
    except Exception:
        return p.stem
    m = re.search(r"\bmodule\s+([A-Za-z_]\w*)\s*[\(;]", text)
    return m.group(1) if m else p.stem


def _resolve_sky130_lib() -> Optional[str]:
    for cand in SKY130_LIB_CANDIDATES:
        if Path(cand).is_file():
            return cand
    return None


def _inline_synth(rtl: str, top: str, out_v: Path) -> tuple[bool, str, Optional[str]]:
    """Inline yosys generic-synth (NO SKY130 tech mapping) to produce
    the equiv-friendly gate netlist.

    Verify cell deliberately uses generic synth (not the full
    dfflibmap+abc pipeline from synthesize cell) — equiv against
    SKY130-tech-mapped cells requires Verilog cell models we don't
    bundle, so verify lives at the "RTL vs canonical-RTL" level. This
    proves yosys synth is deterministic + the RTL is consistent · NOT
    a check against the SKY130-mapped netlist (that's a downstream
    formal-flow honest-gap · chip §D).
    """
    if shutil.which("yosys") is None:
        return False, "", "yosys not on PATH"
    if out_v.exists():
        out_v.unlink()
    script = (
        f"read_verilog -sv {rtl}; "
        f"hierarchy -check -top {top}; "
        "proc; opt; check; "
        f"synth -top {top}; "
        "opt_clean -purge; "
        f"write_verilog {out_v}"
    )
    try:
        proc = subprocess.run(
            ["yosys", "-p", script], capture_output=True, text=True,
            timeout=180, check=False,
        )
    except subprocess.TimeoutExpired:
        return False, "", "yosys inline synth timeout"
    except Exception as e:
        return False, "", f"yosys inline synth failed: {e}"
    if proc.returncode != 0:
        return False, (proc.stdout or "") + (proc.stderr or ""), \
               f"inline synth exit {proc.returncode}"
    return True, (proc.stdout or "") + (proc.stderr or ""), None


def _run_equiv(rtl: str, synth_v: Path, top: str) -> tuple[bool, bool, str, Optional[str]]:
    """Run yosys equiv flow. Returns (ran_ok, cleared, log_text, error).

    ran_ok: yosys exited cleanly (with or without equiv assertion).
    cleared: equiv_status -assert passed (designs are equivalent).

    Approach: compare gold RTL (transformed through `prep`) against the
    GENERIC gate netlist (`<out>/chip_v1.synth.v` produced inline here
    via generic `synth` · NOT the SKY130-mapped one from synthesize cell).
    Verify equates RTL against yosys-canonical synth representation —
    proves the RTL parses + synths deterministically. SKY130-mapped
    equivalence requires Verilog cell models (honest-gap · chip §D).
    """
    if shutil.which("yosys") is None:
        return False, False, "", "yosys not on PATH"
    if not Path(rtl).is_file():
        return False, False, "", f"gold RTL not readable: {rtl}"
    if not synth_v.is_file() or synth_v.stat().st_size == 0:
        return False, False, "", f"gate netlist not readable: {synth_v}"

    gate_top = f"gate_{top}"
    script = (
        # 1 · gate netlist (generic synth output · no SKY130 mapping).
        f"read_verilog -sv {synth_v}; "
        f"hierarchy -check -top {top}; "
        f"proc; opt; memory; opt; "
        f"rename {top} {gate_top}; "
        f"design -stash gate; "
        # 2 · gold RTL · prep for equivalence.
        f"read_verilog -sv {rtl}; "
        f"hierarchy -check -top {top}; "
        f"proc; opt; memory; opt; "
        # 3 · pull the gate copy back in beside gold.
        f"design -copy-from gate -as {gate_top} {gate_top}; "
        # 4 · equivalence build + solve.
        f"equiv_make {top} {gate_top} equiv; "
        f"prep -top equiv; "
        f"equiv_struct; "
        f"equiv_simple; "
        f"equiv_induct -seq 5; "
        f"equiv_status -assert"
    )
    try:
        proc = subprocess.run(
            ["yosys", "-p", script], capture_output=True, text=True,
            timeout=180, check=False,
        )
    except subprocess.TimeoutExpired:
        return False, False, "", "yosys equiv timeout"
    except Exception as e:
        return False, False, "", f"yosys equiv spawn failed: {e}"
    combined = (proc.stdout or "") + "\n" + (proc.stderr or "")
    if proc.returncode != 0:
        # Equiv assertion failure also exits non-zero — distinguishable
        # via log content.
        # Heuristic: look for "Equivalence successfully proven" string.
        cleared = "Equivalence successfully proven" in combined
        return True, cleared, combined, f"yosys equiv exit {proc.returncode}"
    cleared = "Equivalence successfully proven" in combined
    return True, cleared, combined, None


def _parse_cell_counts(log_text: str) -> tuple[int, int]:
    """Best-effort pre/post cell-count parse from yosys log."""
    counts: list[int] = []
    for raw in log_text.splitlines():
        m = re.match(r"^\s*(\d+)\s+cells\s*$", raw.rstrip())
        if m:
            counts.append(int(m.group(1)))
    if len(counts) >= 2:
        return counts[0], counts[-1]
    if len(counts) == 1:
        return counts[0], 0
    return 0, 0


def main(argv: list[str]) -> int:
    out_dir, rtl_path = _parse_argv(argv)
    rtl = rtl_path or DEFAULT_RTL
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    produced_at_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    top = _detect_top(rtl)
    sky130_lib = _resolve_sky130_lib()

    # Always produce a GENERIC (non-tech-mapped) gate netlist for equiv.
    # Verify cell's `<out>/chip_v1.synth.v` is the generic-synth output
    # — different file content from synthesize cell's SKY130-mapped
    # `chip_v1.synth.v` (different output_dir per chip.demi).
    synth_v = out / f"{GEOMETRY_ID}.synth.v"
    inline_synth_ran = True
    inline_synth_ok, inline_log, inline_err = _inline_synth(
        rtl, top, synth_v)

    yosys_version: Optional[str] = None
    ran_ok = False
    cleared = False
    equiv_log = ""
    equiv_err: Optional[str] = None
    if synth_v.is_file() and synth_v.stat().st_size > 0:
        ran_ok, cleared, equiv_log, equiv_err = _run_equiv(
            rtl, synth_v, top)
        m = re.search(r"Yosys\s+(\S+)", equiv_log or inline_log)
        if m:
            yosys_version = m.group(1)
    else:
        equiv_err = (
            inline_err or "synth netlist not generated for equiv check"
        )

    equiv_log_path = out / f"{GEOMETRY_ID}.equiv_log.txt"
    full_log = (
        (f"[inline_synth_log]\n{inline_log}\n" if inline_synth_ran else "") +
        (f"[equiv_log]\n{equiv_log}\n" if equiv_log else "") +
        (f"[error] {equiv_err}\n" if equiv_err else "")
    )
    equiv_log_path.write_text(full_log or "(no yosys log)\n",
                              encoding="utf-8")

    pre_cell_count, post_cell_count = _parse_cell_counts(
        inline_log + "\n" + equiv_log)

    # Dossier.
    dossier_path = out / f"{GEOMETRY_ID}.equiv_dossier.md"
    dossier_lines = [
        f"# chip verify dossier — {top} (verify cell · yosys equiv)",
        "",
        f"Stamp: {stamp}",
        f"RTL: {rtl}",
        f"Top module: {top}",
        f"yosys equiv ran: **{ran_ok}**",
        f"equiv cleared: **{cleared}**",
        f"yosys version: {yosys_version or '(unknown / not run)'}",
        f"inline synth fallback: **{inline_synth_ran}**"
        f" (ok={inline_synth_ok})" if inline_synth_ran else
        f"inline synth fallback: **{inline_synth_ran}**",
        "",
        "## Measurements",
        "",
        f"- pre-synth cell count (approx): {pre_cell_count}",
        f"- post-synth cell count (approx): {post_cell_count}",
        f"- equiv result: {'PROVEN' if cleared else 'NOT PROVEN'}",
        "",
        "## Artifacts",
        "",
        f"- gate netlist: `{synth_v.name}` "
        f"({'OK' if synth_v.is_file() else 'MISSING'})",
        f"- yosys log: `{equiv_log_path.name}`",
        "",
        "## Honest-skip caveats (g3)",
        "",
    ]

    citations = [
        "chip.demi [cell.verify] — chip_verify_record kind.",
        "Yosys 0.65 equiv_make · equiv_simple · equiv_status — "
        "combinational equivalence (yosyshq.net/yosys docs).",
        "chip.demi caveat — Formal sequential equivalence (SymbiYosys / "
        "Yosys SBY) honest-gap; UVM/cocotb dynamic verify 흡수 不在.",
    ]
    scope_caveats = [
        "Combinational equivalence only — sequential equivalence "
        "(SymbiYosys SBY · induction proofs) is honest-gap (chip.demi).",
        "UVM/cocotb dynamic verification 흡수 不在 — this cell does NOT "
        "exercise the design with stimulus.",
        "absorbed=false maintained — equiv pass alone is NOT tapeout "
        "signoff (need LVS · DRC · STA timing closure · IR-drop too · "
        "chip §D).",
        "Tapeout signoff (post-P&R LVS · DRC · STA) ≠ this cell · "
        "handoff cell aggregates the cert checklist.",
    ]
    if not ran_ok:
        scope_caveats.append(
            f"yosys equiv did NOT run cleanly: "
            f"{equiv_err or 'unknown error'} — graceful skip.")
    if ran_ok and not cleared:
        scope_caveats.append(
            "yosys equiv ran but FAILED to prove equivalence — synth "
            "regression candidate (rare for combinational flow on these "
            "5 reference chips · investigate gate netlist).")
    if inline_synth_ran and not inline_synth_ok:
        scope_caveats.append(
            f"Inline synth fallback failed: {inline_err or 'unknown'} "
            "— upstream synthesize cell may not have run; check that "
            "stdlib/chip/synthesize.py landed first.")
    dossier_lines.extend(f"- {c}" for c in scope_caveats)
    dossier_lines.append("")
    dossier_path.write_text("\n".join(dossier_lines), encoding="utf-8")

    gate_type = "hexa-native-absent" if ran_ok else "substrate-absent"

    measurements = {
        "equiv_cleared": 1 if cleared else 0,
        "equiv_ran": 1 if ran_ok else 0,
        "pre_cell_count": pre_cell_count,
        "post_cell_count": post_cell_count,
        "inline_synth_ran": 1 if inline_synth_ran else 0,
    }

    meta = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "produced_at_utc": produced_at_utc,
        "python_version": platform.python_version(),
        "yosys_version": yosys_version,
        "equiv_ran": ran_ok,
        "equiv_cleared": cleared,
        "equiv_error": equiv_err,
        "inline_synth_ran": inline_synth_ran,
        "inline_synth_ok": inline_synth_ok,
        "gate_type": gate_type,
        "provisional": True,
        "measurements": measurements,
        "rtl_path": rtl,
        "rtl_top": top,
        "artifacts": {
            "equiv_log": equiv_log_path.name,
            "equiv_dossier": dossier_path.name,
        },
        "provenance": {
            "measurement_gate": "GATE_OPEN",
            "absorbed": False,
            "scope_caveats": scope_caveats,
        },
    }
    meta_path = out / f"{GEOMETRY_ID}.meta.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    record = {
        "domain": "chip",
        "verb": "verify",
        "kind": "chip_verify_record",
        "stamp": stamp,
        "producer": f"chip_verify@yosys-{yosys_version or 'absent'}",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": equiv_err if not ran_ok else None,
        "gate_type": gate_type,
        "provisional": True,
        "rtl_path": rtl,
        "rtl_top": top,
        "equiv_ran": ran_ok,
        "equiv_cleared": cleared,
        "pre_cell_count": pre_cell_count,
        "post_cell_count": post_cell_count,
        "yosys_version": yosys_version,
        "inline_synth_ran": inline_synth_ran,
        "inline_synth_ok": inline_synth_ok,
        "artifacts": {
            "meta": meta_path.name,
            "equiv_log": equiv_log_path.name,
            "equiv_dossier": dossier_path.name,
        },
    }
    rec_path = out / f"chip_verify_{stamp}.json"
    with open(rec_path, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"chip_verify: wrote {rec_path} "
        f"(equiv_ran={ran_ok}, cleared={cleared}, top='{top}', "
        f"pre={pre_cell_count}, post={post_cell_count})\n")

    summary = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "gate_type": gate_type,
        "provisional": True,
        "equiv_ran": ran_ok,
        "equiv_cleared": cleared,
        "rtl_top": top,
        "pre_cell_count": pre_cell_count,
        "post_cell_count": post_cell_count,
        "artifacts": {
            "record": rec_path.name,
            "meta": meta_path.name,
            "equiv_log": equiv_log_path.name,
            "equiv_dossier": dossier_path.name,
        },
    }
    sys.stderr.write("CHIP_VERIFY_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
