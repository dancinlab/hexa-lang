# hexa-antimatter v1.0.0 — initial extraction

**Release date**: 2026-05-06
**Provenance**: `canon` SHA `c0f1f570`
**License**: MIT

---

## Summary

`hexa-antimatter` v1.0.0 is the initial standalone extraction of the antimatter
substrate from `canon/domains/physics/` into a public GitHub repo
under the `dancinlab` org. The package ships a **3-verb spec-first
scaffold** organized around the n=6 Dirac-mirror lattice.

```
σ(6) = 12   τ(6) = 4   φ(6) = 2   J₂ = 24
master identity:   σ · φ = n · τ = 24
```

## What's in v1.0.0

- 3 verbs (all SPEC, no working numerical implementation):
  1. **factory** — CERN-scale antimatter factory (1e12 p-bar/hr design,
     24-month Penning trap storage, σ·τ = 48 T RT-SC).
  2. **tabletop** — desktop p-bar factory (0.29 m³ volume, 1.7e12 p-bar/s
     candidate, 16-yr storage, $2.1e4/mg).
  3. **pet_cyclotron** — ¹⁸F β⁺ on-site regeneration (R = 10 cm, B = 48 T,
     48 mg ¹⁸F/season).
- Placeholder CLI router `cli/hexa-antimatter.hexa` (sentinels + status + selftest).
- `hexa.toml` manifest, `install.hexa` hx hook, `tests/test_selftest.hexa`.
- README with §Why / §Verbs / §Status / §Install / §Cross-link / §License.

## What's NOT in v1.0.0 (honest scope, raw#10 C3)

- **No working numerical sandbox.** The `.hexa` CLI is a placeholder; all 3 verbs
  print sentinels only.
- **No empirical verification.** n=6 Dirac-mirror lattice is an algebraic
  conjecture; headline numbers are academia-unproven candidates from
  declarative `.md` SSOT.
- **No apparatus, no clinical PET, no anti-H synthesis.** Out-of-repo for v1.0.0
  and beyond (this repo is a substrate spec, not an experimental rig).

## Cross-links

- Accelerator cousin: `dancinlab/hexa-cern`
- Stage-3 propulsion fuel consumer: `dancinlab/hexa-ufo`
- HEXA family sister: `dancinlab/hexa-bio` (molecular toolkit)
- Upstream `.md` SSOTs in `canon/domains/physics/`:
  - `antimatter-factory/antimatter-factory.md`
  - `tabletop-antimatter/tabletop-antimatter.md`
  - `pet-cyclotron/pet-cyclotron.md`

## Roadmap (post-v1.0)

- v1.1 — convert at least 1/3 verbs from SPEC to a wired numerical sandbox.
- v1.2 — full 3/3 wired; n=6 Dirac-mirror lattice falsifier preregister.
- v2.0 — empirical fit (literature corpus only; no proprietary calibration).
