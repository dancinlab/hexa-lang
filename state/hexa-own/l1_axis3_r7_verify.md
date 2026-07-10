# axis-③ R7 — HEXA_SELFEMIT_PACK_OUT lineage-narrowing verify

**Verdict: AMBER / PARTIAL-GREEN** — R7 **FIXES the R6 compiler-breaking regression** (correctness GREEN)
but **does NOT deliver the memory win** (peak RSS = 19.87 GB, not the ~6.8 GB target). The 19 GB→6.8 GB
premise is **falsified at full-self-emit scale**.

## Run context
- **Measured on:** fresh **RunPod CPU pod** `32cb53gx5oyfo6` (x86_64-linux, 8 vCPU, 124 GB RAM, clang-18,
  unloaded). **Pod DESTROYED after run** (`rm: destroyed … 404-confirmed gone`; SSH refused; `cloud pods`
  RUNNING=0 — no billing leak).
- **Why a pod, not aiden/summer:** BOTH pool hosts were saturated by peer agents' heavy `--emit=obj`
  self-emit jobs (aiden: 2× aprime_cc @ ~21 GB; summer: cc_native packlir @13 GB + anima python @7.8 GB),
  both swap-thrashing. A flag-ON build launched on summer wedged for **21 min on the first seed-converge
  file (lexer.hexa)** at ~12% effective CPU (pure I/O contention). Killed it (courtesy to peers) and
  pivoted to a clean pod — the R6-proven path. ~cents cost.
- **Branch tip tested:** `efe9ee38` "fix(axis-3/R7): close SELFEMIT_PACK_OUT × fs-native flag-interaction
  hole + land review verdicts" — **NEWER** than the `6f9b2e71f` in the task brief (origin branch was
  updated after the initial fetch). Fresh `--depth 1` clone of `origin/feat/axis3-r7-packout-lineage`.

## Captured signals (the 4)
| # | signal | result |
|---|--------|--------|
| 1 | HX1101 count (trivial compile) | **0** (was 3 in R6) |
| 2 | trivial exit | **42** (build stage-5 smoke `exit(6*7)==42 PASS`) |
| 3 | x86_serialize mark | **YES** (count=1) — full pipeline reached |
| 4 | peak RSS / wall / .o | **19.87 GB** / 4:44.69 / self.o = ELF x86-64 REL, 6,869,920 B |

## STEP 2 — flag-ON build  ✅
`HEXA_SELFEMIT_PACK_OUT=1 bash tool/build_aprime.sh` → **BUILD_ON_RC=0**. Seed-converge FIXPOINT in 2
passes; stage-2 transpile 71,952 L C; clang → build/aprime_cc (3,422,976 B); **stage-5 built-in smoke
`exit(42)==42 PASS — aprime_cc OK`**. (R6 FAILED here with 3× HX1101 + uninterpolated `{name}`.)

## STEP 3 — trivial-compile regression (the R6 break)  ✅
- ⚠️ First standalone invocation used wrong arg order (source-first) → compiler printed
  `missing SOURCE.hexa`, rc=2 / HX1101=0 *trivially* (nothing compiled) — INVALID probe.
- Corrected (driver-arg order `aprime_cc _drv.hexa --emit=asm --target=x86_64-linux-gnu -o t.s t.hexa`):
  **COMPILE_RC=0, HX1101_COUNT=0, zero diagnostics**, valid x86_64 `.s` emitted.
- ⇒ R6 frontend miscompile (binder/scope corruption) is **GONE**. Narrowing successfully **contained**
  the packed handle — no escape, no ByteBuf vehicle-switch needed for correctness.

## STEP 4b — profiled native self-emit  (mixed)
`/usr/bin/time -v env HEXA_CG_PROFILE=1 HEXA_SELFEMIT_PACK_OUT=1 aprime_cc --backend=native --emit=obj
--target=x86_64-linux-gnu self_flat.hexa -o self.o` over the 52-file / 68,260-line closure.

CG_PROFILE mark sequence (delta_ms) — **complete, through the x86 backend**:
```
front_begin 0 · lex 10802 · parse 14865 · atlas_load 0 · resolve 241 · bind 4299 ·
type_check 29287 · unit_check 275 · lower_ast_to_hir 50615 · begin 0 · lower_hir 29239 ·
mir_opt 19 · codegen 125776 · x86_pack_lir 17398 · x86_serialize 553
```
- (a) **x86_serialize PRESENT** (count=1) — passed serialize_elf_x86_64, **NOT** the R6 SIGSEGV-at-
  front_begin. ✅
- (b) **self.o = ELF 64-bit LE relocatable, x86-64** (e_type=1 REL, e_machine=62), 6,869,920 B. ✅
- (c) **PROBE_RC=0.** ✅
- (d) **peak RSS = 19,866,936 KB ≈ 19.87 GB.** ❌ — this is the *unpacked/boxed wall*, NOT ~6.8 GB.

## Interpretation — the memory-win premise is falsified
The **6.8 GB "fixed" figure is unreproducible** in a full flag-ON self-emit — exactly the suspicion the
R6 doc raised ("must have been observed some other way … not reproducible via a full flag-ON aprime_cc
self-emit"). Peak RSS is dominated by the **boxed compilation state** (AST/HIR/MIR of the 68,260-line
self-source — heavy phases: lower_ast_to_hir 50.6 s, codegen 125.8 s), **not** the serialize `out:[Int]`
accumulator. The ELF output is only **6.87 MB**; even fully boxed (×16 B/int) that accumulator is
~110–220 MB — it **cannot** account for a ~12 GB (19→6.8) swing. So packing only the (correctly, soundly)
narrowed emit-lineage accumulator is **inert w.r.t. peak RSS** at self-emit scale. (No OFF-self-emit RSS
control was run this session, but the output-size argument makes the conclusion robust regardless.)

## Campaign implications
1. **R7 as a REGRESSION-FIX: GREEN, mergeable.** It unbreaks the flag-ON compiler that R6 (#4800/#4801)
   broke, default-OFF + byte-neutral. If OFF-path byteeq stays bit-identical, R7 can land as the fix.
2. **Default-flip "for the memory win": NO measured basis — do NOT proceed.** There is no RSS reduction
   to ship; the 19→6.8 GB premise is falsified. Flipping HEXA_SELFEMIT_PACK_OUT default-ON buys a slower,
   more complex codegen path with **zero peak-RSS benefit**.
3. **If self-emit peak-RSS reduction is the real goal**, the pack-out/serialize-accumulator lever is the
   **wrong target**. The wall is the **boxed AST/HIR/MIR compilation arena (~19 GB for 68 k lines)** — a
   future round should aim there (frontend letregion/arena for boxed HexaVal state), consistent with the
   boxed-substrate-is-terminal findings elsewhere.
4. **Kill-criterion (ByteBuf switch): NOT triggered for correctness** — the packed handle did not escape
   (HX1101=0, no SIGSEGV). ByteBuf would not change the RSS conclusion either (accumulator isn't the wall).
