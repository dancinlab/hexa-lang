# Phase 4-D GPU dispatch fire — design draft (2026-05-17)

> Design only — no cost incurred. Prep doc for the next user-directed
> Phase 4-D cycle (cost-bearing $5-20). Builds on Phase 4-B SHIPPED
> (commit `c4aab67e` PHASE4B_SHIPPED_SUMMARY.md) which delivered
> 3.23× wall on CPU for d=32·3L.

## Phase 4-D scope

**Goal**: F-RFC046-EAGER-PYTORCH-MATCH — ≤1.3× of 336.85s eager-PyTorch
A100 wall on d=768·12L config.

**Why GPU after Phase 4-B**: Phase 4-B reached ≥3× target on CPU for
the SMALL d=32·3L config (16.170s → 5.0s cool projection). The
d=768·12L config (~64× more params) is memory-bandwidth-bound and
fundamentally needs GPU acceleration to compete with eager-PyTorch's
A100 baseline.

**Cost estimate**: $5-20 cost-bearing
- vast.ai A100 SXM: ~$1-2/hr × 2-8 hours
- runpod A100 PCIe: ~$0.8-1.5/hr × similar
- Includes: build setup + dispatch retries per g_fire_dispatch_robust
- One-shot fire; results captured, instance teardown

## Dispatch infrastructure (pre-existing)

The flame stack already has GPU substrate in place from prior work:

1. **RFC 040 device-farr + cuBLAS Dgemm** — landed, runtime.c has
   `farr_zeros` / `farr_get` / etc. with `FARR_HOST | FARR_DEVICE |
   FARR_MIRRORED` residence states + d_buf CUDA pointer slot.

2. **self/forge/** — GPU compute substrate SSOT (see §0 nn_stack in
   project CLAUDE.md). self/runtime.c + self/cuda/ (label-only).

3. **anima HEXAD dispatch patterns** — wilson g_fire_dispatch_robust +
   g_fire_autonomous (proven cross-repo for cost-bearing GPU runs).

What Phase 4-D adds for flame:
- Build flame_d768_12L_corpus_test (scaled config)
- Build dispatch script (vast.ai / runpod CLI)
- Smoke run on local CPU (verifies build sanity)
- GPU dispatch fire (cost-bearing)
- Result capture (wall + acc + final loss)
- Comparison vs eager-PyTorch 336.85s A100 baseline

## Scaled config: d=768·12L

```
T = 1024 (vs d=32·3L T=16)        — 64× sequence length
d = 768  (vs d=32·3L d=32)        — 24× embedding dim
nh = 12  (vs nh=4)                 — 3× heads
nkv = 4   (vs nkv=2)               — 2× kv heads
h = 3072  (vs h=64)                — 48× ffn hidden
n_layer = 12 (vs n_layer=3)        — 4× depth
V = 32768 (vs V=256)              — 128× vocab
─────────────────────────────────────
Params: ~64× more than d=32·3L
```

Compute density: T·T attention scores per head per layer:
- d=32·3L: 16·16 = 256 ops per head-layer × nh·n_layer = 4·3 = 12 head-layers = 3072 ops/block
- d=768·12L: 1024·1024 = ~1M ops per head-layer × nh·n_layer = 12·12 = 144 head-layers = 144M ops/block

→ Attention dominates wall at scale. Phase 4-D 의 핵심 mechanism = cuBLAS Dgemm
on attention matmul (already in RFC 040 substrate).

## Phase 4-D sub-phases

| sub-phase | what | effort | cost | falsifier |
|---|---|---|---|---|
| 4-D-1 | flame_d768_12L_corpus_test source | 1 cycle | $0 | builds local (CPU smoke) |
| 4-D-2 | GPU dispatch script | 1 cycle | $0 | (vast.ai CLI ready) |
| 4-D-3 | Local CPU smoke (skip if too slow) | 0.5 cycle | $0 | builds + runs N steps |
| 4-D-4 | **GPU dispatch fire** | 1 cycle | **$5-20** | **F-RFC046-EAGER-PYTORCH-MATCH** |
| 4-D-5 | Result capture + RFC 046 ship | 1 cycle | $0 | wall + loss vs eager-PyTorch ≤1.3× |
| **total** | — | **4-5 cycles** | **$5-20** | — |

## Verification anchors

**F-RFC046-EAGER-PYTORCH-MATCH** (primary):
- flame d=768·12L A100 wall ≤ 1.3× of eager-PyTorch 336.85s = ≤ 437.9s
- All else equal: same model arch, same corpus, same seed=42

**F-RFC046-LOSS-CONVERGENCE**:
- Final loss within RFC 040 fp-tol of eager-PyTorch reference
- collapse ≥ 1e6× from init (per RFC 045 Phase 3-F-3 pattern)

**F-RFC046-GPU-SANITY**:
- Pre-fire local CPU smoke: 1-step fwd+bwd at scaled config, finite numerics

## Risks

1. **GPU dispatch infra**: vast.ai / runpod instance availability,
   Dgemm Tensor Core utilization, CUDA version mismatch
   - Mitigation: g_fire_dispatch_robust pattern (proven cross-repo)

2. **Reduction order drift at scale**: attention softmax sum over
   T=1024 elements may exceed RFC 040 fp-tol; need TOL_ATTN relaxation
   - Mitigation: define fp-tol class for attention reduction; preserve
     algorithm-byte-eq pattern from Phase 4-B-3 leaf verification

3. **Cost overrun**: 1 fire scope-defined; if build or sanity fails on
   GPU, dispatch retries can multiply cost
   - Mitigation: extensive local CPU smoke before fire; explicit budget cap

4. **Phase 4-B integration on GPU**: Path B primitives use CPU
   `_hx_farr_table[id].buf`; GPU path uses d_buf. Cannot reuse Phase 4-B
   CPU primitives directly.
   - Reality: Phase 4-D wall improvement comes from RFC 040 cuBLAS
     Dgemm + memory bandwidth, NOT Phase 4-B boxing-elim. These are
     orthogonal mechanisms.

## What Phase 4-D does NOT do

- Push d=32·3L past 3.23× (that's CPU-bound; GPU at small scale adds
  dispatch overhead > compute gain)
- Replace Phase 4-B CPU primitives (orthogonal — both ship together)
- "Exceed eager-PyTorch" (that's Phase 5 ultimate goal; Phase 4-D
  targets parity ≤1.3×)

## Cross-link

- Phase 4-B SHIPPED (commit `c4aab67e` PHASE4B_SHIPPED_SUMMARY.md) —
  CPU 3.23× on d=32·3L
- RFC 040 device-farr + cuBLAS (landed)
- RFC 046 Phase 4 fusion framework — F-RFC046-EAGER-PYTORCH-MATCH spec
- self/forge/ GPU compute substrate (project CLAUDE.md §0 nn_stack)
- wilson g_fire_dispatch_robust + g_fire_autonomous patterns
- HEXAD dispatch reference: anima cross-repo cost-bearing fires

## Next user-gate

Phase 4-D fire requires:
1. Explicit budget approval ($5-20)
2. vast.ai / runpod account + API key set
3. Config (d=768·12L corpus_consciousness_v1.jsonl or equivalent)
4. Acceptance of g_fire_autonomous (one-shot fire without per-step approval)

If approved → 4-5 cycle dispatch → F-RFC046-EAGER-PYTORCH-MATCH gate.
If not → Phase 4-B SHIPPED CLOSURE is the substantive Phase 4 milestone.
