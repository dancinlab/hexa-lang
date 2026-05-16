# flame Phase 4-B status — single-page consolidated state (2026-05-17)

> One-page snapshot to reduce review burden after the 11-commit cycle.
> Cross-references the per-topic SSOTs (README.md / PLAN.md / FLAME.tape /
> PERF.md / PHASE4B_SCAFFOLD.md / PHASE4B3_EMISSION_DESIGN.md /
> NEXT_CYCLE.md). Use this for user-gate decisions; the per-topic SSOTs
> for implementation detail.

## What landed (11 commits, autonomous cycle 2026-05-17)

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

## Shippable production state

- **Production `./hexa build`**: UNCHANGED (F-RFC047-FALLBACK-PRESERVED holds vacuously — no hook). Baseline behavior preserved.
- **Phase 4-B-2 IPCP build wrapper**: `tool/flame_phase4b_build.sh <src> <out>` — single command from .hexa source to 1.28× wall binary, byte-identical to baseline. Verified on 3 distinct flame configs (d=32·3L corpus + d=32·3L perf + d=8·toy decoder + d=8·toy block).

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

## Next user-gate decision

Phase 4-B-3-2 implementation start. Three honest paths:

**Path A — Phase 4-B-3-2 boxing-only emit (recommended)**
- effort: 3-4 cycles (revised down from 6-9 per evidence pivot)
- expected wall: ~3.14s (4× ceiling)
- first sub-step: trampoline emit (unbox at entry, call existing HexaVal block_fwd, byte-eq automatic)
- next: leaf fn specializations (rmsnorm/linear/attn_core/swiglu) — captures the 16M box/unbox ops
- risk: mid (C runtime ABI integration, but no math change)
- falsifiers: F-RFC047-BLOCK-EMIT-BYTE-EQ-FWD/BWD + F-RFC047-CORPUS-EMIT-STEP-EQ

**Path B — GPU dispatch fire (Phase 4-D)**
- effort: 1-2 cycles + cost-bearing $5-20 (vast.ai A100)
- ship Phase 4-B-2 IPCP (1.28× already real) and pivot to GPU
- at d=768·12L the IPCP path may compose with GPU memory bandwidth
- target: F-RFC046-EAGER-PYTORCH-MATCH (≤1.3× of 336.85s eager-PyTorch)
- risk: mid (cost + GPU dispatch infra dependencies)

**Path C — current state ship + RFC 048 design**
- effort: 1 cycle (docs only)
- Phase 4-B-2 IPCP 1.28× as final Phase 4-B-2 SHIP closure
- RFC 048 fwd+bwd graph fusion design draft (orthogonal mechanism)
- conservative: capture what's measured, defer ≥3× to evidence-rich future

## Files touched this cycle

| file | type | purpose |
|---|---|---|
| `stdlib/flame/nn_lib.hexa` | revert | Path C dV revert |
| `tool/flame_phase4b_scan.hexa` | new | Phase 4-B-1 scaffold scanner |
| `tool/flame_phase4b_ipcp.hexa` | new | Phase 4-B-2 IPCP rewriter |
| `tool/flame_phase4b_build.sh` | new | reproducible IPCP build wrapper |
| `tool/flame_phase4b3_emit_skeleton.hexa` | new | Phase 4-B-3-1 scaffold |
| `tool/flame_phase4b3_boxing_bench.c` | new | mechanism #1 probe |
| `tool/flame_phase4b3_alloc_bench.c` | new | mechanism #2 probe |
| `tool/flame_phase4b3_fncall_bench.c` | new | mechanism #3 probe |
| `stdlib/flame/PHASE4B_SCAFFOLD.md` | extended | IPCP findings + cross-config audit |
| `stdlib/flame/PHASE4B3_EMISSION_DESIGN.md` | new+updated | emission design + mechanism updates + pivot |
| `stdlib/flame/PERF.md` | extended | 3 mechanism probes + IPCP measurement |
| `stdlib/flame/NEXT_CYCLE.md` | updated | Phase 4-B status |
| `stdlib/flame/STATUS.md` | new (this file) | single-page consolidated state |

## Quick reference — running everything

```bash
# Phase 4-B-2 IPCP build of flame_d32_corpus_test:
tool/flame_phase4b_build.sh \
    stdlib/flame/flame_d32_corpus_test.hexa \
    build/flame_d32_ipcp

# Phase 4-B-3 mechanism probes:
clang -O2 tool/flame_phase4b3_boxing_bench.c -o build/boxing_bench && ./build/boxing_bench
clang -O2 tool/flame_phase4b3_alloc_bench.c  -o build/alloc_bench  && ./build/alloc_bench
clang -O2 tool/flame_phase4b3_fncall_bench.c -o build/fncall_bench && ./build/fncall_bench

# Phase 4-B-3-1 emit skeleton inspect:
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
