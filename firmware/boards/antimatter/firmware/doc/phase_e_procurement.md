# Phase E — procurement + receiving log (HEXA-FIRMWARE-PHASE-E-03)

> Tracks SKU procurement progression for the 4 board v0 BOMs.
> Every line item from `firmware/doc/board_v0_*.md §4` flows here when
> ordered.  No PO has been issued; this is the empty schema.

**Status**: empty (2026-05-08) · **First PO**: TBD (post-funding §A.6 step 2)

---

## §1 Procurement workflow

```
funding ($) ─┐
             v
┌────────────────┐    ┌────────────────┐    ┌──────────────────┐
│ KiCad BOM CSV  │ ─> │ vendor quote   │ ─> │ procurement PO   │
│ (per phase_e_  │    │ + cross-check  │    │ + receiving      │
│  kicad_plan)   │    │ vs board_v0 §4 │    │                  │
└────────────────┘    └────────────────┘    └──────────────────┘
                                                     │
                                                     v
┌──────────────────┐    ┌──────────────────┐    ┌────────────────┐
│ AOI / X-ray /    │ <─ │ SMT assembly     │ <─ │ bare-board fab │
│ continuity test  │    │ (JLCPCB / Kimball│    │ (Gerber → PCB) │
│                  │    │  / PCBWay)       │    │                │
└──────────────────┘    └──────────────────┘    └────────────────┘
        │
        v
┌──────────────────┐    ┌──────────────────┐
│ bring-up per     │ ─> │ sim-parity test  │ ─> Phase E DONE per board
│ board_v0_*.md §7 │    │ (sim/*.hexa)     │
└──────────────────┘    └──────────────────┘
```

## §2 Aggregate budget summary

| Bucket | Estimate | Notes |
|:-------|:---------|:------|
| Phase E1 (pet_cyclotron + atomic_clock proto) | ~$15k | 5×4-layer + 5×6-layer + SMT |
| Phase E2 (tabletop_penning proto) | ~$30k | 5×8-layer HDI + BGA SMT + Wenzel OCXO + AD9162/AD9208 |
| Phase E3 (thrust_acquisition proto) | ~$90k | 3×14-layer HDI + AT&S/Kimball + XCVU13P + 8× ADC32RF45 |
| Test instruments (shared) | ~$80k | Vector network analyzer, sub-ns scope, Watt balance, NIM bin, DAQ host |
| Lab consumables | ~$10k | LHe (initial fill), cryogen interlock sensors, calibration sources |
| **Phase E aggregate** | **~$225k** | excl. salaries / Vivado seat / probe-rs |

This is the funding gate per `.roadmap §A.6 step 2`.  Stage-1 benchtop
hardware ≈ $11M (per Phase A BOM); Phase E electronics is ≈ 2% of that.

## §3 Active POs (receiving log)

(none — schema only)

| PO # | Date | Vendor | Item | Qty | $ | Lead | Recv'd | AOI | Notes |
|:----:|:----:|:-------|:-----|:---:|:-:|:----:|:------:|:---:|:------|
| —    | —    | —      | —    | —   | — | —    | —      | —   | —     |

## §4 Per-board status snapshot

| Board | KiCad | PCB spin | SMT | Bring-up | Sim parity | Status |
|:------|:-----:|:--------:|:---:|:--------:|:----------:|:-------|
| pet_cyclotron      | ✗ | ✗ | ✗ | ✗ | ✗ | Phase C.5 paper only |
| atomic_clock       | ✗ | ✗ | ✗ | ✗ | ✗ | Phase C.5 paper only |
| tabletop_penning   | ✗ | ✗ | ✗ | ✗ | ✗ | Phase C.5 paper only |
| thrust_acquisition | ✗ | ✗ | ✗ | ✗ | ✗ | Phase C.5 paper only |

When a column flips from ✗ → date or PO#, this row reflects current
state.  All four expected to flip simultaneously following Phase E
funding gate.

## §5 Receiving QC checklist (per delivered board)

1. **Visual inspection** — solder bridges, missing parts, lifted pads
2. **AOI report review** — vendor-side machine-vision PASS
3. **X-ray review** (BGA boards) — voids / shorts under BGA balls
4. **Continuity test** — power rails to GND short check
5. **Bare-board ohms test** — 12 V → GND > 100 kΩ
6. **Bench markup** — board ID, PO #, recv'd date, Sharpie label

## §6 Bring-up gate criteria

A board is "Phase E DONE" only when:
- All 13–15 bring-up steps from `board_v0_*.md §7` PASS
- A 60-min capture / acquisition run matches `firmware/sim/*.hexa` golden output
- Hot-soak 4 hr stable + cold-cycle (30 min @ 0 °C) recovery
- Receiving QC results logged (§5 above)
- Photo + signed bring-up report committed to this log

## §7 Cross-link

- `firmware/doc/phase_e_kicad_plan.md`         — KiCad project setup
- `firmware/doc/phase_e_pcb_plan.md`           — PCB layout + fab strategy
- `firmware/doc/phase_e_test_report_template.md` — bench-test report template
- `firmware/doc/board_v0_*.md §4 (BOM)`        — SKU source-of-truth
- `firmware/doc/board_v0_*.md §7 (bring-up)`   — gate criteria source
