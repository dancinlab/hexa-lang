# 💎

> Performance · resource · speed improvement ROI brainstorm for hexa-lang.
>
> ★ **정공법 (orthodox path) — CONCLUSION 2026-05-20.** The measured
> bottleneck is clang (80% of build wall). Every C-path lever below
> (W1/W2/F) optimizes a *dependency on an external compiler*. The
> orthodox fix removes that dependency: emit machine code directly from
> hexa, drop the `.c` step, drop clang. This is not a new idea — it is
> hexa-lang's own stated architecture (`HEXA-NATIVE-ONLY.md`,
> `AGENTS.tape @D g5` "no third-party codegen backend"; the C path is
> "fallback, not the architecture", `@N n1`). Lever `I` is therefore
> promoted from "last / tradeoff" to THE keystone. W1/W2/F remain valid
> only as interim relief while the C fallback still exists. See the
> "정공법 — drop the C step" section below.

```
At-a-glance
  pipeline : .hexa --> hexa_v2 --> C (1 TU) --> clang --> native --> run
  정공법   : drop the C step — direct native codegen, no clang dependency
             (HEXA-NATIVE-ONLY.md / @D g5). clang = 80% of build wall.
  interim  : W1/W2/F speed the C path; relief only while the C fallback lives
  measured : clang = 80% of build wall; runtime.c recompile = 53% alone
  status   : lever 0 profiled + 정공법 recorded — not yet in compiler/PLAN.md
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

Cost is real and honest: direct codegen needs instruction selection,
register allocation, a machine-code emitter, and an object-file / linker
path for arm64 + x86_64. This is RFC-scale, multi-cycle — not a quick
win. The C path stays as the documented portability fallback during the
transition (consistent with `@F f2`: fallback C emission is allowed, it
just is not the architecture).

W1/W2/F are now explicitly interim: worth doing only as relief while the
C fallback still exists; they do not substitute for the 정공법.

## Pipeline — where the levers sit

```
.hexa source ──▶ hexa_v2 ──▶   C   ──▶  clang  ──▶ native ──▶ run
 (frontend)     transpiler   (1 TU)     (-O?)     binary
     │              │          │          │          │          │
   [H] stream     [F] split  [F] split  [A] -O2   [I] no-C    [D] arena
                  [G] incr. cache       [B] -j [C] cache     [E] clone fix
```

Key observation: the current `flatten` (all modules merged into a single C
translation unit) is the shared root of three problems — out-of-memory,
slow compile, and zero incrementality. That is why `F` is the keystone:
breaking flatten unlocks `B`, `C`, and `G` for free.

## ROI matrix — "measure first" is priority 0

| #  | Lever | Axis | Cost | Gain (estimate) | Lossless? |
|----|-------|------|------|-----------------|-----------|
| 0  | Compile profiling / instrumentation | diagnostic | 0.5d | fixes the ranking of the other 9 | yes |
| A  | ~~`clang -O2` on emitted C~~ — ALREADY SHIPPED (`self/main.hexa:1910` `cmd_build`; runtime `:913/915`). No work left. | runtime speed | done | — | — |
| B  | per-module `.c` -> `clang -j` parallel | compile speed | 1d* | compile wall / N cores | yes |
| C  | content-hash C/.o cache (ccache-style) — measured: caching `runtime.o` alone removes 53% of build wall, see W1 | compile speed | 1-2d* | skip recompile of unchanged modules | yes |
| A2 | `-O0`/`-O1` fast-dev build flag (current build is `-O2`-always) | compile speed | 0.5d | app.c clang 3.6s -> 0.7s (5x), see W2 | yes (flag-gated) |
| D  | `HEXA_VAL_ARENA` reclaim wiring | resource | 1-2d | lower memory peak on long compiles | env opt-in |
| E  | `struct_pack_map` shallow-clone gotcha fix | correctness + resource | 1d | removes bug + avoids needless clones | yes |
| F  | drop flatten -> separate compilation (keystone) | all 3 axes | 4-7d | resolves OOM + unlocks B/C/G | yes |
| G  | module-level incremental compile (on top of F) | compile speed | in F | 1-line edit: full build -> 1 module | yes |
| H  | streaming codegen (no whole-AST in memory) | resource | 5-8d | large drop in compile memory peak | yes |
| **I** | **정공법 — direct native codegen; drop `.c`, drop the clang dependency** (promoted from "last" to keystone — see section above) | all axes | RFC-scale | removes clang = removes 80% of build wall at the root | yes (self-hosted) |

`*` B and C depend on `F` (split) — neither parallelism nor caching is
possible while the build is a single flattened translation unit.

## Recommended order

**Wave 1 — cheap, lossless (~3d):** `0` profile -> `A` `-O2` flag -> `E`
clone fix. `A` alone shifts the runtime feel; the `0` profile decides
whether `D` or `H` is the higher-priority memory lever.

**Wave 2 — keystone (`F` separate compilation, ~1 week):** breaking
flatten makes `B`, `C`, and `G` follow for free. The OOM wall (full
`compiler/main.hexa` flatten exceeds memory on every host) is resolved
structurally here.

**Wave 3 — the 정공법 (`I` direct native codegen):** the orthodox fix —
drop the `.c` step, drop the clang dependency, emit machine code
directly. This is hexa-lang's stated architecture (`HEXA-NATIVE-ONLY.md`,
`@D g5`), removes the measured 80%-of-build-wall bottleneck at its root,
and is RFC-scale / multi-cycle. W1/W2/F (Waves 1-2) are interim relief on
the C path, not substitutes for it. See "정공법 — drop the C step" above.

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

1. **clang is 80% of build wall** (9.3s / 11.7s). The transpiler is cheap;
   the C compiler is the bottleneck. Levers that target `hexa_v2` (`H`,
   `I`) have a small ceiling for this build class.
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
   stays the keystone for *that* import-heavy / OOM target class only;
   monolithic builds like `self/main.hexa` do not need it.

### Re-ranked quick wins (measured, supersede pre-profile estimates)

- **W1 — cache `runtime.o`**: build it once at `-O2`, link the cached
  object. 6.2s -> ~0s amortized. Build wall 11.7s -> ~5.5s (~2x). Cost
  ~0.5d. Lossless (the runtime TU does not change between app builds).
- **W2 — `-O0`/`-O1` fast-dev flag**: `app.c` 3.6s -> 0.7s. Stacked on
  W1: 11.7s -> ~3.1s (~3.8x faster dev loop). Release builds keep `-O2`.
  Cost ~0.5d.
- `F` (flatten split) remains the keystone but is now scoped: it earns
  its cost on import-heavy / OOM targets, not on the common build.

## Log

- 2026-05-20 — initial brainstorm captured (10 levers, 3 waves). Not yet
  scheduled into `compiler/PLAN.md`; promote selected levers there when a
  cycle picks them up.
- 2026-05-20 — lever `0` (profiling) DONE — see "Lever 0 — measured
  profile" above. clang is 80% of build wall; `runtime.c` recompile
  alone is 53%. Re-ranked: W1 (`runtime.o` cache, ~2x) + W2 (`-O0` dev
  flag, stacked ~3.8x) are the measured top quick wins; lever `A`
  (`-O2`) was found already shipped.
- 2026-05-20 — 정공법 recorded (user directive). The orthodox path is
  not optimizing the C path — it is removing it. clang is an external
  dependency and the measured 80% of build wall; the orthodox fix is
  direct native codegen (drop `.c`, drop clang), which is hexa-lang's
  own stated architecture (`HEXA-NATIVE-ONLY.md`, `@D g5`). Lever `I`
  promoted to keystone; W1/W2/F demoted to interim C-path relief. Next:
  the 정공법 is RFC-scale — draft an RFC for direct CPU native codegen
  rather than scheduling W1/W2/F as the headline.
