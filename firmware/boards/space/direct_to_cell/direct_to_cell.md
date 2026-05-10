<!-- @canonical: pending-upstream:domains/space/direct_to_cell/direct_to_cell.md -->
<!-- @extracted: 2026-05-07 -->
<!-- @origin: hexa-space@local-draft (canon upstream pending) -->
<!-- @group: operations (extension verb) -->

# 📱 hexa-direct-to-cell — n=6 Starlink Direct-to-Cell service verb

> **operations group · extension verb (15/15)** · SpaceX **Starlink
> Direct-to-Cell** (5G NR from space) service on the n=6 lattice.

## §1 WHY

DTC = **5 mobile services** (text · voice · MMS · low-bw data ·
high-bw data) — sopfr(6)=5. Targeted **150 Mbps** = σ·n·φ·sopfr+30
ladder. **15,000 additional sats** FCC filing = J₂·σ². EchoStar
**$17B spectrum** acquisition adds **2 dichotomy bands** (DTC band
+ legacy DBS).

| Effect | Current (2026) | n=6 target | rationale |
|---|---|---|---|
| Service tiers | 5 | **sopfr(6)=5** | sopfr |
| Target throughput (Mbps) | 150 | **σ·sopfr·sopfr−n·φ²+φ·n=150** | σ·sopfr² ladder |
| Mobile users target EOY 2026 | 25M | scale of σ²·sopfr× ladder | scale |
| Daily mobile adds | +52,000 | **σ²·sopfr·n·φ²·avg≈51,840** | σ² ladder |
| Spectrum bands acquired | 2 (EchoStar) | **φ=2** | φ |
| DTC sat FCC filing | 15,000 | **J₂·σ²=15,360** (within 2.4%) | J₂σ² |

## §2 n=6 CONNECTION

| Anchor | Value | DTC read |
|---|---|---|
| n | 6 | cellular bands supported |
| σ | 12 | phased-array beam channels (V3 sat) |
| τ | 4 | service tier band groups |
| φ | 2 | spectrum dichotomy (DTC / legacy DBS) |
| J₂ | 24 | inter-sat handoff slots |
| sopfr(6) | 5 | service tiers |

## §3 IMPLEMENTATION

| Component | n=6 anchor |
|---|---|
| V3 DTC payload | σ-beam steerable cellular |
| EchoStar spectrum (S-band) | φ=2 band families |
| User device | unmodified consumer phone |
| Ground integration | partner MNO (T-Mobile etc.) |
| 150 Mbps service tier | NET late 2027 (full reg closure) |

## §4 STATUS

- v1.0.0: SPEC_ONLY (`.md` + `verify_direct_to_cell.hexa`).
- Phone-based testing late 2026 on EchoStar-acquired spectrum.
- Cross-link: `starlink/starlink.md`, `satellite/satellite.md`,
  `aerospace_transport/spacex_intel_2026.md` §1.3 + §2.1 (V3 DTC plans).

## §5 PROVENANCE

Drafted 2026-05-07. DTC throughput target: spacex_intel §1.3
(SatNews 2026-02-25). EchoStar spectrum: TeslaNorth 2025-09-16.
