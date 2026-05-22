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
  g_llm_pluggable = "hexa loop --dfs (RFC 080) is the ONLY path that may invoke an external LLM. Opt-in (default off); requires a pluggable --llm-cmd (no vendor baked in); gates real exec behind --allow-llm; MUST enforce a budget cap (--llm-calls/--llm-time/--llm-budget) AND the dfs_verify_child gate (cite-required + cite-in-atlas + English-only via CJK-band 0xE3-0xED reject + Greek normalize). LLM output (verified children) lands in inbox/atlas_candidates/** AND auto-appends a tape `@P <slug> :: dfs [3?]` entry to overlay_path() (= <HX_DATA_DIR>/atlas.overlay.n6 — the same EXPORT-ONLY stream `compiler/drill/round.hexa::_cand_to_n6` writes; unified discovery corpus). It MUST NEVER write compiler/atlas/embedded.gen or compiler/lenses/embedded.gen directly — promotion overlay → baked stays PR-only per g_atlas_binary_builtin (overlay runtime-load is retired-to-empty, so absorbed entries do NOT auto-flow back into build_atlas_view; they feed the discovery → 3+ hits → promote pipeline only). SSOT: TECS-L.md + inbox/rfc_drafts_2026_05_22/rfc_080_hexa_loop_dfs.md."

@D h_native_codegen := "native codegen only — no LLVM, no C-transpile" :: governance [required active]
  do   = "self-hosted compiler emits its own machine code (or its own C fallback artifact); architecture SSOT = hexa-first"
  dont = "add an LLVM IR backend · make C-transpile the default architecture · use third-party codegen as the default path"

@D h_stdlib_ssot := "stdlib SSOT = hexa-lang — downstream imports only" :: governance [required active]
  do   = "all `stdlib/` modules are hexa-lang's sole source of truth; downstream repos (echoes · anima · forge · ...) consume via import only"
  dont = "let downstream vendor / fork / dual-home absorbed stdlib (qrng · qmirror · sim-universe) · accept direct stdlib edits from consumers"

@D h_inbox_patches := "external patches via inbox pipeline" :: governance [required active]
  do   = "downstream patch requests land in `inbox/patches/<descriptive>.md` (one concept per file) → upstream review → integration"
  dont = "downstream consumer edits hexa-lang directly (bypassing inbox) · mix multiple concepts in one patch file"

@D h_atlas_single_export := "atlas SSOT = n6/atlas.n6 — single export, no hxc" :: governance [required active]
  do   = "atlas reads/writes flow through `n6/atlas.n6` (full corpus, vendored) + `atlas.append.*.n6` staging shards. `static_atlas()` parses via `compiler/atlas/merger::load_atlas` at load time (HEXA_ATLAS_N6 env override; empty → `~/core/hexa-lang/n6` stable fallback, NOT CWD-relative). `hexa atlas append-witness` MUST auto-wrap `--raw` into a `@<KIND> <id>` node sigil so shards never orphan in the merger (parser.hexa::_is_header_sigil). Append-witness supports all 9 kinds (P|C|L|E|F|R|S|X|Q)."
  dont = "ship `dist/atlas.hxc` as the runtime artifact · regenerate the sidecar via `tool/atlas_build_hxc.hexa` against the lean `compiler/atlas/embedded.gen.hexa` (it silently shrinks the SSOT — 2026-05-22 incident lost 8,504 nodes) · write witness shards without a `@<KIND>` body sigil (the merger drops them — 6 such orphans observed 2026-05-22) · resolve `atlas.n6` via CWD-relative paths · let downstream vendor `dist/atlas.hxc`. Background: inbox/notes/2026-05-22-atlas-n6-ssot-recovery.md."
