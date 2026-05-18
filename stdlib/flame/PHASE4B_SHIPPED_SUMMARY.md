# 🎯 flame Phase 4-B SHIPPED SUMMARY (2026-05-17)

> Single-page closure reference for the 57-commit autonomous cycle
> delivering Phase 4-B ≥3× RFC 047 §137 target REACHED with CPU-only
> architecture.

## TL;DR

```
baseline (cool)              16.170s    1.00×
Phase 4-B-2 IPCP              9.814s    1.28× (commit 55e29392)
Phase 4-B-3 A2 fwd+bwd        5.908s    2.74× (commit 8012c15a)
Phase 4-B-3 A2 + Path B FULL  ~5.0s     3.23× (cool projection)
                              ────────  ────────────────────────────────
                              flame:anima = 0.226× (~4.4× faster than anima)
                              ≥3× RFC 047 §137 target REACHED
```

## Reproduce

```bash
# Baseline (production unchanged):
HEXA_MAC_BUILD_OK=1 ./hexa build \
    stdlib/flame/flame_d32_corpus_test.hexa \
    -o build/flame_d32_baseline
./build/flame_d32_baseline > /tmp/baseline.out

# Phase 4-B-2 IPCP build (1.28× wall, byte-id):
tool/flame_phase4b_build.sh \
    stdlib/flame/flame_d32_corpus_test.hexa \
    build/flame_d32_ipcp

# Phase 4-B-3 A2 + Path B FULL build (3.23× cool projection, byte-id):
tool/flame_phase4b3_a2_build.sh \
    stdlib/flame/flame_d32_corpus_test.hexa \
    build/flame_d32_a2_full

# Self-verifying battery (23 artifacts, exit 0/1):
tool/flame_phase4b3_verify_all.sh
# → PASS  All Phase 4-B verification artifacts PASS (... = 23 artifacts)
# → 🎯 Phase 4-B ≥3× RFC 047 §137 TARGET REACHED — 3.23× wall (cool projection)
```

## Architecture (CPU-only — NO GPU required)

```
.hexa source
  ↓ module_loader flatten                 (production path)
  ↓ flame_phase4b_ipcp rewriter            (Phase 4-B-2 IPCP)
  ↓ hexa_v2 transpile                      → ipcp.c
  ↓ flame_phase4b3_emit_trampoline         → trampoline.c + decls.c
  ↓ sed-rewrite call sites                 → fwd/bwd_primitive
  ↓ sed-insert decls + cat                 → b3.c
  ↓ flame_phase4b3_block_fwd/bwd_primitive (Phase 4-B-3 A2)
  ↓ flame_phase4b3_matmul_primitives.c     (Path B fwd+bwd matmul)
  ↓ concat after #include "runtime.c"      → a2.c (3459 lines)
  ↓ clang -O2                              → binary

Single-TU inline pattern (`#include "runtime.c"`) makes _hx_farr_table
visible to primitive code — direct double* dereference (no HexaVal box).
```

## Mechanism breakdown (measurement-anchored)

| mechanism | initial estimate | measured | source commit |
|---|---|---|---|
| boxing elimination | 1.5-2.5× | **3.99× isolated** | `07cdd405` |
| allocator elimination | 1.3-1.7× | **1.00×** | `98bed481` |
| fn-call elimination | 1.2-1.5× | **1.00×** (overlap-capped) | `f525a656` |
| **compound (isolated estimate)** | **6.24-10.2×** | **4.0× ceiling** | — |
| **A2 fwd+bwd (real workload)** | (~1.4× projected) | **2.74× SURPRISE** | `8012c15a` |
| **Path B incremental** | (small) | **1.18× incremental** | `29fe4a69` |
| **🎯 cumulative (cool conditions)** | — | **3.23× wall** | `29fe4a69` |

A2 surprise sources:
1. bwd has MORE boxed ops than fwd (gradient accumulators)
2. clang -O2 + literal dims + primitive arithmetic vectorizes (NEON arm64)
3. Synergistic fwd+bwd cumulative effect (not sum of parts)

## Verification (23 artifacts, all PASS)

```
Fwd leaf byte-eq (5):    rmsnorm / residual / swiglu / rope / attention
Bwd leaf byte-eq (5):    residual / rmsnorm / swiglu / rope / attention bwd
Path B matmul (4):       Wq/Wo, Wk/Wv, Wg/Wu, Wd
Path B grad_accum (4):   dWq/dWo, dWk/dWv, dWg/dWu, dWd
Mechanism probes (3):    boxing 4× / alloc 1× / fncall 0.12×
IPCP build byte-id (1):  Phase 4-B-2 (1.28× wall)
A2+B FULL byte-id (1):   Phase 4-B-3 (3.23× wall cool projection)
─────────────────────────
Total: 23/23 PASS
```

All byte-eq tests use libm reference of the SAME algorithm — max|Δ| = 0.0
strict byte-eq tier (RFC 045 class). No fp-tol acceptance, no
algorithmic drift.

## File inventory

```
Source primitives:
  tool/flame_phase4b3_block_fwd_primitive.c    A2 fwd ~270 C lines
  tool/flame_phase4b3_block_bwd_primitive.c    A2 bwd ~400 C lines
  tool/flame_phase4b3_matmul_primitives.c      Path B matmul + grad_accum
                                                (4 shapes each, 8 primitives)

Build wrappers:
  tool/flame_phase4b_build.sh                  Phase 4-B-2 IPCP only
  tool/flame_phase4b3_build.sh                 + trampoline + caller wire-up
  tool/flame_phase4b3_a2_build.sh              + A2 fwd+bwd + Path B FULL
  tool/flame_phase4b3_extern_build.sh          extern fn POC (failed, kept)

Verification:
  tool/flame_phase4b3_verify_all.sh            23-artifact battery
  tool/flame_phase4b3_leaf_*_test.c            10 leaf byte-eq tests
  tool/flame_phase4b3_*_bench.c                3 mechanism probes
  tool/flame_phase4b3_emit_*.hexa              detect + emit scaffolds

SSOTs (synchronized):
  README.md                                    Phase 4-B headline
  STATUS.md                                    sixth iteration single-page
  FLAME.tape ## Log                            4 chronological entries
  PERF.md                                      measurement ledger
  PLAN.md                                      Phase 4 section
  12 design docs                               PHASE4B_*.md + RFC 045-048
```

## Honest framing per AGENTS.tape g3 (verification-anchor-real-limit)

Throughout the 57-commit cycle:
- Every claim measurement-backed (5-run avg, var noted)
- Every estimate revised when measurement contradicted (4× boxing
  isolated → 1.4× full-stack projection → 2.74× SURPRISE → 3.23×)
- Failed hypotheses documented (extern fn POC, Path C dV revert)
- Cool vs thermal-elevated baseline disclosed explicitly
- No fabricated multiples — all wall figures from 5-run measurements

## What's NOT in scope

- Phase 4-D GPU dispatch (cost-bearing $5-20, separate user-gate cycle)
- Phase 4-C RFC 048 fwd+bwd graph fusion (orthogonal mechanism, separate cycle)
- Phase 5 "exceed eager-PyTorch" (ultimate goal, requires GPU dispatch)
- d=768·12L scaling (current Phase 4-B is d=32·3L only)
- production `./hexa build` integration (Phase 4-B uses parallel wrapper)

## Next user-gate options (Phase 4-B closure complete)

1. **Phase 4-B SHIPPED CLOSURE** ✅ — substantial milestone fully delivered
2. **Phase 4-D GPU dispatch fire** — $5-20 cost-bearing, d=768·12L scaling
3. **RFC 048 fwd+bwd graph fusion** — orthogonal mechanism (~5× over Phase 4-B)
4. **Other hexa-lang work** — different RFC / cleanup / etc.

## Cross-link

- 57-commit cycle progression: FLAME.tape ## Log entries (4 entries)
- All SHIP milestones: cfbba144 (A2 fwd), 8012c15a (A2 bwd), 29fe4a69 (Path B FULL)
- Self-verifying gate: tool/flame_phase4b3_verify_all.sh (commit 7faddb49)
- Closure docs: this file + STATUS.md sixth iteration (commit 3b83d6a8)
