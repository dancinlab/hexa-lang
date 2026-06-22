// self/native/rtcore_math.c — zero-c leg-B r7 CLEAN-4 TRANSCENDENTAL SEED (link de-risk).
//
// Supplies 4 pure-transcendental HexaVal wrappers (hexa_sin / hexa_cos /
// hexa_exp / hexa_log) that runtime_core.c externs away under
// HEXA_RT_CORE_MATH_NATIVE (the narrow math-only guard, NOT the broad
// whole-runtime HEXA_RT_SELFEMIT). Compiled to a SEPARATE .o
// (build/rtcore_math_native.o) and linked when HEXA_ZEROC_RT_CORE_MATH=1, so the
// build LINKS these bodies from a standalone object instead of compiling them
// inline in runtime_core.c.
//
// PURPOSE = extend the r4 leaf-cluster (rtcore_leaf.c, 10 HexaVal ctors), r5
// clean-6 arith (rtcore_arith.c), and r6 clean-7 +__raw_fmod de-risk to the next
// seed-portable cluster: the transcendental float ops. It does NOT drop the .c
// file (runtime_core.c drop is all-or-nothing — 250 symbols; this links 4 more).
// Default build (flag unset) is byte-IDENTICAL: these bodies are not compiled and
// the inline #else bodies in runtime_core.c are used verbatim.
//
// CENSUS (r7): the math cluster in runtime_core.c splits into TWO seed-portability
// classes under the shipping HEXA_HAS_HEXA_RT_STDLIB build:
//   (a) hexa_sqrt/pow/floor/ceil/u_floor/abs/tan/log10/round/tanh/log2/to_float —
//       their #else arm already delegates to EXTERNAL rt_* (e.g. rt_sqrt, rt_pow_*,
//       rt_floor); already seed-portable BUT they live inside a #ifndef/#else pair,
//       so seeding them means a 3rd #if level — deferred to r8 (larger surface).
//   (b) hexa_sin/cos/exp/log — emitted UNCONDITIONALLY (no #else arm) as
//       `hexa_float(hxlcl_*(__hx_to_double(v)))`, where hxlcl_sin/cos/exp/log are
//       FROZEN-STATIC helpers (151c52c8…:2358-2361 `static double hxlcl_*`). At
//       first glance the static callee is an r6-style WALL — but exactly like r6's
//       hxlcl_fmod, each hxlcl_* is a 1-line delegate to an EXTERNAL rt_* core:
//         static double hxlcl_sin(double x) { return HX_FLOAT(rt_sin(hexa_float(x))); }
//         (151c52c8…:2358 rt_exp / :2322 rt_log / :2333 rt_cos / :2345 rt_sin —
//          all `HexaVal rt_*(...)`, NO `static`). So routing the SEED body through
//       rt_sin/cos/exp/log directly (extern) instead of the frozen-static hxlcl_*
//       makes hexa_sin/cos/exp/log seed-portable WITHOUT touching the immutable
//       frozen blob. This is the r6 external-delegate route applied to class (b).
//   These 4 are the r7 cluster.
//
// SEED-PORTABILITY (the r5 rule): a fn is seed-portable ONLY if EVERY callee is
// external-linkage or a macro. The 4 below are clean via the delegate route:
//   hexa_sin → rt_sin(EXTERNAL), hexa_float/__hx_to_double(ext), HX_FLOAT(macro)
//   hexa_cos → rt_cos(EXTERNAL), hexa_float/__hx_to_double(ext), HX_FLOAT(macro)
//   hexa_exp → rt_exp(EXTERNAL), hexa_float/__hx_to_double(ext), HX_FLOAT(macro)
//   hexa_log → rt_log(EXTERNAL), hexa_float/__hx_to_double(ext), HX_FLOAT(macro)
// (hexa_float / __hx_to_double are PUBLIC defs in runtime_core.c — external T
//  symbols in the linked binary, exactly like the r5/r6 arith seed's callees.)
//
// STILL EXCLUDED FROM r7 (deferred, not walled): the class-(a) #else-armed math
// fns (hexa_sqrt/pow/floor/…) — seed-portable but inside a #if/#else, a wider
// surface than this focused 4-fn de-risk. hexa_tan/log10/round/tanh/log2 likewise
// have an #else arm; only sin/cos/exp/log are #else-LESS, so they are the cluster
// where the frozen-static delegate route is the ONLY way to link them out.
//
// BIT-IDENTITY: the OFF inline body `hexa_float(hxlcl_sin(__hx_to_double(v)))`
// expands (hxlcl_sin = HX_FLOAT(rt_sin(hexa_float(x)))) to
// `hexa_float(HX_FLOAT(rt_sin(hexa_float(__hx_to_double(v)))))` — exactly the seed
// body below. The outer hexa_float(HX_FLOAT(...)) re-box is identity on a float
// result, so both arms compute the same bits; the OFF arm is preserved verbatim
// (runtime_core_emit.hexa #else) so the default build is byte-identical.
//
// This file is #include'd by a 1-line TU at seed-regen time with the runtime
// headers already in scope (HexaVal / HX_FLOAT + extern protos for
// hexa_float / __hx_to_double). HX_FLOAT is declared by runtime.h; no extra
// re-declares are needed for this cluster (unlike the arith seed's HX_IS_BOOL /
// HX_MAP_LEN). rt_sin/cos/exp/log are not declared in runtime.h, so re-declare
// the externs here (same prototype as the frozen runtime.c).

extern HexaVal rt_sin(HexaVal x);
extern HexaVal rt_cos(HexaVal x);
extern HexaVal rt_exp(HexaVal x);
extern HexaVal rt_log(HexaVal x);

// zero-c r7 — hexa_sin/cos/exp/log, made seed-portable by routing through the
// EXTERNAL rt_* cores instead of the frozen-static hxlcl_* delegates. Each is the
// expanded form of the inline #else body and computes bit-identical results.
HexaVal hexa_sin(HexaVal v) { return hexa_float(HX_FLOAT(rt_sin(hexa_float(__hx_to_double(v))))); }
HexaVal hexa_cos(HexaVal v) { return hexa_float(HX_FLOAT(rt_cos(hexa_float(__hx_to_double(v))))); }
HexaVal hexa_exp(HexaVal v) { return hexa_float(HX_FLOAT(rt_exp(hexa_float(__hx_to_double(v))))); }
HexaVal hexa_log(HexaVal v) { return hexa_float(HX_FLOAT(rt_log(hexa_float(__hx_to_double(v))))); }
