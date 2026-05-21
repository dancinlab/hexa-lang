#!/usr/bin/env python3
# design.py - `sscb + design` producer (D72 adapter-only · firmware-stub
# pattern · D111 cellrun-compatible · ngspice + KiCad template emit).
#
# Emits an `sscb_v1.meta.json` (sibling meta with `measurements` block for
# D113 cellrun payload flattening / roll-up) plus four sibling artifacts:
#
#   - sscb_design_v1.cir                        — ngspice transient netlist
#   - sscb_design_v1.netlist.kicad_pcb_stub     — KiCad-like footprint sketch
#   - sscb_design_v1.dossier.md                 — human-readable design narrative
#   - sscb_design_<stamp>.json                  — top-level record JSON (Codable mirror)
#
# This is a TEMPLATE-emit design (datasheet binding = placeholder · NO
# actual .lib acquisition) — `absorbed = false` permanently per g3.
# The netlist is an illustrative scaffold derived from `~/core/demiurge/
# domains/sscb.md` §2 DESIGN row (open-source col: KiCad + ngspice · FOSDEM'24
# VDMOS power-MOSFET model reference) + `sscb.demi` [cell.design] caveats.
# Real datasheet binding (Wolfspeed C3M0021120K · IXYS IXDD609SI · etc.)
# is a Tier-2 follow-on (.lib acquisition + bench-validated load + DEVSIM
# TCAD coupling).
#
# Pattern reuse: mirrors `stdlib/sscb/specify.py` (Step 1) + `structure.py`
# (Step 2) envelope shape; netlist construction borrows the `_build_netlist`
# pattern from `stdlib/sscb/ngspice_breaking.py` (verify producer) without
# spawning ngspice — design emits the .cir, downstream analyze/verify cells
# are the actual SPICE invocations.
#
# Citations (domains/sscb.md §2 DESIGN row · open-source col):
#   - KiCad (PCB + embedded ngspice for SPICE) — kicad.org/discover/spice/
#   - ngspice (open SPICE engine) — FOSDEM'24 VDMOS + JFET temp models
#   - sscb.md §2 DESIGN row — "schematic capture + PCB layout + SPICE
#     pre-layout"
#   - sscb.demi caveats — "design pending — 게이트 드라이버 sizing +
#     busbar layout + thermal margin tradeoff producer 미작성 · Synth
#     (femmt magnetics) + Verify (breaking) 사이의 design-space exploration
#     loop가 자연스러운 위치"
#
# D61: substrate SSOT here under hexa-lang/stdlib/sscb/.
# D116: hexa-lang stdlib is the single producer SSOT (sibling repos = docs only).
# g3:  honest. Datasheet bindings = placeholder · netlist is a template
#      scaffold · absorbed=false PERMANENTLY (a netlist without datasheet
#      .lib + bench-validated load is illustrative, not absorption).

from __future__ import annotations

import json
import platform
import sys
import time
from pathlib import Path

GEOMETRY_ID = "sscb_design_v1"
META_ID = "sscb_v1"   # sibling meta uses sscb_v1.meta.json (matches Step 1/2)


# --------------------------------------------------------------------------
# Datasheet placeholder bindings — BOM-node → vendor part class mapping.
# --------------------------------------------------------------------------
# Each binding ties a Step 2 BOM node (component_id) to a SPEC-LEVEL part
# class (vendor part NUMBER candidate · NOT an absorbed .lib). The .lib_url
# field is intentionally a doc citation, NOT a downloaded model file — that
# would require an active vendor login + per-vendor click-through license.
#
# placeholder=true on every binding — datasheet absorption (Wolfspeed C3M
# class .lib bind-out · IXYS gate driver SPICE macro · etc.) is a Tier-2
# fan-out, NOT design verb territory.

def _build_datasheet_bindings() -> list[dict]:
    """Hardcoded BOM-to-datasheet placeholder bindings.

    9 BOM nodes (Step 2 transcription) → 6 are bound to vendor placeholders;
    3 (busbar_input · busbar_dc_link · busbar_output) share the busbar
    rule-of-thumb stray-R binding.
    """
    return [
        {
            "component_id": "sic_switch_stack",
            "vendor_part": "Wolfspeed C3M0021120K",
            "part_class": "1200V SiC MOSFET (TO-247-4L)",
            "lib_url": (
                "wolfspeed.com/products/power/sic-mosfets/"
                "c3m-mosfet-series/ — .lib download requires vendor login."
            ),
            "design_value_summary": (
                "Rds(on) ~21 mΩ @ 25°C · Vds 1200V · Id 100A · TO-247-4L "
                "Kelvin source pin · paralleling count TBD (synthesis sweep)."
            ),
            "placeholder": True,
        },
        {
            "component_id": "gate_driver_ic",
            "vendor_part": "IXYS IXDD609SI",
            "part_class": "9A high-speed gate driver (SOIC-8)",
            "lib_url": (
                "littelfuse.com/products/power-semiconductors/discrete-mosfets/"
                "ixdd609 — datasheet PDF · SPICE macro on vendor request."
            ),
            "design_value_summary": (
                "Vgs drive 0/+15V (SiC threshold ~2.8V) · 9A peak source/sink "
                "· isolated supply Tier-2 (Si8261 candidate)."
            ),
            "placeholder": True,
        },
        {
            "component_id": "snubber",
            "vendor_part": "rule-of-thumb RC + TVS",
            "part_class": "10Ω + 10nF + 1500V TVS clamp",
            "lib_url": (
                "Wolfspeed app note CRD-001 (SiC MOSFET hard-switching "
                "snubber guideline) — sizing rule-of-thumb cited."
            ),
            "design_value_summary": (
                "Rsnub = 10Ω · Csnub = 10nF · Vtvs_clamp ~1500V · sizing "
                "= rule-of-thumb · synthesis sweep + bench measurement needed."
            ),
            "placeholder": True,
        },
        {
            "component_id": "magnetic_limiter",
            "vendor_part": "FEMMT analytic_fallback",
            "part_class": "ferrite coupled inductor (gapped N87)",
            "lib_url": (
                "stdlib/sscb/femmt_sweep.py (synthesize cell · analytic "
                "A_L = OpenMagnetics catalogue + Hagedorn §7.4)."
            ),
            "design_value_summary": (
                "L = 1.118 µH (Step 2 synthesize analytic_fallback) · "
                "gapped N87 core · DC bias derating Tier-2."
            ),
            "placeholder": True,
        },
        {
            "component_id": "cold_plate",
            "vendor_part": "rule-of-thumb liquid plate",
            "part_class": "Cu cold plate (mini-channel · ethylene glycol)",
            "lib_url": (
                "Wolfspeed app note typical R_thja ~0.05 °C/W for "
                "liquid-cooled TO-247-4L (placeholder · NOT measured)."
            ),
            "design_value_summary": (
                "R_thja ~0.05 °C/W (placeholder typical · OpenFOAM CHT "
                "analyze cell = downstream consumer)."
            ),
            "placeholder": True,
        },
        {
            "component_id": "busbars",
            "vendor_part": "Cu busbar — 3mΩ/segment rule-of-thumb",
            "part_class": "stamped Cu (input · DC link · output)",
            "lib_url": (
                "rule-of-thumb stray-R ~3mΩ per busbar segment "
                "(15mm × 1.5mm × 100mm Cu · placeholder · NOT measured)."
            ),
            "design_value_summary": (
                "Rstray ~3mΩ per segment · stray-L = downstream measurement "
                "(loop-area extraction in PCB editor)."
            ),
            "placeholder": True,
        },
    ]


# --------------------------------------------------------------------------
# ngspice netlist template — sample HEXA-SSCB mk1 transient circuit.
# --------------------------------------------------------------------------

def _build_netlist() -> tuple[str, int, int]:
    """Build the template ngspice netlist text.

    Returns (netlist_text, node_count, element_count).
      • node_count   = unique non-zero numeric nodes referenced by elements
      • element_count = lines starting with a SPICE primitive (V/R/L/C/M/D/X)

    The netlist is a transient bolted-fault scaffold:
      Vdc 1500V source → Lbus → SiC switch (VDMOS_SIC placeholder · NCHAN
      VDMOS card · FOSDEM'24 reference) → busbar stray-R → output node →
      load. Snubber (R + C + clamp diode) across the switch. Pulsed gate
      drive from a Vgate PWL source.

    SCOPE: This is a TEMPLATE EMIT — the .MODEL VDMOS_SIC card uses
    PUBLIC-DOMAIN placeholder parameters (Vto / Kp / lambda / etc.), NOT
    Wolfspeed C3M0021120K absorbed coefficients. .TRAN params are
    declared so downstream analyze/verify cells can `ngspice -b` this
    file directly, but THIS producer does NOT spawn ngspice.
    """
    netlist = """* sscb_design_v1 — demiurge sscb+design template emit (Step 3 walkthrough)
* HONEST: ngspice netlist scaffold — VDMOS placeholder coefficients
* (FOSDEM'24 NCHAN VDMOS reference card · NOT absorbed Wolfspeed C3M0021120K).
* Downstream analyze/verify cells consume this .cir via `ngspice -b`.
.title sscb_design_v1 — HEXA-SSCB mk1 design template
*
* ---- Sources ---------------------------------------------------------------
Vdc       1   0   DC 1500
Vload     2   0   PULSE(0 100 1u 10n 10n 4u 5u)
*
* ---- Power path (Step 2 BOM nodes · placeholder values) --------------------
Lbus_in   1   3   100n            ; busbar_input stray-L (rule-of-thumb)
Rbus_in   3   4   3m              ; busbar_input stray-R (~3 mΩ)
* SiC switch stack — Wolfspeed C3M0021120K placeholder via VDMOS_SIC model
M1        4   gate  5   5   VDMOS_SIC
Rbus_dc   5   6   3m              ; busbar_dc_link stray-R
Lcoupled  6   7   1.118u          ; magnetic_limiter (FEMMT analytic_fallback)
Rbus_out  7   8   3m              ; busbar_output stray-R
Rload     8   0   15              ; load — ~100A @ 1500V proxy (rule-of-thumb)
*
* ---- Snubber (rule-of-thumb RC + TVS clamp) --------------------------------
Rsnub     4   9   10              ; snubber R (10 Ω)
Csnub     9   10  10n             ; snubber C (10 nF)
Dtvs      10  0   DTVS_CLAMP      ; TVS clamp (placeholder diode)
*
* ---- Gate drive — IXYS IXDD609SI placeholder pulse -------------------------
Vgate     gate  0   PULSE(0 15 0 50n 50n 1u 5u)
Rg        gate  4   2.5           ; gate resistance (rule-of-thumb)
*
* ---- Thermal probe (analyze-cell hook · cold_plate R_thja 0.05 °C/W) -------
* Note: ngspice cannot solve coupled thermal directly · this is a comment
* hook for the OpenFOAM CHT analyze cell (sscb.md §2 ANALYZE row).
*
* ---- Models (placeholder · FOSDEM'24 VDMOS reference card) -----------------
.MODEL VDMOS_SIC VDMOS NCHAN (VTO=2.8 KP=20 LAMBDA=0.01 RD=0.021 RS=0.01 RG=2.5 CGS=2.5n CGD=0.3n CDS=0.5n)
.MODEL DTVS_CLAMP D (IS=1e-12 BV=1500 IBV=1m)
*
* ---- Analysis decks --------------------------------------------------------
.TRAN 1n 5u
.PROBE V(1) V(4) V(8) I(Vdc) I(Vload)
.PRINT TRAN V(1) V(4) V(8) I(Vdc)
*
.END
"""
    # Count elements (lines starting with V/R/L/C/M/D/X · case-insensitive ·
    # excluding model cards which start with .MODEL).
    element_prefixes = ("V", "R", "L", "C", "M", "D", "X")
    element_count = 0
    nodes_seen: set[str] = set()
    for raw in netlist.splitlines():
        line = raw.strip()
        if not line or line.startswith("*") or line.startswith("."):
            continue
        first = line.split()[0].upper()
        # Strip element-letter to check prefix.
        if first[:1] in element_prefixes:
            element_count += 1
            # nodes are tokens [1] and [2] for two-terminal elements;
            # M-element has 4 nodes (drain gate source bulk). Just collect
            # all alphanumeric tokens that don't look like model names /
            # values · keep this loose — count is approximate but useful.
            toks = line.split()
            for tok in toks[1:5]:
                # Stop at first model-name-looking token (all-letters · upper).
                if tok.replace("_", "").isalpha() and len(tok) > 3:
                    break
                if tok == "0":
                    nodes_seen.add("0")
                else:
                    nodes_seen.add(tok)
    # Exclude pure-numeric value tokens (e.g. "100n", "1500"). Keep only
    # tokens that look like node names: pure digits OR alphanumeric-with-
    # letter-start short names (e.g. "gate").
    node_set = set()
    for n in nodes_seen:
        if n.isdigit() or (n.isalnum() and n[0].isalpha() and len(n) <= 8):
            node_set.add(n)
    return netlist, len(node_set), element_count


# --------------------------------------------------------------------------
# KiCad-like PCB footprint stub — textual skeleton only (NOT a real .kicad_pcb).
# --------------------------------------------------------------------------

def _build_kicad_stub() -> str:
    """Textual sketch of the SSCB PCB layout. NOT a loadable .kicad_pcb —
    full schematic + layout = downstream Tier-2 work (KiCad schematic
    capture + interactive routing).
    """
    return """# sscb_design_v1.netlist.kicad_pcb_stub
# HONEST: textual skeleton · NOT a loadable .kicad_pcb file.
# Full schematic capture + interactive PCB routing = downstream Tier-2.
# Source SSOT for the BOM: stdlib/sscb/structure.py (Step 2 networkx tree).
#
# Footprint placeholders (per Step 2 BOM node):
#
#   (footprint "TO-247-4L"   (at  20  40)  (layer F.Cu)  (ref M1)
#       (descr "Wolfspeed C3M0021120K placeholder — SiC MOSFET die"))
#   (footprint "SOIC-8"      (at  35  35)  (layer F.Cu)  (ref U_GATE)
#       (descr "IXYS IXDD609SI placeholder — gate driver IC"))
#   (footprint "RC1206-0805" (at  25  45)  (layer F.Cu)  (ref R_SNUB+C_SNUB)
#       (descr "snubber RC — 10Ω + 10nF · rule-of-thumb"))
#   (footprint "TVS-DO214"   (at  28  45)  (layer F.Cu)  (ref D_TVS)
#       (descr "TVS clamp — 1500V breakdown · placeholder"))
#   (footprint "TOROID-T106" (at  60  40)  (layer F.Cu)  (ref L_LIM)
#       (descr "magnetic_limiter — 1.118 µH coupled inductor · FEMMT"))
#   (footprint "BUSBAR-CU"   (at  10  40)  (layer F.Cu)  (ref BB_IN)
#       (descr "busbar_input — stamped Cu · ~3 mΩ stray-R"))
#   (footprint "BUSBAR-CU"   (at  40  40)  (layer F.Cu)  (ref BB_DC)
#       (descr "busbar_dc_link — stamped Cu · ~3 mΩ stray-R"))
#   (footprint "BUSBAR-CU"   (at  80  40)  (layer F.Cu)  (ref BB_OUT)
#       (descr "busbar_output — stamped Cu · ~3 mΩ stray-R"))
#   (footprint "COLDPLATE"   (at  50  20)  (layer B.Cu)  (ref CP1)
#       (descr "cold_plate — liquid Cu plate · 0.05 °C/W placeholder"))
#
# Nets (BOM-edge driven · power_path + signal_path from Step 2 DiGraph):
#   (net  1 "VDC+1500")
#   (net  2 "LOAD")
#   (net  4 "DRAIN_M1")
#   (net  5 "BUSBAR_DC")
#   (net  6 "L_LIM_IN")
#   (net  7 "L_LIM_OUT")
#   (net  8 "BUSBAR_OUT")
#   (net  gate "GATE_DRIVE")
#
# Scope caveat (g3): footprint coordinates are illustrative · NOT
# routed · NOT thermally optimized · NOT EMI-shielded. Full PCB
# layout cycle (KiCad schematic + interactive routing + DRC) is
# Tier-2 follow-on, NOT design verb scope.
"""


# --------------------------------------------------------------------------
# Design dossier — human-readable narrative covering 8-10 sections.
# --------------------------------------------------------------------------

def _build_dossier(
    stamp: str,
    bindings: list[dict],
    node_count: int,
    element_count: int,
) -> str:
    lines = [
        "# HEXA-SSCB mk1 — design dossier (design cell template emit)",
        "",
        f"Stamp: {stamp}",
        "Source SSOT: domains/sscb.md §2 DESIGN row (KiCad + ngspice · "
        "open-source col)",
        "",
        "## 1 · Voltage rating",
        "",
        "- DC link: 1500 Vdc max (IEC 60947-2 SSHCB envelope · spec §1).",
        "- Switch Vds: 1200V (Wolfspeed C3M-class placeholder · 25% margin "
        "headroom over DC link is borderline · Tier-2 sweep needed for "
        "transient overshoot).",
        "- TVS clamp: 1500V breakdown placeholder.",
        "",
        "## 2 · Current rating",
        "",
        "- Continuous: ~100A target proxy (1500V / 15Ω load · rule-of-thumb).",
        "- Peak fault: TBD per UL 489I type-test (verify cell's bolted-fault "
        "scenario probes I_peak · I²t).",
        "- Per-die: TBD — paralleling count is a synthesis sweep parameter.",
        "",
        "## 3 · Die paralleling decision",
        "",
        "- Placeholder: 1× C3M0021120K (21 mΩ Rds(on)) — sufficient for "
        "100A continuous WITHOUT paralleling.",
        "- Tier-2 work: thermal-coupled paralleling sweep · current-share "
        "imbalance from gate-loop asymmetry (Kelvin source pin layout).",
        "",
        "## 4 · Gate drive Vgs",
        "",
        "- Vgs: 0 / +15V (SiC threshold ~2.8V · adequate enhancement margin).",
        "- Driver: IXYS IXDD609SI placeholder (9A peak source/sink).",
        "- Rg: 2.5Ω (rule-of-thumb · trade-off between dv/dt and switching "
        "loss · synthesis sweep parameter).",
        "- Isolation: Si8261-class candidate (Tier-2 placeholder).",
        "",
        "## 5 · Snubber sizing",
        "",
        "- Rsnub = 10Ω · Csnub = 10nF · TVS clamp 1500V (rule-of-thumb per "
        "Wolfspeed CRD-001 app note).",
        "- Caveat: snubber is for transient suppression ONLY · NOT "
        "engineered for the specific stray-L of this PCB stack-up · "
        "synthesis sweep + bench measurement needed.",
        "",
        "## 6 · Busbar geometry",
        "",
        "- 3 segments: input · DC link · output.",
        "- Stray-R: ~3 mΩ per segment (15mm × 1.5mm × 100mm Cu rule-of-thumb).",
        "- Stray-L: TBD — KiCad interactive layout + extraction Tier-2.",
        "- Loop area minimization: gate-loop Kelvin source priority · "
        "power-loop secondary · NOT yet routed.",
        "",
        "## 7 · Thermal margin",
        "",
        "- R_thja placeholder: 0.05 °C/W (Wolfspeed typical liquid-cooled "
        "TO-247-4L · NOT measured for THIS stack-up).",
        "- Junction temp budget: T_j_max 175°C - T_ambient 40°C → "
        "ΔT 135°C → P_diss_max ~2700W (single die · liquid plate).",
        "- OpenFOAM CHT analyze cell (sscb.md §2 ANALYZE row) is the "
        "downstream verifier · NOT this cell.",
        "",
        "## 8 · Cert dossier hooks",
        "",
        "- UL 489I 1st ed. (Oct 2025) — SSCB / SSHCB ≤ 1500 Vdc.",
        "- IEC 60947-2 — type-test envelope.",
        "- IEEE C37.x — switchgear family.",
        "- Hooks recorded for handoff verb (Step 4) — type-test scheduling "
        "+ lab-booking artefacts · NOT design cell scope.",
        "",
        "## 9 · Netlist summary",
        "",
        f"- ngspice netlist: `sscb_design_v1.cir` · {node_count} nodes · "
        f"{element_count} elements.",
        "- KiCad PCB stub: `sscb_design_v1.netlist.kicad_pcb_stub` (textual "
        "skeleton · NOT loadable).",
        "",
        "## 10 · Datasheet bindings (placeholder)",
        "",
    ]
    for b in bindings:
        lines.append(
            f"- `{b['component_id']}` → {b['vendor_part']} "
            f"({b['part_class']}) — {b['design_value_summary']}"
        )
    lines.extend([
        "",
        "## Honest-skip caveats (g3)",
        "",
        "- Datasheet bindings = placeholder · actual .lib (Wolfspeed "
        "C3M0021120K · IXYS gate driver SPICE macro · etc.) NOT acquired "
        "· netlist is a template scaffold.",
        "- ngspice transient / breaking is run by analyze / verify cells · "
        "this is netlist template emit ONLY (no SPICE invocation here).",
        "- Snubber · busbar · cold plate values = rule-of-thumb · NOT "
        "optimized · synthesis sweep + bench measurement needed.",
        "- KiCad PCB stub is a textual skeleton · NOT a loadable "
        "`.kicad_pcb` · full schematic + layout cycle = downstream Tier-2 work.",
        "- absorbed = false PERMANENTLY · template netlist is illustrative "
        "scaffold · NOT a measured design.",
        "",
    ])
    return "\n".join(lines)


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    produced_at_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    bindings = _build_datasheet_bindings()
    netlist_text, node_count, element_count = _build_netlist()
    kicad_stub = _build_kicad_stub()

    datasheet_bound_count = sum(1 for b in bindings if b.get("placeholder"))
    placeholder_remaining_count = datasheet_bound_count  # all are placeholders
    simulation_ready = ".TRAN" in netlist_text and ".END" in netlist_text

    # ---- write artifacts ---------------------------------------------------
    netlist_path = out / f"{GEOMETRY_ID}.cir"
    netlist_path.write_text(netlist_text, encoding="utf-8")

    kicad_path = out / f"{GEOMETRY_ID}.netlist.kicad_pcb_stub"
    kicad_path.write_text(kicad_stub, encoding="utf-8")

    dossier = _build_dossier(stamp, bindings, node_count, element_count)
    dossier_path = out / f"{GEOMETRY_ID}.dossier.md"
    dossier_path.write_text(dossier, encoding="utf-8")

    # ---- D113 measurements roll-up ----------------------------------------
    measurements = {
        "netlist_node_count": node_count,
        "netlist_element_count": element_count,
        "datasheet_bound_count": datasheet_bound_count,
        "placeholder_remaining_count": placeholder_remaining_count,
    }

    citations = [
        "KiCad — kicad.org/discover/spice/ (embedded ngspice for PCB SPICE).",
        "ngspice — FOSDEM'24 power-MOSFET VDMOS + JFET temp model "
        "presentation.",
        "domains/sscb.md §2 DESIGN row — KiCad + ngspice open-source col.",
        "sscb.demi [cell.design] caveats — design pending producer note.",
        "Wolfspeed C3M0021120K product page — wolfspeed.com (datasheet · "
        ".lib download requires vendor login).",
        "IXYS IXDD609SI product page — littelfuse.com (gate driver IC).",
    ]
    scope_caveats = [
        "Datasheet bindings = placeholder · actual .lib (Wolfspeed "
        "C3M0021120K · IXYS gate driver SPICE macro · etc.) NOT acquired "
        "· netlist is a template scaffold.",
        "ngspice transient / breaking happens in analyze / verify cells · "
        "this is netlist template emit ONLY (no SPICE invocation here).",
        "Snubber · busbar · cold plate values = rule-of-thumb · NOT "
        "optimized · synthesis sweep + bench measurement needed.",
        "absorbed=false maintained · template netlist is illustrative "
        "scaffold · NOT a measured design.",
        "KiCad PCB stub is a textual skeleton · NOT a loadable "
        "`.kicad_pcb` · full schematic + layout cycle = downstream Tier-2 work.",
    ]

    # Sibling meta.json — D113 cellrun payload flattening source.
    meta = {
        "ok": True,
        "geometry_id": META_ID,
        "produced_at_utc": produced_at_utc,
        "python_version": platform.python_version(),
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "measurements": measurements,
        "datasheet_bindings": bindings,
        "artifacts": {
            "netlist": netlist_path.name,
            "kicad_stub": kicad_path.name,
            "dossier": dossier_path.name,
        },
        "provenance": {
            "measurement_gate": "GATE_OPEN",
            "absorbed": False,
            "scope_caveats": scope_caveats,
        },
    }
    meta_path = out / f"{META_ID}.meta.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    # ---- top-level record JSON (Codable mirror) ---------------------------
    record = {
        "domain": "sscb",
        "verb": "design",
        "kind": "sscb_design_record",
        "stamp": stamp,
        "producer": "sscb_design@template",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": None,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        # Scalar roll-up fields (Codable mirror on cockpit).
        "netlist_file": netlist_path.name,
        "kicad_stub_file": kicad_path.name,
        "dossier_file": dossier_path.name,
        "netlist_node_count": node_count,
        "netlist_element_count": element_count,
        "datasheet_bound_count": datasheet_bound_count,
        "placeholder_remaining_count": placeholder_remaining_count,
        "simulation_ready": simulation_ready,
        "notes": (
            "ngspice netlist + KiCad PCB stub + design dossier template "
            "emit (Step 3 SSCB walkthrough). Datasheet bindings = "
            "placeholder vendor part numbers · NOT absorbed .lib. Snubber "
            "+ busbar + cold plate values = rule-of-thumb. absorbed=false "
            "permanently — template netlist is illustrative, not measured."
        ),
        "artifacts": {
            "meta": meta_path.name,
            "netlist": netlist_path.name,
            "kicad_stub": kicad_path.name,
            "dossier": dossier_path.name,
        },
    }
    rec_path = out / f"sscb_design_{stamp}.json"
    with open(rec_path, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"sscb_design: wrote {rec_path} "
        f"(ok=True, nodes={node_count}, elements={element_count}, "
        f"datasheet_bound={datasheet_bound_count}, "
        f"placeholders={placeholder_remaining_count})\n")

    summary = {
        "ok": True,
        "geometry_id": META_ID,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "netlist_node_count": node_count,
        "netlist_element_count": element_count,
        "datasheet_bound_count": datasheet_bound_count,
        "placeholder_remaining_count": placeholder_remaining_count,
        "simulation_ready": simulation_ready,
        "artifacts": {
            "record": rec_path.name,
            "meta": meta_path.name,
            "netlist": netlist_path.name,
            "kicad_stub": kicad_path.name,
            "dossier": dossier_path.name,
        },
    }
    # SSCB_DESIGN_RESULT marker on stderr — mirrors specify.py /
    # structure.py / ngspice_breaking.py pattern; cellrun and Swift
    # CellrunDispatch consume the merged stdout+stderr stream so either
    # is fine.
    sys.stderr.write("SSCB_DESIGN_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/sscb_design"))
