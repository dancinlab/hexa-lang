// ════════════════════════════════════════════════════════════════════════
// tool/flame_phase4d9_orin_clobber_oracle.c — $0 TARGETED INSTRUMENTATION
// ORACLE: pinpoint the GPU-path Bc[oRin] clobber step.
//
// WHY
// ───
// The whole-block fwd GPU oracle (flame_phase4d9_block_fwd_oracle) localised
// the divergence to ONE field: oRin (max|Δ|=1.704e-1) while oXout/oHstate/
// oQ/oP/oSwS are byte-eq. oQ byte-eq proves Bc[oRin] was CORRECT when step-2
// (Q proj) read it → some step AFTER step-2 overwrites Bc[oRin]. The block
// oracle's no-CUDA path is _cpu-vs-_cpu (its forge shims are CPU stubs with
// NO device buffer) so it cannot localise WHICH step, nor reproduce a
// substrate-residence clobber at $0.
//
// This instrument is a FAITHFUL $0 model of the runtime_cuda.c device
// residence state machine for Bc: it maintains a SIMULATED device-side Bc
// buffer and applies the EXACT _h2d / _d2h / pin / H2D-skip predicates
// copied verbatim from self/cuda/runtime_cuda.c (lines 161-244, 373-388,
// 1845-1908 — the H2D-skip at :190, the full-buffer _d2h at :1906). The
// REAL primitives (flame_phase4d6_matmul_primitives.c +
// flame_phase4d7_block_fwd_primitive.c) are spliced UNMODIFIED, exactly as
// flame_phase4d9_block_fwd_oracle.sh splices them, and run through the
// transpose-scatter path (mm_c_id ≥ 0 forced for the d²>8192 projections,
// reproducing the d768 / d=384 GPU dim-gate). After EVERY forge op that
// touches Bc the shim snapshots Bc[oRin][0..3] + a slab checksum and prints
// the per-step trace, so the exact clobbering op is named.
//
// The clobber is OFFSET/RESIDENCE-STRUCTURAL (the H2D-skip + full-D2H
// arithmetic is identical on CPU and GPU), so it reproduces here at $0 —
// per the campaign's instrument-first methodology. A genuinely
// GPU-kernel-numeric bug would NOT reproduce here (this models residence,
// not float kernels), which is itself a useful discriminant.
//
// Build / run: tool/flame_phase4d9_orin_clobber_oracle.sh
// ════════════════════════════════════════════════════════════════════════

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

typedef struct { int tag; union { int64_t i; double f; void* p; }; } HexaVal;
#define TAG_INT 1
#define TAG_FLOAT 2
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

// ── runtime_cuda.c residence enum (verbatim, :98) ──
enum { FARR_HOST = 0, FARR_DEVICE = 1, FARR_MIRRORED = 2 };

// ── simulated device slot table (models runtime_cuda.c g_slots) ──
// d_buf here is a malloc'd host array standing in for device memory.
typedef struct { double* d_buf; int64_t len; int64_t view_base; } _SimSlot;
static _SimSlot* g_slots   = NULL;
static int64_t   g_slot_cap = 0;

static int _ensure_slot_cap(int64_t id) {
    if (id < g_slot_cap) return 0;
    int64_t nc = g_slot_cap < 16 ? 16 : g_slot_cap;
    while (nc <= id) nc *= 2;
    g_slots = (_SimSlot*)realloc(g_slots, nc * sizeof(_SimSlot));
    for (int64_t i = g_slot_cap; i < nc; i++) {
        g_slots[i].d_buf = NULL; g_slots[i].len = 0; g_slots[i].view_base = -1;
    }
    g_slot_cap = nc;
    return 0;
}

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
    _ensure_slot_cap(id);
    return id;
}

static HexaVal hexa_farr_zeros(HexaVal n_v) {
    return hexa_int(_oracle_farr_alloc(HX_INT(n_v), NULL));
}
static HexaVal hexa_farr_free(HexaVal id_v) { (void)id_v; return hexa_int(0); }
static HexaVal farr_zeros_fn(HexaVal a) { return hexa_farr_zeros(a); }
static HexaVal farr_free_fn(HexaVal a)  { return hexa_farr_free(a);  }
#define farr_zeros farr_zeros_fn
#define farr_free  farr_free_fn
#define hexa_call1(f, a1) (f)(a1)
#ifndef HEXA_FORGE_OUT_DEVICE_KEEP
#define HEXA_FORGE_OUT_DEVICE_KEEP 1
#endif

// ── instrumentation: the oRin slab snapshot ─────────────────────────────
// Set by main() once the config is known (oRin = 2*T*d, slab len T*d).
static int  g_oRin = -1, g_orin_len = 0;
static int  g_step = 0;
static const double* g_golden_orin = NULL;  // correct post-step-1 oRin

static double _orin_checksum(const double* Bc) {
    double s = 0.0;
    for (int i = 0; i < g_orin_len; i++) s += Bc[g_oRin + i] * (i + 1);
    return s;
}
static double _orin_maxdelta_vs_golden(const double* Bc) {
    if (!g_golden_orin) return 0.0;
    double mx = 0.0;
    for (int i = 0; i < g_orin_len; i++) {
        double d = fabs(Bc[g_oRin + i] - g_golden_orin[i]);
        if (d > mx) mx = d;
    }
    return mx;
}
static void _snap(const char* tag, int Bc_id) {
    if (g_oRin < 0) return;
    const double* Bc = _hx_farr_table[Bc_id].buf;
    double cs = _orin_checksum(Bc);
    double md = _orin_maxdelta_vs_golden(Bc);
    printf("  [snap %2d] %-34s oRin[0..3]= % .6e % .6e % .6e % .6e  "
           "cksum=% .6e  max|Δ vs step1|=%.3e%s\n",
           g_step, tag, Bc[g_oRin+0], Bc[g_oRin+1], Bc[g_oRin+2],
           Bc[g_oRin+3], cs, md, (md > 1e-9 ? "   <== CLOBBER" : ""));
}

// ════════════════════════════════════════════════════════════════════════
// runtime_cuda.c residence state machine — FAITHFUL $0 MODEL
// (verbatim logic from self/cuda/runtime_cuda.c; cudaMalloc/cudaMemcpy →
//  malloc/memcpy on a simulated device buffer. NOTHING here is modified
//  from the substrate's control flow — only the memory backend.)
// ════════════════════════════════════════════════════════════════════════
static int _h2d(int64_t id) {                       // runtime_cuda.c:161
    if (id < 0 || id >= _hx_farr_count) return -1;
    _ensure_slot_cap(id);
    HexaFarrEntry* e = &_hx_farr_table[id];
    _SimSlot* s = &g_slots[id];
    if (s->view_base >= 0 && s->d_buf) {            // :173 view
        e->d_buf = (void*)s->d_buf; e->dirty_dev = 0; return 0;
    }
    if (!e->buf || e->len <= 0) return -1;
    if ((e->loc == FARR_DEVICE || e->loc == FARR_MIRRORED) &&   // :190 H2D-SKIP
        !e->dirty_host && s->d_buf && s->len == e->len) {
        e->d_buf = (void*)s->d_buf; e->dirty_dev = 0;
        return 0;                                   // SKIP cudaMemcpy H2D
    }
    if (!s->d_buf || s->len != e->len) {            // :196 (re)alloc
        if (s->d_buf) free(s->d_buf);
        s->d_buf = (double*)malloc((size_t)e->len * sizeof(double));
        s->len = e->len;
    }
    memcpy(s->d_buf, e->buf, (size_t)e->len * sizeof(double)); // :208 H2D
    e->d_buf = (void*)s->d_buf;
    if (e->loc == FARR_HOST) e->loc = FARR_MIRRORED;
    e->dirty_dev = 0;
    return 0;
}
static int _d2h(int64_t id) {                       // runtime_cuda.c:224
    if (id < 0 || id >= _hx_farr_count) return -1;
    if (id >= g_slot_cap) return -1;
    HexaFarrEntry* e = &_hx_farr_table[id];
    _SimSlot* s = &g_slots[id];
    if (!e->buf || !s->d_buf || s->len != e->len) return -1;
    memcpy(e->buf, s->d_buf, (size_t)e->len * sizeof(double));  // :233 full D2H
    e->dirty_host = 0;
    if (e->loc == FARR_DEVICE) e->loc = FARR_MIRRORED;
    return 0;
}

// ── residence / disposition surface (runtime.c + runtime_cuda.c) ────────
static HexaVal hexa_farr_to_device(HexaVal h_v) {
    int64_t id = HX_INT(h_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_int(0);
    return hexa_int(_h2d(id) == 0 ? 1 : 0);
}
static HexaVal hexa_farr_to_host(HexaVal h_v) {
    int64_t id = HX_INT(h_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_int(0);
    return hexa_int(_d2h(id) == 0 ? 1 : 0);
}
static HexaVal hexa_farr_set_out_disposition(HexaVal d_v) { (void)d_v; return hexa_int(0); }
static HexaVal hexa_farr_dev_view(HexaVal base_v, HexaVal off_v, HexaVal len_v) {
    int64_t base_id = HX_INT(base_v), offset = HX_INT(off_v), len = HX_INT(len_v);
    if (base_id < 0 || base_id >= _hx_farr_count) return hexa_int(-1);
    if (offset < 0 || len <= 0) return hexa_int(-1);
    if (offset + len > _hx_farr_table[base_id].len) return hexa_int(-1);
    HexaVal vh = hexa_farr_zeros(hexa_int(len));
    int64_t view_id = HX_INT(vh);
    if (view_id < 0) return hexa_int(-1);
    // model runtime_cuda.c:340 dev_view — alias base device buffer + off
    _ensure_slot_cap(base_id); _ensure_slot_cap(view_id);
    _SimSlot* bs = &g_slots[base_id];
    if (!bs->d_buf) {  // base not device-resident → materialise host slice
        double* bb = _hx_farr_table[base_id].buf;
        double* vb = _hx_farr_table[view_id].buf;
        if (bb && vb) for (int64_t i = 0; i < len; i++) vb[i] = bb[offset + i];
        return hexa_int(view_id);
    }
    _SimSlot* vs = &g_slots[view_id];
    vs->d_buf = bs->d_buf + offset; vs->len = len; vs->view_base = base_id;
    HexaFarrEntry* ve = &_hx_farr_table[view_id];
    ve->d_buf = (void*)vs->d_buf; ve->loc = FARR_DEVICE;
    ve->dirty_host = 1; ve->dirty_dev = 0;
    return hexa_int(view_id);
}
static HexaVal hexa_farr_pin_device(HexaVal h_v) {  // runtime_cuda.c:373
    int64_t id = HX_INT(h_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_int(-1);
    if (_h2d(id) != 0) return hexa_int(-1);
    HexaFarrEntry* e = &_hx_farr_table[id];
    e->pinned = 1;
    if (e->loc == FARR_HOST) e->loc = FARR_MIRRORED;
    return hexa_int(1);
}
static HexaVal hexa_farr_unpin_device(HexaVal h_v) {// runtime_cuda.c:382
    int64_t id = HX_INT(h_v);
    if (id < 0 || id >= _hx_farr_count) return hexa_int(-1);
    HexaFarrEntry* e = &_hx_farr_table[id];
    e->pinned = 0;
    if (e->dirty_dev) (void)_d2h(id);
    return hexa_int(1);
}

// ── forge math ops that DO NOT touch Bc: CPU math into a fresh farr ─────
// (mirrors the no-CUDA helpers in flame_phase4d9_block_fwd_oracle.c — these
//  return a NEW farr id; they never write Bc, so they cannot clobber oRin.
//  Using CPU math keeps the harness numerically tame; what we test is the
//  RESIDENCE clobber, not the kernel float math.)
static int64_t _cpu_rmsnorm(int64_t x_id, int64_t R, int64_t C, double eps) {
    if (x_id < 0 || x_id >= _hx_farr_count || R <= 0 || C <= 0) return -1;
    if (!(eps >= 0.0)) return -1;
    if (!_hx_farr_table[x_id].buf || _hx_farr_table[x_id].len < R*C) return -1;
    int64_t oid = HX_INT(hexa_farr_zeros(hexa_int(R*C)));
    const double* X = _hx_farr_table[x_id].buf;
    double* Y = _hx_farr_table[oid].buf;
    double invC = 1.0/(double)C;
    for (int64_t r = 0; r < R; r++) {
        const double* xr = X + r*C; double* yr = Y + r*C; double ms = 0.0;
        for (int64_t j = 0; j < C; j++) ms += xr[j]*xr[j];
        ms *= invC; double inv = 1.0/sqrt(ms + eps);
        for (int64_t j = 0; j < C; j++) yr[j] = xr[j]*inv;
    }
    return oid;
}
static int64_t _cpu_add(int64_t a, int64_t b, int64_t n) {
    if (a<0||a>=_hx_farr_count||b<0||b>=_hx_farr_count||n<=0) return -1;
    int64_t oid = HX_INT(hexa_farr_zeros(hexa_int(n)));
    const double* A=_hx_farr_table[a].buf; const double* B=_hx_farr_table[b].buf;
    double* O=_hx_farr_table[oid].buf;
    for (int64_t i=0;i<n;i++) O[i]=A[i]+B[i];
    return oid;
}
static int64_t _cpu_mul(int64_t a, int64_t b, int64_t n) {
    if (a<0||a>=_hx_farr_count||b<0||b>=_hx_farr_count||n<=0) return -1;
    int64_t oid = HX_INT(hexa_farr_zeros(hexa_int(n)));
    const double* A=_hx_farr_table[a].buf; const double* B=_hx_farr_table[b].buf;
    double* O=_hx_farr_table[oid].buf;
    for (int64_t i=0;i<n;i++) O[i]=A[i]*B[i];
    return oid;
}
static int64_t _cpu_silu(int64_t x_id, int64_t n) {
    if (x_id<0||x_id>=_hx_farr_count||n<=0) return -1;
    int64_t oid = HX_INT(hexa_farr_zeros(hexa_int(n)));
    const double* X=_hx_farr_table[x_id].buf; double* Y=_hx_farr_table[oid].buf;
    for (int64_t i=0;i<n;i++) { double x=X[i]; Y[i]=x*(1.0/(1.0+exp(-x))); }
    return oid;
}

static HexaVal hexa_farr_rmsnorm_rows_gpu(HexaVal x_v, HexaVal r_v,
                                          HexaVal c_v, HexaVal eps_v) {
    int64_t x=HX_INT(x_v), R=HX_INT(r_v), C=HX_INT(c_v);
    double eps = (eps_v.tag==TAG_INT)?(double)eps_v.i:eps_v.f;
    return hexa_int(_cpu_rmsnorm(x,R,C,eps));
}
static HexaVal hexa_farr_softmax_rows_gpu(HexaVal x_v, HexaVal r_v, HexaVal c_v) {
    (void)x_v;(void)r_v;(void)c_v; return hexa_int(-1);  // → block CPU fallback
}
static HexaVal hexa_farr_add_gpu(HexaVal a_v, HexaVal b_v, HexaVal n_v) {
    return hexa_int(_cpu_add(HX_INT(a_v),HX_INT(b_v),HX_INT(n_v)));
}
static HexaVal hexa_farr_mul_gpu(HexaVal a_v, HexaVal b_v, HexaVal n_v) {
    return hexa_int(_cpu_mul(HX_INT(a_v),HX_INT(b_v),HX_INT(n_v)));
}
static HexaVal hexa_farr_silu_gpu(HexaVal x_v, HexaVal n_v) {
    return hexa_int(_cpu_silu(HX_INT(x_v),HX_INT(n_v)));
}
static HexaVal hexa_farr_rope_gpu(HexaVal t_v, HexaVal cos_v, HexaVal sin_v,
                                  HexaVal T_v, HexaVal nh_v, HexaVal hd_v) {
    (void)t_v;(void)cos_v;(void)sin_v;(void)T_v;(void)nh_v;(void)hd_v;
    return hexa_int(-1);  // → primitive's CPU rope fallback (does not touch Bc residence)
}

// ── matmul: model runtime_cuda.c — output left device-resident (RFC 057) ─
// The matmul writes a FRESH output farr (scratch C), then the primitive
// transpose-scatters it into Bc. We model the cuBLAS output being left
// loc=FARR_DEVICE/dirty_dev with a live device slot (RFC 057 §6.1), exactly
// what flame_proj_gpu_matmul_g_ex relies on for mm_c_id ≥ 0.
static HexaVal hexa_farr_matmul_gpu(HexaVal a_v, HexaVal ar_v, HexaVal ac_v,
                                    HexaVal b_v, HexaVal bc_v) {
    int64_t M=HX_INT(ar_v), K=HX_INT(ac_v), N=HX_INT(bc_v);
    int64_t a_id=HX_INT(a_v), b_id=HX_INT(b_v);
    if (M<=0||K<=0||N<=0) return hexa_int(-1);
    if (a_id<0||a_id>=_hx_farr_count||b_id<0||b_id>=_hx_farr_count) return hexa_int(-1);
    int64_t c_id = _oracle_farr_alloc(M*N, NULL);
    if (c_id < 0) return hexa_int(-1);
    const double* A=_hx_farr_table[a_id].buf;
    const double* B=_hx_farr_table[b_id].buf;
    double* C=_hx_farr_table[c_id].buf;
    for (int64_t i=0;i<M*N;i++) C[i]=0.0;
    for (int64_t i=0;i<M;i++) for (int64_t k=0;k<K;k++) {
        double aik=A[i*K+k];
        for (int64_t j=0;j<N;j++) C[i*N+j]+=aik*B[k*N+j];
    }
    // RFC 057 §6.1: cuBLAS output left device-resident (mirror :478).
    _ensure_slot_cap(c_id);
    g_slots[c_id].d_buf = (double*)malloc((size_t)(M*N)*sizeof(double));
    g_slots[c_id].len = M*N;
    memcpy(g_slots[c_id].d_buf, C, (size_t)(M*N)*sizeof(double));
    _hx_farr_table[c_id].d_buf = g_slots[c_id].d_buf;
    _hx_farr_table[c_id].loc = FARR_MIRRORED;
    _hx_farr_table[c_id].dirty_host = 0;
    return hexa_int(c_id);
}

// snoop: only the long-lived Bc handle is traced (set by main()).
static int g_snoop_bc_id = -1;

// The block's attention step extern-decls this PHASE4D9 causal-softmax
// kernel under #ifdef HEXA_CUDA. Returning non-zero makes
// flame_g7_causal_softmax_rows_gpu() return -1 → the primitive's VERBATIM
// host softmax fallback runs (writes Bc[oP] host-side only — orthogonal to
// the oRin residence clobber, and keeps the harness numerically tame).
int _hx_cuda_farr_causal_softmax_rows_gpu(int64_t x_id, int64_t R,
                                          int64_t T, int64_t out_id) {
    (void)x_id;(void)R;(void)T;(void)out_id; return -1;
}

// ── THE transpose-scatter — FAITHFUL model of runtime_cuda.c:1845-1908 ──
// This is the d768 / d=384 GPU-resident projection write path. The
// per-step oRin snapshot brackets it so the clobber is named precisely.
static HexaVal hexa_farr_transpose_scatter_gpu(HexaVal src_v, HexaVal dst_v,
                                               HexaVal rows_v, HexaVal cols_v,
                                               HexaVal dst_off_v) {
    int64_t src_id=HX_INT(src_v), dst_id=HX_INT(dst_v);
    int64_t rows=HX_INT(rows_v), cols=HX_INT(cols_v), dst_off=HX_INT(dst_off_v);
    if (src_id<0||dst_id<0) return hexa_int(-1);
    if (rows<=0||cols<=0||dst_off<0) return hexa_int(-1);
    if (src_id>=_hx_farr_count||dst_id>=_hx_farr_count) return hexa_int(-1);
    int64_t total = rows*cols;
    if (_hx_farr_table[src_id].len < total) return hexa_int(-1);
    if (_hx_farr_table[dst_id].len < dst_off+total) return hexa_int(-1);

    char tag[80];
    int is_bc = (dst_id == g_snoop_bc_id);
    if (is_bc) {
        snprintf(tag, sizeof tag, "scatter pre  (dst_off=%lld)",
                 (long long)dst_off);
        _snap(tag, (int)dst_id);
        HexaFarrEntry* e = &_hx_farr_table[dst_id];
        printf("            Bc residence: loc=%s dirty_host=%d slot_live=%d  "
               "→ _h2d will %s\n",
               e->loc==0?"HOST":(e->loc==1?"DEVICE":"MIRRORED"),
               e->dirty_host, g_slots[dst_id].d_buf!=NULL,
               ((e->loc==FARR_DEVICE||e->loc==FARR_MIRRORED) && !e->dirty_host
                && g_slots[dst_id].d_buf && g_slots[dst_id].len==e->len)
                 ? "SKIP (device stays stale)" : "UPLOAD host→device");
    }

    if (_h2d(src_id) != 0) return hexa_int(-1);     // :1880
    if (_h2d(dst_id) != 0) return hexa_int(-1);     // :1881  ← H2D-skip risk
    double* SRC = g_slots[src_id].d_buf;
    double* DST = g_slots[dst_id].d_buf;
    if (!SRC || !DST) return hexa_int(-1);
    // kernel: dst[dst_off + c*rows + r] = src[r*cols + c]  (:1518 / :1808)
    for (int64_t r = 0; r < rows; r++)
        for (int64_t c = 0; c < cols; c++)
            DST[dst_off + c*rows + r] = SRC[r*cols + c];
    if (_d2h(dst_id) != 0) return hexa_int(-1);     // :1906  full-buffer D2H

    if (is_bc) {
        snprintf(tag, sizeof tag, "scatter post (dst_off=%lld)",
                 (long long)dst_off);
        _snap(tag, (int)dst_id);
    }
    return hexa_int(0);
}
//@FLAME_ORACLE_SPLICE_MARKER@

// ════════════════════════════════════════════════════════════════════════
// deterministic inputs (identical generators to the block-fwd oracle)
// ════════════════════════════════════════════════════════════════════════
static double gen_X(int i)   { return cos(0.017 * (double)(i + 5)) * 0.20; }
static double gen_Bp(int i)  { return sin(0.011 * (double)(i + 1)) * 0.12; }
static double gen_cos(int i) { return cos(0.0090 * (double)(i + 1)); }
static double gen_sin(int i) { return sin(0.0090 * (double)(i + 1)); }

int main(void) {
    const int T = 16, d = 384, nh = 6, nkv = 2, h = 512;
    const int hd  = d / nh;
    const int kvd = nkv * (d / nh);
    const long Bp_size = (long)2*d + 2L*d*d + 2L*kvd*d + 3L*h*d;
    const long Bc_size = 8L*T*d + 2L*T*kvd + (long)nh*T*T + 3L*T*h + 2L*T;
    const long X_size  = (long)T * d;
    const long CS_size = (long)T * hd;

    g_oRin = 2*T*d;  g_orin_len = T*d;

    printf("=== flame Phase 4-D-9 — Bc[oRin] CLOBBER-STEP $0 ORACLE ===\n");
    printf("  config : T=%d d=%d nh=%d nkv=%d h=%d (hd=%d kvd=%d)\n",
           T, d, nh, nkv, h, hd, kvd);
    printf("  oRin = 2*T*d = %d   slab len T*d = %d   [%d, %d)\n",
           g_oRin, g_orin_len, g_oRin, g_oRin + g_orin_len);
    printf("  model : runtime_cuda.c residence FSM ($0 sim device buffer);\n");
    printf("          real primitives spliced UNMODIFIED; transpose-scatter\n");
    printf("          path ACTIVE (mm_c_id≥0 for d²=%d > 8192).\n\n", d*d);

    double* X_d  = (double*)malloc(sizeof(double)*X_size);
    double* Bp_d = (double*)malloc(sizeof(double)*Bp_size);
    double* cs_d = (double*)malloc(sizeof(double)*CS_size);
    double* sn_d = (double*)malloc(sizeof(double)*CS_size);
    for (long i=0;i<X_size;i++)  X_d[i]=gen_X((int)i);
    for (long i=0;i<Bp_size;i++) Bp_d[i]=gen_Bp((int)i);
    for (long i=0;i<CS_size;i++) cs_d[i]=gen_cos((int)i);
    for (long i=0;i<CS_size;i++) sn_d[i]=gen_sin((int)i);

    int X_id  = _oracle_farr_alloc(X_size,  X_d);
    int Bp_id = _oracle_farr_alloc(Bp_size, Bp_d);
    int cos_id= _oracle_farr_alloc(CS_size, cs_d);
    int sin_id= _oracle_farr_alloc(CS_size, sn_d);
    int Bc_id = _oracle_farr_alloc(Bc_size, NULL);
    g_snoop_bc_id = Bc_id;

    // ── reference: the verified _cpu block → the "intended" oRin ──
    int Bc_ref_id = _oracle_farr_alloc(Bc_size, NULL);
    flame_block_generic_fwd_primitive_cpu(
        X_id, Bp_id, Bc_ref_id, cos_id, sin_id, T, d, nh, nkv, h);
    double* Bc_ref = _hx_farr_table[Bc_ref_id].buf;
    static double golden[1<<20];
    for (int i = 0; i < g_orin_len; i++) golden[i] = Bc_ref[g_oRin + i];
    g_golden_orin = golden;
    printf("  reference _cpu oRin[0..3] = % .6e % .6e % .6e % .6e\n",
           golden[0], golden[1], golden[2], golden[3]);
    printf("  (this is the CORRECT RMSNorm-1 output the GPU path must keep)\n\n");

    // ── candidate: the GPU-resident block, residence FSM modelled ──
    printf("  ── per-op Bc[oRin] trace through flame_block_*_gpu ──\n");
    g_step = 0;
    flame_block_generic_fwd_primitive_gpu(
        X_id, Bp_id, Bc_id, cos_id, sin_id, T, d, nh, nkv, h);
    double* Bc = _hx_farr_table[Bc_id].buf;

    // TOL = 1e-8: same justification as the block-fwd oracle (the residence
    // model uses libm rmsnorm so a ~1e-16 reorder floor exists; the
    // structural clobber is 1.704e-1, 15 orders above — unmissable).
    double mx = _orin_maxdelta_vs_golden(Bc);
    printf("\n  FINAL block-end max|Δ(oRin vs _cpu)| = %.6e\n", mx);
    free(X_d);free(Bp_d);free(cs_d);free(sn_d);
    if (mx > 1e-8) {
        printf("FAIL  F-PHASE4D9-ORIN-CLOBBER  oRin RESIDENCE-CLOBBER present\n");
        printf("      — the <== CLOBBER line above names the exact op +\n");
        printf("      dst_off (pre-fix expected: FIRST scatter, dst_off=oQ,\n");
        printf("      max|Δ|=1.704e-1, bit-identical to the d768 GPU oracle).\n");
        return 1;
    }
    printf("PASS  F-PHASE4D9-ORIN-CLOBBER  Bc[oRin] STABLE across every\n");
    printf("      transpose-scatter (max|Δ| = residence-model FP floor) —\n");
    printf("      the host-authoritative Bc contract holds; clobber gone.\n");
    return 0;
}
