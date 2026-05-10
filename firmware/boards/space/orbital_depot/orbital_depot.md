<!-- @canonical: pending-upstream:domains/space/orbital_depot/orbital_depot.md -->
<!-- @extracted: 2026-05-07 -->
<!-- @origin: hexa-space@local-draft (canon upstream pending) -->
<!-- @group: operations (extension verb) -->

# ⛽ hexa-orbital-depot — n=6 orbital propellant depot verb

> **operations group · extension verb (9/15)** · SpaceX **propellant
> transfer demo + HLS depot architecture** on the n=6 lattice.

## §1 WHY

A Starship lunar mission needs **~10 tanker launches** to refuel a
depot ship — close to σ=12 ladder. Each transfer = **2 ships docked**
(φ=2), τ=4 fluid-regime stages (chill / fill / press / release),
J₂=24-hour transfer-window cap.

| Effect | Current (2026) | n=6 target | rationale |
|---|---|---|---|
| Tanker launches per refuel | ~10 | **σ=12** ceiling | σ |
| Ships docked per transfer | 2 | **φ=2** | φ |
| Fluid regimes | 4 | **τ=4** | τ |
| Transfer-window cap (hr) | ≤24 | **J₂=24** | J₂ |
| Cryogenic insulation layers | 6 | **n=6** | n |
| Header-tank quick-disconnects | 12 | **σ=12** | σ |

## §2 n=6 CONNECTION

| Anchor | Value | Depot read |
|---|---|---|
| n | 6 | cryogenic insulation layers |
| σ | 12 | tanker launch ceiling per HLS refuel |
| τ | 4 | chill/fill/press/release fluid regimes |
| φ | 2 | tanker / depot dichotomy |
| J₂ | 24 | transfer window hours (in-orbit pass) |

## §3 IMPLEMENTATION

| Component | n=6 anchor |
|---|---|
| Tanker Starship | σ ≥ launches/HLS refuel |
| Depot Starship | central reservoir |
| Quick-disconnect ring | σ=12 propellant lines |
| Vacuum jacket | n=6 layers |
| Header tank | τ=4 valve regimes |

## §4 STATUS

- v1.0.0: SPEC_ONLY (`.md` + `verify_orbital_depot.hexa`).
- Demo target 2026 (slipping); HLS surface mission requires it.
- Cross-link: `aerospace_transport/spacex_intel_2026.md` §2.2 (orbital
  prop transfer demo).

## §5 PROVENANCE

Drafted 2026-05-07. Wikipedia + TechCrunch refs in spacex_intel §5.
