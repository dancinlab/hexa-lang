# incoming patch: term-isatty-forward-decl-build-failure — every `hexa build` / `hexa run` of a fresh script fails with `term_isatty_stdin` / `term_isatty_stdout` implicit-function-declaration error

> **id**: `term-isatty-forward-decl-build-failure` · **opened**: 2026-05-23 KST · **status**: fixed — `self/runtime.h:1345-1346` replaced the inline function bodies with proper forward declarations. User-code TU no longer sees the bare-name calls (`term_isatty_stdin` / `_stdout`), so the implicit-function-declaration error is gone. Bodies remain at `self/runtime.c:11835-11836` where `term_ffi.c` is in scope. Side effect: also removes a latent multi-def link error.
> **trees**: `self/runtime.h` (function-definition site for `hexa_term_isatty_stdin` / `hexa_term_isatty_stdout` — uses bare-name callees `term_isatty_stdin` / `term_isatty_stdout` without a preceding forward-decl)
> **source**: downstream `sidecar` (`~/core/sidecar`, every PreToolUse hook — `_pool_route.hexa` · `_cloud_guard.hexa` · `_pr_automerge.hexa` · `_verify_guard.hexa` · `_plist_guard.hexa` · `_hexa_native.hexa` · `_inbox.hexa` · …). Any `hexa run`/`hexa build` against a hexa source that isn't already cached fails at the C-compile stage.
> **observed**: 2026-05-23 · `hexa --version` → `hexa 0.1.0-dispatch`
> **severity**: high — blocks *every new* hexa source from compiling. Cached builds (already-shipped hooks) continue to run from the cache, but any code change forces a rebuild, which fails. All downstream sidecar hook work is gated on this.

---

## 1. Failure (verbatim)

```
In file included from build/artifacts/hexa_run.<hash>.c:2:
/Users/ghost/core/hexa-lang/self/runtime.h:1345:65:
  error: call to undeclared function 'term_isatty_stdin';
         ISO C99 and later do not support implicit function declarations
         [-Wimplicit-function-declaration]
 1345 | HexaVal hexa_term_isatty_stdin(void) {
        return hexa_int((int64_t)term_isatty_stdin()); }
                                 ^
note: did you mean 'hexa_term_isatty_stdin'?
/Users/ghost/core/hexa-lang/self/runtime.h:1346:66:
  error: call to undeclared function 'term_isatty_stdout';
         ISO C99 and later do not support implicit function declarations
 1346 | HexaVal hexa_term_isatty_stdout(void) {
        return hexa_int((int64_t)term_isatty_stdout()); }
                                  ^
2 warnings and 2 errors generated.
error: clang compile failed — binary not produced
```

## 2. Why

- `runtime.h:1345-1346` defines `hexa_term_isatty_stdin()` / `hexa_term_isatty_stdout()` and calls the bare-name `term_isatty_stdin()` / `term_isatty_stdout()`.
- The bare-name definitions live in `runtime.c:11835-…` (verified by grep).
- `runtime.h` is included **before** `runtime.c` in the generated user-code C file, so the C frontend sees the call site before the definition.
- No forward-decl exists for `term_isatty_stdin` / `term_isatty_stdout` in `runtime.h` (other functions follow the `hxlcl_*` forward-decl block but these two were apparently missed in the recent additional-builtin batch — see `runtime.h:383-384` "auto-generated 2026-05-15" header).

## 3. Suggested resolution (upstream's call)

Either:
- **(a)** add forward-decls for `term_isatty_stdin(void)` and `term_isatty_stdout(void)` to the "Additional native/*.c forward-decls" block at `runtime.h:383` so they are visible by the time `runtime.h:1345-1346` calls them; or
- **(b)** move the `hexa_term_isatty_*` definitions out of `runtime.h` (where they shadow the bare-name) into `runtime.c` and only forward-decl the `hexa_*` wrappers in `runtime.h`.

(a) is the minimal fix — two lines, mechanical, mirrors the existing `hxlcl_*` forward-decl pattern.

## 4. Operational impact

The `hexa-cache` keeps already-compiled hooks alive — `_pool_route` / `_hexa_native` / `_plist_guard` / `_cloud_guard` / `_pr_automerge` continue to work on the live system because their binaries were built earlier. But:

- Every *new* hexa source fails at first invocation.
- Any *edit* to an existing hexa source invalidates the cache and forces a rebuild — also fails.
- The downstream PR queue (sidecar `verify-guard` hook, all hexa-lang ports) is blocked.

Workaround: none on the downstream side — the call site is in upstream `runtime.h`. Cannot be patched per-hook.

## 5. Downstream context

Filed during sidecar's `verify-guard` hook authoring (the 5th PreToolUse deny-pattern hook, following hexa-native · plist-guard · cloud-guard · cloud-guard). Source itself (`_verify_guard.hexa`) parses cleanly (`hexa parse` OK) — the failure is purely at the C-compile stage of the runtime header. sidecar's PR proceeds with the source committed; the hook will start enforcing once this upstream fix lands.
