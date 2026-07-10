# axis-② R1b — strtod anomaly close-out

**Base:** 4efa2f89b (origin/main 25057d1b5 tree). READ-verified; no builds run (mini=git/gh only).

## Census correction (the task's 3 sites are mis-attributed)
`nm runtime.a` strtod comes ONLY from literal `strtod(` calls (there is NO `#define strtod`; `hxlcl_atof` in runtime.c is native, `atof` is `#define`d to it). Actual carriers in runtime.a-relevant emitted C:

| # | emit source | generated | role | live in shipping? |
|---|---|---|---|---|
| A | runtime_emit_full.hexa:14592 | runtime.c:14522 | `_shortest_double` JSON round-trip C fallthrough | **YES** (native block needs EXACT, default-OFF) |
| B | runtime_core_emit.hexa:8031 | runtime_core.c:7640 | `__hexa_format_float_mode` NATIVE round-trip fallback | **YES** (FORMAT_FLOAT_NATIVE ON, falls to strtod on rt_parse_float_native decline) |
| C | runtime_core_emit.hexa:8044 | runtime_core.c:7653 | `__hexa_format_float_mode` REPR_SHORTEST branch | **YES** (UNGATED) |
| — | runtime_core_emit.hexa:2128 (task site 1) | — | `hxlcl_atof` terminal | **NO** — hxlcl_atof is native, no strtod |
| — | runtime_emit_full.hexa:5388 (task site 2) | runtime.c:5305 | `hexa_str_parse_float` | **NO** — `#ifndef HEXA_HAS_HEXA_RT_STDLIB`, compiled out in ship |
| — | runtime_emit.hexa:348 | runtime_hi_seed.c:185 | seed `hexa_str_parse_float` | conditional (lenient family; confirm via nm) |
| — | build_c.hexa:3669 | (app C) | gen2 transpile helper | out of scope (not runtime.a) |

**The real R1b = drop strtod from A, B, C** — all three are round-trip CHECKS on freshly-emitted clean `%g`/native-format decimals, so the full-domain native parser `rt_str_parse_float_exact` (correctly-rounded over all finite decimals, "never declines on %g output", TAG_VOID sentinel on decline) is a byte-exact drop-in. Gate on `HEXA_RT_NUM_PARSE_FLOAT_EXACT` (default-OFF) → `#else` keeps strtod → byte-neutral.

## Why NOT the task's sites 1/2 (and NOT HEXA_RT_STRTOD_TAIL_NATIVE→0.0)
The user parse path (to_float / `__hx_to_double` string coercion / `hexa_str_parse_float`) is **prefix-lenient** (strtod parses a leading numeric prefix, ignores trailing junk; the shipping default `rt_str_parse_float` does the same). All native tiers (`rt_parse_float_native` num_float_core.hexa:207, `rt_str_parse_float_exact` float_parse_exact.hexa:403, hexinfnan) **bail to TAG_VOID on trailing junk**. So a "native-junk 0.0 terminal" would make `to_float("3.5abc")` → 0.0 instead of 3.5 — a miscompile. These sites keep C strtod (no-stdlib) or route to lenient native `rt_str_parse_float` (stdlib ON, already the case). site 1's hxlcl_atof isn't strtod anyway.

## Edits
- **A** runtime_emit_full.hexa: turn the native `#if…EXACT` block's trailing `#endif` (:14589) into `#else`, add a native-branch `%.17g` last-resort return before it, close with `#endif` after the C loop (:14594).
- **B** runtime_core_emit.hexa:8031: `#ifdef EXACT` → route rt_parse_float_native decline to `rt_str_parse_float_exact(r)`; `#else` current strtod.
- **C** runtime_core_emit.hexa:8044: `#ifdef EXACT` → `rt_str_parse_float_exact(hexa_str(buf))`; `#else` current strtod.

## Verify
1. EXACT-OFF (default) byteeq 3-target GREEN + `nm runtime.a | grep strtod` unchanged vs base → neutrality.
2. EXACT-ON rebuild 3-target: `nm` strtod count → 0/3; #4651 float_dtoa_shortest_gate.c parity 0-diff (n~140,678) + float_dtoa_core_gate.c + num_float_core_gate.c 0-fail; byteeq 3-target GREEN + install smoke → then flip EXACT default-ON.

## Kill
Trailing-junk corpus (`"3.5abc"`,`"1e3xyz"`,`"12.5 ."`) fed to the USER path shows native tiers → TAG_VOID vs strtod → prefix value: confirms 0.0-terminal is wrong for lenient sites (keep C there); format sites immune. If post-flip nm still shows strtod → residual is the lenient hexa_str_parse_float seed family (runtime.c:5305 / runtime_hi_seed.o); confirm it is stdlib-routed/dead in the shipping TU rather than nulling it.