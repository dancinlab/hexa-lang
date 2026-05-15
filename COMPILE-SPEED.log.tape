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
