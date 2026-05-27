<!-- @canonical: pending-upstream:domains/space/hls/hls.md -->
<!-- @extracted: 2026-05-07 -->
<!-- @origin: hexa-space@local-draft (canon upstream pending) -->
<!-- @group: operations (extension verb) -->

# 🌙 hexa-hls — n=6 Human Landing System (Starship HLS variant) verb

> **operations group · extension verb (10/15)** · interpretation of
> **NASA Artemis HLS** Starship variant on the n=6 lattice.

## §1 WHY

HLS Starship is a **modified Starship V3** without aerodynamic surfaces,
with **4 lunar legs** (τ), **6 throttle-down landing engines** (n), and
target **24 t** of payload to lunar surface (J₂). Rebaselined Feb 2026
to LEO rendezvous demo NET 2027.

| Effect | Current (2026) | n=6 target | rationale |
|---|---|---|---|
| Landing legs | 4 | **τ=4** | τ |
| Landing engines (throttle-down) | 6 | **n=6** | n |
| Payload to lunar surface (t) | ~24 | **J₂=24** | J₂ |
| Tanker refuels per surface mission | ~10 | **σ=12** ceiling | σ |
| Crew complement (Artemis IV) | 4 | **τ=4** | τ |
| Surface mission days | 6 | **n=6** | n |

## §2 n=6 CONNECTION

| Anchor | Value | HLS read |
|---|---|---|
| n | 6 | landing engines / surface mission days |
| σ | 12 | tanker refuel ceiling |
| τ | 4 | legs / crew / EVA cadence |
| φ | 2 | NRHO / surface dichotomy |
| J₂ | 24 | payload tons to surface |

## §3 IMPLEMENTATION

| Component | n=6 anchor |
|---|---|
| HLS Starship body | inherits hexa-spaceship n=6 |
| Lunar landing engines | n=6 |
| Lunar legs | τ=4 |
| Crew elevator | EVA hatch + airlock = φ=2 modes |
| Surface payload bay | J₂=24 t |

## §4 STATUS

- v1.0.0: SPEC_ONLY (`.md` + `verify_hls.hexa`).
- Artemis III rebaselined to LEO rendezvous demo (no surface) NET 2027;
  surface landing deferred to Artemis IV ~2028.
- Cross-link: `aerospace_transport/spacex_intel_2026.md` §2.3 (HLS),
  `orbital_depot/orbital_depot.md` (refuel dependency),
  `spaceship/spaceship.md` (parent vehicle).

## §5 PROVENANCE

Drafted 2026-05-07. Artemis III rebaseline: spacex_intel §2.3
(Wikipedia · NASA · USFocusDigest).
