# heapify frame-clean agg-gate — byteeq + perf verdict

**Branch:** `perf/heapify-frameclean-agg-gate` (PR #3939) · HEAD `7131bdd6`
**Macro:** `HEXA_RT_HEAPIFY_AGG_GATE` (opt-in C macro, default-OFF) — extends the
`hexa_arena_frame_clean()` short-circuit to the top-level `TAG_ARRAY` / `TAG_MAP`
cases of `hexa_val_heapify` (emitted from `self/runtime_core_emit.hexa`).
**Host:** summer (summer-B650M-K · x86_64 · gcc 13.3.0 · 12c/30G), isolated checkout
`~/heapify-verify-run/repo` (now removed). Build: `tool/build_native_linux_x86_64`.
**Date:** 2026-06-25

---

## VERDICT: UNSOUND — REJECT PR #3939's gate

The flag-ON compiler **deterministically SIGSEGVs (signal 11, rc 139)** during its own
self-emit, inside `hexa_val_heapify` itself. The frame-clean invariant the gate relies on
("frame clean ⟹ all top-level array/map children provably heap, skip the O(N) walk") is
**FALSE** for the compiler's self-emit value graph: skipping the walk leaves an
arena-resident / dangling element that a later recursive `hexa_val_heapify` dereferences
→ crash. The gate skipped a walk that mattered.

This is the falsified outcome. The byte-neutrality question is moot — the ON path crashes
before producing any object file, so there is no `cc-self-on.o` to compare. **Keep the gate
OFF; do not flip default; the optimization as written cannot ship even as opt-in (enabling
it crashes the compiler).**

---

## The three numbers (loop-closing evidence)

| | flag-OFF (baseline) | flag-ON (gate) |
|---|---|---|
| self-emit wall | **22:07.65** (1327.65 s) | **CRASH @ 0:02.60** (SIGSEGV) |
| peak RSS (`/usr/bin/time -v`) | 12,707,616 KB (~12.7 GB) | 846,424 KB (crashed early) |
| self-emit RC | 0 | **139 (signal 11)** — reproduced 2× + gdb |
| encode-miss | 0 | n/a (no codegen reached) |
| `cc-self.o` produced | yes, 4,797,136 B | **NONE** |
| `cc_native` binary built | yes (3,855,720 B, stage5 PASS hi/rc7) | yes (3,855,720 B, stage5 PASS hi/rc7) |

### SHAs (16-hex)
- **cc-self-off.o** (OFF, full emit): `20a909f50b51b70c…`
  (full `20a909f50b51b70c62c7499f11bb77357b9827a649c2a2e32c5bc633d4df8dd4`)
- **cc-self-on.o** (ON): **does not exist — SIGSEGV before output.**
- SHA-equal? **N/A — flag-ON produced no object file (crash).** ⇒ cannot claim byte-neutral.

### Gate-is-active proof (the ON binary really differs)
- `cc_native` OFF sha256 `e2c3ad3c65bf9973…` vs ON `4ce29e76fe324d6c…` — **DIFFER** ⇒
  `-DHEXA_RT_HEAPIFY_AGG_GATE` genuinely compiled the `#ifdef` branch into the ON binary
  (emitter ran: generated `runtime_core.c` carried the `#ifdef HEXA_RT_HEAPIFY_AGG_GATE`
  guard; macro appended to `GCC_FLAGS` in stage4).

### gdb backtrace of the crash (root cause)
```
Program received signal SIGSEGV, Segmentation fault.
0x…dc3 in hexa_val_heapify ()    # rip = hexa_val_heapify+83
#0  hexa_val_heapify ()
#1  hexa_val_heapify ()
…  (entire stack = recursive hexa_val_heapify frames)
```
Crash is *inside* `hexa_val_heapify` — the skipped top-level walk left a non-heap
element that a nested heapify recursion dereferenced.

### gen3≡gen4
Not evaluated — would require the OFF/ON `cc-self.o` to link into a gen and re-emit; the ON
side never produces a `.o`. The OFF baseline alone (`encode-miss=0`, rc 0) is the only
clean emit. gen3==gen4 is therefore **inconclusive for ON (no artifact)** and not needed to
reach the verdict: a crash is a stronger rejection than a byte diff.

---

## Notes / recipe caveats
- `tool/build_native_linux_x86_64` stage4 link needed `build/runtime.a` appended (provides
  the native-seed `rt_*_native` bodies — `rt_array_truncate_native`, `rt_str_split`, etc. —
  that the `HEXA_HAS_HEXA_RT_STDLIB=1` extern path requires; the single-TU compile alone left
  them undefined). This is a build-invocation fix only (same native bodies stage5 already
  links for the `hi` smoke); it does not affect compiler semantics. Applied identically to
  both OFF and ON, so the OFF/ON comparison is apples-to-apples.
- The OFF self-emit is genuinely ~22 min / ~12.7 GB RSS — consistent with the prior
  profiling that put `hexa_val_heapify` at 94.79% self-time. The hotspot is real; the
  proposed short-circuit is just unsound.

**One line:** PR #3939's `HEXA_RT_HEAPIFY_AGG_GATE` is UNSOUND — flag-ON segfaults inside
`hexa_val_heapify` during self-emit (rc 139, reproduced, gdb-confirmed); the top-level
TAG_ARRAY/TAG_MAP frame-clean short-circuit skips a required walk. REJECT.
