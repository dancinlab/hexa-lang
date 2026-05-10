# CERN baseline — LHC vs DESY vs HEXA σ-φ

> Scope: design-target comparison only. **Specs only, .hexa CLI TBD.** σ-cascade 6-order figures are HEXA design ceilings, NOT measurements. Stage-1+ benchtop builds required for empirical validation.

Provenance: extracted from `canon@c0f1f570` (`domains/physics/mini-accelerator/`, `particle-accelerator/`, `classical-mechanics-accelerator/`) on 2026-05-06.

n=6 lattice constants used below: σ(6)=12, τ(6)=4, φ(6)=2.

---

## Comparison table

| facility / spec              | total energy   | gradient (per metre) | footprint        | mode             | cost class        | reference                                  |
|:-----------------------------|:--------------:|:---------------------:|:-----------------|:-----------------|:------------------|:-------------------------------------------|
| **CERN LHC**                 | 7 TeV (×2)     | ~5 MeV/m (RF cavity)  | 27 km ring       | proton-proton    | $4.75 B build     | CERN Annual Report                         |
| **DESY laser-plasma**        | ~1 GeV         | **1 GeV/m**           | research-lab     | electron, pulsed | ~$10 M class      | DESY FLASHForward / LUX                    |
| **HEXA σ-φ design ceiling**  | 100 MeV        | **σ-φ = 10 GeV/m**    | **benchtop 0.1 L** | continuous       | **~$0 Mac local** for spec; build TBD | `mini/doc/mini-accelerator.md` (this repo) |

### Order-of-magnitude deltas (HEXA ceiling vs DESY)

```
gradient:    DESY 1 GeV/m  → HEXA σ-φ = 10 GeV/m            ×10
footprint:   research-lab  → benchtop 0.1 L                 ÷10  (1/(σ-φ))
duty cycle:  pulsed (~Hz)  → continuous                     qualitative step-change
```

### σ-cascade 6-order ceiling (HEXA design vs current)

| effect              | current baseline       | HEXA design ceiling           | ratio              |
|---------------------|------------------------|-------------------------------|--------------------|
| precision           | 1.0 unit               | σ-φ = 10×                     | ×10                |
| throughput          | 1.0×                   | σ² = 144×                     | ×144               |
| energy cost         | 100%                   | 1/σ ≈ 8.3%                    | ÷12                |
| equipment size      | 1.0 L (or 27 km)       | 1/(σ-φ) = 0.1 L (benchtop)    | ÷10                |
| error rate          | 1%                     | 1/σ² ≈ 0.7%                   | ÷144               |
| lifetime            | 1 year                 | σ·τ = 48 months                | ×48                |

---

## Honesty (raw#10 C3)

1. The HEXA column is **design-target ceiling**. v1.0.0 ships specs only — no benchtop hardware yet.
2. LHC and DESY columns are public-domain figures (CERN Annual Report; DESY FLASHForward / LUX publications); no live data feed or proprietary calibration in this repo.
3. The σ-cascade 6-order ratios derive from n=6 perfect-number arithmetic applied per-axis. Per-axis empirical validation is deferred per pillar:
   - `mini` → Stage-1+ laser-plasma benchtop sandbox
   - `parent` → Stage-2+ integrated parent build
   - `classical` → Stage-1+ classical-mechanics baseline solver
4. SC magnet substrate (mini pillar) depends on `dancinlab/hexa-rtsc`, which is itself a separate spec/empirical roadmap.

---

## See also

- [`mini/doc/mini-accelerator.md`](../mini/doc/mini-accelerator.md)
- [`parent/doc/particle-accelerator.md`](../parent/doc/particle-accelerator.md)
- [`classical/doc/classical-mechanics-accelerator.md`](../classical/doc/classical-mechanics-accelerator.md)
- Cross-link: [`dancinlab/hexa-rtsc`](https://github.com/dancinlab/hexa-rtsc), [`dancinlab/hexa-antimatter`](https://github.com/dancinlab/hexa-antimatter), [`dancinlab/hexa-ufo`](https://github.com/dancinlab/hexa-ufo)
