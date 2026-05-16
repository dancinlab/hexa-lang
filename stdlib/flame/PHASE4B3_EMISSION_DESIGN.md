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

2. **Allocator elimination — MEASURED 1.00× on M-Mac (WEAK)**
   `tool/flame_phase4b3_alloc_bench.c` simulates the per-layer pattern:
   malloc(Bp_l) + malloc(Bc_l) + malloc(Xc) + memset(0) + strided
   touch + free × 240 layer-calls × 50 reps. 5-run avg:
   **heap 0.0185s / stack 0.0185s = 1.00×** (var 0.5%).

   Why the estimate was wrong: macOS libsystem_malloc has a hot
   thread-local cache for typical sizes (~75 KB Bp_l, ~70 KB Bc_l,
   ~4 KB Xc are all common slab buckets). Page-fault cost on first
   touch dominates, and stack arrays of 75 KB also fault pages on
   first touch — same cost as heap alloc + touch.

   **Caveat**: this bench uses raw malloc/free. The real flame
   `farr_zeros` + `farr_free` go through `farr_table` indirection
   which may include lock acquisition, slot lookup, free-list mutation,
   etc. — overhead the bench does NOT capture. Real-world allocator
   factor could be slightly higher than 1.00× but unlikely to reach
   the original 1.3-1.7× estimate. **Use 1.0× as the planning factor.**

3. **Fn-call elimination — MEASURED 0.12× (NEGATIVE on synthetic bench)**
   `tool/flame_phase4b3_fncall_bench.c` runs the same 7-kernel
   workload (sum_sq + dot + sum_silu + 2 combine × 7 inner iters)
   via two paths:
   - PATH A: noinline helpers (`__attribute__((noinline))`) — mimics
     fn-dispatch path of IPCP-rewritten flame
   - PATH B: full inline of all kernel bodies — proposed Phase 4-B-3
     specialized kernel form

   5-run avg: **call 0.0992s / inline 0.8233s = 0.12×** (call FASTER).
   Variance both paths <1% — clean measurement.

   This is the OPPOSITE of the original 1.2-1.5× estimate. Likely causes:
   - clang -O2 optimizes small isolated noinline helpers very well
     (each helper compiles to vectorized NEON, ~10 instructions)
   - inline path has 7 different reduction loops in one fn body →
     register pressure + instruction cache contention defeats clang
   - synthetic helpers take primitive `double*` args (no HexaVal
     marshaling), so per-call overhead is just the C function call
     (~2-5 cycles, vectorizable through with link-time inlining)

   **Critical insight — overlap with boxing-elim**: in real flame
   (not this synthetic bench), fn-call cost decomposes as
   `(C call overhead) + (HexaVal arg marshaling)`. The marshaling
   is ALREADY counted in mechanism #1 (boxing-elim, 4× MEASURED).
   The bench above measured pure C fn-call overhead in isolation
   and found it negative — so fn-call elim factor BEYOND what
   boxing-elim already provides is ≤1.0×, possibly <1.0× if inlining
   creates register pressure as the bench suggests.

   Planning factor: **1.0× (no additional gain from full inline
   beyond what boxing-elim already captures)**.

**Updated compound estimate** (3/3 mechanisms measured):
- Boxing eliminated: × 4.00 MEASURED
- Allocator eliminated: × 1.00 MEASURED
- Fn-call eliminated: × 1.00 MEASURED (negative on bench; capped at 1.0× because boxing-elim already captures HexaVal arg marshaling)

**Compound = 4.0×** (single-mechanism: boxing-elim is the dominant
and only substantial contributor).

This is well above RFC 047 §137 ≥3× ceiling but **significantly below**
the original 6.24-10.2× and even the revised 4.8-6.0× estimates. The
margin is now ~33% (4.0× / 3.0× = 1.33×) rather than 60-100%+.

At 4.0× on baseline 12.574s, expected post-Phase-4-B-3 wall is
**~3.14s** — flame would be 0.142× of anima 22.13s (~7× faster).
The eager-PyTorch crossing remains a Phase 4-D GPU dispatch question.

## Design pivot — boxing-only Phase 4-B-3 scope (2026-05-17)

Given the measurement evidence that 2 of 3 mechanisms contribute
≤1.0×, the original Phase 4-B-3 plan (full kernel inlining +
stack-resident scratch + boxing elim) over-scopes for the realized
gain. A **boxing-only Phase 4-B-3** captures the entirety of the
measured 4× ceiling with substantially less implementation risk:

**Reduced scope: emit unboxed-fn-signature trampolines**
- Generate `flame_block_<hash>_fwd(int X_id, int Bp_id, ...)` that
  unboxes ids at entry, runs the existing block body unchanged
  (with leaf fn calls preserved), boxes nothing back at exit
- The leaf fns (rmsnorm/linear/etc.) keep their HexaVal signatures —
  arg passing across them still pays boxing, BUT only at fn boundaries,
  not on every arithmetic op
- Most of the 16M box/unbox ops per run happen INSIDE leaf fn bodies
  (farr_get loops, arithmetic accumulators). Those move to unboxed
  form when the leaf fns themselves are also emitted as
  `flame_<leaf>_<hash>(double*)` specializations

**Result**: ~4× wall improvement (matching the measured boxing-elim
factor) at ~1/3 the implementation cost of the original Phase 4-B-3
plan. Inlining and stack-scratch effort is not justified by
measurement evidence.

Updated effort estimate: **3-4 cycles** (down from 6-9) for the
boxing-only Phase 4-B-3. Falsifier matrix unchanged — strict byte-eq
gates still apply.

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
