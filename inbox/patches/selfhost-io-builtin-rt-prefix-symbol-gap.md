# selfhost codegen emits `_read_file_bytes` / `_read_bytes_at` but runtime exports `_rt_`-prefixed

**Found:** anima 303M engine-mount verification (2026-06-16), hexa `0.1.0-dispatch`
(`hexa.real` → `hx-selfhost-cli`), macOS arm64.

## Symptom

Any `.hexa` that calls the binary-IO builtins fails at JIT-exec with a dyld abort:

```
dyld[…]: Symbol not found: _read_file_bytes
  Referenced from: …/.hexa-cache/hexa_run.<hash>_0.1.0-dispatch
  Expected in:     /usr/lib/libSystem.B.dylib
```

Same for `_read_bytes_at`. The JIT artifact is a standalone MH_EXECUTE (TWOLEVEL,
links only `libSystem.B.dylib`) and records the builtin as an *undefined symbol
expected from libSystem* — so flat-namespace `DYLD_INSERT_LIBRARIES` does not
override it (two-level binding pins the lookup to libSystem).

## Root cause

The self-host codegen emits a call to the **un-prefixed** symbol `_read_file_bytes`
(and `_read_bytes_at`), but the runtime (`packages/hexa/self/runtime_core.c`, linked
via `~/.hx/self/native/selfhost/rt.o` and `~/.hx/bin/build/runtime.a`) defines them
**`rt_`-prefixed**:

```
$ nm ~/.hx/self/native/selfhost/rt.o | grep read_file_bytes
000000000000e500 T _rt_read_file_bytes        # runtime exports this
# codegen calls   _read_file_bytes            # …but emits this (no rt_)
```

`runtime_core.c:7218  HexaVal rt_read_file_bytes(HexaVal path)` /
`runtime_core.c:7249  HexaVal rt_read_bytes_at(HexaVal, HexaVal, HexaVal)` —
identical signatures, just the name the codegen builtin-table maps to lost the
`rt_` prefix for these two IO builtins (other builtins resolve fine, so it is a
per-builtin table regression, not a global prefix change).

Every local `hexa` binary (active selfhost + all `hexa.real.*` pre-selfhost backups)
reproduces it because they share the codegen frontend. The `.hexa-cache` artifact is
also poisoned across binary swaps until cleared (`rm ~/.hexa-cache/hexa_run.*`).

## Fix (the proper one, compiler-side)

In the selfhost codegen builtin→symbol table, map `read_file_bytes`→`rt_read_file_bytes`
and `read_bytes_at`→`rt_read_bytes_at` (restore the `rt_` prefix these two lost), matching
how every other runtime builtin is emitted.

## Local workaround used (reversible)

Aliased the two symbols into the runtime object so the un-prefixed name resolves:

```c
// io_alias.c
typedef void* HexaVal;
extern HexaVal rt_read_file_bytes(HexaVal);
extern HexaVal rt_read_bytes_at(HexaVal, HexaVal, HexaVal);
HexaVal read_file_bytes(HexaVal p){ return rt_read_file_bytes(p); }
HexaVal read_bytes_at(HexaVal p, HexaVal o, HexaVal n){ return rt_read_bytes_at(p,o,n); }
```

```
cc -c io_alias.o io_alias.c
ld -r -o rt_patched.o ~/.hx/self/native/selfhost/rt.o io_alias.o
cp rt_patched.o ~/.hx/self/native/selfhost/rt.o   # backup kept
rm ~/.hexa-cache/hexa_run.*
```

After this, `read_file_bytes` works (verified: read the 1.2 GB ByteGPT-303M flat binary,
`len=1213440020`) and the full 24-layer `CORE/bytegpt_decode.hexa` mount runs byte-exact.

## Secondary bug (separate, not worked around)

`bytegpt_forward_last_ranged` / `read_bytes_at` **SIGSEGVs (exit 139)** on a small
partial slice read (`read_bytes_at(path, 0, 20)` → `_bg_rd_farr(slice, 0, n)`), even
after the symbol alias above. The whole-file `bg_load` path is unaffected and is what
the 303M mount uses. The ranged reader needs its own fix (likely the partial-slice
HexaVal byte-array bounds). Cross-ref the existing `read-f32-at-native-ranged-reader.md`
and `read-file-bytes-64bit-overflow-4gb.md` inbox patches.
