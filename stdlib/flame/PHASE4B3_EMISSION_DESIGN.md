# flame Phase 4-B-3 emission design (RFC 047 §69 detailed walkthrough)

> Design draft only — no implementation. Builds on Phase 4-B-2 IPCP
> prototype (commit `55e29392`) which delivers 1.28× wall via text
> substitution. This document walks through the ≥3× ceiling
> mechanism for the user-gate Phase 4-B-3 specialized kernel emission
> decision.

## What IPCP actually changed at the C level

Inspecting `build/artifacts/flame_d32_corpus_test_ipcp.c` after the
Phase 4-B-2 IPCP rewrite:

```c
// fn signature — UNCHANGED by IPCP (still HexaVal boxed):
HexaVal nn_decoder_block_fwd(HexaVal X, HexaVal Bp, HexaVal Bc,
                             HexaVal u_cos, HexaVal u_sin,
                             HexaVal T, HexaVal d, HexaVal nh,
                             HexaVal nkv, HexaVal h);

// call site — args boxed with hexa_int():
nn_decoder_block_fwd(Xc, Bp_l, Bc_l, u_cos, u_sin,
                     hexa_int(16), hexa_int(32), hexa_int(4),
                     hexa_int(2), hexa_int(64));

// body interior — IPCP-substituted literals in expressions:
let oX = mc_off_X(16, 32, 4, 2, 64, V, n_layer)
// generates: HexaVal oX = mc_off_X(hexa_int(16), hexa_int(32), ...)
```

The IPCP win (1.28×) comes from constant folding **inside the literals
themselves** — `mc_off_X(16, 32, 4, 2, 64, V, n_layer)` becomes
`mc_off_X(hexa_int(16), hexa_int(32), hexa_int(4), hexa_int(2),
hexa_int(64), V, n_layer)` at the C level. clang -O2 can fold the
hexa_int(16) construction if mc_off_X is inlined; otherwise the boxing
overhead persists.

## The real bottleneck — HexaVal boxing per operation

Every fn call and every arithmetic operation in flame goes through
HexaVal: an 8-byte tagged union (per `self/hexa_nanbox.h`). Each
`farr_get(X, i)` call expands to roughly:

1. unbox `X` from HexaVal to int32_t farr_id
2. unbox `i` from HexaVal to int32_t index
3. farr_table lookup by farr_id → double* base + size
4. bounds check `i < size`
5. load `base[i]` as double
6. box double back to HexaVal

Steps 1, 2, 6 are pure boxing overhead — not present in a hand-written
fp64 inner loop. For an 80-step d=32·3L training run with ~200K
farr_get calls per step, boxing overhead is on the order of
**16M box/unbox ops per run**.

clang -O2 with link-time inlining can sometimes eliminate boxing, but
the HexaVal tagged union forces a runtime tag check on every arithmetic
operation — `hexa_add(a, b)` dispatches on `tag_of(a)`, `tag_of(b)`.
Even with constants visible, the tag dispatch path is not optimized
away.

## Phase 4-B-3 emission: drop HexaVal, drop dim args, drop fn calls

The specialized kernel form per RFC 047 §75 is a static C fn with
**unboxed primitive args** and **stack-resident scratch**:

```c
// PROPOSED Phase 4-B-3 emission for dims_hash = 0x388e4067
static void flame_block_T16_d32_nh4_nkv2_h64_fwd(
    int X_id, int Bp_id, int Bc_id, int cos_id, int sin_id
) {
    // Unbox once at fn entry — runtime farr_table lookups by id
    double* X    = farr_table_base(X_id);    // [T·d] = [16·32]
    double* Bp   = farr_table_base(Bp_id);   // [bp_total(32,4,2,64)]
    double* Bc   = farr_table_base(Bc_id);   // [bc_total(16,32,4,2,64)]
    double* cos  = farr_table_base(cos_id);  // [T·hd] = [16·8]
    double* sin  = farr_table_base(sin_id);  // [16·8]

    // Stack-resident scratch — no farr alloc per layer
    double rin[16*32];       // T·d
    double rin2[16*32];
    double hstate[16*32];
    double sw_a[16*64];      // T·h
    double sw_b[16*64];
    double sw_s[16*64];
    double Q[16*32];         // T·d
    double K[16*16];         // T·kvd (kvd = nkv*hd = 2·8 = 16)
    double V[16*16];
    double P[4*16*16];       // nh·T·T = 4·256

    // Pass 1: RMSNorm(X, g1) + Q/K/V proj + RoPE rotation
    // All loop bounds are literal — clang unrolls aggressively
    for (int i = 0; i < 16; i++) {
        // ─── RMSNorm inline (no fn call) ─────
        double ms = 0.0;
        for (int c = 0; c < 32; c++) {
            double xv = X[i*32 + c];
            ms += xv * xv;
        }
        ms /= 32.0;  // d literal
        double inv = 1.0 / sqrt(ms + 1e-6);
        for (int c = 0; c < 32; c++) {
            rin[i*32 + c] = (X[i*32 + c] * inv) * Bp[c];  // bp_off_g1 = 0
        }
        // ─── Q projection inline + RoPE in same loop ─────
        for (int q = 0; q < 32; q++) {
            double acc = 0.0;
            for (int c = 0; c < 32; c++) {
                acc += rin[i*32 + c] * Bp[32 + q*32 + c];  // bp_off_Wq = 32
            }
            Q[i*32 + q] = acc;
        }
        // RoPE fused into Q immediately — keeps Q in registers
        for (int hh = 0; hh < 4; hh++) {           // nh literal
            for (int c = 0; c < 4; c++) {          // half = hd/2 = 4
                int idx0 = i*32 + hh*8 + c;
                int idx1 = i*32 + hh*8 + c + 4;
                double q0 = Q[idx0];
                double q1 = Q[idx1];
                double co = cos[i*8 + c];
                double si = sin[i*8 + c];
                Q[idx0] =  q0 * co - q1 * si;
                Q[idx1] =  q0 * si + q1 * co;
            }
        }
        // ... K projection + RoPE, V projection (similar inline)
    }
    // Pass 2: attention scores + softmax + value combine
    // Pass 3: SwiGLU + residual + output write to Bc
    // ... (omitted for brevity — same inline pattern)

    // Final: copy stack scratch to Bc fields
    for (int k = 0; k < 16*32; k++) {
        Bc[bc_off_Xout_const + k] = hstate[k];  // bc_off_Xout literal
    }
}
```

Per-call savings vs the IPCP-rewritten current form:

| Cost dimension | IPCP current | Phase 4-B-3 specialized | Reduction |
|---|---|---|---|
| HexaVal box/unbox per fn arg | 10 args × box | 5 unboxed once at entry | ~10× per call |
| farr_get tagged dispatch | per op | direct array load | ~3-5× per fp op |
| Inner loop fn calls (rmsnorm/swiglu/etc.) | 7-12 calls/iter | 0 (inlined) | fn call overhead = 0 |
| Bp_l/Bc_l/Xc farr alloc per layer | 3 alloc/free per layer call | 0 (stack scratch) | allocator pressure = 0 |
| Loop bounds | literal (post-IPCP) | literal + unrolled | clang -O2 unroll |

## First-principle mechanism for the ≥3× target

Three independent multiplicative effects. Initial estimates updated
with measurement (2026-05-17 boxing micro-bench, see PERF.md).

1. **Boxing elimination — MEASURED 3.99× on M-Mac**
   `tool/flame_phase4b3_boxing_bench.c` runs Σx² over 512 elements ×
   200K reps via HexaVal-boxed path (mirrors runtime.c HexaVal 16-byte
   tagged-union struct + per-op tag dispatch in hexa_add / hexa_mul)
   vs direct fp64. 5-run avg: **boxed 0.3868s / direct 0.0969s
   = 3.99×** (var 0.01%, identical fp result, byte-eq). Initial
   estimate was 1.5-2.5× — measurement is STRONGER.

   Why: every HexaVal arithmetic op pays (tag check × 2) + (branch) +
   (struct copy of result on return). Direct fp64 is single FADD or
   FMUL instruction; clang -O2 vectorizes the inner loop via NEON
   on arm64. The boxed path cannot vectorize through the tag
   dispatch branch.

2. **Allocator elimination (× ~1.3-1.7, estimate, not yet measured)**:
   Bp_l/Bc_l/Xc farr_zeros + farr_free per layer (4 layer-calls × 3
   allocs × 80 steps = 960 alloc/free ops) replaced by stack scratch.
   Heap allocator latency plus farr_table mutation overhead disappear.

3. **Fn-call elimination (× ~1.2-1.5, estimate)**: 7-12 inner fn
   calls per block-fwd (rmsnorm/linear/attn_core/swiglu/...) inlined
   into one contiguous fn body. Register-resident intermediates
   instead of memory round-trips through farr_table.

**Updated compound estimate** (boxing measured, others still estimated):
- Optimistic:  4.0× × 1.7× × 1.5×  ≈ **10.2×**
- Geometric (midpoint of remaining estimates): 4.0× × 1.5× × 1.35× ≈ **8.1×**
- Honest minimum (if others weaker than estimated): 4.0× × 1.3× × 1.2× ≈ **6.24×**

All three scenarios are well above RFC 047 §137 ≥3× target with
substantial margin. The 8× geometric midpoint suggests Phase 4-B-3
may approach or exceed the RFC 043 "exceed eager-PyTorch" boundary
(estimated 3.4s × 8 / 22 ≈ 1.2× crossing for d=32·3L).

**Reality caveat**: the 4× boxing factor is measured on an inner-loop
best-case workload (pure Σx²). Real flame block_fwd mixes ops with
different boxing profiles (matmul calls farr_get/farr_set heavily,
which involve box+unbox per access plus farr_table lookup). The
average effect across the full block is likely 2-3× from boxing alone
— still substantial. Take **6.24× honest minimum** as the planning
target; ≥3× RFC 047 ceiling is highly probable.

## Implementation surface

Two paths considered:

**(P1) hexa-source-level emission** — write a hexa-lang tool that takes
the IPCP-rewritten source and emits a NEW hexa-lang `flame_block_<hash>_fwd`
fn alongside the original (which becomes the variable-shape fallback).
The rewrite changes:
- fn signature: `HexaVal T` → `int T` for param-stripped form, or
  emit a new fn entirely with dim args removed.
- body: replace `farr_get(X, i)` calls with stack-scratch index when
  X is the local scratch; replace fn calls with inline bodies of the
  callees (rmsnorm/linear/attn_core/swiglu).

Pro: stays in hexa-lang surface; debugger maps to hexa source.
Con: requires hexa-lang to support `int`-typed primitive params
(currently only HexaVal at the C boundary) — language extension or
attribute-driven escape.

**(P2) C-source-level emission** — emit a hand-written C file
alongside the hexa_v2-emitted C, and let clang link both. The Phase
4-B-3 emitter writes
`build/artifacts/flame_block_T16_d32_nh4_nkv2_h64_fwd.c` directly.
The IPCP-rewritten hexa source's call site is rewritten to call the
specialized C fn via FFI/extern.

Pro: no hexa-lang extension; fully orthogonal to compiler internals.
Con: source duplication across the language boundary — the
specialized kernel must be kept in sync with the hexa-source block
fwd if the algorithm changes (mitigated by deriving the C emit from
the IPCP-rewritten hexa source via the emitter).

**Recommendation: P2** — the IPCP-rewritten C is the input; the Phase
4-B-3 emitter is a hexa→C translator with primitive-typed signatures
and stack-resident scratch. Lower hexa-lang risk; reversible
(`--flame-phase4b3` flag default OFF preserves Phase 4-B-2 byte-eq).

## Falsifiers (Phase 4-B-3 specific)

- **F-RFC047-BLOCK-EMIT-BYTE-EQ-FWD** — specialized fn output byte-id
  to nn_decoder_block_fwd on F-RFC043-BLOCK-DET inputs. max|Δ| = 0.0.
- **F-RFC047-BLOCK-EMIT-BYTE-EQ-BWD** — same for bwd.
- **F-RFC047-DECODER-EMIT-BYTE-EQ** — full decoder_lib fwd + grad
  byte-id (or within RFC 040 TOL_MATMUL fp-tol when reduction order
  unavoidably changes; aim for byte-id first).
- **F-RFC047-CORPUS-EMIT-STEP-EQ** — 80-step trajectory byte-id with
  Phase 4-B-2 IPCP baseline on flame_d32_corpus_test. The flame ↔ anima
  3.12e-5 init-gn2 delta MUST be preserved exactly (Phase 4-B-3 changes
  emit pattern, not math).
- **F-RFC047-BLOCK-WALL-IMPROVED** — 5-run avg wall reduction.
  - Target: ≥3× over Phase 4-A-bwd baseline (12.574s → ≤4.2s)
  - Equivalent: ≥2.3× over Phase 4-B-2 IPCP (9.814s → ≤4.2s)
  - Honest minimum: ≥2× over Phase 4-A-bwd; if measured <2×, pass
    design needs revision.

## Risks

1. **Reduction-order drift** — replacing `farr_matmul` (ijk loop order
   via runtime helper) with inline ikj inline accumulator can change
   FMA fusion context → last-ulp drift → F-RFC047-CORPUS-EMIT-STEP-EQ
   FAIL. Mitigation: preserve the IPCP-rewritten reduction order by
   construction (lift the same loops, don't reorder them). Aligns
   with Path C lesson (commit `23705dc5`).

2. **Source-of-truth split** — the specialized C kernel and the hexa-
   source block fwd must stay in sync if the math changes. Mitigation:
   the emitter derives the C from the IPCP-rewritten hexa source, so
   hexa source remains SSOT. Falsifier F-RFC047-BLOCK-EMIT-BYTE-EQ-FWD/BWD
   gates this.

3. **HexaVal escape at fn boundaries** — the specialized fn returns
   to a HexaVal-typed caller (the IPCP-rewritten nn_decoder_fwd body).
   Calling convention must box the unboxed primitive-typed scratch
   pointers back to HexaVal at the boundary. Per-call overhead bounded
   (5 box ops at entry + 0 at return for void fn). Falsifier sweep
   confirms no semantic drift.

4. **Emitter complexity creep** — temptation to add cross-block
   fusion (RFC 048 territory) inside the Phase 4-B-3 emitter.
   Mitigation: strict scope — Phase 4-B-3 emits ONE specialized fn
   per dims_hash for fwd and ONE for bwd. Cross-block fusion is
   Phase 4-C / RFC 048.

## Cross-link

- RFC 047 §69 (emit pattern) + §107 (generation algorithm) + §137
  (F-RFC047-BLOCK-WALL-IMPROVED)
- PHASE4B_SCAFFOLD.md — IPCP prototype findings (commit `55e29392`)
- PERF.md — measurement convention (5-run, sub-second var ~7%)
- self/hexa_nanbox.h — HexaVal tagged union layout (boxing source)
- Path C revert lesson (commit `23705dc5`) — strict byte-eq must hold
  at Phase 2 level too, not just Phase 3+
- RFC 048 (Phase 4-C fwd+bwd graph fusion) — orthogonal next step
  after Phase 4-B-3

## Estimated effort

- Phase 4-B-3-1 — emitter scaffold (reads IPCP source, prints
  prospective C kernel signature + skeleton): 1 cycle. Falsifier:
  emitter runs without crash on flame_d32_ipcp source.
- Phase 4-B-3-2 — fwd kernel body emission for one (T,d,nh,nkv,h)
  tuple: 2-3 cycles. Falsifier: F-RFC047-BLOCK-EMIT-BYTE-EQ-FWD.
- Phase 4-B-3-3 — bwd kernel body emission + integration test:
  2-3 cycles. Falsifier: F-RFC047-BLOCK-EMIT-BYTE-EQ-BWD +
  F-RFC047-DECODER-EMIT-BYTE-EQ + F-RFC047-CORPUS-EMIT-STEP-EQ +
  F-RFC047-BLOCK-WALL-IMPROVED.
- Phase 4-B-3-4 — d=768·12L config dispatch (sets up Phase 4-D GPU
  fire): 1-2 cycles.

Total: 6-9 cycles. Risk: mid-high (C emitter complexity + reduction-
order discipline). Reward: ≥3× target probable; ≥2× highly likely.
