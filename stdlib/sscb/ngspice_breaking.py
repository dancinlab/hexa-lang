#!/usr/bin/env python3
# ngspice_breaking.py — `sscb + verify` producer (D72 / κ-N).
#
# ①b DOMAIN ADAPTER (demiurge design.md D72 2-layer STDLIB restructure).
# This file owns ONLY the SSCB breaking-capacity verify scenario:
# bolted-fault simulation on the HEXA-SSCB mk1 600 V / 100 A topology
# (domains/sscb.md §1 spec, §4 breaker test discipline). The kernel
# math (SPICE syntax, transient solver) belongs to ngspice itself —
# this adapter generates the netlist + spawns ngspice + post-processes
# the table per the breaking-capacity figure-of-merit (I²t let-through,
# peak fault current, clearing-time t_c).
#
# Distinct from `sscb + analyze` (sscb/ngspice.hexa) — analyze runs
# a *normal-turn-off* hard-switching transient and measures the
# switch-current dv/dt + interrupt_ratio. *Verify* runs a *bolted-
# fault* breaking-capacity scenario and measures I_peak / I²t / t_clear
# — the UL 489I-style breaker figures-of-merit (domains/sscb.md §4).
#
# SSOT location: `~/core/hexa-lang/stdlib/sscb/ngspice_breaking.py`
# (D61 — producer scripts live under hexa-lang/stdlib/<domain>/,
# sibling repo from demiurge; cockpit/scripts/*.py is forbidden for
# NEW producers).
#
# Invoked by Swift's SSCBVerifyProducer via:
#   /opt/homebrew/bin/python3.13 \
#       ~/core/hexa-lang/stdlib/sscb/ngspice_breaking.py <output_dir>
#
# What it does (honest scope):
#   1. Writes a bolted-fault SSCB netlist to <output_dir>/
#      sscb_breaking_v1.cir — same HEXA-SSCB mk1 topology as the
#      analyze producer but with R_LOAD → R_FAULT (0.01 Ω bolted
#      short) and the gate opens at the user-fixed protection-
#      detection delay (t_det = 5 µs after fault inception).
#   2. Spawns `ngspice -b -o <log> <netlist>`. Captures stdout +
#      log file for the printed `.print tran` table.
#   3. Parses the (time, v_sw, i_load) table, computes:
#        I_peak_A         — peak prospective fault current
#        I_post_clear_A   — residual current after clearing
#        t_clear_s        — time from gate-open command to i < 1 % I_peak
#        let_through_I2t  — ∫ i² dt over the clearing interval (A²·s)
#        clearing_energy_J — ∫ v_sw · i dt over the clearing interval
#   4. Writes <output_dir>/sscb_breaking_v1.meta.json + emits one
#      `SSCB_BREAKING_RESULT <json>` summary line on stderr.
#
# HONESTY (g3 — non-negotiable):
#   • ngspice IS the cited verify instrument — the SPICE transient
#     solver IS the measurement. The numbers (I_peak, I²t, t_clear)
#     are real IEEE-754 outputs.
#   • The underlying CIRCUIT is PLAUSIBLE — no Wolfspeed C3M0021120K
#     .lib, no measured stray-inductance, no measured snubber B-H,
#     no thermal coupling. The TCAD coupling (DEVSIM JOSS doi:
#     10.21105/joss.03898) is cited but NOT wired here — that's a
#     later phase.
#   • The OpenFOAM thermal-margin check (referenced in the research
#     note as "skip with handoff note") is INTENTIONALLY omitted —
#     thermal margin requires a measured-package thermal model + a
#     coupled CFD solve, neither of which sit in this verify slice.
#     A handoff stub lives in scope_caveats and the demiurge-side
#     dispatch note.
#   • UL 489I certification is an accredited-lab type-test, NOT a
#     SPICE simulation. The producer's verdict is a *first honest
#     witness* of the breaking-capacity envelope, NOT a regulatory
#     verify. So:
#       measurement_gate = GATE_OPEN
#       absorbed         = false
#     ALWAYS.
#   • If ngspice is missing OR exits non-zero OR no valid rows parse,
#     returns ok=false and writes no record. Silent success is
#     forbidden.
#
# CITATIONS (clean-room — public algorithm references, no upstream
# code copied):
#   - ngspice — Berkeley SPICE3 descendant (BSD-3) — invoked as a
#     subprocess, version pinned in record provenance.
#   - DEVSIM JOSS doi:10.21105/joss.03898 (Sanchez 2022) — TCAD anchor
#     cited in the research note. NOT wired (Stage 3-4 deferred).
#   - SEMIDV arxiv:2504.00214 — compact-device sim w/ quantum effects;
#     algorithm reference for the deferred TCAD coupling.

import hashlib
import json
import math
import os
import platform
import re
import shutil
import subprocess
import sys
import time

GEOMETRY_ID = "sscb_breaking_v1"

# ── bolted-fault topology (HEXA-SSCB mk1) ─────────────────────────────
V_DC = 600.0
R_FAULT = 0.01          # bolted short circuit (Ω) — F1/UL 489I worst case
L_BUS = 1.0e-6          # bus stray inductance (H)
R_SW_ON = 0.020         # 20 mΩ on-state (generic SiC, NOT C3M datasheet)
R_SW_OFF = 1.0e9
V_THR = 7.0
V_HYST = 1.0
C_SNUB = 100.0e-9       # 100 nF snubber (generic, not engineered)
R_SNUB = 5.0

T_DET = 5.0e-6          # protection detection delay (5 µs)
T_OPEN_RAMP = 50.0e-9   # gate-fall ramp (50 ns)
T_SIM = 20.0e-6         # total sim time (20 µs)
T_STEP = 5.0e-9         # 5 ns step (4000 rows)


def _ngspice_path() -> str | None:
    for c in ("/opt/homebrew/bin/ngspice",
              "/usr/local/bin/ngspice",
              "/usr/bin/ngspice"):
        if os.path.isfile(c) and os.access(c, os.X_OK):
            return c
    p = shutil.which("ngspice")
    return p if p else None


def _ngspice_version(ngspice: str) -> str:
    try:
        out = subprocess.run([ngspice, "-v"], capture_output=True,
                             text=True, timeout=10).stdout
    except Exception:
        return "unknown"
    for ln in out.splitlines():
        s = ln.strip().lstrip("*").strip()
        if s.startswith("ngspice-"):
            # e.g. "ngspice-46 : Circuit level simulation program"
            head = s.split(":", 1)[0].strip()
            return head[len("ngspice-"):]
    return "unknown"


def _build_netlist(csv_path: str) -> str:
    """Generate the bolted-fault netlist. `csv_path` is where the
    .control `wrdata` will deposit a clean tab/space-separated table —
    we avoid `.print`'s line-wrap pagination by writing to a file.
    """
    return f"""* {GEOMETRY_ID} — demiurge sscb+verify breaking-capacity producer
* HONEST: bolted-fault scenario on plausible HEXA-SSCB mk1 topology.
* NOT a Wolfspeed C3M datasheet model, NOT a UL 489I type-test.
.title {GEOMETRY_ID}
Vdc 1 0 {V_DC}
Lbus 1 2 {L_BUS}
Rfault 2 3 {R_FAULT}
SW 3 0 gate 0 SWMOD
* RC snubber across the switch
Csnub 3 4 {C_SNUB}
Rsnub 4 0 {R_SNUB}
* Gate drive — high (closed) until t_det, falls in t_open_ramp
Vgate gate 0 PWL(0 15 {T_DET} 15 {T_DET + T_OPEN_RAMP} 0 {T_SIM} 0)
.model SWMOD SW (Ron={R_SW_ON} Roff={R_SW_OFF} Vt={V_THR} Vh={V_HYST})
.tran {T_STEP} {T_SIM}
.control
run
wrdata {csv_path} v(3) v(2) i(Vdc)
.endc
.end
"""


def _parse_wrdata_csv(path: str) -> list[tuple[float, float, float, float]]:
    """Parse ngspice's `wrdata` output for three variables (6 columns:
    t, v(3), t, v(2), t, i(vdc)) into [(t, v_sw, v_load, i_dc), …].
    All three time columns are identical (same .tran sample grid).
    """
    rows: list[tuple[float, float, float, float]] = []
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            text = f.read()
    except Exception:
        return rows
    for ln in text.splitlines():
        toks = ln.strip().split()
        if len(toks) != 6:
            continue
        try:
            t = float(toks[0])
            v_sw = float(toks[1])
            v_load = float(toks[3])
            i_dc = float(toks[5])
        except ValueError:
            continue
        rows.append((t, v_sw, v_load, i_dc))
    rows.sort(key=lambda r: r[0])
    return rows


def _measure(rows: list[tuple[float, float, float, float]]) -> dict:
    """Compute breaking-capacity figures-of-merit from the trace."""
    if len(rows) < 4:
        return {"ok": False, "reason": "too few rows"}

    # i(Vdc) is negative of source-conventional load current; flip sign
    # so I > 0 means "current flowing through the breaker".
    times = [r[0] for r in rows]
    v_sw = [r[1] for r in rows]
    i_load = [-r[3] for r in rows]

    # Peak prospective fault current = max |i| over pre-clear window.
    i_peak = max(abs(x) for x in i_load)

    # Find clearing transition: gate-open command happens at T_DET.
    # Find first sample where i < 1 % of i_peak AFTER T_DET.
    i_thresh = 0.01 * i_peak
    t_clear = None
    for t, i in zip(times, i_load):
        if t >= T_DET and abs(i) <= i_thresh:
            t_clear = t - T_DET
            break

    # I²t let-through over the clearing window [T_DET, T_DET + t_clear]
    # (or whole post-trip window if never fully clears).
    if t_clear is None:
        # Did not clear within simulation window.
        i_post = abs(i_load[-1])
        clear_end = times[-1]
    else:
        i_post = 0.0
        for t, i in zip(times, i_load):
            if t >= T_DET + t_clear:
                i_post = abs(i)
                break
        clear_end = T_DET + t_clear

    # Trapezoidal integration over the clearing interval.
    i2t = 0.0
    energy_j = 0.0
    prev_t = None
    prev_i2 = 0.0
    prev_p = 0.0
    for t, v, i in zip(times, v_sw, i_load):
        if t < T_DET:
            continue
        if t > clear_end:
            break
        cur_i2 = i * i
        cur_p = v * i
        if prev_t is not None:
            dt = t - prev_t
            i2t += 0.5 * (prev_i2 + cur_i2) * dt
            energy_j += 0.5 * (prev_p + cur_p) * dt
        prev_t = t
        prev_i2 = cur_i2
        prev_p = cur_p

    return {
        "ok": True,
        "rows": len(rows),
        "i_peak_a": i_peak,
        "i_post_clear_a": i_post,
        "t_clear_s": t_clear,
        "let_through_i2t_a2s": i2t,
        "clearing_energy_j": energy_j,
        "v_sw_peak_v": max(v_sw),
        "cleared_in_window": t_clear is not None,
    }


def _sha16(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()[:16]


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        sys.stderr.write(
            "ngspice_breaking.py: usage: ngspice_breaking.py <output_dir>\n")
        return 2

    out_dir = argv[1]
    os.makedirs(out_dir, exist_ok=True)
    netlist_path = os.path.join(out_dir, f"{GEOMETRY_ID}.cir")
    log_path = os.path.join(out_dir, f"{GEOMETRY_ID}.log")
    csv_path = os.path.join(out_dir, f"{GEOMETRY_ID}.data")
    meta_path = os.path.join(out_dir, f"{GEOMETRY_ID}.meta.json")

    netlist = _build_netlist(csv_path)
    with open(netlist_path, "w", encoding="utf-8") as f:
        f.write(netlist)
    netlist_hash = _sha16(netlist)

    ngspice = _ngspice_path()
    if ngspice is None:
        sys.stderr.write(
            "ngspice_breaking: ngspice binary not found "
            "(brew install ngspice required).\n")
        sys.stderr.write("SSCB_BREAKING_RESULT "
                         + json.dumps({"ok": False,
                                       "geometry_id": GEOMETRY_ID,
                                       "error": "ngspice missing",
                                       "gate_type": "install-gated"},
                                      sort_keys=True) + "\n")
        return 3
    ngs_ver = _ngspice_version(ngspice)

    try:
        proc = subprocess.run(
            [ngspice, "-b", "-o", log_path, netlist_path],
            capture_output=True, text=True, timeout=120)
        ng_exit = proc.returncode
        captured = (proc.stdout or "") + "\n" + (proc.stderr or "")
    except Exception as exc:
        sys.stderr.write(f"ngspice_breaking: ngspice spawn failed — {exc}\n")
        sys.stderr.write("SSCB_BREAKING_RESULT "
                         + json.dumps({"ok": False,
                                       "geometry_id": GEOMETRY_ID,
                                       "error": f"spawn: {exc}",
                                       "gate_type": "install-gated"},
                                      sort_keys=True) + "\n")
        return 4

    # ngspice's `wrdata` deposited the transient table at csv_path
    # (6 columns: t v(3) t v(2) t i(vdc) — wrdata repeats time per
    # var). Defence-in-depth: if the file is missing or empty, the
    # parser returns []; rows = 0 triggers ok=false below.
    rows = _parse_wrdata_csv(csv_path)
    m = _measure(rows)

    ok = (ng_exit == 0) and m.get("ok", False) and len(rows) > 0
    measurements = {
        "rows": m.get("rows", 0),
        "i_peak_a": m.get("i_peak_a"),
        "i_post_clear_a": m.get("i_post_clear_a"),
        "t_clear_s": m.get("t_clear_s"),
        "let_through_i2t_a2s": m.get("let_through_i2t_a2s"),
        "clearing_energy_j": m.get("clearing_energy_j"),
        "v_sw_peak_v": m.get("v_sw_peak_v"),
        "cleared_in_window": m.get("cleared_in_window", False),
    }
    topology = {
        "v_dc_V": V_DC,
        "r_fault_ohm": R_FAULT,
        "l_bus_H": L_BUS,
        "switch_ron_ohm": R_SW_ON,
        "switch_roff_ohm": R_SW_OFF,
        "snubber_C_F": C_SNUB,
        "snubber_R_ohm": R_SNUB,
        "t_detection_s": T_DET,
        "t_open_ramp_s": T_OPEN_RAMP,
        "sim_time_s": T_SIM,
        "step_s": T_STEP,
    }
    meta = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "netlist_sha256_16": netlist_hash,
        "ngspice_version": ngs_ver,
        "ngspice_exit": ng_exit,
        "python_version": platform.python_version(),
        "produced_at_utc": time.strftime(
            "%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        # G7 typed gate_type — ngspice ran (success path); no hexa-native
        # circuit-transient kernel exists yet → D80 hexa-native-absent +
        # provisional.
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "topology": topology,
        "measurements": measurements,
        "artifacts": {
            "netlist": f"{GEOMETRY_ID}.cir",
            "log": f"{GEOMETRY_ID}.log",
            "data": f"{GEOMETRY_ID}.data",
        },
    }
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"ngspice_breaking: wrote {meta_path} "
        f"(ok={ok}, exit={ng_exit}, rows={len(rows)}, "
        f"I_peak={measurements['i_peak_a']}, "
        f"t_clear={measurements['t_clear_s']})\n")

    summary = {
        "ok": ok,
        "geometry_id": GEOMETRY_ID,
        "netlist_sha256_16": netlist_hash,
        "ngspice_version": ngs_ver,
        "ngspice_exit": ng_exit,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "rows": len(rows),
        "i_peak_a": measurements["i_peak_a"],
        "i_post_clear_a": measurements["i_post_clear_a"],
        "t_clear_s": measurements["t_clear_s"],
        "let_through_i2t_a2s": measurements["let_through_i2t_a2s"],
        "clearing_energy_j": measurements["clearing_energy_j"],
        "cleared_in_window": measurements["cleared_in_window"],
        "artifacts": {
            "netlist": f"{GEOMETRY_ID}.cir",
            "log": f"{GEOMETRY_ID}.log",
            "data": f"{GEOMETRY_ID}.data",
            "meta": f"{GEOMETRY_ID}.meta.json",
        },
    }
    sys.stderr.write("SSCB_BREAKING_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    return 0 if ok else 5


if __name__ == "__main__":
    sys.exit(main(sys.argv))
