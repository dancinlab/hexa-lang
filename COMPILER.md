# 💎

> hexa-lang compiler — build-speed analysis and the native-codegen
> 정공법 (orthodox path).
>
> This started as a perf / resource / speed ROI brainstorm. The
> measurement (lever 0) plus an exhaustive survey re-centred it on one
> conclusion: the build bottleneck is clang (80% of build wall), clang
> is an *external dependency*, and the orthodox fix is hexa-lang's own
> native codegen — `compiler/`, which already exists and nearly
> self-hosts. **Finish `compiler/`; do not optimize the C path.** The
> C-path levers (W1/W2/F, lower in this file) are interim relief only.
>
> SSOT for staged compile progress is `compiler/PLAN.md`; this file is
> the analysis + ordered sequence that points into it.

```
At-a-glance
  pipeline : .hexa --> hexa_v2 --> C (1 TU) --> clang --> native --> run
  정공법   : finish compiler/ — the native codegen (aprime_cc, 85K LoC)
             ALREADY EXISTS and self-compiles; blocker = codegen
             super-linear perf. order = compiler/PLAN.md #18 S1->S4.
  interim  : W1/W2/F speed the C path; relief only while the C fallback lives
  naming   : drop bootstrap vestiges (_v2 _c2 aprime s4) — separate cycle
  measured : clang = 80% of build wall; runtime.c recompile = 53% alone
  status   : S1-S5 done · 🛸 S7 RFC 063 ALL PHASES CLOSED:
              P0 🛸 (corpus 4/4 byte-eq vs clang)
              P1 🛸 (F-P1-RUNEQ trivial.hexa exec→exit 42 via static-link)
              P2 🛸 (ELF Linux exec→exit 42 + multi-obj CALL reloc on ubu-2)
              P3 🛸 (F-P3-ZERO-EXTERN-OBJ + FULL-RUNEQ — stripped PATH PASS)
              campaign 21 cycles on s7-p0-cycle1 (FF merged compiler-native-codegen, origin pushed)
```

---

## 정공법 — drop the C step (orthodox path)

Levers W1, W2, and F all make the *C compilation* faster — but the C
step exists only to hand work to clang, an external compiler. The
orthodox path removes the dependency entirely:

```
current (C-path, depends on clang):
  .hexa --> hexa_v2 --> C --> [ clang -O2 ] --> native binary
                              ^^^^^^^^^^^^^
                              external dependency · 80% of build wall

정공법 (direct native codegen, self-hosted):
  .hexa --> hexa codegen --> machine code --> native binary
                             (own instr-sel + regalloc + emitter + linker)
```

Why this is the orthodox path, not lever `I` "ranked last":

- It IS hexa-lang's stated architecture — `HEXA-NATIVE-ONLY.md`, `@D g5`
  ("no third-party codegen backend"), `@N n1` ("direct native codegen is
  on the roadmap"; the C path is "fallback, not the architecture").
- clang is the measured 80% of build wall — removing the dependency
  removes the bottleneck at its root, not at the margin.
- "loses clang's optimizer" is not a cost of the path — it is scope
  hexa must own (its own optimizer passes). Keeping clang to borrow its
  optimizer is precisely the external dependency to shed.

The C path stays as the documented portability fallback during the
transition (consistent with `@F f2`: fallback C emission is allowed, it
just is not the architecture).

### Reality check — the 정공법 is ~70% built (2026-05-20 exhaustive survey)

The earlier estimate ("RFC-scale, 10d+, build it from scratch") was
WRONG — a measured falsification. The direct native codegen path
already exists as `compiler/` (85,023 lines of hexa, binary `aprime_cc`):

- Full IR pipeline, built and spec'd (RFC-018): `.hexa` -> lex -> parse
  -> resolve -> check -> lower(HIR) -> lower(MIR, SSA CFG) -> codegen
  (MIR->LIR) -> emit(`.s`). IR structs in `compiler/ir/{hir,mir,lir}.hexa`.
- CPU targets exist: `compiler/codegen/arm64_darwin.hexa` (linear-scan
  regalloc), `x86_64_linux.hexa`, `thumbv7em_eabihf.hexa`.
- It self-compiles: `aprime_cc` byte-cleanly compiles its own hardest
  modules (parser, codegen) to assembly; the frontend typechecks the
  entire 21K-line compiler source with 0 errors.
- Measured corpus: `aprime_cc`-direct passes 30/60 smoke tests vs interp.

What it is NOT yet:

- Not fully self-hosting. The dominant blocker is codegen *performance* —
  `_lower_hexpr` (`compiler/lower/hir_to_mir.hexa`, 1209 lines) is
  super-linear (~0.5 s/stmt); the 21K-line full compiler does not finish
  codegen inside a 9-min cap. This is compiler-engineering, not a
  language gap. Correctness is "almost closed" (residual: nested-struct
  SIGSEGV x3, atlas-verifier divergence x5, macro-depth x3).
- The native path still shells `as` / `clang -c` to assemble the `.s` and
  system `ld` to link. That is the *thin* assembler, not the optimizing
  compiler — the 80%-of-build-wall clang *optimizer* cost is exactly what
  `compiler/`'s own MIR->LIR replaces. An own assembler (drop `as`) +
  `hexa_ld` integration (the in-house linker exists, v1.1) are later
  refinements, not blockers.

So the 정공법 is to FINISH `compiler/`, not to START it.

### 순서 — the ordered sequence

The canonical staged order is already written in `compiler/PLAN.md` #18
("aprime_cc self-host"); that file is the SSOT — this file only
cross-links it:

```
S1  codegen performance — DONE 2026-05-20. The dominant blocker, closed.
    step-1 (commit 8ab732bd): per-phase instrumentation HEXA_CG_PROFILE=1
      + baseline — lower_hir (HIR->MIR) confirmed THE super-linear phase.
    step-2 (commit ce4c9706): hoisted _lower_hexpr's LowerCtx accumulators
      (locals/blocks/bindings) to module scope, killing the per-recursion
      O(N^2) deep-copy of the growing LowerExprResult{ctx}. MEASURED:
      lower_hir at N=400 = 1527 ms -> 9 ms (~170x); O(N^2) -> near-linear.
      byte-eq 7/7 fixtures PASS (perf-only, zero semantic change).
S2  full-closure codegen 완주 — DONE 2026-05-20 (commit a94ed6e3).
    The full 24k-line compiler closure codegens to completion: `.s`
    emits in ~94s (was a 9-min-cap timeout pre-S1). Per-phase:
    lower_hir 971ms (S1 holds at full scale), codegen 7.4s (the new
    long pole, ~79% — not a blocker, <2min total), emit 1.2s. codegen
    diagnostics clean — 0 errors, 0 unmapped-builtins, 11 HX4001 warns.
    S2-followup (non-blocking): codegen sub-phase instrumentation.
S3  self-host fixpoint — PROVEN 2026-05-20. gen1 (built via the hexa_v2
    -> C -> clang path) and gen2 (built by assembling gen1's emitted .s
    of the full closure + a 3-fn shim `gen2_shim.c` mapping native-asm
    builtin names `sha256_hex`/`list_dir`/`mono_ns` to the `hexa_*`
    runtime exports — the asm path lacks build_aprime.sh's sed rewrites)
    both compile the same flatten of `compiler/main.hexa` to BYTE-
    IDENTICAL `.s` — 10,094,662 B, md5
    `29426b801cb072b2861bd608e884b20b`. The compiler reproduces its own
    emitted code: gen3 follows transitively. Honest caveat: the shim is
    a *bootstrap-time naming-convention bridge*, not a semantic gap.
S4  drop the hexa_v2 dependency — wiring DONE 2026-05-20. New
    `tool/build_hexac.hexa` (hexa-native, NOT .sh — hexa-first) runs
    the native path: flatten -> aprime_cc --emit=asm -> 3-fn naming
    shim -> clang assemble+link. Mirrors the gen2 chain verified by
    S3 fixpoint. hexa_v2 is no longer in the compiler's own build
    path. clang remains as assembler+linker only — S7 closes that.
    Verification build deferred to post-rate-limit-reset.

post-fixpoint (beyond compiler/PLAN.md #18 — analysis-side continuation):
S5  native `hexa build` backend — wiring DONE 2026-05-20 (commit
    30dc7a77). HEXA_BACKEND=native selector + resolve_native_cc() added
    to cmd_build, env-gated OFF by default (C path byte-identical when
    unset), smoke-verified — native path builds + runs a trivial program
    (exit 42). Native path is 2-stage (aprime_cc --emit=asm, then clang
    assemble+link runtime.c) because `aprime_cc --emit=exec` does not
    self-link (no runtime.o/crt) — that self-linking is an S7 item.
    Default-on flip waits on S1-S4 (fixpoint) + S7 (native linker).
S6  optimization passes — the basic passes (const_fold, dce, inline)
    are ALREADY wired (`compiler/main.hexa --opt=0..3`). S6 = extend
    them toward parity with clang -O2 via the HEXA-NATIVE-ONLY.md
    G-0..G-11 axis ladder (typed scalar lane A1/A2 first, then loop /
    SIMD / tiling) — that ladder is the substantive gap.
S7  own assembler + hexa_ld — drop `as` / `ld` / `clang`. Design
    contract: RFC 063 (`inbox/rfc_drafts_2026_05_12/rfc_063_s7_
    native_assembler_linker.md`), 4 phases with falsifiers (F-P0-
    OBJEQ / F-P1-RUNEQ / F-P3-ZERO-EXTERN), ~12-18 cycles total.
    P0 scaffold landed 2026-05-20 (`compiler/emit/macho_arm64.hexa`
    — types + entry + encoding checklist + Mach-O constants).
    P1 scaffold landed (`tool/hexa_ld.hexa` — CLI + types + link
    entry + relocation/symbol-resolution checklist). Implementation
    across future S7-{P0,P1,P2,P3} sub-agent cycles. Final closure
    of "의존도 없이 외부 / 완전한 hexa-native".
```

S1 is both the dominant blocker AND a performance problem in its own
right — it is itself an instance of this whole analysis (the compiler
compiling slowly). Start there.

W1/W2/F are now explicitly interim: worth doing only as relief while the
C fallback still exists; they do not substitute for the 정공법.

### Step detail — S2..S7 (prep survey, 2026-05-20)

Surveyed read-only while S1-step-2 runs, so each step is dispatch-ready.

- **S2 — full-closure codegen 완주.** Prereq: S1. Re-run the full
  `compiler/main.hexa` import+use closure (38 files / 21,832 lines)
  through `aprime_cc`; confirm `.s` emits within time (it hit the 9-min
  cap pre-S1). First point full-scope codegen-correctness is measurable.
- **S3 — self-host fixpoint.** Full `.s` -> assemble -> link -> 2nd-gen
  `aprime_cc`. byte-diff 1st-gen (built via hexa_v2) vs 2nd-gen (built
  via aprime_cc) = the fixpoint proof. Harness: `tool/build_aprime.sh`.
- **S4 — drop hexa_v2.** `tool/build_aprime.sh` stage 2 is the hexa_v2
  `.hexa->.c` transpile. Once S3's byte-diff PASSES, swap stage 2 to
  `aprime_cc` — the compiler no longer needs the C transpiler (nor clang)
  to build itself.
- **S5 — native `hexa build` backend.** `compiler/main.hexa` already has
  `--emit=asm|obj|exec` (default exec — it already produces linked
  executables, `:125`/`:151`). `self/main.hexa::cmd_build` (`:1710`)
  currently drives hexa_v2->C->clang. Add a backend selector (env/flag)
  so `cmd_build` can invoke `aprime_cc --emit=exec`. This delivers the
  lever-0 build-speed win to *user* programs, not just the compiler.
- **S6 — optimization passes.** CORRECTION (2026-05-20 prep): the basic
  passes ARE wired, not stubs. `compiler/main.hexa` documents
  `--opt=0..3` (`:128`/`:140-142`): `--opt=1` const_fold, `--opt=2`
  const_fold + dce, `--opt=3` inline_small + const_fold + dce 2-pass.
  `compiler/optimize/{const_fold (160L), dce (152L), inline (412L)}.hexa`
  are implemented (RFC-018 §9). S6 = extend toward parity with `clang
  -O2` via the `HEXA-NATIVE-ONLY.md` G-0..G-11 ladder (typed scalar lane
  A1/A2 first, then loop / SIMD / tiling) — the ladder is the
  substantive gap, not the basic optimizer scaffold.
- **S7 — own assembler + linker (완전한 hexa-native).** `compiler/main.hexa`
  already marks `as` / `ld` / `xcrun` as "L1 keepers — replaced when
  self-as lands" (`:2`, `:806`); an L1->L2 migration scaffold +
  `compiler/intrinsics/intrinsics.hexa` exist. CORRECTION (2026-05-20
  prep): `tool/hexa_link.hexa` is a *clang wrapper* per its own header
  ("Thin clang wrapper. Takes N .c files ... clang handles C-level symbol
  resolution") — NOT a from-scratch linker. S5's finding confirms scope:
  `aprime_cc --emit=exec` does not self-link (no runtime.o / crt). S7 =
  land self-`as` (LIR -> object code directly, skipping `.s` -> `as`) +
  write a real native linker for Mach-O arm64 / ELF x86_64 (relocation
  records + crt + runtime.o). The deepest step — what closes "의존도 없이
  외부" fully.

## Naming — drop the bootstrap vestiges

The bootstrap era left version-suffix / codename file names. As the
정공법 makes `compiler/` the one real compiler, these vestiges go —
completely. The conventions being abandoned:

- version suffixes — `_v2`, `_c2`, any `<n>` generation marker
- codenames — `aprime` (the native compiler's temporary codename)
- stage numbers baked into names — `s4_...`

Vestige inventory (known; canonical names are the plan — adjust before
the rename cycle runs if any name is contested):

| vestige | what it is | canonical |
|---------|------------|-----------|
| `aprime_cc` · `tool/build_aprime.sh` | native codegen compiler + its build | `hexac` · `tool/build_hexac.sh` |
| `hexa_v2` · `self/native/hexa_cc.c` | legacy C transpiler binary + source | `ctrans` · `ctrans.c` |
| `self/codegen_c2.hexa` | C-backend codegen (SSOT) | `codegen_c.hexa` |
| `self/native/codegen_c2_v2.c` | C-frontend codegen mirror | `codegen_c.c` |
| `self/native/{lexer,parser,type_checker}_v2.c` | C-frontend mirror | drop `_v2` |
| `tool/s4_flatc_post.py` | flatten post-processor | `tool/flatc_post.py` |
| `self/native/*.bak.*` · `*.pre*` | dead bootstrap snapshots | delete |

Execution is a SEPARATE atomic cycle — NOT folded into S1. A mass rename
rewrites `import` paths across the whole tree; mixing it into a perf
change makes both unreviewable, and the shared-checkout branch churn
(this session alone saw the branch flip twice) compounds the conflict
risk. Do it in one worktree, atomically, when S1 is parked. New files
created from here on already use clean names — the vestige convention is
abandoned for anything new immediately.

## Pipeline — where the C-path levers sit

```
.hexa source ──▶ hexa_v2 ──▶   C   ──▶  clang  ──▶ native ──▶ run
 (frontend)     transpiler   (1 TU)     (-O?)     binary
     │              │          │          │          │          │
   [H] stream     [F] split  [F] split  [A] -O2   [I] no-C    [D] arena
                  [G] incr. cache       [B] -j [C] cache     [E] clone fix
```

Key observation: the current `flatten` (all modules merged into a single C
translation unit) is the shared root of three problems — out-of-memory,
slow compile, and zero incrementality. That is why `F` is the keystone
*of the C path*: breaking flatten unlocks `B`, `C`, and `G` for free.

## C-path lever matrix — interim relief only

These levers speed the C-transpile path. They are interim: valid only
while the C fallback exists. The 정공법 (lever `I`) supersedes all of them.

| #  | Lever | Axis | Cost | Gain (estimate) | Lossless? |
|----|-------|------|------|-----------------|-----------|
| 0  | Compile profiling / instrumentation | diagnostic | 0.5d | fixes the ranking of the other 9 | yes |
| A  | ~~`clang -O2` on emitted C~~ — ALREADY SHIPPED (`self/main.hexa:1910` `cmd_build`; runtime `:913/915`). No work left. | runtime speed | done | — | — |
| B  | per-module `.c` -> `clang -j` parallel | compile speed | 1d* | compile wall / N cores | yes |
| C  | content-hash C/.o cache (ccache-style) — measured: caching `runtime.o` alone removes 53% of build wall, see W1 | compile speed | 1-2d* | skip recompile of unchanged modules | yes |
| A2 | `-O0`/`-O1` fast-dev build flag (current build is `-O2`-always) | compile speed | 0.5d | app.c clang 3.6s -> 0.7s (5x), see W2 | yes (flag-gated) |
| D  | `HEXA_VAL_ARENA` reclaim wiring | resource | 1-2d | lower memory peak on long compiles | env opt-in |
| E  | `struct_pack_map` shallow-clone gotcha fix | correctness + resource | 1d | removes bug + avoids needless clones | yes |
| F  | drop flatten -> separate compilation (C-path keystone) | all 3 axes | 4-7d | resolves OOM + unlocks B/C/G | yes |
| G  | module-level incremental compile (on top of F) | compile speed | in F | 1-line edit: full build -> 1 module | yes |
| H  | streaming codegen (no whole-AST in memory) | resource | 5-8d | large drop in compile memory peak | yes |
| **I** | **정공법 — finish `compiler/`: hexa-lang's own native codegen (binary `aprime_cc`). Replaces the clang stage outright — see "정공법" section.** | all axes | finish (~70% built) | removes clang = removes 80% of build wall at the root | yes (self-hosted) |

`*` B and C depend on `F` (split) — neither parallelism nor caching is
possible while the build is a single flattened translation unit.

## Recommended order

**Wave 1 — cheap, lossless (~3d):** `0` profile -> `E` clone fix. Lever
`A` (`-O2`) was found already shipped; the `0` profile decides whether
`D` or `H` is the higher-priority memory lever.

**Wave 2 — C-path keystone (`F` separate compilation, ~1 week):** breaking
flatten makes `B`, `C`, and `G` follow for free. The OOM wall (full
`compiler/main.hexa` flatten exceeds memory on every host) is resolved
structurally here.

**Wave 3 — the 정공법 (`I`, finish `compiler/` native codegen):** the
orthodox fix — replace the clang stage with hexa-lang's own MIR->LIR
native codegen. `compiler/` already exists (85K LoC, binary `aprime_cc`)
and nearly self-hosts; the work is to FINISH it, not start it. Ordered
sequence S1->S7 is in the "순서" section above. W1/W2/F (Waves 1-2) are
interim relief on the C path, not substitutes for it.

## Why lever 0 leads

Every gain figure above is an *estimate*. Running `0` (cost ~= free, it is
a diagnostic, not a cost-bearing fire) turns the ranking into measurement:
if clang dominates compile wall, `B` wins; if the `hexa_v2` frontend
dominates, `H` wins. A half-day profile validates or refutes the 1-week
bet on `F` before it is made.

---

## Lever 0 — measured profile (2026-05-20)

Target: `hexa build self/main.hexa` — the hexa CLI itself (183 KB source
-> 155 KB / 3331-line C). Profiled on the local macOS host with
`/usr/bin/time -l`.

| Stage | Wall | Peak RSS | Share |
|-------|------|----------|-------|
| 1+2  flatten + transpile (`hexa_v2`) | 2.4s | 103 MB | ~21% |
| 3    clang `-O2`  — `runtime.c` (9574 lines) | 6.2s | 164 MB | ~53% |
| 3    clang `-O2`  — `app.c` (transpiled program) | 3.6s | 120 MB | ~31% |
| **total** (one-shot link 9.3s + transpile 2.4s) | **~11.7s** | 163 MB | 100% |

Reference: `app.c` at `-O0` compiles in 0.70s vs 3.57s at `-O2` — a 5x
optimizer tax.

### Findings

1. **clang is 80% of build wall** (9.3s / 11.7s). The transpiler is cheap.
   So `H` (streaming the transpiler) has only a small ceiling — but `I`
   (native codegen) does not: it replaces the clang stage outright. That
   is why `I`, not `H`, is the 정공법.
2. **`runtime.c` recompile = 53% of every build** (6.2s). The same
   unchanged 9574-line C file is recompiled at `-O2` on every build
   (one-shot link, `self/main.hexa:1910`). It is larger than the
   transpiled program itself.
3. **`-O2` costs 5x** vs `-O0` on the transpiled C. The build is
   `-O2`-always — the wrong default for the edit-compile-test loop.
4. **No OOM on this target** (peak 163 MB). The known OOM is specific to
   `compiler/main.hexa`, whose flatten merges all imported stdlib into one
   translation unit — a result already settled (see
   `project_compiler_selfbuild_blockers`), not re-fired here. Lever `F`
   stays the C-path keystone for *that* import-heavy / OOM target class
   only; monolithic builds like `self/main.hexa` do not need it.

### Re-ranked C-path quick wins (measured, supersede pre-profile estimates)

- **W1 — cache `runtime.o`**: build it once at `-O2`, link the cached
  object. 6.2s -> ~0s amortized. Build wall 11.7s -> ~5.5s (~2x). Cost
  ~0.5d. Lossless (the runtime TU does not change between app builds).
- **W2 — `-O0`/`-O1` fast-dev flag**: `app.c` 3.6s -> 0.7s. Stacked on
  W1: 11.7s -> ~3.1s (~3.8x faster dev loop). Release builds keep `-O2`.
  Cost ~0.5d.
- `F` (flatten split) remains the C-path keystone but is now scoped: it
  earns its cost on import-heavy / OOM targets, not on the common build.

These are interim — they speed the C path that the 정공법 (lever `I`)
ultimately removes.

## Interpreter retirement (R-series)

GOAL ② SSOT: `compiler/PLAN.md` (cycle log) + `GOAL.md` ②. The native
`compiler/` toolchain must become good enough to **retire the
interpreter** (`hexa_real` / `self/hexa_full.hexa`); the interpreter
stays as fallback until native corpus coverage equals it.

The hard parts already work — the native front-end and the arm64
codegen (S1–S4 + builtin-symbol map + int/bool ret-box) emit correct
`.s`. "Retire interp" = replace `hexa run X.hexa` (interpret) with
native compile + run; compilation works, the open question is whether
a compiled binary runs *correctly*. Each failure is a missing/incorrect
**builtin lowering** in arm64 codegen — bounded one-line-class fixes,
not architectural blockers. The footprint, F6-A and x86_64-codegen ABI
work (below) are **independent of interp retirement** — small-program
native compile is cheap and is all interp-retirement needs.

Phased roadmap (R0–R6 closed; dated detail in `COMPILER.log.md`):

| phase | deliverable | status |
|-------|-------------|--------|
| R0 | native compile→link→run end-to-end, no crash | ✅ arm64/Mac |
| R1 | a verifiable program runs correctly (`exit(42)`⇒`$?`=42) | ✅ aprime_cc arm64 |
| R2 | codegen-correctness audit driven by real programs | ✅ root-cause fixes landed |
| R3 | compile+run a representative corpus natively; diff vs interp | ✅ nine codegen-correctness classes; `t_batch22` 31/31 byte-identical |
| R4 | `hexa run` → native compile+run, interp kept as fallback | ✅ `bin/hexa-run-native` wrapper |
| R5 | broader corpus coverage; close DIFFs cluster-by-cluster | 🔄 aprime_cc-direct ~45%, hexa-build ~63% full-corpus sweep |
| R6 | three-tier wrapper exposing R3 aprime_cc-direct as opt-in | ✅ `HEXA_APRIME_CC=<path>` opt-in |
| R7 | delete the interp once aprime_cc-direct coverage ≥ interp | ⬜ gated on R5 cluster closure |

Each phase is incremental and default-safe (interp fallback stays until
R5; codegen fixes are additive symbol/ABI corrections that do not
regress working paths). The largest open blocker is the atlas-runtime
aliasing cluster (struct-array-grow shallow-clone — see `COMPILER.log.md`
"atlas_* DIFF diagnostic"). Build recipe for the native arm64 compiler
is recorded in `COMPILER.log.md` ("Build recipe").

## Stage-3 codegen — HexaVal-ABI + footprint

The stage-3 verdict (self-host fixed point) had two halves: codegen
**correctness** (Path A) and self-compile **footprint** (the streaming
work). Decision authority: `COMPILE-ONLY.log.tape` `@D d_stage3_abi_path`.

### Path A′ — memory-resident HexaVal codegen (arm64-first)

`sizeof(HexaVal)=16` (`{HexaTag tag(4); union{i64/f64/ptr…}(8)}`,
8-aligned, non-HFA). AAPCS64 ⇒ HexaVal is passed/returned in a
**register pair** (arg0→x0:x1 … arg3→x6:x7, then 16B stack; returned in
x0:x1). The chosen tactic **A′** models every SSA value as a **16B frame
slot** and threads slot addresses, not register-resident values — this
avoids a pair-aware register allocator and mirrors the proven
`self/codegen_c2.hexa` value model. Slower (memory-resident) but
correct; optimise post-bootstrap.

- low 8B (slot+0, xLo): `tag` (4B) + 4B pad
- high 8B (slot+8, xHi): the union payload (i64 / f64 bits / pointer)
- TAG values (runtime.h): INT=0 FLOAT=1 BOOL=2 STR=3 VOID=4 ARRAY=5
  MAP=6 FN=7 CHAR=8 CLOSURE=9 VALSTRUCT=10.

Sub-units S1–S5 (S1 value/slot model · S2 call ABI + literals · S3
value-op routing · S4 residual builtins + `_main` synthesis = THE
verification gate · S5 mirror to x86_64_linux + thumbv7em). S1–S3 have
no honest per-commit verification (assemble ≠ correct for a value-model
change) — they are explicitly-labelled **structural checkpoints** of one
entangled unit whose sole correctness gate is S4's byte-diff. Tree-safety
invariant: every commit must still `clang -c` cleanly so S4 is always
reachable. S4 status + the `_main`-entry synthesis detail are in
`COMPILER.log.md`.

### Footprint — streaming per-function compilation (F1–F6)

`compiler/main.hexa` self-compiles a ~25,932-line flat-spliced
super-module; the back-half materialises **four whole-program carriers**
(`AST → HModule → MModule → LModule → asm_text`) all resident at peak,
leaking to 10–16 GB RSS. Each carrier is dead once the next phase
consumes it, but nothing frees it (the Val arena reclaims only scoped
transients). **Streaming** fuses the four per-function loops (`_lower_item`
→ `_lower_fn` → `_arm64_lower_func` → `_emit_func`) into one, so only one
function's HIR/MIR/LIR is live at a time:

```
for each item in module.items:
    arena_scope_push()
    hitem = _lower_item(it, def, atlas, module_sc)
    if hitem is fn:
        mfunc = _lower_fn(hitem)
        st    = _collect_strs_from_fn(st, mfunc)   # strtab grows incrementally
        lfunc = _arm64_lower_func(mfunc, st, modhash)
        asm_text += _emit_func(target, lfunc)      # the ONLY escaping value
    arena_scope_heapify(asm_text); arena_scope_pop()
```

Caveats handled in the refactor: strtab made incremental
(`_arm_strtab_collect_fn`), globals kept in a light pre-pass, rodata/bss
emitted after the `.text` loop, the front half (`lex/parse/resolve/bind/
types` + `lower`'s DefId pre-pass) stays whole-program so the AST is
resident for the whole loop.

| step | deliverable | status |
|------|-------------|--------|
| prereq | heapify TAG_STR O(blocks)→O(1) envelope (`f4b597a7`) | ✅ |
| F1 | `_arm_strtab_collect_fn` per-MFunc interning (`f39a3bd9`) | ✅ |
| F2 | `codegen_emit_streaming` fused per-fn loop (`2002c023`) | ✅ |
| F3 | `--stream` / `HEXA_STREAM=1` gate in `compiler/main.hexa` (`8a40b521`) | ✅ |
| F4 | array-of-fragments + `parts.join("")` — kills O(N·T) accumulator (`d39853ef`) | ✅ |
| F5 | streaming default once byte-diff verified | ⬜ needs the stage-1 build |
| F6 | per-function IR reclaim (architectural) | ⛔ structurally blocked — see below |

**F4 was re-scoped** (Finding 2026-05-16): a loop-body arena scope
reclaims only per-iteration string scratch — it cannot free the
per-function MFunc/LFunc, which are fn return values heapified to the
malloc heap by `__hexa_fn_arena_return`. Streaming bounds the *logical*
live set but not native RSS without a reclaim mechanism. The O(N·T)
`out = out + frag` accumulator is a separate, cheaply-fixable sink in
both the streaming and legacy `emit_asm` paths — F4 became its removal.

Verification rule: streaming is a **pure refactor** — `emit asm` with
and without `--stream` must be **byte-identical** `.s`; peak-RSS delta
target is < 4 GB for the stage-1 self-compile (down from 10–16 GB). The
dated F-step log + the legacy 30 GB / 3 min / exit-0 verdict-ready
fallback are in `COMPILER.log.md`.

### F6 — per-function IR reclaim (decided, then structurally blocked)

F6 is the only remaining lever that actually moves native RSS. The
gated question: *how should the streaming compiler reclaim a function's
MFunc/LFunc once emitted, given hexa-native has no GC?*

Cross-cutting hazard — **aliasing**: per-function IR shares string
storage with longer-lived structures (`st.keys ← MFunc operand strings`,
`LFunc ← st.labels`, `MFunc ← HItem/hmodule strings`, `MFunc.name ←
HItem.name`). **P0 — escape-edge discipline** is the prerequisite for
any reclaim: every reference *from* a longer-lived structure *into*
per-function IR must become an owned forced copy (`s.substring(0,len(s))`
always allocates — residency-independent). The audit closed five
string-leaf edges (P0a–P0d, P0c-2) with no arbitrary substructure
sharing (P0e clean).

Three options were weighed: **A** region-promote on return
(escape-aware heapify — principled value-model change, high blast
radius), **B** re-enable the array/struct freelist (disabled because of
the shallow-clone aliasing defect — same hazard, repo-wide), **C** a
targeted explicit-drop intrinsic (`hexa_val_free_tree`) for the
streaming loop. Decision history:

- **Decided P0-then-C** (2026-05-16, user "완성도 기준으로 선택해
  진행") — C is a bounded, fully-enumerated, per-step byte-diff-verifiable
  sequence; A is an open-ended value-model rewrite. P0a–P0d/c-2 forced
  copies all landed.
- **Pivoted to option A** (2026-05-16, user "F6 옵션 A — substantial
  별도 effort") — C *empirically failed*: runtime-level sharing
  (`hexa_str_concat` empty-elision, `struct_pack_map` inner-aliasing) is
  wider than the static string-leaf audit caught, and the resolve pass
  rejects new builtins (HX2001). A trades blast radius for safety.
- **A then structurally blocked** (2026-05-16, gdb-confirmed) — in this
  value model a hexa `struct` lowers to a **TAG_MAP**, and
  `hexa_map_set` always builds its table via `hmap_alloc(cap)` =
  `from_arena=0` = **malloc**, never arena. The dominant IR
  (LowerCtx/MFunc/LFunc) is map-backed, so a per-iteration arena POP has
  nothing to reclaim. Making F6-A work needs an arena-resident map
  subsystem (hand-rolled `hexa_map_set` against an arena table) — a
  multi-week value-model rewrite. **F6-A is the wrong lever for this
  value model.**

Net stage-3 footprint conclusion — three characterized paths:

| path | status | remaining work |
|------|--------|----------------|
| F6-A region reclaim | structurally blocked | hand-rolled arena-map subsystem (multi-week value-model) |
| ARENA=1 heapify perf | hotspot pinpointed (`hexa_val_heapify` = 92.86% of ARENA=1 compile time) | per-node arena-free seal (multi-day, ABI-sensitive) |
| x86_64 verdict ABI | diagnosed | codegen bare-name→runtime-symbol alignment (multi-day) |

The *productive* lever is **ARENA=1 perf**: the existing per-fn arena
scope already bounds the self-compile RSS 30 GB → ~12 GB (2.5×) — it
just costs ≫14× wall-time because `hexa_val_heapify` deep-copies returned
trees on every fn return. `f4b597a7` (O(1) str-envelope) was step 1; the
remaining heapify-cost reductions are bounded engineering, not a
value-model rewrite. All three remaining paths are deliberate
non-loop-tick engineering. A1–A5 region infra stays landed as dormant,
double-gated (`HEXA_STREAM_RECLAIM=1`). Dated F6 implementation status,
the gdb bug history, and the `hexa_val_heapify` gprof profile are in
`COMPILER.log.md`.

## Log

Dated cycle history moved to [`COMPILER.log.md`](./COMPILER.log.md)
(chronological spec/log split — `COMPILER.md` carries the current
compiler analysis + staged sequence, `COMPILER.log.md` carries the
append-only cycle log + the absorbed stage-3 / interp-retirement
decision history).
