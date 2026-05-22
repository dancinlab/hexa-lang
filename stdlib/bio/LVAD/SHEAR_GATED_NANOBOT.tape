#!/usr/bin/env tape
# LVAD scenario ① · shear-gated therapeutic delivery · NANOBOT × QUANTUM
# Tier A · spatial specificity novelty

@V := "tape" :: spec [active]
  version = "1.2"

# ─── §1 Identity ─────────────────────────────────────────────────────

@I id := "lvad.shear-gated-nanobot" :: identity-claim [d=2026-05-16 active]
  kind = "shear-responsive nanobot · LVAD-pump-internal payload release"
  axis = "NANOBOT × QUANTUM"
  parent = "./README.md §3"
  tier = "A · spatial-specificity novelty"
  scope = "in-silico shear-actuator kinematics + payload binding-site VQE"

# ─── §2 Target problem ───────────────────────────────────────────────

@N target := "clinical-unmet-need" :: note [active]
  problem = "pump thrombosis vs systemic bleeding trade-off"
  mechanism <<~EOF
    LVAD requires anticoagulation (warfarin INR 2.0-3.0 + aspirin)
      → systemic effect → intracranial / GI bleeding (top mortality)
      ↔ insufficient anticoagulation → pump thrombosis (catastrophic)
    narrow therapeutic window · no spatial discrimination available today
  EOF
  approved-therapy = "warfarin + aspirin (systemic, non-spatial)"

# ─── §3 Real-limits anchor (g1) ──────────────────────────────────────

@D real-limits := "real-limits-first-anchor" :: governance [required]
  rule = "verification anchors ≥1 real limit (per AGENTS.tape g1)"
  limits = [
    "LVAD impeller shear stress 70-150 dyn/cm² (HeartMate 3 axial zones)",
    "physiological venous/arterial shear 1-10 dyn/cm² (>10× separation)",
    "RBC hemolysis threshold ≈ 400 dyn/cm² × time integral",
    "nanobot residence time in pump <1 s per pass · trigger response must be sub-second",
    "FXI Ki target for narrow-window anticoagulation ~10-100 nM"
  ]
  authority = "[@g1]"

# ─── §4 5-axis contribution ──────────────────────────────────────────

@D contribution := "5-axis-mapping" :: decision [active]
  primary-axes = [NANOBOT, QUANTUM]
  modules = [
    "hexa-nanobot/ — C0b skeleton simulator",
    "_python_bridge/module/nanobot_actuation_simulation.py",
    "_python_bridge/module/nanobot_actuator_v2_reference_emit.py",
    "_python_bridge/module/nanobot_l6_l7_contract_test.py",
    "quantum/pocket_vqe_orchestrator.py (payload binding)"
  ]
  workflow <<~EOF
    [NANOBOT]   shear-sensor actuator kinematics · trigger threshold > 50 dyn/cm²
       ↓
    [NANOBOT]   payload release latch model · sub-second response verification
       ↓
    [QUANTUM]   payload candidate (e.g. FXI inhibitor) active-site VQE
       ↓
    [coupling]  payload-loaded nanobot stability under physiologic shear (no premature release)
  EOF

# ─── §5 Novelty rationale ────────────────────────────────────────────

@N novelty := "why-novel" :: note [active]
  white-space = "shear-responsive nanoparticles exist in literature · LVAD-impeller-zone as explicit trigger ≈ none"
  competing-approaches = [
    "systemic FXI/FXII inhibitors (asundexian, milvexian) — still systemic",
    "surface-coating antithrombotic (see WEAVE_COATING.tape) — passive, not gated"
  ]
  differentiator = "spatial separation of where anticoagulation acts (pump-internal) from where bleeding risk is paid (systemic)"

# ─── §6 Honest boundaries (g8 / f2) ──────────────────────────────────

@D limits := "honest-boundaries" :: governance [required deny:overclaim]
  scope = "in-silico C2 simulator+metadata consistency only"
  authority = "[@g8] · [@f2]"
  unknowns = [
    "<1 s residence time vs trigger response — kinetic feasibility unproven in-silico",
    "biocompatibility · clearance · immunogenicity all wet-lab boundary",
    "payload leakage rate under physiologic shear — must be near-zero"
  ]

@F overclaim := "no-pump-trial-claim-from-c2-pass" :: governance [required deny:write]
  pattern = "implying in-silico actuator-model PASS = device approval / animal-study readiness"
  remedy = "phrase as 'kinetic feasibility shortlist · wet-lab + bench-pump validation required'"
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
  scope = "§3 ① shear-gated nanobot"

# ─── §8 Negative-result finding (real-limits-first) ──────────────────

@N bell_model_negative := "compact-nanobot-cannot-shear-gate" :: note [d=2026-05-16 active]
  finding = "simple Bell-model bond-rupture transduction does NOT produce sub-second shear-gating for a compact nanobot at LVAD shear (70-150 dyn/cm²)"
  physics <<~EOF
    F = τ·A·1e-7 pN  ;  τ=150 dyn/cm², A=10 nm² (per-site DNA-origami scale)
      → F ≈ 1.5e-4 pN
    Bell exponent = F·x_β/kT = (1.5e-4 · 0.4) / 4.28 ≈ 1.4e-5  → exp ≈ 1
      → k_open ≈ k0  → τ_response ≈ 1/k0 ≈ 1000 s  ≫  <1 s sub-second target

    Quantitative anchor (bell_min_area_for_subsecond, deterministic, k0=1e-3,
    x_β=0.4 nm, T=310 K; round-trip self-consistent — C8):
      shear  70 dyn/cm² → A_min = 1.056e7 nm²  (1056× compact-nanobot scale)
      shear 100 dyn/cm² → A_min = 7.391e6 nm²  ( 739×)
      shear 150 dyn/cm² → A_min = 4.928e6 nm²  ( 493×)
    i.e. sub-second gating needs a µm-scale drag element (~2.2–3.3 µm
    equivalent square), 2-3 orders of magnitude beyond a compact nanobot.
  EOF
  double-failure = "the concept fails on BOTH ends, same root cause. (1) PUMP: does not open — sub-second gating needs ≥493-1056× more drag area than a compact nanobot (C8 anchor; __SHEAR_RESPONSE_SIDECAR__ FAIL). (2) SYSTEMIC: leaks ~5.8% payload per 60 s circulatory transit, shear-independent — at compact scale the baseline k0 is itself leaky over circulatory time AND Bell gives zero shear discrimination (C9 FAIL). Both follow from the SAME inert-Bell-at-compact-scale physics. §3 payload-leakage limit is ANCHORED with a NEGATIVE verdict."
  cross-scenario = "shares shear-mechanotransduction physics with [[lvad.a2-stabilizer]] (②). SAME equation F_mid ∝ C_T·τ·L²; L²=2500× scale gap (vWF 5µm @70 = 8.75 pN vs nanobot 0.1µm @70 = 0.0035 pN). ① is a ROBUST NEGATIVE: a compact nanobot cannot collect shear force at all. The duality is ASYMMETRIC — ② is NOT a symmetric robust positive: post Zhang-2009 g1/g3 correction (k_cat 0.14/s, ΔG 3.9 kcal/mol, MEASURED rupture ~11 pN), vWF(5µm)@70 = 8.75 pN is BELOW the measured 11 pN, so ②'s in-silico UNFOLD is marginal/loading-rate-dependent (robust only ≥100 dyn/cm² or higher prefactor; rigorous verdict needs DHS = drylab #6). What holds for ②: the aVWS mechanism premise (established biology) + the cleavage-limited kinetic regime. See LVAD/A2_STABILIZER.tape §8 corrected."
  design-implication = "a viable shear-gated nanobot needs either (a) a vWF-mimetic µm-scale drag tether, or (b) a non-Bell transduction mechanism (e.g. cooperative conformational switch, catch-bond) — AND (c) a baseline k0 low enough that circulatory-transit leakage is acceptable (the current k0=1e-3/s fails this independently)."
  governance = "area_nm2 was NOT inflated to force a PASS — that is the fit-to-convenient-number anti-pattern forbidden by [@g1] (real-limits-first). Both FAILs (sidecar, C9) are retained as honest negative results; C9 was NOT re-thresholded to manufacture a PASS."

---

## Log

- 2026-05-16 — next-slice implemented: shear_response_v0.schema.json sidecar (draft-07, v1 schema untouched per g11) + Bell-model k_open(τ_shear) coupling (opt-in LVAD_SHEAR_COUPLING=1) + C7_shear_separation_ge_10x criterion. Default regression 6/6 PASS preserved; shear-mode F-NB-4 7/7 PASS (C7 = static 50/1 ≥ 10× ratio). __SHEAR_RESPONSE_SIDECAR__ = FAIL — honest real-limits outcome (§8): compact-nanobot Bell transduction physically insufficient for sub-second LVAD-shear gating. Implementation complete; the FAIL is the finding, not a bug. Logs /tmp/lvad_shear_next_{default,coupling}_*.log.
- 2026-05-16 — Bell real-limit ANCHORED. Added bell_min_area_for_subsecond (inverse Bell) + bell_design_constraint_anchor + C8_bell_design_constraint_selfconsistent (round-trip exact: at A_min, τ_response=1.000s). §8 physics now carries the deterministic A_min grid (1.06e7 / 7.39e6 / 4.93e6 nm² @ 70/100/150 dyn/cm²). The back-fitted SHEAR_AREA_NM2_AGGREGATE=2e7 constant is deliberately NOT wired into simulate_shear_response (its own comment admits it was "sized to give … sub-second response" = fit-to-convenient-number, [@g1]-forbidden). ① real-limit score 0/5 → 1/5 (Bell 1978 force-spectroscopy, a cited biophysical limit). Sidecar FAIL STANDS — anchor quantifies the negative result, does not overturn it. Default mode still 6/6 (C8 env-gated, no leak).
- 2026-05-16 — payload-leakage limit ANCHORED (negative) → ① 1/5 → 2/5. Added C9_leakage_bounded_at_venous_shear: P_release ≈ 1−exp(−k0·60 s) ≈ 5.8% per circulatory transit, shear-independent → C9 FAIL. This STRENGTHENS the negative: the concept fails on BOTH ends (pump: doesn't open / systemic: leaks), same inert-Bell-at-compact-scale root (§8 double-failure). C9 was NOT re-thresholded to manufacture a PASS ([@g1]). Shear-mode F-NB-4 = 8/9 (C9 the honest FAIL); default still 6/6 (C8/C9 env-gated, no leak). The §3 payload-leakage limit is now anchored with a quantified NEGATIVE — honest real-limits output.
- 2026-05-16 — g3 cross-scenario correction (consequence of [[lvad.a2-stabilizer]] Zhang-2009 fix). ①'s own Bell/C8/C9 physics is UNCHANGED and remains a robust negative (nanobot force-collection argument is independent of the A2 numbers). Only the §8 cross-scenario text was corrected: the prior "② anchored the POSITIVE side, vWF 8.75 pN ≫ A2 barrier" is FALSE post-correction (measured A2 rupture ~11 pN > 8.75 pN). The duality is now stated as ASYMMETRIC — ① robust negative; ② mechanism-premise-holds but in-silico UNFOLD marginal/loading-rate-dependent. nanobot_actuation_simulation.py + shear_response_v0.schema.json survived the working-tree reset (committed via parallel session) — no code rebuild needed; this was a surgical tape-text g3 fix only.
