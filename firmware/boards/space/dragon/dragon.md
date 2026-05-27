<!-- @canonical: pending-upstream:domains/space/dragon/dragon.md -->
<!-- @extracted: 2026-05-07 -->
<!-- @origin: hexa-space@local-draft (canon upstream pending) -->
<!-- @group: operations (extension verb) -->

# 🐉 hexa-dragon — n=6 Dragon capsule family verb

> **operations group · extension verb (7/15)** · interpretation of
> **Crew Dragon + Cargo Dragon** capsule family on the n=6 lattice.

## §1 WHY

Crew Dragon = **6-seat** capsule (max), Cargo Dragon = **2-section**
(pressurized + trunk = φ), CRS-33 boost-kit added **6 hydrazine tanks**
+ **2 Draco thrusters** matching n + φ. Crew rotation cadence ≈ τ=4
slot/yr at ISS.

| Effect | Current (2026) | n=6 target | rationale |
|---|---|---|---|
| Max crew seats | 4 (NASA std) | **n=6** (full) | n directly |
| ECLSS subsystems | 6 | **n=6** | n directly |
| Capsule sections | 2 | **φ=2** (cabin/trunk) | φ |
| Draco thrusters | 16 | **σ+τ=16** | σ+τ |
| SuperDraco abort | 8 | **J₂/n+τ=8** | J₂ ladder |
| ISS slot cadence (yr) | ~4 (Crew + Axiom) | **τ=4** | τ |
| Boost-kit hydrazine tanks | 6 | **n=6** | n |

## §2 n=6 CONNECTION

| Anchor | Value | Dragon read |
|---|---|---|
| n | 6 | seats (max) / ECLSS subsystems / boost-tanks |
| σ | 12 | Draco thrusters base count (σ) + τ-extension = 16 |
| τ | 4 | ISS rotation slots/yr |
| φ | 2 | cabin/trunk dichotomy |
| J₂ | 24 | mission profile types |

## §3 IMPLEMENTATION

| Component | n=6 anchor |
|---|---|
| Crew Dragon Endeavour/Resilience/Endurance/Freedom | 4 = τ active capsules |
| Cargo Dragon | unpressurized trunk J₂/n=4 standard rack carriers |
| Draco RCS | σ+τ=16 thrusters |
| SuperDraco | J₂/n+τ=8 abort thrusters |
| CRS boost-kit (CRS-33+) | n=6 hydrazine tanks + φ=2 Dracos |

## §4 STATUS

- v1.0.0: SPEC_ONLY (`.md` + `verify_dragon.hexa`).
- Cross-link: `aerospace_transport/spacex_intel_2026.md` §1.4 (Crew Dragon),
  §1.5 (Cargo Dragon CRS-32/33).

## §5 PROVENANCE

Drafted 2026-05-07. CRS-33 boost-kit: `spacex_intel_2026.md` §1.5.
