// self/native/rtcore_leaf.c — zero-c leg-B r4 LEAF-CLUSTER SEED (link de-risk).
//
// Supplies the 10 HexaVal value-ctor/reinterpret symbols that runtime_core.c
// externs away under HEXA_RT_CORE_LEAF_NATIVE (the narrow ctor-only guard, NOT
// the broad whole-runtime HEXA_RT_SELFEMIT). Compiled to a SEPARATE .o
// (build/rtcore_leaf_native.o) and linked when HEXA_ZEROC_RT_CORE_LEAF=1, so
// the build LINKS these bodies from a standalone object instead of compiling
// them inline in runtime_core.c.
//
// PURPOSE = de-risk the standalone-link path (separate .o + extern + symbol
// resolution across the HexaVal 16-byte struct-return ABI) that the full r5
// runtime_core.c redesign needs. It does NOT drop the .c file (runtime_core.c
// drop is all-or-nothing — 250 symbols; this ports 10). Default build
// (flag unset) is byte-IDENTICAL: these bodies are not compiled and the
// inline #else aggregate-literals in runtime_core.c are used verbatim.
//
// The bodies are the EXACT same C aggregate-literals as the runtime_core.c
// #else arms (SSOT self/runtime_core_emit.hexa lines ~1540/1640/1654/1662/1667/
// 1682/1700) — byte-faithful by construction. A future r5 step can swap this
// C SSOT for hand-emitted native .s seeds (self/codegen/runtime_arm64.hexa
// already has the arm64 machine code: rt_hexa_void/int/bool/float/enum_str).
//
// This file is #include'd by a 1-line TU at seed-regen time with the runtime
// headers already in scope (HexaVal / HexaTag / HexaEnumDesc / HX_INT/HX_FLOAT).

HexaVal hexa_int(int64_t n)   { return (HexaVal){.tag=TAG_INT,   .i=n}; }
HexaVal hexa_float(double f)  { return (HexaVal){.tag=TAG_FLOAT, .f=f}; }
HexaVal hexa_bool(int b)      { return (HexaVal){.tag=TAG_BOOL,  .b=b}; }
HexaVal hexa_void(void)       { return (HexaVal){.tag=TAG_VOID}; }
HexaVal hexa_float_to_bits(HexaVal x) { union { double d; int64_t i; } u; u.d = HX_FLOAT(x); return hexa_int(u.i); }
HexaVal hexa_bits_to_float(HexaVal x) { union { int64_t i; double d; } u; u.i = HX_INT(x);   return hexa_float(u.d); }
HexaVal float_to_bits(HexaVal x) { return hexa_float_to_bits(x); }
HexaVal bits_to_float(HexaVal x) { return hexa_bits_to_float(x); }
HexaVal hexa_enum_str(const char* display)        { return (HexaVal){.tag=TAG_ENUM, .s=(char*)display}; }
HexaVal hexa_enum_str_v(const struct HexaEnumDesc* desc) { return (HexaVal){.tag=TAG_ENUM, .s=(char*)desc}; }
