/* self/runtime_hexaval_abi.h — SHARED HexaVal type-ABI contract (SSOT).
 *
 * ZERO-C leg-B disentangle (ING #35, r3): the HexaVal tagged-union struct +
 * the HX_* accessor/mutator macros are the binary type-ABI contract shared by
 * the TWO runtime supply paths:
 *   (a) the runtime.c amalgamation — self/runtime_core_emit.hexa emits this
 *       block inline into runtime_core.c (#include'd by runtime.c), and
 *   (b) the native .o supply — self/runtime.h (pulled into the 1-line wrapper
 *       TUs by tool/regen_rtcore_*_native_o.sh) carries an equivalent copy.
 *
 * Extracting the contract here makes ONE canonical definition the SSOT so the
 * two sides can no longer drift. This is a FRAGMENT (NOT a standalone header):
 * it assumes HexaTag / HexaArr / HexaMap / HexaFn / HexaClo / HexaValStruct +
 * HexaMapTable are already in scope from the including TU (exactly as the
 * inline runtime_core.c block did). The text below is byte-identical to the
 * block runtime_core_emit.hexa emits inline under the default build, so a
 * clang -E -P (no -D) of the emitted runtime_core.c reproduces the baseline
 * preprocessed output verbatim (proven byte-neutral — the merge gate).
 *
 * The #include-DROP that swaps the inline block for this header lives behind
 * the experimental HEXA_ZEROC_DROP_RTCORE flag (default OFF) in the emitter;
 * the EXTRACTION (this file existing as the SSOT) is always-on.
 */
#ifndef HEXA_RUNTIME_HEXAVAL_ABI_H
#define HEXA_RUNTIME_HEXAVAL_ABI_H

typedef struct HexaVal_ {
    HexaTag tag;
    union {
        int64_t i;
        double f;
        int b;
        char* s;           // owned string (malloc'd)
        HexaArr* arr_ptr;  // S1-D3a: heap descriptor (was inline struct)
        HexaMap* map_ptr;  // S1-D3a: heap descriptor (was inline struct)
        HexaFn*  fn_ptr_d; // S1-D3a: heap descriptor (was inline struct)
        HexaClo* clo_ptr;  // S1-D3a: heap descriptor (was inline struct)
        // rt 32-G: heap-allocated flat struct pointer (TAG_VALSTRUCT).
        HexaValStruct* vs;
    };
} HexaVal;

// ═══════════════════════════════════════════════════════════
//  STRUCTURAL-1 Phase A: NaN-boxing accessor macros
//  Current: identity-map to tagged union fields (zero-cost).
//  Phase B: macro bodies swap to NaN-boxed 8B representation.
//  All hot-path code MUST use these instead of raw .tag/.i/.f etc.
// ═══════════════════════════════════════════════════════════

#define HX_TAG(v)       ((v).tag)
#define HX_INT(v)       ((v).i)
#define HX_INT_U(v)     ((uint64_t)(v).i)   // unsigned read — safe for NaN-boxed pointers
#define HX_FLOAT(v)     ((v).f)
#define HX_BOOL(v)      ((v).b)
#define HX_STR(v)       ((v).s)
// S1-D3a: compound-type READ macros — dereference heap descriptors.
// IMPORTANT: caller MUST ensure the tag matches before calling these;
// they dereference the descriptor pointer unconditionally for performance.
// The one exception is HX_MAP_TBL which is guarded because the IC
// fast-path (hexa_map_get_ic) probes it before a tag check, and
// hexa_map_get probes it on TAG_VALSTRUCT-routed values.
#define HX_ARR_LEN(v)   ((v).arr_ptr->len)
#define HX_ARR_ITEMS(v) ((v).arr_ptr->items)
#define HX_ARR_CAP(v)   ((v).arr_ptr->cap)
#define HX_MAP_LEN(v)   ((v).map_ptr->len)
#define HX_MAP_TBL(v)   (HX_IS_MAP(v) ? (v).map_ptr->tbl : (HexaMapTable*)0)
#define HX_FN_PTR(v)    ((v).fn_ptr_d->fn_ptr)
#define HX_FN_ARITY(v)  ((v).fn_ptr_d->arity)
#define HX_CLO_PTR(v)   ((v).clo_ptr->fn_ptr)
#define HX_CLO_ARITY(v) ((v).clo_ptr->arity)
#define HX_CLO_ENV(v)   ((v).clo_ptr->env_box)
#define HX_VS(v)        ((v).vs)
// ── STRUCTURAL-1 Phase A: raw descriptor-POINTER read accessors ──
// Sibling of the HX_SET_*_PTR writers: return the union pointer slot itself
// (no deref) for callers that cast it (e.g. (HexaArrI64*)HX_ARR_PTR(v)) or
// null-check/compare it. The flip decodes the NaN-boxed pointer here in one spot.
#define HX_ARR_PTR(v)   ((v).arr_ptr)
#define HX_MAP_PTR(v)   ((v).map_ptr)
#define HX_FN_PTR_D(v)  ((v).fn_ptr_d)
#define HX_CLO_PTR_D(v) ((v).clo_ptr)

// ── S1-D3a: compound-type SET macros (write accessors) — heap descriptor ──
#define HX_SET_ARR_ITEMS(v, p) ((v).arr_ptr->items = (p))
#define HX_SET_ARR_LEN(v, n)   ((v).arr_ptr->len = (n))
#define HX_SET_ARR_CAP(v, n)   ((v).arr_ptr->cap = (n))
#define HX_SET_MAP_TBL(v, t)   ((v).map_ptr->tbl = (t))
#define HX_SET_MAP_LEN(v, n)   ((v).map_ptr->len = (n))
#define HX_SET_CLO_PTR(v, p)   ((v).clo_ptr->fn_ptr = (p))
#define HX_SET_CLO_ARITY(v, n) ((v).clo_ptr->arity = (n))
#define HX_SET_CLO_ENV(v, p)   ((v).clo_ptr->env_box = (p))

// ── STRUCTURAL-1 Phase A: scalar + descriptor-pointer writer macros ──
// Prep for NaN-boxing typedef flip (HexaVal → uint64_t). Once callers route
// all writes through these macros, the macro bodies swap to encode-into-u64
// in one place. Struct-initializer literals ({.tag=T, .i=n}) are OUT OF SCOPE
// here — they need a different rewrite (constructor fns or the flip itself).
#define HX_SET_TAG(v, t)       ((v).tag = (t))
#define HX_SET_INT(v, n)       ((v).i = (n))
#define HX_SET_FLOAT(v, f)     ((v).f = (f))
#define HX_SET_BOOL(v, b)      ((v).b = (b))
#define HX_SET_STR(v, p)       ((v).s = (p))
#define HX_SET_ARR_PTR(v, p)   ((v).arr_ptr = (p))
#define HX_SET_MAP_PTR(v, p)   ((v).map_ptr = (p))
#define HX_SET_FN_PTR_D(v, p)  ((v).fn_ptr_d = (p))
#define HX_SET_CLO_PTR_D(v, p) ((v).clo_ptr = (p))
#define HX_SET_VS(v, p)        ((v).vs = (p))

// HexaValStruct (inner) field access via v — routes through HX_VS so the
// typedef flip can adjust the .vs bits in one spot. The inner HexaValStruct
// remains a plain C struct — HX_VSF is pointer deref + member access.
#define HX_VSF(v, field)       (HX_VS(v)->field)

#define HX_IS_INT(v)    ((v).tag == TAG_INT)
#define HX_IS_FLOAT(v)  ((v).tag == TAG_FLOAT)
#define HX_IS_BOOL(v)   ((v).tag == TAG_BOOL)
#define HX_IS_STR(v)    ((v).tag == TAG_STR)
#define HX_IS_VOID(v)   ((v).tag == TAG_VOID)
#define HX_IS_ARRAY(v)  ((v).tag == TAG_ARRAY)
#define HX_IS_MAP(v)    ((v).tag == TAG_MAP)
#define HX_IS_FN(v)     ((v).tag == TAG_FN)
#define HX_IS_CLOSURE(v)((v).tag == TAG_CLOSURE)
#define HX_IS_VALSTRUCT(v) ((v).tag == TAG_VALSTRUCT)

// ── STRUCTURAL-1 Phase A: HexaVal CONSTRUCTOR macros (struct-literal residue) ──
// Drain raw compound-literal constructors ((HexaVal){.tag=T, .field=v}) into one
// site so the NaN-boxing typedef flip (HexaVal to uint64_t) becomes a single-spot
// edit. Bodies stay IDENTITY-mapped to the current 16B tagged union, so the DEFAULT
// build is byte-identical (pure preprocessor refactor); Phase B swaps the bodies to
// encode-into-u64 in this one place. HX_MAKE_INT is also the def the @bitfield
// setter codegen (self/codegen.hexa) already references.
#define HX_MAKE_INT(v)   ((HexaVal){.tag=TAG_INT, .i=(v)})
#define HX_MAKE_FLOAT(v) ((HexaVal){.tag=TAG_FLOAT, .f=(v)})
#define HX_MAKE_BOOL(v)  ((HexaVal){.tag=TAG_BOOL, .b=(v)})
#define HX_MAKE_VOID()   ((HexaVal){.tag=TAG_VOID})
#define HX_MAKE_STR(v)   ((HexaVal){.tag=TAG_STR, .s=(v)})
#define HX_MAKE_ENUM(v)  ((HexaVal){.tag=TAG_ENUM, .s=(v)})
// Tag-only constructor for declare-then-populate values (descriptor/scalar
// field set afterward via HX_SET_*). Generalizes HX_MAKE_VOID to any tag.
#define HX_MAKE_TAG(t)   ((HexaVal){.tag=(t)})

#endif /* HEXA_RUNTIME_HEXAVAL_ABI_H */
