<!-- @canonical: pending-upstream:domains/space/space_center/space_center.md -->
<!-- @extracted: 2026-05-07 -->
<!-- @origin: hexa-space@local-draft (canon upstream pending) -->
<!-- @group: operations (extension verb) -->

# 🛰️ hexa-space-center — n=6 ground operations center verb

> **operations group · extension verb (3/5)** · interpretation of
> SpaceX **Starbase + Cape + Vandenberg** ground complex as a single
> n=6 operations-center family.

## §1 WHY (why n=6 — how this technology pattern reshapes life)

A modern launch operations center is **6 functional cells** (Range
Safety · Pad Ops · Mission Ops · Recovery · Payload Integration · GSE).
SpaceX's 5-pad architecture (Starbase Pad 1+2 / 39A / SLC-37 ×2 / SLC-40)
operating at the FAA-approved **146 launches/yr** cap closes exactly on
the n=6 ladder: 146 ÷ σ months = **12.17 launches/month per program**,
i.e. saturation at σ=12.

**Key lemma (candidate):** `σ(6)·φ(6) = 6·τ(6) = 12` ⇒ a single launch
complex saturates at **σ launches/mo** when staffed by **n=6 functional
cells** running **τ=4 shift regimes**.

| Effect | Current (2026) | After HEXA-SPACE-CENTER (target) | n=6 rationale |
|---|---|---|---|
| Functional cells / center | 6 | **n=6** | n directly |
| Shift regimes | 3 (8h) | **τ=4** (6h) | τ regimes |
| Active pads (Starship) | 1 (Starbase) | **5 (Starbase×2 + 39A + SLC-37×2)** | σ−n+1 = 5 |
| Launches/yr cap (FAA approved) | open | **146** ≈ J₂·σ·n/φ × small margin | J₂ ladder |
| Launches/mo per program | ~12 | **σ=12** | σ ladder saturation |
| Range-safety zones | 6 | **n=6** | n directly |

## §2 n=6 CONNECTION (depth > 2 — structural)

Three SpaceX centers + 2 ULA-shared = **5 = σ−n+1 active pads**.
Each pad runs **n=6 functional cells** × **τ=4 shift regimes** = **24 = J₂
operator-shifts/day**, anchoring the J₂ identity at the operations layer.

| Anchor | Value | SpaceX read |
|---|---|---|
| n | 6 | functional cells per center |
| σ | 12 | launches/month at saturation per program |
| τ | 4 | 6-hour shifts |
| φ | 2 | TX (Starbase) vs FL (Cape) dichotomy |
| J₂ | 24 | operator-shifts per pad per day (n·τ) |

## §3 IMPLEMENTATION (anchor mappings)

| Component | n=6 anchor |
|---|---|
| Starbase Pad 1 | original Starship pad (TX) |
| Starbase Pad 2 | catch+launch tower w/ 20 hold-down arms (TX, mid-2026) |
| LC-39A | KSC, Crew Dragon + future Starship (FL, 2H 2026) |
| SLC-37 (×2 towers) | future Starship (FL, late 2026) |
| SLC-40 | F9 workhorse (FL) |
| VSFB SLC-4E | F9 polar (CA) |
| GSE / chilldown / SQD | τ-regime cryogenic timing |

## §4 STATUS (raw#10 honest C3)

- v1.0.0: SPEC_ONLY (this `.md` + `verify_space_center.hexa`).
- Verify script checks **center counts vs lattice**; does NOT simulate
  range-safety, pad-flow, or GSE timing.
- 146/yr cap is the **FAA approval ceiling**, not a delivery commitment.
- Cross-link: `aerospace_transport/spacex_intel_2026.md` §2.11
  (launch infrastructure build-out).

## §5 PROVENANCE

- Drafted 2026-05-07. Pad data: `spacex_intel_2026.md` §2.11
  (NASASpaceflight 2026-01 + SpaceNews 2025-09).
