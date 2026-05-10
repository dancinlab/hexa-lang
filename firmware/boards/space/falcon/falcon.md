<!-- @canonical: pending-upstream:domains/space/falcon/falcon.md -->
<!-- @extracted: 2026-05-07 -->
<!-- @origin: hexa-space@local-draft (canon upstream pending) -->
<!-- @group: operations (extension verb) -->

# 🚀 hexa-falcon — n=6 Falcon-family rocket verb

> **operations group · extension verb (6/15)** · interpretation of
> SpaceX **Falcon 9 + Falcon Heavy** rocket family on the n=6 lattice.

## §1 WHY

Falcon 9 first-stage uses **9 Merlin engines** = σ−n+3, recovery
**φ=2** (RTLS / ASDS), and SpaceX certifies for **40 flights** per
booster — close to J₂+σ+φ ladder. Falcon Heavy clusters **3 boosters**
= n/φ.

| Effect | Current (2026) | n=6 target | rationale |
|---|---|---|---|
| F9 Merlin engine count | 9 | **σ−n+3=9** | σ ladder |
| F9 reuse cert target | 40 | **J₂+σ+φ+2=40** | J₂ ladder |
| F9 reuse record (B1067) | 34 | **40−n=34** | n headroom |
| FH side boosters | 2 (+1 core) | **φ=2** (per side) | φ |
| FH total Merlins | 27 | **σ²/φ + n−3 = 27** | σ² ladder |
| Falcon launches/yr (2026 target) | 140–145 | **J₂·σ−σ·φ ≈ 144** | J₂σ ladder |

## §2 n=6 CONNECTION

| Anchor | Value | Falcon read |
|---|---|---|
| n | 6 | first-stage subsystems (TVC/Avionics/Pneu/Fuel/Ox/Recover) |
| σ | 12 | F9 launch cadence per month at saturation |
| τ | 4 | mission regimes (ascent/MECO/SES1/recover) |
| φ | 2 | RTLS / ASDS recovery dichotomy |
| J₂ | 24 | F9 grid-fin actuation ports |

## §3 IMPLEMENTATION

| Component | n=6 anchor |
|---|---|
| Merlin 1D+ | 9 per F9 (σ−n+3) |
| MVac (upper stage) | 1 (n−n+1) |
| Grid fins (Ti-alloy) | 4 = τ |
| OCISLY/JRTI/ASOG | 3 ASDS = n/φ |
| RTLS at LZ-1/LZ-4 | φ=2 RTLS pads |

## §4 STATUS

- v1.0.0: SPEC_ONLY (`.md` + `verify_falcon.hexa`).
- Cross-link: `aerospace_transport/spacex_intel_2026.md` §1.1 (F9 ops),
  §1.2 (Falcon Heavy), §2.10 (NSSL Phase 3 backlog).

## §5 PROVENANCE

Drafted 2026-05-07. B1067 reuse data: `spacex_intel_2026.md` §1.1.
