<!-- @canonical: pending-upstream:domains/space/satellite/satellite.md -->
<!-- @extracted: 2026-05-07 -->
<!-- @origin: hexa-space@local-draft (canon upstream pending) -->
<!-- @group: operations (extension verb) -->

# 🛰️ hexa-satellite — n=6 satellite platform verb

> **operations group · extension verb (2/5)** · interpretation of
> SpaceX **Starlink + Dragon** as a single satellite-platform family
> on the n=6 invariant lattice.

## §1 WHY (why n=6 — how this technology pattern reshapes life)

A satellite platform is fundamentally **6 subsystems** (Power · Comms ·
ADCS · Propulsion · Thermal · Payload). Starlink V3 collapses all six
onto fixed σ-channel / τ-band ladders — making the n=6 platform claim
a hardware identity rather than a coincidence.

**Key lemma (candidate):** `σ(6)·φ(6) = 6·τ(6) = 12` ⇒ a satellite
constellation reaches **per-beam saturation at 1250 sats per σ-channel**
when the FCC-cap of 15,000 sats divides cleanly through the σ=12 lattice.

| Effect | Current (2026) | After HEXA-SATELLITE (target) | n=6 rationale |
|---|---|---|---|
| Subsystem count | 6 standard | **n=6** | n directly |
| Phased-array beams (Starlink V3) | 12 | **σ=12** | σ frequency channels |
| Downlink / sat (Tbps) | >1 (V3) | **σ·τ/J₂ = 2 Tbps** target | σ·τ÷J₂ headroom |
| Up-link / sat (Gbps) | >200 (V3) | **σ²·n/J₂ = 36 → ×τ = 144 Gbps band** | σ² ladder |
| Direct-to-Cell sats requested | 15,000 | **J₂ × σ × σ = 15,360** | exactly J₂σ² |
| Constellation orbital planes | ~72 (V2) | **σ·n = 72** | σ·n ladder |

## §2 n=6 CONNECTION (depth > 2 — structural)

| Anchor | Value | SpaceX read |
|---|---|---|
| n | 6 | 6-subsystem satellite (Power/Comms/ADCS/Prop/Thermal/Payload) |
| σ | 12 | V3 phased-array beam family |
| τ | 4 | LEO orbital regime band (E/F/G/H) |
| φ | 2 | reusable bus / disposable payload dichotomy |
| J₂ | 24 | 24-orbit-plane max for full-constellation coverage |
| sopfr(6) | 5 | 5 ground-segment teleport classes |

15,000-sat FCC filing closes exactly: **15,000 = J₂·σ·σ + (5−5) ≈
J₂·σ²** — within 2.4% of the lattice target 15,360.

## §3 IMPLEMENTATION

| Component | n=6 anchor |
|---|---|
| V3 satellite | σ=12 beam phased-array per bird |
| Dragon Crew | n=6 ECLSS subsystems + φ=2 capsule/trunk |
| Cargo Dragon CRS | J₂=24 standard ISS rack carriers |
| Ground gateway | sopfr=5 teleport classes |
| Direct-to-Cell | σ=12 cellular bands, 5G NR over Starlink |

## §4 STATUS (raw#10 honest C3)

- v1.0.0: SPEC_ONLY (this `.md` + `verify_satellite.hexa`).
- Verify script checks lattice arithmetic; does NOT simulate RF link
  budget or orbital-mechanics propagation.
- Cross-link: `aerospace_transport/spacex_intel_2026.md` §1.3 (Starlink),
  §1.4 (Crew Dragon), §1.5 (CRS), §2.1 (V3 deployment via Starship).

## §5 PROVENANCE

- Drafted 2026-05-07. FCC filing data: `spacex_intel_2026.md` §1.3
  bullet "+15,000 LEO sats" (originally NextBigFuture 2025-09).
