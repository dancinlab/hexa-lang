# runtime.c malloc-macro vs clang-18 / glibc-2.39 — runtime.o cache-miss build break

## where
`self/runtime.c` libc-shim macros (`#define malloc(n) hxlcl_malloc(...)`, free/realloc/calloc)
collide with `<malloc.h>` (included via `runtime_core.c:328`) when the runtime.o OBJECT
CACHE MISSES and clang recompiles the runtime from source.

## symptom (summer · Ubuntu 24.04 · clang 18.1.3 · glibc 2.39 · RTX 5070)
On a runtime.o cache-miss (`.hexa-cache` GC'd), `hexa run` falls back to "using source"
and the clang runtime compile fails with 10 errors:

```
/usr/include/malloc.h:39: error: function cannot return function type 'int (size_t)'
  expanded from macro 'malloc': #define malloc(n) hxlcl_malloc((size_t)(n))
... (calloc / realloc / free identically)
5 warnings and 10 errors generated.
error: clang compile failed — binary not produced
```

The `hexat` front-end emits the program C cleanly (`[hexat] OK`); ONLY the runtime
source-recompile breaks. A previously-cached runtime.o masks it — so the bug is latent
until a cache GC. `HEXA_APRIME_CC=cc` does NOT redirect the runtime link (still clang).

## root cause
`#include <malloc.h>` is processed AFTER the `#define malloc(...)` shim macros are in
scope, so glibc's `extern void *malloc (size_t)` prototype is rewritten by the function
macro. Older glibc/clang tolerated this; glibc 2.39 + clang 18 do not.

## fix candidates (upstream hexa toolchain)
1. Move every `<malloc.h>`/`<stdlib.h>` system include ABOVE the shim-macro block in
   runtime.c (include system headers first, THEN `#define malloc ...`).
2. Guard the shim: `#undef malloc` (etc.) immediately before the system include, restore
   after — or only define the shim in TUs that never include `<malloc.h>`.
3. Drop the `#include <malloc.h>` (use `<stdlib.h>` which the shim already wraps) — the
   only thing pulled from `<malloc.h>` is `malloc_usable_size`; gate it behind a feature.
4. Ship a prebuilt runtime.o with the toolchain so a cache-miss never source-recompiles.

## workaround used in-campaign
QFORGE converged-CaH6 screened-λ run routed to mini (hexa builds clean there) instead of
summer's free GPU. Summer's hexa is otherwise healthy (CUDA 5070 fine) — purely the
runtime.o cache-miss C-build path. d8 handoff so `hexa` absorbs the fix upstream.
