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
