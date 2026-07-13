<!-- axis-② unit #6 hexa_array_new spec · Fable bselak675 · 2026-07-13 -->

Spec complete and saved to `state/hexa-own/axis2_array_new_spec.md` (105 lines). The full 5-section spec is in my message above; the headline decisions:

1. **Stats bump: DROP** — the counter is a static, debug-only instrument behind `_hx_stats_on()` (OFF by default), read only by a stderr stats dump; it never feeds emitted bytes, so gen3≡gen4 byteeq is unaffected by construction. Parity-delta note recorded in the spec, same accepted class as the zeros/i64/f64 seeds' dropped OOM `fprintf` richness.
2. **Seed** — new file `stdlib/runtime/array_new_leaf.hexa`, 3-line body (`calloc(1,32)` → `__hx_make_val(5, a)` → `return out`), extern block minimal (`calloc` only). Zero-arg is trivially pair-clean.
3. **Guard** — fold/introduce `HEXA_RT_CORE_ARRAY_NEW_NATIVE` sub-guard at the ~L2734 body; proto at ~L1122 stays unconditional; mandatory pre-flip grep for a second unconditional body (the arr-f64 duplicate-body lesson).
4. **Wiring** — all names fixed as proposed (`resolve_native_array_new_seed`, `rt_arr_new_def`, `build/array_new_leaf_native.o`, 3-target frozen `.s`, regen script); KG NSYMS=1 confirmed, U-floor `{calloc}` + tolerated `hexa_exit`.
5. **Staging** — PR-1 guard-OFF byte-neutral → PR-2 pool `.s` regen + flip. **Wall-free confirmed**; the stats bump was the only novelty and it's resolved.