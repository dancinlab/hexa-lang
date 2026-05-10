<!-- @canonical: pending-upstream:domains/space/recovery/recovery.md -->
<!-- @extracted: 2026-05-07 -->
<!-- @origin: hexa-space@local-draft (canon upstream pending) -->
<!-- @group: operations (extension verb) -->

# 🪂 hexa-recovery — n=6 booster recovery verb (drone-ship + chopstick)

> **operations group · extension verb (8/15)** · SpaceX **ASDS +
> chopstick catch** recovery fleet on the n=6 lattice.

## §1 WHY

Recovery = **φ=2 modes** (RTLS / ASDS) × **τ=4 trajectory regimes**
(boostback / re-entry / aero / land). 3 active drone-ships
(OCISLY/JRTI/ASOG) = n/φ. Chopstick catch arms = φ=2 per tower.

| Effect | Current (2026) | n=6 target | rationale |
|---|---|---|---|
| Recovery modes | 2 | **φ=2** | φ |
| Trajectory regimes | 4 | **τ=4** | τ |
| Active drone-ships | 3 | **n/φ=3** | n/φ |
| Chopstick arms / tower | 2 | **φ=2** | φ |
| Hold-down arms / pad (Pad 2) | 20 | **J₂−τ=20** | J₂ ladder |
| Catch tolerance window (s) | ~2 | **φ=2** | φ |

## §2 n=6 CONNECTION

| Anchor | Value | Recovery read |
|---|---|---|
| n | 6 | recovery subsystems (Avi/GNC/HLP/Hyd/Net/Catch) |
| σ | 12 | telemetry channels during catch |
| τ | 4 | trajectory regimes |
| φ | 2 | RTLS/ASDS or per-arm dichotomy |
| J₂ | 24 | hold-down + cushion arms total per Pad 2 |

## §3 IMPLEMENTATION

| Component | n=6 anchor |
|---|---|
| OCISLY (Atlantic) | drone-ship 1 |
| JRTI (Atlantic) | drone-ship 2 |
| ASOG (Pacific) | drone-ship 3 (n/φ=3 total) |
| Chopstick arms | φ=2 per Mechazilla tower |
| Hold-down arms | J₂−τ=20 per Pad 2 |
| Catch chilldown vent | 3 outlets = n/φ |

## §4 STATUS

- v1.0.0: SPEC_ONLY (`.md` + `verify_recovery.hexa`).
- Cross-link: `aerospace_transport/spacex_intel_2026.md` §2.11 (Pad 2
  chopstick + 20 hold-down arms).

## §5 PROVENANCE

Drafted 2026-05-07.
