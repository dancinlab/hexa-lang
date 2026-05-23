# `pool.hexa` transpile fail — `ks`/`i` undeclared in generated C (line 707) — pool CLI 전체 사용 불가

**Reporter**: demiurge (RTSC N5 funnel cycle 12 · 2026-05-24)
**Severity**: high (pool CLI completely broken — all `pool on <host> …` invocations fail with hexa build error before any remote dispatch attempt)
**Affected**: `~/.hx/packages/pool/bin/pool.hexa` (rebuilt 2026-05-24 06:56) → hexa-lang transpiler regression
**Trigger**: any `pool on <host> <cmd>` invocation (sees the build retry per call via hexa run dispatch)

## TL;DR

`pool` CLI compile fails consistently. The transpiler emits C that references identifiers `ks` and `i` outside their declaring scope — a closure / lambda binding regression. User has no working `pool on <host> …` path; campaign falls back to direct `ssh ubu-2` (g9 emergency workaround).

## Reproduction

```
$ pool on ubu-2 "uptime"
error: `hexa build /Users/ghost/.hx/packages/pool/bin/pool.hexa` failed (compile error).
…
build/.../hexa_run.661f21fa457a6af7_0.1.0-dispatch.tmp.…tmp.c:707:54:
  error: use of undeclared identifier 'ks'
  return __hexa_fn_arena_return(hexa_index_get(ks, i));
                                               ^~
build/.../hexa_run.…:707:58: error: use of undeclared identifier 'i'
  return __hexa_fn_arena_return(hexa_index_get(ks, i));
                                                   ^
… (same error at lines 710, 720)
```

The `pool.hexa` source (visible around the same logical region, lines 700-725) is regular code (host-row formatting, no closure trick):

```
let row = _pad(name, nw) + "  " + flag + "  " + _pad(ssh, sw) + ...
println(row.trim())
```

— no `ks`/`i` in *source*. They appear only in the transpiled C output, which suggests the codegen is leaking inner-scope names from an iterator/closure transformation into a wrong return frame.

## Cross-references

- The exact same transpiler emits `hexa_index_get(ks, i)` in **3 places** (lines 707, 710, 720) — looks like a hoisted closure body referencing the parent iteration vars by name without arena rebinding.
- May relate to recent stdlib changes (commit `b18bbf57 domain(STDLIB)`, 2026-05-24) — bisection 후보.

## Impact on RTSC campaign

- RTSC N5 funnel cycle 12 (3 ambient-stable hydride DFT verification preparation) — agent a640a68 successfully prepared inputs but cannot fire because `pool on ubu-2 …` is broken.
- ubu-2 actually FREE (load 0.00, ph_222 + iter_A_Γ + B all finished or stopped) but unreachable via canonical pool route.
- Emergency: campaign uses direct `ssh ubu-2 …` (g9 violation, but the only path until pool builds).

## Suggested fixes (priority order)

### Fix 1 — root-cause the codegen regression (recommended)

The transpiler is emitting an inner-closure body that references `ks` and `i` as if they were in the enclosing scope. Two candidates:

- `let (key, value) in some_map { … }` or similar iteration desugaring that names the parent's iterator inside an emitted helper function but doesn't pass them as arena-bound captures.
- `array.index(...)` callback codegen that synthesizes a function but loses the closure environment.

Bisect against `b18bbf57` (latest STDLIB-domain commit on hexa-lang main) and earlier closure / iteration codegen changes.

### Fix 2 — `pool.hexa` rewrite to avoid the broken codegen path

If the regression is too deep, rewrite the affected region of `pool.hexa` (around the host-row formatting loop) to not trigger whatever idiom emits the broken closure. e.g. expand `let _pad(ld, lw) + ... + _pad(dk, dw)` into explicit intermediate variables.

### Fix 3 — emergency workaround documented

If neither fix lands fast, document the `ssh <host> …` fallback explicitly in `pool --help` and in `commons.tape g9` so downstream agents don't waste tool turns on the workaround discovery.

## Status

- [x] Bug surfaced + reproduced in current state
- [ ] Bisect `b18bbf57` ↔ working version (whoever has the previous-build `pool` binary cached)
- [ ] Codegen fix in self/ transpiler
- [ ] `pool.hexa` rebuild + smoke test
- [ ] Document `ssh` workaround in g9 until fix lands
