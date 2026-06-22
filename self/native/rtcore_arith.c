// self/native/rtcore_arith.c — zero-c leg-B r5 CLEAN-6 ARITH SEED (link de-risk).
//
// Supplies 6 pure-arithmetic __raw_* / __map_raw_* HexaVal wrappers that
// runtime_core.c externs away under HEXA_RT_CORE_ARITH_NATIVE (the narrow
// arith-only guard, NOT the broad whole-runtime HEXA_RT_SELFEMIT). Compiled to
// a SEPARATE .o (build/rtcore_arith_native.o) and linked when
// HEXA_ZEROC_RT_CORE_ARITH=1, so the build LINKS these bodies from a standalone
// object instead of compiling them inline in runtime_core.c.
//
// PURPOSE = extend the r4 leaf-cluster de-risk (self/native/rtcore_leaf.c, the
// 10 HexaVal value-ctors) to the SEED-PORTABLE __raw_* arithmetic class — the
// next batch of runtime_core.c symbols whose every callee is external-linkage
// or a macro (the seed-portability rule). It does NOT drop the .c file
// (runtime_core.c drop is all-or-nothing — 250 symbols; this links 6 more).
// Default build (flag unset) is byte-IDENTICAL: these bodies are not compiled
// and the inline #else bodies in runtime_core.c are used verbatim.
//
// SEED-PORTABILITY (the r5 rule): a fn is seed-portable ONLY if EVERY callee is
// external-linkage or a macro. The 6 below are clean:
//   __raw_idiv    → hexa_int(ext), HX_INT(macro), `/`
//   __raw_imod    → hexa_int(ext), HX_INT(macro), `%`
//   __raw_d2i     → hexa_int(ext), __hx_to_double(ext), (int64_t) cast
//   __raw_code_is → hexa_bool(ext), HX_INT(macro), `==`
//   __raw_add_f   → hexa_int/hexa_float(ext), __hx_to_double(ext),
//                   HX_IS_BOOL/HX_BOOL(macro)
//   __map_raw_len → hexa_int(ext), HX_MAP_LEN(macro)
// EXPLICITLY EXCLUDED (NOT clean — internal-linkage static callee):
//   __raw_fmod  → static hxlcl_fmod  (runtime.c:2357 `static double hxlcl_fmod`)
//   __raw_cmp3  → static _hexa_enum_pair_idx / hxlcl_strcmp / _hx_int_slot_ordered
// These two stay inline-C; a separate .o could not resolve the static callees.
//
// The bodies are the EXACT same C as the runtime_core.c #else arms (SSOT
// self/runtime_core_emit.hexa lines 3013/7715/8706/9223/9224/9435) —
// byte-faithful by construction. The callees (hexa_int/hexa_float/hexa_bool/
// __hx_to_double) and the macros (HX_INT/HX_FLOAT/HX_IS_BOOL/HX_BOOL/HX_MAP_LEN)
// resolve from the rest of the link (runtime_core.c / runtime.h), exactly as the
// r4 leaf seed's hexa_float_to_bits calls hexa_int across the .o boundary.
//
// This file is #include'd by a 1-line TU at seed-regen time with the runtime
// headers already in scope (HexaVal / HexaTag / HX_INT / HX_FLOAT / HX_BOOL +
// the extern protos for hexa_int/float/bool + __hx_to_double). Two macros that
// runtime_core.c defines but runtime.h does NOT (HX_IS_BOOL / HX_MAP_LEN) are
// re-declared below with #ifndef guards, byte-identical to the SSOT
// (self/runtime_core_emit.hexa lines 1305 / 1262), so the seed TU compiles from
// runtime.h alone — same value, no semantic change.

#ifndef HX_IS_BOOL
#define HX_IS_BOOL(v)   ((v).tag == TAG_BOOL)
#endif
#ifndef HX_MAP_LEN
#define HX_MAP_LEN(v)   ((v).map_ptr->len)
#endif

HexaVal __raw_idiv(HexaVal a, HexaVal b) { return hexa_int(HX_INT(a) / HX_INT(b)); }
HexaVal __raw_imod(HexaVal a, HexaVal b) { return hexa_int(HX_INT(a) % HX_INT(b)); }
HexaVal __raw_d2i(HexaVal v) { return hexa_int((int64_t)__hx_to_double(v)); }
HexaVal __raw_code_is(HexaVal v, HexaVal k) { return hexa_bool(HX_INT(v) == HX_INT(k)); }
HexaVal __raw_add_f(HexaVal a, HexaVal b) {
    if (HX_IS_BOOL(a)) a = hexa_int(HX_BOOL(a) ? 1 : 0);
    if (HX_IS_BOOL(b)) b = hexa_int(HX_BOOL(b) ? 1 : 0);
    return hexa_float(__hx_to_double(a) + __hx_to_double(b));
}
HexaVal __map_raw_len(HexaVal m) { return hexa_int(HX_MAP_LEN(m)); }
