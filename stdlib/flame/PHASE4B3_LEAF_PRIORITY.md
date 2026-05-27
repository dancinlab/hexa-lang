# flame Phase 4-B-3-2-third — leaf priority + primitive ABI (design)

> Design only — no code change. Plans the leaf-by-leaf specialization
> sequence for Phase 4-B-3-2-third per PHASE4B3_2_INTEGRATION.md
> "real boxing-elim body" path.

## Critical ABI finding (2026-05-17)

`self/runtime.c` exposes:

```c
typedef struct {
    double*  buf;        /* host pointer — direct double[] data */
    int64_t  len;
    void*    d_buf;      /* CUDA device pointer */
    int      loc, pinned, dirty_host, dirty_dev;
} HexaFarrEntry;

#ifdef HEXA_CUDA
HexaFarrEntry*        _hx_farr_table     = NULL;
#else
static HexaFarrEntry* _hx_farr_table     = NULL;
#endif
```

In the hexa_v2 single-TU inline pattern (`#include "runtime.c"` at
file top), `_hx_farr_table` is in scope. No-CUDA build keeps it
static (visible only within the TU — which is exactly where the
trampoline / specialization lives).

**Primitive body ABI**:
```c
static inline void flame_<leaf>_<shape>(
    int x_id, int g_id, int y_id, ...
) {
    double* x = _hx_farr_table[x_id].buf;
    double* g = _hx_farr_table[g_id].buf;
    double* y = _hx_farr_table[y_id].buf;
    // ... direct fp64 loop, no HexaVal, no farr_get/set fn calls
}
```

This eliminates the **entire box/unbox chain per farr access** —
the dominant 16M box/unbox ops/run that boxing-elim 4× MEASURED
(commit `07cdd405`) targets.

## Leaf priority order (smallest → largest, for byte-eq verification)

| order | leaf | body lines | farr ops/call | calls/training run | rationale |
|---|---|---|---|---|---|
| 1 | `nn_rmsnorm_fwd` | ~22 | ~3·d = 96 | ~480 (3L × 2 norms × 80) | smallest body, simple Σ + scale loops, easiest byte-eq |
| 2 | `nn_rmsnorm_bwd` | ~30 | ~5·d = 160 | ~480 | vjp mirror of #1 |
| 3 | `nn_lm_head_fwd` | ~20 | ~V·d ≈ 8K | 80 | bigger matrix, useful sanity check |
| 4 | `nn_rope_apply_fwd/bwd` | ~15 each | ~hd = 8 | ~T·nh × steps | small but called per-token-per-head |
| 5 | `nn_linear_fwd` | ~10 | (farr_matmul wrap; already routed) | 7 × ~480 | already primitive at farr_matmul level |
| 6 | `nn_swiglu_fwd` | ~25 | 2·matmul + h·loop + 1·matmul | ~240 | medium complexity |
| 7 | `nn_swiglu_bwd` | ~50 | ~4·matmul + ~3·loop | ~240 | bigger vjp |
| 8 | `nn_attn_core_fwd` | ~70 | ~nh·T·T + ~T·nh·hd | ~240 | softmax + GQA, careful with causal mask |
| 9 | `nn_attn_core_bwd` | ~120 | ~3·prev + sdot loop | ~240 | largest body; Path C lesson reminds us byte-eq sensitive |

## First step (Phase 4-B-3-2-third-1): nn_rmsnorm_fwd

Proposed primitive C body (drafted, NOT yet emitted):

```c
// Specialization for d=32 (from flame_d32_corpus_test 5-tuple)
static inline void flame_rmsnorm_d32_fwd_primitive(
    int x_id, int g_id, int y_id, int xn_id, int inv_id
) {
    double* x   = _hx_farr_table[x_id].buf;
    double* g   = _hx_farr_table[g_id].buf;
    double* y   = _hx_farr_table[y_id].buf;
    double* xn  = _hx_farr_table[xn_id].buf;
    double* inv = _hx_farr_table[inv_id].buf;

    const double eps = 1e-6;
    double ms = 0.0;
    for (int i = 0; i < 32; i++) {       // d literal
        ms += x[i] * x[i];
    }
    ms /= 32.0;
    double iv = 1.0 / sqrt(ms + eps);
    inv[0] = iv;
    for (int j = 0; j < 32; j++) {
        double xni = x[j] * iv;
        xn[j] = xni;
        y[j] = g[j] * xni;
    }
}
```

**Algorithm equivalence with hexa-source `nn_rmsnorm_fwd`** (stdlib/flame/nn_lib.hexa:146):
- Σx² accumulator: same order (left-to-right), same FMA-non-context
- 1/sqrt: same libm sqrt (clang -O2 may use vsqrt on arm64 — verify byte-eq)
- output write: same per-element operations in same order

**Expected byte-eq**: STRICT (algorithm-byte-eq tier, RFC 045 class).
The hexa-source body uses `_nn_sqrt(ms + eps)` which routes to libm
sqrt — same intrinsic at the primitive level. Falsifier:
F-RFC043-LAYER-EQ-RMSNORM-FWD already validates this at Phase 2;
the primitive version must match the hexa wrapper byte-id.

## Integration mechanism (Phase 4-B-3-2-third)

The current trampoline body forwards to HexaVal fn:
```c
static inline void flame_block_T16_d32_..._fwd(int X_id, ...) {
    nn_decoder_block_fwd(hexa_int(X_id), ...);  // fallback
}
```

Phase 4-B-3-2-third replaces this body with a primitive block_fwd
that calls primitive leaf fns:
```c
static inline void flame_block_T16_d32_..._fwd(int X_id, int Bp_id, ...) {
    // ... unbox once at entry
    double* X  = _hx_farr_table[X_id].buf;
    double* Bp = _hx_farr_table[Bp_id].buf;
    double* Bc = _hx_farr_table[Bc_id].buf;

    // call primitive leaf fns (each takes int farr_ids, dereferences internally)
    flame_rmsnorm_d32_fwd_primitive(
        X_id,
        bp_off_g1_const,            // baked from dims literal
        bc_off_rin_const,
        bc_off_rmxn_const,
        bc_off_rminv_const
    );
    // ... linear, RoPE, attn_core, swiglu (each primitive leaf)
}
```

Each leaf fn signature takes int farr_ids (with optional offset constants
baked in via dims literals). Internally dereferences via `_hx_farr_table[id].buf`.

## Per-leaf falsifier (Phase 2 strict byte-eq tier)

| leaf | falsifier name | input | check |
|---|---|---|---|
| `flame_rmsnorm_d32_fwd_primitive` | F-RFC047-LEAF-EMIT-RMSNORM-FWD | T·d random | max|y/xn/inv − hexa_wrapper| = 0.0 |
| `flame_rmsnorm_d32_bwd_primitive` | F-RFC047-LEAF-EMIT-RMSNORM-BWD | dy_random | max|dx/dg − ref| = 0.0 |
| ... (mirror per leaf) | ... | ... | ... |

Composite gate (Phase 3 trickle-up):
- F-RFC047-BLOCK-EMIT-BYTE-EQ-FWD: full primitive block_fwd byte-id
  on F-RFC043-BLOCK-DET inputs (T=3·d=8 toy)
- F-RFC047-DECODER-EMIT-BYTE-EQ: full decoder GRAD-EXACT trickle
- F-RFC047-CORPUS-EMIT-STEP-EQ: 80-step trajectory byte-id with anima
  oracle preserved

## Risks (Phase 4-B-3-2-third specific)

1. **Reduction-order drift** — primitive Σx² inner loop may auto-vectorize
   into different reduction order than the hexa-source unrolled scalar.
   Mitigation: keep scalar accumulator pattern, no `-ffast-math`, verify
   per-leaf with F-RFC047-LEAF-EMIT-* before composite.

2. **`_hx_farr_table` symbol leak** — static under no-CUDA build but
   the trampoline is in same TU so visible. Verify no symbol-export
   regression in production hexa build (which doesn't include trampoline).

3. **Per-leaf offset constants** — `bp_off_g1(32, 4, 2, 64)`, `bc_off_rin(...)` etc.
   are hexa fn calls in current code. Primitive version needs them as
   compile-time C constants (or call the hexa fn at trampoline entry once).

4. **Composite drift** — even if each leaf byte-eq's, the composite
   block_fwd may drift if any inter-leaf data movement (e.g., farr_table
   slot transitions) differs. Path C revert (commit `23705dc5`) reminds
   us strict byte-eq must hold at every tier, not just composite.

## Effort estimate per leaf

- Phase 4-B-3-2-third-1: rmsnorm fwd primitive + falsifier — 1 cycle (smallest)
- Phase 4-B-3-2-third-2: rmsnorm bwd + linear/lmhead/rope leaves — 1-2 cycles
- Phase 4-B-3-2-third-3: swiglu fwd + bwd + composite block_fwd integration — 1-2 cycles
- Phase 4-B-3-2-third-4: attn_core fwd + bwd + final composite + wall measure — 1-2 cycles

Total: 4-7 cycles for full Phase 4-B-3-2-third (consistent with prior
2-3 cycle estimate per leaf-family + integration).

## Cross-link

- PHASE4B3_2_INTEGRATION.md (commit `a7d066a2`) — pipeline integration
- PHASE4B3_EMISSION_DESIGN.md (commits `828717fb`+`f525a656`) — mechanism table
- self/runtime.c:7918-7938 — `_hx_farr_table` exposure (audit source)
- stdlib/flame/nn_lib.hexa — leaf fn bodies SSOT
- F-RFC043-LAYER-EQ-RMSNORM-FWD (Phase 2 selftest, commit `5602833f`) —
  pre-existing strict byte-eq oracle for #1 leaf
- Path C revert lesson (commit `23705dc5`) — strict byte-eq discipline
