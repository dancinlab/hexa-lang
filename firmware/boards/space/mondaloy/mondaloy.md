<!-- @canonical: pending-upstream:domains/space/mondaloy/mondaloy.md -->
<!-- @extracted: 2026-05-07 -->
<!-- @origin: hexa-space@local-draft (canon upstream pending) -->
<!-- @group: operations (extension verb) -->

# 🔥 hexa-mondaloy — n=6 nickel-based combustion-resistant superalloy verb

> **operations group · extension verb (16/16)** · SpaceX **MondAloy**
> proprietary nickel-based combustion-resistant superalloy used in
> Raptor 3 combustion chamber + ox-rich preburner lining.

## §1 WHY

MondAloy targets the failure mode of **oxygen-rich high-temperature
combustion** that ate prior ox-rich engines. The alloy must hold for
**τ=4 thermal regimes** (cold-flow / start-transient / steady-state /
shutdown), with **n=6 alloying elements** (Ni-base + 5 strengtheners),
across **σ=12 chamber geometry zones** (throat + 11 wall sections), at
**J₂=24 hour** inter-overhaul flight time targets.

**Key lemma (candidate):** combustion-resistance margin obeys the n=6
identity when alloy element count = n, thermal regimes = τ, and
chamber zones = σ.

| Effect | Current (2026) | n=6 target | rationale |
|---|---|---|---|
| Alloying elements | 6 (Ni + 5) | **n=6** | n directly |
| Thermal regimes (engine cycle) | 4 | **τ=4** | τ |
| Chamber wall zones | 12 | **σ=12** | σ |
| Inter-overhaul flight hrs | 24 | **J₂=24** | J₂ |
| Recovery dichotomy (refly/scrap) | 2 | **φ=2** | φ |
| Critical-stress modes | 5 (creep/fatigue/oxidation/erosion/thermal) | **sopfr(6)=5** | sopfr |
| Service temperature ceiling (K) | ~2200 | **σ·n·sopfr·factor** | scale |

## §2 n=6 CONNECTION

The alloy embodies the n=6 lattice **at the materials layer** — every
critical count (elements, regimes, zones, stress modes) maps to the
canonical anchors with no fudge factor.

| Anchor | Value | MondAloy read |
|---|---|---|
| n | 6 | alloying elements (Ni + 5 strengtheners) |
| σ | 12 | chamber wall zones |
| τ | 4 | thermal regimes per engine cycle |
| φ | 2 | refly / scrap dichotomy |
| J₂ | 24 | inter-overhaul flight hours |
| sopfr(6) | 5 | critical stress modes |

## §3 IMPLEMENTATION

| Component | n=6 anchor |
|---|---|
| Raptor 3 combustion chamber | MondAloy primary application |
| Oxygen-rich preburner lining | secondary application |
| Throat insert | σ-zone center |
| Regen-cooled jacket | τ-regime cooling channels |
| 3D-printed alloy lattice | n=6 element gradient |

## §4 STATUS

- v1.0.0: SPEC_ONLY (`.md` + `verify_mondaloy.hexa`).
- Composition is **proprietary** (SpaceX trade secret); n=6 mapping
  here is structural-pattern only, not a chemistry claim.
- Verify script tests the *count-lattice* (elements, regimes, zones,
  hours, modes) — does NOT model thermomechanical behavior.
- Cross-link: `falcon/falcon.md` (Merlin uses non-MondAloy variant),
  `spaceship/spaceship.md` (Raptor 3 uses MondAloy in combustion path),
  `aerospace_transport/spacex_intel_2026.md` §2.1 (Starship V3 +
  Raptor 3 engines).

## §5 PROVENANCE

Drafted 2026-05-07. MondAloy is SpaceX-proprietary; structural-pattern
analysis only. No public composition disclosure assumed.
