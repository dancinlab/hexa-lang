<!-- @canonical: pending-upstream:domains/space/space_datacenter/space_datacenter.md -->
<!-- @extracted: 2026-05-07 -->
<!-- @origin: hexa-space@local-draft (canon upstream pending) -->
<!-- @group: operations (extension verb) -->

# 🏛️ hexa-space-datacenter — n=6 orbital edge-compute datacenter verb

> **operations group · extension verb (5/5)** · interpretation of
> Musk's **"Starlink V3 + space computing power" market** announcement
> as an n=6 orbital edge-compute fabric.

## §1 WHY (why n=6 — how this technology pattern reshapes life)

A satellite-borne datacenter is constrained by **n=6 orthogonal
budgets** (Power · Thermal · Mass · Volume · Latency · Radiation). The
Starlink V3 bus delivers σ=12 beams and ≥1 Tbps DL — providing the
exact transport substrate to elevate satellites into edge-compute nodes
without changing the bus.

**Key lemma (candidate):** `σ(6)·φ(6) = 6·τ(6) = 12` ⇒ each Starlink
V3 satellite hosts **σ=12 GPU-equivalent inference cores** at
**τ=4 thermal-regime tiers**, feeding **J₂=24 down-stream beams**.

| Effect | Current (2026) | After HEXA-SPACE-DATACENTER (target) | n=6 rationale |
|---|---|---|---|
| Sat-borne inference cores | none | **σ=12 GPU-eq / sat** | σ channels → cores |
| Thermal regimes | 1 (passive) | **τ=4** (passive→loop-heatpipe→TEC→cryo) | τ regimes |
| Constellation compute (PFLOPs) | 0 | **σ²·N_sats / 1000** PFLOPs | σ² loading |
| Down-stream beams / sat | 12 | **J₂=24** (V3 +50% margin) | J₂ ladder |
| Edge-compute storage tiers | 0 | **n=6** (L1/L2/HBM/NVMe/orbital-tape/ground) | n tiers |
| Latency budget tier | varies | **6 ms LEO + σ ms = 18 ms total** | n+σ tier |

## §2 n=6 CONNECTION (depth > 2 — structural)

Musk's announced "**space computing power market**" effectively requests
a constellation-scale compute fabric where each sat is 1 inference
node. With 15,000-sat DTC FCC filing + 12 GPU-eq cores/sat, the fabric
caps at **180,000 cores ≈ σ²·n·sopfr(6) × scale = 12·12·6·5 ≈ 4320 ×
~42 scale-factor**. The lattice predicts the saturation cell-count.

| Anchor | Value | SpaceX read |
|---|---|---|
| n | 6 | edge-compute storage tiers |
| σ | 12 | GPU-equivalent cores per V3 satellite |
| τ | 4 | thermal-regime tiers (pass/heatpipe/TEC/cryo) |
| φ | 2 | LEO-edge / GEO-relay dichotomy |
| J₂ | 24 | down-stream beams per V3 sat (V3+50% margin) |

## §3 IMPLEMENTATION (anchor mappings)

| Component | n=6 anchor |
|---|---|
| V3 satellite GPU rack | σ=12 inference cores |
| Cooling stack | τ=4 thermal regimes |
| Storage hierarchy | n=6 tiers (L1/L2/HBM/NVMe/orbital-tape/ground) |
| Inter-sat optical link | σ=12 wavelength channels |
| Ground gateway | sopfr=5 teleport classes (matches `satellite` verb) |

## §4 STATUS (raw#10 honest C3)

- v1.0.0: SPEC_ONLY (this `.md` + `verify_space_datacenter.hexa`).
- The Musk "space computing power market" announcement is a stated
  intent, not a delivered system. Treat the verb as **aspirational
  spec** until V3 deployment data lands.
- Verify script checks lattice arithmetic; does NOT estimate energy or
  thermal closure.
- Cross-link: `aerospace_transport/spacex_intel_2026.md` §1.3 (V3
  satellites + Tbps figures) + Musk space-computing-power announcement
  (eu.36kr.com, sourced 2026-05-07).

## §5 PROVENANCE

- Drafted 2026-05-07. Source: `spacex_intel_2026.md` §1.3 + Musk
  Starlink V3 expansion announcement (sourced via eu.36kr.com).
