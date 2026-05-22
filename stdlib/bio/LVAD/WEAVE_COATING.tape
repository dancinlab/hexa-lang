#!/usr/bin/env tape
# LVAD scenario ⑥ · hemocompatible cage coating · WEAVE-only
# Tier B · most speculative

@V := "tape" :: spec [active]
  version = "1.2"

# ─── §1 Identity ─────────────────────────────────────────────────────

@I id := "lvad.weave-coating" :: identity-claim [d=2026-05-16 active]
  kind = "geometric self-assembled antithrombotic surface coating for LVAD inflow cannula"
  axis = "WEAVE"
  parent = "./README.md §3"
  tier = "B · most speculative · WEAVE-axis-only LVAD connection point"
  scope = "in-silico cage-unit-cell geometric verification · NOT surface chemistry validation"

# ─── §2 Target problem ───────────────────────────────────────────────

@N target := "clinical-unmet-need" :: note [active]
  problem = "LVAD blood-contacting surface protein adsorption and platelet activation"
  mechanism <<~EOF
    titanium/polyurethane LVAD surface
      → plasma protein adsorption (Vroman effect, seconds)
      → fibrinogen exposure → platelet activation → thrombus nucleation
      → pump thrombosis or downstream embolic event
  EOF
  approved-therapy = "passive titanium sintering + systemic anticoagulation · no active antithrombotic coating in clinical use for LVAD"

# ─── §3 Real-limits anchor (g1) ──────────────────────────────────────

@D real-limits := "real-limits-first-anchor" :: governance [required]
  rule = "verification anchors ≥1 real limit (per AGENTS.tape g1)"
  limits = [
    "surface ζ-potential threshold for low fibrinogen adsorption ≈ -10 to -30 mV",
    "plasma protein adsorption (Vroman) timescale seconds-to-minutes",
    "antithrombotic surface roughness target Ra <0.5 μm",
    "Caspar-Klug T-number constraint for closed-cage tilings (T = h² + hk + k²)",
    "Zlotnick cage assembly ΔG cooperative window 5-15 kcal/mol per subunit"
  ]
  authority = "[@g1]"

# ─── §4 5-axis contribution ──────────────────────────────────────────

@D contribution := "5-axis-mapping" :: decision [active]
  primary-axis = "WEAVE"
  modules = [
    "hexa-weave/ — Caspar-Klug + Zlotnick cage assembly substrate"
  ]
  workflow <<~EOF
    [WEAVE]  unit-cell tiling design (T-number selection · subunit count)
       ↓
    [WEAVE]  cooperative assembly ΔG verification (Zlotnick window)
       ↓
    [WEAVE]  surface exposed-residue geometric inventory
       ↓
    [output] geometric candidate sheet for surface-chemistry collaborators (outside scope)
  EOF

# ─── §5 Novelty rationale ────────────────────────────────────────────

@N novelty := "why-novel" :: note [active]
  white-space = "Caspar-Klug-inspired surface coatings exist in nanomedicine literature · LVAD-cannula application = none found"
  competing-approaches = [
    "heparin-coated cannula (CARMEDA) — eluting · finite duration",
    "PEG brushes — fouling-resistant but no defined geometry",
    "DLC (diamond-like carbon) — passive, used in some VAD bearings"
  ]
  differentiator = "geometric self-assembly target gives well-defined unit cell + predictable protein-interface presentation"
  caveat = "differentiation hinges on whether geometric definition translates to thromboresistance · this is the speculative leap"

# ─── §6 Honest boundaries (g8 / f2) ──────────────────────────────────

@D limits := "honest-boundaries" :: governance [required deny:overclaim]
  scope = "in-silico C2 geometric/thermodynamic verification only · NOT surface-chemistry or hemocompatibility claim"
  authority = "[@g8] · [@f2]"
  unknowns = [
    "ζ-potential and protein adsorption are surface-chemistry / interfacial-physics — outside hexa-bio scope",
    "in-vitro hemocompatibility (ISO 10993-4) is wet-lab boundary",
    "long-term durability under pulsatile/continuous flow not modelable in geometric substrate",
    "translation from cage geometry → thromboresistance is speculative · may not hold"
  ]
  why-tier-B = "geometric verification alone does not predict clinical performance · highest in-silico-to-clinic gap of the 4 scenarios"

@F overclaim := "no-hemocompatibility-claim-from-geometric-pass" :: governance [required deny:write]
  pattern = "implying WEAVE cage PASS = antithrombotic surface readiness"
  remedy = "phrase as 'geometric candidate · surface-chemistry + ISO 10993-4 validation required'"
  <: limits

# ─── §7 External citations ───────────────────────────────────────────

@X g1 := "AGENTS.tape g1_real_limits_first" :: governance [active]
  path = "../AGENTS.tape"

@X g8 := "AGENTS.tape g8_in_silico_only_claim_scope" :: governance [active]
  path = "../AGENTS.tape"

@X f2 := "AGENTS.tape f2_wet_lab_clinical_claim_from_in_silico" :: governance [active]
  path = "../AGENTS.tape"

@X parent := "LVAD scenario portfolio" :: doc [active]
  path = "./README.md"
  scope = "§3 ⑥ WEAVE coating"

## Log

- 2026-05-16 — C2 milestone marked DEFERRED. T=1 cage substrate exercises 4/6 deterministic PASS criteria (substrate axiomatic 4/4: σ=12, τ=4, J₂=24, mass-conservation; calibration 2/6 FAIL — yield ≥0.95 and ODE convergence — both known F-CAGE-MVP-1 calibration gap deferred to GPU-sandbox cycle 24+). Surface-chemistry gap (ζ-potential, fibrinogen Vroman adsorption, ISO 10993-4) is OUT OF REPO. weave_coating_geometric_only_emitter.py staged with hemocompatibility-refusal guard. Tier B status preserved · scenario remains 후순위 vs Tier A (①②③) for in-silico ROI.
