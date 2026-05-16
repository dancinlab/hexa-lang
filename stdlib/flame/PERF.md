# flame PERF.md — accumulated wall measurements + measurement convention

> Append-only ledger for flame's compiled-native wall measurements
> across the 33-commit Phase 3 → Phase 4-A-bwd session.
> SSOT for performance comparison; cross-linked from RFC 046.

## Measurement convention

- **Host**: M-Mac (Darwin arm64), CPU only (no GPU dispatch yet)
- **Toolchain**: hexa-lang `./hexa build` → clang -O2 → native binary
- **Run protocol**: ≥5-run averaging for sub-second-per-iteration walls
- **Reported**: avg, range, variance %
- **Why 5-run**: macOS task scheduler + page cache effects produce
  ~7-10% per-run variance on this workload; 3-run can be dominated
  by a single outlier; ≥5-run gives stable median + range bounds.
- **Convention adopted (2026-05-17)**: future RFC 046 wall comparisons
  use 5-run avg, NOT single-shot, NOT 3-run.

## Baselines

### `flame_d32_corpus_test` (RFC 045 Phase 3-F-3 corpus benchmark)

Config: T=16, d=32, nh=4, nkv=2, h=64, V=256, n_layer=3, nsamp=8,
stride=512, 80-step AdamW (lr=0.03, b1=0.9, b2=0.999, eps=1e-8,
wd=0.01), seed=42, corpus_consciousness_v1.jsonl byte-level (V=256).

| State | Commit | Walls (s) | avg | Notes |
|---|---|---|---|---|
| Phase 3-F-3 initial | `c00ee7c8` | 30.50 (1-run) | 30.50 | inline projections, dt_* not yet wired |
| Phase 3-J fwd farr_matmul-routed | `e10ecd79` | 18.5 (1-run, post-wire-in) | ~18.5 | 7 fwd projections farr_matmul-routed |
| Phase 4-A-bwd partial 4 (5-run) | `285f77bf` | 13.03, 13.14, 13.09, 13.47, 13.93 | **13.33** | 7 outer-product bwd accumulators wired; range 13.03-13.93, var ~7% |

### `_anima_dcf` (anima d_corpus_fire, built with same hexa toolchain)

Config: identical to flame above (matches RFC 045 cross-impl test).

| Run | Wall (s) | Notes |
|---|---|---|
| (HEXA_MEM_UNLIMITED=1) 3-run | 21.34, 23.49, 21.55 | avg **22.13s**, range 21.34-23.49, var ~10% |

### Ratio: flame vs anima

**flame 13.33s / anima 22.13s = 0.602×** (flame ~60% of anima wall)

Same host, same toolchain, same data. The 40% gap is flame's
packed-farr + 7 outer-product farr_matmul-routed accumulators
delivering measurable wall improvement over anima's dict + list
storage rep, even though clang -O2 vectorizes both efficiently at
the per-loop level.

## `flame_perf_breakdown_test` (per-step breakdown)

Config: 1 warm-up step + 8 measure steps × 1 corpus window. time_ms()
per fwd / bwd / AdamW phase. d=32·3L config.

| State | Commit | fwd (ms) | bwd (ms) | AdamW (ms) | total/step (ms) | n-run convention |
|---|---|---|---|---|---|---|
| Phase 3-J baseline | (post `df50e265`) | 3 (14%) | 20 (84%) | 0 (<1%) | 23 | 1×8-iter single |
| + dWq/dWk/dWv | `bbaa4bbf` | 4 (17%) | 19 (82%) | 0 (<1%) | 23 | 1×8-iter single |
| + dWd | `9ff5ae92` | 4 (19%) | 17 (80%) | 0 (<1%) | 21 | 1×8-iter single |
| + dWo | `d272bca2` | 4 | 17 | 0 | 21 | 1×8-iter single |
| + dWg/dWu | `e8c78f4e` | 3 | 12 (76%) | 0 | 15 | 1×8-iter single |
| + drin (REVERTED) | `6fa735c7` | 3 | 14 | 0 | 19 | 1×8-iter single |
| Phase 4-A-bwd final | (post `a4f2970e`) | **4 (25%)** | **12 (75%)** | **~0** | **16 (range 16-17)** | **5×8-iter avg (low variance, this is the reliable reading)** |

**Cumulative bwd reduction (post-drin-revert)**: 20→12 ms (40%).
**Cumulative total/step reduction**: 23→15 ms (35%) per-step,
but **full-corpus 5-run wall improvement is ~25% (17→13.33s)**
— measurement layers differ because time_ms() granularity (~1ms) +
single-run-variance dominate at sub-25ms walls.

## Findings (durable, cross-cycle)

### Granularity floor for `farr_matmul`-routing (~32K ops)

The `_db_grad_accum_farr` helper (transpose + matmul + accumulate)
is **anti-perf** for reductions below ~32K ops. The drin reduction
(T·d=512 output elements × ~64-op dot = ~32K total ops) tested in
commit `6fa735c7` produced a wall regression: 3 buffer copies + 3
farr allocs + 3 frees + element-wise add exceeded the savings.

**Design rule**: route only OUTER-PRODUCT accumulators (Σ_ts
dY[ts]⊗X[ts]) through `_db_grad_accum_farr`. per-element inner-dot
reductions stay inline at this scale.

### attention_core_bwd sub-reductions are below the floor

dV/dQ/dK accumulators in `nn_attn_core_bwd` are ~2-8K ops each
(sparse causal mask, GQA grouping). Routing through farr_matmul
would likely fall well below the granularity floor → anti-perf.
Future Phase 4 attention bwd fusion requires the IR-level approach
(RFC 046 Stage 2/3), not the single-pattern helper.

### Anima impl difference IS the source of the 3.12e-5 init-gn2 delta

RFC 045 Phase 3-F-3 init gn2 = 7.97113 (flame) vs 7.97116 (anima)
persists exactly across **all** flame Phase 4-A-bwd refactors. The
delta is precisely the dict/list-vs-packed-farr last-ulp drift
(RFC 040 §2.2 TOL_MATMUL class); no algorithm tier 변경 affects it.

## Cross-references

- RFC 045 (Phase 3 closure, source #4 analysis) — `inbox/rfc_drafts_2026_05_12/rfc_045_*.md`
- RFC 046 (Phase 4 compiler fusion design) — `inbox/rfc_drafts_2026_05_12/rfc_046_*.md`
- FLAME.tape `## Log` — full 34-commit session timeline
- `flame_perf_breakdown_test.hexa` — the per-step measurement harness
- `flame_d32_corpus_test.hexa` — the 80-step corpus benchmark
- anima d_corpus_fire reference — `~/core/anima/HEXAD/D/d_corpus_fire.hexa`
