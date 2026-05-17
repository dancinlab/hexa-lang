// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4d9_block_fwd_oracle.c — WHOLE-BLOCK GPU-path byte-eq
// ORACLE (the d7 oracle, generalised from one projection primitive to the
// entire forward decoder block).
//
// WHY THIS EXISTS
// ───────────────
// tool/flame_phase4d7_gpu_path_oracle covers exactly ONE primitive
// (flame_proj_batch_generic_primitive). The Phase 4-D-9 device-chain
// conversion (PHASE4D9_DEVICE_CHAIN_DESIGN.md) rewrites the ENTIRE
// flame_block_generic_fwd_primitive_gpu — RMSNorm/RoPE/attention/SwiGLU/
// residual — into a dev_view chain. Without a CHEAP block-level byte-eq
// oracle that rewrite is verifiable ONLY by the wasteful 600 s / $0.17
// d768·12L fire (the trap that burned 15 fires, completing 0 steps). This
// instrument is that cheap gate at BLOCK scope: it byte-compares the GPU
// path of the whole block against the verified-good CPU reference at a
// mid-size GPU-gated config, sub-second / $-cents.
//
// THE CONFIG — d=384, nh=6, nkv=2, h=512, T=16
// ─────────────────────────────────────────────
//   • d = 384 > FLAME_GPU_RESIDENT_THRESHOLD (256)  → the block dim-gate
//     (flame_phase4d7_block_fwd_primitive.c:1016) routes to
//     flame_block_generic_fwd_primitive_gpu — the SAME GPU-resident chain
//     the d768 trainer runs (the only difference vs d768 is loop-bound
//     VALUES; the code path is byte-for-byte identical, dim-generic
//     RFC 047).
//   • every projection crosses the cuBLAS gate (FLAME_MATMUL_GPU_
//     THRESHOLD 8192, M·K = d_out·d_in):
//       Q  : 384·384 = 147 456   K/V: 128·384 = 49 152
//       O  : 384·384 = 147 456   G/U: 512·384 = 196 608
//       D  : 384·512 = 196 608   — all ≫ 8192 → cuBLAS Dgemm.
//     Q·Kᵀ / P·V are routed to hexa_farr_matmul_gpu per head.
//   • integer-clean: hd = d/nh = 64, half = 32, n_rep = nh/nkv = 3,
//     kvd = nkv·(d/nh) = 128 — no truncation in any offset formula.
//   • cost: the largest buffer is Bp ≈ (2d + 2d² + 2·kvd·d + 3·h·d)·8 B
//     ≈ 4.1 MB; a T=16 forward is sub-millisecond CPU and sub-second on
//     any GPU — NOT the ~10 GB / 600 s d768 fire.
//
// HOW THE BYTE-COMPARE WORKS
// ──────────────────────────
//   CPU reference  : flame_block_generic_fwd_primitive_cpu called DIRECTLY
//                    at this config (bypassing the dim-gate). This is the
//                    verified-good byte-eq algorithm (the d=32·3L
//                    F-RFC047-A2-PATHB-FULL-BYTE-EQ body, verbatim).
//   GPU candidate  : under -DHEXA_CUDA the oracle calls
//                    flame_block_generic_fwd_primitive_gpu DIRECTLY — the
//                    GPU-resident chain (forge Phase B kernels + cuBLAS).
//                    On the no-CUDA Mac the candidate is
//                    flame_block_generic_fwd_primitive_cpu (the dispatch/
//                    explicit call lands on the CPU body — there is NO
//                    GPU substrate, and the forge no-CUDA helpers use
//                    libm exp/sqrt whereas the _cpu body uses the
//                    deterministic flame_g7 polynomials, so a no-CUDA
//                    _gpu run would measure the EXP/SQRT-ALGORITHM gap,
//                    NOT the reduction reorder — that is not the contract
//                    this oracle verifies). The no-CUDA run is therefore
//                    CPU-vs-CPU: it proves the harness wiring + the
//                    reference, exactly as the d7 oracle's no-CUDA mode.
//   Compared       : the block OUTPUT + key cache fields over their valid
//                    ranges — oXout (T·d), oHstate (T·d), oRin (T·d),
//                    oQ (T·nh·hd), oP (causal region j≤i per head),
//                    oSwS (T·h). max|Δ| over ALL compared elements.
//   Verdict        :  max|Δ| == 0.0          → STRICT byte-eq      PASS
//                     max|Δ| ≤ TOL_BLOCK     → Phase-B reorder band PASS
//                     max|Δ| >  TOL_BLOCK    → GPU-path REGRESSION  FAIL
//                     any NaN/Inf            → -nan signature       FAIL
//
//   TOL_BLOCK = 1e-8. Per-op contract (PHASE4D7_GPU_PATH_ORACLE.md §5 +
//   the block primitive's d≥768 contract header L33-36 + RFC 040/041
//   measured): each forge Phase B reduction kernel is reduction-reorder
//   bounded at ~1e-12 (rmsnorm/softmax rows) and each cuBLAS Dgemm at
//   ~3e-11 (PHASE4D7 §5, measured K=512). The forward block chains ~12
//   such ops (2 RMSNorm, 7 projections, per-head Q·Kᵀ + softmax + P·V,
//   2 residual adds, SwiGLU silu⊙); errors accumulate roughly additively
//   through the residual stream, so the end-to-end bound is conservatively
//   ~1e-9 (PHASE4D9_DEVICE_CHAIN_DESIGN.md §5 "~1e-9 end-to-end across the
//   block"). 1e-8 is one order ABOVE that measured bound — tight enough
//   that the fire #13 gn2-drift (~6e-3) and the fire #14 NaN blow through
//   it instantly, NOT inflated to mask error. Justified from the per-op
//   numerical contract, not chosen for convenience.
//
// SCOPE — HONEST (g3)
// ───────────────────
//   FULLY IMPLEMENTED: the CPU-reference half (= the verified-good _cpu
//   block body, spliced unmodified), the harness, the no-CUDA self-check
//   (CPU-vs-CPU, must be max|Δ|=0.0 STRICT), and the -DHEXA_CUDA GPU
//   candidate code path (compiles syntactically on Mac). The -DHEXA_CUDA
//   NUMERIC run is the ONE step that genuinely needs a GPU — a sub-second
//   / $-cents fire handed to the parent (cannot run here, no nvcc). This
//   is the verification INSTRUMENT only; it does NOT itself convert the
//   block to a dev_view chain (that is the next link — building the
//   instrument before the change is the campaign's proven methodology).
//
// Build / run: tool/flame_phase4d9_block_fwd_oracle.sh
// ════════════════════════════════════════════════════════════════════════

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

// ── HexaVal / farr-table shim ───────────────────────────────────────────
// Same single-TU approach as the d7 / causal-softmax oracles: a
// self-contained farr table so the oracle is ONE translation unit with no
// runtime.c. The block fwd primitive's non-standalone path uses BOTH the
// `farr_zeros`/`farr_free` HexaVal-carrier + hexa_call1 macro path (the
// _cpu body + the matmul primitive) AND direct hexa_farr_zeros/_free()
// calls (the _gpu body). HexaVal therefore carries the union form the
// block primitive's STANDALONE typedef declares (.i / .f / .p) so
// hexa_call1(f,a) = ((fn*)(f.p))(a) and HX_INT(v)=v.i both resolve.
//
// When built --cuda the oracle links self/cuda/runtime_cuda.c, which
// `extern`-declares `_hx_farr_table` (HexaFarrEntry*) and `_hx_farr_count`
// (int64_t). They MUST be non-static here and the types MUST match
// (runtime_cuda.c:86-96). HexaFarrEntry layout is byte-identical to the
// runtime_cuda.c typedef (double* buf; int64_t len; void* d_buf;
// int loc,pinned,dirty_host,dirty_dev).
typedef struct { int tag; union { int64_t i; double f; void* p; }; } HexaVal;
#define TAG_INT 1
#define TAG_FLOAT 2   /* any value ≠ TAG_INT — the rmsnorm shim branches
                         (eps_v.tag==TAG_INT)?.i:.f, so a non-INT tag is
                         read as the .f double. Self-consistent WITHIN this
                         harness (its hexa_float ↔ its shim); it need NOT
                         match runtime.c's tag enum — the real trainer build
                         resolves hexa_float to runtime.c's own, paired with
                         runtime.c's __hx_to_double. The block-fwd GPU
                         oracle's 1st real catch (RMSNorm eps=0) requires a
                         float HexaVal the spliced primitive can pass; the
                         hexa_int-only harness had no faithful float path. */
#define HX_INT(v) ((v).i)
static inline HexaVal hexa_int(int64_t n) { HexaVal v; v.tag = TAG_INT; v.i = n; return v; }
static inline HexaVal hexa_float(double f) { HexaVal v; v.tag = TAG_FLOAT; v.f = f; return v; }

typedef struct {
    double*  buf;
    int64_t  len;
    void*    d_buf;
    int      loc, pinned, dirty_host, dirty_dev;
} HexaFarrEntry;

HexaFarrEntry* _hx_farr_table    = NULL;
int64_t        _hx_farr_count    = 0;
static int64_t _hx_farr_capacity = 0;

static int _oracle_farr_alloc(long n, const double* init) {
    if (_hx_farr_count >= _hx_farr_capacity) {
        _hx_farr_capacity = _hx_farr_capacity < 16 ? 16 : _hx_farr_capacity * 2;
        _hx_farr_table = (HexaFarrEntry*)realloc(
            _hx_farr_table, _hx_farr_capacity * sizeof(HexaFarrEntry));
    }
    int id = (int)_hx_farr_count++;
    _hx_farr_table[id].buf = (double*)calloc(n > 0 ? n : 1, sizeof(double));
    _hx_farr_table[id].len = n;
    _hx_farr_table[id].d_buf = NULL;
    _hx_farr_table[id].loc = 0; _hx_farr_table[id].pinned = 0;
    _hx_farr_table[id].dirty_host = 0; _hx_farr_table[id].dirty_dev = 0;
    if (init) memcpy(_hx_farr_table[id].buf, init, n * sizeof(double));
    return id;
}

// ── core farr API the matmul + _cpu block primitive reference ───────────
static HexaVal hexa_farr_zeros(HexaVal n_v) {
    return hexa_int(_oracle_farr_alloc(HX_INT(n_v), NULL));
}
static HexaVal hexa_farr_free(HexaVal id_v) {
    // No-op free — the oracle is one-shot; calloc'd buffers are reclaimed
    // at process exit. Matters only that the id stays valid (the primitive
    // never re-reads a freed id). Mirrors the d7 oracle simplification.
    (void)id_v; return hexa_int(0);
}
// hexa_call1 dispatch path the _cpu body + matmul primitive use. runtime.c
// routes through HexaVal fn-pointer carriers; the oracle binds the names
// directly (the primitives only ever pass farr_zeros / farr_free).
static HexaVal farr_zeros_fn(HexaVal a) { return hexa_farr_zeros(a); }
static HexaVal farr_free_fn(HexaVal a)  { return hexa_farr_free(a);  }
#define farr_zeros farr_zeros_fn
#define farr_free  farr_free_fn
#define hexa_call1(f, a1) (f)(a1)

// runtime.c:10791 — the forge out-disposition constant the block fwd GPU
// body references at L913 (hexa_int(HEXA_FORGE_OUT_DEVICE_KEEP)). Mirror
// the runtime.c value (== FORGE_OUT_DEVICE_KEEP, runtime_cuda.c enum).
#ifndef HEXA_FORGE_OUT_DEVICE_KEEP
#define HEXA_FORGE_OUT_DEVICE_KEEP 1
#endif

// ════════════════════════════════════════════════════════════════════════
// Forge surface shims (the runtime.c `hexa_farr_*` dispatchers)
// ════════════════════════════════════════════════════════════════════════
// The block fwd primitive's GPU body (#ifndef FLAME_BLOCK_PRIM_STANDALONE)
// calls the runtime.c forge surface: hexa_farr_{to_device,to_host,
// pin_device,unpin_device,dev_view,set_out_disposition,rmsnorm_rows_gpu,
// softmax_rows_gpu,silu_gpu,mul_gpu,add_gpu,matmul_gpu,rope_gpu}. In the
// real trainer those live in self/runtime.c and forward to the _hx_cuda_*
// kernels in self/cuda/runtime_cuda.c. The oracle is standalone (no
// runtime.c — like the Phase 4-B-3 leaf tests + the d7 oracle), so it
// provides its OWN thin shims here whose bodies are byte-for-byte the
// runtime.c wrapper logic (so the GPU path the oracle exercises IS the
// trainer's). runtime_cuda.c is linked by the .sh; its kernels are
// FORBIDDEN to modify and are NOT modified — only called.
//
// NOTE: the no-CUDA $0 self-check candidate is the _cpu body, so these
// shims are NEVER reached at runtime on no-CUDA (the _gpu body is dead
// code there); they only need to COMPILE in that mode. Under -DHEXA_CUDA
// they forward to the real kernels and the parent's GPU run exercises
// them. The no-CUDA bodies still mirror the runtime.c CPU helper math
// (libm) so the instrument is self-consistent / reusable if a future
// caller drives the _gpu path on a GPU build.

#ifdef HEXA_CUDA
// ── C-LINKAGE (the fire: oracle --cuda link error 2026-05-18) ───────────
// The .sh builds --cuda via `nvcc -x cu` which ALWAYS parses as C++.
// runtime_cuda.c exports every _hx_cuda_* op inside
// `#ifdef __cplusplus extern "C" {` (runtime_cuda.c:45-46 / :1913) →
// unmangled C symbols. Without the matching `extern "C"` here the
// harness's C++ TU emits MANGLED call sites → undefined-reference at
// link. The no-CUDA + clang-syntactic checks structurally CANNOT catch
// this (no C++ link step) — only the nvcc link does, and a fire already
// cost us exactly this. Mirror the runtime_cuda.c guard EXACTLY.
#ifdef __cplusplus
extern "C" {
#endif
extern int _hx_cuda_farr_to_device(int64_t farr_id);
extern int _hx_cuda_farr_to_host(int64_t farr_id);
extern int _hx_cuda_farr_device_free(int64_t farr_id);
extern int _hx_cuda_farr_dev_view(int64_t base_id, int64_t offset,
                                  int64_t len, int64_t view_id);
extern int _hx_cuda_farr_pin_device(int64_t farr_id);
extern int _hx_cuda_farr_unpin_device(int64_t farr_id);
extern int _hx_cuda_set_out_disposition(int d);
extern int _hx_cuda_farr_matmul_gpu(int64_t a_id, int64_t M, int64_t K,
                                    int64_t b_id, int64_t N, int64_t c_id);
extern int _hx_cuda_farr_softmax_rows_gpu(int64_t x_id, int64_t R,
                                          int64_t C, int64_t out_id);
extern int _hx_cuda_farr_rmsnorm_rows_gpu(int64_t x_id, int64_t R,
                                          int64_t C, double eps,
                                          int64_t out_id);
extern int _hx_cuda_farr_add_gpu(int64_t a_id, int64_t b_id,
                                 int64_t n, int64_t out_id);
extern int _hx_cuda_farr_mul_gpu(int64_t a_id, int64_t b_id,
                                 int64_t n, int64_t out_id);
extern int _hx_cuda_farr_silu_gpu(int64_t x_id, int64_t n, int64_t out_id);
extern int _hx_cuda_farr_rope_gpu(int64_t t_id, int64_t cos_id,
                                  int64_t sin_id, int64_t T,
                                  int64_t nheads, int64_t hd,
                                  int64_t out_id);
extern int _hx_cuda_farr_transpose_scatter_gpu(int64_t src_id,
                                               int64_t dst_id,
                                               int64_t rows, int64_t cols,
                                               int64_t dst_off);
#ifdef __cplusplus
}  /* extern "C" */
#endif
#endif  // HEXA_CUDA

// ── residence / disposition shims (runtime.c:10821-10946) ───────────────
static HexaVal hexa_farr_to_device(HexaVal h_v) {
    int64_t id = HX_INT(h_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_int(0);
    if (!_hx_farr_table[id].buf && _hx_farr_table[id].loc == 0)
        return hexa_int(0);
#ifdef HEXA_CUDA
    return hexa_int(_hx_cuda_farr_to_device(id));
#else
    return hexa_int(1);
#endif
}
static HexaVal hexa_farr_to_host(HexaVal h_v) {
    int64_t id = HX_INT(h_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_int(0);
    if (!_hx_farr_table[id].buf && _hx_farr_table[id].loc == 0)
        return hexa_int(0);
#ifdef HEXA_CUDA
    return hexa_int(_hx_cuda_farr_to_host(id));
#else
    return hexa_int(1);
#endif
}
static HexaVal hexa_farr_set_out_disposition(HexaVal d_v) {
#ifdef HEXA_CUDA
    return hexa_int(_hx_cuda_set_out_disposition((int)HX_INT(d_v)));
#else
    (void)d_v; return hexa_int(0);
#endif
}
static HexaVal hexa_farr_dev_view(HexaVal base_v, HexaVal off_v,
                                  HexaVal len_v) {
    int64_t base_id = HX_INT(base_v);
    int64_t offset  = HX_INT(off_v);
    int64_t len     = HX_INT(len_v);
    if (base_id < 0 || base_id >= _hx_farr_count) return hexa_int(-1);
    if (offset < 0 || len <= 0) return hexa_int(-1);
    if (offset + len > _hx_farr_table[base_id].len) return hexa_int(-1);
    HexaVal vh = hexa_farr_zeros(hexa_int(len));
    int64_t view_id = HX_INT(vh);
    if (view_id < 0) return hexa_int(-1);
#ifdef HEXA_CUDA
    if (_hx_cuda_farr_dev_view(base_id, offset, len, view_id) != 0) {
        (void)hexa_farr_free(hexa_int(view_id));
        return hexa_int(-1);
    }
    return hexa_int(view_id);
#else
    {  // no-CUDA: materialise the slice (byte-eq with the resident view)
        double* bb = _hx_farr_table[base_id].buf;
        double* vb = _hx_farr_table[view_id].buf;
        if (bb && vb) for (int64_t i = 0; i < len; i++) vb[i] = bb[offset + i];
    }
    return hexa_int(view_id);
#endif
}
static HexaVal hexa_farr_pin_device(HexaVal h_v) {
    int64_t id = HX_INT(h_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_int(-1);
#ifdef HEXA_CUDA
    return hexa_int(_hx_cuda_farr_pin_device(id));
#else
    _hx_farr_table[id].pinned = 1; return hexa_int(1);
#endif
}
static HexaVal hexa_farr_unpin_device(HexaVal h_v) {
    int64_t id = HX_INT(h_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_int(-1);
#ifdef HEXA_CUDA
    return hexa_int(_hx_cuda_farr_unpin_device(id));
#else
    _hx_farr_table[id].pinned = 0; return hexa_int(1);
#endif
}

// ── no-CUDA CPU helper math (mirrors runtime.c:11086-11470) ─────────────
// Reached only if a future caller drives the _gpu body on a no-CUDA
// build; the oracle's own no-CUDA candidate is the _cpu body so these
// are dead at runtime here. Kept byte-faithful to the runtime.c helpers
// (libm exp/sqrt — the runtime.c no-CUDA semantics) so the instrument is
// self-consistent and reusable.
#ifndef HEXA_CUDA
static int64_t _ora_rmsnorm_rows_cpu(int64_t x_id, int64_t R, int64_t C,
                                     double eps) {
    if (x_id < 0 || x_id >= _hx_farr_count || R <= 0 || C <= 0) return -1;
    if (!(eps >= 0.0)) return -1;
    if (!_hx_farr_table[x_id].buf || _hx_farr_table[x_id].len < R*C) return -1;
    HexaVal oh = hexa_farr_zeros(hexa_int(R * C));
    int64_t oid = HX_INT(oh);
    if (oid < 0) return -1;
    const double* X = _hx_farr_table[x_id].buf;
    double*       Y = _hx_farr_table[oid].buf;
    double inv_C = 1.0 / (double)C;
    for (int64_t r = 0; r < R; r++) {
        const double* xr = X + r*C; double* yr = Y + r*C;
        double ms = 0.0;
        for (int64_t j = 0; j < C; j++) ms += xr[j]*xr[j];
        ms *= inv_C;
        double inv = 1.0 / sqrt(ms + eps);
        for (int64_t j = 0; j < C; j++) yr[j] = xr[j] * inv;
    }
    return oid;
}
static int64_t _ora_softmax_rows_cpu(int64_t x_id, int64_t R, int64_t C) {
    if (x_id < 0 || x_id >= _hx_farr_count || R <= 0 || C <= 0) return -1;
    if (!_hx_farr_table[x_id].buf || _hx_farr_table[x_id].len < R*C) return -1;
    HexaVal oh = hexa_farr_zeros(hexa_int(R * C));
    int64_t oid = HX_INT(oh);
    if (oid < 0) return -1;
    const double* X = _hx_farr_table[x_id].buf;
    double*       Y = _hx_farr_table[oid].buf;
    for (int64_t r = 0; r < R; r++) {
        const double* xr = X + r*C; double* yr = Y + r*C;
        double zmax = xr[0];
        for (int64_t j = 1; j < C; j++) if (xr[j] > zmax) zmax = xr[j];
        double s = 0.0;
        for (int64_t j = 0; j < C; j++) { double e = exp(xr[j]-zmax); yr[j]=e; s+=e; }
        double inv = (s > 0.0) ? (1.0/s) : 0.0;
        for (int64_t j = 0; j < C; j++) yr[j] *= inv;
    }
    return oid;
}
static int64_t _ora_add_cpu(int64_t a, int64_t b, int64_t n) {
    if (a<0||a>=_hx_farr_count||b<0||b>=_hx_farr_count||n<=0) return -1;
    if (!_hx_farr_table[a].buf||!_hx_farr_table[b].buf) return -1;
    if (_hx_farr_table[a].len<n||_hx_farr_table[b].len<n) return -1;
    HexaVal oh = hexa_farr_zeros(hexa_int(n));
    int64_t oid = HX_INT(oh);
    if (oid < 0) return -1;
    const double* A=_hx_farr_table[a].buf; const double* B=_hx_farr_table[b].buf;
    double* O=_hx_farr_table[oid].buf;
    for (int64_t i=0;i<n;i++) O[i]=A[i]+B[i];
    return oid;
}
static int64_t _ora_mul_cpu(int64_t a, int64_t b, int64_t n) {
    if (a<0||a>=_hx_farr_count||b<0||b>=_hx_farr_count||n<=0) return -1;
    if (!_hx_farr_table[a].buf||!_hx_farr_table[b].buf) return -1;
    if (_hx_farr_table[a].len<n||_hx_farr_table[b].len<n) return -1;
    HexaVal oh = hexa_farr_zeros(hexa_int(n));
    int64_t oid = HX_INT(oh);
    if (oid < 0) return -1;
    const double* A=_hx_farr_table[a].buf; const double* B=_hx_farr_table[b].buf;
    double* O=_hx_farr_table[oid].buf;
    for (int64_t i=0;i<n;i++) O[i]=A[i]*B[i];
    return oid;
}
static inline double _ora_sigmoid_d(double x) { return 1.0/(1.0+exp(-x)); }
static int64_t _ora_silu_cpu(int64_t x_id, int64_t n) {
    if (x_id<0||x_id>=_hx_farr_count||n<=0) return -1;
    if (!_hx_farr_table[x_id].buf||_hx_farr_table[x_id].len<n) return -1;
    HexaVal oh = hexa_farr_zeros(hexa_int(n));
    int64_t oid = HX_INT(oh);
    if (oid < 0) return -1;
    const double* X=_hx_farr_table[x_id].buf; double* Y=_hx_farr_table[oid].buf;
    for (int64_t i=0;i<n;i++) Y[i]=X[i]*_ora_sigmoid_d(X[i]);
    return oid;
}
#endif  // !HEXA_CUDA

// ── forge math dispatchers (runtime.c:10972-11900) ──────────────────────
static HexaVal hexa_farr_matmul_gpu(HexaVal a_v, HexaVal ar_v, HexaVal ac_v,
                                    HexaVal b_v, HexaVal bc_v) {
    int64_t M = HX_INT(ar_v), K = HX_INT(ac_v), N = HX_INT(bc_v);
    int64_t a_id = HX_INT(a_v), b_id = HX_INT(b_v);
    if (M <= 0 || K <= 0 || N <= 0) return hexa_int(-1);
    if (a_id < 0 || a_id >= _hx_farr_count) return hexa_int(-1);
    if (b_id < 0 || b_id >= _hx_farr_count) return hexa_int(-1);
    int64_t c_id = _oracle_farr_alloc(M * N, NULL);
    if (c_id < 0) return hexa_int(-1);
#ifdef HEXA_CUDA
    if (_hx_cuda_farr_matmul_gpu(a_id, M, K, b_id, N, c_id) != 0)
        return hexa_int(-1);
#else
    {  // CPU Dgemm-equivalent (ikj, byte-eq with the d7 reference)
        const double* A=_hx_farr_table[a_id].buf;
        const double* B=_hx_farr_table[b_id].buf;
        double* C=_hx_farr_table[c_id].buf;
        for (int64_t i=0;i<M*N;i++) C[i]=0.0;
        for (int64_t i=0;i<M;i++)
            for (int64_t k=0;k<K;k++) {
                double aik=A[i*K+k];
                for (int64_t j=0;j<N;j++) C[i*N+j]+=aik*B[k*N+j];
            }
    }
#endif
    return hexa_int(c_id);
}
static HexaVal hexa_farr_rmsnorm_rows_gpu(HexaVal x_v, HexaVal r_v,
                                          HexaVal c_v, HexaVal eps_v) {
    int64_t x_id = HX_INT(x_v), R = HX_INT(r_v), C = HX_INT(c_v);
    double eps = (eps_v.tag == TAG_INT) ? (double)eps_v.i : eps_v.f;
#ifdef HEXA_CUDA
    if (R <= 0 || C <= 0 || !(eps >= 0.0)) return hexa_int(-1);
    if (x_id < 0 || x_id >= _hx_farr_count) return hexa_int(-1);
    int64_t oid = _oracle_farr_alloc(R * C, NULL);
    if (oid < 0) return hexa_int(-1);
    if (_hx_cuda_farr_rmsnorm_rows_gpu(x_id, R, C, eps, oid) != 0)
        return hexa_int(-1);
    return hexa_int(oid);
#else
    return hexa_int(_ora_rmsnorm_rows_cpu(x_id, R, C, eps));
#endif
}
static HexaVal hexa_farr_softmax_rows_gpu(HexaVal x_v, HexaVal r_v,
                                          HexaVal c_v) {
    int64_t x_id = HX_INT(x_v), R = HX_INT(r_v), C = HX_INT(c_v);
#ifdef HEXA_CUDA
    if (R <= 0 || C <= 0) return hexa_int(-1);
    if (x_id < 0 || x_id >= _hx_farr_count) return hexa_int(-1);
    int64_t oid = _oracle_farr_alloc(R * C, NULL);
    if (oid < 0) return hexa_int(-1);
    if (_hx_cuda_farr_softmax_rows_gpu(x_id, R, C, oid) != 0)
        return hexa_int(-1);
    return hexa_int(oid);
#else
    return hexa_int(_ora_softmax_rows_cpu(x_id, R, C));
#endif
}
static HexaVal hexa_farr_add_gpu(HexaVal a_v, HexaVal b_v, HexaVal n_v) {
    int64_t a_id = HX_INT(a_v), b_id = HX_INT(b_v), n = HX_INT(n_v);
#ifdef HEXA_CUDA
    if (n <= 0) return hexa_int(-1);
    if (a_id < 0 || a_id >= _hx_farr_count) return hexa_int(-1);
    if (b_id < 0 || b_id >= _hx_farr_count) return hexa_int(-1);
    int64_t oid = _oracle_farr_alloc(n, NULL);
    if (oid < 0) return hexa_int(-1);
    if (_hx_cuda_farr_add_gpu(a_id, b_id, n, oid) != 0) return hexa_int(-1);
    return hexa_int(oid);
#else
    return hexa_int(_ora_add_cpu(a_id, b_id, n));
#endif
}
static HexaVal hexa_farr_mul_gpu(HexaVal a_v, HexaVal b_v, HexaVal n_v) {
    int64_t a_id = HX_INT(a_v), b_id = HX_INT(b_v), n = HX_INT(n_v);
#ifdef HEXA_CUDA
    if (n <= 0) return hexa_int(-1);
    if (a_id < 0 || a_id >= _hx_farr_count) return hexa_int(-1);
    if (b_id < 0 || b_id >= _hx_farr_count) return hexa_int(-1);
    int64_t oid = _oracle_farr_alloc(n, NULL);
    if (oid < 0) return hexa_int(-1);
    if (_hx_cuda_farr_mul_gpu(a_id, b_id, n, oid) != 0) return hexa_int(-1);
    return hexa_int(oid);
#else
    return hexa_int(_ora_mul_cpu(a_id, b_id, n));
#endif
}
static HexaVal hexa_farr_silu_gpu(HexaVal x_v, HexaVal n_v) {
    int64_t x_id = HX_INT(x_v), n = HX_INT(n_v);
#ifdef HEXA_CUDA
    if (n <= 0) return hexa_int(-1);
    if (x_id < 0 || x_id >= _hx_farr_count) return hexa_int(-1);
    int64_t oid = _oracle_farr_alloc(n, NULL);
    if (oid < 0) return hexa_int(-1);
    if (_hx_cuda_farr_silu_gpu(x_id, n, oid) != 0) return hexa_int(-1);
    return hexa_int(oid);
#else
    return hexa_int(_ora_silu_cpu(x_id, n));
#endif
}
static HexaVal hexa_farr_rope_gpu(HexaVal t_v, HexaVal cos_v, HexaVal sin_v,
                                  HexaVal T_v, HexaVal nh_v, HexaVal hd_v) {
    int64_t t_id = HX_INT(t_v), cos_id = HX_INT(cos_v), sin_id = HX_INT(sin_v);
    int64_t T = HX_INT(T_v), nheads = HX_INT(nh_v), hd = HX_INT(hd_v);
#ifdef HEXA_CUDA
    if (T <= 0 || nheads <= 0 || hd <= 0) return hexa_int(-1);
    if (t_id < 0 || t_id >= _hx_farr_count) return hexa_int(-1);
    if (cos_id < 0 || cos_id >= _hx_farr_count) return hexa_int(-1);
    if (sin_id < 0 || sin_id >= _hx_farr_count) return hexa_int(-1);
    int64_t oid = _oracle_farr_alloc(T * nheads * hd, NULL);
    if (oid < 0) return hexa_int(-1);
    if (_hx_cuda_farr_rope_gpu(t_id, cos_id, sin_id, T, nheads, hd, oid) != 0)
        return hexa_int(-1);
    return hexa_int(oid);
#else
    // No-CUDA: the _gpu body's CPU fallback (its `qr_id < 0` branch) does
    // the rope rotation itself; returning -1 routes there. The oracle's
    // own no-CUDA candidate is the _cpu body so this is never reached.
    (void)t_id;(void)cos_id;(void)sin_id;(void)T;(void)nheads;(void)hd;
    return hexa_int(-1);
#endif
}
// RFC 058 transpose-scatter — the matmul primitive's d768 revival site.
static HexaVal hexa_farr_transpose_scatter_gpu(HexaVal src_v, HexaVal dst_v,
                                               HexaVal rows_v, HexaVal cols_v,
                                               HexaVal dst_off_v) {
#ifdef HEXA_CUDA
    int64_t src_id = HX_INT(src_v), dst_id = HX_INT(dst_v);
    int64_t rows = HX_INT(rows_v), cols = HX_INT(cols_v);
    int64_t dst_off = HX_INT(dst_off_v);
    if (rows <= 0 || cols <= 0 || dst_off < 0) return hexa_int(-1);
    if (src_id < 0 || src_id >= _hx_farr_count) return hexa_int(-1);
    if (dst_id < 0 || dst_id >= _hx_farr_count) return hexa_int(-1);
    return hexa_int(_hx_cuda_farr_transpose_scatter_gpu(
        src_id, dst_id, rows, cols, dst_off));
#else
    // No-CUDA: -1 → the matmul primitive's host transpose loop runs
    // (did_dev_scatter stays 0). Byte-eq with the verified host scatter.
    (void)src_v;(void)dst_v;(void)rows_v;(void)cols_v;(void)dst_off_v;
    return hexa_int(-1);
#endif
}

// ── The primitives under test (spliced, NOT forked) ─────────────────────
// The .sh splices, AT the marker below and in the SAME order as the a2
// build (tool/flame_phase4d7_a2_build.sh:132 `cat PRIM_MATMUL PRIM_FWD`):
//   1. tool/flame_phase4d6_matmul_primitives.c   (the projection primitive
//      flame_proj_batch_generic_primitive — the block calls it 7×)
//   2. tool/flame_phase4d7_block_fwd_primitive.c (the _cpu reference body
//      + the _gpu candidate body + the dim-gated dispatch)
// matmul FIRST so flame_proj_batch_generic_primitive is in scope when the
// block fwd references it. NEITHER file is modified. FLAME_BLOCK_PRIM_
// STANDALONE is NOT defined → the GPU body + the dim-gate dispatch (both
// under the single `#ifndef FLAME_BLOCK_PRIM_STANDALONE` guard) are kept;
// the trivial standalone wrapper (`#ifdef FLAME_BLOCK_PRIM_STANDALONE`)
// compiles out naturally.
//@FLAME_ORACLE_SPLICE_MARKER@

// ════════════════════════════════════════════════════════════════════════
// Deterministic input generators (reproducible across runs / hosts)
// ════════════════════════════════════════════════════════════════════════
// Same spirit as the d7 oracle's oracle_gen_w/x: bounded O(1) values so
// flame_g7_dt_exp's range-halve and flame_g7_dt_sqrt's Newton iterate are
// both exercised, and the residual stream stays numerically tame.
static double gen_X(int i)   { return cos(0.017 * (double)(i + 5)) * 0.20; }
static double gen_Bp(int i)  { return sin(0.011 * (double)(i + 1)) * 0.12; }
static double gen_cos(int i) { return cos(0.0090 * (double)(i + 1)); }
static double gen_sin(int i) { return sin(0.0090 * (double)(i + 1)); }

// ── compare one Bc field over its valid range ───────────────────────────
static double cmp_range(const double* a, const double* b, int off, int n,
                        int* nan_hit, int* exact) {
    double mx = 0.0;
    for (int i = 0; i < n; i++) {
        double x = a[off + i], y = b[off + i];
        if (isnan(x) || isinf(x) || isnan(y) || isinf(y)) { *nan_hit = 1; continue; }
        double d = fabs(x - y);
        if (d != 0.0) *exact = 0;
        if (d > mx) mx = d;
    }
    return mx;
}

int main(void) {
    // ── the mid-size GPU-gated config (see header) ──
    const int T = 16, d = 384, nh = 6, nkv = 2, h = 512;
    const int hd  = d / nh;            // 64
    const int kvd = nkv * (d / nh);    // 128

    // Bp size — bp_off_* formulas (block primitive L119-122):
    //   WD + h·d   where WD = 2d + 2d² + 2·kvd·d + 2·h·d  → +h·d.
    const long Bp_size = (long)2*d + 2L*d*d + 2L*kvd*d + 3L*h*d;
    // Bc size — last field oR2inv at 8Td+2Tkvd+nh·T·T+3Th+T, +T (block L139).
    const long Bc_size = 8L*T*d + 2L*T*kvd + (long)nh*T*T + 3L*T*h + 2L*T;
    const long X_size  = (long)T * d;
    const long CS_size = (long)T * hd;   // cos/sin tables [T·hd]

    printf("=== flame Phase 4-D-9 — WHOLE-BLOCK fwd GPU-PATH byte-eq ORACLE ===\n");
    printf("  config : T=%d d=%d nh=%d nkv=%d h=%d  (hd=%d kvd=%d)\n",
           T, d, nh, nkv, h, hd, kvd);
    printf("  block dim-gate : d=%d > FLAME_GPU_RESIDENT_THRESHOLD(256)"
           "  → _gpu chain\n", d);
    printf("  cuBLAS gate    : Q d_out·d_in = %d  (threshold 8192)\n", d*d);
#ifdef HEXA_CUDA
    printf("  build  : -DHEXA_CUDA  → candidate = flame_block_*_gpu "
           "(forge + cuBLAS) ACTIVE\n");
#else
    printf("  build  : no-CUDA     → candidate = flame_block_*_cpu "
           "(harness self-check, $0 gate)\n");
#endif
    printf("  Bp=%ld  Bc=%ld  X=%ld  cos/sin=%ld (doubles)\n\n",
           Bp_size, Bc_size, X_size, CS_size);

    // ── deterministic init ──
    double* X_d  = (double*)malloc(sizeof(double) * X_size);
    double* Bp_d = (double*)malloc(sizeof(double) * Bp_size);
    double* cs_d = (double*)malloc(sizeof(double) * CS_size);
    double* sn_d = (double*)malloc(sizeof(double) * CS_size);
    for (long i = 0; i < X_size;  i++) X_d[i]  = gen_X((int)i);
    for (long i = 0; i < Bp_size; i++) Bp_d[i] = gen_Bp((int)i);
    for (long i = 0; i < CS_size; i++) cs_d[i] = gen_cos((int)i);
    for (long i = 0; i < CS_size; i++) sn_d[i] = gen_sin((int)i);

    // shared inputs (X / Bp / cos / sin) — one farr each, both runs read
    // them read-only (the block writes only into Bc), so a single copy is
    // safe and keeps the two runs on byte-identical inputs.
    int X_id  = _oracle_farr_alloc(X_size,  X_d);
    int Bp_id = _oracle_farr_alloc(Bp_size, Bp_d);
    int cos_id= _oracle_farr_alloc(CS_size, cs_d);
    int sin_id= _oracle_farr_alloc(CS_size, sn_d);

    // ── candidate: GPU path under -DHEXA_CUDA, else the _cpu body ──
    int Bc_cand_id = _oracle_farr_alloc(Bc_size, NULL);
#ifdef HEXA_CUDA
    // d=384 > 256 so the dispatch would route here anyway; call _gpu
    // explicitly so the intent is unambiguous in the instrument.
    flame_block_generic_fwd_primitive_gpu(
        X_id, Bp_id, Bc_cand_id, cos_id, sin_id, T, d, nh, nkv, h);
#else
    flame_block_generic_fwd_primitive_cpu(
        X_id, Bp_id, Bc_cand_id, cos_id, sin_id, T, d, nh, nkv, h);
#endif
    // re-fetch (the primitive's farr_zeros calls may have realloc'd table)
    double* Bc_cand = _hx_farr_table[Bc_cand_id].buf;

    // ── reference: the verified-good _cpu block body, DIRECTLY ──
    int Bc_ref_id = _oracle_farr_alloc(Bc_size, NULL);
    flame_block_generic_fwd_primitive_cpu(
        X_id, Bp_id, Bc_ref_id, cos_id, sin_id, T, d, nh, nkv, h);
    double* Bc_ref = _hx_farr_table[Bc_ref_id].buf;
    Bc_cand = _hx_farr_table[Bc_cand_id].buf;   // re-fetch post-realloc

    // ── Bc field offsets (block primitive L124-139) ──
    const int oXout  = 0;
    const int oHstate= T*d;
    const int oRin   = 2*T*d;
    const int oQ     = 7*T*d;
    const int oP     = 8*T*d + 2*T*kvd;
    const int oSwS   = 8*T*d + 2*T*kvd + nh*T*T + 2*T*h;

    int nan_hit = 0, exact = 1;
    double m_xout = cmp_range(Bc_cand, Bc_ref, oXout,   T*d,        &nan_hit, &exact);
    double m_hst  = cmp_range(Bc_cand, Bc_ref, oHstate, T*d,        &nan_hit, &exact);
    double m_rin  = cmp_range(Bc_cand, Bc_ref, oRin,    T*d,        &nan_hit, &exact);
    double m_q    = cmp_range(Bc_cand, Bc_ref, oQ,      T*nh*hd,    &nan_hit, &exact);
    double m_sws  = cmp_range(Bc_cand, Bc_ref, oSwS,    T*h,        &nan_hit, &exact);
    // oP: only the causal region (j ≤ i) per head is written; cells j>i
    // stay 0 in both → comparing the full nh·T·T block is exact-safe but
    // we report it explicitly as the causal-region max.
    double m_p = 0.0;
    for (int hh = 0; hh < nh; hh++)
        for (int i = 0; i < T; i++) {
            int base = oP + (hh*T + i)*T;
            double mm = cmp_range(Bc_cand, Bc_ref, base, i+1, &nan_hit, &exact);
            if (mm > m_p) m_p = mm;
        }

    double max_abs = m_xout;
    if (m_hst > max_abs) max_abs = m_hst;
    if (m_rin > max_abs) max_abs = m_rin;
    if (m_q   > max_abs) max_abs = m_q;
    if (m_sws > max_abs) max_abs = m_sws;
    if (m_p   > max_abs) max_abs = m_p;

    const double TOL_BLOCK = 1e-8;   // ~1e-9 measured end-to-end, +1 order
    printf("  ref  Xout[0..3] = %.15f %.15f %.15f %.15f\n",
           Bc_ref[oXout+0], Bc_ref[oXout+1], Bc_ref[oXout+2], Bc_ref[oXout+3]);
    printf("  cand Xout[0..3] = %.15f %.15f %.15f %.15f\n",
           Bc_cand[oXout+0], Bc_cand[oXout+1], Bc_cand[oXout+2], Bc_cand[oXout+3]);
    printf("  per-field max|Δ|:  oXout=%.3e  oHstate=%.3e  oRin=%.3e\n",
           m_xout, m_hst, m_rin);
    printf("                     oQ=%.3e  oP(causal)=%.3e  oSwS=%.3e\n",
           m_q, m_p, m_sws);
    printf("  max|Δ| = %.3e   (TOL_BLOCK = %.0e)\n\n", max_abs, TOL_BLOCK);

    int rc;
    if (nan_hit) {
        printf("FAIL  F-PHASE4D9-BLOCK-FWD-ORACLE  NaN/Inf in output "
               "(the fire #14 -nan signature)\n");
        rc = 1;
    } else if (exact) {
        printf("PASS  F-PHASE4D9-BLOCK-FWD-ORACLE  max|Δ|=0.0  STRICT "
               "byte-eq vs verified-good CPU block reference\n");
        rc = 0;
    } else if (max_abs <= TOL_BLOCK) {
        printf("PASS  F-PHASE4D9-BLOCK-FWD-ORACLE  max|Δ| ≤ TOL_BLOCK  "
               "(forge Phase-B + cuBLAS reorder, per-op contract)\n");
        rc = 0;
    } else {
        printf("FAIL  F-PHASE4D9-BLOCK-FWD-ORACLE  max|Δ| > TOL_BLOCK  "
               "— block GPU-path REGRESSION (fire #13 gn2-drift signature)\n");
        rc = 1;
    }

    free(X_d); free(Bp_d); free(cs_d); free(sn_d);
    return rc;
}
