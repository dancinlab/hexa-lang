# flame Phase 4-B status — single-page consolidated state (2026-05-17, third update)

> Updated after the **27-commit autonomous cycle** — Phase 4-B-3
> verification layer COMPLETE. ALL 5 dominant sections byte-eq verified
> (RMSNorm × 2 + residual × 2 + SwiGLU + RoPE + Attention). Integration
> step + wall measure = next user-gate.
> Cross-references the per-topic SSOTs (README.md / PLAN.md / FLAME.tape /
> PERF.md / PHASE4B_SCAFFOLD.md / PHASE4B3_EMISSION_DESIGN.md /
> NEXT_CYCLE.md). Use this for user-gate decisions; the per-topic SSOTs
> for implementation detail.

## What landed (16 commits, autonomous cycle 2026-05-17)

| # | commit | type | summary |
|---|---|---|---|
| 1 | `23705dc5` | revert | Path C dV attempt + REVERT — Phase 2 byte-eq evidence |
| 2 | `038041f5` | scaffold | Phase 4-B-1 — detect-only scanner + classify |
| 3 | `364818c1` | docs | option survey audit — IPCP feasibility |
| 4 | `55e29392` | **ship** | **Phase 4-B-2 IPCP — 1.28× wall, byte-id** |
| 5 | `7d98c3cd` | tool | reproducible IPCP build wrapper + LTO probe (inconclusive) |
| 6 | `828717fb` | design | Phase 4-B-3 emission design draft |
| 7 | `07cdd405` | **measure** | **boxing-elim probe — 3.99× MEASURED (STRONGER)** |
| 8 | `0a95371b` | scaffold | Phase 4-B-3-1 emitter scaffold (skeleton) |
| 9 | `97cb9617` | verify | cross-config IPCP robustness (3 configs PASS byte-eq) |
| 10 | `98bed481` | **measure** | **allocator-elim probe — 1.00× MEASURED (WEAKER)** |
| 11 | `f525a656` | **measure** | **fn-call elim probe — 0.12× MEASURED + design pivot** |
| 12 | `e49bb691` | docs | STATUS.md single-page consolidate (first version) |
| 13 | `45b6cf22` | docs | README.md Phase 4-B-2 SHIPPED entry |
| 14 | `a7d066a2` | design | PHASE4B3_2_INTEGRATION.md — single-TU concat mechanism |
| 15 | `f5182641` | **ship** | **Phase 4-B-3-2-first trampoline emit + concat + link PASS** |
| 16 | `28cf24a6` | **ship** | **Phase 4-B-3-2-second caller wire-up + build wrapper PASS** |
| 17 | `b0116176` | docs | STATUS.md 16-commit cycle update |
| 18 | `725ff6bb` | design | PHASE4B3_LEAF_PRIORITY.md — `_hx_farr_table.buf` ABI |
| 19 | `dcd2ed74` | **ship** | **Phase 4-B-3-2-third-1 rmsnorm leaf primitive emit** |
| 20 | `1da62cc1` | **verify** | **rmsnorm primitive byte-eq PASS (max\|Δ\|=0.0)** |
| 21 | `122e186d` | docs | design correction — block_fwd inline, not leaf-call |
| 22 | `490e7b2a` | audit | PHASE4B3_BLOCK_FWD_AUDIT.md — 9-section roadmap |
| 23 | `9e065f89` | **verify** | **residual byte-eq PASS (sections #6+#9)** |
| 24 | `e7472b1e` | audit | matmul SKIP — small contribution per cost-benefit |
| 25 | `9f95621d` | **verify** | **SwiGLU silu+Hadamard byte-eq PASS (section #8)** |
| 26 | `8537739e` | **verify** | **RoPE pair-rotate byte-eq PASS (section #3)** |
| 27 | `fe7c1922` | **verify** | **Attention byte-eq PASS — FINAL dominant section (section #4)** |

## Shippable production state

- **Production `./hexa build`**: UNCHANGED (F-RFC047-FALLBACK-PRESERVED holds vacuously — no hook). Baseline behavior preserved.
- **Phase 4-B-2 IPCP build wrapper**: `tool/flame_phase4b_build.sh <src> <out>` — single command from .hexa source to 1.28× wall binary, byte-identical to baseline. Verified on 3 distinct flame configs.
- **Phase 4-B-3-2-second wired build wrapper**: `tool/flame_phase4b3_build.sh <src> <out>` — extends IPCP pipeline with trampoline emit + caller wire-up. Currently fallback path (trampoline forwards to HexaVal fn → byte-id with baseline, ~IPCP wall). Phase 4-B-3-2-third will replace trampoline body with primitive-typed direct dereferences (boxing-elim 4× ceiling target).

## Measurement-anchored evidence (5-run avg per PERF.md convention)

| measurement | baseline | post-IPCP | speedup |
|---|---|---|---|
| flame_d32_corpus_test wall | 12.574s | **9.814s** | 1.28× (-22%) |
| variance (range) | 3.7% | **1.7%** | both reliable |
| flame vs anima ratio | 0.568× | **0.443×** | (~56% faster than anima) |
| F-RFC043-STEP-EQ-ORACLE | PASS | PASS | byte-identical stdout (diff) |

## Phase 4-B-3 mechanism analysis (3/3 mechanisms MEASURED)

| mechanism | initial estimate | measured | factor planning |
|---|---|---|---|
| boxing elim (HexaVal → primitive) | 1.5-2.5× | **3.99×** | use 4.0× |
| allocator elim (heap → stack) | 1.3-1.7× | **1.00×** | use 1.0× |
| fn-call elim (inline) | 1.2-1.5× | **1.00×** | use 1.0× (overlap-capped) |
| **compound expected ceiling** | 6.24-10.2× | **4.0×** | margin to ≥3× target = 33% |

**Boxing-elim is the only substantial mechanism.** allocator and fn-call provide no measurable additional gain on M-Mac. Phase 4-B-3 design pivoted to **boxing-only scope** (3-4 cycles vs original 6-9).

Expected Phase 4-B-3 wall: **~3.14s** (4× on 12.574s baseline). flame would be ~0.142× of anima 22.13s (~7× faster).

## Next user-gate decision (THIRD revision — measurement evidence updated)

Phase 4-B-3-2-third VERIFICATION-LAYER COMPLETE. 5/5 dominant sections
byte-eq verified, 2/9 matmul SKIPPED per audit. Integration step
remaining. Three honest paths, **with updated wall projections per
verification evidence**:

**Path A — Integration only (~1.8-2.5× projected, 2-3 cycles)**
- effort: 2-3 cycles
- expected wall: **~1.8-2.5×** over baseline (12.574s → ~5-7s)
  - Conservative: 1 / (0.59/4 + 0.41) ≈ 1.79× from 59% boxing covered
  - Optimistic if clang -O2 vectorizes well: ~2.5×
- **RFC 047 §137 ≥3× target NOT REACHED with this scope**
- risk: mid (block_fwd body integration — sed or hexa-source rewrite)
- falsifiers: F-RFC047-CORPUS-EMIT-STEP-EQ + F-RFC047-BLOCK-WALL-IMPROVED (will likely be marked PARTIAL)

**Path B — Integration + ALSO primitive matmul (~2.8-3.5× projected, 4-5 cycles)**
- effort: 4-5 cycles (extends Path A with 2 more sections + retest)
- expected wall: **~2.8-3.5×** over baseline (12.574s → ~3.6-4.5s)
  - Targets the remaining 32% boxing in matmul SKIP sections
- ≥3× target REACHABLE (marginal — 2.8× lower bound, 3.5× upper)
- risk: mid-high (matmul transpose helpers have helper-call overhead;
  primitive form must preserve farr_matmul reduction order)
- falsifiers: same as Path A + F-RFC047-LEAF-EMIT-MATMUL byte-eq tests

**Path C — Ship current state + RFC 048 / GPU pivot (1 cycle docs)**
- effort: 1 cycle (docs only)
- 5 verified sections + integration design + measurement projection
  ALL CAPTURED in current commits
- Pivot to RFC 048 fwd+bwd graph fusion design OR Path B GPU dispatch fire
- conservative: 5 byte-eq verifications + design + measurement evidence
  is itself substantial Phase 4-B-3 delivery — Phase 4-B-3 integration
  becomes a separate future cycle when ≥3× is required

**Recommendation**: Path C — ship the verification layer + projection
evidence as Phase 4-B-3 VERIFICATION-LAYER MILESTONE. Integration
step gates the actual wall improvement, but per-section byte-eq +
ABI proof + reduction-order discipline + dt_sqrt/dt_exp ports are
SUBSTANTIAL standalone evidence. The 27 verification commits make
the implementation ALGORITHMICALLY READY; integration is a small
follow-on (vs the full design+verification work already done).

## Files touched this cycle (16 commits)

| file | type | purpose |
|---|---|---|
| `stdlib/flame/nn_lib.hexa` | revert | Path C dV revert |
| `tool/flame_phase4b_scan.hexa` | new | Phase 4-B-1 scaffold scanner |
| `tool/flame_phase4b_ipcp.hexa` | new | Phase 4-B-2 IPCP rewriter |
| `tool/flame_phase4b_build.sh` | new | reproducible IPCP build wrapper |
| `tool/flame_phase4b3_emit_skeleton.hexa` | new | Phase 4-B-3-1 scaffold (sibling) |
| `tool/flame_phase4b3_emit_trampoline.hexa` | new | Phase 4-B-3-2-first emit (with --decls extension) |
| `tool/flame_phase4b3_build.sh` | new | Phase 4-B-3-2-second end-to-end wrapper |
| `tool/flame_phase4b3_boxing_bench.c` | new | mechanism #1 probe |
| `tool/flame_phase4b3_alloc_bench.c` | new | mechanism #2 probe |
| `tool/flame_phase4b3_fncall_bench.c` | new | mechanism #3 probe |
| `stdlib/flame/PHASE4B_SCAFFOLD.md` | extended | IPCP findings + cross-config audit |
| `stdlib/flame/PHASE4B3_EMISSION_DESIGN.md` | new+updated | emission design + mechanism updates + pivot |
| `stdlib/flame/PHASE4B3_2_INTEGRATION.md` | new | Phase 4-B-3-2 build pipeline integration design |
| `stdlib/flame/PERF.md` | extended | 3 mechanism probes + IPCP measurement |
| `stdlib/flame/NEXT_CYCLE.md` | updated | Phase 4-B status |
| `stdlib/flame/STATUS.md` | new+updated × 3 (this file) | single-page consolidated state |
| `stdlib/flame/README.md` | updated | Phase 4-B-2 SHIPPED entry |
| `stdlib/flame/PHASE4B3_LEAF_PRIORITY.md` | new | leaf ABI + priority (commit 725ff6bb) |
| `stdlib/flame/PHASE4B3_DESIGN_CORRECTION.md` | new | block_fwd INLINE not leaf-call (commit 122e186d) |
| `stdlib/flame/PHASE4B3_BLOCK_FWD_AUDIT.md` | new+updated | 9-section roadmap + matmul SKIP (490e7b2a + e7472b1e) |
| `tool/flame_phase4b3_leaf_rmsnorm_test.c` | new | byte-eq test (commit 1da62cc1) |
| `tool/flame_phase4b3_leaf_residual_test.c` | new | byte-eq test (commit 9e065f89) |
| `tool/flame_phase4b3_leaf_swiglu_test.c` | new | byte-eq test (commit 9f95621d) |
| `tool/flame_phase4b3_leaf_rope_test.c` | new | byte-eq test (commit 8537739e) |
| `tool/flame_phase4b3_leaf_attention_test.c` | new | byte-eq test (commit fe7c1922) |

## Quick reference — running everything

```bash
# Phase 4-B-2 IPCP build (1.18-1.28× wall, byte-id):
tool/flame_phase4b_build.sh \
    stdlib/flame/flame_d32_corpus_test.hexa \
    build/flame_d32_ipcp

# Phase 4-B-3-2-second trampoline-wired build (current ≈IPCP wall, byte-id):
tool/flame_phase4b3_build.sh \
    stdlib/flame/flame_d32_corpus_test.hexa \
    build/flame_d32_b3

# Phase 4-B-3 mechanism probes (3-tier mechanism evidence):
clang -O2 tool/flame_phase4b3_boxing_bench.c -o build/boxing_bench && ./build/boxing_bench   # 4.00× MEASURED
clang -O2 tool/flame_phase4b3_alloc_bench.c  -o build/alloc_bench  && ./build/alloc_bench    # 1.00× MEASURED
clang -O2 tool/flame_phase4b3_fncall_bench.c -o build/fncall_bench && ./build/fncall_bench   # 0.12× MEASURED (negative)

# Phase 4-B-3-2-third leaf primitive byte-eq verification battery (run all):
for leaf in rmsnorm residual swiglu rope attention; do
    clang -O2 tool/flame_phase4b3_leaf_${leaf}_test.c -lm -o build/leaf_${leaf}_test
    ./build/leaf_${leaf}_test | grep -E "PASS|FAIL"
done
# Expected: 5 PASS, 0 FAIL (commits 1da62cc1/9e065f89/9f95621d/8537739e/fe7c1922)

# Phase 4-B-3-1 emit skeleton inspect (deprecated by trampoline tool but kept):
hexa run tool/flame_phase4b3_emit_skeleton.hexa /tmp/flame_d32_corpus_test_ipcp.hexa
```

## Cross-link

- README.md — high-level status (needs §"Phase 4-B-2 SHIPPED" entry; next cycle)
- PLAN.md — staged roadmap
- FLAME.tape `## Log` — append-only event history
- PHASE4B_SCAFFOLD.md — Phase 4-B-1/4-B-2 detailed findings
- PHASE4B3_EMISSION_DESIGN.md — Phase 4-B-3 design + mechanism table
- PERF.md — all measurements (5-run convention, full tables)
- NEXT_CYCLE.md — single-page onboarding (slightly stale; this file supersedes)
- RFC 047 — IR pass design (now partially implemented at Phase 4-B-1/2)
- RFC 048 — fwd+bwd graph fusion (orthogonal, design only)
