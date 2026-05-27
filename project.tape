@V := "tape" :: spec [active]
  version = "1.2"

@I := "hexa-lang" :: identity [active]
  kind   = "Native compiler with atlas-bound theorems (8 strict-lint stages · no LLVM · no C-transpile · 💎)"
  brief  = "Code cites a theorem atlas at compile time; lint rejects formula-bearing code without @cite."
  parent = "dancinlab"
  ssot   = "github.com/dancinlab/hexa-lang (`hx install hexa-lang`)"

@D diff_guard := "subagent diff-guard before staging" :: governance [required active]
  do   = "subagent cycles `git diff <baseline>...HEAD` guarded files before staging · `.githooks/pre-commit`"

@D wipe_guard := "wipe-guard — >50-line deletions need scope or WIPE-OK" :: governance [required active]
  dont = "commit >50-line deletions in stdlib/runtime/codegen/rt without scoped subject or `WIPE-OK:` trailer"

@D external_llm := "external LLM only via `hexa loop --dfs`" :: governance [required active]
  dont = "invoke external LLM outside `hexa loop --dfs` (pluggable --llm-cmd · budget cap · verify gate)"

@D atlas_fold := "atlas fold — embedded.gen.hexa via branch → commit → PR" :: governance [required active]
  dont = "fold atlas nodes anywhere but compiler/atlas/embedded.gen.hexa via branch → commit → PR"

@D stdlib_trig_libm := "stdlib trig = libm builtins, not hand-rolled Taylor" :: governance [required active]
  do   = "stdlib signal/math modules use native libm trig (`cos`/`sin`/…) — IEEE-correct · codegen-stable"
  dont = "hand-rolled Taylor sin/cos — fragile (float→int narrowing the codegen dropped → collapses)"

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

@D paper_on_discovery := "any verified discovery becomes a paper — free slug, no fixed domain" :: workflow [required active]
  do   = "every terminal discovery → its own paper slug (named by the finding, not a fixed bucket)"
  do   = "replace/supersede in place when a stronger finding lands on the same slug"
  dont = "pre-assign papers to fixed domain buckets · cap the paper set · force a finding into wrong slug"

@D discovery := "discovery runs continuously, not only at cycle tail" :: workflow [required active]
  do   = "interleave /kick · /gap discovery every batch — a discovery lane runs alongside verify"
  dont = "defer discovery to the end · single tail-only round · stop discovering once a paper ships"

@D discovery_log := "discoveries persist at .discoveries/<slug>.tape" :: workflow [required active]
  do   = "log every kick/gap discovery to `.discoveries/<slug>.tape` — id · seed · verdict-tier-target"
  dont = "discard discovery output · paraphrase findings · skip linking discovery → next-cycle claim"

@D h_verify_auto_absorb := "hexa verify auto-folds atom to atlas on success — ambient, not ceremony" :: governance [required active]
  do   = "successful 🔵/🟢 verify auto-folds the atom to atlas (embedded.gen.hexa SSOT) by default"
  do   = "verify is the SINGLE canonical surface — no separate `atlas register` ceremony needed post-verify"
  dont = "ship a verify pass that doesn't auto-fold on success · require manual `atlas register` after verify"

@D h_audit_axis_form := "domain audits = `hexa verify --<axis> <domain>` subcommand form (e.g. --blue-max)" :: governance [required active]
  do   = "future domain-level audits land as `hexa verify --<axis> <domain>` — single CLI surface, no new verbs"
  do   = "audit output = tier matrix + pair-coverage + atlas-absorb side-effect (ambient via auto-absorb)"
  dont = "spawn new top-level `hexa <audit>` verbs · split audit from verify · split atlas absorb from verify"
