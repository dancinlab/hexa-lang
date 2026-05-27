# RFC 032 — `farr_matmul` native packed-double matmul builtin

- **Status**: implemented (2026-05-12)
- **Date**: 2026-05-12
- **Severity**: HIGH (blocks pure-hexa 24-layer forward parity)
- **Priority**: P0 (HEXA_NATIVE Phase 5∥ prerequisite)
- **Source convergence**: HEXA_NATIVE_INFERENCE.md Phase 5∥
- **Source session**: anima 1-layer subset parity (commit `a0f221cd0`)
  hits 6.25e-7 max |Δ| on one hidden state — but using Python BLAS for
  matmul. Pure-hexa matmul through `farr_get`/`farr_set` boxes ~88 B
  HexaVal per inner-loop scalar, saturating arena before completion.

## Implementation status (2026-05-12)

**LANDED** as a single new builtin
`farr_matmul(A_farr, A_rows, A_cols, B_farr, B_cols) -> C_farr`.

- `self/runtime.c::hexa_farr_matmul` (~70 LoC after the RFC 025 / 031
  safetensors block). Uses `ikj` triple-loop with manual ×4 inner-unroll
  for clang -O2 fma emission. No BLAS, no AVX intrinsics — portability
  over peak FLOPS for v1.
- `self/runtime.c::_hexa_init_fn_shims` — fn_shim registration (arity 5).
- `self/codegen_c2.hexa` — AOT dispatch entry (5-arg block).
- `self/hexa_full.hexa::call_builtin` — interp dispatch handler.
- Smoke: `tmp_rfc032_smoke.hexa`.

## Problem

A pure-hexa `for k in 0..K: c += A[i][k] * B[k][j]` inner loop allocates
one HexaVal scratch (~12 B int / ~24 B double / ~88 B with arena
overhead) per scalar multiply-accumulate. For a single `1024×1024` matmul
the inner loop is `2^30` MACs, requiring tens of GB of arena pressure
that no current hexa interp can sustain. The interp OOMs, the AOT path
emits inner loops that still go through `farr_get`/`farr_set`'s HexaVal
boxing because farr ops are typed-builtin-returning-HexaVal.

A native `farr_matmul` reads two packed-double farr buffers directly via
`double*` pointer arithmetic with zero HexaVal allocation in the hot
loop, then returns one freshly-allocated output farr — matching the
typed-arena contract that `_read_f32_farr` / RFC 031's
`_read_bf16_to_f32_farr` already use.

## Proposal

```hexa
// C = A @ B,
//   A is (M × K) row-major in farr buffer A_farr,
//   B is (K × N) row-major in farr buffer B_farr,
//   C is (M × N) row-major in a freshly-allocated farr,
//   returns farr_id (≥ 0) or -1 on shape/bounds error.
pub fn farr_matmul(A_farr: int, A_rows: int, A_cols: int,
                   B_farr: int, B_cols: int) -> int
```

### Algorithm

Cache-friendly `ikj` triple loop (best for row-major × row-major →
row-major output):

```c
for (i = 0; i < M; i++) {
    const double* Ai = A + i*K;
    double*       Ci = C + i*N;
    for (k = 0; k < K; k++) {
        double a_ik = Ai[k];
        const double* Bk = B + k*N;
        for (j = 0; j < N; j += 4) {   // manual ×4 unroll
            Ci[j  ] += a_ik * Bk[j  ];
            Ci[j+1] += a_ik * Bk[j+1];
            Ci[j+2] += a_ik * Bk[j+2];
            Ci[j+3] += a_ik * Bk[j+3];
        }
    }
}
```

- `B` and `C` are streamed linearly within each inner loop — TLB / L1
  friendly.
- `a_ik` hoists out of the innermost loop and stays in a register.
- ×4 unroll keeps source portable (no AVX intrinsics) while letting
  clang emit `fma` / SIMD.
- Tail loop handles `N % 4 != 0`.

### Future-friendly hooks (NOT in v1)

- AVX2/NEON 4×4 block kernel — drop-in replacement of inner loop.
- BLAS bridge — `farr_matmul_blas(...)` ABI-compatible alternative.
- Multi-threaded variant — `farr_matmul_par(..., nthreads)`.

v1 keeps a single-thread scalar baseline so all Falsifiers test the
correctness foundation; perf RFC will follow once Phase 5∥ lands.

## Falsifiers

- **F-RFC-032-2x2-IDENT**: `[[1,0],[0,1]] @ [[3,4],[5,6]] = [[3,4],[5,6]]`,
  max |Δ| = 0.
- **F-RFC-032-IDENT-LARGE**: `I_32 @ M_32x32_random ≈ M`, max |Δ| < 1e-12.
- **F-RFC-032-RECT**: `(32×64) @ (64×32) → (32×32)`, max |Δ| vs
  numpy/PyTorch reference < 1e-9.
- **F-RFC-032-LARGE-PARITY**: `(64×128) @ (128×64) → (64×64)`, max |Δ| vs
  reference < 1e-9.
- **F-RFC-032-ZERO**: any matrix `@ zeros` = `zeros`.
- **F-RFC-032-SHAPE-ERR**: invalid handle / non-positive dim returns -1
  with no crash and no leak (output farr not allocated on early return).
- **F-RFC-032-MEM**: 100 consecutive `(64×64) @ (64×64)` calls do not
  monotonically grow farr table beyond a known bound (output farr can
  be `farr_free`'d).
- **F-RFC-032-BF16-CHAIN**: feed RFC 031 BF16-loaded farr through
  `farr_matmul`, finite + non-zero result (integration with the rest of
  Phase 5∥).

(≥ 3 per directive; we ship 8.)

## Memory cost

- Input: A (M·K·8 B), B (K·N·8 B) — already resident from the caller.
- Output: M·N·8 B in a new farr slot.
- Hot loop scratch: zero HexaVal allocation. The full inner loop is
  pure C `double*` arithmetic.

## Risks

- Numerical: `f32 → f64 → f32` upcast in BF16 → f32 → farr (double)
  inflates the accumulator precision over PyTorch's native f32 matmul
  → SLIGHTLY tighter results, not looser. The Phase 5∥ parity gate
  (max |Δ| < 1e-3 BF16 tolerance) is unaffected.
- Determinism: single-thread, no reduction reordering → bit-exact
  reproducibility for the v1 kernel.
- Aliasing: A, B, C are distinct farr slots (different ids) by
  construction (output is freshly allocated). Caller responsible if
  they pass `A == B`; the algorithm tolerates that case (reads happen
  before writes within each `(i,k)` pair).

## Cross-RFC dependency

- RFC 025 (mmap zero-copy load) — provides the farr buffers via
  `_read_f32_farr`.
- RFC 031 (BF16 reader) — provides BF16-sourced farr buffers.
- HEXA_NATIVE Phase 5∥ — `engine_ag_nn_native.hexa::linear_forward`
  is one `farr_matmul` call.

## Implementation pointers

```c
// self/runtime.c (after RFC 031 BF16 reader)
HexaVal hexa_farr_matmul(HexaVal a_v, HexaVal ar_v, HexaVal ac_v,
                         HexaVal b_v, HexaVal bc_v) {
    int64_t a_id = hexa_as_num(a_v);
    int64_t M    = hexa_as_num(ar_v);
    int64_t K    = hexa_as_num(ac_v);
    int64_t b_id = hexa_as_num(b_v);
    int64_t N    = hexa_as_num(bc_v);
    if (a_id < 0 || a_id >= _hx_farr_count) return hexa_int(-1);
    if (b_id < 0 || b_id >= _hx_farr_count) return hexa_int(-1);
    if (M <= 0 || K <= 0 || N <= 0)         return hexa_int(-1);
    HexaFarrEntry* ae = &_hx_farr_table[a_id];
    HexaFarrEntry* be = &_hx_farr_table[b_id];
    if (!ae->buf || !be->buf)               return hexa_int(-1);
    if (ae->len < M*K || be->len < K*N)     return hexa_int(-1);
    HexaVal c_handle = hexa_farr_zeros(hexa_int(M*N));
    int64_t c_id = HX_INT(c_handle);
    HexaFarrEntry* ce = &_hx_farr_table[c_id];
    if (!ce->buf || ce->len < M*N)          return hexa_int(-1);
    const double* A = ae->buf;
    const double* B = be->buf;
    double*       C = ce->buf;
    for (int64_t i = 0; i < M; i++) {
        const double* Ai = A + i*K;
        double*       Ci = C + i*N;
        for (int64_t k = 0; k < K; k++) {
            double a_ik = Ai[k];
            const double* Bk = B + k*N;
            int64_t j = 0;
            for (; j + 4 <= N; j += 4) {
                Ci[j]   += a_ik * Bk[j];
                Ci[j+1] += a_ik * Bk[j+1];
                Ci[j+2] += a_ik * Bk[j+2];
                Ci[j+3] += a_ik * Bk[j+3];
            }
            for (; j < N; j++) Ci[j] += a_ik * Bk[j];
        }
    }
    return c_handle;
}
```
