#!/usr/bin/env bash
# RT-NATIVE dual-config compile gate — the regression safety net for leg B
# (incremental C-body → hexa-source porting). Every fn-port must keep BOTH
# runtime.c build configs compiling on this Mac (Darwin arm64), locally:
#   • active     = -DHEXA_HAS_HEXA_RT_STDLIB=1 (the build_aprime config:
#                  hexa-source rt_* delegation active)
#   • standalone = no -D (the C #else bodies; cross_build_runtime_linux_arm64
#                  / selfhost_crossemit_smoke link path)
# A fn-port that breaks EITHER config is a leg-B regression. This lets the
# port loop run the gate per-fn locally WITHOUT a linux cross-build for the
# common case (full cross byte-eq still needs the linux gate / pod).
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
RT="self/runtime.c"
fail=0
echo "── RT-NATIVE dual-config gate ($RT) ───────────────────"
clang -c -DHEXA_HAS_HEXA_RT_STDLIB=1 "$RT" -o /tmp/_rt_active.o 2>/tmp/_rt_active.err
if [ -f /tmp/_rt_active.o ]; then echo "  active     : OK ($(stat -f%z /tmp/_rt_active.o)B)"; else echo "  active     : FAIL"; grep -i error: /tmp/_rt_active.err | head -3; fail=1; fi
clang -c "$RT" -o /tmp/_rt_standalone.o 2>/tmp/_rt_standalone.err
if [ -f /tmp/_rt_standalone.o ]; then echo "  standalone : OK ($(stat -f%z /tmp/_rt_standalone.o)B)"; else echo "  standalone : FAIL"; grep -i error: /tmp/_rt_standalone.err | head -3; fail=1; fi
echo "───────────────────────────────────────────────────────"
[ $fail -eq 0 ] && echo "✅ dual-config gate PASS — both build configs compile" || echo "❌ dual-config gate FAIL"
exit $fail
