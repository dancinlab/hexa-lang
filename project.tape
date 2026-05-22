@V := "tape" :: spec [active]
  version = "1.2"

@I := "hexa-lang" :: identity [active]
  kind   = "Native compiler with atlas-bound theorems (8 strict-lint stages · no LLVM · no C-transpile · 💎)"
  brief  = "Code cites a theorem atlas at compile time; lint rejects formula-bearing code without @cite."
  parent = "dancinlab"
  ssot   = "github.com/dancinlab/hexa-lang (`hx install hexa-lang`)"

@D := "hexa-lang" :: governance [active]
  do   = "subagent cycles `git diff <baseline>...HEAD` guarded files before staging · use `.githooks/pre-commit`"
  dont = "commit >50-line deletions in stdlib/runtime/codegen/rt paths without a scoped subject or `WIPE-OK:` trailer · invoke an external LLM outside `hexa loop --dfs` (opt-in · pluggable --llm-cmd · budget cap · verify gate) · fold atlas nodes anywhere but directly into compiler/atlas/embedded.gen.hexa via branch → commit → PR"
