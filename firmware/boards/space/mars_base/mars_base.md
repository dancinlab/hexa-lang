<!-- @canonical: pending-upstream:domains/space/mars_base/mars_base.md -->
<!-- @extracted: 2026-05-07 -->
<!-- @origin: hexa-space@local-draft (canon upstream pending) -->
<!-- @group: operations (extension verb) -->

# 🟥 hexa-mars-base — n=6 Mars settlement verb

> **operations group · extension verb (14/15)** · SpaceX/Musk **Mars
> uncrewed-26 → 2050 self-sustaining colony** roadmap on n=6.

## §1 WHY

Mars 2026/27 window: **5 Starships uncrewed** = sopfr(6). Mars 2028/29
window: **~20 Starships** ≈ J₂−τ. First crewed: 2029. Self-sustaining
goal 2050. Each Mars-base habitat module needs **6 life-support
subsystems** + **τ=4 redundancy ladder**.

| Effect | Current (2026) | n=6 target | rationale |
|---|---|---|---|
| Uncrewed Starships (2026/27) | 5 | **sopfr(6)=5** | sopfr |
| Uncrewed Starships (2028/29) | ~20 | **J₂−τ=20** | J₂ ladder |
| Mars transit (months, Hohmann) | ~6 | **n=6** | n |
| Habitat life-support subsystems | 6 | **n=6** | n |
| ISRU layers (CO₂→CH₄/O₂) | 4 | **τ=4** | τ |
| Optimus units in 2026 wave | 5 | **sopfr(6)=5** | sopfr |
| Crewed mission target (Musk) | 2029 | NET 2029 (with delays 5–7 yr risk) | calendar |
| Self-sustaining colony (Musk) | 2050 | aspirational | aspirational |

## §2 n=6 CONNECTION

| Anchor | Value | Mars-base read |
|---|---|---|
| n | 6 | Hohmann transit months / habitat subsystems |
| σ | 12 | per-window deep-space comms latency rebroadcast slots |
| τ | 4 | ISRU regime ladder |
| φ | 2 | uncrewed / crewed dichotomy |
| J₂ | 24 | window-cumulative ship count cap (5+20=25 = J₂+1 stretch) |
| sopfr(6) | 5 | first-window ship count + Optimus count |

## §3 IMPLEMENTATION

| Component | n=6 anchor |
|---|---|
| Mars uncrewed-26 | sopfr=5 ships (50% confidence per Musk) |
| Mars uncrewed-28 | J₂−τ=20 ships |
| Mars crewed (NET 2029) | first humans |
| Optimus humanoid | sopfr=5 robots in first wave |
| Habitat module | n=6 life-support subsystems |
| ISRU plant | τ=4 conversion regimes |

## §4 STATUS

- v1.0.0: SPEC_ONLY (`.md` + `verify_mars_base.hexa`).
- 2026-02-09 update: Mars goal pushed back **5–7 years** to focus on
  Moon. Treat 2029 crewed target as soft.
- Cross-link: `aerospace_transport/spacex_intel_2026.md` §2.4 (Mars
  uncrewed window), `verify_mk_ladder.hexa` rungs r=14..16, 20..24,
  `space_ai_center/space_ai_center.md` (Optimus).

## §5 PROVENANCE

Drafted 2026-05-07. Mars timeline: spacex_intel §2.4 (Wikipedia +
Space.com + NewSpaceEconomy + 2026-02 Musk delay statement).
