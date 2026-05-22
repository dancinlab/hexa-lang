@V := "tape" :: spec [active]
  version = "1.2"

@I := "hexa-lang" :: identity [active]
  kind   = "Native compiler with atlas-bound theorems (8 strict-lint stages · no LLVM · no C-transpile · 💎)"
  brief  = "Write code that cites a theorem atlas at compile time; lint stages reject formula-bearing code without @cite. Self-host compiler + interpreter; in-house prover + linker; English-only diagnostics; zero runtime GC."
  parent = "dancinlab"
  ssot   = "github.com/dancinlab/hexa-lang (`hx install hexa-lang`)"

@D := "hexa-lang" :: governance [active]
  do   = "Subagent cycles MUST git diff <baseline>...HEAD on every guarded file BEFORE staging. Use the pre-commit hook (.githooks/pre-commit) — opt in via `git config core.hooksPath .githooks`."
  dont = "Never commit deletions in stdlib/runtime/** · self/runtime*.c · self/runtime_arena.c · self/codegen_c2.hexa · compiler/check/bind.hexa · self/rt/core.hexa unless the cycle declares 'runtime/stdlib/codegen' scope in the subject. Sub-agent worktrees are 8-session shared; a stale tree silently drops re-lands. WIPE-OK: <reason> trailer is the only escape."
  g_runtime_wipe_guard = "Pre-commit wipe-guard (.githooks/pre-commit) blocks any staged commit deleting >50 lines across guarded paths (stdlib/runtime/** · self/runtime.c · self/runtime_core.c · self/runtime_arena.c · self/codegen_c2.hexa · compiler/check/bind.hexa · self/rt/core.hexa) unless the subject mentions runtime|stdlib|codegen|rt_|RUNTIME|restore|re-land|recover, or a `WIPE-OK: <reason>` trailer is present. Opt-in per clone via `git config core.hooksPath .githooks`. Background: inbox/notes/2026-05-22-wipe-governance-proposal.md. Motivated by 10 silent wipes in 3 weeks (5 in 48h: c39afbbe + 0d59c419 + 724c38b3 + c4c721bc + e8c2dc1c)."
  g_llm_pluggable = "hexa loop --dfs (RFC 080) is the ONLY path that may invoke an external LLM. Opt-in (default off); requires a pluggable --llm-cmd (no vendor baked in); gates real exec behind --allow-llm; MUST enforce a budget cap (--llm-calls/--llm-time/--llm-budget) AND the dfs_verify_child gate (cite-required + cite-in-atlas + English-only ASCII). LLM output lands ONLY in inbox/atlas_candidates/** (PR-only, per g_atlas_binary_builtin) — it MUST NEVER write compiler/atlas/embedded.gen or compiler/lenses/embedded.gen directly. SSOT: TECS-L.md + inbox/rfc_drafts_2026_05_22/rfc_080_hexa_loop_dfs.md."

@D h_native_codegen := "native codegen only — no LLVM, no C-transpile" :: governance [required active]
  do   = "self-hosted compiler emits its own machine code (or its own C fallback artifact); architecture SSOT = hexa-first"
  dont = "add an LLVM IR backend · make C-transpile the default architecture · use third-party codegen as the default path"

@D h_stdlib_ssot := "stdlib SSOT = hexa-lang — downstream imports only" :: governance [required active]
  do   = "all `stdlib/` modules are hexa-lang's sole source of truth; downstream repos (echoes · anima · forge · ...) consume via import only"
  dont = "let downstream vendor / fork / dual-home absorbed stdlib (qrng · qmirror · sim-universe) · accept direct stdlib edits from consumers"

@D h_inbox_patches := "external patches via inbox pipeline" :: governance [required active]
  do   = "downstream patch requests land in `inbox/patches/<descriptive>.md` (one concept per file) → upstream review → integration"
  dont = "downstream consumer edits hexa-lang directly (bypassing inbox) · mix multiple concepts in one patch file"
