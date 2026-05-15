#!/usr/bin/env tape
# COMPILE-SPEED.log.tape — append-only event history for the compile-speed program.
# Architecture SSOT is COMPILE-SPEED.tape (latest-wins). This file holds
# per-event measurements and audit results in chronological order.
# v1.2 doctrine: NEVER mutate prior entries here — append only.

@V := "tape" :: spec [active]
  version = "1.2"

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

@N audit_baseline_bench := "baseline-bench at audit time (reproduces measurements in COMPILE-SPEED.tape §4)" :: measurement [d=2026-05-15 ok]
  hexa_v2_on_test_tiny2 = "0.01 s real / 3.4 MB RSS"
  clang_O0_on_tiny2_c   = "1.07 s real / 78 MB RSS"
  ftime_report_split    = "MC-gen 65.3% · front-end 24.6% · IR 6.7% · opt 3.3%"
  runtime_c_compile_alone = "0.88 s real (= 82% of full build wall)"
  env = "macOS 25.4.0 arm64 · Apple clang"

@X x_compile_speed := "COMPILE-SPEED.tape" :: doctrine [active]
  url = "https://github.com/dancinlab/hexa-lang/blob/main/COMPILE-SPEED.tape"
  scope = "architecture SSOT — proposals, findings, action queue (latest-wins). This .log.tape is its event history (append-only)."
