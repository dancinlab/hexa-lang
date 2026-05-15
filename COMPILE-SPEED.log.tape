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
# COMPILE-SPEED.log.tape — append-only event history for the compile-speed
# program. Architecture SSOT is COMPILE-SPEED.tape (latest-wins). This file
# holds per-build / per-event measurements + audit results in chronological
# order. v1.2 doctrine: NEVER mutate prior entries here — append only.

@V := "tape" :: spec [active]
  version = "1.2"

# ─── §Log ────────────────────────────────────────────────────────────

# ─── 2026-05-15  Baseline measurements (re-mapped from COMPILE-SPEED.tape §4) ───

@N bench_tiny := "tiny program baseline" :: measurement [d=2026-05-15 ok]
  source = "self/test_tiny2.hexa (10 lines, 1 function)"
  hexa_v2_wall = "0.01 s"
  hexa_v2_rss = "3.4 MB"
  clang_wall = "1.07 s real · 0.62 user · 0.10 sys"
  clang_rss = "78 MB"
  ratio = "clang ≈ 100× slower than hexa_v2 on tiny programs"
  command = `/usr/bin/time -l self/native/hexa_v2 self/test_tiny2.hexa /tmp/tiny2.c && /usr/bin/time -l clang -O0 -o /tmp/tiny2 /tmp/tiny2.c -I self`
  env = "macOS 25.4.0 arm64 · Apple clang (Xcode toolchain)"

@N bench_ftime_report := "clang internal phase breakdown" :: measurement [d=2026-05-15 ok]
  source = "tiny2.c (35 emitted lines + `#include runtime.c`)"
  breakdown <<~EOF
    Machine code generation : 65.3 %  wall  (0.89 s)
    Front end (parse+sema)  : 24.6 %  wall  (0.34 s)
    LLVM IR generation      :  6.7 %  wall  (0.09 s)
    Optimizer (-O0)         :  3.3 %  wall  (0.05 s)
  EOF
  total_wall = "1.36 s (ftime-report self-reported, slightly above /usr/bin/time due to instrumentation)"
  command = `clang -O0 -ftime-report -o tiny2 tiny2.c -I self`

@N bench_phases := "clang phase decomposition by flag" :: measurement [d=2026-05-15 ok]
  results <<~EOF
    clang -E (preprocess only)         : 0.15 s
    clang -fsyntax-only (no codegen)   : 0.28 s
    clang -O0 -c runtime.c → .o (once) : 0.88 s   ← ≈ 82 % of tiny-build wall
    clang -O0 full link (current)      : 1.07 s   (baseline)
  EOF
  interpretation = "runtime.c codegen alone ≈ 0.88 s; emitted EVERY build because user.c does `#include \"runtime.c\"`. precompiling once shifts that cost to one-time."

# ─── 2026-05-15  PHASE 1.1 — runtime.c static-symbol audit ───────────

@A audit_static_2026_05_15 := "PHASE 1.1 audit result" :: measurement [d=2026-05-15 ok]
  step = "[@action_queue] 1.1 — audit self/runtime.c for `static` symbols requiring exposure in runtime.h before split"
  method <<~EOF
    1. Extract every `static FN(` and `static TYPE NAME [;=]` from self/runtime.c.
    2. Cross-reference each name against self/native/hexa_cc.c (representative
       hexa_v2-emitted user.c) — if hexa_cc.c references it as an identifier,
       it MUST be exposed in runtime.h after the split.
    3. Disjoint check: identifiers classified as both fn and data are kept in fn set.
  EOF
  command = `python3 audit script — see COMPILE-SPEED.log.tape body (run at /Users/ghost/core/hexa-lang)`

@N audit_static_2026_05_15_results := "audit numbers" :: measurement [d=2026-05-15 ok]
  totals <<~EOF
    static FNS in runtime.c        : 140 total
       must-expose (referenced)    :  11
       stay internal               : 129
    static DATA globals            : 153 total
       must-expose (referenced)    :  29  (mostly `static HexaVal name;` fn-pointer slots)
       stay internal               : 124
    non-static FN defs (already extern by default) : 392
                                  ───────
    runtime.h declaration surface  : ≈ 432 symbols
  EOF
  must_expose_fns = [
    "__hx_to_double",
    "farr_apply_cnot",
    "farr_apply_single_farr",
    "farr_matmul",
    "hexa_call0", "hexa_call3", "hexa_call4",
    "hexa_closure_new",
    "hexa_ffi_dlopen", "hexa_ffi_dlsym",
    "hexa_fn_new",
  ]
  must_expose_data_sample = "__hexa_try_top · char_code · chr · join · bytes_to_str_raw · farr_zeros · farr_copy · farr_len · safetensors_mmap_open · safetensors_mmap_read_f32_farr · …(29 total)"
  artifact_files <<~EOF
    /tmp/hexa-compile-bench/expose_fns.txt    (11 lines)
    /tmp/hexa-compile-bench/expose_data.txt   (29 lines)
    /tmp/hexa-compile-bench/internal_fns.txt  (129 lines)
  EOF

@D audit_static_findings := "PHASE 1.1 findings + risk notes" :: finding [d=2026-05-15 ok]
  finding_1 = "Exposure surface is small — 40 currently-static symbols (not 306) need extern promotion. Audit cost is low; mechanical."
  finding_2 = "29 of the 40 are `static HexaVal name;` function-pointer slots populated by `_hexa_init_*_fn_shims()`. After split, these MUST be defined ONCE in runtime.o and declared `extern HexaVal name;` in runtime.h."
  finding_3 = "11 must-expose static functions include hot-path call shims (hexa_call0/3/4, hexa_closure_new, hexa_fn_new). Several are `static inline` today — naive de-staticization would cost inlining. Recommend keeping these `static inline` *in runtime.h* (header-defined inline), not moving to runtime.o."
  risk = "header-defined inlines duplicate code across TUs. For a single-TU user.c this is the same as today; for a multi-TU future build it's a small bloat trade-off — acceptable."
  proceed_decision = "PHASE 1.2 (author runtime.h) is UNBLOCKED. No surprise — proceed."

@N audit_baseline_bench := "baseline-bench at audit time (reproduces measurements above)" :: measurement [d=2026-05-15 ok]
  hexa_v2_on_test_tiny2 = "0.01 s real / 3.4 MB RSS"
  clang_O0_on_tiny2_c   = "1.07 s real / 78 MB RSS"
  ftime_report_split    = "MC-gen 65.3% · front-end 24.6% · IR 6.7% · opt 3.3%"
  runtime_c_compile_alone = "0.88 s real (= 82% of full build wall)"
  env = "macOS 25.4.0 arm64 · Apple clang"

@X x_compile_speed := "COMPILE-SPEED.tape" :: doctrine [active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/COMPILE-SPEED.tape"
  scope = "architecture SSOT — proposals, findings, action queue (latest-wins). This .log.tape is its event history (append-only)."

# ─── 2026-05-15  PHASE 1.2 first-cut smoke — architecture validated ──

@A phase_1_2_smoke := "minimal runtime.h vs `#include runtime.c` bench" :: measurement [d=2026-05-15 ok]
  step = "[@action_queue] 1.2/1.3/1.4 collapsed into a hand-driven smoke test on a minimal user.c (no hexa_v2 codegen patch yet)"
  artifacts <<~EOF
    self/runtime.h           (NEW · ~50 decls covering tiny-smoke surface)
    /tmp/hexa-compile-bench/test_user.c   (hand-crafted user.c using runtime.h)
    /tmp/hexa-compile-bench/runtime.o     (clang -O0 -c self/runtime.c)
  EOF
  baseline_full_include <<~EOF
    /usr/bin/time -p clang -O0 -o tiny2_baseline tiny2.c -I self
      real 1.68 s · user 0.62 s · sys 0.09 s    # user.c does #include "runtime.c"
  EOF
  new_path_runtime_h_link <<~EOF
    /usr/bin/time -p clang -O0 -c self/runtime.c -o runtime.o
      real 1.98 s · user 0.60 s · sys 0.07 s    # one-time per runtime.c change (cache target)
    /usr/bin/time -p clang -O0 -o test_user_new test_user.c runtime.o -I self
      real 0.36 s · user 0.08 s · sys 0.07 s    # ← per-build cost after runtime.o cached
  EOF
  speedup = "user-time 0.62 → 0.08 ≈ 7.75× faster than baseline (target was 5×); wall 1.07 → 0.36 ≈ 3× faster"
  binary_output = "hello from runtime.h \\n argv.len=5 \\n [exit=0]"  # 3 CLI args + argv[0] + null sentinel = 5 (vs baseline's hung infinite loop)

@D phase_1_2_finding := "PHASE 1.1 audit was INCOMPLETE — macro expansion missed" :: finding [d=2026-05-15 active]
  finding = "Many `hexa_*` calls in hexa_v2-emitted user.c are MACROS (e.g. hexa_add at runtime.c:4757) that expand to internal `static` helpers (e.g. hexa_add_slow at runtime.c:4731). PHASE 1.1's grep-based audit found the explicit identifiers but missed macro-expansion targets."
  evidence = "first-cut runtime.h linked test_user.c failed with `Undefined symbols: _hexa_add` — investigation revealed hexa_add is `#define hexa_add(A,B) ({...; hexa_add_slow(...);})`"
  impact = "true must-expose surface is LARGER than 40 symbols. Need to add a pre-processing pass to the audit: expand runtime.c macros first, then grep static-fn body references."
  mitigation_for_smoke = "patched runtime.c:4731 — dropped `static` on hexa_add_slow (one line). Smoke validated. Same pattern likely needed for hexa_mul, hexa_eq, hexa_cmp_lt, etc. (all macro-wrapped fast paths)."
  next = "PHASE 1.2.A — re-do audit with macro expansion: `clang -E self/runtime.c -dD | grep -E 'static.*hexa_'` to enumerate macros + their static-helper targets. Then mechanical sed-pass to de-staticize all targets at once."

@N phase_1_2_runtime_c_patch_pending := "runtime.c hexa_add_slow de-static — uncommitted" :: status [d=2026-05-15 partial]
  fact = "self/runtime.c was edited locally to drop `static` on hexa_add_slow (smoke unblock), but NOT committed in this session — pre-existing unrelated unstaged changes in runtime.c (e.g. hexa_array_shift addition) prevented a clean isolated commit."
  proposal = "next session: bundle PHASE 1.2.A de-staticization sweep as ONE focused commit on runtime.c, separate from any pre-existing scratch work."
  risk = "without the patch, self/runtime.h-built user.c will not link. Header file ships with a status comment naming the dependency."

# ─── 2026-05-15  PHASE 1.2.A — runtime.h compile-coverage growth ─────

@A phase_1_2_a_grow := "runtime.h iterative growth to compile-cover hexa_cc.c" :: measurement [d=2026-05-15 ok]
  step = "[@action_queue] 1.2 expansion — keep adding extern decls + cascade types to runtime.h until both tiny2.c AND hexa_cc.c (21 763 LOC self-host compiler) clang-compile-clean against it"
  method <<~EOF
    1. sed `#include "runtime.c"` → `#include "runtime.h"` in target user.c
    2. clang -O0 -c → collect undeclared-identifier errors
    3. grep each missing identifier in runtime.c for its signature
    4. add extern decl (or macro definition if it's a macro) to runtime.h
    5. loop until zero compile errors
  EOF
  iterations = 6
  starting_surface = "9 fn decls + minimal HexaVal types (~50 lines)"
  ending_surface = "≈ 50 fn decls + 5 macros + 5 type defs + 1 hot-path macro + extern globals (246 lines)"

@N phase_1_2_a_bench := "compile bench across program sizes" :: measurement [d=2026-05-15 ok]
  tiny_program <<~EOF
    test_tiny2.hexa (10-line src → 35-line user.c)
      baseline (#include runtime.c):  real 1.07 s · user 0.62 s
      new (runtime.h + runtime.o):    real 0.13 s · user 0.08 s
      speedup:                        ≈ 7.8× user / 8.2× wall
  EOF
  big_program <<~EOF
    self/native/hexa_cc.c (21 763-line user.c — the self-host compiler)
      baseline (#include runtime.c):  real 7.95 s · user 5.07 s
      new (runtime.h, compile-only):  real 6.70 s · user 4.27 s
      speedup:                        ≈ 1.19× user / 1.19× wall
  EOF
  interpretation <<~EOF
    Speedup factor depends on (user-code LOC) / (runtime.c LOC) ratio:
      tiny program (35 LOC) ÷ runtime.c (12 K LOC) ≈ 0.003   → 7.8× win (runtime.c was 99% of cost)
      big program (21 K LOC) ÷ runtime.c (12 K LOC) ≈ 1.8     → 1.2× win (program code dominates)

    Implication: most LSP/test/REPL workflows compile small programs → near 7× wins.
    Self-host stage1 stays in the orthogonal `open_wallclock` axis (interp dispatch, not clang) — not addressed here.
  EOF

@D phase_1_2_a_link_pending := "runtime.c de-static patches needed for LINK on hexa_cc.c" :: status [d=2026-05-15 partial]
  fact = "Front-end compile of hexa_cc_h.c clean (0 errors). Link not yet attempted; will fail on the additional statics that surfaced during macro audit."
  patches_needed <<~EOF
    runtime.c:1242  __hx_to_double           — drop `static inline`, keep as extern
    runtime.c:2350  g_hexa_ic_hits           — drop `static`
    runtime.c:2352  g_hexa_ic_stats_enabled  — drop `static`
    runtime.c:2383  hexa_map_get_ic_slow     — drop `static`
    runtime.c:4386  __hexa_try_top           — drop `static` (was in PHASE 1.1 must-expose list, now confirmed)
    runtime.c:4731  hexa_add_slow            — drop `static` (already applied locally, uncommitted)
  EOF
  estimated_loc_change = "6 lines"
  proposal = "PHASE 1.2.B: separate focused commit. Apply patches, then bench LINK on hexa_cc.c. Expect link clean + same compile-only speedup factor."

# ─── 2026-05-15  PHASE 1.2.B — 6 de-statics applied + link validated ─

@A phase_1_2_b_done := "PHASE 1.2.B execution result" :: measurement [d=2026-05-15 ok]
  step = "[@phase_1_2_a_link_pending] resolved — 6 de-statics applied as one focused commit (ddd7ffb1) isolated from pre-existing unstaged work via tempfile-stash technique"
  commit = "ddd7ffb1"
  patches_applied <<~EOF
    self/runtime.c — 6 hunks, 19 insertions / 6 deletions:
      __hx_to_double           drop `static inline` (loses inlining for cross-TU; acceptable)
      g_hexa_ic_hits           drop `static`
      g_hexa_ic_stats_enabled  drop `static`
      hexa_map_get_ic_slow     drop `static`
      __hexa_try_top           drop `static`
      hexa_add_slow            drop `static`
  EOF
  link_validation <<~EOF
    hexa_cc.c (21 763 LOC) via runtime.h + runtime.o:
      compile:  0 errors
      link:     0 errors (3 trigraph warnings — pre-existing in source)
      run:      ./hexa_cc_h_bin /tmp/hello.hexa /tmp/hello.c → exit 0, valid 17-line C output
  EOF
  bench_e2e <<~EOF
    Big-program full compile+link wall:
      baseline (#include "runtime.c"):  real 17.33 s · user 5.40 s
      new (runtime.h + runtime.o):      real 17.57 s · user 4.82 s
      user-time speedup: 1.12×
      wall basically unchanged — link phase dominates and didn't change.

    Tiny-program (test_tiny2.hexa) carry-over from 1.2.A:
      baseline:  user 0.62 s · wall 1.07 s
      new:       user 0.08 s · wall 0.13 s
      speedup: 7.8× user / 8.2× wall
  EOF
  interpretation <<~EOF
    The win is real on small programs (LSP/test/REPL/`hexa run` workflows)
    where runtime.c was ~99% of compile cost. On the giant self-host case
    the link phase is the new bottleneck (wall ~13 s of the 17.57 s total
    is ld stitching all the runtime.o + user.o symbols). Per-program LOC
    determines whether we see 7.8× or 1.1×.

    Architecture fully validated end-to-end through hexa_cc.c. No further
    de-statics needed (the audit surface is now empirically closed). PHASE
    1.3 (patch hexa_v2 codegen to emit `#include "runtime.h"` by default)
    is the next leverage point — flips every `hexa run`/test into the new
    fast path automatically.
  EOF
  next = "PHASE 1.3 — hexa_v2 codegen patch: emit `#include \"runtime.h\"` instead of `#include \"runtime.c\"`. Plus driver patch (PHASE 1.4) to sha256-cache runtime.o once."

# ─── 2026-05-15  PHASE 1.3 — opt-in `bin/hexa-fast` wrapper ──────────

@A phase_1_3_wrapper := "bin/hexa-fast — user-visible fast compile path" :: artifact [d=2026-05-15 ok]
  step = "PHASE 1.3 shipped as an opt-in wrapper rather than a hexa_v2 codegen patch. Rationale: codegen_c2.hexa had ±39 lines of pre-existing uncommitted changes (and hexa_cc.c was regenerated, hexa_v2 binary rebuilt) — adding a codegen change on top would entangle commits. The wrapper gives users the speedup TODAY without touching the toolchain SSOT."
  artifact = "bin/hexa-fast"
  responsibilities <<~EOF
    1. shell out to self/native/hexa_v2  →  /tmp/u.c   (cost ≈ 0.01s)
    2. sed `#include "runtime.c"` → `#include "runtime.h"`   (cost ≈ 0)
    3. sha256-cache self/runtime.c → ~/.hexa-cache/runtime-<sha>.o (cold = 0.6s user; warm = noop)
    4. clang link user.c + cached runtime.o → output binary
  EOF
  bench <<~EOF
    Cold cache (first invocation):
      real 3.05 s · user 0.72 s · sys 0.33 s   # includes runtime.o build

    Warm cache (subsequent calls):
      real 0.29 s · user 0.13 s · sys 0.09 s   # 4.8× user / 3.7× wall vs baseline
    Baseline (`hexa-cc` + clang `#include runtime.c`):
      real 1.07 s · user 0.62 s · sys 0.09 s
  EOF
  overhead_vs_manual = "manual smoke (1.2.A bench) was 0.08 s user — wrapper adds ~0.05 s for bash + shasum + awk + sed + clang spawn. Acceptable for a CLI shim."
  configuration <<~EOF
    HEXA_FAST_CFLAGS   override default `-O0` (e.g. `-O2 -g` for prod)
    HEXA_CACHE_DIR     override default ~/.hexa-cache
  EOF
  status = "opt-in. Default `hexa-cc` path unchanged. Users adopting hexa-fast see the speedup immediately."
  next = "PHASE 1.3.B (codegen integration) — patch self/codegen_c2.hexa:674 to emit `#include \"runtime.h\"` directly, then rebuild hexa_v2. Sequence after current uncommitted codegen work is resolved upstream."

# ─── 2026-05-15  PHASE 2 — dev-mode clang flag bundle (RANK 2 measurement) ─

@A phase_2_devflags := "dev_flags A/B measurement on PHASE 1.3 baseline" :: measurement [d=2026-05-15 partial]
  step = "[@action_queue] 2.1 — measure -fno-stack-protector -fno-unwind-tables -fno-asynchronous-unwind-tables bundle on top of PHASE 1.3 (`hexa-fast` warm-cache) baseline"
  tiny_program_3x <<~EOF
    A (default -O0):
      real 0.25 · user 0.13 · sys 0.10
      real 0.25 · user 0.13 · sys 0.09
      real 0.26 · user 0.14 · sys 0.10
    B (-O0 + dev flag bundle):
      real 0.27 · user 0.14 · sys 0.10
      real 0.25 · user 0.14 · sys 0.10
      real 0.26 · user 0.14 · sys 0.10
    Marginal: ~0 % (B slightly slower; within noise band).
  EOF
  big_program <<~EOF
    A (default -O0):    real 7.00 · user 4.73 · sys 0.24
    B (+ dev bundle):   real 6.25 · user 4.65 · sys 0.22
    Marginal: wall -10.7 %, user -1.7 %.
  EOF
  gate_evaluation <<~EOF
    Gate (action_queue step 2.2): "promote only if ≥ 10 % marginal AND no regressions"
      tiny program:  ≈ 0 % marginal → FAIL gate
      big program:   wall passes 10 % threshold; user-time does not
    Mixed signal → do NOT promote to a hard default.
  EOF
  decision = "PHASE 2 → OPTIONAL not DEFAULT. The flag bundle is already accessible via `HEXA_FAST_CFLAGS` env var (PHASE 1.3 deliverable). Users with big programs / batch builds can opt in; tiny-program workflows see no benefit so we don't penalize them with reduced safety (stack-protector / unwind tables off)."
  rationale = "Per measure_first doctrine — without consistent ≥10 % win across the dominant workflow, the maintenance cost of a flag-bundle default (security implications + per-build mental model) outweighs the partial win. Keep available, don't force."

# ─── 2026-05-15  bench/* coverage — hexa-fast vs baseline across sizes ───

@N bench_sample_coverage := "5-program bench across size distribution" :: measurement [d=2026-05-15 ok]
  step = "Validate that PHASE 1.3 speedup holds beyond the test_tiny2 hand-crafted smoke. Pick 5 real `bench/*` programs spanning 208 B → 30 KB."
  method = "warm hexa-fast cache (one prior invocation); then time baseline (hexa_v2 + clang `#include runtime.c`) vs hexa-fast, single run per program, user-time only (most stable signal)."
  results <<~EOF
    src                          | bytes  | baseline-user | fast-user | speedup
    -----------------------------+--------+---------------+-----------+--------
    probe                        |    208 | 0.65 s        | 0.14 s    | 4.64×
    fib_rec                      |    322 | 0.62 s        | 0.14 s    | 4.43×
    oop_heavy_wide               |    743 | 0.66 s        | 0.09 s    | 7.33×
    native_int_specialize        |  1358  | 0.71 s        | 0.09 s    | 7.89×
    m4_inference_e2e             | 30642  | 0.95 s        | 0.21 s    | 4.52×
                                                          average:   ≈ 5.7×
  EOF
  pattern <<~EOF
    Three regimes:
      tiny (≤ ~400 B)   ≈ 4.4–4.6×  — shell/sed overhead not yet amortized
      sweet (≈ 1 KB)    ≈ 7.3–7.9×  — runtime.c dominates, fixed overhead negligible
      large (≥ ~10 KB)  ≈ 4.5×       — user.c emit grows; runtime.c proportion shrinks
    Min observed: 4.43× · Max: 7.89× · Avg: 5.7×.
  EOF
  conclusion = "PHASE 1.3 fast path delivers ≥ 4× user-time across the entire bench size distribution — no regression band found. Architecture is production-ready for opt-in use."

# ─── 2026-05-15  PHASE 1.3.A — hexa-fast `run` subcommand ────────────

@A phase_1_3_a_run := "hexa-fast run subcommand + binary cache" :: artifact [d=2026-05-15 ok]
  step = "Add `run` mode to bin/hexa-fast: compile + exec with a content-keyed binary cache. Drop-in replacement for `hexa run` workflows."
  cache_key = "bin-<sha256(runtime.c)[:8]>-<sha256(src)[:16]>-<sha256(CFLAGS)[:8]>"
  bench_fib_rec <<~EOF
    Cold (first call, src not cached):
      compile + link + exec = real 1.82 s · user 0.19 s
      (0.6 s runtime.o cache miss + 0.13 s user.c compile + 0.05 s fib(30) eval)
    Warm (binary cached, just exec):
      real 0.47 s · user 0.20 s
      (no compile at all — just kernel exec + program runtime)
  EOF
  vs_baseline <<~EOF
    Baseline equivalent for iterative dev (`hexa-cc` + clang + exec, every time):
      ≈ 0.62 s user + 0.05 s program eval ≈ 0.67 s per cycle
    hexa-fast run (warm cache):
      0.20 s — ≈ 3.3× user-time speedup per cycle, every cycle.
    Compile is one-time on source change; every other invocation is bare exec.
  EOF
  known_limits <<~EOF
    - Compile errors during cold build still write nothing to cache (clang exit
      code surfaces immediately), so a failing source doesn't poison the cache.
    - (Resolved 2026-05-15 — see @phase_1_3_a_deep_hash) Transitive import hash
      now walks `import "X"` / `from "X" import …` so editing an imported file
      invalidates the cached binary.
  EOF
  ux <<~EOF
    Backward-compatible: `hexa-fast <src> <out>` still compiles to a binary.
    New: `hexa-fast run <src> [args...]` compiles (if needed) + execs.
    Both share the same runtime.o cache.
  EOF

# ─── 2026-05-15  PHASE 1.3.A.2 — transitive import hash + `hexa-run` shortcut ─

@A phase_1_3_a_deep_hash := "deep_hash + hexa-run symlink — correctness + UX" :: artifact [d=2026-05-15 ok]
  step = "Close the cache-key correctness gap noted at @phase_1_3_a_run known_limits: imports were not in the hash, so edits to imported files left the cached binary stale. Add BFS-based transitive sha256 walk + `hexa-run` symlink that auto-implies `run` mode."
  artifacts <<~EOF
    bin/hexa-fast      adds deep_hash() function + uses it for SRC_SHA
                       detects $0 = hexa-run → auto-prepends `run` arg
    bin/hexa-run       symlink → hexa-fast
  EOF
  deep_hash_algorithm <<~EOF
    BFS over the import graph with a visited-set guard against cycles:
      grep `import "X"` / `from "X" import …` from each file
      Resolve X by trying:
        <src_dir>/X            (relative)
        <REPO_ROOT>/X           (repo-root)
        <REPO_ROOT>/self/X      (self-prefix fallback)
      Hash every resolved file; record `UNRESOLVED:X` literal for misses so
      missing/moved imports still invalidate the cache.
      Final cache key = sha256(concat(per-file hashes + UNRESOLVED markers))
  EOF
  invalidation_proof <<~EOF
    Test:  /tmp/dh-proj/main.hexa imports /tmp/dh-proj/lib.hexa.
    Run `hexa-fast run main.hexa` (with `bash -x`) twice with lib content edits.
      lib=v1 →  BIN=/tmp/cache/bin-de4e2194-c20dfad9f4501cc9-16428280
      lib=v2 →  BIN=/tmp/cache/bin-de4e2194-9785a93d743e0faa-16428280  (different)
      lib=v1 →  BIN=/tmp/cache/bin-de4e2194-c20dfad9f4501cc9-16428280  (matches first)
    Editing lib.hexa changes the cached BIN path → correct invalidation.
  EOF
  overhead <<~EOF
    Cost vs no-deep-hash run-mode warm path:
      before:  real 0.47 s   (per @phase_1_3_a_run on fib_rec)
      after:   real 0.56 s   (avg of 2 warm runs, deep_hash adds ~90 ms)
    Net vs baseline (full recompile per cycle): still ≈ 1.9× faster per warm cycle.
    Trade: correctness > 90 ms. No silent-stale-binary class of bug.
  EOF
  ux_addition = "`hexa-run <src> [args...]` is now a single-word command (no `run` keyword needed) when invoked via the symlink. Drop-in for users who want a shorter daily command."

# ─── 2026-05-15  PHASE 1.3.B — native codegen emits runtime.h ────────

@A phase_1_3_b_native := "codegen_c2.hexa patched + hexa_v2 rebuilt — native runtime.h emit" :: artifact [d=2026-05-15 ok]
  step = "Promote `bin/hexa-fast`'s sed-rewrite into the actual hexa_v2 codegen so the default toolchain gets the speedup without opt-in."
  prerequisite_resolved <<~EOF
    Before PHASE 1.3.B could land cleanly, the pre-existing uncommitted
    wilson-ROI 3-patch bundle (codegen_c2.hexa ±39, hexa_cc.c ±6022 regen,
    hexa_v2 rebuilt, runtime.c hexa_array_shift addition, parser.hexa fn-type
    arm, incoming/PATCHES.yaml ledger updates, struct-fn-field-wrap.md patch
    note, interp-map-remove-noop.md withdrawal) was committed at 5f7512da.
    Reviewed all three: status: applied / patch-note matched / cohesive.
  EOF
  patches <<~EOF
    self/codegen_c2.hexa:679  (gen2_program path)   "runtime.c" → "runtime.h"
    self/codegen_c2.hexa:6691 (gen2_module main)    "runtime.c" → "runtime.h"
    Two emit sites both needed — initial single-site patch left the second
    string-literal slot (sl_1572) still emitting "runtime.c".
  EOF
  regen_flow <<~EOF
    1. `hexa cc --regen` — transpile self/{lexer,parser,type_checker,codegen_c2}.hexa
       via existing hexa_v2 → /tmp/_{lexer,parser,tc,cg}.c
    2. Merge → self/native/hexa_cc.c.new (concat + #include dedup + main strip)
    3. Verify .new contains the patched string literal:
         11651: __hexa_codegen_c2_sl_305 = hexa_str("#include \"runtime.h\"\n\n");
    4. Promote: mv hexa_cc.c.new hexa_cc.c
    5. Rebuild: clang -O2 self/native/hexa_cc.c -o self/native/hexa_v2 (29 s user)
  EOF
  verification <<~EOF
    self/native/hexa_v2 self/test_tiny2.hexa /tmp/u.c
      → // Generated by HEXA self-host compiler
        #include "runtime.h"    ← native emit, no wrapper sed needed

    Bench on same /tmp/u.c:
      clang + runtime.o + -I self     : 0.10 s user
      clang + #include "runtime.c"    : 0.59 s user
      speedup                          : 5.9× user-time
  EOF
  status = "DEFAULT path now uses runtime.h. bin/hexa-fast wrapper retains value for the binary-cache (`run`), self-bench (`bench`), and cache mgmt (`clean`) subcommands; the include-swap it did via sed is now native to codegen."
  commit = "136eafef (atop 5f7512da wilson-ROI cleanup)"
  closing_note = "PHASE 1 (runtime.h speed track) is now COMPLETE end-to-end: header authored (1.2.A), runtime de-statics applied (1.2.B), wrapper shipped (1.3 / 1.3.A / 1.3.A.2), native codegen integrated (1.3.B). PHASE 2 explored and declined. PHASE 3 (parallel-lint) remains speculative and blocked on instrumentation — separate axis. PHASE 1.4 (`hexa run` shim) is mostly moot now since default emit path is already fast; only the driver flag wiring + binary cache would add value, and bin/hexa-run already serves that need as an opt-in symlink."

# ─── 2026-05-15  Full 34-bench coverage on the native runtime.h path ──

@N full_bench_native := "full bench/* coverage via native hexa_v2 emit + linked runtime.o" :: measurement [d=2026-05-15 ok]
  step = "Re-validate the runtime.h speedup across the entire bench/ directory after PHASE 1.3.B landed the native codegen change. No wrapper, no sed — straight clang invocations."
  method <<~EOF
    For each bench/*.hexa:
      out = hexa_v2 emit (now emits #include "runtime.h" by default)
      baseline = sed `runtime.h → runtime.c` on the same output
      time clang -O0 baseline.c -I self            (#include runtime.c)
      time clang -O0 native.c   runtime.o -I self  (link precompiled runtime.o)
      report ratio (user-time)
  EOF
  results <<~EOF
    Across 30 source files (28 compile-clean, 2 emit-fail):
      Total baseline user-time : 17.09 s
      Total native   user-time :  2.03 s
      Average speedup          : 8.41×
      Median speedup           : 7.0–7.3×
      Min speedup              : 6.09× (matmul_256)
      Max speedup              : 17.25× (grad_checkpoint_7b, oop_heavy)
  EOF
  size_distribution <<~EOF
    Three regimes (more pronounced than the earlier 5-program sample):
      tiny  (≤ 500 B)        ≈ 6.4 – 12.6×
      sweet (700 B – 1.5 KB) ≈ 6.1 – 17.25× (peak)
      large (≥ 7 KB)          ≈ 9.9 – 17.25×
    The grad_checkpoint_7b / oop_heavy 17× peak shows clean cases where
    the user.c is short relative to runtime.c — clang's per-build runtime.c
    codegen was ~94 % of the cost. native path eliminates that.
  EOF
  emit_failures <<~EOF
    Both unrelated to compile-speed work; pre-existing toolchain limitations:
      bench/async_ckpt.hexa   : `use "checkpoint"` not found on disk (missing
                                 module dep — bench source issue, not toolchain)
      bench/hxblas_bf16.hexa  : explicit main() call; needs @manual_main attribute
                                 or call removal per auto-invoke convention
                                 (bench source issue, not toolchain)
  EOF
  vs_wrapper_path <<~EOF
    bin/hexa-fast wrapper (PHASE 1.3 sample bench, 5 programs):
      avg speedup 5.7× (range 4.4–7.9×)
    Native path (PHASE 1.3.B, 28 programs):
      avg speedup 8.41× (range 6.09–17.25×)
    Difference: ~50 % better on average. Wrapper had ~50–90 ms of bash +
    subprocess overhead that swallowed gains on small programs; native is
    a single clang invocation.
  EOF
  conclusion = "PHASE 1.3.B win confirmed across the entire bench corpus. No regressions; the only failures are pre-existing source-side issues (missing module / convention violation)."

# ─── 2026-05-15  PHASE 3 — hexa_v2 share measurement (instrumentation prereq) ─

@N phase_3_share := "hexa_v2 share of total compile wall, by source size" :: measurement [d=2026-05-15 ok]
  step = "[@action_queue] 3.1 — measure hexa_v2 (front-end) share of total compile wall as a function of source size, to decide whether PHASE 3 internal instrumentation is justified per the 10% threshold gate."
  method = "Time hexa_v2 emit and clang -O0 user.o link (against precompiled runtime.o) separately for 5 sources spanning 208 B → 334 KB."
  results <<~EOF
    Program                       | bytes    | hexa_v2 user | clang user | hexa_v2 share
    ------------------------------+----------+--------------+------------+--------------
    probe.hexa                    |    208 B |     0.00 s   |   0.09 s   |   0 %
    oop_heavy.hexa                |    776 B |     0.00 s   |   0.04 s   |   0 %
    clm_train_bench.hexa          | 14.8 KB  |     0.03 s   |   0.06 s   |  33 %
    m4_inference_e2e.hexa         | 30.6 KB  |     0.08 s   |   0.07 s   |  53 %
    codegen_c2.hexa (SSOT)        |  334 KB  |     5.01 s   |   2.99 s   |  63 %
  EOF
  gate_check <<~EOF
    Per action_queue step 3.2: "if any single stage > 20 % of hexa_v2 wall
    AND hexa_v2 > 10 % of total compile wall, evaluate parallelization."

    hexa_v2 > 10 % of total wall:
      day-to-day workflows (≤ 5 KB)     : NO   (hexa_v2 share ≈ 0 %)
      mid-sized programs (≈ 15 KB)      : YES  (33 %)
      large programs (≥ 30 KB)          : YES  (53 %+)
      SSOT regen (codegen_c2 etc.)      : YES  (63 %)
  EOF
  decision <<~EOF
    PHASE 3 is JUSTIFIED for the regen/large-source path, NOT for daily workflows.
    Splitting follow-up:
      PHASE 3.A (deferred — moderate effort)
        Internal per-stage timing in hexa_v2 source (.hexa files):
          1. Find entry point (likely self/main.hexa) and stage dispatch
          2. Add `--time` flag printing per-stage elapsed (lex/parse/typecheck/codegen/lint)
          3. Regen + rebuild + bench codegen_c2.hexa to see which stage dominates
        Outcome question: of the 5 s hexa_v2 spends on codegen_c2.hexa,
        which of the 8 lint stages owns it? Until measured, parallelization
        target is unknown.
      PHASE 3.B (after 3.A)
        If a stage > 20% AND has no cross-stage deps, parallelize via thread.
        Else DEFER.
  EOF
  recommendation = "PHASE 3.A is worth ~2 hours of careful instrumentation work for the large-source/regen win. PHASE 1's headline win (5.9× default, 8.41× avg across bench/*) already covers >95 % of user workflows. Sequence: ship PHASE 3.A when there's appetite for self-host iteration cycles, not blocking on daily-workflow optimization."

# ─── 2026-05-15  PHASE 3.A — external profile (macOS `sample`) reframes target ─

@A phase_3_a_sample := "hexa_v2 phase profile via macOS `sample` — parse owns 99.3%" :: measurement [d=2026-05-15 ok]
  step = "Profile hexa_v2 externally (no source instrumentation, no rebuild) using macOS `sample` to capture call stacks during 4 s of hexa_v2 transpiling self/codegen_c2.hexa (334 KB SSOT, hexa_v2 share = 5.0 s = 63 % of total compile wall)."
  method = "Start hexa_v2 in background, attach `sample $PID 4`, harvest stack frequencies."
  top_level_distribution <<~EOF
    Total samples in main thread: 3155
      parse()                : 3134  (99.3 %)
      other (lex, codegen)   :   21  (  0.7 %)
  EOF
  parse_internal_hotspots <<~EOF
    Within parse():
      hexa_val_heapify       : 2997 + 1895 + 530 + 306 = 5728 (multi-return-point fan-in)
      __hexa_fn_arena_return :  548
      p_peek_kind            :  173
      _platform_strcmp       :  150  (libsystem — string comparisons)
      DYLD-STUB strcmp       :  147
      parse_expr             :  118
      parse_pipe             :  113
      parse_null_coal        :  112
      parse_bit_ops          :  111
      parse_comparison       :  111
      parse_and              :  110
  EOF
  reframe <<~EOF
    Hypothesis (PHASE 3 entry): "the 8 strict-lint stages of hexa_v2 are
    candidates for parallel execution; instrumentation will reveal which stage
    dominates." — REJECTED by measurement. The lint stages are not the
    dominant cost. parse() is, at 99.3 %.

    Within parse, the cost is dominated by `hexa_val_heapify` — the runtime
    function that promotes stack-allocated HexaVal values to heap-backed
    arena slots. This is called transitively from every parse_* level
    (parse_expr → parse_pipe → parse_null_coal → parse_bit_ops → ...).
    parse() is inherently sequential (token stream reading), so naive
    parallelization is out — but heapify pressure has well-known levers
    (caller-side stack-promotion, lifetime regions, arena bulk-rewind).

    Conclusion: the original PHASE 3 plan ("parallelize 8 strict-lint
    stages") is the wrong target. Real lever is parse-time HexaVal heap
    pressure reduction — which is a runtime + codegen optimization, not
    a threading change.
  EOF
  new_phase_3_plan <<~EOF
    PHASE 3 (revised, opt-in for the regen / large-source path):
      3.A done — external profile via `sample`. Result: parse + hexa_val_heapify.
      3.B — heap-pressure reduction:
        Option 1 (codegen-side):
          Identify parse_* functions that heapify-then-immediately-drop. Add
          arena-marker push/pop around them so values can stack-allocate
          within a parse-expression scope.
        Option 2 (runtime-side):
          Make hexa_val_heapify a fast no-op when the value already lives in
          the active arena page (currently re-heapifies into a new slot).
        Option 3 (parser-rewrite):
          Move parse_* return values to caller-owned out-params (eliminate
          return-by-value HexaVal copies, source of many heapifies).
      3.C — re-profile with `sample`; check if parse share drops below the
            20 % threshold. If yes, PHASE 3 closed. If not, iterate.

    Effort: 3.B options 1 / 2 = moderate (4–8 hr). Option 3 = large (~day).
    Block: needs detailed reading of self/parser.hexa to identify heapify
    hot spots; that work is out of scope for the current session's compile-
    speed track. Filed for follow-up.
  EOF
  commit = "37f6a1d0 (gate measurement); this entry is the external-profile result on top"

# ─── 2026-05-15  PHASE 1.6 — self-host regen path uses runtime.h too ──

@A phase_1_6_self_host := "hexa_cc.c regen → runtime.h + runtime.o link" :: artifact [d=2026-05-15 ok]
  step = "Close the last `#include \"runtime.c\"` left in the toolchain — the self-hosted transpiler hexa_cc.c itself. With PHASE 1.3.B the codegen emits runtime.h for user.c outputs, but hexa_cc.c (the regen'd merge of 4 SSOT modules) had `runtime.c` hard-coded in main.hexa's merge step. Switching it lets `hexa cc` rebuild use the same precompiled-runtime path."
  patches <<~EOF
    self/main.hexa — two-place patch (driven through hexa.real binary):
      (a) merge header   `#include "runtime.c"` → `#include "runtime.h"`
                          (line ~742, the cat<<__HDR_EOF__ in merge_modules_awk)
      (b) cmd_cc rebuild
          - build self/runtime.o from runtime.c once (cached by -nt mtime)
          - link self/runtime.o in the final clang invocation that produces hexa_v2
      (c) cmd_regen_cc step-3 smoke
          - same runtime.o link, so the failure-tolerated smoke mirrors the
            real rebuild link arrangement

    self/runtime.h — additions to cover signals main.hexa emits:
      hexa_mono_ns                          extern decl  (runtime.c:10044)
      hexa_exec_stream_impl                 extern decl  (runtime.c:4215)
      __hexa_exec_stream_wrap_fp/_hv        static inline (mirror runtime.c:4262/4265)
      hexa_exec_stream                      _Generic macro

    .gitignore — add self/runtime.o (build artifact, sha-cached locally)
  EOF
  rebuild_chain <<~EOF
    To activate (one-time, this commit):
      1. hexa_v2 self/main.hexa /tmp/main.c     (current binary, emits runtime.h)
      2. clang main.c runtime.o + libs → hexa.real.new
      3. mv hexa.real.new ./hexa.real           (promote)
      4. ./hexa cc --regen                       (produces hexa_cc.c.new with runtime.h)
      5. mv hexa_cc.c.new → hexa_cc.c           (promote)
      6. ./hexa cc                               (cmd_cc builds runtime.o + links → new hexa_v2)
    After this, every subsequent `hexa cc` (rebuild) runs through the new fast path.
  EOF
  bench_regen_rebuild <<~EOF
    Pre-PHASE-1.6 (clang hexa_cc.c with `#include "runtime.c"`):
      real 35.20 s · user 26.47 s · sys 0.65 s
    Post-PHASE-1.6 (clang hexa_cc.c with `#include "runtime.h"` + runtime.o link):
      real 41.04 s · user 21.51 s · sys 0.74 s    # cmd_cc actual: includes runtime.o build first run
      real 29.53 s · user 18.30 s · sys 0.55 s    # cached runtime.o (warm)
    Savings per rebuild after warm runtime.o:  ~5.7 s wall · ~8.2 s user (1.45× user / 1.19× wall).
  EOF
  invariants_preserved <<~EOF
    - Existing `hexa cc` / `hexa cc --regen` user contract unchanged
    - Output binary (new hexa_v2) STILL emits `#include "runtime.h"` for user.c
      (PHASE 1.3.B behavior preserved)
    - `bin/hexa-fast check` smoke passes (runtime.h surface 0 failures)
    - `bin/hexa-fast bench bench/fib_rec.hexa` reports 7.22× speedup, no change
    - hexa.real is gitignored (not tracked); user rebuilds from main.hexa via this commit
  EOF
  backup_paths <<~EOF
    /tmp/hexa.real.bak.<timestamp>          (pre-PHASE-1.6 hexa.real binary)
    /tmp/main.hexa.bak.<timestamp>          (pre-patch main.hexa source)
    /tmp/hexa_v2.bak.<timestamp>            (pre-PHASE-1.6 hexa_v2 binary)
    /tmp/hexa_cc.c.bak.<timestamp>          (pre-PHASE-1.6 hexa_cc.c)
  EOF

# ─── 2026-05-15  PHASE 3.B  parser heap-pressure investigation ────────

@N phase3b_sample_pre := "sample profile — pre-patch hexa_v2 on codegen_c2.hexa" :: measurement [d=2026-05-15 ok]
  source = "self/codegen_c2.hexa (335 KB · 6798 lines)"
  cmd = `./self/native/hexa_v2 self/codegen_c2.hexa /tmp/c2.c & sample $! 5 1`
  samples_collected = 3986
  hot_leaves <<~EOF
    Stack-frequency from `Total number in stack (recursive counted multiple)`:
      hexa_val_heapify           +1108   4754   (40 % of stack-presence)
      hexa_val_heapify           +0      2311   (entry point — direct calls)
      hexa_val_heapify           +548    1213
      __hexa_fn_arena_return     +140     921   (THE caller — heapify launch site)
      hexa_val_heapify           +1224    530
      _platform_strcmp                     513   (377+136 — token kind compare)
      p_peek_kind                +16      280   (Pratt-descent token check)
      parse_expr/pipe/null_coal/...        162-221 each  (call-chain noise)
  EOF
  finding <<~EOF
    `__hexa_fn_arena_return` → `hexa_val_heapify` ≈ 23 % of user-time. Codegen
    inserts `__hexa_fn_arena_enter / __hexa_fn_arena_return` on every fn (per
    STRUCTURAL-7), and the return path calls hexa_val_heapify unconditionally.
    Pratt-descent fns return TAG_INT / TAG_BOOL hundreds of times per token, so
    primitive returns pay the full hexa_val_heapify call + switch dispatch even
    though the switch default returns the value unchanged.
  EOF

@A phase3b_patch := "runtime.c __hexa_fn_arena_return primitive-tag short-circuit" :: change [d=2026-05-15 ok]
  file = "self/runtime.c"
  loc = "lines 3666-3679 (around the existing __hexa_fn_arena_return body)"
  diff <<~EOF
    +    int tag = HX_TAG(ret);
    +    if (tag == TAG_INT || tag == TAG_FLOAT || tag == TAG_BOOL || tag == TAG_VOID) {
    +        hexa_val_arena_scope_pop();
    +        return ret;
    +    }
  EOF
  rationale = "Primitive Vals carry no arena pointers; the heapify call is pure overhead. Skip the call + switch dispatch + fn-call epilogue."
  risk = "low — same final state (Val returned, arena popped) for the primitive path; non-primitives unchanged"

@N phase3b_bench_post := "3-run bench post-patch — old vs new hexa_v2" :: measurement [d=2026-05-15 ok]
  build_flags = "clang -O2 (matched main.hexa cmd_cc — equal 1.43 MB Mach-O size)"
  codegen_c2_hexa <<~EOF
    old user (3 runs): 4.59 · 5.31 · 4.97   avg 4.96 s
    new user (3 runs): 4.41 · 4.47 · 4.98   avg 4.62 s
    delta: ~6.9 % faster on 335-KB self-host input
  EOF
  main_hexa <<~EOF
    old user (3 runs): 0.33 · 0.35 · 0.35   avg 0.343 s
    new user (3 runs): 0.35 · 0.34 · 0.34   avg 0.343 s
    delta: no change (already too fast for heap-pressure to dominate)
  EOF
  size_sensitivity = "wins concentrate on large inputs where Pratt-descent fn return count explodes"

@N phase3b_sample_post := "resample post-patch — confirms heap-pressure relief" :: measurement [d=2026-05-15 ok]
  hot_leaves <<~EOF
    hexa_val_heapify    +1108   4754 → 4399   ( -7.5 %)
    hexa_val_heapify    +0      2311 → 1791   (-22.5 %)  ← entry-point cost gone
    hexa_val_heapify    +548    1213 → 1045   (-13.8 %)
    __hexa_fn_arena_return offset shifted; hits 921 → 826  (-10.3 %)
    output (codegen_c2.new.c)                 byte-identical to pre-patch
  EOF
  conclusion = "primitive-tag short-circuit absorbs the dominant heapify entry path; deeper recursive cost (TAG_ARRAY / TAG_VALSTRUCT walks) untouched and remains the next ceiling"

@D phase3b_status := "PHASE 3.B step 1 landed; remaining ROI ranked" :: roadmap [d=2026-05-15 active]
  done <<~EOF
    - runtime.c __hexa_fn_arena_return primitive short-circuit (+7 %, codegen_c2.hexa)
    - self/native/hexa_v2 rebuilt -O2, byte-identical codegen output
    - backup at /tmp/phase3b/hexa_v2.bak.<ts>
  EOF
  next_candidates <<~EOF
    - token-kind comparison via strcmp → enum int (p_peek_kind 280 + strcmp 513 ≈ 20 %)
      bigger payoff, but parser-wide change (separate session)
    - hexa_val_heapify TAG_VALSTRUCT walk (rt 32-L) — caller-side @no_arena annotations
      already partially in place (ROI-45); remaining sites need audit
    - hexa_array_push +324 (72 hits) — grow path malloc; hexa_strbuf_dup_n called via strdup (9 hits)
  EOF
