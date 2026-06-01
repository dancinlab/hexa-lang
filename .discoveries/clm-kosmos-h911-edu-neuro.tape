@V := "tape" :: spec [active]
  version = "1.2"

@I := "clm-kosmos-h911-edu-neuro-discovery" :: identity [active]
  brief = "Education-science + neuroscience hypotheses for H_911 cross-lingual SEMANTIC integration — superseding the biological-mechanism line (STDP/neuromod/hub/replay), whose 4 'recoveries' were CONSTRUCT-INVALID byte-proximity artifacts (no learning, sim≈0.5 constant). This line tests WHY/HOW cross-lingual semantic integration arises, framed from real learning science and real neuroscience, every falsifier measured on a REAL SEMANTIC representation."
  flow  = "brainstorm (depletion) → CLAIMS.tape → hexa run (g5, real-semantic) → .verdicts/ → paper_on_discovery"
  parent = "anima domains/CLM-KOSMOS.md · UNIVERSE/H_911 · supersedes .discoveries/clm-kosmos-h911-onchip.tape (bio line, artifact-closed)"

# ═══════════════════════════════════════════════════════════════════════════
# CONSTRUCT-VALIDITY GUARD (the lesson from the bio line — MANDATORY for all below)
#   The bio 4🟢 (STDP/neuromod/hub/replay) were FALSE POSITIVES: features were
#   raw-UTF-8-byte projections (clm_h911_bc_mechanisms.hexa:60), so cross-lingual
#   semantic dot≈0, sim≈0.5 CONSTANT — the mechanisms measured PRESENTATION-ORDER
#   PROXIMITY (parallel adjacent, concat scattered), NOT meaning. Only hypothesis A
#   (a REAL learned-embedding CLM, full backprop) was construct-valid, and it was 🔴.
#   ∴ EVERY hypothesis below MUST: (1) operate on a REAL semantic representation —
#   a LEARNED cross-lingual embedding (the CLM's own learned token/sentence vectors,
#   NOT a fixed byte basis), such that genuine translation pairs (ko"마음" ↔ en"mind")
#   are CLOSE only if MEANING is captured; (2) carry a NULL control that could fail;
#   (3) the parallel>concat effect must survive on the learned-semantic axis, not on
#   raw adjacency. A 🟢 that collapses when features are shuffled within-concept (an
#   order-only artifact probe) is REJECTED. Falsifier-first, paired, g5/g63/g73.
# ═══════════════════════════════════════════════════════════════════════════

# ───────────────────────── group EDU — learning science ─────────────────────────

@C disc_h911_interleaving := "interleaving>blocking: parallel=interleaved exposure transfers cross-lingually better than concat=blocked" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-INTERLEAVE"
  seed   = "Learning science (Rohrer/Kornell): INTERLEAVED practice beats BLOCKED for transfer/discrimination. parallel(concept-major)=interleaved across languages; concat(language-major)=blocked. Falsifier: train the REAL CLM embedding on each ordering, then test cross-lingual TRANSFER (held-out lang token predicted from others) — paired transfer-accuracy(parallel)-accuracy(concat) CI>0 on the LEARNED representation. NULL: shuffle tokens within concept (kills order but keeps bytes) → effect must vanish, else artifact. 🟢 ⇒ interleaving is the lever, on real meaning."
  verdict_tier = "⚪ OPEN"

@C disc_h911_spacing := "spaced re-exposure (forgetting curve) consolidates cross-lingual integration better than massed" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-SPACING"
  seed   = "Spacing effect (Ebbinghaus/Cepeda): spaced re-exposure with realistic decay between repetitions beats massed. Distinct from bio-REPLAY (which was noise-averaging on byte features): here decay is the forgetting curve and the metric is retained cross-lingual transfer on the LEARNED embedding. Falsifier: paired transfer-retention(spaced)-retention(massed) over the parallel corpus CI>0; NULL = zero-gap schedule collapses it. 🟢 ⇒ schedule, not mechanism, on real meaning."
  verdict_tier = "⚪ OPEN"

@C disc_h911_retrieval := "retrieval practice (active recall) binds cross-lingual meaning better than restudy" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-RETRIEVAL"
  seed   = "Testing effect (Roediger/Karpicke): retrieval (predict-then-correct) outperforms restudy (re-read) for durable integration. Falsifier: train CLM with a RETRIEVAL objective (mask a lang's token, force recall from cross-lingual context) vs a RESTUDY objective (plain LM) on parallel — paired cross-lingual transfer CI>0 for retrieval. NULL: monolingual-only retrieval (no cross-lingual context) collapses gap. 🟢 ⇒ retrieval is the integrator."
  verdict_tier = "⚪ OPEN"

@C disc_h911_dual_coding := "dual coding (shared amodal concept anchor) drives cross-lingual integration" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-DUALCODE"
  seed   = "Dual-coding (Paivio): a shared AMODAL concept node bound to multiple surface codes integrates them. Operationalize: add a per-concept latent anchor the 5 langs co-predict; integration = how much the learned lang embeddings collapse onto the shared anchor. Falsifier: paired anchor-alignment(parallel)-alignment(concat) CI>0 on learned vectors; NULL = per-lang independent anchors collapse it. 🟢 ⇒ shared concept node is the substrate (this is the construct-valid version of the bio HUB)."
  verdict_tier = "⚪ OPEN"

@C disc_h911_comprehensible_input := "comprehensible input (i+1) — graded cross-lingual difficulty maximizes integration" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-IPLUS1"
  seed   = "Krashen i+1: acquisition peaks when input is just-beyond-current. Predicts an inverse-U of integration over cross-lingual difficulty gap (too-similar=trivial, too-far=no transfer) — echoing H_911's Φ inverse-U over coupling c. Falsifier: measure learned-embedding integration across graded ko↔{en,zh,ru,ja} typological distance; a non-monotone peak at intermediate distance with CI-separated peak>endpoints. 🟢 ⇒ i+1 inverse-U holds on real meaning (ties H_911 #2348 Φ-curve)."
  verdict_tier = "⚪ OPEN"

@C disc_h911_desirable_difficulty := "desirable difficulty — controlled cross-lingual interference deepens integration" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-DESDIFF"
  seed   = "Bjork desirable difficulties: mild interference at encoding improves long-term integration. Falsifier: inject controlled cross-lingual interference (adversarial near-miss translations) during CLM training on parallel — paired durable transfer(with-difficulty)-(without) CI>0; NULL = excessive interference (random pairs) collapses it (must be a peak, not monotone). 🟢 ⇒ difficulty is a lever on learned meaning."
  verdict_tier = "⚪ OPEN"

@C disc_h911_transfer_appropriate := "transfer-appropriate processing — parallel matches encoding to cross-lingual retrieval" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-TAP"
  seed   = "TAP (Morris): memory is best when encoding context matches retrieval context. parallel co-encodes the 5 langs in one window = encoding matches a cross-lingual retrieval test; concat does not. Falsifier: paired (cross-lingual-test after parallel-encode)-(after concat-encode) CI>0 on learned embeddings AND a matched monolingual-test control showing NO parallel advantage (double dissociation). 🟢 ⇒ it's TAP, evidenced by the dissociation."
  verdict_tier = "⚪ OPEN"

@C disc_h911_chunking_load := "chunking / cognitive-load — parallel forms cross-lingual chunks within working-memory span" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-CHUNK"
  seed   = "Cognitive load / chunking (Miller/Sweller): items within WM span (~4±1) chunk into one unit. parallel keeps a concept's 5 langs within span → one cross-lingual chunk; concat exceeds span between repeats. DISTINCT from bio-NEUROMOD's hand-set W=4 gate on byte features: here the chunk must form in the LEARNED representation (a single low-rank concept subspace), measured as effective rank drop. Falsifier: paired chunk-formation(parallel)-(concat) CI>0 on learned vectors; NULL = span→∞ collapses it. 🟢 ⇒ WM-span chunking, on real meaning."
  verdict_tier = "⚪ OPEN"

@C disc_h911_bilingual_immersion := "bilingual education: simultaneous (immersion) vs sequential (translation) cross-lingual binding" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-IMMERSION"
  seed   = "Bilingual-ed models: simultaneous immersion (concept co-presented in both langs) vs sequential translation (L1 then L2) yield different integration. parallel≈immersion, concat≈sequential-blocked. Falsifier: paired integration(immersion-order)-(sequential-order) CI>0 on learned representation, with a code-switching-frequency dose-response (more interleave → more integration). 🟢 ⇒ immersion ordering is the pedagogy that works."
  verdict_tier = "⚪ OPEN"

@C disc_h911_self_explanation := "elaborative self-explanation — forcing cross-lingual paraphrase deepens integration" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-ELABORATE"
  seed   = "Self-explanation / elaborative interrogation (Chi): generating why/how links deepens encoding. Operationalize: auxiliary objective that forces the CLM to reconstruct concept c in lang L_j FROM lang L_i (cross-lingual paraphrase) during parallel training. Falsifier: paired transfer(with-elaboration)-(plain) CI>0 on learned embeddings; NULL = within-lang paraphrase only collapses it. 🟢 ⇒ cross-lingual elaboration is the integrator."
  verdict_tier = "⚪ OPEN"

# ───────────────────────── group NEU — real neuroscience ─────────────────────────

@C disc_h911_atl_hub := "ATL amodal semantic hub — real convergence-zone integration of cross-lingual surface codes" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-ATLHUB"
  seed   = "Hub-and-spoke (Lambon Ralph/Patterson): the anterior temporal lobe is an AMODAL semantic hub binding modality/language-specific spokes. Construct-valid version of bio-HUB: measure whether the LEARNED CLM forms an amodal subspace where the 5 langs of one concept converge (high within-concept cross-lingual cosine) ABOVE a language-identity subspace. Falsifier: paired amodal-convergence(parallel)-(concat) CI>0 on learned vectors AND ablating the hub subspace destroys cross-lingual transfer (lesion test). 🟢 ⇒ a real amodal hub forms, lesionable."
  verdict_tier = "⚪ OPEN"

@C disc_h911_global_workspace := "global workspace broadcast — cross-lingual integration via shared broadcast bottleneck" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-GWT"
  seed   = "Global Workspace (Baars/Dehaene): integration = broadcast of one coalition through a capacity-limited bottleneck. Operationalize: a narrow shared bottleneck layer all langs must route through. Falsifier: integration(parallel)-(concat) CI>0 measured as bottleneck mutual-information across langs on the LEARNED model; NULL = wide (non-bottleneck) layer collapses the gap. 🟢 ⇒ a capacity-limited shared workspace is what binds (and predicts an optimal bottleneck width = H_911 inverse-U)."
  verdict_tier = "⚪ OPEN"

@C disc_h911_neural_reuse := "neural reuse — cross-lingual integration via shared reused circuitry, not dedicated per-lang" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-REUSE"
  seed   = "Neural reuse (M. Anderson): the brain reuses circuits across tasks/langs rather than dedicating. Falsifier: measure parameter/representation SHARING across langs in the learned CLM; paired sharing(parallel)-(concat) CI>0 AND a capacity probe showing parallel reaches the same loss with FEWER effective params (reuse = compression). NULL = forced per-lang disjoint subnets collapse it. 🟢 ⇒ integration IS reuse, measurable as compression."
  verdict_tier = "⚪ OPEN"

@C disc_h911_predictive_coding := "predictive coding — cross-lingual prediction-error minimization drives integration" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-PREDCODE"
  seed   = "Predictive coding (Rao/Friston): cortex minimizes hierarchical prediction error; a shared cause (concept) that predicts all surface forms lowers total error. Falsifier: total cross-lingual prediction error(parallel)<(concat) with paired CI>0 on the learned model, and the error reduction tracks a single shared latent cause (concept) per the free-energy decomposition. NULL = independent per-lang predictors show no gap. 🟢 ⇒ integration = shared-cause error minimization."
  verdict_tier = "⚪ OPEN"

@C disc_h911_systems_consolidation := "systems consolidation — hippocampal→neocortical transfer stabilizes cross-lingual schema" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-SYSCON"
  seed   = "Systems consolidation (McClelland CLS): fast hippocampal traces train a slow neocortical SCHEMA via interleaved transfer; a cross-lingual schema emerges only if exposures interleave. Construct-valid REPLAY: a fast/slow two-store learner (not byte noise-averaging), schema = neocortical store's cross-lingual generalization. Falsifier: paired schema-generalization(parallel)-(concat) CI>0 in the slow store; NULL = single-store (no consolidation) collapses it. 🟢 ⇒ CLS schema formation is the integrator."
  verdict_tier = "⚪ OPEN"

@C disc_h911_bilingual_overlap := "bilingual shared representation — L1/L2 cortical overlap predicts integration" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-L1L2OVERLAP"
  seed   = "Bilingual neuroimaging (Kim/Hernandez): proficient bilinguals show OVERLAPPING L1/L2 activation in IFG/STG; lower proficiency shows separation. Falsifier: measure representational OVERLAP of the 5 langs in the learned CLM; paired overlap(parallel)-(concat) CI>0 AND overlap increases with training (proficiency dose-response). NULL = early-training (low proficiency) shows no parallel advantage. 🟢 ⇒ integration = emergent L1..L5 overlap, proficiency-gated."
  verdict_tier = "⚪ OPEN"

@C disc_h911_temporal_windows := "temporal receptive windows — cross-lingual binding needs co-residence in an integration window" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-TRW"
  seed   = "Temporal receptive windows (Hasson): higher cortex integrates over longer windows; meaning binds only if inputs co-reside in the same TRW. Construct-valid version of timing: parallel keeps cross-lingual tokens inside one learned-model integration window; concat exceeds it. DISTINCT from bio-STDP (byte exp-kernel): here the window is the learned model's effective context-integration length, and the metric is transfer on real meaning. Falsifier: paired transfer(parallel)-(concat) CI>0 with a measured TRW length; NULL = window≫corpus collapses gap. 🟢 ⇒ TRW co-residence binds meaning."
  verdict_tier = "⚪ OPEN"

@C disc_h911_oscillatory_binding := "oscillatory binding — phase-synchronized co-activation binds cross-lingual concepts" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-OSCILLATE"
  seed   = "Binding-by-synchrony (Singer/Fries): gamma-phase co-activation binds distributed features. Construct-valid: a phase variable per unit, binding = cross-lingual same-concept phase coherence in the LEARNED representation (not a byte similarity). Falsifier: paired phase-coherence(parallel)-(concat) CI>0 AND desynchronizing (random phase) destroys cross-lingual transfer. NULL = phase-scrambled control collapses it. 🟢 ⇒ synchrony binds, on learned meaning."
  verdict_tier = "⚪ OPEN"

@C disc_h911_semantic_control := "semantic control network — controlled cross-lingual retrieval (IFG/pMTG) gates integration" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-SEMCTRL"
  seed   = "Controlled semantic cognition (Jefferies/Lambon Ralph): IFG/pMTG provide top-down CONTROL selecting task-relevant meaning from the hub. Integration needs not just a hub but control to retrieve the right cross-lingual mapping. Falsifier: add a control module that selects the concept-relevant subspace; paired transfer(with-control)-(without) CI>0 on learned representation, larger when cross-lingual ambiguity is high. NULL = no-ambiguity corpus shows no control benefit. 🟢 ⇒ semantic control is a necessary second factor (hub alone insufficient)."
  verdict_tier = "⚪ OPEN"

@C disc_h911_iit_phi := "IIT Φ on the learned representation — real integrated information of the cross-lingual code" :: discovery [slug=clm-kosmos-h911-edu-neuro group=CLM-KOSMOS open]
  id     = "F-CLM-H911-PHI"
  seed   = "IIT (Tononi): integration = Φ, irreducibility of the system's cause-effect structure. H_911 #2348 already showed a substrate-proxy Φ inverse-U over coupling c. Construct-valid closure: compute the Φ-proxy on the LEARNED CLM representation (not byte features), parallel vs concat. Falsifier: paired Φ(parallel)-Φ(concat) CI>0 on learned vectors AND Φ tracks the c-coupling inverse-U from #2348 (peak at intermediate). NULL = partition-invariant (reducible) representation shows Φ gap 0. 🟢 ⇒ real integrated information rises with cross-lingual semantic coupling (closes H_911 on a learned substrate)."
  verdict_tier = "⚪ OPEN"

# ───────────────────────── depletion ─────────────────────────
# Brainstorm depleted at 20 hypotheses (10 EDU + 10 NEU). Adjacent ideas collapse
# into these: working-memory/attention → CHUNK; motivation/affect → out of scope
# (no semantic-integration falsifier); translation-equivalence priming → DUALCODE;
# code-switching cost → IMMERSION; cross-language priming → L1L2OVERLAP. Further
# lenses (sociolinguistic, developmental critical-period) lack a deterministic
# learned-representation falsifier and are fenced ⚪ rather than added.
#
# Next: each → CLAIMS.tape → construct-valid hexa run (LEARNED semantic axis, with
# the within-concept-shuffle NULL probe) → .verdicts/. The PHI + ATLHUB + GWT trio
# is the highest-value first wave (each closes H_911 on a real substrate and ties to
# the #2348 Φ inverse-U). Bio line (clm-kosmos-h911-onchip.tape) closed as artifact.
