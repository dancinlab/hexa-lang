# MISCOMPILE-ZERO — log

Append-only history sister of `MISCOMPILE-ZERO.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-06-02 — linker/compiler DETERMINISM gate: verified + locked

Milestone: "linker determinism — make hexa_ld output byte-deterministic
(relink gen2 == gen2b; prior diff @byte ~1924664 symtab tail)". The OLD
note flagged possible linker nondeterminism; byte-eq graduation suggested
it was resolved but it was never LOCKED as a gate. Verified deterministic
end-to-end and gated.

- [x] RE-EMIT determinism: native --emit=obj each corpus program TWICE on
      GHOST (gen2_fix) — 10/10 byte-identical objects (cmp + SHA256). The
      `_L<sha4>_` label hash = sha256(module.file)[:4]
      (compiler/codegen/arm64_darwin.hexa:752) is a PURE FUNCTION of the
      fixed module path — same path → same labels every emit (path-derived,
      NOT nondeterminism), empirically confirmed by the byte-identical
      re-emit.
- [x] RELINK determinism: link each object TWICE with hld_fixed —
      10/10 byte-identical executables. ROOT-CAUSE of the only diff seen:
      a naive two-name relink (link_A vs link_B) differs in EXACTLY ONE
      byte at 0x8192 — the output basename baked into the linker
      ad-hoc-codesign build-id string `<basename>-UUID0123…0123456789abc`
      (the hex tail is the hardcoded LC_UUID constant, hexa_ld.hexa:1750-53,
      NOT a timestamp/random). Same-basename relink (two dirs) → SHA256
      identical. So the build-id is path-derived/deterministic, NOT a
      nondeterminism source. NO fix to hexa_ld needed.
- [x] SCALE proof (the exact OLD-note case): re-linked the 3.2MB graduated
      compiler object cc-prc2-fix.o TWICE → 1.6MB executable, IDENTICAL
      SHA256 (683b85f8f7e3…). The symtab/strtab tail at ~1924664 is
      deterministic; the relink wall is CLOSED. Audited hexa_ld.hexa:
      LC_UUID = hardcoded const, LC_SOURCE_VERSION = 0, n_desc = 0,
      strtab verbatim + zero-pad, nlist emitted in fixed scan order — no
      wall-clock / random / unstable-sort / uninit-pad source exists.
- [x] GATE `tool/determinism_gate.sh` — PHASE 1 emit-twice + PHASE 2
      link-twice (same basename) over self/test/miscompile_zero/*.hexa,
      FAIL NONZERO on any byte diff. Env-portable (HEXA_NATIVE_CC /
      HEXA_CC_PREARGS / HEXA_LD / HEXA_TARGET / DETERM_OUT). NO /tmp
      (writes under repo build/). Honest rc, no pipe-masking.
- [x] VERIFIED on GHOST against graduated gen2_fix + hld_fixed:
      PASS 10/10 re-emit AND 10/10 relink byte-identical, real exit 0.
- [x] NEGATIVE-TESTED: a one-byte perturbation in a relink output trips
      the FAIL branch → exit 1. Detection proven both directions.
- [x] CI wired: `.github/workflows/determinism-gate.yml` builds ./hexa via
      the shared release_build on macos-latest (arm64), then runs the gate
      with the linker via `hexa run tool/hexa_ld.hexa`. Path-filtered on
      compiler/self/corpus/gate/linker changes.
- [x] One-line ghost reference run:
      `HEXA_NATIVE_CC=~/dancinlab/selfhost-work/gen2_fix HEXA_LD=~/dancinlab/selfhost-work/hld_fixed bash tool/determinism_gate.sh`

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


## 2026-06-03 — PRIMITIVE-level miscompile-CLASS targeted tests (branch mczero/class-tests)

Milestone: "catalogue the native-codegen miscompile CLASS as targeted codegen
tests" — each historical class isolated as a MINIMAL primitive test (not a whole
program), native-compiled + RUN on the graduated gen2_fix (ghost), with a real
exit-code behavioral assert AND a cheap byte/asm oracle (0 ENCODE-MISS, 0 udf).

NEW (additive — does NOT touch tool/miscompile_zero_gate.sh / determinism_gate.sh
/ .github/workflows, per scope boundary):
  - self/test/miscompile_class/  (NEW dir, distinct from miscompile_zero/)
      m1_hex_literal          — hex-literal lowering 0xNN->0 (#2532, 47421c89c)
      m2_fn_body_aliasing     — shared module-global .truncate(0)/reassign
                                snapshot survival (#2509, _lr_ctx_clear 953c8824b)
      m3_string_compare       — _ends_with/starts_with/== cascade on asm-operand
                                + @PAGE-label strings (hex downstream)
      m4_two_reg_value_abi    — (ptr,len) string value live across a clobbering
                                intervening call
      m5_linker_reloc_kinds   — __literal8(f64) + __DATA UNSIGNED(module-global)
                                + __mod_init_func(top-level init) in one program
                                (#2509: 5f38d7eb4/23207ce70/07d8556d1)
      m6_index_slice_charcode — array index / substring / char_code / truncate(n)
                                offset-loads (cycle-34/35 fallthrough,
                                arm64_darwin.hexa:1303)
      m7_struct_ctor_fields   — struct ctor + field-offset reads (cf. c3)
  - self/test/miscompile_class/run.sh  — standalone runner: emit -> asm-oracle
      (0 ENCODE-MISS, 0 udf) -> clang link vs self/runtime.c -> RUN, real rc.
      exit 0 all-clean / 1 class-regressed / 2 infra. No pipe-mask.
  - .verdicts/miscompile-class/CLASS-TESTS.txt  — verdict (verbatim runner output)

RESULT (graduated gen2_fix, ghost 192.168.50.150):
  7/7 PASS — every class emits clean (0 ENCODE-MISS, 0 udf) AND runs rc=0.
  RUNNER-EXIT=0. No surprising failure -> no live regression in any class.

g63 discrimination proof (both directions):
  - negative control: assert the COLLAPSED hex value (0xff&0xf0==0) -> gen2_fix
    printed CORRECT rc=99 (hex did NOT collapse); a regressed compiler would
    have printed COLLAPSED rc=0.
  - tamper control: m1 expected 240 mutated to 999 -> runner "FAIL ... RUN
    rc=51 (CLASS REGRESSED)", RUNNER-EXIT=1 (names the class, real nonzero).

CI-wiring note (for the gate agent — NOT done here): run.sh is invocable in CI
with HEXA_NATIVE_CC=<graduated gen2> + HEXA_RUNTIME=self/runtime.c, gated like
miscompile_zero_gate.sh (exit 2 = CI-neutral infra; exit 1 = real regression);
complements (does not replace) the program-level gate.
