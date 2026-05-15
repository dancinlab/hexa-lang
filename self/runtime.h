/* self/runtime.h — public ABI of self/runtime.c (PHASE 1.2 first cut)
 *
 * Purpose: replace `#include "runtime.c"` in generated user.c so clang only
 * codegens user code per build; runtime.c is precompiled once to runtime.o.
 *
 * Status (d=2026-05-15): MINIMAL first cut — covers a hand-crafted ~9-fn
 *   smoke (proven 7.75× user-time speedup over `#include "runtime.c"` path,
 *   0.62 s → 0.08 s; see COMPILE-SPEED.log.tape @phase_1_2_smoke).
 *
 *   FINDING from first cut: PHASE 1.1 audit was INCOMPLETE — many `hexa_*`
 *   call sites in hexa_v2-emitted user.c are MACROS (e.g. `hexa_add` at
 *   runtime.c:4757) that expand to internal `static` helpers (`hexa_add_slow`
 *   at runtime.c:4731). To make those macros work via this header, the
 *   helpers must be de-staticized in runtime.c. Tracked as PHASE 1.2 follow-up.
 *
 *   This header currently DECLARES `hexa_add_slow` as extern; running it
 *   against an unpatched runtime.c yields a link error for `_hexa_add_slow`.
 *   Apply the de-static patch (drop `static` on runtime.c:4731) before use.
 *
 * SSOT for signatures: self/runtime.c. When that file's ABI changes, this
 * header must be re-synced (eventual goal: generate from runtime.c, not
 * hand-author).
 */

#ifndef HEXA_RUNTIME_H
#define HEXA_RUNTIME_H

#include <stdint.h>
#include <stddef.h>
#include <stdio.h>     /* hexa_v2-emitted main() calls fflush(stdout/stderr) */
#include <ctype.h>     /* user.c may call isalpha/isalnum/isdigit directly */
#include <stdlib.h>    /* exit, atoi, getenv from try/catch lowering */
#include <setjmp.h>    /* try/catch lowers to setjmp/longjmp + __hexa_try_* */
#include <math.h>      /* hexa_v2 emits direct log/sin/cos/exp calls for math intrinsics */

/* ── Tagged value layout (mirrors runtime.c lines 908–996) ── */

typedef enum {
    TAG_INT = 0, TAG_FLOAT, TAG_BOOL, TAG_STR, TAG_VOID,
    TAG_ARRAY, TAG_MAP, TAG_FN, TAG_CHAR, TAG_CLOSURE,
    TAG_VALSTRUCT
} HexaTag;

typedef struct HexaVal_       HexaVal;
typedef struct HexaValStruct  HexaValStruct;

typedef struct {
    char*    key;     /* owned strdup'd, NULL means empty slot */
    uint32_t hash;
    int      order_idx;
} HexaMapSlot;

typedef struct HexaMapTable {
    HexaMapSlot* slots;
    HexaVal*     vals;
    int          ht_cap;
    char**       order_keys;
    HexaVal*     order_vals;
    int          len;
    int          order_cap;
    int          from_arena;
} HexaMapTable;

typedef struct HexaArr { HexaVal* items; int len; int cap; }            HexaArr;
typedef struct HexaMap { HexaMapTable* tbl; int len; }                  HexaMap;
typedef struct HexaFn  { void* fn_ptr; int arity; }                     HexaFn;
typedef struct HexaClo { void* fn_ptr; int arity; HexaVal* env_box; }   HexaClo;

typedef struct HexaVal_ {
    HexaTag tag;
    union {
        int64_t        i;
        double         f;
        int            b;
        char*          s;
        HexaArr*       arr_ptr;
        HexaMap*       map_ptr;
        HexaFn*        fn_ptr_d;
        HexaClo*       clo_ptr;
        HexaValStruct* vs;
    };
} HexaVal;

/* ── Public API (tiny-program subset) ────────────────────────────────
 *   Signatures must match self/runtime.c exactly. Line refs below are
 *   the definition sites in runtime.c for cross-check.
 */

/* constructors / primitives */
HexaVal hexa_int(int64_t n);                          /* runtime.c:1231 */
HexaVal hexa_bool(int b);                             /* runtime.c:1233 */
HexaVal hexa_void(void);                              /* runtime.c:1234 */
HexaVal hexa_str(const char* s);                      /* runtime.c:1346 */
int     hexa_truthy(HexaVal v);                       /* runtime.c:4686 */
HexaVal hexa_eq(HexaVal a, HexaVal b);                /* runtime.c:4785 */
HexaVal hexa_struct_pack_map(const char* type_name, int n,
                             const char* const* keys,
                             const HexaVal* vals);    /* runtime.c:2155 */

/* Inline-cache slot — user.c declares `static HexaIC` arrays for fast field
 * lookup. Layout mirrors runtime.c:897. */
typedef struct HexaIC {
    void*    keys_ptr;
    int      len;
    int      idx;
    uint64_t hits;
    uint64_t misses;
} HexaIC;

/* arithmetic / conversion
 * NOTE: hexa_add is a MACRO in runtime.c (line 4757) that expands to a
 * hot-path int+int branch + fallback to hexa_add_slow. We must mirror the
 * macro here AND expose hexa_add_slow as extern (runtime.c patched: drop
 * `static` on line 4731).
 */
#define HX_TAG(v)        ((v).tag)
#define HX_INT(v)        ((v).i)
#define HX_INT_U(v)      ((uint64_t)(v).i)
#define HX_BOOL(v)       ((v).b)
#define HX_STR(v)        ((v).s)
#define HX_FLOAT(v)      ((v).f)
#define HX_IS_INT(v)     ((v).tag == TAG_INT)
#define HX_IS_FLOAT(v)   ((v).tag == TAG_FLOAT)
#define HX_IS_STR(v)     ((v).tag == TAG_STR)
#define HX_IS_MAP(v)     ((v).tag == TAG_MAP)
#define HX_IS_ARRAY(v)   ((v).tag == TAG_ARRAY)
#define HX_IS_FN(v)      ((v).tag == TAG_FN)
#define HX_IS_CLOSURE(v) ((v).tag == TAG_CLOSURE)
#define HX_MAP_TBL(v)    (HX_IS_MAP(v) ? (v).map_ptr->tbl : (HexaMapTable*)0)

/* HexaFn / HexaClo descriptor field accessors (read + write) */
#define HX_FN_PTR(v)         ((v).fn_ptr_d->fn_ptr)
#define HX_FN_ARITY(v)       ((v).fn_ptr_d->arity)
#define HX_CLO_PTR(v)        ((v).clo_ptr->fn_ptr)
#define HX_CLO_ARITY(v)      ((v).clo_ptr->arity)
#define HX_CLO_ENV(v)        ((v).clo_ptr->env_box)
#define HX_SET_FN_PTR_D(v, p)  ((v).fn_ptr_d = (p))
#define HX_SET_CLO_PTR_D(v, p) ((v).clo_ptr = (p))
#define HX_SET_CLO_PTR(v, p)   ((v).clo_ptr->fn_ptr = (p))
#define HX_SET_CLO_ARITY(v, n) ((v).clo_ptr->arity = (n))
#define HX_SET_CLO_ENV(v, p)   ((v).clo_ptr->env_box = (p))

HexaVal hexa_add_slow(HexaVal a, HexaVal b);          /* runtime.c:4731 (was static) */
double  __hx_to_double(HexaVal v);                    /* runtime.c:1242 (was `static inline`) */

#define hexa_add(A, B) \
    ({ HexaVal __ha = (A), __hb = (B); \
       (HX_IS_INT(__ha) && HX_IS_INT(__hb)) \
           ? hexa_int(HX_INT(__ha) + HX_INT(__hb)) \
           : hexa_add_slow(__ha, __hb); })

HexaVal hexa_to_string(HexaVal v);                    /* runtime.c: 777 (decl) */

/* I/O + program state */
void    hexa_println(HexaVal v);                      /* runtime.c:4478 */
void    hexa_set_args(int argc, char** argv);         /* runtime.c:5088 */
HexaVal hexa_args(void);                              /* runtime.c:5103 */

/* arrays */
int     hexa_len(HexaVal v);                          /* runtime.c:2042 */
HexaVal hexa_array_new(void);                         /* runtime.c:1693 */
HexaVal hexa_array_push(HexaVal arr, HexaVal item);   /* runtime.c:1809 */
HexaVal hexa_float(double f);                         /* runtime.c:1232 */

/* arithmetic (non-macro) */
HexaVal hexa_sub(HexaVal a, HexaVal b);               /* runtime.c:5483 */
HexaVal hexa_mul(HexaVal a, HexaVal b);               /* runtime.c:5488 */
HexaVal hexa_mod(HexaVal a, HexaVal b);               /* runtime.c: 770 (decl) */
HexaVal hexa_div(HexaVal a, HexaVal b);               /* runtime.c:5501 */
HexaVal hexa_concat_many(int n, HexaVal* parts);      /* runtime.c:4774 */

/* comparisons */
HexaVal hexa_cmp_lt(HexaVal a, HexaVal b);            /* runtime.c:5537 */
HexaVal hexa_cmp_gt(HexaVal a, HexaVal b);            /* runtime.c:5544 */
HexaVal hexa_cmp_ge(HexaVal a, HexaVal b);            /* runtime.c:5558 */
HexaVal hexa_cmp_le(HexaVal a, HexaVal b);            /* runtime.c: 775 (decl) */

/* string ops */
HexaVal hexa_str_chars(HexaVal s);                    /* runtime.c:3742 */
HexaVal hexa_str_join(HexaVal arr, HexaVal sep);      /* runtime.c:5404 */
HexaVal hexa_str_split(HexaVal s, HexaVal delim);     /* runtime.c:5320 */
HexaVal hexa_str_substring(HexaVal s, HexaVal start, HexaVal end); /* runtime.c:3780 */
int     hexa_str_contains(HexaVal s, HexaVal sub);    /* runtime.c:3753 */
int64_t hexa_str_index_of(HexaVal s, HexaVal sub);    /* runtime.c:3794 */
HexaVal hexa_format_n(HexaVal fmt, HexaVal args);     /* runtime.c:5231 */
HexaVal hexa_char_code(HexaVal s, HexaVal idx);       /* runtime.c:6519 */
HexaVal rt_str_to_upper(HexaVal s);                   /* runtime.c:5390 */
HexaVal rt_str_trim(HexaVal s);                       /* runtime.c:5347 */
int     rt_str_starts_with(HexaVal s, HexaVal prefix); /* runtime.c:3766 */

/* file I/O */
HexaVal rt_read_file(HexaVal path);                   /* runtime.c:4844 */
HexaVal rt_write_file(HexaVal path, HexaVal content); /* runtime.c:4857 */
HexaVal rt_file_exists(HexaVal path);                 /* runtime.c:4877 */

/* process / shell */
HexaVal hexa_exec(HexaVal cmd);                       /* runtime.c:4153 */

/* string parsing / mutation */
HexaVal hexa_str_parse_int(HexaVal s);                /* runtime.c:6785 */
HexaVal hexa_str_replace(HexaVal s, HexaVal old, HexaVal n); /* runtime.c:5357 */

/* arena */
void    hexa_arena_reset(void);                       /* runtime.c:3076 */

/* array lifecycle */
HexaVal hexa_array_free(HexaVal arr);                 /* runtime.c:7182 */

/* container indexing */
HexaVal hexa_index_get(HexaVal container, HexaVal key); /* runtime.c:2643 */
HexaVal hexa_array_pop(HexaVal arr);                    /* runtime.c:3878 */

/* map predicates */
int     hexa_map_contains_key(HexaVal m, const char* key); /* runtime.c:2452 */

/* conversion */
const char* hexa_to_cstring(HexaVal v);                 /* runtime.c:1287 */
HexaVal hexa_index_set(HexaVal container, HexaVal key, HexaVal val); /* runtime.c:2685 */
HexaVal hexa_iter_get(HexaVal v, int64_t idx);          /* runtime.c:2673 */
HexaVal hexa_contains_poly(HexaVal obj, HexaVal arg);   /* runtime.c:6972 */
HexaVal hexa_type_of(HexaVal v);                        /* runtime.c:4704 */

/* diagnostics */
void    hexa_print_val(HexaVal v);                    /* runtime.c:4436 */
void    hexa_eprint_val(HexaVal v);                   /* runtime.c:4343 */

/* try/catch lowering (codegen emits __hexa_try_push/pop around fn bodies
 * with non-void try-blocks; __hexa_try_top is read as a saved-depth marker)
 * DE-STATIC NEEDED in runtime.c (line 4386): drop `static` on __hexa_try_top. */
extern int __hexa_try_top;                            /* runtime.c:4386 (was static) */
void    __hexa_try_push(jmp_buf* jb);                 /* runtime.c:4389 */
void    __hexa_try_cleanup(int* saved);               /* runtime.c:4396 */
HexaVal __hexa_last_error(void);                      /* runtime.c:4391 */

/* maps */
HexaVal hexa_map_new(void);                             /* runtime.c:2143 */
HexaVal hexa_map_set(HexaVal m, const char* key, HexaVal val); /* runtime.c:2254 */
HexaVal hexa_map_get(HexaVal m, const char* key);       /* runtime.c:2319 */

/* Hot-path inline-cache map lookup — MACRO that mirrors runtime.c:2409.
 * Required for hexa_v2-emitted user.c (1294 calls in hexa_cc.c alone).
 * Depends on these statics being de-staticized in runtime.c (PHASE 1.2.A.2
 * follow-up patches — without them, link fails with undefined refs):
 *   - g_hexa_ic_hits             runtime.c:2350
 *   - g_hexa_ic_stats_enabled    runtime.c:2352
 *   - hexa_map_get_ic_slow       runtime.c:2383
 */
extern uint64_t g_hexa_ic_hits;
extern int      g_hexa_ic_stats_enabled;
HexaVal         hexa_map_get_ic_slow(HexaVal m, const char* key, HexaIC* ic);

#define hexa_map_get_ic(M, KEY, IC) \
    ({ HexaVal __ic_m = (M); HexaIC* __ic = (IC); \
       (HX_MAP_TBL(__ic_m) \
        && (void*)HX_MAP_TBL(__ic_m)->order_keys == __ic->keys_ptr \
        && HX_MAP_TBL(__ic_m)->len == __ic->len \
        && __ic->idx < __ic->len) \
           ? (g_hexa_ic_stats_enabled > 0 \
              ? (__ic->hits++, g_hexa_ic_hits++, HX_MAP_TBL(__ic_m)->order_vals[__ic->idx]) \
              : HX_MAP_TBL(__ic_m)->order_vals[__ic->idx]) \
           : hexa_map_get_ic_slow(__ic_m, (KEY), __ic); })

/* misc */
HexaVal hexa_exit(HexaVal code);                        /* runtime.c:7518 */
void    hexa_throw(HexaVal err);                        /* runtime.c:4398 */
HexaVal hexa_env_var(HexaVal name);                     /* runtime.c:9608 */
HexaVal hexa_clock(void);                               /* runtime.c:6514 */
int64_t hexa_as_num(HexaVal v);                         /* runtime.c:1262 */

/* math */
HexaVal hexa_sqrt(HexaVal v);                           /* runtime.c:5152 */
HexaVal hexa_pow(HexaVal base, HexaVal exp);            /* runtime.c:5156 */
HexaVal hexa_rms_norm(HexaVal x, HexaVal gamma, HexaVal eps); /* runtime.c:10846 */

/* FFI (raw pointer / extern dispatch + dlopen/dlsym; latter two are
 * de-staticized to expose to runtime.h consumers — runtime.c:5658, 5782) */
HexaVal hexa_extern_call(void* fn_ptr, HexaVal* hargs, int nargs, int ret_kind); /* runtime.c:5846 */
HexaVal hexa_ptr_alloc(HexaVal size);                   /* runtime.c:6241 */
HexaVal hexa_ptr_free(HexaVal ptr, HexaVal size);       /* runtime.c:6248 */
void*   hexa_ffi_dlopen(const char* lib_name);          /* runtime.c:5658 (was static) */
void*   hexa_ffi_dlsym(void* handle, const char* symbol); /* runtime.c:5782 (was static) */

/* Tensor-kernel raw-pointer ops. DEFINED in self/native/tensor_kernels.c
 * (NOT runtime.c) — programs using these must link the tensor_kernels.o
 * artifact in addition to runtime.o. clm_train_bench / hxblas_linux /
 * m4_inference_e2e are the main consumers. */
HexaVal hexa_ptr_read_f32(HexaVal ptr, HexaVal offset);                  /* tensor_kernels.c:64 */
HexaVal hexa_ptr_read_i32(HexaVal ptr, HexaVal offset);                  /* tensor_kernels.c:73 */
HexaVal hexa_ptr_write_f32(HexaVal ptr, HexaVal offset, HexaVal val);    /* tensor_kernels.c:37 */
HexaVal hexa_ptr_write_i32(HexaVal ptr, HexaVal offset, HexaVal val);    /* tensor_kernels.c:46 */

/* string queries */
int64_t hexa_str_last_index_of(HexaVal s, HexaVal sub); /* runtime.c:3831 */

/* arena (codegen wraps fn bodies) */
void    __hexa_fn_arena_enter(void);                  /* runtime.c:3652 */
HexaVal __hexa_fn_arena_return(HexaVal ret);          /* runtime.c:3657 */

/* ── Closures + fn-pointer call dispatch (header-defined static inline)
 *
 * These mirror runtime.c:1110–1227. Stripped of internal _hx_stats_* counter
 * bumps that referenced static-in-runtime.c symbols; behavior is identical
 * from the caller's perspective (closures + fn-pointer values still create /
 * dispatch correctly), only the per-TU stat accounting differs. The runtime.c
 * TU still has the original stats-instrumented bodies for its own callers.
 *
 * Filed as fix for incoming/patches/runtime-h-incomplete-after-phase-1-3-b.md
 * (wilson stdlib/sort + event-bus folds hit `_undeclared` link errors against
 * the post-PHASE-1.3.B runtime.h surface).
 */

static inline HexaVal hexa_closure_new(void* fn_ptr, int arity, HexaVal env_arr) {
    HexaVal v = {.tag=TAG_CLOSURE};
    HX_SET_CLO_PTR_D(v, (HexaClo*)calloc(1, sizeof(HexaClo)));
    HX_SET_CLO_PTR(v, fn_ptr);
    HX_SET_CLO_ARITY(v, arity);
    HX_SET_CLO_ENV(v, (HexaVal*)malloc(sizeof(HexaVal)));
    *HX_CLO_ENV(v) = env_arr;
    return v;
}

static inline HexaVal hexa_fn_new(void* fn_ptr, int arity) {
    HexaVal v = {.tag=TAG_FN};
    HX_SET_FN_PTR_D(v, (HexaFn*)calloc(1, sizeof(HexaFn)));
    HX_FN_PTR(v) = fn_ptr;
    HX_FN_ARITY(v) = arity;
    return v;
}

static inline HexaVal hexa_closure_env(HexaVal c) {
    if (!HX_IS_CLOSURE(c) || !HX_CLO_ENV(c)) return hexa_array_new();
    return *HX_CLO_ENV(c);
}

static inline HexaVal hexa_call0(HexaVal f) {
    if (HX_IS_CLOSURE(f)) {
        HexaVal (*fp)(HexaVal) = (HexaVal(*)(HexaVal))HX_CLO_PTR(f);
        return fp(hexa_closure_env(f));
    }
    if (HX_IS_FN(f)) {
        HexaVal (*fp)(void) = (HexaVal(*)(void))HX_FN_PTR(f);
        return fp();
    }
    return hexa_void();
}

static inline HexaVal hexa_call1_hv(HexaVal f, HexaVal a1) {
    if (HX_IS_CLOSURE(f)) {
        HexaVal (*fp)(HexaVal, HexaVal) = (HexaVal(*)(HexaVal, HexaVal))HX_CLO_PTR(f);
        return fp(hexa_closure_env(f), a1);
    }
    if (HX_IS_FN(f)) {
        HexaVal (*fp)(HexaVal) = (HexaVal(*)(HexaVal))HX_FN_PTR(f);
        return fp(a1);
    }
    return hexa_void();
}
static inline HexaVal __hexa_call1_fp1(HexaVal (*fp)(HexaVal), HexaVal a1) {
    return fp(a1);
}
#define hexa_call1(f, a1) _Generic((f), \
    HexaVal: hexa_call1_hv, \
    HexaVal (*)(HexaVal): __hexa_call1_fp1, \
    default: hexa_call1_hv)((f), (a1))

static inline HexaVal hexa_call2_hv(HexaVal f, HexaVal a1, HexaVal a2) {
    if (HX_IS_CLOSURE(f)) {
        HexaVal (*fp)(HexaVal, HexaVal, HexaVal) = (HexaVal(*)(HexaVal, HexaVal, HexaVal))HX_CLO_PTR(f);
        return fp(hexa_closure_env(f), a1, a2);
    }
    if (HX_IS_FN(f)) {
        HexaVal (*fp)(HexaVal, HexaVal) = (HexaVal(*)(HexaVal, HexaVal))HX_FN_PTR(f);
        return fp(a1, a2);
    }
    return hexa_void();
}
static inline HexaVal __hexa_call2_fp2(HexaVal (*fp)(HexaVal, HexaVal), HexaVal a1, HexaVal a2) {
    return fp(a1, a2);
}
#define hexa_call2(f, a1, a2) _Generic((f), \
    HexaVal: hexa_call2_hv, \
    HexaVal (*)(HexaVal, HexaVal): __hexa_call2_fp2, \
    default: hexa_call2_hv)((f), (a1), (a2))

static inline HexaVal hexa_call3(HexaVal f, HexaVal a1, HexaVal a2, HexaVal a3) {
    if (HX_IS_CLOSURE(f)) {
        HexaVal (*fp)(HexaVal, HexaVal, HexaVal, HexaVal) = (HexaVal(*)(HexaVal, HexaVal, HexaVal, HexaVal))HX_CLO_PTR(f);
        return fp(hexa_closure_env(f), a1, a2, a3);
    }
    if (HX_IS_FN(f)) {
        HexaVal (*fp)(HexaVal, HexaVal, HexaVal) = (HexaVal(*)(HexaVal, HexaVal, HexaVal))HX_FN_PTR(f);
        return fp(a1, a2, a3);
    }
    return hexa_void();
}

static inline HexaVal hexa_call4(HexaVal f, HexaVal a1, HexaVal a2, HexaVal a3, HexaVal a4) {
    if (HX_IS_CLOSURE(f)) {
        HexaVal (*fp)(HexaVal, HexaVal, HexaVal, HexaVal, HexaVal) = (HexaVal(*)(HexaVal, HexaVal, HexaVal, HexaVal, HexaVal))HX_CLO_PTR(f);
        return fp(hexa_closure_env(f), a1, a2, a3, a4);
    }
    if (HX_IS_FN(f)) {
        HexaVal (*fp)(HexaVal, HexaVal, HexaVal, HexaVal) = (HexaVal(*)(HexaVal, HexaVal, HexaVal, HexaVal))HX_FN_PTR(f);
        return fp(a1, a2, a3, a4);
    }
    return hexa_void();
}

#endif /* HEXA_RUNTIME_H */
