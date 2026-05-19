# 💎

> Performance · resource · speed improvement ROI brainstorm for hexa-lang.
> Estimates are *ranges* — no profile run yet. Lever `0` (instrument) is the
> 0-priority action that turns every estimate below into a measured ranking.

```
At-a-glance
  pipeline : .hexa --> hexa_v2 --> C (1 TU) --> clang --> native --> run
  keystone : F — drop whole-program flatten; it is the common root of
             OOM + slow compile + zero incrementality
  do first : 0 (profile, in progress) — A already shipped, see Log
  status   : brainstorm — not yet scheduled into compiler/PLAN.md
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
| C  | content-hash C/.o cache (ccache-style) | compile speed | 1-2d* | skip recompile of unchanged modules | yes |
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

## Log

- 2026-05-20 — initial brainstorm captured (10 levers, 3 waves). Not yet
  scheduled into `compiler/PLAN.md`; promote selected levers there when a
  cycle picks them up.
- 2026-05-20 — lever `0` (profiling) underway. Finding 1: lever `A` is
  already shipped — `cmd_build` emits `clang -O2` for the transpiled C
  and `-O2` for `runtime.c` (`self/main.hexa:1910`, `:913/915`). Row `A`
  struck. Finding 2 (to confirm): `runtime.c` is recompiled at `-O2` on
  every build (one-shot link, `:1910`) — a fixed per-build cost a
  `runtime.o` cache would remove (folds into lever `C`).
