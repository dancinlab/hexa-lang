# Calorimetry Rig v0 — BCS ΔC/γTc Specific-Heat Bench

> Stage-1+ hardware spec, draft. **Out of RSC code-layer scope** per
> `.roadmap.hexa_rtsc §A.6`. §A.6.1 Stage A deliverable.

**Status**: paper design (2026-05-08). No procurement.
**Owner**: TBD.

## §1 WHY

To close `F-SC-3` (BCS specific-heat jump ratio ΔC/γTc ≠ ~1.43 → DEMOTE
σ(6)=12 molecule) at **strict-T3** tier, an in-house calorimetry bench
is required. The n=6 derivation gives ΔC/γTc = σ(6)/(7·ζ(3)) ≈ 1.426
which must be cross-verified on s-wave SC samples (Pb, Nb, V₃Si) and
on putative RT-SC candidates (LK-99 successors).

Also closes `F-SC-1` (Cooper pair size φ=2 — derivable from gap
extraction) and `F-SC-2` (Abrikosov vortex CN=6 — derivable from
mixed-state ΔC anomalies).

## §2 ANCHORS

- ΔC/γTc = σ(6)/(7·ζ(3)) ≈ 1.4257 (n=6 closed form)
- BCS universal 2Δ(0)/kTc = π·e^{-γ_E}·φ(6) ≈ 3.5279
- `verify/numerics_bcs.hexa` + `verify/numerics_bcs_solver.hexa`
  (T2 ×3 stack)

## §3 BOM (compact)

| # | Item | Spec | Vendor | Cost (USD) |
|:-:|:-----|:-----|:------|:----------:|
| 1 | Adiabatic calorimeter | 0.1–300 K, ± 0.1 % | QD PPMS HC option | 90k |
| 2 | Dilution refrigerator | 10 mK base | BlueFors LD-400 | 480k |
| 3 | Sample mounts | sapphire stage + Pt RTD | custom | 8k |
| 4 | Heat pulse generator | 1 nJ–10 mJ, 1 ms–10 s | Keithley 6221 | 12k |
| 5 | μ-metal shielded room | 4 × 4 m, < 1 nT residual | MMT | 65k |
| 6 | LHe/LN₂ supply | 100 L LHe/wk, 200 L LN₂/wk | local | $4k/mo ops |
| 7 | Vibration isolation table | active piezo-damped | Newport S-2000A | 28k |
| 8 | DAQ + control | NI cDAQ + LabVIEW | NI | 18k |

**Subtotal**: ≈ 700k USD + ops.

## §4 Block diagram

```
   ┌──────────────────────────────────┐
   │  μ-metal SHIELDED ROOM (BOM #5)  │
   │  ┌────────────────────────────┐  │
   │  │  DILUTION FRIDGE (#2)      │  │
   │  │  10 mK base, < 1 K Cu can  │  │
   │  │  ┌─────────────────────┐   │  │
   │  │  │  SAPPHIRE MOUNT (#3)│   │  │
   │  │  │  + Pt RTD + heater  │◀──┼──┼──── heat pulse (BOM #4)
   │  │  └─────────────────────┘   │  │
   │  └────────────────────────────┘  │
   └──────────────┬───────────────────┘
                  ▼
       T(t) trace → DAQ (BOM #8)
       → ΔT/Δt fit → C(T)
       → ΔC at Tc + γT extraction
       → ΔC/γTc ratio
       → schema raw_77_sc_bcs_ratio_sigma12_v1
```

## §5 Interface table

| Source | Sink | Protocol | Rate | Note |
|:------|:----|:--------|:----:|:-----|
| Pt RTD | DAQ 4-wire | analog | 100 Hz | T(t) trace |
| Heat pulse | sample heater | constant-current source | per-pulse | ± 0.1 nJ resolution |
| Mixing chamber T | dilution-fridge bus | TCP | 1 Hz | base-T monitor |
| He level | Lakeshore | RS-232 | 0.1 Hz | refill alarm |

## §6 Safety spec

- LHe + dilution-mix (³He/⁴He): ³He inventory ~10 L at $1k/L; cold
  trap on exhaust.
- Liquid N₂ pre-cool: O₂ monitor in shielded room; 19 %/18 % alarms.
- 10 mK temperature: thermal-radiation shields, cryogen O-ring
  inspection per fill.
- μ-metal handling: anneal cycle every 6 mo (residual field creep).

## §7 Verification path

| Tier | What closes it | Status |
|:-:|:-----------------|:-:|
| T1 algebraic | `verify/calc_bcs.hexa` | ✓ |
| T2 numerical | `verify/numerics_bcs{,_parity,_solver}.hexa` | ✓ |
| T3 archival  | `verify/empirical_specific_heat_arxiv.hexa` | ✓ |
| T3 raw-data  | this rig produces `raw_77_sc_bcs_ratio_sigma12_v1` | **TBD** |

## §8 Build path

| Step | What | Cost (cum.) | Time |
|:-:|:-----|:-----------:|:----:|
| 0 | This document | $0 | 1 d ✓ |
| 1 | Drawings + dilution-fridge install plan | $15k | 2 mo |
| 2 | Procurement (BOM #1–8) | $700k | 9 mo |
| 3 | Commissioning (10 mK base + Pb baseline run) | $50k | 4 mo |
| 4 | s-wave reference cohort (Pb / Nb / V₃Si ΔC measurements) | $30k/yr | 6 mo |

Total to **F-SC-3 strict-T3 closure**: ≈ $0.8M + 17 months.

## §9 Open questions

- 10 mK base needed (dilution) vs 0.3 K base (³He fridge, $200k cheaper)?
  Latter sufficient for Pb/Nb/V₃Si but not for sub-K candidate
  unconventional pairing.
- Sample mass: 1 mg suffices via PPMS heat-capacity option; LK-99-class
  novel synthesis often yields < 0.1 mg single-phase — needs nano-cal
  upgrade ($150k delta).

## §10 Cross-references

- `verify/numerics_bcs_solver.hexa` (Newton on gap eq → 2Δ/kTc check)
- `verify/empirical_specific_heat_arxiv.hexa`

---

**Authority**: §A.6.1 Stage A paper-design.
