# incoming patch: phanes-linux-self-host-build-driver-for-containerization — no documented from-source path to a working `hexa build` (flatten-capable driver) on linux/amd64; blocks downstream container images

> **id**: `phanes-linux-self-host-build-driver-for-containerization` · **opened**: 2026-05-19 KST · **status**: `resolved-ssot — verified pure-from-source linux self-host recipe found + measured (see §Resolution). hexa-lang source needs NO change; the gap was stale recipe docs + tooling.`

> **§Resolution (2026-05-19, measured mac arm64 + applied in phanes Dockerfile):**
> hexa-lang's linux self-host needs **no source change** — there IS a
> working pure-from-source path; the recipe docs/tooling were just
> stale. **Verified 4-step chain** (each step measured):
> ```
> # [1] genesis transpiler  (runtime.c is the §2A fix — NOT single-file)
> clang -O2 -std=c11 -D_GNU_SOURCE -I self \
>       self/native/hexa_cc.c self/runtime.c -o self/native/hexa_v2 -lm
> # [2] transpile the build driver — self/main.hexa is import-free,
> #     so hexa_v2 (single-file transpiler) handles it standalone
> ./self/native/hexa_v2 self/main.hexa /tmp/hexa_main.c
> # [3] link the full `hexa` driver (has the `build` subcommand +
> #     import-flatten) — runtime.c again, codegen emits #include runtime.h
> clang -O2 -std=c11 -I self /tmp/hexa_main.c self/runtime.c -o self/native/hexa -lm
> # [4] the driver now does the real thing
> ./self/native/hexa build <any.hexa with imports> -o <bin>   # flatten works
> ```
> Measured: step 4 builds both a 1-line probe AND phanes' import-bearing
> `service/http_phanes.hexa` (stdlib/aws, stdlib/net flatten) — exit 0,
> binaries run. This is the §2B answer: `self/main.hexa` having **zero
> `import` statements** is what makes it transpilable by the single-file
> `hexa_v2` — no circular flatten dependency.
>
> **Upstream artifacts still to correct (doc/tooling only, no source):**
> - `tool/config/build_toolchain.json:527,561` + `tool/cross_compile_linux.hexa:180`
>   — the `clang … hexa_cc.c` single-file recipe → add `self/runtime.c`.
> - `tool/ubu_bootstrap.sh` — `cmd_transpile` hard-`die`s on the deleted
>   `self/hexa_full.hexa` (`@D g_interp_deprecated`), and `_remote_build_script`
>   gcc's `hexa_main.c` without `runtime.c` (stale: pre-2026-05-15 codegen
>   `#include`d runtime inline; now emits `#include "runtime.h"`). It
>   should offer a pure-linux `bootstrap` = the 4-step chain above (no
>   mac-transpile / rsync / interp needed).
>
> Applied downstream: phanes' `Dockerfile` now encodes this 4-step chain
> verbatim — that is the live falsifier (the Cloudflare Containers image
> builds phanes-http on linux/amd64 through it).

> **prior status**: `open — measured downstream (live Docker build), upstream owns the linux self-host story`
> **trees**: `self/native/hexa_cc.c` + `self/runtime.c` (the genesis bootstrap) · `tool/ubu_bootstrap.sh` (the linux flow — partly stale) · `tool/cross_compile_linux.hexa` · `tool/config/build_toolchain.json` (the recipe doc) · `self/main.hexa` (the `build` subcommand driver)
> **source**: downstream `phanes` (`~/core/phanes`, public source-available SaaS) — Cloudflare Containers deploy
> **observed**: 2026-05-19 · measured in a real `docker buildx` build (debian:bookworm, linux/amd64)
> **severity**: medium — phanes runs fully on macOS (whole architecture measured); only the *containerized linux image* is blocked. Not a regression; a missing/stale self-host path.

---

## 1. Why filed upstream (not worked around in phanes)

phanes' Cloudflare Containers deploy (design.md Decision 22) builds a
`Dockerfile` that, per the downstream invariant (`@I id002` /
`@D g_stdlib_ownership` — phanes invokes the upstream toolchain, never
vendors it), clones hexa-lang at a pinned SHA and bootstraps it inside
the image. Producing a linux `phanes-http` needs a working
`hexa build` on linux. That is a hexa-lang self-host capability, not a
phanes concern — so it is filed here.

## 2. What was measured (live `docker buildx`, debian:bookworm, amd64)

Two concrete findings:

**(A) The `hexa_cc.c` → `hexa_v2` recipe in the docs is stale — it
link-fails.** `tool/config/build_toolchain.json:527,561` and
`tool/cross_compile_linux.hexa:180` document:
```
clang -O2 -I../ -o hexa_v2 hexa_cc.c          # (single file)
```
This **fails to link** — on linux *and* on macOS — with undefined
references to `hexa_str`, `rt_read_file`, `hexa_array_new`,
`hexa_arena_reset`, `hexa_int`, `hexa_add_slow`,
`g_hexa_ic_stats_enabled`, … (the C runtime). `hexa_cc.c` only
`#include "runtime.h"` (declarations); the definitions are in
`self/runtime.c` (438 KB). **Measured-correct recipe:**
```
clang -O2 -std=c11 -D_GNU_SOURCE -I self \
      self/native/hexa_cc.c self/runtime.c -o self/native/hexa_v2 -lm
```
Verified: builds `hexa_v2` clean on both macOS arm64 and linux/amd64
(debian, ~405 s). Suggest the doc recipes be corrected to add
`self/runtime.c`.

**(B) `hexa_v2` is transpile-only — there is no from-source path to the
`build` driver on linux.** With `hexa_v2` built, `service/build.sh`
runs `hexa_v2 build http_phanes.hexa -o …` → **SIGSEGV (exit 139)**.
Cause: `hexa_v2` is `hexa-cc <input.hexa> <output.c>` — transpile of a
*single* file only. The `build` subcommand (import flatten → transpile
→ clang orchestration) lives in `self/main.hexa`, a separate program.
Compiling `self/main.hexa` needs import flattening, which needs the
`build` driver — circular. The genesis `hexa_cc.c` does not carry
`main.hexa`'s `build` logic. So a fresh linux clone can produce the
*transpiler* but not the *driver*.

`tool/ubu_bootstrap.sh` is the existing linux flow, but it (i) breaks
the circle by transpiling `self/main.hexa` **on macOS** then gcc-ing on
linux (so it is not a pure-linux / pure-Docker path), and (ii)
references `self/hexa_full.hexa` + `build/hexa_interp` — sources the
interpreter retirement (`@D g_interp_deprecated`) **deleted**. It is
partly stale.

## 3. What would resolve it (upstream's call)

A documented, pure-linux, from-fresh-clone path to a working
`hexa build` — e.g. one of:
- a self-contained genesis that includes the `build` driver (so
  `clang hexa_cc*.c runtime.c → hexa` gives a `build`-capable binary), or
- a documented `hexa_v2 self/main.hexa → main.c → clang` sequence that
  is verified to transpile `main.hexa` standalone (state its real
  import set), updating `ubu_bootstrap.sh` to drop the deleted
  `hexa_full.hexa` / `hexa_interp` references, or
- an explicitly supported `hexa cross --target linux` artifact.

Plus the §2(A) doc-recipe correction (`+ self/runtime.c`).

## 4. Scope / honesty (g3)

- Observation + precise measured gap, **not** a request for phanes to
  patch hexa-lang. Filed per `@D g7` / `@D g_stdlib_ownership`.
- phanes is **not blocked from existing** — it builds + runs + is
  measured end-to-end on macOS (Decisions 21–24, B3 chain). Only the
  Cloudflare-Containers *linux image* waits on this.
- Everything else of the deploy is live and measured: R2 plane, the
  `phanes-jobs` queue, scoped tokens, the Cloudflare Worker
  (`phanes.dancinlife.workers.dev`) + bindings + 7 secrets, and the
  local Docker (colima + buildx) build environment. The `Dockerfile`
  already carries the §2(A) corrected recipe; it gets `hexa_v2` built
  and stops exactly at §2(B).

## 5. Cross-refs

- phanes `design.md` Decision 22 (Cloudflare Containers) — DEPLOY
  EXECUTION block records the same measured wall.
- `tool/ubu_bootstrap.sh` · `tool/cross_compile_linux.hexa` ·
  `tool/config/build_toolchain.json` — the linux/recipe surfaces.
- `@D g_interp_deprecated` — why `hexa_full.hexa` / `hexa_interp` are gone.
