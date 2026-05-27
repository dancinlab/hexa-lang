# Phase E — Hardware Path (KiCad → fab → bring-up)

> Phase E lives **outside the .hexa code surface**.  Per recipe §9, code-layer
> closure (sat-1 + sat-2 + sat-3) is complete at v1.1.0; remaining steps are
> hardware/ops events that cannot be unblocked by additional `.hexa` files.
>
> This document is the **paper roadmap** that bridges Phase D (HDL/MCU/
> schematic specs in this repo) to Phase E (real boards in hand).  It does
> not produce artefacts that change `verify/all.hexa` count; it scopes the
> work, vendor matrix, and funding ladder so a future maintainer (or a
> funded hire) can pick up where Phase D ended.

**Status**: planning doc (2026-05-08) · **Trigger**: external funding event · **Verified by**: external (this repo's `firmware_phase_d_lint.hexa` only audits paper-spec drift, not hardware)

---

## §1 Phase E sub-stages

| Sub-stage | Window | Trigger | Cost | Deliverable |
|:----------|:-------|:--------|----:|:------------|
| **E1 — KiCad** | 2-4 weeks per board | $0 (volunteer-grade) | $0 | `pcb/{board}/*.{kicad_sch,kicad_pcb}` + Gerber + drill |
| **E2 — Fab + assy** | 4-8 weeks | $3.5 K – $50 K per board (see §3) | $3.5 K – $115 K | physical board, populated, electrically tested |
| **E3 — Flash + bring-up** | 1-2 weeks per board | bench access + JTAG | $0 if E2 done | flashed Rust + Vivado bitstream verified at JTAG; Phase D `cargo embed` + `vivado -mode batch` succeed |
| **E4 — End-system integration** | 3-12 months | per pillar facility access | facility-dependent | live data feed replaces paper-feed in `state/`; F-AM-1/2/3/4 T3 closes empirically |

---

## §2 Per-board Phase E sequence

### Board 1 — HEXA-PET-FW-01 (PET cyclotron, F-AM-1)

| E1 — KiCad | E2 — Fab | E3 — Bring-up | E4 — Integration |
|:-----------|:---------|:--------------|:------------------|
| 6-layer PCB, 100 × 80 mm Eurocard half-rack | JLCPCB / OSH Park | ST-LINK V3 + probe-rs | hospital PET cyclotron partner |
| Schematic from `firmware/doc/schematic_v0_pet_cyclotron.md` §1 + §3 | $3-5 K (single run, 5 boards) | `cargo embed --bin pet_cyclotron` | replace `state/HOSPITAL_PET_LOG.hexa` fixtures with live ¹⁸F readings |
| Symbols/footprints from §4 (KiCad library map) | 4 weeks lead time | run `firmware/sim/cyclotron_trigger.hexa` reference scenario, compare GPIO trace | demonstrate σ·τ=48 mg/season recycled stock |
| Stackup from §5 | optional: stencil + reflow | safety interlock < 10 ms (oscilloscope) | F-AM-1 T3 closes |
| **Effort**: ~40 hr | **Cost**: ~$5 K | **Effort**: 1-2 weeks | **Effort**: 6-12 months + IRB |

### Board 2 — HEXA-TABLETOP-FW-01 (tabletop Penning RF, F-AM-2)

| E1 — KiCad | E2 — Fab | E3 — Bring-up | E4 — Integration |
|:-----------|:---------|:--------------|:------------------|
| 14-layer HDI, 220 × 200 mm full Eurocard | Sanmina / TTM / Würth Elektronik | Vivado Lab Edition + JTAG | CERN AD beam slot |
| From `firmware/doc/schematic_v0_tabletop_penning.md` §1 + §3 | $15-20 K (HDI prequal) | flash `penning_rf.bit` + AD9528 PLL lock | RS-485 handshake to AD timing trunk |
| BGA breakout, microvias ≥ 0.1 mm | 6-8 weeks lead time | DAC SFDR ≥ 60 dBc at 731 MHz | 4.2 K cryogenic bring-up |
| Diff pair impedance 100 Ω ±5%, length-matched ±0.5 mm | optional: HDI stencil + X-ray inspection | first p̄ capture | `state/CERN_AD_LOG.hexa` live |
| **Effort**: ~80 hr | **Cost**: ~$25 K (board + cryo) | **Effort**: 2-3 weeks | **Effort**: 1-2 yr + AD slot |

### Board 3 — HEXA-FACTORY-FW-01 (atomic clock counter, F-AM-3)

| E1 — KiCad | E2 — Fab | E3 — Bring-up | E4 — Integration |
|:-----------|:---------|:--------------|:------------------|
| 10-layer impedance-controlled, 200 × 150 mm | Sanmina / Würth Elektronik | Vivado Lab Edition | Cs 5071A 10 MHz ref + 243 nm 1S-2S laser bench |
| From `firmware/doc/schematic_v0_atomic_clock.md` | $8-12 K | TDC7201 1 ps resolution test | line-center lock to 1S-2S transition |
| BGA-1156 (XCKU040) breakout | 4 weeks lead time | LTC2387 ENOB ≥ 22 | sub-shot-noise CPT bench |
| Hard analog/digital split | optional: stencil | full PLL chain locked | `state/CPT_BENCH_LOG.hexa` live |
| **Effort**: ~60 hr | **Cost**: ~$50 K (board + 1S-2S laser + ULE cavity) | **Effort**: 2-3 weeks | **Effort**: 1-2 yr |

### Board 4 — HEXA-PROPULSION-FW-01 (thrust acquisition, F-AM-4)

| E1 — KiCad | E2 — Fab | E3 — Bring-up | E4 — Integration |
|:-----------|:---------|:--------------|:------------------|
| 20-layer HDI, 280 × 230 mm full 6U Eurocard | Sanmina / TTM (HDI mandatory) | Vivado Lab Edition (XCVU13P largest device) | thrust bench + Watt-balance + BGO + ToF discriminators |
| From `firmware/doc/schematic_v0_thrust_acquisition.md` | $30-50 K (most expensive board) | per-ADC JESD204C link train | first thrust measurement post-Phase E2 |
| 4 lamination cycles | 8-12 weeks lead time | trigger fan-out skew ≤ 1 ns (LECROY scope) | `state/THRUST_BENCH_LOG.hexa` live |
| 0.85 V FPGA core + 16-ADC array | optional: HDI stencil + AOI | sustained 2.4 GB/s DAQ | F-AM-4 T3 closes |
| **Effort**: ~120 hr | **Cost**: ~$85-115 K (FPGA + 16 ADCs + HDI fab) | **Effort**: 3-4 weeks | **Effort**: 6-12 months |

---

## §3 Vendor matrix

### PCB fabrication

| Vendor | Capability | Strengths | Best fit |
|:-------|:-----------|:----------|:---------|
| **JLCPCB** | up to 12-layer, 0.1 mm trace | cheap, fast (1-2 wk), online quote | Boards 1, 3 |
| **OSH Park** | up to 6-layer | community-friendly, USA-made | Board 1 (alt) |
| **Sanmina** | 28+ layer HDI | enterprise-grade, military spec | Boards 2, 4 |
| **TTM Technologies** | 28+ layer HDI | telecom-grade SI, large panels | Boards 2, 4 |
| **Würth Elektronik** | 14+ layer HDI | EU presence, SI consultancy | Board 2 (alt) |
| **Advanced Circuits** | up to 16-layer | USA quick-turn | Board 3 (alt) |

### Electronic component distributors (for BOM in `firmware/doc/board_v0_*.md`)

| Vendor | Coverage |
|:-------|:---------|
| Digi-Key | full BOM (all 4 boards), single PO |
| Mouser | secondary source |
| Avnet | Xilinx FPGAs (XCZU9EG, XCKU040, XCVU13P) — distributor channel |
| Arrow | Linear Tech / Analog Devices preferred |
| LCSC | low-cost passive sourcing (capacitors, resistors, connectors) |

### Assembly

| Vendor | Capability | Best fit |
|:-------|:-----------|:---------|
| JLCPCB SMT | up to 0.4 mm pitch, 2-side reflow | Boards 1, 3 (low complexity) |
| AccuAssembly | BGA, fine-pitch, X-ray inspection | Boards 2, 4 (HDI BGA) |
| MacroFab | API-driven, US-made | Board 1 (alt) |

### Cryo/RF/laser hardware (Phase E2-E4)

| Item | Vendor | Cost | Boards |
|:-----|:-------|----:|:-------|
| Pulse-tube cryocooler 4.2 K (PT-415) | Cryomech | $80 K | Board 2 (tabletop) |
| 48 T REBCO solenoid | Bruker / SuperOX | $200-300 K | Board 2 |
| 100 MHz OCXO | Wenzel Associates | $3 K | Board 2 |
| Cs 5071A clock | Microchip (formerly Symmetricon) | $50 K | Board 3 |
| 243 nm SHG laser | Toptica | $80 K | Board 3 |
| ULE cavity | Stable Laser Systems | $40 K | Board 3 |
| Watt-balance reference | NIST custom | $20 K | Board 4 |
| BGO + PMT array | Hamamatsu / Saint-Gobain | $30 K | Board 4 |

---

## §4 Funding ladder ($staircase)

| Stage | Cost | Achieves | Earliest |
|:------|----:|:---------|:---------|
| **E1 alone** (4 boards, KiCad files only) | $0 | spec-complete repo, ready to fab | now (volunteer) |
| **E1 + Board 1 fab** (PET cyclotron only) | $5 K | smallest hardware proof-point; validates DAC + safety interlock loop | Q3 2026 |
| **E1 + Boards 1,3 fab** | $13-17 K | adds atomic clock counter; CPT bench partial bring-up | Q4 2026 |
| **E1 + Boards 1,2,3 fab** (no thrust) | $38-42 K | tabletop Penning trap (no AD slot yet, just bench tests with simulant) | Q1 2027 |
| **E1 + all 4 boards fab + bring-up** | ~$118 K | full Phase E2 + E3 complete; Phase E4 ready to start | Q2 2027 |
| **+ cryo/RF/laser equipment** (E4 hardware) | $500 K – $1 M | Stage-1 prototype operational | 2027-2028 |
| **+ CERN AD beam slot** | facility access only | first p̄ capture in tabletop trap | 2028-2030 |
| **+ factory-scale** (Phase E5, post-this-repo) | $50 M+ | 1e12 p̄/hr factory operation | 2030+ |

---

## §5 Phase E entry criteria (gates from this repo)

A Phase E hire / contractor / volunteer must verify the following before fab:

1. ✅ `verify/firmware_phase_d_lint.hexa` PASSes — Phase D paper-spec internally consistent
2. ✅ `verify/all.hexa` reports 38/38 PASS — all numerics + sim-firmware + cross-cuts green
3. ✅ Per board: `firmware/doc/board_v0_*.md` BOM has catalog SKUs (not just chip families)
4. ✅ Per FPGA board: `firmware/hdl/{board}.v` synthesizes in Vivado 2024.1+ for the target part
5. ✅ Per FPGA board: `firmware/hdl/{board}.xdc` placement is legal (Vivado linter passes)
6. ✅ Per MCU board: `firmware/mcu/{board}.rs` `cargo check --target {board-target}` succeeds
7. ✅ `firmware/doc/schematic_v0_*.md` §3 net list is complete — every signal has a length budget + impedance + layer hint
8. ✅ Recent CHANGELOG entry within ≤ 30 days (paper specs not stale)

If any of 1–7 fails, do NOT proceed to fab — fix the paper spec first.

---

## §6 Anti-patterns (avoid)

- ❌ **Don't fab without the lint passing.**  Phase D specs catch most schematic-vs-sim drift before they cost $$$.
- ❌ **Don't fab one board if you can co-fab multiple.**  Setup cost dominates; if budget allows 2 boards, fab them in the same panel run.
- ❌ **Don't skip impedance control on Boards 2 and 4.**  100 Ω ±5% diff pair tolerance is non-negotiable for JESD204C @ 32 Gbps.
- ❌ **Don't flash before electrical bring-up.**  Test power rails, JTAG, and basic GPIO via test patterns first.
- ❌ **Don't promise CERN AD slot before E2.**  AD slots are scheduled 12-18 months in advance; only request after physical board exists.
- ❌ **Don't skip the safety officer.**  48 T magnet + cryo + radiation = 3 separate insurance categories.

---

## §7 Phase E artefact map

What lands in this repo when Phase E completes (target paths):

```
hexa-antimatter/
├── pcb/                                 ← NEW: KiCad source
│   ├── pet_cyclotron/
│   │   ├── pet_cyclotron.kicad_pro
│   │   ├── pet_cyclotron.kicad_sch
│   │   ├── pet_cyclotron.kicad_pcb
│   │   ├── gerbers/
│   │   └── BOM.csv
│   ├── tabletop_penning/
│   ├── atomic_clock/
│   └── thrust_acq/
│
├── state/                               ← NEW: live data feeds (Phase E4)
│   ├── HOSPITAL_PET_LOG.hexa            ← F-AM-1 live ¹⁸F readings
│   ├── CERN_AD_LOG.hexa                 ← F-AM-2 live p̄ capture
│   ├── CPT_BENCH_LOG.hexa               ← F-AM-3 live 1S-2S transitions
│   └── THRUST_BENCH_LOG.hexa            ← F-AM-4 live impulse events
│
├── verify/empirical_*.hexa              ← UPDATED: ingest live state/ feeds, replace fixtures
└── firmware/build/                      ← NEW: bitstreams + .elf
    ├── pet_cyclotron.elf
    ├── tabletop.bit
    ├── atomic_clock.bit
    └── thrust_acq.bit
```

When `state/*.hexa` files land with live readings, F-AM-1/2/3/4 T3 transitions from "paper closure" to "empirical closure" — and the v1.1.0 100% bookkeeping closure becomes 100% empirical closure (i.e., truly retracted falsifiers, or honest negatives if data disagrees).

---

## §8 Forward-pointer

When Phase E1 begins, replace this doc with:
- `firmware/doc/PHASE_E1_KICAD_LOG.md` — per-board KiCad progress log
- `firmware/doc/PHASE_E2_FAB_LOG.md` — per-board fab + assembly log
- `firmware/doc/PHASE_E3_BRINGUP_LOG.md` — per-board bring-up log + scope captures
- `firmware/doc/PHASE_E4_DATAFEED_LOG.md` — per-board live data feed schema

Until then, this is the canonical Phase E reference.