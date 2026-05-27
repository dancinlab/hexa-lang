#!/usr/bin/env python3
# analyze.py - `chip + analyze` producer (D72 adapter-only · firmware-stub
# pattern · D111 cellrun-compatible · yosys stat consumer).
#
# Emits chip_v1.meta.json + chip_v1.yosys_stat.txt +
# chip_v1.analyze_dossier.md + chip_analyze_<stamp>.json (4 artifacts).
#
# Spawns yosys 0.65: `yosys -p "read_verilog <rtl>; hierarchy -top <top>;
# proc; opt; check; stat" 2>&1` and parses the stat output for:
#   - total cell count (post-proc, pre-tech-map)
#   - DFF count (`$dff` / `$_DFF_*`)
#   - combinational count (everything else)
#   - rough area estimate (rule-of-thumb · NOT tech-mapped — that's
#     synthesize cell territory)
#
# argv:
#   chip/analyze.py <output_dir> [--rtl <path>]
#
# Graceful skip: if yosys CLI is not available on PATH the producer
# emits a record with `absorbed=false · gate_type=substrate-absent`
# and exits 0 (honest gap, NOT a crash). Same path if yosys runs but
# returns non-zero (e.g. RTL syntax error · file missing).

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

# Expected post-proc/opt/check cell counts per chip (sanity floor only ·
# yosys output is the actual measurement). Note: pre-tech-map yosys
# collapses multi-bit registers into a single `$sdffe` / `$dff` cell, so
# the dff_count here is "register groups" not "flop bits" — tech-mapped
# DFF count (synthesize cell) gives the per-flop figure.
EXPECTED_CELLS = {
    "counter4":   {"dff_min": 1,  "dff_max": 4,  "total_max": 40},
    "pwm8":       {"dff_min": 1,  "dff_max": 8,  "total_max": 80},
    "uart_tx":    {"dff_min": 4,  "dff_max": 20, "total_max": 200},
    "crc8":       {"dff_min": 1,  "dff_max": 10, "total_max": 100},
    "spi_master": {"dff_min": 4,  "dff_max": 20, "total_max": 200},
}


def _parse_argv(argv: list[str]) -> tuple[str, Optional[str]]:
    out_dir = "/tmp/chip_analyze"
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


def _run_yosys_stat(rtl: str, top: str) -> tuple[bool, str, Optional[str]]:
    """Run `yosys -p "..."`; return (ok, stdout+stderr, error)."""
    if shutil.which("yosys") is None:
        return False, "", "yosys not on PATH"
    if not Path(rtl).is_file():
        return False, "", f"RTL file not readable: {rtl}"
    cmd = [
        "yosys", "-p",
        f"read_verilog -sv {rtl}; hierarchy -check -top {top}; "
        f"proc; opt; check; stat",
    ]
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=60, check=False,
        )
    except subprocess.TimeoutExpired:
        return False, "", "yosys timeout (60 s)"
    except Exception as e:
        return False, "", f"yosys spawn failed: {e}"
    combined = (proc.stdout or "") + "\n" + (proc.stderr or "")
    if proc.returncode != 0:
        return False, combined, f"yosys exit {proc.returncode}"
    return True, combined, None


def _parse_stat(stat_text: str) -> dict:
    """Parse yosys stat output → {total_cells, dff_count, comb_count, by_kind}.

    yosys stat format (single module, post-proc):
      === <module> ===
        4 wires
       16 wire bits
        ...
        2 cells
        1   $add
        1   $logic_not

    Per-kind lines are leading-whitespace, then count, then $kind.
    """
    by_kind: dict[str, int] = {}
    total_cells = 0
    in_cell_block = False
    for raw in stat_text.splitlines():
        line = raw.rstrip()
        # Total `<N> cells` line (e.g. "        2 cells").
        m = re.match(r"^\s*(\d+)\s+cells\s*$", line)
        if m:
            total_cells = int(m.group(1))
            in_cell_block = True
            continue
        if in_cell_block:
            # `<count>   $<kind>` per-kind row.
            m2 = re.match(r"^\s+(\d+)\s+(\$\S+)\s*$", line)
            if m2:
                by_kind[m2.group(2)] = int(m2.group(1))
                continue
            # Blank-ish or summary line → block ended.
            if line.strip() and not line.lstrip().startswith("$"):
                in_cell_block = False

    dff_count = sum(
        v for k, v in by_kind.items()
        if "dff" in k.lower() or "sdff" in k.lower() or "adff" in k.lower()
    )
    comb_count = max(total_cells - dff_count, 0)

    # Rough area estimate — NOT a tech-mapped figure. Each cell ~5 µm²
    # in SKY130_fd_sc_hd footprint average (handwave).
    area_estimate_um2 = total_cells * 5

    return {
        "total_cells": total_cells,
        "dff_count": dff_count,
        "comb_count": comb_count,
        "area_estimate_um2": area_estimate_um2,
        "by_kind": by_kind,
    }


def main(argv: list[str]) -> int:
    out_dir, rtl_path = _parse_argv(argv)
    rtl = rtl_path or DEFAULT_RTL
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    produced_at_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    top = _detect_top(rtl)
    yosys_ok, stat_text, yosys_err = _run_yosys_stat(rtl, top)
    yosys_version: Optional[str] = None
    if yosys_ok:
        m = re.search(r"Yosys\s+(\S+)", stat_text)
        if m:
            yosys_version = m.group(1)

    parsed = _parse_stat(stat_text) if yosys_ok else {
        "total_cells": 0, "dff_count": 0, "comb_count": 0,
        "area_estimate_um2": 0, "by_kind": {},
    }

    expected = EXPECTED_CELLS.get(top, {})
    floor_ok = True
    floor_notes: list[str] = []
    if yosys_ok and expected:
        if not (expected["dff_min"] <= parsed["dff_count"] <= expected["dff_max"]):
            floor_ok = False
            floor_notes.append(
                f"dff_count {parsed['dff_count']} outside expected "
                f"[{expected['dff_min']}, {expected['dff_max']}] for {top}.")
        if parsed["total_cells"] > expected["total_max"]:
            floor_ok = False
            floor_notes.append(
                f"total_cells {parsed['total_cells']} exceeds expected "
                f"max {expected['total_max']} for {top}.")

    # Sibling stat text artifact.
    stat_path = out / f"{GEOMETRY_ID}.yosys_stat.txt"
    stat_path.write_text(
        stat_text or f"(yosys did not run: {yosys_err})\n",
        encoding="utf-8",
    )

    # Dossier.
    dossier_path = out / f"{GEOMETRY_ID}.analyze_dossier.md"
    dossier_lines = [
        f"# chip analyze dossier — {top} (analyze cell · yosys stat consumer)",
        "",
        f"Stamp: {stamp}",
        f"RTL: {rtl}",
        f"Top module: {top}",
        f"yosys ok: **{yosys_ok}**",
        f"yosys version: {yosys_version or '(unknown / not run)'}",
        "",
        "## Measurements",
        "",
        f"- total cells: {parsed['total_cells']}",
        f"- DFF count: {parsed['dff_count']}",
        f"- combinational count: {parsed['comb_count']}",
        f"- area estimate (handwave 5 µm²/cell): {parsed['area_estimate_um2']} µm²",
        "",
        "## Cell breakdown (by yosys kind)",
        "",
    ]
    if parsed["by_kind"]:
        for kind, cnt in sorted(parsed["by_kind"].items()):
            dossier_lines.append(f"- `{kind}` × {cnt}")
    else:
        dossier_lines.append("- (no cells parsed — yosys skipped or stat empty)")
    if expected:
        dossier_lines.extend([
            "",
            "## Sanity floor (per chip family expectations)",
            "",
            f"- DFF expected range: [{expected['dff_min']}, {expected['dff_max']}]",
            f"- total_cells expected max: {expected['total_max']}",
            f"- floor_ok: **{floor_ok}**",
        ])
        if floor_notes:
            dossier_lines.append("")
            dossier_lines.extend(f"- WARN: {n}" for n in floor_notes)
    dossier_lines.extend([
        "",
        "## Honest-skip caveats (g3)",
        "",
    ])

    citations = [
        "chip.demi [cell.analyze] — chip_analyze_record kind.",
        "Yosys 0.65 stat / hierarchy / proc / opt / check commands.",
        "stdlib/yosys/passes.hexa — hexa-native pass library (this Python "
        "cell shims the CLI; native passes are the absorbed substrate).",
    ]
    scope_caveats = [
        "Cell counts are POST-proc/opt/check (generic RTLIL · NOT "
        "tech-mapped) — synthesize cell does the SKY130 mapping.",
        "area_estimate_um2 is a handwave (5 µm²/cell average) · NOT a "
        "tech-mapped figure · ABC + dfflibmap give the real area.",
        "absorbed=false maintained — yosys stat alone is not signoff; "
        "OpenSTA timing + post-P&R area = absorbed=true conditions.",
    ]
    if not yosys_ok:
        scope_caveats.append(
            f"yosys did not run successfully: {yosys_err or 'unknown'} "
            "— graceful skip · cell counts default to 0.")
    if expected and not floor_ok:
        scope_caveats.append(
            "Sanity floor mismatch — counts outside expected ranges; "
            "check for RTL changes or yosys-version regression.")
    dossier_lines.extend(f"- {c}" for c in scope_caveats)
    dossier_lines.append("")
    dossier_path.write_text("\n".join(dossier_lines), encoding="utf-8")

    gate_type = "hexa-native-absent" if yosys_ok else "substrate-absent"
    measurements = {
        "total_cells": parsed["total_cells"],
        "dff_count": parsed["dff_count"],
        "comb_count": parsed["comb_count"],
        "area_estimate_um2": parsed["area_estimate_um2"],
        "yosys_ran": 1 if yosys_ok else 0,
    }

    meta = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "produced_at_utc": produced_at_utc,
        "python_version": platform.python_version(),
        "yosys_version": yosys_version,
        "yosys_ok": yosys_ok,
        "yosys_error": yosys_err,
        "gate_type": gate_type,
        "provisional": True,
        "measurements": measurements,
        "by_kind": parsed["by_kind"],
        "rtl_path": rtl,
        "rtl_top": top,
        "artifacts": {
            "yosys_stat": stat_path.name,
            "analyze_dossier": dossier_path.name,
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
        "verb": "analyze",
        "kind": "chip_analyze_record",
        "stamp": stamp,
        "producer": f"chip_analyze@yosys-{yosys_version or 'absent'}",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": yosys_err if not yosys_ok else None,
        "gate_type": gate_type,
        "provisional": True,
        "rtl_path": rtl,
        "rtl_top": top,
        "yosys_ok": yosys_ok,
        "yosys_version": yosys_version,
        "total_cells": parsed["total_cells"],
        "dff_count": parsed["dff_count"],
        "comb_count": parsed["comb_count"],
        "area_estimate_um2": parsed["area_estimate_um2"],
        "by_kind": parsed["by_kind"],
        "floor_ok": floor_ok,
        "floor_notes": floor_notes,
        "artifacts": {
            "meta": meta_path.name,
            "yosys_stat": stat_path.name,
            "analyze_dossier": dossier_path.name,
        },
    }
    rec_path = out / f"chip_analyze_{stamp}.json"
    with open(rec_path, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"chip_analyze: wrote {rec_path} "
        f"(yosys_ok={yosys_ok}, top='{top}', "
        f"total_cells={parsed['total_cells']}, "
        f"dff_count={parsed['dff_count']})\n")

    summary = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "gate_type": gate_type,
        "provisional": True,
        "yosys_ok": yosys_ok,
        "rtl_top": top,
        "total_cells": parsed["total_cells"],
        "dff_count": parsed["dff_count"],
        "comb_count": parsed["comb_count"],
        "area_estimate_um2": parsed["area_estimate_um2"],
        "floor_ok": floor_ok,
        "artifacts": {
            "record": rec_path.name,
            "meta": meta_path.name,
            "yosys_stat": stat_path.name,
            "analyze_dossier": dossier_path.name,
        },
    }
    sys.stderr.write("CHIP_ANALYZE_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
