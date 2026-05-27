#!/usr/bin/env python3
# synthesize.py - `chip + synthesize` producer (D72 adapter-only ·
# firmware-stub pattern · D111 cellrun-compatible · yosys + ABC + SKY130).
#
# Emits chip_v1.meta.json + chip_v1.synth.v + chip_v1.synth.blif +
# chip_v1.synth_dossier.md + chip_synthesize_<stamp>.json (5 artifacts).
#
# Spawns yosys with the full tech-mapping pipeline:
#   read_verilog -sv <rtl>
#   hierarchy -check -top <top>
#   proc; opt; check
#   synth -top <top>
#   dfflibmap -liberty <sky130.lib>
#   abc -liberty <sky130.lib>
#   opt_clean -purge
#   stat -liberty <sky130.lib>
#   write_verilog <out>/chip_v1.synth.v
#   write_blif    <out>/chip_v1.synth.blif
#
# Parses post-synth stat for:
#   - post-synth cell count (SKY130-mapped)
#   - per-cell-type breakdown (sky130_fd_sc_hd__* prefix)
#   - chip area (µm² · from stat -liberty's "Chip area" line)
#
# argv:
#   chip/synthesize.py <output_dir> [--rtl <path>]
#
# Graceful skip: yosys absent OR SKY130 .lib absent OR yosys exit non-zero
# → emit record with absorbed=false · gate_type=substrate-absent · honest
# error string in skipped_reason. Exit 0 in all cases (cell-run friendly).

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
    out_dir = "/tmp/chip_synthesize"
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


def _run_synth(
    rtl: str, top: str, sky130_lib: str,
    out_v: Path, out_blif: Path,
) -> tuple[bool, str, Optional[str]]:
    """Run the full synth flow via yosys -p."""
    if shutil.which("yosys") is None:
        return False, "", "yosys not on PATH"
    if not Path(rtl).is_file():
        return False, "", f"RTL not readable: {rtl}"
    if not Path(sky130_lib).is_file():
        return False, "", f"SKY130 lib not readable: {sky130_lib}"
    # Truncate-before-exec (memory note guidance — avoid stale artifact
    # masking a synth failure as success).
    for p in (out_v, out_blif):
        if p.exists():
            p.unlink()
    script = (
        f"read_verilog -sv {rtl}; "
        f"hierarchy -check -top {top}; "
        "proc; opt; check; "
        f"synth -top {top}; "
        f"dfflibmap -liberty {sky130_lib}; "
        f"abc -liberty {sky130_lib}; "
        "opt_clean -purge; "
        f"stat -liberty {sky130_lib}; "
        f"write_verilog {out_v}; "
        f"write_blif {out_blif}"
    )
    cmd = ["yosys", "-p", script]
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=180, check=False,
        )
    except subprocess.TimeoutExpired:
        return False, "", "yosys synth timeout (180 s)"
    except Exception as e:
        return False, "", f"yosys spawn failed: {e}"
    combined = (proc.stdout or "") + "\n" + (proc.stderr or "")
    if proc.returncode != 0:
        return False, combined, f"yosys synth exit {proc.returncode}"
    return True, combined, None


def _parse_post_synth_stat(stat_text: str) -> dict:
    """Parse post-synth stat (with `-liberty`).

    Output includes a `Chip area for module '\\<top>': <N>` line and a
    per-cell-type breakdown of `sky130_fd_sc_hd__*` cells.
    """
    cells_by_kind: dict[str, int] = {}
    total_cells = 0
    chip_area = 0.0
    in_cell_block = False
    for raw in stat_text.splitlines():
        line = raw.rstrip()
        # `Chip area for module '\<top>': <float>` (post-stat-liberty).
        m_area = re.search(r"Chip area for module.*?:\s*([\d.]+)", line)
        if m_area:
            try:
                chip_area = float(m_area.group(1))
            except ValueError:
                pass
        # stat -liberty totals line: `<N> <area> cells` (with area column).
        m_total_liberty = re.match(r"^\s*(\d+)\s+[\d.]+\s+cells\s*$", line)
        # plain stat totals line: `<N> cells`.
        m_total_plain = re.match(r"^\s*(\d+)\s+cells\s*$", line)
        if m_total_liberty:
            total_cells = int(m_total_liberty.group(1))
            in_cell_block = True
            continue
        if m_total_plain:
            # Only accept plain total if we haven't seen a liberty total yet
            # (liberty stat is the authoritative post-synth view).
            if total_cells == 0:
                total_cells = int(m_total_plain.group(1))
            in_cell_block = True
            continue
        if in_cell_block:
            # stat -liberty per-kind row: `<N>  <area>  <kind>`.
            m_kind_liberty = re.match(
                r"^\s+(\d+)\s+[\d.]+\s+(\S+)\s*$", line)
            # plain stat per-kind row: `<N>  <kind>` (kind starts with $).
            m_kind_plain = re.match(r"^\s+(\d+)\s+(\$\S+)\s*$", line)
            if m_kind_liberty:
                cnt = int(m_kind_liberty.group(1))
                kind = m_kind_liberty.group(2)
                cells_by_kind[kind] = cnt
                continue
            if m_kind_plain:
                cnt = int(m_kind_plain.group(1))
                kind = m_kind_plain.group(2)
                # only record plain rows if we don't already have liberty entries
                cells_by_kind.setdefault(kind, cnt)
                continue
            if line.strip() and not line.lstrip()[0:1].isdigit():
                in_cell_block = False

    sky130_cells_count = sum(
        v for k, v in cells_by_kind.items() if "sky130_fd_sc_hd" in k
    )
    dff_cells_count = sum(
        v for k, v in cells_by_kind.items()
        if "dff" in k.lower() or "sdf" in k.lower()
    )
    return {
        "post_synth_cells": total_cells,
        "sky130_cells_count": sky130_cells_count,
        "dff_cells_count": dff_cells_count,
        "comb_cells_count": max(total_cells - dff_cells_count, 0),
        "chip_area_um2": chip_area,
        "cells_by_kind": cells_by_kind,
    }


def main(argv: list[str]) -> int:
    out_dir, rtl_path = _parse_argv(argv)
    rtl = rtl_path or DEFAULT_RTL
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    produced_at_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    top = _detect_top(rtl)
    sky130_lib = _resolve_sky130_lib()
    out_v = out / f"{GEOMETRY_ID}.synth.v"
    out_blif = out / f"{GEOMETRY_ID}.synth.blif"
    yosys_log_path = out / f"{GEOMETRY_ID}.yosys_log.txt"

    yosys_version: Optional[str] = None
    ok = False
    log_text = ""
    err: Optional[str] = None
    if sky130_lib is None:
        err = "SKY130 .lib not found on any candidate path"
    else:
        ok, log_text, err = _run_synth(rtl, top, sky130_lib, out_v, out_blif)
        if log_text:
            m = re.search(r"Yosys\s+(\S+)", log_text)
            if m:
                yosys_version = m.group(1)
    yosys_log_path.write_text(
        log_text or f"(yosys did not run: {err})\n",
        encoding="utf-8",
    )

    parsed = _parse_post_synth_stat(log_text) if ok else {
        "post_synth_cells": 0,
        "sky130_cells_count": 0,
        "dff_cells_count": 0,
        "comb_cells_count": 0,
        "chip_area_um2": 0.0,
        "cells_by_kind": {},
    }

    # Confirm sibling artifacts.
    synth_v_exists = out_v.exists() and out_v.stat().st_size > 0
    synth_blif_exists = out_blif.exists() and out_blif.stat().st_size > 0
    if ok and not (synth_v_exists and synth_blif_exists):
        # yosys returned 0 but didn't emit — honest gap.
        ok = False
        err = "yosys exit 0 but synth.v / synth.blif not written"

    # Dossier.
    dossier_path = out / f"{GEOMETRY_ID}.synth_dossier.md"
    dossier_lines = [
        f"# chip synthesize dossier — {top} (synthesize cell · yosys+ABC+SKY130)",
        "",
        f"Stamp: {stamp}",
        f"RTL: {rtl}",
        f"Top module: {top}",
        f"yosys ok: **{ok}**",
        f"yosys version: {yosys_version or '(unknown / not run)'}",
        f"SKY130 lib: `{sky130_lib or '(not found)'}`",
        "",
        "## Post-synth measurements (SKY130-mapped)",
        "",
        f"- post-synth cells: {parsed['post_synth_cells']}",
        f"- sky130_fd_sc_hd cells: {parsed['sky130_cells_count']}",
        f"- DFF cells: {parsed['dff_cells_count']}",
        f"- combinational cells: {parsed['comb_cells_count']}",
        f"- chip area: {parsed['chip_area_um2']:.2f} µm²",
        "",
        "## Cell breakdown (by sky130 kind)",
        "",
    ]
    if parsed["cells_by_kind"]:
        for kind, cnt in sorted(parsed["cells_by_kind"].items()):
            dossier_lines.append(f"- `{kind}` × {cnt}")
    else:
        dossier_lines.append("- (no cells parsed — yosys skipped or stat empty)")
    dossier_lines.extend([
        "",
        "## Artifacts",
        "",
        f"- post-synth Verilog: `{out_v.name}` "
        f"({'OK' if synth_v_exists else 'MISSING'})",
        f"- post-synth BLIF: `{out_blif.name}` "
        f"({'OK' if synth_blif_exists else 'MISSING'})",
        f"- yosys log: `{yosys_log_path.name}`",
        "",
        "## Honest-skip caveats (g3)",
        "",
    ])

    citations = [
        "chip.demi [cell.synthesize] — chip_synthesize_record kind.",
        "Yosys 0.65 synth · dfflibmap · ABC tech-mapping pipeline.",
        "SKY130 PDK (Google + SkyWater · Apache-2.0) — sky130_fd_sc_hd.",
        "ABC (Berkeley · UC Regents) — comb tech mapping engine.",
        "chip.demi caveat — absorbed=true 조건 = stdlib/yosys phase-b + "
        "OpenROAD P&R + Magic DRC + OpenSTA signoff 4종 동시.",
    ]
    scope_caveats = [
        "Synth uses default yosys+ABC scripts · NOT a PPA-tuned recipe · "
        "per-chip-family tuning is Tier-2 work.",
        "Chip area is the yosys stat -liberty figure (cell-area sum) · "
        "NOT a post-P&R area · routing congestion + IO ring + power "
        "grid overhead unaccounted (chip §D honest-gap).",
        "absorbed=false PERMANENTLY at this cell — synth alone is NOT "
        "tapeout signoff (need OpenROAD P&R · Magic DRC · OpenSTA · "
        "LVS · IR-drop · IO ring · power grid · 7-종 동시 per chip §D).",
        "No SDC / timing constraints applied — `target_freq_mhz` from "
        "design cell is informational · OpenSTA-driven timing closure "
        "is downstream.",
    ]
    if not ok:
        scope_caveats.append(
            f"yosys synth did NOT complete: {err or 'unknown error'} "
            "— graceful skip · downstream verify cell will also skip.")
    if sky130_lib is None:
        scope_caveats.append(
            "SKY130 .lib not found locally · candidates tried: " +
            ", ".join(SKY130_LIB_CANDIDATES))
    dossier_lines.extend(f"- {c}" for c in scope_caveats)
    dossier_lines.append("")
    dossier_path.write_text("\n".join(dossier_lines), encoding="utf-8")

    gate_type = "hexa-native-absent" if ok else "substrate-absent"

    measurements = {
        "post_synth_cells": parsed["post_synth_cells"],
        "sky130_cells_count": parsed["sky130_cells_count"],
        "dff_cells_count": parsed["dff_cells_count"],
        "comb_cells_count": parsed["comb_cells_count"],
        "chip_area_um2": parsed["chip_area_um2"],
        "yosys_ran": 1 if ok else 0,
        "sky130_lib_found": 1 if sky130_lib else 0,
    }

    meta = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "produced_at_utc": produced_at_utc,
        "python_version": platform.python_version(),
        "yosys_version": yosys_version,
        "yosys_ok": ok,
        "yosys_error": err,
        "sky130_lib_path": sky130_lib,
        "gate_type": gate_type,
        "provisional": True,
        "measurements": measurements,
        "cells_by_kind": parsed["cells_by_kind"],
        "rtl_path": rtl,
        "rtl_top": top,
        "artifacts": {
            "synth_v": out_v.name,
            "synth_blif": out_blif.name,
            "yosys_log": yosys_log_path.name,
            "synth_dossier": dossier_path.name,
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
        "verb": "synthesize",
        "kind": "chip_synthesize_record",
        "stamp": stamp,
        "producer": f"chip_synthesize@yosys-{yosys_version or 'absent'}",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": err if not ok else None,
        "gate_type": gate_type,
        "provisional": True,
        "rtl_path": rtl,
        "rtl_top": top,
        "yosys_ok": ok,
        "yosys_version": yosys_version,
        "sky130_lib_path": sky130_lib or "",
        "post_synth_cells": parsed["post_synth_cells"],
        "sky130_cells_count": parsed["sky130_cells_count"],
        "dff_cells_count": parsed["dff_cells_count"],
        "comb_cells_count": parsed["comb_cells_count"],
        "chip_area_um2": parsed["chip_area_um2"],
        "cells_by_kind": parsed["cells_by_kind"],
        "synth_v_file": out_v.name,
        "synth_blif_file": out_blif.name,
        "synth_v_exists": synth_v_exists,
        "synth_blif_exists": synth_blif_exists,
        "artifacts": {
            "meta": meta_path.name,
            "synth_v": out_v.name,
            "synth_blif": out_blif.name,
            "yosys_log": yosys_log_path.name,
            "synth_dossier": dossier_path.name,
        },
    }
    rec_path = out / f"chip_synthesize_{stamp}.json"
    with open(rec_path, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"chip_synthesize: wrote {rec_path} "
        f"(yosys_ok={ok}, top='{top}', "
        f"post_synth_cells={parsed['post_synth_cells']}, "
        f"chip_area_um2={parsed['chip_area_um2']:.1f})\n")

    summary = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "gate_type": gate_type,
        "provisional": True,
        "yosys_ok": ok,
        "rtl_top": top,
        "post_synth_cells": parsed["post_synth_cells"],
        "sky130_cells_count": parsed["sky130_cells_count"],
        "dff_cells_count": parsed["dff_cells_count"],
        "chip_area_um2": parsed["chip_area_um2"],
        "synth_v_exists": synth_v_exists,
        "synth_blif_exists": synth_blif_exists,
        "artifacts": {
            "record": rec_path.name,
            "meta": meta_path.name,
            "synth_v": out_v.name,
            "synth_blif": out_blif.name,
            "yosys_log": yosys_log_path.name,
            "synth_dossier": dossier_path.name,
        },
    }
    sys.stderr.write("CHIP_SYNTHESIZE_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
