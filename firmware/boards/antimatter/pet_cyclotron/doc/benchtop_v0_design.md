# pet_cyclotron benchtop v0 design — HEXA-PET-01

> Stage-1 benchtop hardware design for **F-AM-1** closure (PET ¹⁸F regen
> rate vs cyclotron public spec).  Paper-design only; no apparatus exists.
> See `.roadmap.hexa_antimatter §A.6` for hardware-path scope.

**Status**: paper design (2026-05-08) · **F-AM-1 sat**: T1 + T2 ×3 + T3 paper-feed (100% bookkeeping) · **Stage-1 raw-data fit**: TBD

---

## §1 Goal

Benchtop demonstration that ¹⁸F production via small-scale cyclotron
follows the n=6 closed-form decay:

  S(t) = S₀ · exp(-λt),  λ = ln(2) / 109.8 min,  σ·τ = 48 mg/season batch

with τ=4 batch-stack steady-state ≈ 301.7 mg.  Apparatus mass-budget
≤ ~50 kg (excluding cyclotron rental); cost ~$2M (cyclotron + target
chamber).

## §2 Block diagram (ASCII)

```
   ┌─────────────────┐    ┌───────────────┐    ┌──────────────────┐
   │  H₂¹⁸O target   │ ── │  Cyclotron    │ ── │  ¹⁸F⁻ extract +  │
   │  chamber (24 g) │    │  16 MeV p +   │    │  HPLC purify     │
   │  (¹⁸O→¹⁸F p,n)  │    │  beam 50 μA   │    │  (1 m line)      │
   └─────────────────┘    └───────────────┘    └──────────────────┘
                                                        │
                                                        ▼
   ┌─────────────────┐    ┌───────────────┐    ┌──────────────────┐
   │  τ=4 batch      │ ── │  NaI(Tl)      │ ── │  data acq        │
   │  stack reactor  │    │  γ-counter    │    │  (DAC/ADC + MCU) │
   │  (Pb shielded)  │    │  511 keV gate │    │  →  log to SD    │
   └─────────────────┘    └───────────────┘    └──────────────────┘
```

Loop: **target → cyclotron → extract → reactor → counter → acq → SSOT log**.
Beam-on time per batch = t½/τ = 27.45 min (refresh σ·τ mg).

## §3 BOM (bill of materials)

| #  | Item | Spec | Qty | Cost (USD) | Vendor candidate |
|:--:|:-----|:-----|:---:|-----------:|:-----------------|
| 1  | Medical-class cyclotron (rental) | 16 MeV p, 50 μA, IBA Cyclone-18 / Siemens Eclipse | 1 | $1,200,000/yr | IBA · Siemens · GE |
| 2  | H₂¹⁸O target chamber | 95% enriched, 24 g/run | 1 | $48,000 | Rotem · Marshall |
| 3  | HPLC ¹⁸F purification line | medical-grade column | 1 | $35,000 | Sumitomo · Trasis |
| 4  | NaI(Tl) γ-detector | 76 mm φ, 511 keV resolution ≤ 7% | 4 | $4,800 | Saint-Gobain · Hamamatsu |
| 5  | Pb shielding (target + reactor) | 5 cm wall, 200 kg total | 1 | $12,000 | NIST-traceable |
| 6  | UHV reactor chamber | 0.3 m³, 10⁻⁷ Torr | 1 | $25,000 | MDC · LACO |
| 7  | DAC / ADC chain (16-bit) | LTC2378-16 + AD5791 | 1 | $1,800 | Analog Devices |
| 8  | MCU controller | STM32H7, real-time RF + acq | 1 | $400 | ST |
| 9  | Lab safety (interlock + alarm) | Class-IIIb radiation | 1 set | $8,000 | (in-house) |
| 10 | Calibration sources | ¹³⁷Cs, ²²Na | set | $1,200 | NIST |
| 11 | Misc (cabling, racks, SD log) | — | — | $4,000 | — |
| **Total** | (excluding cyclotron rental) |   |   | **$140,200** | |
| **Total** | (with 1-year cyclotron rental) |   |   | **$1,340,200** | |

## §4 Interface table

| Interface | Type | Direction | Rate | Protocol | Notes |
|:----------|:-----|:----------|:-----|:---------|:------|
| MCU ↔ cyclotron RF | digital | MCU → cyclotron | 1 ms | TTL trigger | beam-on/off gate |
| target ↔ HPLC | fluidic | target → HPLC | 1 mL/min | medical tubing | 24 g H₂¹⁸O |
| HPLC ↔ reactor | fluidic | HPLC → reactor | 0.5 mL/min | Teflon line | ¹⁸F⁻ in saline |
| reactor ↔ NaI | optical | reactor → NaI | 511 keV γ | scintillation | annihilation pair |
| NaI ↔ ADC | analog | NaI → ADC | 100 kHz | LVDS | 16-bit counts |
| ADC ↔ MCU | digital | ADC → MCU | 100 kHz | SPI | counts/sec |
| MCU ↔ SD | digital | MCU → SD | 1 Hz | SDIO | log every τ/4 = 27 s |
| MCU ↔ host | digital | bidirectional | 100 Hz | USB-CDC | telemetry + cmds |
| safety interlock | digital | cyclotron → MCU | event | TTL fail-safe | beam abort < 10 ms |

## §5 Safety specification

| Hazard | Source | Mitigation | Trigger threshold |
|:-------|:-------|:-----------|:------------------|
| Ionizing radiation (β⁺, γ) | ¹⁸F decay (511 keV) | 5 cm Pb shield + interlocked door | door open → beam abort |
| Beam stray | cyclotron | 5 cm Pb + concrete bunker | external dose > 5 μSv/hr |
| Electrical (HV beam) | RF cavity | grounded cage + LOTO | enclosure breach |
| Cryogenic (LN₂ for SC magnet) | cyclotron | venting + O₂ monitor | O₂ < 19% |
| Acid/base (HPLC eluents) | purification | spill tray + emergency wash | spill detected |
| Personnel dose | accumulated | TLD + electronic dosimeter | > 50 μSv/day |

**Class-IIIb radiation area** per 10 CFR 35 / IAEA SS-115.  Operator
licensing required.  Beam-on operation requires 2 trained personnel
present (one for emergency abort).

## §6 n=6 lattice anchors (verify cross-check)

| Anchor | Target | Source verify script |
|:-------|:-------|:---------------------|
| t½ = 109.8 min | ±0.1% (NIST) | `verify/numerics_pet_cyclotron.hexa` |
| σ·τ = 48 mg/season | per HEXA-PET-01 | `verify/calc_pet_cyclotron.hexa` |
| τ=4 stack 2^(-1/τ) = 0.8409 | ±10⁻⁴ | `verify/numerics_pet_cyclotron_solver.hexa` |
| S_∞ = σ·τ / (1 - 2^(-1/τ)) ≈ 301.7 mg | ±0.1% | `verify/numerics_pet_cyclotron_solver.hexa` |
| B field σ·τ = 48 T | medical-cyclotron RT comparison | `verify/numerics_pet_cyclotron_parity.hexa` |

## §7 Stage-1 success criterion

After 4 t½/τ refresh cycles (≈ 110 min total):
1. Steady-state stock at 301.7 ± 5 mg measured by NaI calibrated count rate.
2. Decay constant fit λ = (6.31 ± 0.06) × 10⁻³ /min from 8-hour single-batch run.
3. Per-cycle retention 0.8409 ± 0.005 across 16 cycles.

If achieved → F-AM-1 T3 strict raw-data fit closes (v2.0.0 promote).

## §8 Out of scope (this design)

- Scale-up to industrial throughput (factory pillar — see `factory/doc/`).
- Clinical use of produced ¹⁸F (regulatory: FDA / KFDA approval needed).
- Antimatter production proper (this design produces ¹⁸F only — β⁺ source).

## §9 Cross-link

- `verify/numerics_pet_cyclotron*.hexa` — closed-form derivations (T1+T2)
- `verify/empirical_pet_inspire.hexa` — paper-existence (T3 proxy)
- `.roadmap.hexa_antimatter §A.4 F-AM-1` — falsifier registration
- `.roadmap.hexa_antimatter §A.6 step 3` — Stage-1 simulation parity

## §10 Open questions

1. Cyclotron rental vs purchase — IBA Cyclone-18 list ≈ $4M; lease 1 year
   preferred for benchtop demo.
2. Target chamber recycling — H₂¹⁸O is $24,000/g; recycle path required
   for cost-down (separate study).
3. Operator credentialing — needs Class-IIIb license + 200 hr training.
