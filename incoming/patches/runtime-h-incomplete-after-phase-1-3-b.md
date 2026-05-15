# `runtime.h` missing symbols after PHASE 1.3.B → wilson uncompilable

**Layer:** codegen / runtime header (compile-speed track)
**Related:** commit `0813f4e` (`feat(runtime.h): PHASE 1.2.A — grow header to compile-cover hexa_cc.c`) and codegen commit on `codegen_c2.hexa:679` (`PHASE 1.3.B (2026-05-15) — emit #include "runtime.h"`)

## Symptom

After `2026-05-15` codegen change (`#include "runtime.c"` → `#include "runtime.h"`),
wilson's user.c references several `static inline` runtime symbols that exist in
`self/runtime.c` but were **not** promoted into `self/runtime.h`. Build fails with
20+ identical `call to undeclared function` errors before clang stops at the limit:

```
build/artifacts/wilson.c:10647:31: error: call to undeclared function 'hexa_call1' …
build/artifacts/wilson.c:10712:47: error: call to undeclared function 'hexa_fn_new' …
build/artifacts/wilson.c:10913: 5: error: call to undeclared function 'hexa_array_pop' …
build/artifacts/wilson.c:10950:31: error: call to undeclared function 'hexa_map_contains_key' …
build/artifacts/wilson.c:10950:98: error: call to undeclared function 'hexa_to_cstring' …
fatal error: too many errors emitted, stopping now
```

Codegen-emitted snippet that breaks:

```c
HexaVal sort_by(HexaVal xs, HexaVal key_fn) {
    …
    hexa_array_push(keys, hexa_call1(key_fn, hexa_index_get(xs, i)));   // ← undecl
    …
}

HexaVal sort_asc(HexaVal xs) {
    return __hexa_fn_arena_return(sort_by(xs, hexa_fn_new((void*)_identity, 0)));  // ← undecl
}
```

The functions DO exist as `static inline` in `runtime.c`:

```c
// runtime.c:1130
static inline HexaVal hexa_fn_new(void* fn_ptr, int arity) { … }

// runtime.c:1162-1182
static inline HexaVal hexa_call1_hv(HexaVal f, HexaVal a1) { … }
#define hexa_call1(f, a1) _Generic((f), …)
```

…but `runtime.h` doesn't expose them. So user.c that includes only `runtime.h`
(per the PHASE 1.3.B codegen change) can't link.

## Affected codegen paths

Any `.hexa` program that uses one of these stdlib primitives transitively:

| Symbol                | Used by                                | wilson usage             |
|-----------------------|----------------------------------------|--------------------------|
| `hexa_call1`          | `sort_by` / `sort_desc_by` (via key fn) | `core/event_bus.hexa::_sort_by_priority_desc` |
| `hexa_fn_new`         | `sort_asc` / `sort_desc` (identity)    | indirect via stdlib/sort |
| `hexa_array_pop`      | event_bus frame stack                  | `core/event_bus.hexa` (fold pop) |
| `hexa_map_contains_key` + `hexa_to_cstring` | `_is_deny` / `_is_replace` / `_is_err_envelope` | `core/agent_loop.hexa` policy helpers |

So **anyone using stdlib/sort or event-bus folds** hits this on first compile
after pulling current `main`. Wilson is uncompilable in the new compile-fast
path until runtime.h re-exports these.

## Workaround (wilson, 2026-05-15)

```sh
sed -i.bak 's|#include "runtime.h"|#include "runtime.c"|' build/artifacts/wilson.c
clang -O2 … build/artifacts/wilson.c -o build/Darwin-arm64/wilson …
```

Re-targets clang at the full `runtime.c` (the OLD include path), which has all
the static inline definitions in scope. ~8× slower compile (per COMPILE-SPEED
track) but compiles. Wilson's `bin/wilson` launcher could thread an env var
(`HEXA_USE_RUNTIME_C=1`) to do this automatically until upstream lands the fix.

## Required upstream fix

Either:

1. **Promote the missing inlines into `runtime.h`**, in dependency order, so
   user.c that includes only `runtime.h` can resolve everything codegen emits.
   The full list (clang-error-driven discovery — there may be more after the
   first 20 fail):
   - `hexa_call1` (and `_Generic` dispatch helpers it depends on:
     `hexa_call1_hv`, `__hexa_call1_fp1`)
   - `hexa_fn_new`
   - `hexa_array_pop`
   - `hexa_map_contains_key`
   - `hexa_to_cstring`

2. **OR add a codegen flag** (`HEXA_RUNTIME_INCLUDE`, `--legacy-runtime-c`, env
   `HEXA_FAST_RUNTIME=0`) that reverts the include to `runtime.c` when set.
   Downstream projects can opt out until their stdlib usage stops tripping
   missing symbols.

3. **OR fully transition to precompiled `runtime.o`**: ship a built
   `runtime.o`, document the link flag (`clang user.c runtime.o -o user`).
   Header stays the public API surface; the `.o` provides the bodies. The
   PHASE 1.3.B commit message hints this is the target architecture but the
   `.o` ship path isn't documented yet.

Option 1 is the smallest delta and unblocks all downstream users on the new
codegen path immediately. Option 3 is the long-term architecture.

## Reproducer

```sh
cd ~/core/wilson
git checkout main
./build/Darwin-arm64/wilson build  # fails with the errors above

# Workaround:
sed -i.bak 's|#include "runtime.h"|#include "runtime.c"|' build/artifacts/wilson.c
clang -O2 -DHEXA_HAS_LIBSODIUM -I/opt/homebrew/Cellar/libsodium/1.0.22/include \
      -DHEXA_HAS_OPENSSL -I/opt/homebrew/Cellar/openssl@3/3.6.2/include \
      -Wno-trigraphs -fbracket-depth=4096 \
      -I /Users/ghost/core/hexa-lang/self \
      build/artifacts/wilson.c -o build/Darwin-arm64/wilson \
      -lpthread -lsodium -lssl -lcrypto                 # ← succeeds
```

## Severity

**High — blocks downstream rebuilds.** Anyone tracking `main` on hexa-lang who
compiles a project that uses `stdlib/sort` or event-bus folds (≈ all
non-trivial agents) hits this on the first build after pulling. The
workaround is one `sed` line but it's load-bearing in CI and dev iteration.
