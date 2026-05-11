# wilson ↔ hexa-lang — closure

**Date:** 2026-05-11
**Scope:** Everything hexa-lang owed wilson (the hexa-native re-port of pi-mono's
`{agent→core, ai, tui, coding-agent}`), per `~/core/wilson/docs/hexa-lang-gap-audit.md`
("6 real gaps G1–G6 + G7/G8 nice-to-have") and `~/core/wilson/docs/build-fix-checklist.md`,
plus the build-driver/deploy gaps surfaced when `hexa build core/main.hexa` was first run.
**Verdict up front:** hexa-lang's side is **closed.** The load-bearing gaps (G1 RFC-020
payload enums, G2 RFC-022 async, G3 cancellation) are done and in the deployed binary; the
build-driver gaps (`hexa build` flatten + `-I`) are fixed; the toolchain is re-promoted
through `41ecfb97`. The hexa-lang surface wilson needs for its MVP (`wilson -p "summarize
this file"` does a real turn) is complete. All remaining wilson-build failures are
wilson-source homework, enumerated in wilson's own `docs/build-fix-checklist.md`.

## A. Language / runtime / stdlib gaps (the audit's G1–G8)

| # | gap | weight | hexa-lang status | evidence |
|---|---|---|---|---|
| **G1** | payload-enum complete (`E::V(x)` construction + type-binding + codegen extraction + arm-scope binding) | ★★★ load-bearing | ✅ **DONE** — A1–A5 (`3c8be96c` parser, `005d5427` typechecker, `a85b8a1c` codegen, `4ed9966e` interp+A5) + the **`41ecfb97` regression fix**: A4 codegen had only ever been hand-applied to the *generated* `self/native/hexa_cc.c`, never back-ported to its SSOT `self/codegen_c2.hexa`, so the `64dc8488` `hexa cc --regen` wiped it. `41ecfb97` ports it into `codegen_c2.hexa` (`gen2_expr` EnumPath construction, `gen2_match_cond` tag-only compare gated on `HX_IS_ARRAY`, `gen2_match_stmt` arm-bind injection, `gen2_match_ternary` GCC stmt-expr wrap, `gen2_enum_decl` `@payload` header) + a defensive `payload_expr` on the parser's match-pattern EnumPath node — regen-safe henceforth. `test_enum_payload_full.hexa` **15/15 on the codegen/AOT path AND 15/15 on the interpreter path**, byte-identical stdout (RFC-020 §7); no plain-enum regression (`test_enum_variant`/`construct`/`path` 26/26 + `7gate_smoke` 60/60). Toolchain regen'd + `hexa_real` re-promoted (sha `21c2be60…`). | RFC-020; `41ecfb97`; `self/test_enum_payload_full.hexa`; `incoming/notes/2026-05-11-wilson-build-codegen-wall.md` |
| **G2** | async exec semantics (`async fn`/`await`, identity-await + 1-level `Future` unwrap) + codegen integration | ★★★ load-bearing | ✅ **DONE & deployed** — RFC-022 "Integrated" (`9210e024` G2 v1: parser `AwaitExpr` + interp `NK_AWAIT_EXPR` + native `codegen_c2.hexa` Await branch + `runtime.c hexa_await_unwrap` + `stdlib/future.hexa`); `self/test_async_codegen.hexa` 4/4 interp + 4/4 AOT. The `774c5d32` (5/11) hexa_real re-promote put it in the deployed binary. (Interp-parity sub-gap dissolved per the audit's 2026-05-10(b) decision — streaming exec is just "what a compiled language has".) | `proposals/rfc_022_async_model.md`; `incoming/PATCHES.yaml` `wilson-pi-port-6-gap-prereq` (applied) |
| **G3** | cancellation token (AbortSignal equivalent) | ★★ | ✅ **DONE** — `stdlib/cancel.hexa` + `cancel.ai.md` + `stdlib/test/test_cancel.hexa` 23/23 (`925846d0` / referenced as `wilson-pi-port-6-gap-prereq` G3). Cooperative `Token`. NOTE: wilson's `core/host.hexa` re-exports (`host_cancel_new`/`host_cancel`/`host_cancelled`) call `cancel_new()`/`cancel_cancel(t)`/`cancel_is_cancelled(t)` — names that don't exist; the real API is `token_new()`/`token_cancel(t, reason)`/`token_is_canceled(t)`. That mismatch (+ a missing `use "stdlib/cancel"`) is wilson's fix, already on wilson's checklist (line 30). | `stdlib/cancel.hexa`; wilson `docs/build-fix-checklist.md` line 30 |
| **G4** | JSON-schema runtime validator (tool-argument validation) | ★ | 🟡 **deferred, non-blocking** — `stdlib/jsonschema.hexa` absent; small low-risk stdlib add, "slot in during the port"; explicitly out of the wilson-core gate (`wilson-pi-port-6-gap-prereq`: G4–G6 deferred). | audit §3 |
| **G5** | fs atomic-append + stat parity (audit-ledger writer) | ★ | 🟡 **partial, non-blocking** — `self/stdlib/fs::append_file`/`mkdir_p`/`write_text` + `stdlib/portable_fs::{file_size,mtime,now_ns,exists}` exist; a dedicated `fs_append_atomic` + `fs_rotate_if_over` don't. Non-blocking. | audit §2 |
| **G6** | channel backpressure + JSONL-demux subprocess-pool helper (swarm cells) | ★ | 🟡 **partial, non-blocking** — `stdlib/proc` + `stdlib/channel` + `exec_stream_async` are the pieces; no assembly helper; `channel.ai.md` C3 notes backpressure isn't surfaced. P3, MVP-irrelevant. | audit §2 |
| **G7** | `hexa_ld` dynamic linking / dlopen (in-proc plugins without recompile) | ★ nice-to-have | ⬜ **spec only**, non-blocking *by design* — RFC draft `incoming/patches/g7-hexa-ld-dlopen.md`; `stdlib/dynlink.hexa` + codegen `--shared` not built. wilson works without it via `wilson build --with X` static absorption (the ALT(d) in the RFC). | `incoming/PATCHES.yaml` `g7-hexa-ld-dlopen` (status: spec) |
| **G8** | `hexa_ld` incremental link (`wilson build --with X` = relink changed objects only) | ★ dev-UX | ⬜ **not started**, non-blocking — pure developer-loop nicety. | audit 2026-05-10(b) |

## B. Build driver / install layout (surfaced 2026-05-11 running `hexa build` on wilson)

| issue | hexa-lang status | commit / note |
|---|---|---|
| `hexa build <entry>` didn't pre-flatten the `use`/`import` graph (only `hexa run`'s AOT path did) → link-time undefined symbols for every `use`d sibling module | ✅ **FIXED** — `cmd_build` now mirrors `cmd_run`'s flatten step (uses `self/module_loader.hexa` full-graph fail-loud, not the legacy top-level-only `tool/flatten_imports.hexa`) | `21e7b518` |
| `clang -I` pointed at `<argv0-dir>/self` = `~/.hx/bin/self` (nonexistent for the installed binary) → `#include "runtime.c"` not found | ✅ **FIXED** — `-I` resolved with priority `$HEXA_LANG/self` > `<argv0-dir>/self` > `./self`; applied to both native-clang and `zig cc` cross paths. No more `ln -s ~/core/hexa-lang/self ~/.hx/bin/self` workaround. | `21e7b518` |
| `module_loader.hexa` on the interpreter "blew RSS past 660 MB, didn't finish in ~7 min" on wilson's graph (per wilson's checklist) → feared need for a "compiled module_loader" | ✅ **effectively a non-issue** — measured 2026-05-11 via the `cmd_build` flatten path: full wilson flatten + transpile + clang-attempt = **~12 s** wall. (The checklist's number was from running `module_loader.hexa` *standalone via the interpreter*, not the `cmd_build` path.) "Compiled module_loader" follow-up is moot for wilson. | this note |
| `hexa cc <file>` tries a cwd-relative `hexa_cc.c` rebuild | 🟡 **minor, pending** — only hit when invoking the transpile-self pipeline from outside the repo; workaround `cd $HEXA_LANG && hexa cc`. | `incoming/PATCHES.yaml` `wilson-needs-hexa-build-out-of-tree` note (3) |
| streaming HTTP/SSE POST-with-body for `provider-anthropic` | ✅ **FIXED** — `stdlib/http_sse` v1.1: `http_sse_post` / `http_sse_open_post` / `http_sse_open_method` (+ `http_sse_post_buffered` interp fallback). GET surface byte-identical. | `faca4134` (+ `d8b44ccf`) |

## C. Deploy / toolchain promotion

The deployed CLI binary `~/.hx/bin/hexa_real` was stale (May-2 build; couldn't even parse `await`). Re-promoted:
- 2026-05-10 — `wilson-needs-hexa-real-promotion` (applied): G2 async branches + A1 arena hooks. `test_async_codegen.hexa` 4/4 interp + 4/4 AOT at promote time.
- 2026-05-11 — `774c5d32`: re-promoted from HEAD `64dc8488` — now also has #12 `cmd_build` flatten + `$HEXA_LANG/self -I` (`21e7b518`), A2 in-place splice accumulator (`ab2dfcee`), the Types/C11/Lower/B1+C19/P2 clusters, #14 drain (`18c6a536`). sha256 `ffa91279…`; backups `*.bak.1778481370`; `incoming/manifest_log.jsonl` promote row.
- 2026-05-11 (later) — `41ecfb97`: re-regen'd `hexa_cc.c`/`hexa_v2` with the RFC-020 A4 codegen restored in `codegen_c2.hexa`, rebuilt `hexa_real`, re-promoted (`~/.hx/bin/hexa_real` + `~/.hx/packages/hexa/hexa.real` → sha `21c2be60…`, prev `ffa91279…`, backups `*.bak.1778487926`, manifest row). NOTE: `hexa build` shells out to the *repo's* `self/native/hexa_v2`, so the repo-artifact swap (committed in `41ecfb97`) — not just the `hexa_real` rebuild — is what makes `hexa build` pick up the fix. This was the last hexa-lang-side promote wilson needed.

Side note: `~/.hx/bin/hexa_real run` and `~/.hx/bin/hexa run` LB-route to a remote compute sandbox (where `$HEXA_LANG` is unset); set `RESOURCE_LOCAL_HEXA=1 HEXA_LANG=<repo>` to force local execution. `hexa build` / `hexa cc` don't LB-route.

## D. Remaining wilson-build wall = gap (b) — "first-class ref to a thing with no defining C symbol"

After `41ecfb97` cleared the A4 enum-payload codegen, the wilson build still fails on a single
class: identifiers that codegen emits as `hexa_callN(<name>, …)` — the form for invoking a
*function value* (a bare name used as a first-class reference) — where `<name>` has no defining
C function. Two sub-cases:

**(b1) wilson references names that don't exist — wilson-source bug, already on wilson's checklist:**
- `cancel_new` / `cancel_cancel` / `cancel_is_cancelled` → use `stdlib/cancel`'s `token_new` / `token_cancel(t, reason)` / `token_is_canceled` (+ `use "stdlib/cancel"`). [checklist line 30]
- `read_line_stdin()` / `read_stdin_all()` → builtins `input(prompt?)` / `readline(prompt?)` / `read_stdin` / `input_all`, or `stdlib/sys::sys_stdin_read_line` / `sys_stdin_read_line_timeout(ms)`. **`stdlib/sys.hexa` exists** — the checklist's "❌ no stdlib/sys.hexa" (line 23) is stale. [checklist line 23]
- `split_ws(s)` → wilson-expected helper; not in stdlib/runtime; wilson defines it or uses a real split.

**(b2) wilson takes a runtime *builtin/method* by reference — `char_at`, `trim`, `popen_lines`, `popen_lines_with_status`:** these *do* exist (as `s.char_at(i)` / `s.trim()` method-dispatch and `popen_lines*` runtime builtins) but there's no bare C function named `char_at` / `trim` / `popen_lines` to point a function-value at, so `hexa_call1(trim, x)` is undeclared. This is the one place with a genuine hexa-lang angle — codegen could emit a thunk when a builtin is taken by-value — but the cheaper fix is wilson-side: wrap them (`fn _trim(s) { return s.trim() }`) or call them directly instead of by reference. Either way it's not a wilson-MVP blocker and not tracked as a hexa-lang gap unless wilson asks for the thunk.

## D'. Other NOT-hexa-lang items (wilson-side, on wilson's checklist)
- `fs_read_text` / `fs_write_text` / `fs_mkdir_p` / `read_text` / `write_text` → `self/stdlib/fs`'s `read_file_safe` / `write_file_safe` / `mkdir_p` (+ `fs_exists` / `lstat_is_file` / `lstat_is_dir`). wilson recommends a `core/portability.hexa` adapter that re-exports the real names — already started (`core/portability.hexa: use "self/stdlib/fs"`). [checklist line 21–22]
- `Message.metadata_tool_results` struct field — hexa has no optional struct fields; wilson's fix is `agent_run_turn` returning `#{assistant: Message, tool_results: [ToolResult]}`. [checklist 10-items #1]
- module `use` cycle (`core/loader` → `core/dispatch_table` → `plugins/*/plugin` → `core/types`/`core/host` → `core/loader`) — "verify what hexa-lang actually does first"; the 2026-05-11 build got *past* flatten, so the cycle isn't being rejected (or module_loader tolerates it). Likely a non-issue; if not, wilson breaks the cycle / uses separate compilation units. [checklist 10-items #2]
- pi extension host API (`pi.on(...)`, slash registration, `before_agent_start`); `agent-session.ts` 3110 LOC 6-prereq dep chain; TUI cli subcommands (doctor / self-update / session-picker); macOS Keychain (`security` shell-out); image-resize / mime (`sips`/`convert` shell-out or c_ffi→photon) — coding-agent surface / "just big" / peripheral. Not language gaps.
- `fs_read_text` / `fs_write_text` / `fs_mkdir_p` / `read_text` / `write_text` → `self/stdlib/fs`'s `read_file_safe` / `write_file_safe` / `mkdir_p` (+ `fs_exists` / `lstat_is_file` / `lstat_is_dir`). wilson recommends a `core/portability.hexa` adapter that re-exports the real names — already started (`core/portability.hexa: use "self/stdlib/fs"`). [checklist line 21–22]
- `Message.metadata_tool_results` struct field — hexa has no optional struct fields; wilson's fix is `agent_run_turn` returning `#{assistant: Message, tool_results: [ToolResult]}`. [checklist 10-items #1]
- module `use` cycle (`core/loader` → `core/dispatch_table` → `plugins/*/plugin` → `core/types`/`core/host` → `core/loader`) — "verify what hexa-lang actually does first"; the 2026-05-11 build got *past* flatten, so the cycle isn't being rejected (or module_loader tolerates it). Likely a non-issue; if not, wilson breaks the cycle / uses separate compilation units. [checklist 10-items #2]
- pi extension host API (`pi.on(...)`, slash registration, `before_agent_start`); `agent-session.ts` 3110 LOC 6-prereq dep chain; TUI cli subcommands (doctor / self-update / session-picker); macOS Keychain (`security` shell-out); image-resize / mime (`sips`/`convert` shell-out or c_ffi→photon) — coding-agent surface / "just big" / peripheral. Not language gaps.

## E. Small real hexa-lang follow-ups (none gate wilson MVP)

- builtin-by-reference thunks (gap b2) — codegen could emit a shim when a runtime builtin/method (`trim`, `char_at`, `popen_lines*`, …) is taken as a function value; only do this if wilson would rather not wrap them.
- `exec_stream_kill(h)` — doesn't exist; `exec_stream_close(h)` pclose-joins but doesn't SIGKILL the child, so ESC-cancelling a long `bash` tool isn't prompt. [checklist line 25] — nice-to-have for the `tool-core` plugin.
- `hexa cc <file>` cwd-relative rebuild (B above) — minor.
- G4 `stdlib/jsonschema.hexa`, G5 `fs_append_atomic`+`fs_rotate_if_over`, G6 `stdlib/jsonl_pool.hexa` — small stdlib adds, slot in during the port.
- G7/G8 `hexa_ld` dynamic/incremental — design-time decision, non-blocking.

## Closure statement

hexa-lang has closed the **load-bearing** wilson gaps: G1 (RFC-020 payload enums) — done & deployed (`41ecfb97`; A4 codegen now in the SSOT `codegen_c2.hexa`, regen-safe, `test_enum_payload_full.hexa` 15/15 on both targets); G2 (RFC-022 async) — done & deployed (`9210e024` + `774c5d32`); G3 (cancellation) — done (`stdlib/cancel.hexa`). The **build-driver** gaps wilson hit running `hexa build` are fixed (`21e7b518` flatten + `-I`; the feared "interpreter module_loader too slow" turned out to be ~12 s on the real path). The **deploy** path is current (`774c5d32` → `41ecfb97`; `hexa_real` + `hexa_v2` re-promoted). What remains for wilson to actually `hexa build` clean is **wilson-source homework** that wilson's own `docs/build-fix-checklist.md` already enumerates (the `hexa_callN(<name>,…)`-undeclared class: rename `cancel_*`→`token_*`, fix `read_line_stdin`/`split_ws`, wrap-or-direct-call `trim`/`char_at`/`popen_lines*`; plus the `fs_*` adapter, the `Message` shape, verify the `use` cycle). hexa-lang's remaining items (G4–G8, `exec_stream_kill`, builtin-by-ref thunks, `hexa cc` cwd) are all nice-to-have and do not gate wilson's MVP. **→ The hexa-lang side of wilson is closed; the ball is in wilson's court.**
