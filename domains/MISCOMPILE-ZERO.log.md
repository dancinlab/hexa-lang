# MISCOMPILE-ZERO — log
Append-only history sister of `MISCOMPILE-ZERO.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-06-03 — differential fuzz: 120 seeded random programs CLEAN (gen2 vs aprime-C)
Deferred milestone "differential fuzz — generate random hexa programs and
compare gen2-native vs aprime-C codegen to surface latent miscompiles". A NEW
harness (no overlap with the fixed-corpus gate) that RANDOM-generates valid
hexa and diffs the two compilers across asm / obj-encode / behavioral axes.
- [x] GENERATOR `tool/diff_fuzz_gen.py` — deterministic LCG (seed -> identical
      .hexa, no platform RNG). Feature surface proven on BOTH compilers:
      i64+hex arith, guarded / %, comparisons, if/else, bounded while, arrays+
      index, match-expr (`->` arms), 1-3 helper fns incl. nested calls.
- [x] HARNESS `tool/diff_fuzz.sh` — per seed: (1) --emit=asm byte-diff modulo
      benign `__L<sha4>_` label hash; (2) gen2 --emit=obj 0 ENCODE-MISS / 0 udf
      / non-empty .o; (3) link both + compare exit codes. STOPS on first
      divergence printing seed+program+diff. Honest rc (no pipe-mask).
- [x] RAN seeds 1..120 on ghost (gen2_fix vs aprime_fixhex): 120/120 CLEAN —
      0 asm divergence, 0 ENCODE-MISS, 0 udf, 0 exit mismatch, 0 link-skew.
      101/120 distinct exit codes => programs exercise real varied computation.
- [x] VERDICT `.verdicts/miscompile-zero-fuzz/DIFF-FUZZ-120.txt` (seed range,
      counts, reproduce one-liner). Extend via wider seed range.
- [ ] follow-up: widen seed range (121..500) + add float/struct/closure axes
      once snapshot parse surface is confirmed stable.


## 2026-06-03 — CI-health fix: gate invocation + setup/regression classification

Both gate workflows (miscompile-zero + determinism, on main via #2534/#2538)
were RED on every compiler/self/corpus PR — required checks, so they blocked
PR #2539 + all future compiler PRs. Root cause: the CI invocation drove the
compiler via `./hexa run compiler/main.hexa`, which RECOMPILES the compiler
against the installed embedded runtime and hits the build-floor staleness wall
(undeclared `__raw_add_f` / `__raw_cmp3`) -> every `--emit=obj` is 0-byte. The
gate scored that uniform 0-byte as a 10/10 codegen REGRESSION (exit 1) instead
of a SETUP/INFRA error.

- [x] DIAGNOSED locally: `./hexa run compiler/main.hexa … --emit=obj` -> rc=1,
      0-byte (build-floor wall). `./build/aprime_cc _drv.hexa --emit=obj …` ->
      1208-byte clean object (0 ENCODE-MISS) = the WORKING native-emit form;
      `./hexa run tool/hexa_ld.hexa` linker form works (current embedded rt).
- [x] HONEST g63 finding: the released `./hexa` GENUINELY cannot native-emit a
      single program in CI. Only the graduated self-host gen2 (ghost gen2_fix)
      native-emits cleanly, and it is NOT buildable via release_build in CI.
      Correct fix = gate exits 2 (CI-neutral) in that env, NOT false-red.
- [x] Gate scripts hardened (tool/miscompile_zero_gate.sh + determinism_gate.sh):
      up-front CANARY (c1_hex_literal); if even it won't emit (0-byte, no
      ENCODE-MISS) -> exit 2 "cannot native-emit in this env". Per-program:
      0-byte/no-ENCODE-MISS = SETUP-ERROR (exit 2); exit 1 reserved for a
      PRODUCED object carrying ENCODE-MISS / spurious udf (mcz) or two PRODUCED
      outputs that differ byte-for-byte (determinism).
- [x] Workflows: dropped broken `HEXA_CC_PREARGS="run compiler/main.hexa"`;
      `HEXA_NATIVE_CC` via `${{ vars.HEXA_NATIVE_CC || './hexa' }}` (graduated
      compiler wireable later); gate exit 2 -> neutral job success via
      `::notice::` (infra never reds a PR; real regression still exit 1).
- [x] VERIFIED locally (darwin-arm64): broken `./hexa` -> exit 2 both gates;
      a dirty-emitting native compiler -> exit 1 (real regression); a clean
      single-program emit -> exit 0 PASS + relink byte-identical.
- [x] Landed on branch `ci/fix-gate-invocation` (commit 11ca16adc) -> PR to main.
- [ ] follow-up: add a self-host gen2 build step (or wire `vars.HEXA_NATIVE_CC`)
      so the gate runs the REAL native-emit floor check in CI instead of neutral.

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

## 2026-06-03 diff-fuzz widened 121..500 (float/struct/closure) — ALL CLEAN
- 380 seeded programs (seeds 121..500) gen2-native vs aprime-C: 0 divergence, 0 ENCODE-MISS/udf, exit-match.
- generator axes added: float, struct, closure; for-in excluded (parse-fragile on both, not codegen).
- verdict: .verdicts/miscompile-zero-fuzz/DIFF-FUZZ-500.txt · branch mczero/diff-fuzz-500
## 2026-06-03 — codegen perf-stability baseline + budget (PERF axis)

Added the PERF axis to MISCOMPILE-ZERO: emit COST as a tracked regression
budget, complementing the locked correctness gates (miscompile-zero #2534,
determinism #2538, class tests #2548, diff-fuzz #2557). NOT a correctness
gate — it does not inspect ENCODE-MISS / udf (miscompile_zero_gate.sh owns
that); it records per-program native --emit=obj wall-time + object byte-size.

New files (no production source touched, no collision with #2557):
  - tool/codegen_perf_budget.sh — modes baseline | check. Reuses the read-only
    self/test/miscompile_zero/c1..c10 corpus. baseline = measure → write a
    machine-readable TSV (program<TAB>obj_bytes<TAB>wall_ms_median). check =
    re-measure → diff vs committed baseline, FAIL (exit 1) if obj-size > +5%
    OR median wall > +50% (CI-noise tolerant). Mirrors miscompile_zero_gate.sh
    conventions: same CC-locate / PREARGS / hermetic atlas / build/ scratch
    (NO /tmp), canary 0-byte ⇒ exit 2 CI-neutral infra (NOT a regression),
    no pipe-mask. bash-3.2 portable (baseline lookup via grep, not declare -A).
  - tool/codegen_perf_baseline.tsv — committed REAL baseline (gen2_fix, ghost).
  - .verdicts/miscompile-zero-perf/PERF-BASELINE.txt — verdict (verbatim run).

REAL baseline (graduated native gen2_fix, ghost 192.168.50.150, arm64-darwin,
bash 3.2.57; 5 timed runs, 1 warmup, median wall):
  c1_hex_literal 1600B/14ms · c2_stack_locals 1816B/14ms · c3_struct_ctor
  2296B/13ms · c4_f64_literal 1576B/12ms · c5_multi_fn_alias 2240B/14ms ·
  c6_closures 1408B/24ms · c7_recursion_arrays 3544B/17ms · c8_string_methods
  2144B/21ms · c9_match_control 2320B/14ms · c10_try_catch 2056B/13ms.
  10/10 measured; obj sizes deterministic (byte-identical across runs).

RESULT: budget check vs the committed baseline ⇒ PASS, exit 0 (0 regression
vs self — all 10 within +5% size / +50% wall). g63 discrimination both ways:
  + positive: check vs self PASS (exit 0), sizes byte-match baseline.
  - negative: a baseline row tampered to shrink c7 (3544→1000) ⇒ the real
    3544B object exceeds the +5% cap (1050) ⇒ "FAIL c7_recursion_arrays
    size=3544>cap1050" + terminal exit 1. The budget actually trips on a real
    size growth — not a no-op green.

CI-wiring note (for a future gate agent — NOT done here): invocable in CI with
HEXA_NATIVE_CC=<graduated gen2>, gated like miscompile_zero_gate.sh (exit 2 =
CI-neutral infra; exit 1 = real perf regression). Captures cost; complements
(does not replace) the correctness gates.
