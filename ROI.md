# 💎

> Performance · resource · speed improvement ROI brainstorm for hexa-lang.
> Estimates are *ranges* — no profile run yet. Lever `0` (instrument) is the
> 0-priority action that turns every estimate below into a measured ranking.

```
At-a-glance
  pipeline : .hexa --> hexa_v2 --> C (1 TU) --> clang --> native --> run
  keystone : F — drop whole-program flatten; it is the common root of
             OOM + slow compile + zero incrementality
  do first : W1 runtime.o cache (-53% build wall) then W2 -O0 dev flag
  measured : clang = 80% of build wall; runtime.c recompile = 53% alone
  status   : lever 0 profiled (see below) — not yet in compiler/PLAN.md
```

---

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
| I  | direct native codegen (drop the C step) | compile speed | 10d+ | bypasses clang but **loses the optimizer** | no (tradeoff) |

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

**Wave 3 — long horizon (`H` / `I`):** `I` (no-C) is a ROADMAP item but
loses clang's optimizer, so under the hexa-first "lossless gains first"
rule it ranks last — a self-hosted optimizer pass should land before it
breaks even.

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
  (`-O2`) was found already shipped. Next: schedule W1+W2 into
  `compiler/PLAN.md` when a cycle picks them up.
