<!-- @canonical: pending-upstream:domains/space/rideshare/rideshare.md -->
<!-- @extracted: 2026-05-07 -->
<!-- @origin: hexa-space@local-draft (canon upstream pending) -->
<!-- @group: operations (extension verb) -->

# 🛰️ hexa-rideshare — n=6 smallsat rideshare service verb

> **operations group · extension verb (12/15)** · SpaceX **Transporter
> (SSO) + Bandwagon (mid-inclination)** rideshare service.

## §1 WHY

SpaceX rideshare = **Transporter (SSO) + Bandwagon (mid-incl)** =
φ=2 orbit dichotomy. Steady-state cadence **3 Transporter + 2 Bandwagon
per year = 5 = sopfr(6)**. Transporter-16 deployed **119 payloads** ≈
σ²−τ·n+τ−1 ladder.

| Effect | Current (2026) | n=6 target | rationale |
|---|---|---|---|
| Annual rideshare flights | 5 (3+2) | **sopfr(6)=5** | sopfr |
| Orbit families | 2 (SSO/mid) | **φ=2** | φ |
| Payloads per Transporter (avg) | 119 | **σ²−n·τ−1=119** | σ² ladder |
| Adapter ports per ESPA ring | 6 | **n=6** | n |
| Orbital transfer vehicles per flight | 2–4 | **φ to τ** | φ↔τ |
| Pricing tiers | 4 (mass·orbit·ride·season) | **τ=4** | τ |

## §2 n=6 CONNECTION

| Anchor | Value | Rideshare read |
|---|---|---|
| n | 6 | ESPA adapter ports |
| σ | 12 | small-payload integration windows/yr |
| τ | 4 | pricing tiers |
| φ | 2 | SSO / mid-inclination dichotomy |
| J₂ | 24 | OTV ports cap per ride |
| sopfr(6) | 5 | annual rideshare flights |

## §3 IMPLEMENTATION

| Component | n=6 anchor |
|---|---|
| Transporter (SSO) | F9 from VSFB SLC-4E |
| Bandwagon (mid-incl) | F9 from CCSFS SLC-40 |
| ESPA ring | n=6 standard ports |
| OTV (e.g. Vigoride) | φ-σ delivery agents |

## §4 STATUS

- v1.0.0: SPEC_ONLY (`.md` + `verify_rideshare.hexa`).
- Cross-link: `aerospace_transport/spacex_intel_2026.md` §1.6 (cadence),
  §3 program registry slugs `transporter-17`, `bandwagon-3-plus`.

## §5 PROVENANCE

Drafted 2026-05-07. Cadence: spacex_intel §1.6 (ElonX + edhat).
