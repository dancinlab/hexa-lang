#!/usr/bin/env bash
# zeroc_dropon_ztrace_run.sh — RFC061 drop-ON map-coherence PROBE (measure-only).
#
# Rebuild a CLEAN baseline (non-M7) program.o + stub via tool/zeroc_dropon_fixpoint.sh,
# then relink with an INSTRUMENTED runtime_core.o (tool/zeroc_dropon_ztrace_instr.py
# injects ZSET/ZGET/ZMISS counters into hexa_struct_pack_map INSERT + hmap_find
# LOOKUP), and run `exit42` emit under ZTRACE=1 to trace where map keys miss.
#
# Instrumentation touches ONLY the gitignored regen self/runtime_core.c (restored
# at the end); the frozen blob 151c52c8 self/runtime.c is NEVER touched.
#
# MEASURED VERDICT (aiden x86_64, this round): the "cross-TU map-coherence /
# sets=0" wall is FALSIFIED — ZSET=315573, ZGET=121394, ZMISS=6. INSERT runs at
# full volume; hexa_fnv1a_str("severity")=2415677362 is byte-identical SET vs GET;
# the only misses are 3 keys (severity/code/span) on ONE table (0x..9740, cap=16)
# that has `kind` (a FixIt/Severity carrier mis-routed to the Diagnostic renderer)
# — a single value-confusion, NOT a descriptor escape. INSERT/LOOKUP already
# co-locate in runtime_core.o (nm + ld --trace-symbol), so map-INSERT-arm routing
# (lever-a) is a no-op. Run on a host with build/hexat + tool/zeroc_dropon_fixpoint.sh.
set -uo pipefail
cd ~/hexa-lang
O=/tmp/zeroc_dropon

# (a) regenerate a clean baseline drop-ON build (non-M7) so program.o + stub are consistent.
SIMULATE_M7=0 bash tool/zeroc_dropon_fixpoint.sh >/tmp/zt_base.log 2>&1
echo "baseline exit42 RC line: $(grep 'exit42 emit RC' /tmp/zt_base.log)"
echo "baseline RUNNABLE: $(grep DROPON_RUNNABLE /tmp/zt_base.log)"

RC=self/runtime_core.c
cp "$RC" /tmp/rc_clean.c   # canonical-ok throwaway probe snapshot
python3 /tmp/zt_instr.py "$RC"

CLUSTER_DEFS="-DHEXA_RT_CORE_LEAF_NATIVE=1 -DHEXA_RT_CORE_ARITH_NATIVE=1 -DHEXA_RT_CORE_MATH_NATIVE=1 -DHEXA_RT_CORE_MATH2_NATIVE=1 -DHEXA_RT_CORE_MAP_QUERY_FOLD_NATIVE=1 -DHEXA_RT_CORE_COLLECTION_MUTATE_NATIVE=1 -DHEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE=1 -DHEXA_RT_CORE_FS_READ_WRITE_NATIVE=1 -DHEXA_RT_CORE_ARITH_COERCE_FORMAT_NATIVE=1 -DHEXA_RT_CORE_RUNTIME_MISC_NATIVE=1 -DHEXA_RT_CORE_VALOP_DISPATCH_NATIVE=1 -DHEXA_RT_CORE_MAP_QUERY_DISPATCH_NATIVE=1 -DHEXA_RT_CORE_STRARR_READ_NATIVE=1 -DHEXA_ZEROC_RT_CORE_STRBUF_ARENA=1"
DROP_DEFS="-DHEXA_ZEROC_DROP_RTCORE_INCLUDE -DHEXA_ZEROC_DROP_RTCORE $CLUSTER_DEFS -DHEXA_RT_ALLOC_NATIVE=1"
CFLAGS="-c -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -I self -I ."
clang $CFLAGS -DHEXA_HAS_HEXA_RT_STDLIB=1 $DROP_DEFS -include self/runtime_core_sysheaders.h "$RC" -o "$O/runtime_core_zt.o" 2>/tmp/zt_cc.err
echo "runtime_core_zt.o RC=$? errors=$(grep -c error: /tmp/zt_cc.err||echo 0)"; grep error: /tmp/zt_cc.err|head -4

SEEDS=$(ls build/*.o 2>/dev/null | grep -vE '(^|/)(runtime|runtime_dropON|runtime_core)\.o$|rt_hi_native\.o' | tr '\n' ' ')
clang -O2 "$O/program.o" "$O/runtime_core_zt.o" "$O/hxlcl_shim.o" "$O/init_fn_shims_stub.o" $SEEDS -o "$O/aprime_zt" -lm -lc -ldl -lpthread 2>/tmp/zt_link.err
echo "link RC=$? undef=$(grep -c undefined /tmp/zt_link.err) multidef=$(grep -c 'multiple def' /tmp/zt_link.err)"
[ -x "$O/aprime_zt" ] || { grep -iE 'undefined|multiple' /tmp/zt_link.err | head -8; cp /tmp/rc_clean.c "$RC"; exit 1; }

printf 'fn main() {\n  exit(6 * 7)\n}\n' > "$O/e42.hexa"
ZTRACE=1 "$O/aprime_zt" _drv.hexa --emit=asm --target=x86_64-linux-gnu -o "$O/e42zt.s" "$O/e42.hexa" 2>/tmp/zt_run.err
echo "instrumented emit RC=$?"
echo "===== SET events for diag keys ====="
grep -E 'ZSET key=(severity|code|span|file|line|col|len)$' /tmp/zt_run.err | head -20
echo "===== GET events for diag keys ====="
grep -E 'ZGET key=(severity|code|span|file|line|col|len)$' /tmp/zt_run.err | head -20
echo "===== MISS events for diag keys ====="
grep -E 'ZMISS key=(severity|code|span|file|line|col|len) ' /tmp/zt_run.err | head -20
echo "===== ALL severity events (set+get+miss, with tbl ptr) ====="
grep -E 'key=severity\b' /tmp/zt_run.err | head -10
echo "===== global totals ====="
echo "total ZSET=$(grep -c '^ZSET' /tmp/zt_run.err) ZGET=$(grep -c '^ZGET' /tmp/zt_run.err) ZMISS=$(grep -c '^ZMISS' /tmp/zt_run.err)"
cp /tmp/rc_clean.c "$RC"
echo "restored clean runtime_core.c"
