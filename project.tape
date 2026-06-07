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

# ── PAPER / capitalization policy → commons g84 (single SSOT · OPT-IN) ────
# Capitalization (paper / README-publish) is NOT proactive: the agent never proposes
# /paper nor auto-scaffolds on discovery. A verified discovery is logged (verdict +
# domain milestone) ONLY; a paper happens WHEN the user instructs it, gated by commons
# g84. verify discipline = commons g5. (Removed: ported claim_*/paper_*/discovery flow.)

@D h_verify_auto_absorb := "hexa verify auto-folds atom to atlas on success — ambient, not ceremony" :: governance [required active]
  do   = "successful 🔵/🟢 verify auto-folds the atom to atlas (embedded.gen.hexa SSOT) by default"
  do   = "verify is the SINGLE canonical surface — no separate `atlas register` ceremony needed post-verify"
  dont = "ship a verify pass that doesn't auto-fold on success · require manual `atlas register` after verify"

@D h_audit_axis_form := "domain audits = `hexa verify --<axis> <domain>` subcommand form (e.g. --blue-max)" :: governance [required active]
  do   = "domain audits land as `hexa verify --<axis> <domain>` — one CLI surface, no new verbs"
  do   = "audit output = tier matrix + pair-coverage + atlas-absorb side-effect (ambient via auto-absorb)"
  dont = "spawn new top-level `hexa <audit>` verbs · split audit from verify · split atlas absorb from verify"

@D hf_org := "HuggingFace namespace = `dancinlab` org (huggingface.co/dancinlab)" :: governance [required active]
  do   = "all HF uploads + Collections live under the `dancinlab` ORG namespace"
  do   = "create_collection(namespace=\"dancinlab\") · push `dancinlab/<repo>` — token user is org admin"
  do   = "the org page huggingface.co/dancinlab is the single SSOT surface for models + datasets"
