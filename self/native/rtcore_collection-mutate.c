// self/native/rtcore_collection-mutate.c — zero-c leg-B r7 COLLECTION-MUTATE SEED (link de-risk).
//
// Supplies 13 map/array mutate+query symbols that runtime_core.c externs away
// under HEXA_RT_CORE_COLLECTION_MUTATE_NATIVE (the narrow collection-mutate
// guard, NOT the broad whole-runtime HEXA_RT_SELFEMIT). Compiled to a SEPARATE
// .o (build/rtcore_collection-mutate_native.o) and linked when
// HEXA_ZEROC_RT_CORE_COLLECTION_MUTATE=1, so the build LINKS these bodies from a
// standalone object instead of compiling them inline in runtime_core.c.
//
// PURPOSE = extend the r4 leaf-cluster (rtcore_leaf.c) + r5 arith (rtcore_arith.c)
// link de-risk to the SEED-PORTABLE map/array mutate class — the next batch of
// runtime_core.c symbols whose every immediate callee is external-linkage, a
// macro, or a seed-supplied rt_* (the seed-portability rule). It does NOT drop
// the .c file (runtime_core.c drop is all-or-nothing — 250 symbols; this links
// 13 more). Default build (flag unset) is byte-IDENTICAL: these bodies are not
// compiled and the inline runtime_core.c bodies are used verbatim.
//
// SEED-PORTABILITY (the r5/r7 rule): a fn is seed-portable ONLY if EVERY callee
// is external-linkage, a macro, or a seed-supplied rt_* (array_core .s seed,
// linked in BOTH the aprime and smoke link paths). The seed replicates the
// SMOKE-SAFE arm (the body that compiles with NEITHER HEXA_HAS_HEXA_RT_STDLIB
// nor the hexa-stdlib rt_* present) so the standalone .o links cleanly in the
// stage-5 smoke (no-stdlib) link too — except array_truncate, whose smoke-safe
// rt_array_truncate_native IS in the array_core seed, so the seed keeps that
// delegation byte-faithful to the aprime active path.
//
// The 13 below are clean (immediate callees + their linkage):
//   hexa_map_from_array  → hexa_map_new/hexa_str_as_ptr/hexa_to_string/hexa_map_set
//                          (ext T), HX_IS_ARRAY/HX_ARR_LEN/HX_ARR_ITEMS (macro)
//   hexa_map_invert      → hexa_map_new/hexa_str_as_ptr/hexa_to_string/hexa_map_set/
//                          hexa_str (ext T), HX_MAP_TBL (macro)
//   hexa_map_merge       → hexa_map_set (ext T), HX_MAP_TBL (macro)
//   hexa_map_remove      → hexa_map_remove_impl (ext T)
//   hexa_map_remove_impl → hmap_find/hexa_fnv1a_str (ext T, de-staticized),
//                          free (libc), HX_MAP_TBL/HX_SET_MAP_LEN (macro)
//   hexa_map_set         → hexa_map_set_impl (ext T)
//   hexa_map_set_v       → hexa_map_set/hexa_to_cstring (ext T)
//   hexa_array_contains  → hexa_truthy/hexa_eq (ext T), HX_IS_ARRAY/HX_ARR_LEN/
//                          HX_ARR_ITEMS (macro)  [non-stdlib arm — no rt_*]
//   hexa_array_last      → snprintf (libc), hexa_throw/hexa_str (ext T),
//                          HX_IS_ARRAY/HX_ARR_LEN/HX_ARR_ITEMS/HX_TAG (macro)
//   hexa_array_pop       → rt_array_pop_native (array_core seed), snprintf (libc),
//                          hexa_throw/hexa_str (ext T)
//   hexa_array_set       → rt_array_set_native (array_core seed), snprintf (libc),
//                          hexa_throw/hexa_str (ext T), __hexa_arena_slot_dirty
//                          (ext int — runtime_core.c global)
//   hexa_array_shift     → rt_array_shift_native (array_core seed), snprintf,
//                          hexa_throw/hexa_str (ext T)
//   hexa_array_truncate  → rt_array_truncate_native (array_core seed),
//                          HX_IS_ARRAY (macro)
//
// EXPLICITLY EXCLUDED (NOT clean — static or seed-absent rt_* callee):
//   hexa_array_sort → qsort comparator hexa_sort_cmp is `static int
//                     hexa_sort_cmp(...)` (runtime_core.c:5981) — a separate .o
//                     cannot resolve it; the float fast-path also calls
//                     rt_array_sort_float, which NO seed exports (hexa-stdlib
//                     only, absent in the smoke no-stdlib link). Stays inline-C.
//
// The bodies are the EXACT same C as the runtime_core.c smoke-safe arms (SSOT
// self/runtime_core_emit.hexa) — byte-faithful by construction. The callees
// (hexa_map_new/hexa_map_set/hexa_map_set_impl/hexa_map_remove_impl/hexa_str/
// hexa_str_as_ptr/hexa_to_string/hexa_to_cstring/hexa_eq/hexa_truthy/hexa_throw/
// hmap_find/hexa_fnv1a_str + the rt_array_*_native seed symbols + the
// __hexa_arena_slot_dirty global) resolve from the rest of the link
// (runtime_core.c / runtime.h / array_core .s seed), exactly as the r4 leaf seed
// resolves hexa_int and the r5 arith seed resolves __hx_to_double across the .o
// boundary.
//
// This file is #include'd by a 1-line TU at seed-regen time with the runtime
// headers already in scope (HexaVal / HexaArr / HexaMapTable / HexaMapSlot +
// HX_* macros + the extern protos). Five macros that runtime_core.c defines but
// runtime.h does NOT (HX_ARR_LEN / HX_ARR_ITEMS / HX_SET_MAP_LEN / HX_SET_ARR_LEN
// / HX_IS_VOID) are re-declared below with #ifndef guards, byte-identical to the
// SSOT (self/runtime_core_emit.hexa), so the seed TU compiles from runtime.h
// alone — same value, no semantic change.

#ifndef HX_ARR_LEN
#define HX_ARR_LEN(v)   ((v).arr_ptr->len)
#endif
#ifndef HX_ARR_ITEMS
#define HX_ARR_ITEMS(v) ((v).arr_ptr->items)
#endif
#ifndef HX_SET_MAP_LEN
#define HX_SET_MAP_LEN(v, n)   ((v).map_ptr->len = (n))
#endif
#ifndef HX_SET_ARR_LEN
#define HX_SET_ARR_LEN(v, n)   ((v).arr_ptr->len = (n))
#endif
#ifndef HX_IS_VOID
#define HX_IS_VOID(v)   ((v).tag == TAG_VOID)
#endif

// extern protos for the cross-.o callees (resolved from runtime_core.c / the
// array_core .s seed). runtime.h already declares hexa_map_new/hexa_map_set/
// hexa_str/hexa_to_string/hexa_str_as_ptr/hexa_eq/hexa_truthy/hexa_throw, but
// re-declaring is harmless (identical protos) and keeps the seed self-contained.
extern HexaVal hexa_int(int64_t n);
extern HexaVal hexa_void(void);
extern HexaVal hexa_map_new(void);
extern HexaVal hexa_map_set(HexaVal m, const char* key, HexaVal val);
extern HexaVal hexa_map_set_impl(HexaVal m, const char* key, HexaVal val);
extern HexaVal hexa_map_remove_impl(HexaVal m, const char* key);
extern HexaVal hexa_str(const char* s);
extern HexaVal hexa_to_string(HexaVal v);
extern const char* hexa_str_as_ptr(HexaVal v);
extern const char* hexa_to_cstring(HexaVal v);
extern HexaVal hexa_eq(HexaVal a, HexaVal b);
extern int     hexa_truthy(HexaVal v);
extern void    hexa_throw(HexaVal err);
extern int     hmap_find(HexaMapTable* t, const char* key, uint32_t h);
extern uint32_t hexa_fnv1a_str(const char* s);
extern int     __hexa_arena_slot_dirty;
extern HexaVal rt_array_pop_native(HexaVal arr);
extern HexaVal rt_array_shift_native(HexaVal arr);
extern HexaVal rt_array_set_native(HexaVal arr, HexaVal idx, HexaVal v);
extern HexaVal rt_array_truncate_native(HexaVal arr, HexaVal new_len_v);

// ── map mutate ───────────────────────────────────────────
HexaVal hexa_map_merge(HexaVal a, HexaVal b) {
    if (!HX_MAP_TBL(a)) return a;
    if (!HX_MAP_TBL(b)) return a;
    HexaVal out = a;
    HexaMapTable* tb = HX_MAP_TBL(b);
    for (int i = 0; i < tb->len; i++) {
        out = hexa_map_set(out, tb->order_keys[i], tb->order_vals[i]);
    }
    return out;
}

HexaVal hexa_map_invert(HexaVal m) {
    HexaVal out = hexa_map_new();
    if (!HX_MAP_TBL(m)) return out;
    HexaMapTable* t = HX_MAP_TBL(m);
    for (int i = 0; i < t->len; i++) {
        const char* new_key = hexa_str_as_ptr(hexa_to_string(t->order_vals[i]));
        if (!new_key) continue;
        out = hexa_map_set(out, new_key, hexa_str(t->order_keys[i]));
    }
    return out;
}

HexaVal hexa_map_from_array(HexaVal self_map, HexaVal arr) {
    (void)self_map;
    HexaVal out = hexa_map_new();
    if (!HX_IS_ARRAY(arr)) return out;
    int n = HX_ARR_LEN(arr);
    for (int i = 0; i < n; i++) {
        HexaVal pair = HX_ARR_ITEMS(arr)[i];
        if (!HX_IS_ARRAY(pair) || HX_ARR_LEN(pair) < 2) continue;
        HexaVal k = HX_ARR_ITEMS(pair)[0];
        HexaVal v = HX_ARR_ITEMS(pair)[1];
        const char* k_str = hexa_str_as_ptr(hexa_to_string(k));
        if (!k_str) continue;
        out = hexa_map_set(out, k_str, v);
    }
    return out;
}

HexaVal hexa_map_remove_impl(HexaVal m, const char* key) {
    if (!HX_MAP_TBL(m)) return m;
    HexaMapTable* t = HX_MAP_TBL(m);
    uint32_t h = hexa_fnv1a_str(key);
    int si = hmap_find(t, key, h);
    if (si < 0) return m;

    // ROI-24: O(1) locate in order array via cached order_idx, then shift
    int oi = t->slots[si].order_idx;
    for (int j = oi; j < t->len - 1; j++) {
        t->order_keys[j] = t->order_keys[j+1];
        t->order_vals[j] = t->order_vals[j+1];
    }
    // Fix order_idx for all hash-table slots whose order position shifted
    for (int j = 0; j < t->ht_cap; j++) {
        if (t->slots[j].key && t->slots[j].order_idx > oi) {
            t->slots[j].order_idx--;
        }
    }

    // Remove from hash table: mark slot empty and re-insert displaced entries
    free(t->slots[si].key);
    t->slots[si].key = NULL;
    t->slots[si].hash = 0;
    // Robin Hood deletion: re-probe subsequent slots
    uint32_t mask = (uint32_t)(t->ht_cap - 1);
    uint32_t ci = ((uint32_t)si + 1) & mask;
    while (t->slots[ci].key) {
        // Remove and re-insert this entry
        HexaMapSlot saved_slot = t->slots[ci];
        HexaVal saved_val = t->vals[ci];
        t->slots[ci].key = NULL;
        t->slots[ci].hash = 0;
        uint32_t ri = saved_slot.hash & mask;
        while (t->slots[ri].key) ri = (ri + 1) & mask;
        t->slots[ri] = saved_slot;  // ROI-24: order_idx carried in struct copy
        t->vals[ri] = saved_val;
        ci = (ci + 1) & mask;
    }

    t->len--;
    HX_SET_MAP_LEN(m, t->len);
    return m;
}

HexaVal hexa_map_remove(HexaVal m, const char* key) {
    return hexa_map_remove_impl(m, key);
}

HexaVal hexa_map_set(HexaVal m, const char* key, HexaVal val) {
    return hexa_map_set_impl(m, key, val);
}

HexaVal hexa_map_set_v(HexaVal m, HexaVal key, HexaVal val) { return hexa_map_set(m, hexa_to_cstring(key), val); }

// ── array mutate / query ─────────────────────────────────
int hexa_array_contains(HexaVal arr, HexaVal item) {
    if (!HX_IS_ARRAY(arr)) return 0;
    for (int i = 0; i < HX_ARR_LEN(arr); i++) {
        if (hexa_truthy(hexa_eq(HX_ARR_ITEMS(arr)[i], item))) return 1;
    }
    return 0;
}

HexaVal hexa_array_last(HexaVal arr) {
    if (!HX_IS_ARRAY(arr)) {
        char _buf[128];
        snprintf(_buf, sizeof(_buf), "array.last(): container is not an array (tag=%d)", (int)HX_TAG(arr));
        hexa_throw(hexa_str(_buf));
        return hexa_void();
    }
    int n = HX_ARR_LEN(arr);
    if (n == 0) {
        hexa_throw(hexa_str("array.last(): empty array"));
        return hexa_void();
    }
    return HX_ARR_ITEMS(arr)[n - 1];
}

HexaVal hexa_array_set(HexaVal arr, int64_t idx, HexaVal val) {
    if (!HX_IS_ARRAY(arr)) {
        char _buf[128];
        // Strings hit this branch when the user writes `s[i] = v`. Emit a
        // string-specific diagnostic instead of the generic "container is
        // not an array (tag=3)" — hexa strings are immutable.
        if (HX_IS_STR(arr)) {
            snprintf(_buf, sizeof(_buf), "s[%lld] = …: strings are immutable", (long long)idx);
        } else {
            snprintf(_buf, sizeof(_buf), "array_set[%lld]: container is not an array (tag=%d)", (long long)idx, (int)HX_TAG(arr));
        }
        hexa_throw(hexa_str(_buf));
        return arr;
    }
    int64_t _orig_idx_s = idx;
    // PROBE r15-D12: negative array index = OOB (Go/Rust canonical), not wrap.
    // Mirror of the get path above — `xs[-1] = v` panics.
    if (idx < 0 || idx >= HX_ARR_LEN(arr)) {
        char _buf[128];
        snprintf(_buf, sizeof(_buf), "index %lld out of bounds (len %lld)", (long long)_orig_idx_s, (long long)HX_ARR_LEN(arr));
        hexa_throw(hexa_str(_buf));
        return arr;
    }
    // In-place mutate (no copy — caller reassigns)
    rt_array_set_native(arr, hexa_int(idx), val);
    // ω-interp-2: SETTER for the per-frame "dirty" flag. Any direct write to
    // a host-array element is the canonical "slot may now contain arena Vals"
    // event — covers `array_store[idx] = items.push(item)` from
    // array_push_inplace, plus map_store / struct_store assignments. Marking
    // here is a single-store fast path with no branch on arr identity (the
    // checker in hexa_val_heapify scopes the work to the actual store walked).
    __hexa_arena_slot_dirty = 1;
    return arr;
}

HexaVal hexa_array_pop(HexaVal arr) {
    if (!HX_IS_ARRAY(arr)) {
        char _buf[128];
        snprintf(_buf, sizeof(_buf), "array.pop(): container is not an array (tag=%d)", (int)HX_TAG(arr));
        hexa_throw(hexa_str(_buf));
        return hexa_void();
    }
    if (HX_ARR_LEN(arr) == 0) {
        hexa_throw(hexa_str("array.pop(): empty array"));
        return hexa_void();
    }
    return rt_array_pop_native(arr);
}

HexaVal hexa_array_shift(HexaVal arr) {
    if (!HX_IS_ARRAY(arr)) {
        char _buf[128];
        snprintf(_buf, sizeof(_buf), "array.shift(): container is not an array (tag=%d)", (int)HX_TAG(arr));
        hexa_throw(hexa_str(_buf));
        return hexa_void();
    }
    if (HX_ARR_LEN(arr) == 0) {
        hexa_throw(hexa_str("array.shift(): empty array"));
        return hexa_void();
    }
    return rt_array_shift_native(arr);
}

HexaVal hexa_array_truncate(HexaVal arr, HexaVal new_len_v) {
    if (!HX_IS_ARRAY(arr)) return arr;
    return rt_array_truncate_native(arr, new_len_v);
}