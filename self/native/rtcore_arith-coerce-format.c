// self/native/rtcore_arith-coerce-format.c — zero-c leg-B ARITH-COERCE-FORMAT
// SEED (link de-risk). Mirrors the r4 leaf / r5 arith cluster pattern
// (self/native/rtcore_leaf.c, self/native/rtcore_arith.c).
//
// Supplies 10 numeric/coercion/format HexaVal wrappers that runtime_core.c
// externs away under HEXA_RT_CORE_ARITH_COERCE_FORMAT_NATIVE (the narrow
// cluster-only guard, NOT the broad whole-runtime HEXA_RT_SELFEMIT). Compiled
// to a SEPARATE .o (build/rtcore_arith-coerce-format_native.o) and linked when
// HEXA_ZEROC_RT_CORE_ARITH_COERCE_FORMAT=1, so the build LINKS these bodies
// from a standalone object instead of compiling them inline in runtime_core.c.
// Default build (flag unset) is byte-IDENTICAL: these bodies are not compiled
// and the inline #else bodies in runtime_core.c are used verbatim.
//
// SEED-PORTABILITY (the r5 rule): a fn is seed-portable ONLY if EVERY callee is
// external-linkage or a macro. A static internal-linkage callee a separate .o
// cannot resolve = BLOCK. The 10 below are the SHIPPED-PATH bodies (the build
// always defines HEXA_HAS_HEXA_RT_STDLIB), each of which delegates to an
// external rt_* / public hexa_* helper or a macro — verified seed-portable:
//   hexa_concat_many      → hexa_array_new/hexa_array_push/rt_concat_many_arr (ext) + hexa_str (ext)
//   hexa_fma              → rt_fma_int/rt_fma_float/hexa_float/__hx_to_double (ext) + HX_IS_INT (macro)
//   hexa_len              → rt_len (ext) + HX_INT (macro)        [int64_t ret]
//   hexa_null_coal        → rt_null_coal (ext)
//   hexa_to_int           → rt_to_int (ext)
//   hexa_format           → hexa_to_string/rt_format (ext) + HX_IS_STR (macro)
//   hexa_format_float     → rt_format_float_f/hexa_float/__hx_to_double (ext)
//   hexa_format_float_sci → rt_format_float_sci/hexa_float/__hx_to_double (ext)
//   hexa_print            → rt_print (ext)
//   hexa_str_char_at      → rt_str_char_at/hexa_str (ext) + HX_IS_STR (macro)
//
// EXPLICITLY EXCLUDED (NOT clean / out of scope — recorded so the census is
// honest, no filler):
//   hexa_add_slow / hexa_sub / hexa_mul / hexa_div / hexa_truthy — each carries
//     an INNER `#ifdef HEXA_RT_VALOP_NATIVE` arm and is owned by the VALOP
//     native lane (rt_add_native/rt_sub_native/rt_mul_native/rt_div_native/
//     rt_truthy_native, self/native/valop_core_*.s). Porting them via THIS
//     cluster would shadow the valop fast path when both seeds are co-enabled
//     (a cross-lane flag interaction). Left to the valop lane = no regression.
//   hexa_str_byte_at / hexa_str_char_code_at — use HX_STRLEN, which expands to
//     `hexa_strlen_v_inline(...)`, a `static inline` callee (runtime_core.c:780)
//     that a separate .o cannot resolve from runtime.h alone = BLOCK (the r5
//     static-callee rule).
//
// The bodies are the EXACT same C as the runtime_core.c HEXA_HAS_HEXA_RT_STDLIB
// arms (SSOT self/runtime_core_emit.hexa) — byte-faithful by construction. The
// callees (hexa_array_new/hexa_array_push/hexa_str/hexa_to_string/hexa_float/
// __hx_to_double + the rt_* delegates) resolve from the rest of the link
// (runtime_core.c / the hexa-source stdlib), exactly as the r5 arith seed's
// __raw_add_f calls hexa_int across the .o boundary.
//
// This file is #include'd by a 1-line TU at seed-regen time with the runtime
// headers already in scope (HexaVal / HexaTag / HX_INT / HX_IS_STR / HX_IS_INT
// + the public protos for hexa_int/float/str/void/array_new/array_push/
// to_string + __hx_to_double). The rt_* delegates are external T symbols in the
// linked binary; they are forward-declared below exactly as the runtime_core.c
// arms declare them, so the seed TU compiles from runtime.h alone.

// rt_* delegates — external-linkage in the hexa-source stdlib, declared here
// verbatim from the runtime_core.c HEXA_HAS_HEXA_RT_STDLIB arms.
extern HexaVal rt_concat_many_arr(HexaVal parts);
extern HexaVal rt_fma_int(HexaVal a, HexaVal b, HexaVal c);
extern HexaVal rt_fma_float(HexaVal a, HexaVal b, HexaVal c);
extern HexaVal rt_len(HexaVal v);
extern HexaVal rt_null_coal(HexaVal a, HexaVal b);
extern HexaVal rt_to_int(HexaVal v);
extern HexaVal rt_format(HexaVal fmt, HexaVal sarg);
extern HexaVal rt_format_float_f(HexaVal v, HexaVal prec);
extern HexaVal rt_format_float_sci(HexaVal v, HexaVal prec);
extern HexaVal rt_print(HexaVal v);
extern HexaVal rt_str_char_at(HexaVal s, HexaVal idx);

// hexa_concat_many — TAG_ARRAY bridge → rt_concat_many_arr (runtime_core.c arm).
HexaVal hexa_concat_many(int n, HexaVal* parts) {
    if (n <= 0) return hexa_str("");
    HexaVal arr = hexa_array_new();
    for (int i = 0; i < n; i++) {
        arr = hexa_array_push(arr, parts[i]);
    }
    return rt_concat_many_arr(arr);
}

// hexa_fma — fused multiply-add via rt_fma_int / rt_fma_float.
HexaVal hexa_fma(HexaVal a, HexaVal b, HexaVal c) {
    if (HX_IS_INT(a) && HX_IS_INT(b) && HX_IS_INT(c))
        return rt_fma_int(a, b, c);
    return rt_fma_float(hexa_float(__hx_to_double(a)),
                        hexa_float(__hx_to_double(b)),
                        hexa_float(__hx_to_double(c)));
}

// hexa_len — int64_t return; delegates to rt_len, unwraps via HX_INT.
int64_t hexa_len(HexaVal v) {
    return HX_INT(rt_len(v));
}

// hexa_null_coal — `??` predicate delegate.
HexaVal hexa_null_coal(HexaVal a, HexaVal b) {
    return rt_null_coal(a, b);
}

// hexa_to_int — scalar→int coercion delegate.
HexaVal hexa_to_int(HexaVal v) { return rt_to_int(v); }

// hexa_format — single-arg `{}` format; polymorphic arg coerced C-side.
HexaVal hexa_format(HexaVal fmt, HexaVal arg) {
    if (!HX_IS_STR(fmt)) return fmt;
    HexaVal sarg = hexa_to_string(arg);
    return rt_format(fmt, sarg);
}

// hexa_format_float — `%.*f` delegate.
HexaVal hexa_format_float(HexaVal f, HexaVal prec) {
    return rt_format_float_f(hexa_float(__hx_to_double(f)), prec);
}

// hexa_format_float_sci — `%.*e` delegate.
HexaVal hexa_format_float_sci(HexaVal f, HexaVal prec) {
    return rt_format_float_sci(hexa_float(__hx_to_double(f)), prec);
}

// hexa_print — print delegate.
HexaVal hexa_print(HexaVal v) {
    return rt_print(v);
}

// hexa_str_char_at — byte-indexed char access delegate.
HexaVal hexa_str_char_at(HexaVal s, HexaVal idx) {
    if (!HX_IS_STR(s)) return hexa_str("");
    return rt_str_char_at(s, idx);
}
