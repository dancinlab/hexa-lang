// self/native/rtcore_math2.c — zero-c leg-B r8 ELSE-MATH SEED (link de-risk).
//
// Supplies 12 #else-armed math HexaVal wrappers as a SEPARATE object so that
// build_aprime can LINK these bodies from a standalone .o instead of compiling
// them inline in runtime_core.c:
//   hexa_sqrt · hexa_pow · hexa_floor · hexa_ceil · hexa_u_floor · hexa_abs ·
//   hexa_tan · hexa_log10 · hexa_round · hexa_tanh · hexa_log2 · hexa_to_float
//
// runtime_core.c externs these away under the narrow HEXA_RT_CORE_MATH2_NATIVE
// guard (NOT the broad whole-runtime HEXA_RT_SELFEMIT). Compiled to a SEPARATE
// .o (build/rtcore_math2_native.o) and linked when HEXA_ZEROC_RT_CORE_MATH2=1,
// so the build LINKS these bodies from a standalone object.
//
// PURPOSE = the r7 census's class-(a) cluster, picked up exactly as r7 deferred
// it ("STILL EXCLUDED FROM r7 … the class-(a) #else-armed math fns
// hexa_sqrt/pow/floor/… — seed-portable but inside a #if/#else, a wider surface").
// This round seeds that wider surface: each of the 12 lives inside a
// `#ifndef HEXA_HAS_HEXA_RT_STDLIB / #else / #endif` pair, and in the SHIPPING
// build (HEXA_HAS_HEXA_RT_STDLIB defined) the #else arm already delegates to an
// EXTERNAL rt_* core. So the seed body is that exact delegate, and the 3rd #if
// level (added in runtime_core_emit.hexa) externs the hexa_* definition out of
// the shipping arm without touching the #ifndef standalone arm.
//
// It does NOT drop the .c file (runtime_core.c drop is all-or-nothing). Default
// build (flag unset) is byte-IDENTICAL: these bodies are not compiled and the
// inline #else delegate bodies in runtime_core.c are used verbatim (proven by
// preprocessor diff — the inner #else preserves them exactly).
//
// SEED-PORTABILITY (the r5 rule): a fn is seed-portable ONLY if EVERY callee is
// external-linkage or a macro. All 12 are clean:
//   rt_sqrt/rt_pow_int/rt_pow_float/rt_floor/rt_ceil/rt_u_floor/rt_abs_int/
//   rt_abs_float/rt_tan/rt_log10/rt_round/rt_tanh/rt_log2/rt_to_float — EXTERNAL
//     T cores (pub fn in stdlib/runtime/{math,numeric}.hexa, linked into the
//     binary), exactly like r5/r6/r7's rt_* callees.
//   hexa_float / hexa_int / __hx_to_double — PUBLIC defs in runtime_core.c
//     (external T symbols in the linked binary).
//   HX_IS_INT / HX_INT / HX_FLOAT — macros (runtime.h:152/156/157).
// No frozen-STATIC callee anywhere in this cluster (unlike r7's hxlcl_*), so no
// external-delegate re-route is needed — the #else arm is already the clean
// delegate. The seed body is copied VERBATIM from the runtime_core.c #else arm.
//
// BIT-IDENTITY: the seed bodies below are textually identical to the
// runtime_core.c inline #else bodies (same C, same callees resolved from the rest
// of the link), so ON and OFF compute the same bits. The OFF arm is preserved
// verbatim (runtime_core_emit.hexa inner #else) so the default build is
// byte-identical (cpp-proven).
//
// This file is #include'd by a 1-line TU at seed-regen time with the runtime
// headers already in scope (HexaVal / HX_* macros + extern protos for
// hexa_float / hexa_int / __hx_to_double). HX_IS_INT/HX_INT/HX_FLOAT are declared
// by runtime.h; the rt_* cores are NOT declared in runtime.h, so re-declare the
// externs here (same prototype as the frozen runtime.c #else arm).

extern HexaVal rt_sqrt(HexaVal v);
extern HexaVal rt_pow_int(HexaVal b, HexaVal e);
extern HexaVal rt_pow_float(HexaVal b, HexaVal e);
extern HexaVal rt_floor(HexaVal v);
extern HexaVal rt_ceil(HexaVal v);
extern HexaVal rt_u_floor(HexaVal a, HexaVal b);
extern HexaVal rt_abs_int(HexaVal v);
extern HexaVal rt_abs_float(HexaVal v);
extern HexaVal rt_tan(HexaVal x);
extern HexaVal rt_log10(HexaVal x);
extern HexaVal rt_round(HexaVal v);
extern HexaVal rt_tanh(HexaVal x);
extern HexaVal rt_log2(HexaVal x);
extern HexaVal rt_to_float(HexaVal v);

// zero-c r8 — the 12 #else-armed math wrappers, bodies copied VERBATIM from the
// runtime_core.c shipping (#else) arm. Each callee is external-linkage or a macro.
HexaVal hexa_sqrt(HexaVal v) {
    return rt_sqrt(hexa_float(__hx_to_double(v)));
}
HexaVal hexa_pow(HexaVal base, HexaVal exp) {
    if (HX_IS_INT(base) && HX_IS_INT(exp) && HX_INT(exp) >= 0) {
        return rt_pow_int(base, exp);
    }
    return rt_pow_float(hexa_float(__hx_to_double(base)),
                        hexa_float(__hx_to_double(exp)));
}
HexaVal hexa_floor(HexaVal v) {
    return rt_floor(hexa_float(__hx_to_double(v)));
}
HexaVal hexa_ceil(HexaVal v) {
    return rt_ceil(hexa_float(__hx_to_double(v)));
}
HexaVal hexa_u_floor(HexaVal a, HexaVal b) {
    int64_t ai = HX_IS_INT(a) ? HX_INT(a) : (int64_t)__hx_to_double(a);
    int64_t bi = HX_IS_INT(b) ? HX_INT(b) : (int64_t)__hx_to_double(b);
    return rt_u_floor(hexa_int(ai), hexa_int(bi));
}
HexaVal hexa_abs(HexaVal v) {
    if (HX_IS_INT(v)) return rt_abs_int(v);
    return rt_abs_float(v);
}
HexaVal hexa_tan(HexaVal v)   { return rt_tan(hexa_float(__hx_to_double(v))); }
HexaVal hexa_log10(HexaVal v) { return rt_log10(hexa_float(__hx_to_double(v))); }
HexaVal hexa_round(HexaVal v) { return rt_round(hexa_float(__hx_to_double(v))); }
HexaVal hexa_tanh(HexaVal v)  { return rt_tanh(hexa_float(__hx_to_double(v))); }
HexaVal hexa_log2(HexaVal v)  { return rt_log2(hexa_float(__hx_to_double(v))); }
HexaVal hexa_to_float(HexaVal v) {
    return rt_to_float(hexa_float(__hx_to_double(v)));
}
