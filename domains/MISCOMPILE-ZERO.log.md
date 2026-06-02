# MISCOMPILE-ZERO — log

Append-only history sister of `MISCOMPILE-ZERO.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-06-02 — broad self-emit sweep: 82-program CLEAN-SWEEP (no new miscompile)

Milestone: "broaden the self-emit corpus beyond the compiler flat — exercise
gen2 native codegen on diverse programs, sweep for new miscompiles." Hunted for
LATENT gen2 miscompiles beyond the 6 graduation classes by widening coverage to
a feature-diverse 82-program corpus on GHOST.

- [x] Swept 82 diverse `example/*.hexa` programs through the native gen2 path on
      GHOST (`~/dancinlab/selfhost-work/gen2_fix`, graduated byte-eq compiler).
      Per program: gen2 `--emit=obj` + gen2 `--emit=asm` + oracle
      (`aprime_fixhex`) `--emit=asm` = 246 native compiles. Assert per program:
      rc=0 · 0 ENCODE-MISS · 0 spurious udf · non-empty obj · gen2-asm ==
      oracle-asm after normalizing the benign per-module label hash
      (`__L<hex>_` → `__L_`).
- [x] Feature axes covered: closures/lambda-capture/callbacks · pattern-match +
      dense branch control · recursion + array index/assign (quicksort, sudoku,
      queens, hanoi, ackermann) · float math + format precision (mandelbrot,
      physics, stats) · string ops/methods/encoding (regex, base64, rot13,
      chained methods) · arrays/maps/aggregate (matmul, histogram, json,
      hash_demo) · memoization · structs/records/globals · comptime/builtins ·
      parsers/calculators/state-machines (calc, rpn, bf, mini_transpiler) ·
      text tools (wc/uniq/grep/diff/tree) · self-host lexer/parser ·
      try/catch · ptr arithmetic.
- [x] RESULT = CLEAN SWEEP. 82/82 CLEAN: rc=0, ENCODE-MISS=0, udf=0,
      objsize 1272..25328, oracle-asm MATCH 82/82. The ONLY asm difference
      observed anywhere = the benign 4-hex label hash (e.g.
      `__L18a9_fizzbuzz_bb0` vs `__Lb30b_fizzbuzz_bb0`) — every instruction,
      operand, and basic-block structure identical. NO new miscompile found.
- [x] Pre-registered falsifier (a NEW ENCODE-MISS / udf / non-benign asm
      divergence on any broader program) NOT triggered → strong positive
      result. Verdict persisted verbatim:
      `.verdicts/miscompile-zero-sweep/CLEAN-SWEEP-82.txt` (+ raw
      `results.tsv`, 82 rows).
- [x] Corpus broadened 6 → 10 classes so the gate guards the newly-swept
      surface: `self/test/miscompile_zero/`
        c6_closures          — closures / lambda capture
        c7_recursion_arrays  — recursion + array index/assign (quicksort)
        c8_string_methods    — chained string methods + parse_int builtin
        c9_match_control     — dense branch / control-flow basic blocks
        c10_try_catch        — try / catch / throw landing-pad lowering
      All 10 (c1..c10) PASS the gate on gen2_fix: 10/10 clean, 0 ENCODE-MISS,
      0 udf.
- [ ] follow-up (deferred): random differential-fuzz gen2 vs aprime to surface
      latent miscompiles before users hit them (domain `## deferred`).

## 2026-06-02 — regression guard: lightweight miscompile-zero gate landed

Milestone: "regression guard — a CI gate that fails on ANY `gen2 --emit=obj`
ENCODE-MISS / spurious udf". Built a fast gate (seconds, not the 68-min full
self-emit) covering every miscompile class fixed to reach byte-eq graduation.

- [x] Corpus `self/test/miscompile_zero/*.hexa` — one tiny program per class:
      - c1_hex_literal     — hex-literal lowering (0xNN->0, 47421c89c)
      - c2_stack_locals    — STP/LDP `[sp,#N]` stack-slot codegen (the literal
                             "ENCODE-MISS: STP/LDP mem-parse-fail" signature)
      - c3_struct_ctor     — aggregate construct + field load (aliasing-adjacent)
      - c4_f64_literal     — f64 __literal8 const pool + __DATA reloc (#2509)
      - c5_multi_fn_alias  — multi-fn bodies + shared module global + .ends_with
                             string-compare cascade (953c8824b / hex downstream)
- [x] Gate `tool/miscompile_zero_gate.sh` — native --emit=obj each program,
      assert rc=0 + 0 ENCODE-MISS (stderr grep) + 0 spurious udf (otool/objdump
      disasm) + non-empty obj; EXIT NONZERO on any. Portable via env
      (HEXA_NATIVE_CC / HEXA_CC_PREARGS / HEXA_TARGET / MCZERO_OUT). NO /tmp
      default (writes under repo `.mczero-gate-out` or MCZERO_OUT). Honest rc
      (no pipe-masking).
- [x] VERIFIED on GHOST against the graduated gen2_fix native compiler:
      5/5 PASS, real rc=0 (0 ENCODE-MISS, 0 udf across all classes).
- [x] NEGATIVE-TESTED: a shim emitting a `udf #0` object trips the gate ->
      FAIL, real rc=1. Detection proven in both directions.
- [x] CI wired: `.github/workflows/miscompile-zero-gate.yml` builds `./hexa`
      via the shared `tool/release_build` on macos-latest (arm64 — same
      arm64-apple-darwin emit + otool path) then runs the gate. Path-filtered
      on compiler/self/corpus/gate changes.
- [x] One-line ghost reference run (proven host):
      `HEXA_NATIVE_CC=~/dancinlab/selfhost-work/gen2_fix bash tool/miscompile_zero_gate.sh`
- [ ] follow-up: broaden corpus + promote into the standard `hexa verify` suite
      (domain `## deferred`).

