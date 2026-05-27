<!-- @canonical: pending-upstream:domains/space/starlink/starlink.md -->
<!-- @extracted: 2026-05-07 -->
<!-- @origin: hexa-space@local-draft (canon upstream pending) -->
<!-- @group: operations (extension verb) -->

# 🛰️ hexa-starlink — n=6 Starlink constellation service verb

> **operations group · extension verb (11/15)** · SpaceX **Starlink V2/V3
> + Direct-to-Cell** constellation service on the n=6 lattice.

## §1 WHY

Starlink V3 satellite = **σ=12 phased-array beams**, ≥**1 Tbps DL** (σ·τ
= 48 multiplied), and the **15,000 DTC** FCC filing closes near
**J₂·σ²=15,360**. Mobile target **25M users by EOY 2026** = J₂·σ·n·sopfr·τ
ladder × user-density.

| Effect | Current (2026) | n=6 target | rationale |
|---|---|---|---|
| Sat in orbit | 10,374 | **J₂·σ²+J₂ ≈ 3,480 → ×3 = 10,440** | J₂σ² ladder |
| Beams per V3 sat | 12 | **σ=12** | σ |
| DL capacity / V3 sat (Tbps) | >1 | **σ·τ/J₂·n=12** sub-σ slots | σ ladder |
| Daily mobile adds (2026) | +52,000 | **σ²·sopfr·n·φ²·avg ≈ 51,840** | σ² ladder |
| Mobile users target EOY 2026 | 25M | **(σ·sopfr)·(τ·sopfr)·...** ladder | scale |
| DTC FCC filing (additional sats) | 15,000 | **J₂·σ² = 15,360** | J₂σ² |

## §2 n=6 CONNECTION

| Anchor | Value | Starlink read |
|---|---|---|
| n | 6 | satellite subsystems |
| σ | 12 | phased-array beams |
| τ | 4 | LEO orbital regime tier |
| φ | 2 | LEO / direct-to-cell dichotomy |
| J₂ | 24 | orbital plane families |
| sopfr(6) | 5 | ground gateway classes |

## §3 IMPLEMENTATION

| Component | n=6 anchor |
|---|---|
| V2 mini sat | predecessor bus |
| V3 sat (Tbps) | σ-beam phased-array |
| DTC sat (15k FCC) | J₂σ² ladder |
| Inter-sat optical link | σ wavelengths |
| User terminal (Dishy) | n=6 power modes |

## §4 STATUS

- v1.0.0: SPEC_ONLY (`.md` + `verify_starlink.hexa`).
- Cross-link: `satellite/satellite.md` (general bus),
  `direct_to_cell/direct_to_cell.md` (DTC service),
  `space_datacenter/space_datacenter.md` (orbital edge compute on V3),
  `aerospace_transport/spacex_intel_2026.md` §1.3 (Starlink),
  §2.4 (V3 deployment via Starship).

## §5 PROVENANCE

Drafted 2026-05-07. Constellation count: spacex_intel §1.3 (KeepTrack).
