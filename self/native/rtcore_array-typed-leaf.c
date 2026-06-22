// self/native/rtcore_array-typed-leaf.c — zero-c leg-B ARRAY-TYPED-LEAF SEED (link de-risk).
//
// Supplies 10 LEAF typed-array ctors/accessors + zeros-leaf builders that
// runtime_core.c externs away under HEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE (the
// narrow array-typed-leaf-only guard, NOT the broad whole-runtime
// HEXA_RT_SELFEMIT). Compiled to a SEPARATE .o
// (build/rtcore_array_typed_leaf_native.o) and linked when
// HEXA_ZEROC_RT_CORE_ARRAY_TYPED_LEAF=1, so the build LINKS these bodies from a
// standalone object instead of compiling them inline in runtime_core.c.
//
// PURPOSE = extend the r4 leaf-cluster (rtcore_leaf.c), r5 clean-6 arith
// (rtcore_arith.c) and r7 clean-4 transcendental (rtcore_math.c) to the next
// seed-portable cluster: the LEAF typed-array constructors/accessors over raw
// libc malloc/calloc/realloc + external HexaVal box helpers. It does NOT drop the
// .c file (runtime_core.c drop is all-or-nothing — 250 symbols; this links 10
// more). Default build (flag unset) is byte-IDENTICAL: these bodies are not
// compiled and the inline #else bodies in runtime_core.c are used verbatim.
//
// CLUSTER (10 fns, all emitted UNCONDITIONALLY inline — no #else arm in the
// shipping HEXA_HAS_HEXA_RT_STDLIB build, so the frozen-static WALL question of
// r6/r7 does not arise; these are plain strong defs whose every callee is
// external-linkage or a macro):
//   hexa_arr_i64_new / _push / _len / _box   — native int64_t[] ctor/accessor
//   hexa_arr_f64_new / _push / _len / _box   — native double[]  ctor/accessor
//   hexa_arr_zeros_leaf / _zeros_leaf_int    — zero-filled HexaVal[] builders
//
// SEED-PORTABILITY (the r5 rule): a fn is seed-portable ONLY if EVERY callee is
// external-linkage or a macro. The 10 below are clean:
//   - libc:   malloc / calloc / realloc / free / fprintf / exit / stderr
//             (all in <stdio.h>/<stdlib.h>, pulled in via runtime.h).
//   - hexa:   hexa_int / hexa_float / hexa_throw / hexa_str / __hx_to_double
//             (PUBLIC non-static defs in runtime_core.c — external T symbols in
//              the linked binary, exactly like the r5/r7 seeds' callees).
//   - macros: HX_SET_ARR_PTR / HX_SET_ARR_ITEMS / HX_SET_ARR_LEN / HX_SET_ARR_CAP
//             / HX_IS_INT / HX_INT  (preprocessor — no link symbol).
//   - types:  HexaVal / HexaArr / HexaArrI64 / HexaArrF64 + TAG_* enum.
//   None of these callees is a frozen-STATIC body, so the cluster needs no
//   external-delegate route (unlike r6 hxlcl_fmod / r7 hxlcl_sin) — it is
//   directly seed-portable.
//
// DROPPED (not in this seed — already ported via a different lane, NOT a wall):
//   hexa_arena_mark / hexa_arena_rewind / hexa_arena_reset — in the shipping
//   build these are EMITTED UNDER `#ifdef HEXA_RT_ALLOC_NATIVE` as `extern`
//   (runtime_core.c links them from the native alloc syscall seed,
//   alloc_syscall_*.s, default-ON). Their inline C bodies exist ONLY in the
//   `#else  // !HEXA_RT_ALLOC_NATIVE` arm. So in the default build there is NO
//   inline body to extern out via this r7-style C-seed mechanism, and adding
//   them to a C seed would MULTI-DEF against the assembly alloc seed already
//   supplying them. They are already native (alloc lane), not seed-portable here.
//
// BIT-IDENTITY: each seed body below is the VERBATIM body emitted inline by
// runtime_core_emit.hexa (same C text, same callees resolved from the rest of the
// link), so the ON arm computes the same bits as the OFF inline body. The OFF arm
// is preserved verbatim (runtime_core_emit.hexa #else) so the default build is
// byte-identical.
//
// This file is #include'd by a 1-line TU at seed-regen time with the runtime
// headers already in scope (HexaVal / HexaArr / TAG_* / HX_INT / HX_IS_INT +
// extern protos for hexa_int / hexa_float / hexa_str / hexa_throw /
// __hx_to_double, all in runtime.h). Two struct types (HexaArrI64 / HexaArrF64)
// and the four HX_SET_ARR_* writer macros are defined in runtime_core.c but NOT
// in runtime.h, so re-declare them here (guarded — identical to the runtime_core.c
// definition, layout-match invariant with HexaArr).

// HexaArrI64 / HexaArrF64 — native unboxed typed-array descriptors (layout-match
// HexaArr: ptr, int64_t len, int64_t cap). Not in runtime.h; define here. The TU
// includes runtime.h (HexaVal/HexaArr) but never runtime_core.c, so these do not
// collide. Sentinel-guarded so a future runtime.h that adds them stays safe.
#ifndef HEXA_RTCORE_ARR_TYPED_DEFINED
#define HEXA_RTCORE_ARR_TYPED_DEFINED
typedef struct HexaArrI64 {
    int64_t* data;
    int64_t len;
    int64_t cap;
} HexaArrI64;
typedef struct HexaArrF64 {
    double* data;
    int64_t len;
    int64_t cap;
} HexaArrF64;
#endif

// HX_SET_ARR_* writer macros — defined in runtime_core.c, NOT runtime.h. Guarded
// (#ifndef) so they are a no-op if runtime.h ever supplies them.
#ifndef HX_SET_ARR_PTR
#define HX_SET_ARR_PTR(v, p)   ((v).arr_ptr = (p))
#endif
#ifndef HX_SET_ARR_ITEMS
#define HX_SET_ARR_ITEMS(v, p) ((v).arr_ptr->items = (p))
#endif
#ifndef HX_SET_ARR_LEN
#define HX_SET_ARR_LEN(v, n)   ((v).arr_ptr->len = (n))
#endif
#ifndef HX_SET_ARR_CAP
#define HX_SET_ARR_CAP(v, n)   ((v).arr_ptr->cap = (n))
#endif

// ── zero-c array-typed-leaf — native-i64 array storage helpers ──────────────
HexaVal hexa_arr_i64_new(int cap) {
    HexaArrI64* a = (HexaArrI64*)malloc(sizeof(HexaArrI64));
    if (!a) { fprintf(stderr, "OOM in arr_i64_new\n"); exit(1); }
    if (cap < 1) cap = 1;
    a->data = (int64_t*)malloc(sizeof(int64_t) * (size_t)cap);
    if (!a->data) { fprintf(stderr, "OOM in arr_i64_new data\n"); exit(1); }
    a->len = 0; a->cap = cap;
    HexaVal v = {.tag=TAG_ARRAY};
    HX_SET_ARR_PTR(v, (HexaArr*)a);
    return v;
}
HexaVal hexa_arr_i64_push(HexaVal v, int64_t x) {
    HexaArrI64* a = (HexaArrI64*)v.arr_ptr;
    if (a->len >= a->cap) {
        a->cap *= 2;
        a->data = (int64_t*)realloc(a->data, sizeof(int64_t) * (size_t)a->cap);
        if (!a->data) { fprintf(stderr, "OOM in arr_i64_push\n"); exit(1); }
    }
    a->data[a->len++] = x;
    return v;
}
int hexa_arr_i64_len(HexaVal v) { return ((HexaArrI64*)v.arr_ptr)->len; }
HexaVal hexa_arr_i64_box(HexaVal v, int64_t i) {
    HexaArrI64* a = (HexaArrI64*)v.arr_ptr;
    if (i < 0 || i >= a->len) { hexa_throw(hexa_str("index out of bounds")); }
    return hexa_int(a->data[i]);
}

// ── zero-c array-typed-leaf — native-f64 array storage helpers ──────────────
HexaVal hexa_arr_f64_new(int cap) {
    HexaArrF64* a = (HexaArrF64*)malloc(sizeof(HexaArrF64));
    if (!a) { fprintf(stderr, "OOM in arr_f64_new\n"); exit(1); }
    if (cap < 1) cap = 1;
    a->data = (double*)malloc(sizeof(double) * (size_t)cap);
    if (!a->data) { fprintf(stderr, "OOM in arr_f64_new data\n"); exit(1); }
    a->len = 0; a->cap = cap;
    HexaVal v = {.tag=TAG_ARRAY};
    HX_SET_ARR_PTR(v, (HexaArr*)a);
    return v;
}
HexaVal hexa_arr_f64_push(HexaVal v, double x) {
    HexaArrF64* a = (HexaArrF64*)v.arr_ptr;
    if (a->len >= a->cap) {
        a->cap *= 2;
        a->data = (double*)realloc(a->data, sizeof(double) * (size_t)a->cap);
        if (!a->data) { fprintf(stderr, "OOM in arr_f64_push\n"); exit(1); }
    }
    a->data[a->len++] = x;
    return v;
}
int hexa_arr_f64_len(HexaVal v) { return ((HexaArrF64*)v.arr_ptr)->len; }
HexaVal hexa_arr_f64_box(HexaVal v, int64_t i) {
    HexaArrF64* a = (HexaArrF64*)v.arr_ptr;
    if (i < 0 || i >= a->len) { hexa_throw(hexa_str("index out of bounds")); }
    return hexa_float(a->data[i]);
}

// ── zero-c array-typed-leaf — zero-filled HexaVal[] leaf builders ───────────
HexaVal hexa_arr_zeros_leaf(HexaVal nv) {
    HexaVal out = {.tag=TAG_ARRAY};
    HX_SET_ARR_PTR(out, (HexaArr*)calloc(1, sizeof(HexaArr)));
    int64_t n = HX_IS_INT(nv) ? HX_INT(nv) : (int64_t)__hx_to_double(nv);
    if (n <= 0) return out;
    HexaVal* items = (HexaVal*)malloc(sizeof(HexaVal) * (size_t)n);
    if (!items) { fprintf(stderr, "OOM in hexa_arr_zeros_leaf n=%lld\n", (long long)n); exit(1); }
    HexaVal zero = {.tag=TAG_FLOAT, .f=0.0};
    for (int64_t i = 0; i < n; i++) items[i] = zero;
    HX_SET_ARR_ITEMS(out, items);
    HX_SET_ARR_LEN(out, (int)n);
    HX_SET_ARR_CAP(out, (int)n);
    return out;
}
HexaVal hexa_arr_zeros_leaf_int(HexaVal nv) {
    HexaVal out = {.tag=TAG_ARRAY};
    HX_SET_ARR_PTR(out, (HexaArr*)calloc(1, sizeof(HexaArr)));
    int64_t n = HX_IS_INT(nv) ? HX_INT(nv) : (int64_t)__hx_to_double(nv);
    if (n <= 0) return out;
    HexaVal* items = (HexaVal*)malloc(sizeof(HexaVal) * (size_t)n);
    if (!items) { fprintf(stderr, "OOM in hexa_arr_zeros_leaf_int n=%lld\n", (long long)n); exit(1); }
    HexaVal zero = {.tag=TAG_INT, .i=0};
    for (int64_t i = 0; i < n; i++) items[i] = zero;
    HX_SET_ARR_ITEMS(out, items);
    HX_SET_ARR_LEN(out, (int)n);
    HX_SET_ARR_CAP(out, (int)n);
    return out;
}
