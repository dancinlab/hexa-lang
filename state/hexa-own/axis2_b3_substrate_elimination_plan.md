
## A0 round-1 — array_core PROVEN (summer ON-path, 2026-07-12)

First family landed + verified. `resolve_native_array_core_seed` HEXA_RT_OWNOBJ branch (feat/axis2-b3-a0-ownobj,
default-OFF): with `HEXA_RT_OWNOBJ=1 HEXA_OWNOBJ_CC=<aprime>`, `stage_resolve_runtime_a` produced
`build/array_core_native.o` by own-emitting `stdlib/runtime/array_core.hexa` (`--backend=native --emit=obj
--target=x86_64-linux-gnu`) — **6/6 rt_array_*_native contract syms**, 4736B, ar'd into runtime.a, **no $CC
assemble**. Log: `B3-A0 OWN-OBJ: array_core via …aprime_cc --emit=obj (6/6 rt_array_*_native, TARGET=linux-
x86_64) → native element path`. So the A0 build-path swap works: the runtime member is now own-emit, not
`.s`+`$CC`. Default (flag-unset) path byte-identical (branch skipped). **Continuation**: replicate the
branch for the other 9 own-emit-GREEN families (map/intern/str/num/num_float/float_parse_exact/hexinfnan/
regex/valop — ideally refactored to one `_b3a0_ownobj_seed <fam> <src> <contract> <n>` helper), build
`tool/ownobj_member_parity_gate` (nm defined-global equality + RUN parity vs the `.s` seed), then the
`:-0`→`:-auto` flip PR after byteeq 3-target + install smoke.
