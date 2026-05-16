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
| Phase 4-A-bwd baseline rerun 2026-05-17 (5-run) | `5602833f` | 12.806, 12.725, 12.575, 12.419, 12.344 | **12.574** | range 12.34-12.81, var 3.7% (fresher rerun; same code) |
| Phase 4-B-2 IPCP rewrite (5-run) | `5602833f` + IPCP | 9.727, 9.840, 9.895, 9.817, 9.793 | **9.814** | range 9.73-9.90, var 1.7%; 715 substitutions across 5 target fns; byte-identical output verified |

### `_anima_dcf` (anima d_corpus_fire, built with same hexa toolchain)

Config: identical to flame above (matches RFC 045 cross-impl test).

| Run | Wall (s) | Notes |
|---|---|---|
| (HEXA_MEM_UNLIMITED=1) 3-run | 21.34, 23.49, 21.55 | avg **22.13s**, range 21.34-23.49, var ~10% |

### Ratio: flame vs anima

**Phase 4-A-bwd**: flame 12.57s / anima 22.13s = 0.568× (flame ~57% of anima wall)
**Phase 4-B-2 IPCP**: flame 9.81s / anima 22.13s = **0.443×** (flame ~44% of anima wall)

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

## Phase 4-B-3 HexaVal boxing-elimination probe (2026-05-17)

Synthetic micro-bench (`tool/flame_phase4b3_boxing_bench.c`) measures
HexaVal-boxed vs direct-fp64 inner loop on M-Mac. Probes Phase 4-B-3
emission's expected ceiling per PHASE4B3_EMISSION_DESIGN.md mechanism #1.

Workload: Σx² over 512 elements (matches RMSNorm inner-loop shape) ×
200K reps = 204.8M ops. Both paths produce byte-identical fp result
(44.870400000000004).

| Run | boxed (s) | direct (s) | ratio |
|---|---|---|---|
| 1 | 0.3868 | 0.0969 | 3.99× |
| 2 | 0.3869 | 0.0969 | 3.99× |
| 3 | 0.3869 | 0.0969 | 3.99× |
| 4 | 0.3870 | 0.0968 | 4.00× |
| 5 | 0.3868 | 0.0968 | 4.00× |
| **avg** | **0.3868** | **0.0969** | **3.99×** |

Variance: 0.01% (effectively zero — clean measurement). Initial
PHASE4B3 estimate was 1.5-2.5× — measurement is **STRONGER**.

This validates the Phase 4-B-3 emission case before the 6-9 cycle
implementation investment: combined with allocator + fn-call
elimination (estimated), expected ceiling is 6.24× honest minimum
to 10.2× optimistic, well above RFC 047 §137 ≥3× target.

## Phase 3-I source analysis findings (cross-impl source isolation, 2026-05-17)

### Per-window gn2 decomposition (flame_d32_corpus_test, 2026-05-17)

flame 8 windows init gn2 (vs anima 7.97116 / 8 = 0.99640 per-window):

```
window 0: 0.99611    window 4: 0.996877
window 1: 0.996562   window 5: 0.996597
window 2: 0.996447   window 6: 0.995675
window 3: 0.996438   window 7: 0.996423
flame per-window avg: 0.99640  (= anima per-window 0.99640 byte-eq)
flame epoch sum: 7.97113      (vs anima 7.97116, |Δ| = 3.12e-5)
theoretical baseline: 1 - 2/V + 1/V² ≈ 0.99607 for V=256
```

Per-window cross-impl drift: ~3.9e-6 ≈ 1 ulp × 256-element softmax floor.
Epoch-sum drift: 8 × per-window-drift = 3.12e-5.

### Full-config GRAD-EXACT libm-fd 8-probe (flame_full_grad_exact_libm_test, 2026-05-17)

flame nn_decoder_grad verified correct at full d=32·3L config via libm-based central-diff (Phase 3-C scope extension):

```
probe                 analytic       rel
tok_emb[50, 7]        0.00361187     1.77e-09
gF[3]                 0.00410722     4.78e-10
block[0].g1[5]        0.00793148     2.26e-10
block[0].Wq[10]       0.00196679     9.62e-10
block[0].Wo[25]      -0.00183616     2.19e-09
block[0].Wg[5]       -0.00063807     1.85e-09
block[1].Wu[17]      -0.00199490     1.70e-09
block[2].Wd[11]       0.00191056     1.62e-10

max |Δ| abs = 6.38e-12
max rel     = 2.19e-09
```

Phase 3-C scope correction REVERSED: nn_decoder_grad correct at full d=32·3L too (verified at fp-double precision).

### dt_ln(p) atanh bias quantification (flame_dt_ln_bias_test, 2026-05-17)

dt_ln (anima d_train_lib atanh 24-term) vs libm log across CE-relevant p:

```
p          dt_ln(p)        log(p)       |Δ|         rel
1e-06     -5.14154        -13.8155      8.67        63%   ← CE clamp
1e-04     -5.13206         -9.21034     4.08        44%
4e-03     -4.79157         -5.52146     0.73        13%   ← V=256 uniform
1e-02     -4.37053         -4.60517     0.23        5.1%
5e-02     -2.99429         -2.99573     1.44e-3     0.05%
1e-01     -2.30258         -2.30259     6.17e-06    2.7e-06
3e-01+    < 1e-15          < 1e-15      < 1e-15     ← machine ε
```

dt_ln high-precision for p ≥ 0.1; 13% bias at V=256 uniform softmax; 63% at CE clamp floor (1e-6). Path implications:
  - gn2 (||softmax−onehot||²) — UNAFFECTED (no log)
  - CE-loss (−dt_ln(p_t)) — biased at small p; self-consistent across runs
  - gradient (dl = softmax−onehot) — UNAFFECTED (bypasses dt_ln)
  - trained regime (p_t → 1) — bias → 0

The 3.12e-5 epoch-sum drift uses the gn2 path → independent of dt_ln, pure source #4.

### Source attribution table (RFC 045 final)

| Source | Affects | Status |
|---|---|---|
| **#1 dt_ln atanh bias** | CE-loss-VALUE only (small p) | quantified above; flame ≡ anima algorithm; not a regression |
| **#2 nn_decoder_grad full-config gap** | gradient | **FALSIFIED** (libm-fd 8-probe max rel 2.19e-09) |
| **#3 clang FMA fusion context** | reduction order | **FALSIFIED** (Phase 3-J 7-projection routing 변동 0) |
| **#4 cross-impl reduction-order** | gn2 (per-window ~3.9e-6, epoch 3.12e-5) + gradient (~3× ratio + sign-flip) | sustained; RFC 040 §2.2 TOL_MATMUL class |

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

### Path C attempt — dV farr_matmul-routing (TESTED + REVERTED 2026-05-17)

Routed `nn_attn_core_bwd`'s dV accumulator (per-hh P^T·dctx_hh form
with T·hd ≈ 2K-output × T-reduce ≈ 16-32 inner) through `farr_matmul`,
keeping dQ/dK inline (their per-i sdot dependence resists matmul form).

Configurations swept on `flame_d32_corpus_test`:

| Test | Path C result | Inline (revert) |
|---|---|---|
| flame_phase2 F-RFC043-LAYER-EQ-ATTN-BWD | **FAIL** dV dev 1.66e-16 | PASS dV dev 0.0 |
| flame_phase3b 9-probe GRAD-EXACT | PASS max rel 3.59e-10 | PASS max rel 3.59e-10 |
| flame_phase3c 10-probe GRAD-EXACT | PASS max rel 5.14e-6 | PASS max rel 5.14e-6 |
| flame_d32_corpus init gn2 | 7.97113 (byte-eq with revert) | 7.97113 |
| flame_d32_corpus final | 8.87e-7 acc 8/8 (byte-eq) | 8.87e-7 acc 8/8 |
| flame_d32_corpus wall | 11.46s single-shot | 13.33s 5-run avg |

**Wall**: Path C single-shot 11.46s vs revert 5-run avg 13.33s. The
13.33s 5-run range was 13.03-13.93 (var ~7%); 11.46s falls 13% below
the low end. Could be genuine improvement OR low-side outlier from
single-shot measurement. PERF.md convention requires ≥5-run averaging
for sub-second-per-iter walls — not measured, so no claim filed.

**Decision**: REVERT. Phase 2 strict cross-impl byte-eq regression
(dV last-ulp drift) is unacceptable even at 1.66e-16 magnitude; the
verification tier guarantees compound across cycles, and any helper
that breaks Phase 2 must be evaluated at the IR level (RFC 047)
where reduction order can be preserved by construction.

**Lesson for RFC 047**: Phase 4-B IR pass design must either (a) operate
on the SHARED reference path so wrapper and ref share reduction order
by construction, or (b) explicitly route both sides through the same
optimized reducer (no parallel inline-vs-helper paths).

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
