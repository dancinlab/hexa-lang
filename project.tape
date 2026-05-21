@V := "tape" :: spec [active]
  version = "1.2"

@I := "hexa-lang" :: identity [active]
  kind   = "Native compiler with atlas-bound theorems (8 strict-lint stages · no LLVM · no C-transpile · 💎)"
  brief  = "Write code that cites a theorem atlas at compile time; lint stages reject formula-bearing code without @cite. Self-host compiler + interpreter; in-house prover + linker; English-only diagnostics; zero runtime GC."
  parent = "dancinlab"
  ssot   = "github.com/dancinlab/hexa-lang (`hx install hexa-lang`)"

@D := "hexa-lang" :: governance [active]
  do   = "..."
  dont = "..."
