// self/native/rtcore_map-query-fold.c — zero-c leg-B MAP-QUERY-FOLD SEED (link de-risk).
//
// Supplies 8 map query runtime_core.c symbols that the build externs away under
// HEXA_RT_CORE_MAP_QUERY_FOLD_NATIVE (the narrow map-query guard, NOT the broad
// whole-runtime HEXA_RT_SELFEMIT). Compiled to a SEPARATE .o
// (build/rtcore_map_query_fold_native.o) and linked when
// HEXA_ZEROC_RT_CORE_MAP_QUERY_FOLD=1, so the build LINKS these bodies from a
// standalone object instead of compiling them inline in runtime_core.c.
//
// PURPOSE = extend the r4 leaf-cluster / r5 arith de-risk
// (self/native/rtcore_leaf.c · self/native/rtcore_arith.c) to the SEED-PORTABLE
// map query class — runtime_core.c symbols whose every immediate callee is
// external-linkage or a macro (the seed-portability rule) AND whose runtime_core.c
// body is UNGUARDED (single definition, compiled identically in the aprime build
// AND the stage-5 standalone smoke link). It does NOT drop the .c file
// (runtime_core.c drop is all-or-nothing — 250 symbols; this links 8 more).
// Default build (flag unset) is byte-IDENTICAL: these bodies are not compiled and
// the inline runtime_core.c bodies are used verbatim.
//
// SCOPE — only the UNGUARDED single-body fns of the map-query-fold cluster are
// linked here. The 11 cluster fns whose runtime_core.c definition is wrapped in
// the shipping `#ifdef HEXA_HAS_HEXA_RT_STDLIB / #else / #endif` dual-arm guard
// (hexa_map_get / keys / values / entries / contains_key / map_values /
// filter_keys / count / any / all) are DROPPED this round: the stage-5 smoke
// links runtime.c WITHOUT HEXA_HAS_HEXA_RT_STDLIB, so it compiles their `#else`
// C-arm body — which would COLLIDE (duplicate symbol) with a seed that also
// defines them. Safely externing those needs a guard inside BOTH arms (a more
// invasive shipping-region edit), deferred to a dedicated round. __map_ptr_eq is
// ALSO dropped — runtime.h provides it as a `static inline` (runtime.h:190-195),
// so it has no external T export and a separate .o cannot carry it.
//
// SEED-PORTABILITY (the rule): a fn is seed-portable ONLY if EVERY immediate
// callee is external-linkage or a macro. The 8 below are clean:
//   __map_has_cstr_v   → HX_MAP_TBL(macro) HX_STR(macro) hmap_find(ext)
//                        hexa_fnv1a_str(ext) hexa_bool(ext)
//   __map_get_cstr_v   → ditto + hexa_void(ext), t->vals[] (struct field read)
//   __map_order_key_at → HX_MAP_TBL HX_INT(macro) hexa_void/hexa_str(ext)
//   __map_order_val_at → HX_MAP_TBL HX_INT hexa_void(ext), t->order_vals[]
//   __map_set_cstr_v   → HX_STR hexa_map_set_impl(ext)
//   __map_remove_cstr_v→ HX_STR hexa_map_remove_impl(ext)
//   hexa_map_get_v     → hexa_map_get(ext) hexa_to_cstring(ext)
//   hexa_map_to_array  → hexa_map_entries(ext)
//
// The callees (hexa_bool/void/str/int/map_get/map_entries/map_set_impl/
// map_remove_impl, the hmap_find/hexa_fnv1a_str de-staticized helpers) resolve
// from the rest of the link (runtime_core.c / runtime.h), exactly as the r4 leaf
// seed's hexa_float_to_bits calls hexa_int across the .o boundary.
//
// This file is #include'd by a 1-line TU at seed-regen time with self/runtime.h
// already in scope (HexaVal / HexaMapTable / HX_INT / HX_STR / HX_MAP_TBL + the
// extern protos for hexa_bool/void/str/int/map_get/map_entries/map_set_impl/
// map_remove_impl/to_cstring). The two de-staticized helpers hmap_find /
// hexa_fnv1a_str that runtime.h does NOT carry are re-declared below — byte-
// identical to the runtime_core.c SSOT (no semantic change) — so the seed TU
// compiles from runtime.h alone.

// ── extern protos runtime.h does NOT carry (de-staticized / runtime_core.c) ──
extern int hmap_find(HexaMapTable* t, const char* key, uint32_t h);
extern uint32_t hexa_fnv1a_str(const char* s);

HexaVal __map_has_cstr_v(HexaVal m, HexaVal key) {
    HexaMapTable* t = HX_MAP_TBL(m);
    if (!t) return hexa_bool(0);
    const char* k = HX_STR(key);
    if (!k) return hexa_bool(0);
    return hexa_bool(hmap_find(t, k, hexa_fnv1a_str(k)) >= 0);
}

HexaVal __map_get_cstr_v(HexaVal m, HexaVal key) {
    HexaMapTable* t = HX_MAP_TBL(m);
    if (!t) return hexa_void();
    const char* k = HX_STR(key);
    if (!k) return hexa_void();
    int si = hmap_find(t, k, hexa_fnv1a_str(k));
    if (si < 0) return hexa_void();
    return t->vals[si];
}

HexaVal __map_order_key_at(HexaVal m, HexaVal i) {
    HexaMapTable* t = HX_MAP_TBL(m);
    if (!t) return hexa_void();
    int idx = (int)HX_INT(i);
    if (idx < 0 || idx >= t->len) return hexa_void();
    return hexa_str(t->order_keys[idx]);
}

HexaVal __map_order_val_at(HexaVal m, HexaVal i) {
    HexaMapTable* t = HX_MAP_TBL(m);
    if (!t) return hexa_void();
    int idx = (int)HX_INT(i);
    if (idx < 0 || idx >= t->len) return hexa_void();
    return t->order_vals[idx];
}

HexaVal __map_set_cstr_v(HexaVal m, HexaVal key, HexaVal val) {
    const char* k = HX_STR(key);
    if (!k) return m;
    return hexa_map_set_impl(m, k, val);
}

HexaVal __map_remove_cstr_v(HexaVal m, HexaVal key) {
    const char* k = HX_STR(key);
    if (!k) return m;
    return hexa_map_remove_impl(m, k);
}

HexaVal hexa_map_get_v(HexaVal m, HexaVal key) { return hexa_map_get(m, hexa_to_cstring(key)); }

HexaVal hexa_map_to_array(HexaVal m) {
    return hexa_map_entries(m);
}
