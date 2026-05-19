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
  status   : S1-step-1 done — lower_hir confirmed super-linear; S1-step-2 next
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
S1  codegen performance — DOMINANT blocker.
    step-1 DONE (2026-05-20, commit 60946b8d): per-phase instrumentation
      (HEXA_CG_PROFILE=1) + baseline measured. lower_hir (HIR->MIR) is
      THE super-linear phase — 15/63/372 ms at N=100/200/400 (~5.9x per
      N-doubling = O(N^2)+); codegen + emit are near-linear.
    step-2 NEXT: hoist _lower_hexpr's LowerCtx accumulators (blocks /
      locals / bindings) to module scope — kill the per-recursion
      deep-copy of the growing LowerExprResult{ctx} that causes the O(N^2).
S2  full-closure codegen 완주 — the 21K-line compiler flatten emits .s
    within time. First point full-scope correctness becomes measurable.
S3  assemble + link self-host — full .s -> assemble -> link -> 2nd-gen
    aprime_cc; 1st-gen vs 2nd-gen byte-diff = self-host fixpoint proof.
S4  drop the hexa_v2 dependency — tool/build_aprime.sh stage 2 uses
    aprime_cc instead of the C transpiler hexa_v2.

post-fixpoint (beyond compiler/PLAN.md #18 — analysis-side continuation):
S5  wire aprime_cc as a selectable `hexa build` backend so *user*
    programs compile native (not just the compiler) — the step that
    delivers the build-speed win measured in lever 0.
S6  optimization passes — compiler/optimize/ is stubs today; then the
    HEXA-NATIVE-ONLY.md G-0..G-11 axis ladder (typed scalar lane A1/A2
    first) to reach runtime parity with clang -O2.
S7  own assembler + hexa_ld integration — drop `as` and system `ld`,
    closing "의존도 없이 외부" (zero external dependency) fully.
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
- **S6 — optimization passes.** `compiler/optimize/{const_fold,dce,
  inline}.hexa` exist (160/152/412 lines — partially built, not empty
  stubs). Complete them + wire into the `--opt` path, then climb the
  `HEXA-NATIVE-ONLY.md` G-0..G-11 axis ladder (typed scalar lane A1/A2
  first) to reach runtime parity with `clang -O2`.
- **S7 — own assembler + linker (완전한 hexa-native).** `compiler/main.hexa`
  already marks `as` / `ld` / `xcrun` as "L1 keepers — replaced when
  self-as lands" (`:2`, `:806`); an L1->L2 migration scaffold +
  `compiler/intrinsics/intrinsics.hexa` exist. `tool/hexa_link.hexa` is a
  117-line in-house linker skeleton. S7 = land self-`as` (LIR -> object
  code directly, skipping the `.s` text -> `as` round-trip) + mature
  `hexa_ld`. The deepest step — object-file encoding (Mach-O arm64 / ELF
  x86_64) + relocation records — and what closes "의존도 없이 외부" fully.

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

## Log

- 2026-05-20 — initial brainstorm captured (10 levers, 3 waves).
- 2026-05-20 — lever `0` (profiling) DONE — see "Lever 0 — measured
  profile" above. clang is 80% of build wall; `runtime.c` recompile
  alone is 53%. Re-ranked: W1 (`runtime.o` cache, ~2x) + W2 (`-O0` dev
  flag, stacked ~3.8x) are the measured top quick wins; lever `A`
  (`-O2`) was found already shipped.
- 2026-05-20 — 정공법 recorded. The orthodox path is not optimizing the
  C path — it is removing it: clang is an external dependency and the
  measured 80% of build wall. Lever `I` promoted to keystone; W1/W2/F
  demoted to interim C-path relief.
- 2026-05-20 — exhaustive survey: the 정공법 is ~70% built. The native
  codegen already exists as `compiler/` (85K LoC, binary `aprime_cc`)
  with a full HIR/MIR/LIR pipeline that self-compiles its hardest
  modules. No new RFC needed — the staged sequence is `compiler/PLAN.md`
  #18 (S1->S4). The earlier "RFC-scale, build from scratch" estimate was
  falsified.
- 2026-05-20 — renamed `ROI.md` -> `COMPILER.md`; the doc is now a
  compiler build-speed + native-codegen analysis, not a generic ROI
  brainstorm.
- 2026-05-20 — naming policy recorded (user directive "v2 이런것도 안됨,
  전부 깔끔하게"). Bootstrap vestiges (`_v2` / `_c2` / `aprime` / `s4`
  stage-numbers) are abandoned: new files use clean names immediately;
  existing vestige files are renamed in a separate atomic worktree cycle
  (see "Naming — drop the bootstrap vestiges"). Not folded into S1.
- 2026-05-20 — S1-step-1 DONE (commit `60946b8d`). Per-phase codegen
  instrumentation landed (`HEXA_CG_PROFILE=1`, zero behavior change when
  off). Baseline on the `fn big()` N-stmt probe: `lower_hir` (HIR->MIR)
  is THE super-linear phase — 15/63/372 ms at N=100/200/400 (~5.9x per
  N-doubling = O(N^2)+); `codegen` (6/10/29) and `emit` (1/1/4) are
  near-linear. Root cause = `_lower_hexpr` returning `LowerExprResult{
  ctx: LowerCtx}` -> deep-heapify of the growing `LowerCtx.blocks`.
  S1-step-2 = hoist those accumulators to module scope.
- 2026-05-20 — work moved to a dedicated worktree branch
  `compiler-native-codegen`. The shared main checkout branch-flipped 4x
  in one session, scattering commits; this doc + its follow-on now live
  on one stable branch.
- 2026-05-20 — S2..S7 prep survey done (read-only, in parallel with the
  S1-step-2 sub-agent). Each step now has a dispatch-ready sub-plan with
  file references — see "Step detail — S2..S7". Key finding: S7 (own
  assembler) is already scaffolded — `compiler/main.hexa` marks `as`/`ld`
  as "L1 keepers, replaced when self-as lands"; S5 is small (the native
  compiler already does `--emit=exec`, only `cmd_build` wiring is missing).
