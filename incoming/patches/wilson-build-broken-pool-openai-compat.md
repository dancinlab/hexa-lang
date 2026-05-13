# `hexa build core/main.hexa` broken on wilson HEAD: pool + openai-compat codegen errors

**Filed by:** wilson (`~/core/wilson`).
**Date:** 2026-05-13.
**Severity:** wilson can't ship — even the unmodified `git checkout main` HEAD fails to
produce a binary. Per-host build was OK as recently as the `f34c655 / 68bf943` commits;
broke after `177b4a3 provider-openai-compat` + `de4f342 plugins/pool v0.5`.

## Symptoms

Two distinct clang errors in the flattened `build/artifacts/wilson.c`:

### (1) `float` builtin used as a function reference

```
build/artifacts/wilson.c:17159:39: error: expected expression
    return __hexa_fn_arena_return(hexa_call1(float, hexa_index_get(opts, __hexa_sl_1131)));
                                              ^^^^^
```

Source: `plugins/provider-openai-compat/main.hexa`'s `provider_openai_compat_temp_of`
calls `float(opts["temp"])` to coerce a config value. The codegen emits
`hexa_call1(float, …)` — but `float` here should be the builtin scalar coercion, not a
runtime function reference. Same shape as the previous `getenv` regression
(`~/core/hexa-lang/incoming/patches/wilson-shift-tab-csi-Z-decode.md` neighbours).

### (2) Unresolved `pool_invoke_propose` / `pool_invoke_propose_list` / `pool_cmd_pool`

```
build/artifacts/wilson.c:22713:50: error: use of undeclared identifier 'pool_invoke_propose'
build/artifacts/wilson.c:22716:50: error: use of undeclared identifier 'pool_invoke_propose_list'
build/artifacts/wilson.c:23281:50: error: use of undeclared identifier 'pool_cmd_pool'
```

`plugins/pool/main.hexa` defines all three as `pub fn`/`fn` at lines 679, 734, 785.
They're referenced from the same file at lines 186, 187 and from
`plugins/pool/plugin.hexa:98`. The flatten apparently doesn't carry these symbols
into the emitted C — they appear in the dispatch table call sites without ever being
declared above. Forward references that the flatten ordering doesn't resolve, perhaps.

## Reproduce

```sh
cd ~/core/wilson
git checkout main
export HEXA_LANG=~/core/hexa-lang HEXA_SHIM_NO_DARWIN_LANDING=1
~/.hx/bin/hexa parse plugins/pool/main.hexa            # OK
~/.hx/bin/hexa parse plugins/provider-openai-compat/main.hexa   # OK
~/.hx/bin/hexa build core/main.hexa -o build/Darwin-arm64/wilson
# → 4 errors generated, binary not produced.
```

The parser is clean — the failure is purely in the C codegen / flatten output.

## What wilson has done so far

- Confirmed clean `git checkout main` (no working-tree edits) reproduces both errors.
- Confirmed it's not the wilson session's edits — every harness-cli/main.hexa edit
  this session reproduces the same provider/pool symbols at slightly shifted line
  numbers because the flatten pass uses positional ordering.
- Stash + checkout + build cycle: error persists at HEAD.

Per `~/core/wilson/CLAUDE.md` §Session-protocol "Don't fix hexa-lang from wilson",
filing here and stopping. wilson's harness-cli session edits (perm-mode merge logic,
queue visualisation, `/colors` slash + CLI subcommand, prefix_lines echo) are
parse-clean and **logically correct**; they just won't ship until either:
  (a) the codegen handles `float(...)` builtin as a builtin again, AND
  (b) the flatten resolves `pool_invoke_propose`-shape forward refs.

Workaround that wilson can apply locally if upstream is slow: rename
`pool_invoke_propose` → something the flatten can resolve, and replace `float(x)`
with `to_float(x)` (if `to_float` survives codegen better). Not done yet — wanted
to file the upstream report first.

## Related

- The earlier `getenv` codegen regression (`incoming/patches/wilson-shift-tab-csi-Z-decode.md`
  is unrelated, but during the same session I observed `getenv` being miscompiled
  the same way as `float` is here — symbol resolution treating a builtin as a
  runtime HexaVal function ref). The pattern recurs.
