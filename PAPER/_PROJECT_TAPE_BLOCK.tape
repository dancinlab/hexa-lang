# MERGE INTO project.tape AFTER: sidecar sign project
#
# Adapted from anima a_paper_* / hexa-codex cx_paper_* into hexa-lang's
# bare snake_case directive convention (no hx_/hl_ prefix — matches
# diff_guard / wipe_guard / atlas_fold / stdlib_trig_libm).
#
# Paste this block into project.tape after stdlib_trig_libm, then
# `git add project.tape` (the sign token unlocks the agent edit).
#
# Infra already landed in this PR: CLAIMS.tape · .verdicts/ · PAPER/.
# Every `do =`/`dont =` value is ≤100 chars (hexa-lang lint cap).

# ── PAPER auto-generation flow (ported from anima a_paper_* ← hexa-codex) ────
# atlas atom / compiler RUNEQ → hexa verify (g5) → .verdicts/<slug>/<id>.txt
#   → CLAIMS.tape → /paper. g5 verify discipline IS this gate.

@D claim_manifest := "CLAIMS.tape — single audit index of verifiable hexa-lang claims" :: workflow [required active]
  do   = "every verifiable claim in root CLAIMS.tape — id · text · method · slug · group · verdict ptr"
  dont = "scatter claims across docs / RFCs / *.tape logs without a CLAIMS.tape index — no audit surface"

@D claim_verify := "every claim runs through hexa verify (g5), verdict persisted verbatim" :: workflow [required active]
  do   = "each CLAIMS.tape entry → `hexa verify` (g5) → `.verdicts/<slug>/<id>.txt` raw stdout verbatim"
  dont = "LLM self-judge correctness · paraphrase verdicts · hide a 🔴 or unfenced speculation"

@D paper_gate := "/paper gated on terminal verdict AND significance" :: workflow [required active]
  do   = "`/paper new <slug>` only when every section claim is terminal AND significance is satisfied"
  do   = "terminal = 🔵 formal / 🟢 numerical / 🔴 CLOSED-negative — not 🟠 deferred / 🟡 citation / ⚪"
  dont = "scaffold with any 🟠 deferred · 🟡 citation-only · ⚪ unfenced speculation · trivial recheck"

@D paper_significance := "paper requires a pre-registered falsifier + real measurement + a finding" :: workflow [required active]
  do   = "trigger only on a pre-registered falsifier + real measurement (verify / byte-diff / RUNEQ)"
  do   = "finding = Δ vs baseline OR a closed-negative deterministically ruling out one axis"
  dont = "paper for an atom recheck · known identity · bookkeeping closure · 🟠 residual prediction"

@D paper_negative_ok := "closed-negative findings are publishable" :: workflow [required active]
  do   = "a 🔴 FALSIFIED result that deterministically rules out a path is a valid paper"
  do   = "frame as a negative result — the falsifier + the ruled-out space (e.g. a disproven property)"
  dont = "treat a closed-negative as a non-finding · bury a falsification · publish a 🟠 as if closed"

@D paper_format := "paper sections — statement · method · verification · finding" :: workflow [required active]
  do   = "§statement (falsifier) · §method · §verification (real run) · §finding (Δ OR ruled-out axis)"
  do   = "commons g51 — compile ≥10 pages + ≥1 fal.ai figure"
  dont = "narrative-only · verification substitute for the statement · skip §finding · vague claims"

@D paper_sections := "every paper section claim links to its verdict" :: workflow [required active]
  do   = "every section claim links to its `.verdicts/<slug>/<id>.txt` verdict (verbatim stdout)"
  dont = "ship a paper with any unresolved residual section · treat the verdict matrix as optional"

@D paper_violation := "violating paper immediately revoked" :: workflow [required active]
  do   = "violating paper (gate / significance fail) revoked immediately — PAPER/<slug>/ removed"
  dont = "keep a violating paper as a draft · mark it WIP · defer revocation · allow a residual"

@D paper_one_per_group := "one canonical paper per group — ATLAS · COMPILER · CANON" :: workflow [required active]
  do   = "one paper per group — ATLAS theorems · COMPILER self-host/codegen · CANON verify-discipline"
  do   = "replace in place when a stronger finding lands"
  dont = "ship multiple papers per group · accumulate a backlog · fork same-group narratives"
