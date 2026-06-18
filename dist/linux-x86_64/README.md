# hexa_v2 — Linux x86_64 pre-built binary

Cross-compiled from `self/native/hexa_cc.c` on macOS ARM64 via zig cc.
Static musl link — no glibc dependency, runs on Linux kernels ≥ 2.6.32.

## Artifact

- **Path**: `dist/linux-x86_64/hexa_v2`
- **Format**: ELF 64-bit LSB, x86-64, statically linked, stripped=no
- **SHA-256**: `3ff995fc8b68e3a5b9e46a803a269e03204ff0b439a668a6dfadc58acc01d496`
- **Built**: 2026-04-23
- **Source commit**: see `git log -1 dist/linux-x86_64/hexa_v2`

## Rebuild recipe

> **CORRECTION (ING #2, 2026-06-19):** the old recipe compiled ONLY
> `self/native/hexa_cc.c`, which `#include "runtime.h"` (prototypes only) — it
> linked with `undefined reference to hexa_str` (the runtime *definitions* live in
> `self/runtime.c`). The runtime SOURCE must be in the link line. Also the frozen
> `self/runtime.c` seed must first be made musl-portable: run
> `bash tool/restore_frozen_seeds` (its ING #2 patch hoists the POSIX system
> headers above the libc-override macro block + guards `<linux/sched.h>`), which
> is what produces the seed on a `.c=0` checkout anyway.

```
# 0. restore + musl-patch the frozen runtime seed (no-op if already present)
bash tool/restore_frozen_seeds

# 1. static-musl link — runtime.c (definitions) + hexa_cc.c (transpiler + main)
x86_64-linux-musl-gcc -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs \
       -I self \
       self/runtime.c self/native/hexa_cc.c \
       -o dist/linux-x86_64/hexa_v2 -static -lm
```

Verify: `ldd dist/linux-x86_64/hexa_v2` → "not a dynamic executable".

`zig cc -target x86_64-linux-musl …` works as a drop-in for the compiler if a
musl cross-gcc is unavailable (add `self/runtime.c` to its link line too).

For the FULL `./hexa` self-host driver (not just the stage0 transpiler), the
release pipeline builds it static-musl via:

```
unset HEXA_PREBUILT_RUNTIME    # link runtime from SOURCE, not the glibc runtime.a
TARGET=linux-x86_64-musl CC=x86_64-linux-musl-gcc LIBS="-static -lm" \
  bash tool/release_build && \
TARGET=linux-x86_64-musl CC=x86_64-linux-musl-gcc LIBS="-static -lm" \
  bash tool/release_package
# → hexa-linux-x86_64-musl.tar.gz  (statically-linked ./hexa + build/ + precompile/)
```

## Usage on Linux pod

```
./dist/linux-x86_64/hexa_v2 path/to/source.hexa path/to/out.c
```

This is the **stage0 transpiler** — takes `.hexa` input, emits `.c` for clang.
Not to be confused with the `./hexa` wrapper which is a shell script driver.

## Unblocks

- `nxs-20260422-006` (nexus) — Linux pod 'Exec format error'
- `agm-20260422-003` (airgenome)
- `agm-20260422-006` (airgenome) — resource_gap prio 95
- `anima-20260422-003` (anima)

## Rebuild automation

See `tool/build_linux_x86_64.hexa` for scripted rebuild + sha verify.
