// self/native/rtcore_runtime-misc.c — zero-c leg-B r8 RUNTIME-MISC SEED (link de-risk).
//
// Supplies 11 seed-portable runtime_core.c symbols from the "runtime-misc"
// cluster (try-stack tail + index/iter dispatch + fnv1a hash + valstruct/free
// + mkdir + value-ptr eq) that runtime_core.c externs away under
// HEXA_RT_CORE_RUNTIME_MISC_NATIVE (the narrow runtime-misc guard, NOT the
// broad whole-runtime HEXA_RT_SELFEMIT). Compiled to a SEPARATE .o
// (build/rtcore_runtime-misc_native.o) and linked when
// HEXA_ZEROC_RT_CORE_RUNTIME_MISC=1, so the build LINKS these bodies from a
// standalone object instead of compiling them inline in runtime_core.c.
//
// PURPOSE = extend the r4 leaf-cluster (rtcore_leaf.c, 10 HexaVal ctors) and
// r5 arith-cluster (rtcore_arith.c, 6 __raw_* wrappers) de-risk to the misc
// direct-external class — runtime_core.c symbols whose every callee is
// external-linkage or a macro (the seed-portability rule). It does NOT drop
// the .c file (runtime_core.c drop is all-or-nothing — 250 symbols; this links
// 11 more). Default build (flag unset) is byte-IDENTICAL: these bodies are not
// compiled and the inline #else bodies in runtime_core.c are used verbatim.
//
// SEED-PORTABILITY (the r5 rule): a fn is seed-portable ONLY if EVERY callee
// AND every referenced global is external-linkage or a macro. The 11 below are
// clean — their callees are public extern T symbols (hexa_array_new/push/get/
// set, hexa_map_get/set, hexa_str, hexa_str_char_at, hexa_to_cstring, hexa_int/
// bool/void/float, hexa_is_type, hexa_fnv1a_str, hmap_find, __hx_to_double) or
// libc (free / mkdir / fprintf / exit), and the only globals they touch are the
// PUBLIC extern `__hexa_try_top` (runtime.h:726, de-staticized) and macros.
//   __vs_ptr_eq        → hexa_bool(ext), HX_VS(macro)
//   hexa_fnv1a_str     → pure arithmetic (no callee)
//   hexa_index_get     → hexa_map_get/array_get/str_char_at/to_cstring/int(ext)
//   hexa_index_set     → hexa_map_set/array_set/to_cstring(ext), __hx_to_double
//   hexa_iter_get      → hexa_str/array_get(ext), fprintf/exit(libc)
//   hexa_await_unwrap  → hexa_is_type/fnv1a_str(ext), hmap_find(ext)
//   hexa_valstruct_int → hexa_int(ext), HX_VSF/HX_IS_VALSTRUCT/HX_VS(macro)
//   hexa_val_free_tree → hexa_void(ext), free(libc), recursion(self)
//   hexa_mkdir         → hexa_bool(ext), HX_STR(macro), mkdir(libc)
//   __hexa_try_pop     → __hexa_try_top(ext int, runtime.h:726)
//   __hexa_try_cleanup → __hexa_try_top(ext int, runtime.h:726)
// EXPLICITLY EXCLUDED (NOT clean — reference a FILE-LOCAL static global a
// separate .o cannot resolve):
//   __hexa_try_push    → static jmp_buf* __hexa_try_stack[] (runtime_core.c)
//   __hexa_last_error  → static HexaVal __hexa_error_val   (runtime_core.c)
//   hexa_args          → static int _hexa_argc / char** _hexa_argv
//   hexa_real_args     → static _hexa_argc / _hexa_argv
//   hexa_script_path   → static _hexa_argc / _hexa_argv
// These 5 stay inline-C; a standalone .o could not resolve the file-local
// statics (same exclusion class as rtcore_arith's __raw_fmod → static hxlcl_fmod).
//
// The bodies are the EXACT same C as the runtime_core.c #else arms (SSOT
// self/runtime_core_emit.hexa) — byte-faithful by construction. The callees
// and macros resolve from the rest of the link (runtime_core.c / runtime.h),
// exactly as the r4 leaf seed's hexa_float_to_bits calls hexa_int across the
// .o boundary.
//
// This file is #include'd by a 1-line TU at seed-regen time with the runtime
// headers already in scope (HexaVal / HexaTag / HexaMap / HexaMapTable /
// HexaArr from runtime.h). The macros + the full HexaValStruct body that
// runtime_core.c defines but runtime.h does NOT (HX_ARR_LEN/ITEMS/CAP /
// HX_MAP_LEN / HX_VSF / HX_IS_VALSTRUCT / HX_PTR_OK / struct HexaValStruct) are
// re-declared below under #ifndef guards, byte-identical to the SSOT
// (self/runtime_core_emit.hexa lines 1259-1312 / 1240-1261 / 4701), so the seed
// TU compiles from runtime.h alone — same value, no semantic change.

#include <sys/stat.h>   // mkdir
#include <stdlib.h>     // free / exit
#include <stdio.h>      // fprintf / stderr
#include <stdint.h>

// ── macros runtime_core.c defines but runtime.h does not (byte-identical SSOT)
#ifndef HX_ARR_LEN
#define HX_ARR_LEN(v)   ((v).arr_ptr->len)
#endif
#ifndef HX_ARR_ITEMS
#define HX_ARR_ITEMS(v) ((v).arr_ptr->items)
#endif
#ifndef HX_ARR_CAP
#define HX_ARR_CAP(v)   ((v).arr_ptr->cap)
#endif
#ifndef HX_MAP_LEN
#define HX_MAP_LEN(v)   ((v).map_ptr->len)
#endif
#ifndef HX_IS_VALSTRUCT
#define HX_IS_VALSTRUCT(v) ((v).tag == TAG_VALSTRUCT)
#endif
#ifndef HX_VSF
#define HX_VSF(v, field)       (HX_VS(v)->field)
#endif
#ifndef HX_PTR_OK
#define HX_PTR_OK(p) ((uintptr_t)(p) >= 0x1000)
#endif

// ── full HexaValStruct body (runtime.h only forward-declares it) — byte-faithful
//    to self/runtime_core_emit.hexa lines 1240-1261. Completes the incomplete
//    `typedef struct HexaValStruct HexaValStruct;` from runtime.h.
#ifndef HEXA_VALSTRUCT_BODY_DEFINED
#define HEXA_VALSTRUCT_BODY_DEFINED
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

// ── extern protos for the public callees (T symbols resolved from the link)
extern HexaVal hexa_int(int64_t n);
extern HexaVal hexa_bool(int b);
extern HexaVal hexa_void(void);
extern HexaVal hexa_str(const char* s);
extern HexaVal hexa_map_get(HexaVal m, const char* k);
extern HexaVal hexa_map_set(HexaVal m, const char* k, HexaVal v);
extern HexaVal hexa_array_new(void);
extern HexaVal hexa_array_get(HexaVal a, int64_t i);
extern HexaVal hexa_array_set(HexaVal a, int64_t i, HexaVal v);
extern HexaVal hexa_str_char_at(HexaVal s, HexaVal i);
extern const char* hexa_to_cstring(HexaVal v);
extern int hexa_is_type(HexaVal v, const char* type_name);
extern int hmap_find(HexaMapTable* t, const char* k, uint32_t h);
extern double __hx_to_double(HexaVal v);
extern int __hexa_try_top;   // runtime.h:726 — de-staticized public global

// ── ported bodies (byte-identical to runtime_core.c #else arms) ───────────────

// fnv1a_str: pure arithmetic, no callee.
uint32_t hexa_fnv1a_str(const char* s) {
    uint32_t h = 2166136261u;
    for (; *s; s++) {
        h ^= (uint8_t)*s;
        h *= 16777619u;
    }
    return h;
}

// __vs_ptr_eq: hexa_bool(ext) + HX_VS(macro).
HexaVal __vs_ptr_eq(HexaVal a, HexaVal b) {
    return hexa_bool((HX_VS(a)) == (HX_VS(b)));
}

// hexa_index_get: polymorphic index read (map / str / array).
HexaVal hexa_index_get(HexaVal container, HexaVal key) {
    if (HX_IS_MAP(container) && HX_IS_STR(key)) {
        return hexa_map_get(container, HX_STR(key));
    }
    if (HX_IS_MAP(container)) {
        return hexa_map_get(container, hexa_to_cstring(key));
    }
    int64_t idx;
    if (HX_IS_VALSTRUCT(key) && HX_VS(key)) {
        idx = (HX_VSF(key, tag_i) == TAG_INT)
            ? HX_VSF(key, int_val)
            : (int64_t)__hx_to_double(key);
    } else {
        idx = HX_INT(key);
    }
    if (HX_IS_STR(container)) {
        return hexa_str_char_at(container, hexa_int(idx));
    }
    return hexa_array_get(container, idx);
}

// hexa_iter_get: for-in dispatch (array element / map key-as-string).
HexaVal hexa_iter_get(HexaVal v, int64_t idx) {
    if (HX_IS_MAP(v)) {
        if (!HX_MAP_TBL(v) || idx < 0 || idx >= HX_MAP_LEN(v)) {
            fprintf(stderr, "map iter index %lld out of bounds (len %d)\n", (long long)idx, HX_MAP_LEN(v));
            exit(1);
        }
        return hexa_str(HX_MAP_TBL(v)->order_keys[idx]);
    }
    return hexa_array_get(v, idx);
}

// hexa_index_set: polymorphic index write (map / array).
HexaVal hexa_index_set(HexaVal container, HexaVal key, HexaVal val) {
    if (HX_IS_MAP(container) && HX_IS_STR(key)) {
        return hexa_map_set(container, HX_STR(key), val);
    }
    if (HX_IS_MAP(container)) {
        return hexa_map_set(container, hexa_to_cstring(key), val);
    }
    int64_t idx;
    if (HX_IS_VALSTRUCT(key) && HX_VS(key)) {
        idx = (HX_VSF(key, tag_i) == TAG_INT)
            ? HX_VSF(key, int_val)
            : (int64_t)__hx_to_double(key);
    } else {
        idx = HX_INT(key);
    }
    return hexa_array_set(container, idx, val);
}

// hexa_await_unwrap: RFC-022 await helper (Future-struct unwrap / identity).
HexaVal hexa_await_unwrap(HexaVal v) {
    if (hexa_is_type(v, "Future")) {
        if (HX_IS_MAP(v) && HX_MAP_TBL(v)) {
            uint32_t h = hexa_fnv1a_str("value");
            int si = hmap_find(HX_MAP_TBL(v), "value", h);
            if (si >= 0) {
                HexaVal inner = HX_MAP_TBL(v)->vals[si];
                if (inner.tag != TAG_VOID) {
                    return inner;
                }
            }
        }
    }
    return v;  // identity for non-Future or already-resolved values
}

// hexa_valstruct_int: int field read from a TAG_VALSTRUCT wrapper.
HexaVal hexa_valstruct_int(HexaVal v) {
    if (!HX_IS_VALSTRUCT(v) || !HX_VS(v)) return hexa_int(0);
    return hexa_int(HX_VSF(v, int_val));
}

// hexa_val_free_tree: recursive free of a malloc'd HexaVal tree.
HexaVal hexa_val_free_tree(HexaVal v) {
    switch (HX_TAG(v)) {
        case TAG_VALSTRUCT: {
            HexaValStruct* vs = HX_VS(v);
            if (!HX_PTR_OK(vs)) return hexa_void();
            if (vs->from_arena) return hexa_void();
            hexa_val_free_tree(vs->str_val);
            hexa_val_free_tree(vs->char_val);
            hexa_val_free_tree(vs->array_val);
            hexa_val_free_tree(vs->fn_name);
            hexa_val_free_tree(vs->fn_params);
            hexa_val_free_tree(vs->fn_body);
            hexa_val_free_tree(vs->struct_name);
            hexa_val_free_tree(vs->struct_fields);
            free(vs);
            break;
        }
        case TAG_ARRAY: {
            if (!HX_PTR_OK(v.arr_ptr)) return hexa_void();
            int cap = HX_ARR_CAP(v);
            if (cap < 0) return hexa_void();  // arena-backed
            int len = HX_ARR_LEN(v);
            HexaVal* items = HX_ARR_ITEMS(v);
            if (items) {
                for (int i = 0; i < len; i++) {
                    hexa_val_free_tree(items[i]);
                }
                free(items);
            }
            free(v.arr_ptr);
            break;
        }
        case TAG_MAP: {
            HexaMap* mp = v.map_ptr;
            if (!HX_PTR_OK(mp)) return hexa_void();
            HexaMapTable* t = mp->tbl;
            if (t && !t->from_arena) {
                if (t->slots) {
                    for (int i = 0; i < t->ht_cap; i++) {
                        if (t->slots[i].key) free(t->slots[i].key);
                    }
                    free(t->slots);
                }
                if (t->order_vals) {
                    for (int i = 0; i < t->len; i++) {
                        hexa_val_free_tree(t->order_vals[i]);
                    }
                    free(t->order_vals);
                }
                if (t->vals)       free(t->vals);
                if (t->order_keys) free(t->order_keys);
                free(t);
            }
            free(mp);
            break;
        }
        default: break;
    }
    return hexa_void();
}

// hexa_mkdir: hexa_bool(ext) + HX_STR(macro) + mkdir(libc).
HexaVal hexa_mkdir(HexaVal path) { return hexa_bool(mkdir(HX_STR(path), 0755) == 0); }

// __hexa_try_pop / __hexa_try_cleanup: touch only the PUBLIC extern __hexa_try_top.
void __hexa_try_pop(void) { if (__hexa_try_top > 0) __hexa_try_top--; }
void __hexa_try_cleanup(int* saved) { if (__hexa_try_top > *saved) __hexa_try_top = *saved; }