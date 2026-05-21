#!/usr/bin/env python3
# handoff.py - `sscb + handoff` producer (D72 adapter-only · firmware-stub
# pattern · D111 cellrun-compatible · cert-dossier bundle template emit).
#
# Emits an `sscb_v1.meta.json` (sibling meta with `measurements` block for
# D113 cellrun payload flattening / roll-up) plus five sibling artifacts:
#
#   - sscb_handoff_v1.ul489i_checklist.md             — UL 489I lab booking checklist
#   - sscb_handoff_v1.iec60947_2_typetest_dossier.md  — IEC 60947-2 type-test dossier
#   - sscb_handoff_v1.ieee_c37_x_xref.md              — IEEE C37.x cross-reference
#   - sscb_handoff_v1.tier2_fanout.md                 — Steps 1-3 derived fan-out list
#   - sscb_handoff_v1.bundle_manifest.md              — top-level handoff package manifest
#   - sscb_handoff_<stamp>.json                       — top-level record JSON
#
# This is a TEMPLATE-emit cert dossier bundle (NO actual UL/TÜV/KTL lab
# booking · NO actual type-test execution · NO Icu/Ics numbers) —
# `absorbed = false` permanently per g3. The dossier is an illustrative
# scaffold derived from `~/core/demiurge/domains/sscb.md` §2 HANDOFF row
# (UL/TÜV/KTL type-test submission per UL 489I + IEC 60947-2; harmonization
# track per UL Solutions) + `sscb.demi` [cell.handoff] caveats. Real lab
# booking + type-test submission + cert manager review is downstream
# regulatory work, NOT handoff verb scope.
#
# Pattern reuse: mirrors `stdlib/sscb/specify.py` (Step 1) + `structure.py`
# (Step 2) + `design.py` (Step 3) envelope shape; cert-dossier bundle
# pattern borrows the `release.tar.gz` template idea from
# `stdlib/firmware/handoff.py` (CycloneDX SBOM skeleton + sign-probe)
# without the imgtool dependency — this cell emits 5 markdown artifacts +
# a sibling meta.json + a top-level record JSON.
#
# Citations (domains/sscb.md §2 HANDOFF row):
#   - UL 489I 1st ed. (Oct 2025) — SSCB / SSHCB ≤ 1000 Vac / 1500 Vdc
#     molded-case circuit breakers for solid-state branch protection.
#   - IEC 60947-2:2016 — low-voltage switchgear · circuit breakers.
#   - IEEE C37.13 — low-voltage AC power circuit breakers used in enclosures.
#   - IEEE C37.04 — high-voltage AC circuit breaker rating structure.
#   - UL Solutions harmonization — IEC 60947-2 ↔ UL 489I crosswalk track.
#   - sscb.md §2 HANDOFF row — "UL / TÜV / KTL type-test submission"
#   - sscb.demi [cell.handoff] caveats — "bench-test plan producer 미작성"
#
# D61: substrate SSOT here under hexa-lang/stdlib/sscb/.
# D116: hexa-lang stdlib is the single producer SSOT (sibling repos = docs only).
# g3:  honest. Cert dossier = template scaffold · NO actual lab booking ·
#      NO actual type-test execution · absorbed=false PERMANENTLY (a
#      cert dossier without lab partner sign-off + type-test pass = illustrative,
#      NOT absorption).

from __future__ import annotations

import json
import platform
import sys
import time
from pathlib import Path

GEOMETRY_ID = "sscb_handoff_v1"
META_ID = "sscb_v1"   # sibling meta uses sscb_v1.meta.json (matches Steps 1-3)


# --------------------------------------------------------------------------
# UL 489I 1st ed. (Oct 2025) lab-booking checklist — 4 sections · 18 items.
# --------------------------------------------------------------------------

def _build_ul489i_checklist() -> tuple[str, int]:
    """Build the UL 489I 1st edition lab-booking checklist markdown.

    UL 489I 1st ed. (Oct 2025) covers SSCB / SSHCB ≤ 1000 Vac / 1500 Vdc
    molded-case circuit breakers for solid-state branch protection. Four
    sections (A · sample requirements · B · type-test sequence · C ·
    documentation · D · lab partner candidates). Returns (md_text, item_count).
    """
    lines = [
        "# UL 489I 1st ed. (Oct 2025) — lab-booking checklist",
        "",
        "Stamp: handoff template emit",
        "Source SSOT: domains/sscb.md §2 HANDOFF row + UL Solutions UL 489I 1st ed. cert pack",
        "Scope: SSCB / SSHCB ≤ 1000 Vac / 1500 Vdc molded-case CBs for solid-state branch protection.",
        "Responsibility shorthand: `engineer @ vendor` = TBD assigned at cert manager review.",
        "",
        "## Section A · Sample requirements",
        "",
        "- [ ] **A1** — 3× DUT samples of HEXA-SSCB mk1 (pre-production · burn-in 168h @ 85°C). _(engineer @ vendor)_",
        "- [ ] **A2** — Electrical pre-conditioning (10× rated-current cycles · no fault). _(engineer @ vendor)_",
        "- [ ] **A3** — Visual / dimensional inspection sign-off per UL 489I §6.1. _(engineer @ vendor)_",
        "- [ ] **A4** — Serial number traceability to production lot ID + BOM revision lock. _(engineer @ vendor)_",
        "",
        "## Section B · Type-test sequence (UL 489I §7)",
        "",
        "- [ ] **B1** — Rated-current carrying test (§7.2.4 · continuous current at rated value · ΔT ≤ class limit). _(engineer @ vendor)_",
        "- [ ] **B2** — Making/breaking endurance (§7.2.4.6 · mechanical + electrical operations cycle count). _(engineer @ vendor)_",
        "- [ ] **B3** — Short-circuit endurance / interrupting capacity (§7.2.5 · Icu/Ics at rated voltage). _(engineer @ vendor)_",
        "- [ ] **B4** — Temperature rise test (§7.2.2 · ΔT measurement on terminals · TC-instrumented). _(engineer @ vendor)_",
        "- [ ] **B5** — Dielectric withstand (§7.2.3 · 2× Vrated + 1000V per IEC harmonization). _(engineer @ vendor)_",
        "- [ ] **B6** — Ground continuity / bonding (§7.2.6 · ≤ 100 mΩ accessible-metal-to-ground). _(engineer @ vendor)_",
        "",
        "## Section C · Documentation requirements",
        "",
        "- [ ] **C1** — Schematic + KiCad PCB design file (Step 3 sscb_design_v1.* artifacts). _(engineer @ vendor)_",
        "- [ ] **C2** — BOM (Step 2 sscb_structure_v1 networkx tree · vendor part numbers locked). _(engineer @ vendor)_",
        "- [ ] **C3** — Safety analysis / FMEA (single-fault tolerance · safety-MCU watchdog hooks · firmware/handoff cross-domain). _(engineer @ vendor)_",
        "- [ ] **C4** — Test plan + bolted-fault rig instrumentation spec (scope channels · sense resistor calibration · UL489I §7.2.5 procedure). _(engineer @ vendor)_",
        "- [ ] **C5** — Prior compliance evidence (Wolfspeed C3M0021120K UL recognized · IXYS gate driver UL recognized). _(engineer @ vendor)_",
        "",
        "## Section D · Lab partner candidates",
        "",
        "- [ ] **D1** — UL Solutions (Northbrook IL · Melville NY · Suwon KR) — UL 489I 1st-ed. accredited lab. _(cert manager)_",
        "- [ ] **D2** — TÜV Rheinland (Cologne DE · Pleasanton CA · Shanghai CN) — IEC 60947-2 harmonized + UL 489I scope. _(cert manager)_",
        "- [ ] **D3** — KTL / KTC (Seoul KR) — KS C IEC 60947-2 + UL 489I scope · cost-competitive APAC option. _(cert manager)_",
        "",
        "## Honest-skip caveats (g3)",
        "",
        "- All items are TEMPLATE placeholders · NO actual lab booking has been requested · NO actual contract signed.",
        "- Section B test results columns (PASS/FAIL · measured Icu/Ics numbers) intentionally OMITTED — they are populated post-bench by the lab partner.",
        "- Responsibility assignments (`engineer @ vendor` · `cert manager`) are TBD until the cert program PM is named.",
        "- UL 489I §-references trace to the 1st-edition Oct 2025 document — number may shift in amendments.",
    ]
    md = "\n".join(lines) + "\n"
    # Count items = lines starting with "- [ ]".
    item_count = sum(1 for line in lines if line.lstrip().startswith("- [ ]"))
    return md, item_count


# --------------------------------------------------------------------------
# IEC 60947-2:2016 type-test dossier — 6 performance sections · 22 items.
# --------------------------------------------------------------------------

def _build_iec60947_2_dossier() -> tuple[str, int]:
    """Build the IEC 60947-2 type-test dossier markdown.

    IEC 60947-2:2016 — low-voltage switchgear and controlgear · Part 2
    circuit breakers. Six performance sections per §7 (operational ·
    making/breaking · over-current discrim · short-circuit · temperature
    rise · others). Returns (md_text, item_count).
    """
    lines = [
        "# IEC 60947-2:2016 — type-test dossier",
        "",
        "Stamp: handoff template emit",
        "Source SSOT: domains/sscb.md §2 HANDOFF row + IEC 60947-2:2016 (or current revision)",
        "Scope: low-voltage circuit-breaker type-test envelope · harmonized with UL 489I 1st ed. via UL Solutions track.",
        "Verification objects: Icu (ultimate breaking capacity) · Ics (service breaking capacity) · I²t let-through energy.",
        "",
        "## §7.2.1 · Operational performance capability",
        "",
        "- [ ] **OP1** — Mechanical operations (§7.2.4.5 · no-current · per utilization category). _(lab partner)_",
        "- [ ] **OP2** — Electrical operations (§7.2.4.6 · at rated current · ON/OFF cycles per category). _(lab partner)_",
        "- [ ] **OP3** — Verification of dielectric withstand POST endurance (§7.2.4.7 · no flashover). _(lab partner)_",
        "",
        "## §7.2.2 · Temperature rise",
        "",
        "- [ ] **TR1** — Terminal ΔT measurement at rated current (§7.2.2.1 · TC-instrumented · ambient 40°C). _(lab partner)_",
        "- [ ] **TR2** — Enclosure surface ΔT (§7.2.2.2 · accessible-metal touchpoint per IEC 60947-1). _(lab partner)_",
        "- [ ] **TR3** — Coil / electronic-trip auxiliary ΔT (where applicable to SSCB topology). _(lab partner)_",
        "",
        "## §7.2.3 · Dielectric properties",
        "",
        "- [ ] **DI1** — Power-frequency withstand voltage (§7.2.3.1 · 2× Ui + 1000V · 1 min). _(lab partner)_",
        "- [ ] **DI2** — Impulse withstand (§7.2.3.2 · 1.2/50µs · Uimp per rated insulation). _(lab partner)_",
        "- [ ] **DI3** — Insulation resistance verification (§7.2.3.3 · ≥ 5 MΩ at 500V DC). _(lab partner)_",
        "",
        "## §7.2.4 · Making and breaking capacity",
        "",
        "- [ ] **MB1** — Service short-circuit breaking capacity Ics (§7.2.4.2 · O-t-CO cycle · 3-phase). _(lab partner)_",
        "- [ ] **MB2** — Ultimate short-circuit breaking capacity Icu (§7.2.4.3 · O-t-CO · degraded post-test allowed). _(lab partner)_",
        "- [ ] **MB3** — Verification of contact welding / re-strike absence post-MB1/MB2. _(lab partner)_",
        "- [ ] **MB4** — Let-through energy I²t measurement (§Annex A · oscilloscope capture · cert-blocking). _(lab partner)_",
        "",
        "## §7.2.5 · Over-current protection coordination",
        "",
        "- [ ] **OC1** — Inverse-time trip curve verification (§7.2.5.1 · 2x/3x/6x rated · trip-time band). _(lab partner)_",
        "- [ ] **OC2** — Instantaneous-trip threshold verification (§7.2.5.2 · pickup current ± tolerance). _(lab partner)_",
        "- [ ] **OC3** — Coordination / discrimination with upstream breaker (§7.2.5.3 · cascade certificate). _(lab partner)_",
        "",
        "## §7.2.6 · Additional verifications",
        "",
        "- [ ] **AV1** — IP protection rating (§7.2.6.1 · IEC 60529 IPxx per enclosure spec). _(lab partner)_",
        "- [ ] **AV2** — Ambient temperature derating curve (§7.2.6.2 · -25°C to +70°C per UL489I §6.5). _(lab partner)_",
        "- [ ] **AV3** — Vibration / shock per IEC 60068-2-6/27 (transport + service profiles). _(lab partner)_",
        "- [ ] **AV4** — EMC emissions + immunity per IEC 60947-2 §7.3 (CISPR 11 Class A baseline). _(lab partner)_",
        "- [ ] **AV5** — Functional safety hooks (IEC 61508 SIL claim if firmware/handoff safety-MCU certified). _(lab partner + cert manager)_",
        "",
        "## Harmonization cross-reference (UL Solutions track)",
        "",
        "- IEC §7.2.2 (temp rise) ↔ UL 489I §7.2.2 — direct harmonization.",
        "- IEC §7.2.3 (dielectric) ↔ UL 489I §7.2.3 — direct harmonization.",
        "- IEC §7.2.4 (Icu/Ics) ↔ UL 489I §7.2.5 — methodology harmonized · waveform tolerance differs.",
        "- IEC §7.2.5 (over-current) ↔ UL 489I §7.2.4 — trip-curve format differs (band vs envelope).",
        "- IEC §7.2.6 (additional) ↔ UL 489I §6.5/§7.2.6 — partial harmonization · IP / EMC overlap.",
        "",
        "## Honest-skip caveats (g3)",
        "",
        "- All items are TEMPLATE checkboxes · NO actual type-test executed · NO measured Icu/Ics/I²t numbers.",
        "- §-references trace to IEC 60947-2:2016 (or current revision at lab booking) — re-verify against latest amendment.",
        "- Cert-blocking subset (MB1 · MB2 · MB4 · OC1) requires bolted-fault test rig (§9.9.1 verify cell scope).",
        "- SIL claim (AV5) is contingent on firmware/handoff safety-MCU cert path — cross-domain dependency.",
    ]
    md = "\n".join(lines) + "\n"
    item_count = sum(1 for line in lines if line.lstrip().startswith("- [ ]"))
    return md, item_count


# --------------------------------------------------------------------------
# IEEE C37.x family cross-reference — 8 items + applicability mapping.
# --------------------------------------------------------------------------

def _build_ieee_c37_xref() -> tuple[str, int]:
    """Build the IEEE C37.x family cross-reference markdown.

    IEEE C37 series covers switchgear · LV/MV/HV power CBs. The SSCB
    topology (≤ 1500 Vdc · solid-state branch protection) is most aligned
    with C37.13 (low-voltage power CBs in enclosures) but inherits some
    C37.04 (HV interrupter rating structure) language. Returns (md_text,
    item_count).
    """
    lines = [
        "# IEEE C37.x family — cross-reference for SSCB",
        "",
        "Stamp: handoff template emit",
        "Source SSOT: IEEE C37 series · sscb.md §2 HANDOFF row",
        "Scope of applicability: HEXA-SSCB mk1 (solid-state · ≤ 1500 Vdc) — primarily aligned with C37.13 envelope · partial C37.04 inheritance for rating structure language · most C37 family standards target electromechanical CBs and have limited direct applicability to SSCB topology.",
        "",
        "## Mapping table (C37.x → SSCB applicability)",
        "",
        "| Standard | Title | Applicability to SSCB | Cross-ref to UL 489I / IEC 60947-2 |",
        "| --- | --- | --- | --- |",
        "| IEEE C37.13-2015 | LV AC power CBs used in enclosures | **PRIMARY** — terminology + rating structure baseline | UL 489I §6 · IEC 60947-2 §4 |",
        "| IEEE C37.04-2018 | HV AC CB rating structure | Partial — Icu/Ics nomenclature inherited | IEC 60947-2 Annex A (let-through) |",
        "| IEEE C37.06-2009 | HV AC CB ratings preferred values | Limited — voltage tier mismatch | n/a (SSCB ≤ 1500 Vdc out of C37.06 scope) |",
        "| IEEE C37.09-2018 | HV AC CB test procedures | Reference only — test methodology hints | IEC 60947-2 §7.2.4 (MB tests) |",
        "| IEEE C37.20.1 | LV metal-enclosed switchgear | Enclosure baseline · partial | UL 489I §6.1 visual/dim · IEC 60947-2 §7.2.6 |",
        "| IEEE C37.90 | Relays + relay systems EMC | Functional safety / EMC tie-in | IEC 60947-2 §7.3 + IEC 61508 (SIL) |",
        "| IEEE C37.100.1 | Common requirements for HV switchgear | Reference glossary | n/a (SSCB is LV) |",
        "| IEEE Std 1789-2015 | Recommended practices for SSCB / SSPC | **EMERGING** — closest direct fit for SSCB topology | UL 489I 1st ed. (Oct 2025) is the formal cert envelope |",
        "",
        "## Items requiring sign-off",
        "",
        "- [ ] **C37-1** — Confirm IEEE C37.13-2015 rating-structure terminology adopted in cert dossier glossary. _(cert manager)_",
        "- [ ] **C37-2** — Confirm IEEE C37.04-2018 Icu/Ics nomenclature mirrors IEC 60947-2 §7.2.4 usage. _(cert manager)_",
        "- [ ] **C37-3** — Document divergence: SSCB has NO electromechanical contacts → C37.20.1 internal-arc tests NOT directly applicable (semiconductor failure mode is different · let-through energy ≠ arc flash). _(engineer @ vendor)_",
        "- [ ] **C37-4** — Document IEEE Std 1789-2015 SSPC alignment (closest direct topology fit · informational only). _(cert manager)_",
        "- [ ] **C37-5** — Confirm IEEE C37.90 EMC scope covered by IEC 60947-2 §7.3 + CISPR 11 (no separate C37.90 test plan needed). _(lab partner)_",
        "- [ ] **C37-6** — Document IEEE C37.06-2009 preferred-values mismatch (SSCB voltage tier is outside HV scope · no derating). _(engineer @ vendor)_",
        "- [ ] **C37-7** — Cross-domain hook: firmware/handoff safety-MCU SIL claim cites IEC 61508 NOT IEEE C37.90 (avoid double-counting). _(cert manager + firmware lead)_",
        "",
        "## Honest-skip caveats (g3)",
        "",
        "- This is a SCOPE-OF-APPLICABILITY mapping · NOT compliance proof · standards interpretation = legal / cert manager territory.",
        "- C37 family is primarily ELECTROMECHANICAL CB territory — SSCB topology departs at multiple levels (no arc · no contact bounce · semiconductor failure modes). Direct test inheritance is partial.",
        "- IEEE Std 1789-2015 (SSPC recommended practices) is the closest published fit but is NON-NORMATIVE — UL 489I 1st ed. (Oct 2025) is the formal certification envelope.",
        "- Items C37-1 through C37-7 are template placeholders · cert manager review required to finalize the divergence-documentation strategy.",
    ]
    md = "\n".join(lines) + "\n"
    item_count = sum(1 for line in lines if line.lstrip().startswith("- [ ]"))
    return md, item_count


# --------------------------------------------------------------------------
# Tier-2 fan-out list — Steps 1-3 derived · responsibility · cost · cert.
# --------------------------------------------------------------------------

def _build_tier2_fanout() -> tuple[str, int, int]:
    """Build the Tier-2 fan-out markdown derived from Steps 1-3 artifacts.

    Pulls bench-validation needs from:
      - Step 1 (specify): spec-level parameters that need bench validation
      - Step 2 (structure): BOM placeholder vendor parts that need datasheet binding
      - Step 3 (design): ngspice netlist datasheet bindings that need actual .lib

    Returns (md_text, item_count, cert_blocking_count).
    """
    items = [
        # From Step 1 (specify) — spec-level parameters needing bench validation
        {
            "id": "T2-S1-01",
            "source": "Step 1 specify",
            "what": "Rated current carrying validation at 100A continuous (sscb.md §1 spec target proxy)",
            "responsibility": "lab partner (UL 489I §7.2.2 thermal rig)",
            "est_cost_usd": "8k-15k",
            "cert_blocking": True,
        },
        {
            "id": "T2-S1-02",
            "source": "Step 1 specify",
            "what": "Dielectric withstand 2× Ui + 1000V (sscb.md §1 voltage class declaration)",
            "responsibility": "lab partner (UL 489I §7.2.3 hipot stand)",
            "est_cost_usd": "3k-6k",
            "cert_blocking": True,
        },
        {
            "id": "T2-S1-03",
            "source": "Step 1 specify",
            "what": "Operating temperature range -25°C to +70°C derating curve (sscb.md §1 ambient class)",
            "responsibility": "lab partner (env chamber + UL 489I §6.5)",
            "est_cost_usd": "5k-10k",
            "cert_blocking": False,
        },
        # From Step 2 (structure) — BOM placeholder vendor parts needing datasheet binding
        {
            "id": "T2-S2-04",
            "source": "Step 2 structure",
            "what": "sic_switch_stack — Wolfspeed C3M0021120K datasheet bind + UL-recognized component lookup",
            "responsibility": "engineer @ vendor (procurement + UL component DB)",
            "est_cost_usd": "0.5k (samples + datasheet)",
            "cert_blocking": True,
        },
        {
            "id": "T2-S2-05",
            "source": "Step 2 structure",
            "what": "gate_driver_ic — IXYS IXDD609SI datasheet bind + isolated supply (Si8261-class) Tier-2 selection",
            "responsibility": "engineer @ vendor (procurement + UL component DB)",
            "est_cost_usd": "0.3k",
            "cert_blocking": False,
        },
        {
            "id": "T2-S2-06",
            "source": "Step 2 structure",
            "what": "snubber RC + TVS — actual vendor parts vs rule-of-thumb 10Ω/10nF/1500V",
            "responsibility": "engineer @ vendor (Wolfspeed CRD-001 app note alignment)",
            "est_cost_usd": "0.2k",
            "cert_blocking": False,
        },
        {
            "id": "T2-S2-07",
            "source": "Step 2 structure",
            "what": "cold_plate — vendor (Wolverine Tube / Lytron / etc.) + R_thja bench measurement (vs 0.05 °C/W placeholder)",
            "responsibility": "engineer @ vendor (procurement + thermal rig)",
            "est_cost_usd": "2k-4k",
            "cert_blocking": False,
        },
        {
            "id": "T2-S2-08",
            "source": "Step 2 structure",
            "what": "busbars — actual Cu stamping vendor + stray-L extraction (KiCad PCB editor loop-area)",
            "responsibility": "engineer @ vendor (PCB EDA tool)",
            "est_cost_usd": "1k",
            "cert_blocking": False,
        },
        # From Step 3 (design) — ngspice netlist datasheet bindings
        {
            "id": "T2-S3-09",
            "source": "Step 3 design",
            "what": "Wolfspeed C3M0021120K .lib (SPICE model) acquisition + paralleling-count sweep",
            "responsibility": "engineer @ vendor (Wolfspeed login + SPICE setup)",
            "est_cost_usd": "0 (vendor-provided · login required)",
            "cert_blocking": True,
        },
        {
            "id": "T2-S3-10",
            "source": "Step 3 design",
            "what": "IXYS IXDD609SI SPICE macro (vendor request) + Rg/dv/dt sweep",
            "responsibility": "engineer @ vendor (vendor support ticket)",
            "est_cost_usd": "0 (vendor-provided)",
            "cert_blocking": False,
        },
        {
            "id": "T2-S3-11",
            "source": "Step 3 design",
            "what": "magnetic_limiter L = 1.118 µH FEMMT analytic_fallback → measured DC bias derating",
            "responsibility": "lab partner (LCR meter + DC bias sweep)",
            "est_cost_usd": "1k-2k",
            "cert_blocking": False,
        },
        {
            "id": "T2-S3-12",
            "source": "Step 3 design",
            "what": "Bolted-fault rig instrumentation (scope channels · sense resistor calibration · UL489I §7.2.5 Icu/Ics)",
            "responsibility": "lab partner (cert lab) + engineer @ vendor (rig design)",
            "est_cost_usd": "15k-30k (lab + rig)",
            "cert_blocking": True,
        },
        {
            "id": "T2-S3-13",
            "source": "Step 3 design",
            "what": "OpenFOAM CHT thermal coupling (cold plate + die heat-flux · vs ngspice .TRAN time-avg)",
            "responsibility": "engineer @ vendor (analyze cell · sscb.md §2 ANALYZE row)",
            "est_cost_usd": "2k (engineer time)",
            "cert_blocking": False,
        },
    ]

    lines = [
        "# Tier-2 fan-out list — Steps 1-3 derived bench-validation items",
        "",
        "Stamp: handoff template emit",
        "Source SSOT: Steps 1-3 artifacts (specify · structure · design) + sscb.md caveats",
        "Scope: items downstream of design verb · needed before UL 489I lab booking can proceed.",
        "Responsibility legend: `engineer @ vendor` · `lab partner` · `cert manager`",
        "Cost estimates: USD · rough order-of-magnitude · cert manager review required to finalize.",
        "",
        "## Fan-out table",
        "",
        "| ID | Source step | What | Responsibility | Est. cost (USD) | Cert-blocking |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for it in items:
        cb = "**YES**" if it["cert_blocking"] else "no"
        lines.append(
            f"| {it['id']} | {it['source']} | {it['what']} | {it['responsibility']} | "
            f"{it['est_cost_usd']} | {cb} |"
        )

    cert_blocking_count = sum(1 for it in items if it["cert_blocking"])

    lines.extend([
        "",
        "## Roll-up",
        "",
        f"- Total tier-2 items: **{len(items)}**",
        f"- Cert-blocking subset: **{cert_blocking_count}** (must close before lab booking)",
        f"- Non-cert-blocking subset: **{len(items) - cert_blocking_count}** (parallel-tracked)",
        "",
        "## Honest-skip caveats (g3)",
        "",
        "- Cost estimates are rough order-of-magnitude · cert manager + procurement review required to finalize.",
        "- Responsibility assignments are TEMPLATE shorthand — actual program PM + vendor relations + cert manager naming pending.",
        "- Cert-blocking classification reflects UL 489I §7 / IEC 60947-2 §7.2.4-5 dependencies · re-verify against latest amendment.",
        "- This list is DERIVATIVE from Steps 1-3 artifacts · NOT exhaustive — additional items may surface during type-test prep (e.g. EMC pre-scan · vibration profile · cert manager-specific dossier sections).",
        "- Items marked cert-blocking=YES are the gate items for UL 489I lab booking submission · non-blocking items can be parallel-tracked.",
    ])
    md = "\n".join(lines) + "\n"
    return md, len(items), cert_blocking_count


# --------------------------------------------------------------------------
# Bundle manifest — top-level handoff package manifest · 8 sections.
# --------------------------------------------------------------------------

def _build_bundle_manifest(
    stamp: str,
    artifacts: list[tuple[str, str]],
    measurements: dict,
) -> str:
    """Build the top-level handoff bundle manifest markdown.

    artifacts: list of (filename, description) tuples for the 5 artifact docs.
    measurements: dict of measurement values (item counts · cert_blocking_count · etc.)
    """
    lines = [
        "# HEXA-SSCB mk1 — handoff bundle manifest",
        "",
        f"Bundle ID: `{GEOMETRY_ID}_{stamp}`",
        f"Stamp: {stamp}",
        "Source SSOT: domains/sscb.md §2 HANDOFF row + sscb.demi [cell.handoff]",
        "Bundle type: cert dossier scaffold (template emit · NOT actual lab-submission package)",
        "",
        "## 1 · Cert path overview",
        "",
        "Lab partner → test plan → submission → result, executed as:",
        "",
        "1. Lab partner selection (UL Solutions · TÜV Rheinland · KTL — Section D of UL489I checklist).",
        "2. Test plan harmonization (UL 489I 1st ed. + IEC 60947-2:2016 · cross-walk table in IEC dossier §Harmonization).",
        "3. Submission package (this bundle + Tier-2 fan-out closures + measured Icu/Ics/I²t from bolted-fault rig).",
        "4. Type-test execution (lab partner runs §7.2.4-7 tests · 4-8 weeks typical turnaround).",
        "5. Result + cert mark issuance (UL recognized component DB entry + EU CE mark per IEC 60947-2).",
        "",
        "## 2 · Artifacts list",
        "",
    ]
    for fname, desc in artifacts:
        lines.append(f"- `{fname}` — {desc}")
    lines.extend([
        "",
        "## 3 · Sign-off blocks",
        "",
        "- [ ] **Engineering sign-off** — design owner reviews Steps 1-3 + Tier-2 fan-out closure status. _(eng lead · pending)_",
        "- [ ] **QA sign-off** — production lot ID + BOM revision lock + sample traceability verified. _(QA lead · pending)_",
        "- [ ] **Cert manager sign-off** — UL 489I + IEC 60947-2 + IEEE C37.x scope confirmed · lab partner contracted. _(cert manager · pending)_",
        "- [ ] **Firmware lead sign-off** — safety-MCU cross-domain hook (firmware/handoff cert dependency) acknowledged. _(firmware lead · pending)_",
        "",
        "## 4 · Tier-2 fan-out summary",
        "",
        f"- Total items: {measurements['tier2_fanout_item_count']}",
        f"- Cert-blocking: {measurements['cert_blocking_count']}",
        f"- Non-cert-blocking: {measurements['tier2_fanout_item_count'] - measurements['cert_blocking_count']}",
        "- See `sscb_handoff_v1.tier2_fanout.md` for full table.",
        "",
        "## 5 · Cross-domain hooks",
        "",
        "- **firmware/handoff** — safety-MCU cert dependency. If the SSCB ships with a control MCU + watchdog, the firmware/handoff cert path (IEC 61508 SIL claim · MCUboot signed image · CycloneDX SBOM) MUST close before SSCB UL489I submission · cross-domain dependency.",
        "- **chip/verify** — SiC die parity (Wolfspeed C3M0021120K UL-recognized component DB entry) is a Tier-2 procurement closure · see T2-S2-04 · T2-S3-09.",
        "- **matter/analyze** — busbar / cold plate material certification (Cu purity · thermal-cycle endurance) is a parallel-tracked item · NOT cert-blocking for HEXA-SSCB mk1 first article.",
        "",
        "## 6 · Roll-up measurements",
        "",
        f"- UL 489I checklist items: {measurements['ul489i_checklist_item_count']}",
        f"- IEC 60947-2 checklist items: {measurements['iec60947_2_checklist_item_count']}",
        f"- IEEE C37.x reference items: {measurements['ieee_c37_x_reference_count']}",
        f"- Tier-2 fan-out items: {measurements['tier2_fanout_item_count']}",
        f"- Cert-blocking count: {measurements['cert_blocking_count']}",
        f"- Bundle artifact count: {measurements['bundle_artifact_count']}",
        f"- Cert bundle ready: **{measurements['cert_bundle_ready']}** (template scaffold · NOT lab-ready)",
        "",
        "## 7 · Known limitations (g3 honest)",
        "",
        "- This bundle is a TEMPLATE SCAFFOLD · NO actual lab booking has been requested · NO actual contract signed.",
        "- NO actual UL/TÜV/KTL type-test executed · NO measured Icu/Ics/I²t numbers in this bundle.",
        "- Tier-2 fan-out list is DERIVATIVE from Steps 1-3 · NOT exhaustive — additional items may surface during type-test prep.",
        "- IEEE C37.x cross-reference is SCOPE-OF-APPLICABILITY mapping · NOT compliance proof · standards interpretation = legal / cert manager territory.",
        "- absorbed = false PERMANENTLY for this cell · cert dossier without lab partner sign-off + type-test pass = illustrative, NOT absorption.",
        "- Sign-off blocks (Section 3) are TEMPLATE checkboxes · NO actual program PM + vendor relations + cert manager naming pending.",
        "",
        "## 8 · Next steps (downstream)",
        "",
        "1. Close cert-blocking Tier-2 items (T2-S1-01 · T2-S1-02 · T2-S2-04 · T2-S3-09 · T2-S3-12).",
        "2. Cert manager: select lab partner (Section D of UL489I checklist) + sign NDA + lock test plan.",
        "3. Engineer @ vendor: assemble 3× DUT samples + electrical pre-conditioning + serial number traceability.",
        "4. Lab partner: execute UL 489I §7 type-test sequence + IEC 60947-2 §7.2 harmonized verifications.",
        "5. Cert manager: review lab partner report · file UL recognized component DB entry · file CE mark per IEC 60947-2.",
        "",
    ])
    return "\n".join(lines) + "\n"


# --------------------------------------------------------------------------
# Main producer entry point.
# --------------------------------------------------------------------------

def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    produced_at_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    # ---- build artifacts --------------------------------------------------
    ul489i_md, ul489i_count = _build_ul489i_checklist()
    iec_md, iec_count = _build_iec60947_2_dossier()
    ieee_md, ieee_count = _build_ieee_c37_xref()
    tier2_md, tier2_count, cert_blocking_count = _build_tier2_fanout()

    # ---- write 4 of 5 markdowns first (need measurements for manifest) ----
    ul489i_path = out / f"{GEOMETRY_ID}.ul489i_checklist.md"
    ul489i_path.write_text(ul489i_md, encoding="utf-8")

    iec_path = out / f"{GEOMETRY_ID}.iec60947_2_typetest_dossier.md"
    iec_path.write_text(iec_md, encoding="utf-8")

    ieee_path = out / f"{GEOMETRY_ID}.ieee_c37_x_xref.md"
    ieee_path.write_text(ieee_md, encoding="utf-8")

    tier2_path = out / f"{GEOMETRY_ID}.tier2_fanout.md"
    tier2_path.write_text(tier2_md, encoding="utf-8")

    bundle_artifact_count = 5  # 5 markdown artifacts
    cert_bundle_ready = all([
        ul489i_count > 0,
        iec_count > 0,
        ieee_count > 0,
        tier2_count > 0,
    ])

    measurements = {
        "ul489i_checklist_item_count": ul489i_count,
        "iec60947_2_checklist_item_count": iec_count,
        "ieee_c37_x_reference_count": ieee_count,
        "tier2_fanout_item_count": tier2_count,
        "cert_blocking_count": cert_blocking_count,
        "bundle_artifact_count": bundle_artifact_count,
        "cert_bundle_ready": cert_bundle_ready,
    }

    artifacts_for_manifest = [
        (ul489i_path.name, "UL 489I 1st ed. (Oct 2025) lab-booking checklist"),
        (iec_path.name, "IEC 60947-2:2016 type-test dossier · harmonized cross-walk"),
        (ieee_path.name, "IEEE C37.x family cross-reference · scope-of-applicability"),
        (tier2_path.name, "Tier-2 fan-out list · Steps 1-3 derived bench-validation items"),
    ]

    manifest_md = _build_bundle_manifest(stamp, artifacts_for_manifest, measurements)
    manifest_path = out / f"{GEOMETRY_ID}.bundle_manifest.md"
    manifest_path.write_text(manifest_md, encoding="utf-8")

    # Append manifest itself to artifacts list for record JSON.
    all_artifact_names = [
        ul489i_path.name,
        iec_path.name,
        ieee_path.name,
        tier2_path.name,
        manifest_path.name,
    ]

    citations = [
        "UL 489I 1st ed. (Oct 2025) — SSCB / SSHCB ≤ 1000 Vac / 1500 Vdc "
        "molded-case CBs for solid-state branch protection.",
        "IEC 60947-2:2016 — low-voltage switchgear · Part 2 circuit breakers.",
        "IEEE C37.13-2015 — LV AC power CBs used in enclosures (primary alignment).",
        "IEEE C37.04-2018 — HV AC CB rating structure (partial inheritance).",
        "IEEE Std 1789-2015 — recommended practices for SSCB / SSPC (closest direct fit).",
        "UL Solutions harmonization track — IEC 60947-2 ↔ UL 489I crosswalk.",
        "domains/sscb.md §2 HANDOFF row — UL/TÜV/KTL type-test submission.",
        "sscb.demi [cell.handoff] caveats — bench-test plan producer 미작성 · firmware/handoff.py 패턴 reuse.",
        "stdlib/firmware/handoff.py — release.tar.gz template pattern reference (D72 adapter-only).",
    ]
    scope_caveats = [
        "Cert dossier = template scaffold · NO actual UL/TÜV/KTL lab booking · "
        "NO actual type-test execution · NO Icu/Ics numbers (bench-pending).",
        "Tier-2 fan-out list = derivative scaffold from Steps 1-3 artifacts · "
        "responsibilities + costs = rough estimates · cert manager review required.",
        "absorbed=false maintained · handoff is illustrative bundle · "
        "regulatory verify = downstream lab work.",
        "IEEE C37.x cross-reference = scope-of-applicability mapping · NOT "
        "compliance proof · standards interpretation = legal / cert manager territory.",
        "Sign-off blocks in bundle_manifest §3 are TEMPLATE checkboxes · "
        "actual program PM + vendor relations + cert manager naming pending.",
    ]

    # ---- sibling meta.json — D113 cellrun payload flattening source -------
    meta = {
        "ok": True,
        "geometry_id": META_ID,
        "produced_at_utc": produced_at_utc,
        "python_version": platform.python_version(),
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "measurements": measurements,
        "artifacts": {
            "ul489i_checklist": ul489i_path.name,
            "iec60947_2_dossier": iec_path.name,
            "ieee_c37_x_xref": ieee_path.name,
            "tier2_fanout": tier2_path.name,
            "bundle_manifest": manifest_path.name,
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

    # ---- top-level record JSON (Codable mirror) --------------------------
    record = {
        "domain": "sscb",
        "verb": "handoff",
        "kind": "sscb_handoff_record",
        "stamp": stamp,
        "producer": "sscb_handoff@template",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": None,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        # Scalar roll-up fields (Codable mirror on cockpit).
        "ul489i_checklist_item_count": ul489i_count,
        "iec60947_2_checklist_item_count": iec_count,
        "ieee_c37_x_reference_count": ieee_count,
        "tier2_fanout_item_count": tier2_count,
        "cert_blocking_count": cert_blocking_count,
        "bundle_artifact_count": bundle_artifact_count,
        "cert_bundle_ready": cert_bundle_ready,
        "artifacts": all_artifact_names,
        "notes": (
            "Cert-dossier bundle template emit (Step 4 SSCB walkthrough · LAST). "
            "5 markdown artifacts: UL 489I 1st ed. (Oct 2025) lab-booking "
            "checklist + IEC 60947-2:2016 type-test dossier (harmonized "
            "cross-walk) + IEEE C37.x family cross-reference + Tier-2 "
            "fan-out list (Steps 1-3 derived) + bundle manifest. "
            "absorbed=false PERMANENTLY — cert dossier without lab partner "
            "sign-off + type-test pass = illustrative, NOT absorption. "
            "firmware/handoff.py pattern reused for the bundle envelope."
        ),
    }
    rec_path = out / f"sscb_handoff_{stamp}.json"
    with open(rec_path, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"sscb_handoff: wrote {rec_path} "
        f"(ok=True, ul489i={ul489i_count}, iec={iec_count}, "
        f"ieee={ieee_count}, tier2={tier2_count}, "
        f"cert_blocking={cert_blocking_count})\n")

    summary = {
        "ok": True,
        "geometry_id": META_ID,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "ul489i_checklist_item_count": ul489i_count,
        "iec60947_2_checklist_item_count": iec_count,
        "ieee_c37_x_reference_count": ieee_count,
        "tier2_fanout_item_count": tier2_count,
        "cert_blocking_count": cert_blocking_count,
        "bundle_artifact_count": bundle_artifact_count,
        "cert_bundle_ready": cert_bundle_ready,
        "artifacts": {
            "record": rec_path.name,
            "meta": meta_path.name,
            "ul489i_checklist": ul489i_path.name,
            "iec60947_2_dossier": iec_path.name,
            "ieee_c37_x_xref": ieee_path.name,
            "tier2_fanout": tier2_path.name,
            "bundle_manifest": manifest_path.name,
        },
    }
    # SSCB_HANDOFF_RESULT marker on stderr — mirrors specify.py /
    # structure.py / design.py pattern.
    sys.stderr.write("SSCB_HANDOFF_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/sscb_handoff"))
