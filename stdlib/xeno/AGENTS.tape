#!/usr/bin/env tape

@V := "tape" :: spec [active]
  version = "1.2"

@X hexa_verify := "hexa verify — verification via hexa CLI only" :: guide [active]
  tldr = "Any correctness / purity / grade / identity claim → verify with `hexa <verb>` or `hexa run <verifier>.hexa` (e.g. `hexa run tool/atlas_verify.hexa`) and paste the verdict VERBATIM. NEVER cite sympy / PyPhi / Wolfram / Mathematica output as evidence."
  detail = "~/core/atlas/VERIFY.tape"

@X wilson_pool := "wilson pool — resource utilization" :: guide [active]
  tldr = "Heavy / deterministic work (build · drill · probe · compile · test-sweep · GPU fire) → do NOT serialize on localhost; route to the host pool: `wilson pool list` then `wilson pool on <host> <cmd>`, or a ToolUse `\"host\"` field. Empty roster = degrade-to-local, fine."
  detail = "~/core/atlas/POOL.tape"

# ─── identity ─────────────────────────────────────────────────────────
@I id001 := "xeno" :: project [active]
  brief = "Tier C non-GPU exotic compute substrate · AKIDA · Loihi3 · Northpole · FinalSpark · IonQ"
  parent = "dancinlab"
  one_liner = "Standalone repo for non-GPU exotic compute substrate research — Tier C scope (silicon neuromorphic + biological organoid + quantum + random)."
  doi = "10.5281/zenodo.20102972"
  substrates <<~EOF
    AKIDA AKD1000     BrainChip          roadmaps/.roadmap.akida
    Loihi3            Intel              roadmaps/.roadmap.loihi3
    Northpole         IBM                roadmaps/.roadmap.northpole
    FinalSpark        FinalSpark organoid roadmaps/.roadmap.finalspark
    Cortical Labs     DishBrain          roadmaps/.roadmap.cortical_labs
    IonQ              Quantum gate        roadmaps/.roadmap.ionq
    QRNG              Quantum RNG         roadmaps/.roadmap.qrng
  EOF
  entry = "hexa-installed binary (`hx install xeno`); subcommands: status / connect / invoke / fallback / list / roadmap / falsifier / cycle"
  exit_codes <<~EOF
    0  success
    1  subcommand error (dispatched tool exit)
    2  unknown topic / malformed invocation
    91 connection failed (raw 91 honest C3 fail-loud — silent skip BANNED)
  EOF
  bridges = ["anima", "nexus", "hive", "hexa-brain"]
  falsifier_harness = "12-falsifier (nexus copy SSOT)"

# ─── layout ───────────────────────────────────────────────────────────
@L l1 := "repo-layout" :: structure [active]
  root = ["anima_physics_origin/", "bin/", "cli/", "design/", "docs/", "mirror/", "n6/", "roadmaps/", "scripts/", "state/", "tool/", "hexa.toml", "install.hexa", "CITATION.cff", "README.md", "TAPE-AUDIT.md", "AGENTS.tape", "CLAUDE.md"]
  package = "hx-installable (`hx install xeno`); entry via `bin/xeno`"
  CLAUDE_md = "symlink → AGENTS.tape"

# ─── governance (inherits + baseline) ─────────────────────────────────
@D g_inherit := "inherits-lattice-policy" :: governance [active required]
  authority = "~/core/hexa-chip/LATTICE_POLICY.md"
  => "n=6 lattice is a tool, not a constraint — substrate capabilities answer to vendor / physics reality"

@D g1 := "real-limits-first" :: governance [active required]
  => "AKD1000 / Loihi3 / Northpole / FinalSpark / DishBrain / IonQ / QRNG capabilities are dictated by vendor hardware spec + physics; never round measurements or generation counts to fit lattice numerology"

@D g2 := "lattice-is-tool" :: governance [active required]
  => "substrate count is 7 (the substrates that exist); not 6 / 8 / 12 to fit any number system"

@D g3 := "honesty-external" :: governance [active required]
  => "exit-code 91 = raw honest C3 fail-loud; silent-skip BANNED — substrate unreachability is reported, not papered over"

@D g4 := "commit-conventions" :: governance [active recommended]
  => "imperative subject; cite substrate id / roadmap / falsifier when applicable; one concept per commit"

@D g5 := "generation-aware-probes" :: governance [active required]
  => "Akida cycle dispatcher uses `--akida-gen {auto,1,2,3,...}` — probe/capabilities/measure are generation-aware; AKD1000 PRIMARY + Cloud FALLBACK (own 35)"

@D g_arch_vs_log_split := "v1.2 architecture-vs-history split" :: governance [required d=2026-05-14 active]
  rule = "UPPERCASE.tape files are EDITABLE architecture (latest-wins per id). Append-only event history lives in UPPERCASE.log.tape siblings."
  why = "declarative entries (governance · config · layout · identity) evolve naturally; locking them as append-only via ~> supersedes creates noisy histories. The split lets architecture stay current and history stay immutable."
  applies-to = "AGENTS.tape · all UPPERCASE.tape root files"
  authority = "[@x_tape_spec] §Domain-tape sibling §Architecture-vs-history split"
  @> AGENTS.md


# ─── forbidden patterns ───────────────────────────────────────────────
@F f1 := "lattice-fit-on-external-entity" :: forbidden [active deny:write]
  pattern = "rounding substrate measurements / generation counts / falsifier counts / threshold values to n=6 lattice numerology"
  rationale = "substrates are external real-world hardware; their numbers are not negotiable to fit wilson's internal lattice"

@F f_silent_substrate_skip := "silent-substrate-skip" :: forbidden [active deny:write]
  pattern = "catching substrate-connection failures and continuing silently instead of returning exit code 91"
  rationale = "C3 fail-loud doctrine — silent skip on unreachable substrate is BANNED"

# ─── external refs ────────────────────────────────────────────────────
@X x_lattice_policy := "lattice-policy" :: external [active]
  path = "~/core/hexa-chip/LATTICE_POLICY.md"
  binds = "g_inherit, f1"

@X x_tape_spec := "tape-spec" :: external [active]
  path = "~/core/tape/spec/tape.md"
  upstream = "github.com/dancinlab/tape"

@X x_anima := "anima-bridge" :: external [active]
  role = "physics-origin sibling; xeno mirrors anima_physics_origin/ for citation"

@X x_nexus := "nexus-falsifier-ssot" :: external [active]
  role = "12-falsifier harness — nexus is SSOT, xeno carries a copy"

@X x_hexa_lang := "hexa-lang-install" :: external [active]
  url = "https://raw.githubusercontent.com/dancinlab/hexa-lang/main/install.sh"
  role = "prerequisite — `hexa` + `hx` package manager"

# ─── migration history ────────────────────────────────────────────────
@H h1 := "agents-md-replaced" :: migration [active d=2026-05-14]
  => "empty AGENTS.md placeholder removed; AGENTS.tape (this file) is the SSOT"

@H h2 := "claude-md-symlink" :: migration [active d=2026-05-14]
  => "CLAUDE.md → AGENTS.tape (Claude Code projection)"
