# stdlib/c_ffi — C Foreign Function Interface

**Status**: preview (since 2026-05-08)
**Module**: `stdlib/c_ffi.hexa`
**Selftest**: `stdlib/test/test_c_ffi.hexa` — 34/34 PASS (interp, macOS arm64)
**Driver**: anima chat Phase 3 (BG-KM Llama-3.2-3B libllama bindings)

## TL;DR

Hexa already has C FFI. This module is the stdlib-level wrapper + documentation
that makes the existing primitives discoverable and `import "stdlib/c_ffi"`-able.

The historical claim in `stdlib/sqlite.hexa` header lines 14-31 ("Hexa's stdlib
does NOT have a dlopen/extern fn FFI surface") is OUTDATED as of this module's
landing. Hexa has supported `extern fn` + `@link` + `@symbol` for some time
(`self/codegen_c2.hexa::gen2_extern_static_decl + gen2_extern_wrapper`,
`self/runtime.c::hexa_ffi_dlopen + hexa_ffi_dlsym + hexa_extern_call`) — it
just lacked a stdlib-level surface advertising that.

## Canonical usage (the >95% path)

```hexa
@link("m")
extern fn sqrt(x: float) -> float

let r = sqrt(2.0)   // r ≈ 1.41421
```

That's it. The runtime resolves `libm` via `dlopen` at first call and caches
the symbol pointer in a static slot per-call-site. No FFI boilerplate.

`@symbol("c_name")` aliases the Hexa identifier to a different C symbol
(useful when the C name collides with a Hexa keyword or stdlib builtin):

```hexa
@symbol("strlen")
@link("c")
extern fn c_strlen(s: str) -> int

c_strlen("hello")  // 5
```

## Escape hatch (runtime-resolved symbols)

```hexa
import "stdlib/c_ffi" as ff

let h = ff.c_dlopen("llama")          // 0 on failure
if h == 0 {
    println(ff.c_dlerror())            // dlerror message
    return
}
let p = ff.c_dlsym(h, "llama_load_model_from_file")
// ... pass p to extern fn taking *Void ...
ff.c_dlclose(h)
```

The `c_dlsym` int return is the raw `uintptr_t` address. Since Hexa has no
first-class function-pointer type, the ONLY way to call through this address
is to pass it as `*Void` to another `extern fn` that expects an opaque
function pointer. For direct calls, just use the canonical `extern fn` form
above and let the runtime cache the dlsym for you.

## ABI surface

| Hexa type | C type | Lane (ARM64) |
|---|---|---|
| `int` | `long long` (i64) | GPR x0..x7 |
| `float` | `double` (f64) | SIMD d0..d7 |
| `str` | `char*` (UTF-8 NUL-term) | GPR (pointer) |
| `bool` | `int` (0/1) | GPR |
| `*Void` / `Ptr` | `void*` | GPR |
| `void` | `void` (return only) | — |

**Argument-count limits**:
- AOT compile (native binary): up to 12 positional args.
- Interpreter (`hexa run`): up to 6 direct + overflow protocol up to 14 (g_ffi_overflow buffer).

**NOT supported** (intentional gaps; caller must wrap):
1. **Variadic functions** (`printf`, `execl`) — wrap each invocation in a
   non-variadic C shim (e.g. `self/native/hxprintf_d.c` for `printf("%d", x)`).
2. **Struct-by-value** pass/return (POSIX `struct timespec`, NSRect) — use a
   pointer-to-struct wrapper helper. Existing pattern: `self/ml/hxflash.hexa`
   "struct-args ABI" — pass struct address via `*Void`, accessor `extern fn`
   for fields.
3. **Function-pointer callbacks INTO Hexa** (`qsort` comparator, signal
   handlers) — C calls Hexa is impossible (Hexa frames are not C-ABI).
   Use a C trampoline.
4. **i32 / f32** — only i64 / f64 marshalling is wired. For f32 tensor data,
   pass the raw pointer and let C dereference.
5. **String return ownership** — `extern fn foo() -> str` returns a `char*`;
   the runtime does NOT take ownership. If C `malloc`'d it, leak unless
   caller `free()`s explicitly via another extern fn.

## Library resolution (runtime `hexa_ffi_dlopen`)

For `@link("foo")` the runtime tries (`self/runtime.c:5485+`):

**macOS**:
1. `/System/Library/Frameworks/foo.framework/foo`
2. `/usr/lib/libfoo.dylib`
3. `libfoo.dylib` (DYLD_LIBRARY_PATH searched)
4. `${HEXA_LANG}/self/native/build/libfoo.dylib`
5. `./self/native/build/libfoo.dylib` + `build/libfoo.dylib`

**Linux**:
1. `libfoo.so` (LD_LIBRARY_PATH searched)
2. `/usr/local/cuda/lib64/libfoo.so{,.12,.11}` (CUDA path)
3. `libfoo.so.{12,11}` (soname version sweep)
4. Bare `lib_name` (raw `dlopen`)

For absolute paths, pass them directly: `@link("/opt/homebrew/lib/libsqlite3.dylib")`.

## Public API

```
c_dlopen(name) -> int                  # 0 on failure
c_dlopen_path(absolute_path) -> int    # exact-path open, no resolution
c_dlsym(h, symbol) -> int              # 0 on failure (uintptr_t address)
c_dlclose(h) -> bool                   # true on success
c_dlerror() -> string                  # last linker error or ""

c_lib_loadable(name) -> bool           # cheap availability check
c_libname_for(name) -> string          # "m" -> "libm.dylib"|"libm.so"
c_lib_suffix() -> string               # ".dylib"|".so"
c_lib_prefix() -> string               # "lib"

c_rtld_lazy()/now()/local()/global() -> int    # POSIX dlopen mode constants

c_ret_void()/int()/float()/bool()/pointer() -> int  # ret_kind for host_ffi_call_6
c_float_mask_for(arg_is_float: array) -> int        # build float_mask bitfield

c_ptr_null() -> int                    # 0
c_ptr_is_null(p) -> bool
```

## anima Phase 3 — libllama binding plan

Phase 3 of `/Users/ghost/core/anima` needs libllama bindings to talk to a local
3B-parameter model without subprocess'ing `llama-server`. Expected symbols
(~10-20):

```
llama_model_default_params       llama_load_model_from_file
llama_context_default_params     llama_new_context_with_model
llama_n_ctx                      llama_token_bos
llama_token_eos                  llama_tokenize
llama_kv_cache_clear             llama_decode
llama_get_logits                 llama_sample_token_greedy
llama_token_get_text             llama_free
llama_free_model
```

All fit in 12-arg AOT or 6-arg interp call (the largest, `llama_decode`, takes
2 args). Several take struct-by-value (`llama_model_params`,
`llama_context_params`) — wrap via a tiny C shim (`self/native/hxllama.c`)
exposing flat-arg constructors:

```c
// self/native/hxllama.c (TODO: Phase 3 implementation)
void* hxllama_ctx_params_new(int n_ctx, int n_threads, int n_batch);
```

Then bind those flat shims as `extern fn` in `anima/llama_ffi.hexa`:

```hexa
@link("hxllama")
extern fn hxllama_ctx_params_new(n_ctx: int, n_threads: int, n_batch: int) -> *Void

@link("hxllama")
extern fn llama_load_model_from_file(path: str, params: *Void) -> *Void
```

Phase 3 build steps:
1. Compile `libhxllama.dylib` linking against `libllama.a` (llama.cpp prebuild).
2. Place at `/Users/ghost/core/anima/build/libhxllama.dylib`.
3. Set `DYLD_LIBRARY_PATH` or use `@link("/abs/path/libhxllama.dylib")`.
4. Hexa `extern fn` declarations resolve via `hexa_ffi_dlopen`'s search path.

## raw#9 disposition

raw#9 says "stdlib should be hexa-only". C FFI is the ONE explicit escape
hatch — and even then, the surface is implemented in HEXA (`stdlib/c_ffi.hexa`
is `.hexa`, not `.c`). The C side is just `runtime.c` (already shipped and
part of the bootstrap kernel — not a per-module shim). Any new library
binding (libllama, libsqlite3 native, libonnx, ...) is pure-hexa: just
declare `extern fn` + import this module for portability helpers.

## Selftest output

```
$ cd /Users/ghost/core/hexa-lang
$ ~/.hx/bin/hexa_real run stdlib/test/test_c_ffi.hexa
PASS: c_ffi stdlib selftest 34/34
```

Coverage:
- 4 tests: `extern fn sqrt/pow/strlen` direct calls (canonical path)
- 5 tests: `c_libname_for` cross-platform path construction
- 5 tests: `c_dlopen + c_dlsym + c_dlclose` triplet (manual dlopen path)
- 2 tests: bad-input handling (missing lib, NULL handle)
- 2 tests: `c_lib_loadable` predicate
- 1 test: `c_dlopen_path` absolute-path open
- 5 tests: `c_ret_*` ret_kind constants
- 3 tests: `c_float_mask_for` bitfield builder
- 3 tests: `c_ptr_null` / `c_ptr_is_null`
- 4 tests: `c_rtld_*` mode constants

## Out-of-scope (future work)

1. **libffi integration** — currently the runtime uses hand-rolled marshalling
   capped at 12 args (AOT) / 14 args (interp via overflow). For arbitrary
   variadic / struct-by-value support, link `libffi` and route through it.
   Estimated effort: ~400 LoC C (`self/native/hxffi_libffi.c`) + 100 LoC hexa
   wrapper (`stdlib/c_ffi/libffi_path.hexa`). One cycle.
2. **Type-safe function pointer (Hexa first-class)** — design a `Fn(int,float)->float`
   typed pointer that captures both the address and the signature. Would
   subsume `c_dlsym` for typed callbacks and let Hexa-side function pointers
   be passed back to C via libffi closures. Multi-cycle language work.
3. **Auto-generated bindings** — a tool that ingests a C header (libllama.h,
   sqlite3.h) and emits `extern fn` declarations + struct accessor helpers.
   Out-of-scope for this PR; dovetails with `tool/hexa-bindgen` (proposal-stage).
4. **Windows support** — currently macOS + Linux only. Windows needs
   `LoadLibrary` / `GetProcAddress` (no dlopen). The `c_lib_prefix()` helper
   is already factored to support empty prefix on Windows, but the runtime
   has no Windows codegen yet.

## C3 (limitations — honest)

- This module's bootstrap path (`@link("c") extern fn dlopen`) actually
  works on macOS because `libSystem` reexports libdl. On Linux, the runtime
  search may fail for `@link("c")` because `libc.so.6` doesn't always export
  `dlopen` on all glibc versions (resolved in glibc 2.34+). For older
  Linuxes, the runtime falls back to `libdl.so` via additional search; the
  `_ff_dlopen` extern fn declaration in `c_ffi.hexa` will resolve there.
  Not yet tested on Linux; that's a follow-up.
- `c_dlerror()` returning Hexa string from C `char*` works for the
  immediate test (libdl manages the buffer's lifetime). For long error
  retention, copy into a hexa string immediately — don't cache the int pointer.
- `sys_platform()`-style probing (uname -s) is a shell-out per call. Not
  cached. For high-frequency callers, snapshot once at module init.

## File paths

- `/Users/ghost/core/hexa-lang/stdlib/c_ffi.hexa` — the module (~280 LoC)
- `/Users/ghost/core/hexa-lang/stdlib/test/test_c_ffi.hexa` — selftest (~150 LoC)
- `/Users/ghost/core/hexa-lang/stdlib/c_ffi.ai.md` — this doc
- `/Users/ghost/core/hexa-lang/self/runtime.c:5444+` — runtime FFI dispatch (existing)
- `/Users/ghost/core/hexa-lang/self/codegen_c2.hexa:1546+` — extern fn codegen (existing)
- `/Users/ghost/core/hexa-lang/self/parser.hexa:3580+` — extern fn parser (existing)
