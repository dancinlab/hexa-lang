# Phase E — bench-test report template

> Per-board bring-up + sim-parity report.  Filled in by the lab team
> when a Phase E board reaches the bench.  Empty template — copy + edit
> per delivered board.

---

## Board identification

| Field | Value |
|:------|:------|
| Board name | (e.g., HEXA-PET-FW-01) |
| Source spec | `firmware/doc/board_v0_pet_cyclotron.md` |
| Sim source | `firmware/sim/cyclotron_trigger.hexa` |
| HDL source | `firmware/hdl/cyclotron_trigger.v` (or "MCU-only") |
| MCU source | `firmware/mcu/pet_cyclotron.rs` |
| Spin number | 1 / 2 / 3 |
| PO number | (procurement-side reference) |
| Receiving date | YYYY-MM-DD |
| Operator(s) | (name + lab role) |

---

## §1 Receiving QC

| Step | Result | Notes |
|:-----|:------:|:------|
| Visual inspection | ☐ pass / ☐ fail | photos in `output/spin-N/visual/` |
| AOI vendor report | ☐ pass / ☐ fail | attach AOI PDF |
| X-ray BGA review | ☐ pass / ☐ fail / ☐ N/A | attach X-ray images |
| Continuity (power → GND) | ☐ pass / ☐ fail | DMM ohms |
| Bare-board ohms (12 V → GND) | ___ MΩ | target > 100 kΩ |

---

## §2 Bring-up checklist

(Steps 1–15 per `firmware/doc/board_v0_*.md §7`; copy that table here.)

| # | Step | Result | Measured value | Notes |
|:--|:-----|:------:|:---------------|:------|
| 1 | … | ☐ pass / ☐ fail | … | … |
| ⋮ | … | … | … | … |

---

## §3 Sim parity

Final acceptance gate.  Run firmware/sim against the **board** (not
the simulator).  Record:

| Metric | Sim golden | Board measured | Δ | Pass? |
|:-------|:-----------|:---------------|:--|:-----:|
| State machine state count | (per sim) | | | ☐ |
| DAC/ADC range bounds | (per sim) | | | ☐ |
| Safety interlock latency | ≤ 10 ms | _____ ms | | ☐ |
| n=6 lattice anchor (σ·τ=48 etc) | exact | | | ☐ |
| Telemetry rate / data-rate budget | (per sim) | | | ☐ |
| Total cycle time envelope | (per sim) | | | ☐ |

Any FAIL line → board is **NOT** Phase E DONE; investigate and either
patch firmware or respin PCB.

---

## §4 Hot-soak / cold-cycle

| Condition | Duration | Result | Notes |
|:----------|:---------|:------:|:------|
| Hot soak (room temp, full load) | 4 hr | ☐ stable / ☐ drift | thermal photo |
| Cold cycle (chamber 0 °C → 25 °C) | 30 min | ☐ recovers / ☐ glitch | log file |
| Vibration (gentle bench tap) | 1 min | ☐ stable / ☐ glitch | recordings |

---

## §5 Open issues + follow-ups

1. (issue) — (proposed fix) — (priority H/M/L) — (assigned)
2. ⋮

---

## §6 Sign-off

| Role | Name | Signature / Date |
|:-----|:-----|:-----------------|
| Lab engineer | | |
| Board designer | | |
| RSC verification owner | | |

Once all 3 sign → board status flips ✗ → ✅ in
`firmware/doc/phase_e_procurement.md §4`.

---

## §7 Photos / appendix

- `output/spin-N/visual/`  — board front + back photo
- `output/spin-N/scope/`   — bring-up step ‘scope captures
- `output/spin-N/log/`     — telemetry + UART logs
- `output/spin-N/sim_parity_compare.csv` — sim vs measured side-by-side
