/* self/runtime_core_decls.h — ZERO-C leg-B (ING #35, r9) include-drop decl surface.
 *
 * WHAT THIS IS
 * ────────────
 * When the whole-file `#include "runtime_core.c"` is DROPPED from the frozen
 * runtime.c (HEXA_ZEROC_DROP_RTCORE_INCLUDE, default OFF — top-level
 * top-level `self` C-file count 3→1), the trailing runtime.c HI-tier body loses every
 * declaration runtime_core.c used to supply by textual concatenation: the
 * HexaVal type-ABI (struct + HX_* macros), the base aggregate types
 * (HexaArr/HexaMap/HexaFn/HexaClo/HexaValStruct/HexaMapTable + the HexaArena
 * pair), and the forward-decl prototypes of the CORE-tier primitives. This
 * header re-supplies that surface so the trailing body COMPILES against the
 * SEPARATE runtime_core.c seed .o.
 *
 * It is injected — ONLY under the drop flag — by tool/zeroc_drop_rtcore_include.sh
 * immediately before the (guarded-out) `#include "runtime_core.c"` line. The
 * DEFAULT build never includes it (the concatenation supplies everything), so
 * default byte-identity is untouched — this file exists purely for the drop-ON
 * compile.
 *
 * SSOT: the declarations below mirror self/runtime_core_emit.hexa. The base
 * type-ABI + HX_* macros come from self/runtime_hexaval_abi.h (the always-on
 * extracted SSOT) and the broad prototype surface from self/runtime.h (the
 * native-.o supply path's external view). This file adds ONLY the pieces those
 * two do not already carry: the HexaArena struct pair, HX_STRLEN, the 2
 * promoted file-scope externs, and the handful of prototypes runtime.h omits.
 */
#ifndef HEXA_RUNTIME_CORE_DECLS_H
#define HEXA_RUNTIME_CORE_DECLS_H

/* (1) the broad external prototype + base-type surface (HexaTag/HexaArr/…,
 *     the FULL HexaVal struct + the HX_* accessor/mutator macros, and most
 *     hexa_* prototypes). runtime.h is the native-.o path's SSOT for
 *     runtime_core.c's external ABI — it already carries HexaVal + 25 HX_*
 *     macros, so we do NOT also pull runtime_hexaval_abi.h here (that would
 *     redefine HexaVal_ with an incompatible duplicate).
 *
 *     NEUTER the 4 forge-dispatch PROTOTYPES runtime.h carries: the FROZEN
 *     runtime.c body SELF-DEFINES these as weak host-fallback stubs with K&R
 *     empty-param lists (`HexaVal hexa_forge_dispatch_adamw_fused() {…}`,
 *     runtime.c:16193), which CONFLICT with runtime.h's fully-typed
 *     (HexaVal w_ids_v, …) prototypes. The body needs NO prototype (it defines
 *     them), and the frozen def is immutable — so we rename runtime.h's protos
 *     to throwaway symbols across the include, leaving the real names for the
 *     body to define conflict-free. (Surgical: only these 4 names; everything
 *     else in runtime.h is taken verbatim.) */
#define hexa_forge_dispatch_adamw_fused  __hx_rtdecls_skip_fda
#define forge_dispatch_adamw_fused       __hx_rtdecls_skip_fda2
#define hexa_forge_dispatch_clm_megafwd  __hx_rtdecls_skip_fcm
#define forge_dispatch_clm_megafwd       __hx_rtdecls_skip_fcm2
#include "runtime.h"
#undef hexa_forge_dispatch_adamw_fused
#undef forge_dispatch_adamw_fused
#undef hexa_forge_dispatch_clm_megafwd
#undef forge_dispatch_clm_megafwd

/* (1b) the HX_* accessor/mutator macros runtime.h does NOT carry (it has 25 of
 *      ~46; abi.h has the rest but re-typedefs HexaVal_ → redefinition clash, so
 *      we copy ONLY the missing MACROS here — idempotent, no type redefinition).
 *      HX_VSF in particular gates every `.vs->field` deref in the frozen body. */
#ifndef HX_VSF
#define HX_ARR_CAP(v)   ((v).arr_ptr->cap)
#define HX_ARR_ITEMS(v) ((v).arr_ptr->items)
#define HX_ARR_LEN(v)   ((v).arr_ptr->len)
#define HX_IS_BOOL(v)   ((v).tag == TAG_BOOL)
#define HX_IS_VALSTRUCT(v) ((v).tag == TAG_VALSTRUCT)
#define HX_IS_VOID(v)   ((v).tag == TAG_VOID)
#define HX_MAP_LEN(v)   ((v).map_ptr->len)
#define HX_SET_ARR_CAP(v, n)   ((v).arr_ptr->cap = (n))
#define HX_SET_ARR_ITEMS(v, p) ((v).arr_ptr->items = (p))
#define HX_SET_ARR_LEN(v, n)   ((v).arr_ptr->len = (n))
#define HX_SET_ARR_PTR(v, p)   ((v).arr_ptr = (p))
#define HX_SET_BOOL(v, b)      ((v).b = (b))
#define HX_SET_FLOAT(v, f)     ((v).f = (f))
#define HX_SET_INT(v, n)       ((v).i = (n))
#define HX_SET_MAP_LEN(v, n)   ((v).map_ptr->len = (n))
#define HX_SET_MAP_PTR(v, p)   ((v).map_ptr = (p))
#define HX_SET_MAP_TBL(v, t)   ((v).map_ptr->tbl = (t))
#define HX_SET_STR(v, p)       ((v).s = (p))
#define HX_SET_TAG(v, t)       ((v).tag = (t))
#define HX_SET_VS(v, p)        ((v).vs = (p))
#define HX_VSF(v, field)       (HX_VS(v)->field)
#endif

/* (2) the FULL HexaValStruct flat struct — runtime.h only forward-declares it
 *     (`typedef struct HexaValStruct HexaValStruct;`), but the frozen HI-tier
 *     body dereferences `.vs->field` (HX_VSF), needing the complete type. This
 *     mirrors runtime_core.c:1309 verbatim. */
#ifndef HEXA_RTCORE_DECLS_VALSTRUCT
#define HEXA_RTCORE_DECLS_VALSTRUCT
struct HexaValStruct {
    int64_t tag_i;
    int64_t int_val;
    double  float_val;
    int     bool_val;
    int     from_arena;
    HexaVal str_val;
    HexaVal char_val;
    HexaVal array_val;
    HexaVal fn_name;
    HexaVal fn_params;
    HexaVal fn_body;
    HexaVal struct_name;
    HexaVal struct_fields;
};
#endif

/* (3) the HexaArena bump-allocator struct pair — the frozen HI-tier body's
 *     arena-stats walk (`for (HexaArenaBlock* b = __hexa_arena.head; …)`)
 *     dereferences these. runtime.h does not carry them (they are CORE-only). */
#ifndef HEXA_RTCORE_DECLS_ARENA_TYPES
#define HEXA_RTCORE_DECLS_ARENA_TYPES
typedef struct HexaArenaBlock {
    struct HexaArenaBlock* next;   /* NULL for last block */
    size_t cap;                    /* usable bytes in data[] */
    size_t used;                   /* bytes allocated from this block */
    char   data[];                 /* flexible; cap bytes follow the header */
} HexaArenaBlock;

typedef struct {
    HexaArenaBlock* head;   /* first block (never freed until arena_destroy) */
    HexaArenaBlock* cur;    /* current bump block */
} HexaArena;
#endif

/* (3b) the interpreter weak-linked store globals + the interp array tag macro.
 *      runtime_core.c emits these (4622, 4634); the frozen body's incremental-
 *      heapify walk reads array_store / map_store / struct_store and compares
 *      against HEXA_INTERP_TAG_ARRAY. The weak attrs mirror runtime_core.c so
 *      the (absent) interpreter symbols resolve to common/zero. */
#ifndef HEXA_RTCORE_DECLS_INTERP_STORES
#define HEXA_RTCORE_DECLS_INTERP_STORES
extern HexaVal array_store  __attribute__((weak));
extern HexaVal map_store    __attribute__((weak));
extern HexaVal struct_store __attribute__((weak));
#ifndef HEXA_INTERP_TAG_ARRAY
#define HEXA_INTERP_TAG_ARRAY  5
#endif
#endif

/* (3c) the val-arena live-mark counter (rt 32-L), already external in
 *      runtime_core.c (`extern int __hexa_val_mark_top;`). */
extern int __hexa_val_mark_top;

/* (4) HX_STRLEN — defined inline in runtime_core.c (not in abi.h). */
#ifndef HX_STRLEN
#define HX_STRLEN(v)    hexa_strlen_v_inline(HX_STR(v))
#define HX_STRLEN_S(s)  hexa_strlen_v_inline(s)
#endif

/* (5) the 2 promoted file-scope globals (static→external under the drop;
 *     see HX_RTCORE_LOCAL note in runtime_core_emit.hexa). The frozen body
 *     reads __hexa_arena and toggles __hexa_val_region_returns_enabled. */
extern HexaArena __hexa_arena;
extern int __hexa_val_region_returns_enabled;

/* (6) the CORE-tier prototypes runtime.h omits — the cross-tier helpers the
 *     frozen HI-tier body calls. These mirror the runtime_core.c definitions
 *     (now external under the drop via HX_RTCORE_LOCAL / _INLINE). */
size_t      hexa_strlen_v_inline(const char* s);
size_t      _hx_self_rss_bytes(void);
int         _hx_stats_on(void);
int         hexa_array_contains(HexaVal arr, HexaVal item);
const char* hexa_str_as_ptr(HexaVal v);
HexaVal     hexa_str_count_substr(HexaVal s, HexaVal sub);
HexaVal     hexa_str_own(char* s);
HexaVal     hexa_str_own_with_len(char* s, size_t len);
char*       hexa_strbuf_alloc(size_t len);
void        hexa_val_arena_heapify_return(void);
int         hexa_val_arena_on(void);
void        hexa_val_arena_scope_pop(void);
void        hexa_val_arena_scope_push(void);
HexaVal     hexa_valstruct_int(HexaVal v);

/* (7) cross-tier file-scope statics promoted to external under the drop:
 *     _hx_stats_array_new (the array-ctor stats counter incremented by the
 *     body) and `join` (the str-join builtin fn-value the body seats at
 *     module init, runtime.c:13437). */
extern int64_t _hx_stats_array_new;
extern HexaVal join;

#endif /* HEXA_RUNTIME_CORE_DECLS_H */
