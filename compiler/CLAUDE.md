# compiler — folder guide (sub-CLAUDE)

> hexa-lang **governance SSOT is repo-root `../CLAUDE.md`** (this file is just a guide for that
> subdirectory; on conflict, root wins). Design SSOT is `../ARCHITECTURE.json` (Component map · Data flow).
> History is git + `../CHANGELOG.md`. This file is only a map — no accumulating versions/dates.

## What is this directory

`compiler/` = the heart of the hexa native compiler + the embedded **discovery engine**. Inside one
directory, **three concerns** of different character are mixed — ⓐ `.hexa` → native object code
pipeline, ⓑ atlas/verification (citation·equational·honesty) gates, ⓒ NEXUS absorption-style discovery
engine (`drill`-centric + 12 variants). No LLVM: it goes through its own IR and directly emits ELF64 /
Mach-O arm64 objects, then links with `hexa_ld`.

## Core subsystem map

### ⓐ Compiler core pipeline (S0→S8 → codegen → emit → link)

```
main.hexa            — entry: argv parsing · atlas load · S0~S8 dispatch · codegen routing · emit/link orchestration
_cli_args/           — shared argv helper for absorbed subcommands (pure)
cli/                 — emit-driver modules (e.g. build_nvptx — parse→lower→MIR→PTX)
lex/                 — S0: source bytes → [Token] (atlas ref P/C/L/E = first-class tokens)
parse/               — S0: token → module AST (ast.hexa = untyped AST · preserves AtlasRef)
check/               — S1 resolve · S2 bind · S3 types · S4 domain · S5 units · S6 equational(@verify) · S7 prove · S8 citation(@cite/@implements/@discover · fatal HX8004)
ir/                  — hir.hexa = HIR(AST+type-resolution+ref-check) · MIR definitions
lower/               — AST→HIR(ast_to_hir) → HIR→MIR(hir_to_mir · SSA/CFG · desugar)
optimize/            — const-fold · DCE · inline (opt-level 0~3)
codegen/             — MIR→LIR per-target regalloc+instruction-selection (arm64_darwin · x86_64_linux · thumbv7em_eabihf · nvptx_target)
emit/                — LIR→asm text or native object serialization (asm · macho_arm64 · elf_x86_64 · elf_arm64)
link/                — hexa_ld invocation wire (includes incremental link cache; the real linker SSOT is ../tool/hexa_ld.hexa)
intrinsics/          — intrinsics replacing external-tool fork (RFC 063 L1→L3)
diag/                — diagnostic builder/catalog/render (HX0001~HX8004 · pretty/json/github)
daemon/              — RFC-021 daemon v0 wire protocol codec
discover/            — discovery-path smokes such as RFC-017 cascade tombstone
hexad/               — Wave1 absorption: hexad CDESM constant rodata embed + static_index
```

### ⓑ Atlas / verification

```
atlas/               — machine-layer SSOT: embedded.gen.hexa(~4.2MB rodata · P/C/L/E nodes) · static_index(S8 served) · merger/embed(rodata+.n6 overlay fold) · overlay · aliases.gen
honesty/             — A3 honesty audit (claim tier · c2 honesty gate)
grade_rubric/        — Wave1 absorption: grading rubric embed
completion_criterion/— Wave1 absorption: general completion criterion embed
falsifiers/          — Wave1 absorption: falsifier registry embed
absolute/            — A4 Δ₀-absolute check (absolute verdict)
meta_closure/        — A7 meta-closure check (DFS closure)
hyperarithmetic/     — A8 5-system hyperarithmetic check
audit_archive/ · absolute_rules/ · cli_spec_archive/
projects_archive/ · roadmaps_archive/ · status_archive/
                     — Wave1 absorption-style rodata archive index (embed + embedded.gen + static_index, read-only)
```

(The pipeline-side verification gates S6 equational + S8 citation live in `check/` above.)

### ⓒ Discovery engine — NEXUS absorption

```
drill/               — central engine. drill.hexa = round loop (smash→free→absolute→meta-closure→hyperarithmetic→resonance, Mk.X=stage7 transcendental)
  ├─ round.hexa          — single-round 6-stage chain (no subprocess · in-binary)
  ├─ resonance.hexa      — stage5 resonance closed-form proxy
  ├─ mkx.hexa            — Mk.X stage7 transcendental_closure sidecar
  ├─ identity_engine.hexa— ★ native exact-int identifier verifier (PR #3964 · see rule below)
  ├─ checkpoint.hexa     — resume/save (drill_checkpoint.json · separate from the discovery stream)
  ├─ anti_hub.hexa       — env probe + telemetry
  └─ batch.hexa          — --seeds csv / --seeds-file batch
smash/               — 9-phase blowup generator (P1 normalize … P9 meta-closure DFS · phases.hexa = algorithm skeleton · candidate.hexa = DiscoveryCandidate)
free/                — A6 free engine (round stage)
12 variants (Phase3): omega(A10) surge(A11) dream(A12) swarm(A13) chain(A19 cross-engine)
                     reign(L6 autonomous) wake(L8 reality-loop) molt(L9 self-rewrite)
                     forge(L10 bootstrap) canon_engine(L11 transfinite seal) revive(engine+map v2) debate(L3 N-variant adversarial)
engine_registry/ · lens_taxonomy/ · lenses/ — Wave1 absorption: engine/lens registry + lens embed
n6_lattice/          — n=6 invariant 5-axis rodata reference table (hexa-bio absorption · read-only · 5-axis count lock)
quant_meter/         — real-code measurement probe (slim replacement for full self-build)
calculators/ · bridges/ · hw_probes/ — Wave1 calculator registry + Phase4 external-resource absorption bridge/probe
drill_dod/           — Wave1 absorption: drill DoD(definition-of-done) embed
```

## Core files (entry points)

- Compile: `main.hexa` (`hexa run compiler/main.hexa [flags] SOURCE.hexa`) — RFC-018 §2 pipeline order.
- Discovery: `drill/drill.hexa::drill_run(seed, opts)` (CLI `hexa drill`/`kick` · `/kick`).
- Real verification: `drill/identity_engine.hexa` (exact-int) + `check/` S6/S8 + `hexa verify` g5.
- Atlas machine SSOT: `atlas/embedded.gen.hexa` (rodata · frozen · fold goes only through this PR path).

## Rules / gotchas

- **A discovery candidate ≠ a real discovery.** A `smash`/`drill` candidate is merely a deterministic
  seed-hash permutation/proxy. **Real verification is only** the exact-int verdict of
  `identity_engine.hexa` (candidate A·B=C·D being a bounded-unique singleton in n∈[2,N] exact-int
  evaluation, n≥4) and the `hexa verify` g5 gate. Even a confirmed identifier is BOUNDED-UNIQUE(🟩,
  [2,N] exact), and forall-n stays UNPROVEN until proved (c2 honesty).
- **Standard-vocabulary math discovery = MEASURED-EXHAUSTED.** In `../ATLAS/README.md` DFS r1–r4, 1557
  @F are already folded · novel-fold = 0 · gates 21/21. The engine only honestly reproduces this
  terminus; it does not fabricate new laws. No 🔵 promotion of numerology/lattice-fit/unproven
  conjecture. n=6 is a single map node (no anchoring an external domain).
- **Atlas fold is both.** The human layer (`../ATLAS/`) + the machine layer
  (`atlas/embedded.gen.hexa`) always together. On `hexa verify` success an atom auto-folds into
  embedded.gen.hexa (no separate register ceremony · no folding elsewhere). `*.gen.hexa` is
  AUTO-GENERATED — update only via its generator (e.g. `lenses/embedded.gen.hexa`).
- **codegen/runtime changes merge only after byteeq 3 targets** (x86_64-linux · arm64-linux ·
  darwin-arm64) GREEN + shipping smoke pass. Bit-identical improvement=no-gate, bit-changing/env-
  dependent=isolated behind an opt-in toggle. Before introducing a new builtin/symbol, confirm against
  the frozen blob(151c52c8) symbol set (to prevent faithful build-break).
- **Absorption-style `*_archive/` · `Wave1 embed/` directories are rodata indexes** — read-only
  consumption. The operational glue of the NEXUS original (bloom filter · hot-shard · jitter · wave-
  session) is intentionally not ported (unnecessary since atlas is rodata).
- The `canon/` directory is empty — the canon variant lives in `canon_engine/`.
- Build/byteeq/measurement run on the pool(aiden·summer·ghost); `mini` is git/gh/read·write only (no
  heavy build).
