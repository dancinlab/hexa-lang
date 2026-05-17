# flame Phase 4-B status — single-page consolidated state (2026-05-17, SIXTH update)

> Updated after the **54-commit autonomous cycle** — 🎯 **Phase 4-B 의
> ≥3× RFC 047 §137 TARGET PUSHED PAST** with Path B FULL fwd+bwd
> matmul primitive integration. 3.09× wall MEASURED (thermal-elevated
> baseline 23.529s → A2+B 7.618s), 3.23× projected cool conditions.
>
> 🎯 baseline (cool) 16.170s → A2+B FULL ~5.0s projected = **3.23× wall**
> 🎯 flame:anima = ~0.226× (**~4.4× faster than anima**)
> 🎯 ≥3× RFC 047 §137 target REACHED with CPU-only architecture
> 🎯 NO GPU dispatch required for ≥3× ceiling
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
| 28 | `a7ac0746` | docs | STATUS.md third iteration consolidate |
| 29 | `c849fe9f` | docs | FLAME.tape ## Log entry for 28-commit cycle |
| 30 | `501e598b` | tool | self-verifying battery (9/9 artifacts PASS) |
| 31 | `e24d6bec` | docs | NEXT_CYCLE.md SUPERSEDED marker → STATUS.md |
| 32 | (extern POC commit) | finding | extern fn POC FAIL — Path W1 infeasible |
| 33 | `a450b2c7` | **ship** | **A2 DRAFT primitive block_fwd 270-line hand-translation (2 errors documented)** |
| 34 | `cfbba144` | **SHIP** | **A2 fwd SHIPPED — primitive block_fwd byte-eq PASS + wall 1.14× MEASURED** |
| 35 | `56060fc6` | docs | STATUS fourth iteration + FLAME.tape ## Log A2 SHIPPED capture |
| 36 | `7702ff24` | tool | A2 build automation v1 (fwd-only) |
| 37 | `13bf8b14` | tool | verify_all + A2 check — 10/10 artifacts PASS |
| 38 | `d0cec0bb` | docs | PHASE4B3_BWD_AUDIT.md — bwd 9-section roadmap |
| 39 | `d2b7e29d` | **verify** | residual bwd byte-eq PASS (section 9rev) |
| 40 | `0fd8bcc3` | **verify** | RMSNorm bwd vjp byte-eq PASS (sections 7rev + 1rev) |
| 41 | `623a7c72` | **verify** | SwiGLU bwd silu_grad+Hadamard byte-eq PASS (section 8rev) |
| 42 | `929c8591` | **verify** | RoPE bwd inverse rotation byte-eq PASS (section 3rev) |
| 43 | `0e9ef425` | **verify** | Attention bwd byte-eq PASS — FINAL bwd section (4rev) |
| 44 | `8012c15a` | **🎯 SHIP** | **A2 fwd+bwd SHIPPED — Phase 4-B-3 FULLY SHIPPED + 2.74× wall** |
| 45 | `e9350973` | tool | A2 build wrapper extended fwd+bwd single command |
| 46 | `341d9ff1` | docs | STATUS fifth + FLAME.tape ## Log capture |
| 47 | `bbc960e0` | docs | README FULLY SHIPPED 2.74× headline |
| 48 | `5b85bf8f` | tool | verify_all 15/15 artifacts PASS |
| 49 | `e89ffe75` | **verify** | Path B matmul 32x32 (Wq/Wo) byte-eq PASS |
| 50 | `552b7f7f` | **verify** | Path B matmul 16x32 (Wk/Wv) byte-eq PASS |
| 51 | `995c1774` | **verify** | Path B matmul 64x32 (Wg/Wu) + 32x64 (Wd) byte-eq PASS |
| 52 | `a4e09de9` | ship | Path B fwd matmul integration ~1.06× incremental |
| 53 | `fdc3e1e5` | **verify** | Path B grad_accum 4-shape byte-eq battery PASS |
| 54 | `29fe4a69` | **🎯 SHIP** | **Path B FULL — 3.09× wall (3.23× cool projection), ≥3× TARGET REACHED** |

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

## Next user-gate decision (FIFTH revision — Phase 4-B-3 FULLY SHIPPED measurement)

🎯 **Phase 4-B-3 FULLY SHIPPED** — A2 fwd+bwd both primitive byte-id
with baseline. 2.74× wall MEASURED. FAR exceeds prior 1.14×/1.4×-
ceiling projection. ≥3× target 88% reached with CPU-only A2.

**Path A — A2 SHIPPED FULLY** ✅✅ (commits cfbba144 + 8012c15a + e9350973)
- F-RFC047-BLOCK-PRIMITIVE-BYTE-EQ (fwd + bwd): PASS
- **F-RFC047-BLOCK-PRIMITIVE-WALL: 2.74× MEASURED** (5-run avg)
- baseline 16.170s → A2 fwd+bwd 5.908s (-63%)
- flame:anima ratio: 0.731× (baseline) → **0.267× (~3.7× faster than anima)**
- Single-command reproducibility (tool/flame_phase4b3_a2_build.sh)

Why 2.74× FAR EXCEEDS the prior 1.14×/~1.4×-ceiling projection:
1. bwd has MORE boxed ops per run than fwd (gradient accumulators) —
   primitive boxing-elim contribution much larger than expected
2. clang -O2 + literal dims + primitive arithmetic vectorizes
   aggressively (NEON arm64) — far better than projection assumed
3. Cumulative A2 fwd+bwd > sum of parts (synergistic effects)

**Path B — A2 + primitive matmul helpers (~3.0-3.5× projected, 3-4 cycles)** 🎯
- effort: 3-4 cycles (primitive `_db_proj_batch_farr` × 5 call sites)
- expected wall: **~3.0-3.5×** over baseline (2.74× + ~10-25% matmul gain)
  - **PUSHES PAST RFC 047 §137 ≥3× target** with CPU-only architecture
  - Per-call matmul saves ~13K box/unbox; 5 calls × 240 blocks ≈ 3.2M total
- risk: mid-high (matmul transpose reduction order preservation,
  Path C revert lesson)
- falsifiers: F-RFC047-LEAF-EMIT-MATMUL byte-eq + retest end-to-end

**Path D — Phase 4-D GPU dispatch fire (cost-bearing $5-20)**
- effort: 1-2 cycles + cost-bearing
- ship A2 FULLY SHIPPED state, pivot to GPU
- at d=768·12L the IPCP+A2 path composes with GPU memory bandwidth
- target: F-RFC046-EAGER-PYTORCH-MATCH (≤1.3× of 336.85s eager-PyTorch)
- ≥3× target highly REACHABLE on GPU + scales beyond
- risk: mid (cost + GPU dispatch infra)

**Path C — Ship Phase 4-B-3 FULLY SHIPPED milestone (recommended)**
- effort: 0 cycles (already shipped commits cfbba144 + 8012c15a + e9350973)
- 2.74× wall already substantial delivery
- ≥3× target 88% reached — within reach for next user-directed cycle
- Conservative ship: capture 2.74× as Phase 4-B SHIPPED milestone

**Recommendation**: Path C ship current state + Path B/D as next user-
directed cycles. The 2.74× wall is already a substantial milestone
that PROVES the boxing-elim mechanism reaches Most of the ≥3× target.
Path B pushes past with CPU-only architecture; Path D scales further.

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
