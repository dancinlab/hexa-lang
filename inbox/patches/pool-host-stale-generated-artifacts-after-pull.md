# pool host stale generated artifacts after pull

> Materialized from cross-repo handoff `ab8b16ff` (from demiurge, 1780377587) per demiurge @D d8
> (vast/cloud finding -> hexa-lang/inbox/patches so `hexa cloud` absorbs upstream).

pool-host qforge BLOCKED by STALE generated artifacts after git pull. self/runtime.c + self/runtime_core.c + build/hexat(hexa_v2) are GITIGNORED generated files; git pull does NOT refresh them. Result on stale clones: (a) hexa run JIT compiles a STALE self/runtime.c that mismatches current source -> clang errors (undeclared hxlcl_longjmp/hxlcl_backtrace_symbols_fd; missing native/crypto_blowfish.c) on glibc-2.39/clang-18 linux; (b) stale build/hexat SEGV (Segmentation fault) transpiling multi-module qforge (metallic_a2f_selftest). FIX that worked on summer+aiden: install edge prebuilt (releases/edge/hexa-linux-x86_64.tar.gz) hexa + build/{hexat,hexa_module_loader,runtime.a}, and set HEXA_PREBUILT_RUNTIME=<repo>/build/runtime.a so JIT links prebuilt runtime.a (the .c-graduation seam) instead of recompiling stale self/runtime.c. REQUEST: hx install / a `hexa selfcheck`/pull-hook should refresh OR invalidate stale generated self/*.c + build/ transpiler on update, and `hexa run` should auto-prefer build/runtime.a when self/runtime.c is a stale/shim mismatch. Verified PASS: dfpt_selftest + metallic_a2f_selftest on both hosts.

---
source: sidecar handoff `ab8b16ff` (demiurge -> hexa-lang) · status: open (awaiting hexa-lang absorb)
