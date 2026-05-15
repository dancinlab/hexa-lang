#!/usr/bin/env tape
# ══════════════════════════════════════════════════════════════════════
# .tape v1.2 — grammar primer (cold-read by any LLM / agent / human)
# ══════════════════════════════════════════════════════════════════════
# Form: each entry is `@<type> <id> := "<subject>" :: <kind> [<grades>]`
#       optionally followed by body lines (2-space indent) — key=value,
#       edges (<- -> => …), or quoted prose.
#
# ENTRY TYPES (17): @S session @U user @A assistant @T tool-call @R result
#   @H hook @D decision @K cost @P provider @? anomaly @I identity-claim
#   @X external-citation @F forbidden-pattern @N note @C config @L layout
#   @V spec-version
#
# EDGES (12, on body lines, 2-space indent):
#   <- caused-by  -> triggers  == continues  ~> supersedes  !! aborts
#   |> verified-by  => produces  <: specializes  :> generalizes
#   ?> soft-depends  !> conflicts-with  @> projects-to
#
# Full spec: ~/core/tape/spec/tape.md (or github.com/dancinlab/tape)
# ══════════════════════════════════════════════════════════════════════
#
# COMPILE-SPEED.tape for `dancinlab/hexa-lang`
#
# Sibling to COMPILE-ONLY.tape (interpreter-retirement doctrine).
#   COMPILE-ONLY  = WHAT compile path (no interp/JIT/LLVM as architecture).
#   COMPILE-SPEED = HOW FAST that path runs (measure-first, then fix).
#
# v1.2 architecture-vs-history split: this .tape file holds the current
# architecture state (latest-wins per id) — pipeline shape, findings,
# proposals, forbidden patterns, action queue. Per-build measurement
# runs are appended to COMPILE-SPEED.log.tape (append-only sibling).

@V := "tape" :: spec [active]
  version = "1.2"

@I id001 := "hexa-lang.compile-speed-audit" :: identity-claim [d=2026-05-15 active]
  kind = "performance audit + improvement roadmap for the .hexa → C → clang pipeline"
  brief = "compile-speed substrate — measure-first principle + ROI-ranked proposals + phased action queue"
  parent = "dancinlab/hexa-lang"
  sibling-log = "COMPILE-SPEED.log.tape"
  scope = "wall-clock compile time of user programs (small) AND self-host stage1 (large)"
  doctrine = "measure-first — `/usr/bin/time -l` + `clang -ftime-report` before any optimization decision"
  consumers = "build driver authors · hexa_v2 codegen contributors · downstream tooling (LSP, hexa run)"

# ─── §2 Operating doctrine ───────────────────────────────────────────

@D measure_first := "measure-first principle" :: governance [required d=2026-05-15]
  rule = "Compile-speed improvement proposals MUST cite a measurement (time + ftime-report or per-stage instrumentation). Speculation without numbers is rejected."
  why = "user directive 2026-05-15 — `time + clang -ftime-report 그쪽이 추측보다 정확`. Past hot-take fixes optimized the wrong stage."
  apply = "before claiming `clang is slow` / `hexa_v2 is slow` / `runtime is bloated`, run the bench and attach numbers as a @N measurement entry"

# ─── §3 Pipeline anatomy ─────────────────────────────────────────────

@N pipeline := "compile pipeline shape" :: note [d=2026-05-15 active]
  stages <<~EOF
    .hexa source
      → hexa_v2 (emits user.c that does `#include "runtime.c"`)   ≈ frontend
      → clang -O0 user.c (compiles user.c + ~12K LOC runtime.c)    ≈ backend
      → ELF / Mach-O
  EOF
  runtime_loc = "11 950 (self/runtime.c)"
  self_host_loc = "21 763 (self/native/hexa_cc.c — typical large output)"
  authority = "[@x_hexa_native_only] [@x_compile_only]"

# ─── §5 Findings ─────────────────────────────────────────────────────

@D finding_tiny := "tiny-program bottleneck = runtime.c re-codegen" :: finding [d=2026-05-15 active]
  rule = "On user programs ≤ 1 K LOC, ≈ 80 % of wall-clock compile time is clang re-codegening the 12 K LOC runtime.c that's #included into every translation unit."
  evidence = "see COMPILE-SPEED.log.tape @bench_tiny / @bench_ftime_report / @bench_phases (d=2026-05-15)"
  why = "self/runtime.c is included as source by every generated user.c; clang cannot cache across TU boundaries without a header/.o split"
  blast_radius = "every `hexa run x.hexa` · every test · every LSP path that codegens"

@D finding_self_host := "self-host stage1 bottleneck = interp dispatch, NOT clang" :: finding [d=2026-05-15 active]
  rule = "Stage1 self-compile wall (~21 min — see [@x_open_wallclock]) is dominated by hexa_interp running hexa_v2 as interpreted code, NOT by the trailing clang step."
  apply = "do NOT conflate the two axes. Tiny-program wins (runtime.c precompile) and self-host wins (direct native codegen, interp retirement) are ORTHOGONAL."
  authority = "[@x_open_wallclock] [@x_compile_only]"

# ─── §6 Improvement options — ROI-ranked ─────────────────────────────
#
# ROI = (expected absolute wall-clock reduction × affected workflows)
#       / (implementation cost + risk + measurement-uncertainty)
#
# rank 1 : evidence-backed, biggest absolute win, single-leverage
# rank 2 : evidence-backed, small win but trivial cost (stacks on rank 1)
# rank 3 : speculative, blocked on instrumentation — measure first
# rank 4 : weaker alternative to rank 1; use only if rank 1 blocked

@D opt_precompile_runtime := "RANK 1 — precompile runtime.c → runtime.o + link" :: proposal [d=2026-05-15 active recommended]
  roi_rank = 1
  rule = "Replace `#include \"runtime.c\"` in generated user.c with `#include \"runtime.h\"` (extern decls) + final-link against a prebuilt runtime.o."
  expected_speedup = "small programs: 1.07 s → ~0.2 s (≈ 5× faster). Self-host stage1 final-link step: -0.9 s (negligible at 21-min scale, but free)."
  evidence = "see COMPILE-SPEED.log.tape @bench_phases — runtime.o build = 0.88 s; that cost moves from per-build to once-per-runtime-change (sha256-keyed cache)"
  cost <<~EOF
    1. Audit self/runtime.c — list every `static` symbol that becomes externally
       visible after the split; rename/namespace-prefix conflicts before exposing.
    2. Author self/runtime.h — extern decls for hexa_* fns + HexaVal struct + macros.
    3. Patch hexa_v2 codegen: emit `#include "runtime.h"`, not `#include "runtime.c"`.
    4. Patch hexa.real driver: build runtime.o once (sha256-cached), link as final clang step.
  EOF
  risk = "static-local symbols inside runtime.c lose internal linkage when split. Audit (step 1) is the mitigation."
  blast_radius = "every `hexa run` / test / LSP path that compiles — universal win"

@D opt_dev_flags := "RANK 2 — dev-mode clang flag bundle" :: proposal [d=2026-05-15 active optional]
  roi_rank = 2
  rule = "for dev/test builds, pass: `-O0 -fno-stack-protector -fno-unwind-tables -fno-asynchronous-unwind-tables` (and skip -g)."
  expected_speedup = "5–15 % marginal — most -O0 codegen is mandatory. STACKS on top of rank 1."
  cost = "1 line in driver flag-builder; cost ≈ zero"
  status = "NOT YET MEASURED — must bench (on top of rank 1 baseline) before promoting to default"
  why_rank_2 = "trivial effort, but small absolute payoff and only meaningful after rank 1 lands"

@D opt_parallel_lint := "RANK 3 — parallelize strict-lint stages in hexa_v2" :: proposal [d=2026-05-15 draft]
  roi_rank = 3
  rule = "Of the 8 strict-lint stages, those without cross-deps (e.g. citation match || formula well-formedness) could run on threads."
  expected_speedup = "UNKNOWN — depends on actual per-stage cost share. Tiny programs total hexa_v2 = 0.01 s (no win); self-host MAY help (separate axis — see [@finding_self_host])."
  blocked_on = "per-stage timing instrumentation in hexa_v2 — must measure before optimizing"
  why_rank_3 = "speculative + blocked + targets a different axis than rank 1/2"

@D opt_pch_runtime := "RANK 4 (fallback alt) — precompiled-header for runtime.c" :: proposal [d=2026-05-15 active optional]
  roi_rank = 4
  rule = "Build runtime.c as a clang precompiled header (.pch); user.c does `-include runtime.pch` via driver."
  why = "less invasive than .o split — no header to author; clang reads .pch as a binary AST dump, skipping front-end for runtime.c"
  caveat = "skips ONLY front-end (~25 %, 0.34 s); codegen still runs for unused runtime fns (the 65 % bulk). Weaker than rank 1 by ~3×."
  use_when = "rank 1 blocked by static-linkage audit cost or by inability to author runtime.h"
  conflicts_with = "[@opt_precompile_runtime] — pick one, not both"

# ─── §7 Out-of-scope (do not optimize prematurely) ───────────────────

@F skip_jit_for_speed := "JIT as `compile-speed` win" :: governance [required deny:write]
  pattern = "proposing JIT to reduce cold-start latency before AOT compile-speed is exhausted"
  why = "[@x_compile_only] @F f2 already rejects JIT as architecture; speed gains live in the AOT path"

@F skip_ccache_shim := "external build-cache wrapper before splitting runtime.c" :: governance [required deny:write]
  pattern = "wrapping ./hexa with ccache/sccache to mask the runtime.c re-codegen cost"
  why = "treats symptom; [@opt_precompile_runtime] eliminates the cause and is simpler"

# ─── §8 Action queue — ROI-ordered phased plan ───────────────────────

@D action_queue := "phased execution plan (ROI-ordered)" :: plan [active d=2026-05-15]
  ranking_basis = "ROI rank from §6. Higher-rank phase MUST gate-pass (bench evidence) before lower-rank phase starts."
  ordered_steps <<~EOF
    ═══ PHASE 1 — runtime.c split (rank 1, ≈ 5× on tiny programs) ═══
    1.1 Audit self/runtime.c for `static` symbols that need to become extern.
        Rename/namespace conflicts before exposing.
    1.2 Author self/runtime.h — extern decls + HexaVal struct + macros (SSOT for ABI).
    1.3 Patch hexa_v2 codegen — emit `#include "runtime.h"` (not runtime.c).
        Smoke gate: test_tiny2.hexa + handful of bench/ programs pass.
    1.4 Patch ./hexa.real (or build driver) — build runtime.o once, sha256-cached at
        ~/.hexa-cache/runtime-<sha>.o, link as final clang step.
    1.5 BENCH GATE — re-measure tiny + bench/*; require ≈ 5× speedup.
        Append numbers to COMPILE-SPEED.log.tape. PHASE 2 blocked until pass.

    ═══ PHASE 2 — dev-mode flag bundle (rank 2, stack-on win) ═══
    2.1 Measure [@opt_dev_flags] on top of PHASE 1 baseline.
    2.2 Promote to default dev path only if ≥ 10 % marginal AND no test regressions.

    ═══ PHASE 3 — strict-lint parallelization (rank 3, blocked / unknown) ═══
    3.1 Add per-stage timing instrumentation to hexa_v2 (small, mechanical).
    3.2 If any single stage > 20 % of hexa_v2 wall AND hexa_v2 > 10 % of total
        compile wall, evaluate parallelization. Otherwise DEFER.

    ═══ FALLBACK — rank 4 [@opt_pch_runtime] ═══
    Only if PHASE 1 blocks on header-authoring or static-linkage audit cost.
    Smaller win (1.3× vs 5×) but zero header maintenance. Mutually exclusive with PHASE 1.
  EOF
  parallelizable = "PHASE 1 internal: 1.1 → 1.2 → 1.3 → 1.4 → 1.5 strictly sequential. PHASE 3.1 can run in parallel with PHASE 1 if instrumentation work doesn't touch codegen."
  abort_conditions <<~EOF
    PHASE 1 abort if 1.5 bench gate fails (no ≈ 5× win) — investigate before continuing.
    PHASE 2 abort if 2.1 shows < 5 % marginal — not worth flag-bundle maintenance.
    PHASE 3 deferred indefinitely if 3.1 instrumentation shows hexa_v2 < 10 % of total compile wall.
  EOF

# ─── §9 External citations ───────────────────────────────────────────

@X x_compile_only := "COMPILE-ONLY.tape" :: doctrine [active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/COMPILE-ONLY.tape"
  scope = "sibling doctrine — defines the compile-only path (no interp/JIT/LLVM as architecture). This file measures how fast that path runs."

@X x_hexa_native_only := "HEXA-NATIVE-ONLY.md" :: policy [active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/HEXA-NATIVE-ONLY.md"
  scope = "no LLVM backend as architecture; clang serves only as the C → machine-code stage of the AOT pipeline"

@X x_open_wallclock := "COMPILE-ONLY.log.tape @open_wallclock" :: status [active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/COMPILE-ONLY.log.tape"
  scope = "stage1 self-compile wall-clock (~21 min) — orthogonal axis from this file's small-program findings"

@X x_spec_5 := "SPEC.md §5 (Bootstrap)" :: spec [active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/SPEC.md#5-bootstrap--existing-hexa_interp-is-stage-0-decision-2"
  scope = "stage table; constrains how runtime.h / runtime.o changes propagate across the bootstrap chain"

@X x_agents_tape := "AGENTS.tape" :: governance [active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/AGENTS.tape"
  scope = "registers this file as sibling doctrine (cross-link only — no governance edit required)"
