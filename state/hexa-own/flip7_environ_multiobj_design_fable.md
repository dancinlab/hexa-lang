All checks are complete — I have the full picture and the fix design. Here is the deliverable.

---

# FLIP-7 environ redirect gap — root cause + byte-neutral fix design

Worktree verified: HEAD `8b9f526e5` == `origin/main`, clean tree.

## TL;DR

The un-redirected `environ` read is **not in any emitter** — it's in the **OP-19e post-restore patch** at `tool/restore_frozen_seeds:1712-1715`. Its musl-safe capture ctor `hxlcl_capture_environ(void) { if (!hxlcl_environ) hxlcl_environ = environ; }` reads the **libc `environ` data symbol** (declared `extern char **environ;` *before* the `#define environ hxlcl_environ` shadow, deliberately, per its own comment). Since `restore_frozen_seeds` first re-synthesizes `runtime.c` from the emitter SSOT (`:109-164`) and **then always applies OP-19e** (the emitter output never carries the `OP-19e (HEXA-0POD` idempotence marker), every shipped `self/runtime.c` carries this ctor — so `build/runtime.o` (S2, `stage_resolve_runtime_a:3067`) has `U environ` under every config, including OWN_START=1. That is the exact symbol the S5.5 gate (`stage_resolve_runtime_a:3112`) caught. Fix = one edit in the OP-19e print block: compile the ctor out under `#ifndef HEXA_ZEROC_OWN_START`.

## 1. Which MULTIOBJ member, and why only this one

The S5.5 merge is `ld -r build/runtime.o build/runtime_core.o $_mo_hxlcl_members $extra_obj` (`:3095`). Per-member audit:

| Member | environ status |
|---|---|
| **runtime.o** ← `self/runtime.c` | **THE GAP.** OP-19e ctor reads libc `environ` → `U environ`. The #4631 alias/scaffold sits *after* the capture block (by the #4388 design) so the alias is exported fine — but an alias can't remove this TU's own libc-symbol *read*. |
| runtime_core.o ← `runtime_core_emit.hexa` | Clean — zero `environ` occurrences in the emitter and zero in any `_RTC`-targeted restore patch. |
| hxlcl_shim.o ← `runtime_core_hxlcl_shim_emit.hexa:114-126` | Done (#4631) — the `#define environ _hxlcl_environ` sits at TU head, covering all getenv/setenv walks and the `environ = na` store; its `U _hxlcl_environ` resolves against runtime.o's alias inside the merge. |
| extra_obj (rt_hi/array/map/… native .o) | Clean — hexa-native emit reaches env only via `hxlcl_getenv` *function* calls, never the `environ` data symbol. |
| Route C native getenv/setenv .o | Not present — `${HEXA_RT_NATIVE_GETENV:-0}`/setenv are opt-in default-OFF (`:2614`). See flag ③. |

**"Does the read exist in BOTH the emitter and the restore patch?" — No, restore-patch only.** The emitter's own capture block (`runtime_emit_full.hexa:62-67`) reads the **ctor-arg `envp`**, never the libc symbol — an emitter-form `runtime.c` produces no `U environ`. Only the OP-19e rewrite introduces the libc read. One edit covers everything, because `runtime_cuda_host.o` (`:3132`, `:3160`) compiles the *same* patched `runtime.c` with `$_zc_own_def` flowing in.

## 2. Mechanism confirmation

Confirmed as you designed it: `runtime_emit_full.hexa:83` emits `extern char **_hxlcl_environ __attribute__((alias("hxlcl_environ")));` inside the `#ifdef HEXA_ZEROC_OWN_START` scaffold, and own `_start` → `_hx_start_c` writes `hxlcl_environ = envp` **before** `_hx_run_init_array` (`:96-97`). So under OWN_START the capture ctor is dead weight at runtime (its `if (!hxlcl_environ)` guard never fires) — but its libc-`environ` load exists in the object code regardless, and under `-nostartfiles` nothing provides that symbol. The ctor must be compiled out, not merely idempotent.

## 3. The byte-neutral fix (exact edit)

**File: `tool/restore_frozen_seeds`, OP-19e awk block.** Replace lines 1714-1715:

```awk
      print "__attribute__((constructor(101)))"
      print "static void hxlcl_capture_environ(void) { if (!hxlcl_environ) hxlcl_environ = environ; }"
```

with:

```awk
      print "// FLIP-7 own-start (#29): under HEXA_ZEROC_OWN_START the own _start writes"
      print "// hxlcl_environ before init_array and -nostartfiles never provides the libc"
      print "// `environ` cell — this ctor READ was the runtime.o `U environ` that tripped"
      print "// the S5.5 own-start nm-clean gate, so the capture ctor is libc-start-only."
      print "#ifndef HEXA_ZEROC_OWN_START"
      print "__attribute__((constructor(101)))"
      print "static void hxlcl_capture_environ(void) { if (!hxlcl_environ) hxlcl_environ = environ; }"
      print "#endif"
```

Keep `print "extern char **environ;"` (:1712) unconditional — a declaration with no surviving use emits no reloc, and keeping it minimizes the diff. No other file changes: the shim (#4631) and the amalgam alias are already correct, and `runtime_core_emit.hexa` has nothing to redirect.

## 4. Anchor-safety argument

- The OP-19e awk **match** anchor `/^static char \*\*hxlcl_environ = 0;$/` and **skip terminator** `/^#define environ hxlcl_environ$/` operate on the awk's *input* (the emitter-synthesized runtime.c, untouched by this fix). The edit changes only the *printed replacement payload* — the anchored 6-line window in the emitter output is not wrapped, shifted, or split, so the #4388/#4625 trap is avoided by construction.
- The `static char **hxlcl_environ = 0;` line is still printed verbatim (:1713 untouched) and the `OP-19e (HEXA-0POD` idempotence marker is still printed (:1705 untouched), so a double restore still no-ops. The emitter still never emits the marker substring.
- **`tool/musl_ctor_abi_gate.sh` stays GREEN**: it extracts all non-`//` `print "..."` payloads and asserts (1) the exact `hxlcl_capture_environ(void) { … = environ; }` line is present — unchanged verbatim; (2) no `hxlcl_capture_environ(int` / `hxlcl_environ = envp` — none introduced. The new `#ifndef`/`#endif` payloads match neither pattern, and the four explanatory lines are `//`-comments, which the gate drops from its C surface.

**Byte-neutrality (default OFF):** with `HEXA_ZEROC_OWN_START` undefined, the `#ifndef` branch is always taken → the preprocessed token stream of runtime.c is identical; only line numbers shift, and the emitter payload contains zero `__LINE__`/`assert(` uses (measured: 0), matching the #4631/#4652 precedent where scaffold-line insertion into these same TUs kept byteeq 3-target GREEN. S5.5 itself is inert when `$_zc_own_def` is empty.

## 5. Verify / re-gate plan (pool, not mini)

1. `bash tool/restore_frozen_seeds` → confirm the patched block: `sed -n '/OP-19e (HEXA-0POD/,/#define environ hxlcl_environ/p' self/runtime.c` shows the `#ifndef` around the ctor.
2. `bash tool/musl_ctor_abi_gate.sh` → PASS (both assertions).
3. Targeted nm proof on aiden/summer: `HEXA_ZEROC_OWN_START=1 HEXA_RT_MULTIOBJ=1` through `stage_resolve_runtime_a` → S5.5 prints **OWN-START nm-clean GREEN**; directly, `nm -u build/runtime.o | grep -cw environ` → **0** with OWN_START=1 and → **1** with it unset (musl path intact — the libc read must *remain* in the default build).
4. CUDA arm (same TU, not covered by S5.5): `nm -u build/runtime_cuda_host.o | grep -cw environ` → 0 under OWN_START=1.
5. Default byte-neutrality: rebuild the default (OWN_START unset) `runtime.a` before/after → `cmp` identical, then regular PR CI byteeq 3-target GREEN.
6. Re-run flip-D (#4656) — S5.5 was the only environ-class blocker; atexit/`__dso_handle` were already clean.

## Flags

1. **No dual-path fix needed** — the emitter's capture block is envp-based and clean; only the restore patch reads libc `environ`. (The two build paths converge: CI always goes through restore, so the shipped runtime.c is always the OP-19e form.)
2. **Do not "fix" this by removing the extern or the ctor unconditionally** — the default (libc-start) build *needs* the POSIX-`environ` read on musl (`musl_ctor_abi_gate` enforces exactly that).
3. **Future interaction to note in the PR**: `HEXA_RT_NATIVE_GETENV`/`SETENV` Route C members carry a *native* `environ@GOTPCREL` reloc (`stage_resolve_runtime_a:2598`) that no `#define` can redirect. That combo (opt-in, default-OFF today) will re-trip S5.5 the moment it meets OWN_START=1; the fix there is different — retarget `__hx_environ_ptr` (or `objcopy --redefine-sym environ=_hxlcl_environ` on the isolated .o) — separate finding, correctly deferred.