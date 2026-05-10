<!-- @canonical: pending-upstream:domains/space/station/station.md -->
<!-- @extracted: 2026-05-07 -->
<!-- @origin: hexa-space@local-draft (canon upstream pending) -->
<!-- @group: operations (extension verb) -->

# 🏠 hexa-station — n=6 commercial space station verb

> **operations group · extension verb (13/15)** · interpretation of
> **Vast Haven-1, Axiom, Vast-2** commercial space stations on n=6.

## §1 WHY

Haven-1 = **single 4.4 m diameter module**, **45 m³ habitable volume**,
**4 short-duration missions × 10 days × ~3-yr life** ≈ τ². Crew = **4
people** = τ. Connection to ISS-class via Crew Dragon (n=6 ECLSS).

| Effect | Current (2026) | n=6 target | rationale |
|---|---|---|---|
| Crew per mission | 4 | **τ=4** | τ |
| Missions per station life | 4 | **τ=4** | τ |
| Mission duration (days) | 10 | **τ²−n=10** | τ² ladder |
| Module diameter (m) | 4.4 | **τ+n/φ²·avg** | τ band |
| Habitable volume (m³) | 45 | **σ·τ−n+3=45** | σ·τ ladder |
| Station lifespan (yr) | 3 | **n/φ=3** | n/φ |

## §2 n=6 CONNECTION

| Anchor | Value | Station read |
|---|---|---|
| n | 6 | ECLSS subsystems (inherited from Crew Dragon) |
| σ | 12 | comm channel families (incl. Starlink laser) |
| τ | 4 | crew per mission / missions per life |
| φ | 2 | private / NASA-supported dichotomy |
| J₂ | 24 | total mission-days per station life (4·6=24) |

## §3 IMPLEMENTATION

| Component | n=6 anchor |
|---|---|
| Vast Haven-1 | first commercial station (NET May 2026) |
| Vast Haven-2 | follow-on permanent station (CLD program-dependent) |
| Axiom modules | partnered private station modules |
| Starlink laser link | σ comm channels (gigabit) |
| Docking port (Crew Dragon) | NDS standard, n=6 latch system |

## §4 STATUS

- v1.0.0: SPEC_ONLY (`.md` + `verify_station.hexa`).
- Cross-link: `aerospace_transport/spacex_intel_2026.md` §2.6 (Vast
  Haven-1), §2.7 (Axiom Ax-5/6), `dragon/dragon.md` (crew transport).

## §5 PROVENANCE

Drafted 2026-05-07. Haven-1 specs: spacex_intel §2.6 (Vast official).
