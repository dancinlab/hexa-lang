#!/usr/bin/env tape
# LVAD scenario ② · vWF A2 shear-unfolding stabilizer · QUANTUM-driven
# Tier A · white-space (approved drugs = 0)

@V := "tape" :: spec [active]
  version = "1.2"

# ─── §1 Identity ─────────────────────────────────────────────────────

@I id := "lvad.a2-stabilizer" :: identity-claim [d=2026-05-16 active]
  kind = "vWF A2-domain shear-unfolding stabilizer · small-molecule chaperone"
  axis = "QUANTUM"
  parent = "./README.md §3"
  tier = "A · highest novelty"
  scope = "in-silico chaperone candidate VQE binding-energy screen"

# ─── §2 Target problem ───────────────────────────────────────────────

@N target := "clinical-unmet-need" :: note [active]
  problem = "acquired von Willebrand syndrome (aVWS)"
  mechanism <<~EOF
    LVAD pump shear (70-150 dyn/cm²) → vWF A2 domain elongation
      → ADAMTS13 cleavage at Tyr1605-Met1606
      → high-molecular-weight multimer loss
      → impaired primary hemostasis + GI angiodysplastic bleeding
  EOF
  prevalence = ">75% of LVAD recipients · also ECMO · also aortic stenosis (Heyde syndrome)"
  approved-therapy = "none — recombinant vWF (Vonvendi) replaces, does not fix mechanism"

# ─── §3 Real-limits anchor (g1) ──────────────────────────────────────

@D real-limits := "real-limits-first-anchor" :: governance [required]
  rule = "verification anchors ≥1 real limit (per AGENTS.tape g1)"
  limits = [
    "ADAMTS13 k_cat = 0.14 /s single-molecule on unfolded A2 (Zhang 2009 Science 324:1330)",
    "A2 unfolding ΔG = 3.9 ± 0.9 kcal/mol (6.6 ± 1.5 k_BT) — single-molecule mechanical (Zhang 2009)",
    "A2 most-probable mechanical rupture force ≈ 11 pN (range 7-14, LOADING-RATE dependent; Zhang 2009)",
    "A2 unfolded contour 57 ± 5 nm · persistence ≈ 1.1 nm · domain ≈ 177 aa (Zhang 2009; Zhang Q PNAS 106:9226)",
    "shear threshold for A2 cleavage exposure ≈ 30 dyn/cm² (well below LVAD 70-150)",
    "vWF multimer MW range 500 kDa - 20 MDa · HMW = >10 MDa lost first"
  ]
  authority = "[@g1]"
  correction-note = "2026-05-16 g1/g3 fix: prior §3 values (k_cat 2.5/s, ΔG 7-10 kcal/mol, thermo force ~1 pN) DISAGREED with the scenario's own cited primary (Zhang 2009 Science 324:1330, verified verbatim PMC2753189). Replaced with the measured single-molecule values. The old 7-10 kcal/mol was an older bulk/chemical-denaturation figure, not the mechanically-relevant single-molecule ΔG."

# ─── §4 5-axis contribution ──────────────────────────────────────────

@D contribution := "5-axis-mapping" :: decision [active]
  primary-axis = "QUANTUM"
  modules = [
    "quantum/pocket_active_space.py",
    "quantum/pocket_vqe_orchestrator.py",
    "_qiskit_bridge/module/pocket_vqe_orchestrator.py"
  ]
  workflow <<~EOF
    [classical MD]  shear-induced A2 unfolding intermediate ensemble
       ↓
    [QM carve-out]  active-space around exposed Tyr1605-Met1606 cleavage site
       ↓
    [VQE]           binding-energy estimate for chaperone candidates vs intermediate
       ↓
    [ranking]       shortlist for wet-lab (outside hexa-bio scope)
  EOF

# ─── §5 Novelty rationale ────────────────────────────────────────────

@N novelty := "why-novel" :: note [active]
  white-space = "target mechanism well-characterized · approved drugs = 0"
  competing-approaches = [
    "recombinant vWF replacement — replaces factor, not mechanism",
    "ADAMTS13 inhibitors — risk of acquired TTP"
  ]
  differentiator = "small-molecule chaperone stabilizes A2 cleavage-resistant fold without systemic ADAMTS13 block"

# ─── §6 Honest boundaries (g8 / f2) ──────────────────────────────────

@D limits := "honest-boundaries" :: governance [required deny:overclaim]
  scope = "in-silico C2 simulator+metadata consistency only · NOT a therapeutic claim"
  authority = "[@g8] · [@f2]"
  unknowns = [
    "A2 unfolding intermediate not crystallographically resolved — model-dependent",
    "shear-induced ensemble correctness depends on classical MD sampling",
    "selectivity vs A1/A3 domains unverified in-silico"
  ]

@F overclaim := "no-clinical-claim-from-c2-pass" :: governance [required deny:write]
  pattern = "any phrasing that implies in-silico VQE binding rank = clinical efficacy"
  remedy = "use 'in-silico candidate ranking · wet-lab validation required' phrasing"
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
  scope = "§3 ② A2 stabilizer"

# ─── §8 Mechanistic-premise anchor (real-limits-first) ───────────────

@N a2_shear_anchor := "lvad-shear-drives-a2-unfolding" :: note [d=2026-05-16 active]
  finding = "Zhang-2009-corrected (g1/g3). §3 #1 (ADAMTS13 k_cat = 0.14/s) and the cleavage-LIMITED kinetic regime are ROBUST. §3 #2/#3: A2 unfolding under LVAD shear is consistent with the established aVWS mechanism (real biology), BUT the simple threshold model's in-silico 'UNFOLD' is NOT a robust positive — it is marginal/loading-rate-dependent against the MEASURED rupture force."
  module = "_python_bridge/module/a2_shear_unfolding_anchor.py"
  physics <<~EOF
    Two thresholds (do NOT conflate):
      • thermodynamic equilibrium force F=ΔG/Δx = ΔG3.9/Δx53 ≈ 0.51 pN
        (the LOW bound; WRONG threshold for a dwell-time mechanical process)
      • Zhang-2009 MEASURED single-molecule rupture ≈ 11 pN (range 7-14,
        LOADING-RATE dependent) — the mechanically-relevant figure
    vWF HMW multimer (L≈5 µm) midpoint tension F_mid ≈ C_T·τ·L²:
      τ=70  → 8.75-35 pN : > thermo(0.5) ✓ but 8.75 < 11 → NOT robust vs measured
      τ=100 → 12.5-50 pN : ≥ 11 at low C_T → robust
      τ=150 → 18.75-75 pN: robust
    ⇒ in-silico UNFOLD at LVAD 70 is PREFACTOR/LOADING-RATE marginal, robust
      only at ≥100 dyn/cm² or higher C_T. Rigorous DHS force-clamp treatment
      (drylab #6 dhs_force_spectroscopy, BUILT commit 9aec5ee): τ(8.75 pN)
      spans 1.9-190 s across the 10-60 s circulatory dwell ⇒ verdict
      PARAMETER_BAND_DEPENDENT — unfolds within dwell ONLY for higher-k0
      cells; the marginal flag is UPHELD as parameter-sensitive (needs an
      independent k0), NOT resolved either way (outcome computed, not tuned).
    ADAMTS13 (§3#1): t_unfold ≤ 1e-6 s ≪ t_cleave = 1/0.14 = 7.14 s
      → cleavage-LIMITED regime ROBUST (Crawley 2011; aVWS-consistent;
      corrected slower k_cat makes this stronger, not weaker).
  EOF
  cross-scenario = "bidirectional dual of [[lvad.shear-gated-nanobot]] §8. SAME equation F_mid ∝ L². vWF(5 µm)@70 = 8.75 pN vs nanobot(0.1 µm)@70 = 0.0035 pN — the L² = 2500× ratio. ① is a ROBUST NEGATIVE (compact nanobot cannot collect shear force at all). ② is NOT a symmetric robust positive: the disease-mechanism PREMISE is established biology, but the simple in-silico threshold gives a marginal/loading-rate-sensitive UNFOLD verdict. Honest asymmetry — not 'one physics, opposite robust verdicts'."
  citations = ["Zhang X 2009 Science 324:1330 (PMC2753189)", "Zhang Q 2009 PNAS 106:9226 (PMC2695068)", "Crawley 2011 Blood 118:3212", "Alexander-Katz 2006 PRL 97:138101"]
  honest-scope = "in-silico simulator-consistency only ([@g8] [@f2]). Anchors: ROBUST = cleavage-limited kinetic regime (#1); the aVWS mechanism premise (established biology). NOT claimed: a robust in-silico UNFOLD positive (it is marginal vs the measured force). Evaluates NO chaperone; white-space (0 approved A2 stabilizers) unchanged; advances NO drug."

---

## Log

- 2026-05-16 — scaffold inputs staged: a2_candidates.smi (5-10 real-cited compounds, mostly negative controls) + a2_residue_orbital_selector.py (mock-mode helper, real-mode NotImplementedError). VQE pipeline still cannot run against A2 — needs real A2 intermediate PDB + SMD trajectory (outside repo).
- 2026-05-16 — §3 real-limit anchor first build (SUPERSEDED — used wrong numbers; see correction below).
- 2026-05-16 — **g1/g3 CORRECTION + reconstruction.** A working-tree reset destroyed the uncommitted anchor; rebuilt CORRECTLY. RE agent (drylab/research/a2_cg_unfolding.md) verified verbatim from the scenario's OWN cited primary (Zhang X 2009 Science 324:1330, fetched PMC2753189) that the prior §3 numbers were WRONG: k_cat 2.5→**0.14/s**, ΔG 7-10→**3.9±0.9 kcal/mol**, contour 65→**57 nm**, and the relevant force is the MEASURED **~11 pN** rupture (not the ~1 pN thermodynamic estimate). §3 + §8 corrected. **Honest verdict change**: the earlier 'robust ① ⇄ ② positive duality' claim does NOT survive — at LVAD 70 dyn/cm² vWF tension (8.75 pN, conservative C_T) is BELOW the measured 11 pN, so ②'s in-silico UNFOLD is marginal/loading-rate-dependent (robust only ≥100 dyn/cm² or higher prefactor; rigorous verdict needs DHS force-clamp = drylab #6). What REMAINS robust: ADAMTS13 cleavage-LIMITED regime (#1, stronger with the slower k_cat) + the aVWS mechanism premise (established biology). __A2_SHEAR_UNFOLDING_ANCHOR__ PASS where PASS = the honest criteria set (C_A2_1 thermo-consistent + C_A2_2 cleavage-limited + C_A2_3 marginal-flag correctly raised), NOT 'robust positive'. NO therapeutic progress; white-space unchanged ([@g8]/[@f2]).
- 2026-05-16 — **②-marginal gap RESOLVED honestly via DHS #6.** drylab/sim/dhs_force_spectroscopy.py built+committed (9aec5ee), DHS k(F) verbatim-verified vs Dudko-Hummer-Szabo 2008 PNAS (PMC2572921). The §8-deferred "rigorous verdict needs DHS" is now answered: with (ΔG‡≈ΔG≈6.6 kT) and k0/t_obs as EXPLICIT assumed bands (not tuned), τ(8.75 pN) spans 1.9→190 s across the 10-60 s circulatory dwell ⇒ verdict **PARAMETER_BAND_DEPENDENT**. Sustained ~8.75 pN unfolds A2 within physiological dwell ONLY for higher-k0 cells — the ②-UNFOLD call CANNOT be declared robust without an independent k0 measurement. The marginal flag is UPHELD as parameter-sensitive, NOT silently resolved either way (g1: computed across bands, not tuned to a hoped outcome). This honestly CLOSES the flagged gap: the answer is "still marginal, and here is precisely why + what would resolve it (independent k0)" — not a manufactured positive. NO therapeutic progress; white-space unchanged ([@g8]/[@f2]).
- 2026-05-16 — **§4-workflow "external SMD intermediate ensemble" FALSE BOUNDARY dissolved (with honest caveats).** drylab/sim/a2_cg_unfolding.py built+committed (282cfaa, __DRYLAB_A2_CG_UNFOLDING__ PASS): a stdlib Cα-Gō cv-SMD forced-unfolding that produces the A2 unfolding-intermediate ensemble IN-REPO (5 metastable Q-basins, force ramp 0→27.5 pN through the cited 7-14 pN window, rip-force 12.90 pN). The tape's repeated "intermediate ensemble = external SMD, repo-out" was a FALSE BOUNDARY — it was a missing program, not a wet-lab/external blocker. HONEST CAVEATS (the boundary MOVED, it did not vanish): the ensemble is CG topology-proxy fidelity — model ΔG_unfold ≈495 kcal/mol is ~127× the Zhang-2009 3.9 kcal/mol anchor (reported AS-IS, NOT fudged; ε set once for 310 K fold stability then held, g1), and the run reaches the force window but does NOT drive the chain to the 57 nm contour (pure-Python BD budget). So §6 unknowns ("not crystallographically resolved · model-dependent · ensemble correctness depends on sampling") REMAIN valid — all-atom-validated ensemble + selectivity stay external. This does NOT make ② a robust positive (see DHS #6: still PARAMETER_BAND_DEPENDENT); it provides the §4-workflow's input at CG fidelity only. NO therapeutic progress; white-space unchanged ([@g8]/[@f2]).
