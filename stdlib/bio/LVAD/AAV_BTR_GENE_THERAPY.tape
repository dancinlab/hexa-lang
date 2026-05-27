#!/usr/bin/env tape
# LVAD scenario ③ · AAV-mediated Bridge-to-Recovery gene therapy
# VIROCAPSID × RIBOZYME · paradigm-shift potential

@V := "tape" :: spec [active]
  version = "1.2"

# ─── §1 Identity ─────────────────────────────────────────────────────

@I id := "lvad.aav-btr" :: identity-claim [d=2026-05-16 active]
  kind = "AAV-delivered cardiac gene therapy co-administered with LVAD · goal = explant"
  axis = "VIROCAPSID × RIBOZYME"
  parent = "./README.md §3"
  tier = "A · paradigm shift potential"
  scope = "in-silico capsid stability + ribozyme guide MFE + off-target screen"

# ─── §2 Target problem ───────────────────────────────────────────────

@N target := "clinical-unmet-need" :: note [active]
  problem = "LVAD-as-destination-therapy default · myocardial-recovery weaning rare (5-15%) and unpredictable"
  mechanism <<~EOF
    underlying genetic dilated cardiomyopathy (LMNA/TTN/MYH7 etc.)
      → LVAD unloads ventricle → partial reverse remodeling
      → but without curing the genetic substrate, recovery plateaus
    BTR hypothesis: LVAD afterload reduction + AAV gene therapy = synergistic recovery → explant
  EOF
  approved-therapy = "none for LVAD-BTR · prior gene-therapy trials (CUPID/AGENT-HF) excluded LVAD cohort"

# ─── §3 Real-limits anchor (g1) ──────────────────────────────────────

@D real-limits := "real-limits-first-anchor" :: governance [required]
  rule = "verification anchors ≥1 real limit (per AGENTS.tape g1)"
  limits = [
    "AAV9 single-stranded cargo capacity ≈ 4.7 kb (hard wall)",
    "human cardiac transduction efficiency <1% cardiomyocytes vg+ (AAV1/CUPID2b proxy; AAV9 human unreported — Greenberg 2016 Lancet via PMC5544589)",
    "AAV capsid icosahedral T=1 · 60 subunit assembly · Caspar-Klug compatible",
    "ribozyme off-target floor: hammerhead ~10⁻³, cleaner via tertiary contacts",
    "AAV9 hepatic sequestration ≈30% %ID liver day-1 (mouse, radiolabeled; Wang 2024 PMC11404148 — the prior '~70%' was an unverified heuristic)",
    "pre-existing anti-AAV9 NAb seroprevalence 44-60% adults (pooled 57.8%, n=552; Chhabra 2024 PMC11253686 — corrects the prior '30-50%')"
  ]
  authority = "[@g1]"
  correction-note = "2026-05-16 g3 fix: §3 biodistribution/epidemiology values grounded to verified primaries (LVAD/aav_btr_grounded_constants.tsv). Prior heuristics — hepatic '~70%' and NAb '30-50%' and 'cardiac <30%' — replaced with measured-cited values. These remain literature-cited NOT in-substrate-measured; §8 taxonomy classification (structurally-external) is unchanged."

# ─── §4 5-axis contribution ──────────────────────────────────────────

@D contribution := "5-axis-mapping" :: decision [active]
  primary-axes = [VIROCAPSID, RIBOZYME]
  modules = [
    "hexa-virocapsid/ — capsid assembly substrate",
    "_python_bridge/module/virocapsid_pdb_corpus.py",
    "hexa-ribozyme/ — ribozyme catalysis sandbox",
    "_python_bridge/module/ribozyme_mfe_nussinov.py",
    "_python_bridge/module/ribozyme_off_target_screen.py",
    "_python_bridge/module/ribozyme_reaction_coordinate_quotient.py",
    "_python_bridge/module/ribozyme_kinetics_simulation.py"
  ]
  workflow <<~EOF
    [VIROCAPSID]  AAV9 / MyoAAV / AAVMYO capsid variant assembly thermodynamic verification
       ↓
    [VIROCAPSID]  cargo-loaded capsid stability check (4.7 kb fill limit)
       ↓
    [RIBOZYME]   variant-correction guide design (LMNA / TTN / MYH7)
       ↓             · MFE folding (Nussinov)
       ↓             · off-target screen
       ↓             · reaction-coordinate quotient
       ↓
    [coupling]   cardiomyocyte-restricted gating (miR-208a/499 sponging)
       ↓
    [ranking]    candidate cargo+capsid pairs for wet-lab (outside scope)
  EOF

@N candidate-cargo := "cargo-shortlist" :: note
  list = [
    "SERCA2a (ATP2A2) — Ca²⁺ reuptake restoration · prior CUPID trial cargo",
    "MYBPC3 wildtype — for HCM-to-DCM transitioned hearts",
    "β-ARKct — βAR signaling rescue",
    "trans-splicing ribozyme — LMNA/TTN exon correction in-place"
  ]

# ─── §5 Novelty rationale ────────────────────────────────────────────

@N novelty := "why-novel" :: note [active]
  white-space = "LVAD-cohort gene therapy + BTR explant goal = untrodden"
  synergy-hypothesis = "LVAD unloading creates a low-wall-stress window where cardiomyocyte biosynthesis can favor recovery proteins · gene therapy supplies the missing factor in that window"
  competing-approaches = [
    "CUPID (SERCA2a) — non-LVAD cohort · mixed results",
    "AGENT-HF (adenylyl cyclase 6) — non-LVAD · halted",
    "AB-1002 cardiotropic AAV2i8/I-1c — non-ischemic HFrEF · Phase 1 NCT04179643 n=11 (Henry/Chung 2025 Nat Med) · NOT LMNA · NOT LVAD",
    "no verified LMNA-DCM-specific AAV cardiac trial (the prior 'AskBio LION-CS101 LMNA' claim was FALSE — LION-CS101 = LGMD2I/R9 AB-1003 NCT05230459, a limb-girdle muscular dystrophy trial, NOT LMNA dilated cardiomyopathy; g3 correction 2026-05-16)"
  ]
  differentiator = "explicit LVAD co-administration + explant endpoint, not symptom reduction"

# ─── §6 Honest boundaries (g8 / f2) ──────────────────────────────────

@D limits := "honest-boundaries" :: governance [required deny:overclaim]
  scope = "in-silico C2 simulator+metadata consistency only"
  authority = "[@g8] · [@f2]"
  unknowns = [
    "human cardiac transduction efficiency unknown · animal models extrapolate poorly",
    "pre-existing anti-AAV9 immunity excludes ~40% of candidate recipients",
    "synergy hypothesis (LVAD + gene therapy) untested in humans",
    "trans-splicing ribozyme in-vivo efficiency historically low (<10%)",
    "BTR explant criteria not standardized across centers"
  ]

@F overclaim := "no-explant-claim-from-c2-pass" :: governance [required deny:write]
  pattern = "implying in-silico cargo+capsid PASS = LVAD weaning feasibility"
  remedy = "phrase as 'in-silico candidate pair · long path to BTR demonstration'"
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
  scope = "§3 ③ AAV BTR gene therapy"

# ─── §8 §3 real-limit taxonomy (anchorable vs structurally-external) ──

@N limit_taxonomy := "why-3-of-6-is-the-principled-ceiling" :: note [d=2026-05-16 active]
  finding = "③ §3 score 3/6 is a PRINCIPLED ceiling, not incomplete work. 3 limits are anchorable by hexa-bio's in-silico substrate; the other 3 are biodistribution/epidemiological constants that NO in-substrate computation can honestly anchor without external wet-lab/clinical data."
  anchorable-in-substrate = [
    "#1 AAV9 cargo capacity 4.7 kb — ANCHORED (aav_cargo_capacity_check.py, F-AAV-CARGO-1 6/6; Wu 2010/Wang 2019)",
    "#2 capsid icosahedral T=1 · 60-subunit Caspar-Klug — ANCHORED (virocapsid_pdb_corpus σ·φ=n·τ=J₂=24; AAV9/3UX1 in fallback)",
    "#3 ribozyme off-target floor ~1e-3 — pipeline READY (ribozyme_off_target_screen); real LMNA/TTN/MYH7 arms need real transcript context = documented external step (--gencode-pipeline-doc), NOT fabricated here ([@g3])"
  ]
  structurally-external = [
    "AAV9 hepatic sequestration ≈30% %ID (Wang 2024) — biodistribution; measured in vivo, no in-substrate consistency relation",
    "anti-AAV9 NAb seroprevalence 44-60% (Chhabra 2024) — population epidemiology; not a physics/chemistry limit hexa-bio computes",
    "human cardiac transduction <1% vg+ (AAV1/CUPID2b proxy; Greenberg 2016) — in vivo biodistribution; out-of-substrate by construction ([@g8])"
  ]
  honest-scope = "naming the 3 out-of-substrate limits is itself the honest deliverable: it prevents a future reader from treating 3/6 as 'unfinished' and attempting to fabricate the missing 3 ([@g3]/[@g8]). Anchoring more would require leaving the in-silico boundary."

---

## Log

- 2026-05-16 — next-slice landed (prior turns): aav_cargo_capacity_check.py (F-AAV-CARGO-1 6/6, §3#1 ANCHORED) + aav_variant_guides.tsv (5 primary-cited variants) + virocapsid corpus AAV9/3UX1 fallback extension (n=527 audit PASS preserved, [@g11] snapshot untouched; AAV9 entry inert while snapshot present — activates only on --refresh-viperdb). §3 score → 3/6.
- 2026-05-16 — §3 limit taxonomy added (§8): 3/6 confirmed as the PRINCIPLED in-substrate ceiling. Anchorable: #1 cargo, #2 Caspar-Klug T=1, #3 off-target pipeline. Structurally-external (cannot honestly anchor in-silico): hepatic sequestration, anti-AAV9 NAb prevalence, cardiac transduction efficiency — all biodistribution/epidemiology. ③ honestly EXHAUSTED for in-substrate real-limit anchoring; further progress requires the wet-lab boundary (CLOSURE_RESIDUAL_BACKLOG §0).
- 2026-05-16 — **g3 grounding correction + reset-recovery.** BG web-grounding agent verified primaries (LVAD/aav_btr_grounded_constants.tsv, all WebFetch-traced, no fabrication): §3 hepatic '~70%' was an unverified heuristic → measured ≈30% %ID (Wang 2024 PMC11404148); NAb '30-50%' → 44-60% pooled 57.8% (Chhabra 2024 PMC11253686); cardiac '<30%' → <1% vg+ AAV1/CUPID2b proxy (Greenberg 2016, AAV9 human unreported). §5: the "AskBio LION-CS101 LMNA Phase I" claim was FACTUALLY FALSE — LION-CS101 = LGMD2I/R9 (AB-1003, NCT05230459), NOT LMNA-DCM; corrected + the real cardiotropic-AAV datum (AB-1002 Phase 1 NCT04179643, Henry/Chung 2025 Nat Med) substituted. §3/§5/§8 corrected. A working-tree reset wiped uncommitted ③ artifacts; recovered from worktrees: aav_cargo_capacity_check.py (__AAV_CARGO_CAPACITY__ PASS), aav_variant_guides.tsv (5 primary-cited variants), a2_candidates.smi, a2_residue_orbital_selector.py upgraded 263L mock-only → 383L real-mode (3GXB/P04275, scissile Tyr1605-Met1606, __A2_RESIDUE_SELECTOR__ ALL PASS), aav_btr_grounded_constants.tsv. Values remain literature-cited NOT in-substrate-measured (g8/f2); §8 structurally-external classification unchanged; ③ stays 3/6 PRINCIPLED ceiling.
