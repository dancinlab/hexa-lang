// self/native/zeroc_rt_core_prims.c — ZERO-C leg-B (ING #35, r11).
//
// The drop-ON build removes runtime_core.c + runtime_hi_gen.c from the
// compile, so the standalone EXECUTABLE link of the drop-ON runtime loses
// the CORE-tier rt_* primitive bodies that the seed cluster `hexa_*`
// wrappers delegate to (rt_format/rt_print live in the hexa stdlib runtime;
// the math ones come from rtcore math seeds). The cluster seed objects
// (rtcore_arith-coerce-format.c, rtcore_math2.c) only define the `hexa_*`
// wrappers and EXTERN the rt_* leaves — so a full executable link is left
// with the rt_* CORE prims undefined.
//
// This seed re-supplies the SELF-CONTAINED numeric/coercion rt_* leaves as a
// SEPARATE relocatable object (the string-format + IO + transcendental rt_*
// come from the transpiled stdlib runtime modules ctype/io/math). Faithful to
// the stdlib/runtime/numeric.hexa SSOT (transcribed, HexaVal ABI). It is
// MEASURE/EXEC-ONLY: the DEFAULT build never compiles this file (no caller
// passes -DHEXA_ZEROC_RT_CORE_PRIMS), so the default path is byte-IDENTICAL.
//
// Included by a 1-line TU with runtime.h in scope (HexaVal / HX_* / hexa_*).
// rt_log10 (sci-format) and __hx_to_double are external T symbols in the link.

extern HexaVal rt_log10(HexaVal x);

// ── numeric: abs / floor / ceil / u_floor / round (numeric.hexa) ──────────
HexaVal rt_abs_int(HexaVal v)   { long long x = HX_INT(v);   return hexa_int(x < 0 ? -x : x); }
HexaVal rt_abs_float(HexaVal v) { double x = HX_FLOAT(v);    return hexa_float(x < 0.0 ? -x : x); }

HexaVal rt_floor(HexaVal v) {
    double d = HX_FLOAT(v); long long i = (long long)d;
    if (d >= 0.0) return hexa_int(i);
    if ((double)i == d) return hexa_int(i);
    return hexa_int(i - 1);
}
HexaVal rt_ceil(HexaVal v) {
    double d = HX_FLOAT(v); long long i = (long long)d;
    if (d <= 0.0) return hexa_int(i);
    if ((double)i == d) return hexa_int(i);
    return hexa_int(i + 1);
}
HexaVal rt_u_floor(HexaVal va, HexaVal vb) {
    long long a = HX_INT(va), b = HX_INT(vb);
    if (b == 0) return hexa_int(0);
    long long q = a / b, r = a - q * b;
    if (r != 0 && ((a < 0) != (b < 0))) return hexa_int(q - 1);
    return hexa_int(q);
}
HexaVal rt_round(HexaVal v) {
    double d = HX_FLOAT(v);
    if (d >= 0.0) return hexa_int((long long)(d + 0.5));
    return hexa_int((long long)(d - 0.5));
}

// ── numeric: fma / pow_int / to_float (numeric.hexa cycle 21/6/12) ─────────
HexaVal rt_fma_int(HexaVal a, HexaVal b, HexaVal c)   { return hexa_int(HX_INT(a) * HX_INT(b) + HX_INT(c)); }
HexaVal rt_fma_float(HexaVal a, HexaVal b, HexaVal c) { return hexa_float(HX_FLOAT(a) * HX_FLOAT(b) + HX_FLOAT(c)); }
HexaVal rt_pow_int(HexaVal vb, HexaVal ve) {
    long long e = HX_INT(ve); if (e < 0) return hexa_int(0);
    long long r = 1, base = HX_INT(vb);
    while (e > 0) { if (e & 1) r = r * base; base = base * base; e >>= 1; }
    return hexa_int(r);
}
HexaVal rt_to_float(HexaVal v) { return hexa_float(__hx_to_double(v)); }

// ── numeric: to_int / len / null_coal (numeric.hexa) ──────────────────────
HexaVal rt_to_int(HexaVal v) {
    if (HX_IS_INT(v)) return v;
    if (HX_IS_STR(v)) return hexa_str_parse_int(v);
    return hexa_int((long long)__hx_to_double(v));   // __raw_d2i bridge
}
HexaVal rt_len(HexaVal v) { return hexa_byte_len(v); }
HexaVal rt_null_coal(HexaVal a, HexaVal b) {
    if (a.tag == TAG_VOID) return b;
    if (HX_IS_STR(a)) {
        const char* s = HX_STR(a);
        if (!s || s[0] == 0) return b;
    }
    return a;
}

// ── concat-many (numeric.hexa cycle …) — fold + with hexa_add over array ──
HexaVal rt_concat_many_arr(HexaVal parts) {
    long long n = (long long)HX_INT(hexa_byte_len(parts));
    if (n <= 0) return hexa_str("");
    HexaVal acc = hexa_index_get(parts, hexa_int(0));
    for (long long i = 1; i < n; i++)
        acc = hexa_add_slow(acc, hexa_index_get(parts, hexa_int(i)));
    return acc;
}

// ── float→string format (numeric.hexa cycle 60/61) — libc snprintf delegate.
// The hexa-source builds the string digit-by-digit via bytes_to_str_raw; for
// the standalone exec link we delegate to snprintf (same %.*f / %.*e shape).
HexaVal rt_format_float_f(HexaVal v, HexaVal prec) {
    char buf[64]; int p = (int)HX_INT(prec); if (p < 0) p = 0; if (p > 18) p = 18;
    snprintf(buf, sizeof buf, "%.*f", p, HX_FLOAT(v));
    return hexa_str(buf);
}
HexaVal rt_format_float_sci(HexaVal v, HexaVal prec) {
    char buf[64]; int p = (int)HX_INT(prec); if (p < 0) p = 0; if (p > 18) p = 18;
    snprintf(buf, sizeof buf, "%.*e", p, HX_FLOAT(v));
    return hexa_str(buf);
}

// _hexa_init_fn_shims — drop-link-fill. In the DEFAULT (non-drop) build,
// runtime_core.c is concatenated INTO runtime.c so this static initializer
// (runtime.c:13437) and its call site (runtime_core.c:8520) share one TU and
// bind directly. The whole-file DROP separates them into two objects: the body
// stays in the dropped-runtime object (static, invisible) while the call site
// moves to the arena-globals seed TU → an undefined cross-TU reloc that the
// concatenated build never had. The first-class TAG_FN handles it wires (join/
// char_code/chr/farr_*) are only consulted when hexa user-code uses those
// builtins as VALUES; the substrate/exec path does not. We supply an external
// no-op so the drop-ON binary LINKS; the real wiring is the non-drop runtime.
extern int _hexa_init_fn_shims_was_dropped;   /* marker only, unused */
void _hexa_init_fn_shims(void) { /* drop-link-fill: see header */ }
