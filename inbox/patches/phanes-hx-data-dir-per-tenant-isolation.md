# incoming patch: phanes-hx-data-dir-per-tenant-isolation — drill overlay+checkpoint dir is `$HOME`-derived only; no explicit per-tenant data-dir knob for multi-tenant isolation

> **id**: `phanes-hx-data-dir-per-tenant-isolation` · **opened**: 2026-05-19 KST · **status**: `resolved-ssot 2026-05-19 — HX_DATA_DIR env knob landed; parse-gate clean; binary promote = standard separate deploy step per the 22c27a05 pattern`
> **trees**: `compiler/drill/checkpoint.hexa` (`checkpoint_path` / `checkpoint_save` — `env("HOME")`) · `compiler/drill/round.hexa` + `overlay_path()` (`~/.hx/data/atlas.overlay.n6` — `$HOME`) · `compiler/drill/drill.hexa` (`drill_run` Doctrine v2 룰 5 write policy)
> **source**: downstream `phanes` (`~/core/phanes`, new dancinlab consumer — private SaaS wrapping `hexa kick` / OUROBOROS for companies; scope B generic autonomous-cycle platform).
> **observed**: 2026-05-19 · hexa-lang pin: `50f5f073` (`rfc043-hexa-torch`)
> **severity**: medium — no single-tenant correctness bug; but a multi-tenant web service needs *guaranteed* per-job overlay/checkpoint isolation, and the only current lever is hijacking `$HOME` (a blunt instrument that also redirects every other home-relative read of the process).

---

## 1. Observed (verbatim, from source read)

```
compiler/drill/checkpoint.hexa:53   let home = env("HOME")
compiler/drill/checkpoint.hexa:54   if len(home) == 0 { return ".hx/data/drill_checkpoint.json" }
compiler/drill/checkpoint.hexa:55   return home + "/.hx/data/drill_checkpoint.json"
compiler/drill/checkpoint.hexa:26   // $HOME; concurrent batch dispatch serializes through cmd_drill_batch
```

`overlay_path()` mirrors the same `$HOME`-derived resolution
(`drill.hexa:20` Doctrine v2 룰 5 — single runtime overlay at
`~/.hx/data/atlas.overlay.n6`). There is **no** dedicated env var
(`HX_DATA_DIR`) or CLI flag (`--overlay` / `--checkpoint`) to point the
data dir somewhere explicit.

## 2. Why it matters (downstream / SSOT)

- A multi-tenant SaaS must ensure tenant A's accumulated discoveries
  (`atlas.overlay.n6`) and checkpoint never leak into tenant B's run —
  a hard confidentiality requirement, not a nicety.
- The only isolation lever today is per-job `$HOME` override. That works
  (the drill test suite itself does exactly this:
  `mkdir -p '$base/.hx/data'` + run under `HOME=$base` —
  `drill_test.hexa:36`, `mkx_test.hexa:33`, `accumulation_test.hexa:60`),
  but hijacking `$HOME` also redirects every other home-relative path the
  process reads, which is a blunt and fragile foundation for a hosted
  service.
- `checkpoint.hexa:26` notes concurrent dispatch is *serialized* through
  `cmd_drill_batch` under a single `$HOME`. A multi-tenant service needs
  *concurrent* isolated jobs; per-job data-dir is the clean enabler.

## 3. Suggested resolution (upstream's call)

Add an explicit data-dir override, `$HOME` staying as the fallback
(full back-compat):

- **(a)** env var `HX_DATA_DIR` — when set, `checkpoint_path()` /
  `overlay_path()` resolve under it instead of `env("HOME") + "/.hx/data"`;
  **preferred** (zero CLI surface change, trivial to thread per-job).
- **(b)** or CLI flags `--overlay PATH --checkpoint PATH` on `hexa
  drill`/`kick`, plumbed into `DrillOpts`.

Either makes per-tenant isolation + safe concurrency first-class without
`$HOME` hijack.

## Resolution — 2026-05-19

Resolution (a) from §3 landed: env var `HX_DATA_DIR` overrides the data
dir for ALL drill overlay/checkpoint sites. Surgical, ~30 lines net.

**Helper fn** (single canonical location): `compiler/atlas/overlay.hexa`
adds `pub fn hx_data_dir() -> string`. One conditional, three branches:

  1. `env("HX_DATA_DIR")` if non-empty — explicit override (per-tenant).
  2. `env("HOME") + "/.hx/data"` — historical default (back-compat;
     test idiom `HOME=$base` keeps working unchanged).
  3. `".hx/data"` — relative fallback when neither is set (matches the
     prior `overlay_path()` / `checkpoint_path()` shape).

**Call sites switched to `hx_data_dir()`** (every previous `env("HOME")
+ "/.hx/data..."` construction in the drill+overlay surface):

  - `compiler/atlas/overlay.hexa::overlay_path()`         — was `$HOME/.hx/data/atlas.overlay.n6`
  - `compiler/atlas/overlay.hexa::overlay_ensure_dir()`   — was `mkdir($HOME/.hx/data)`
  - `compiler/drill/checkpoint.hexa::checkpoint_path()`   — was `$HOME/.hx/data/drill_checkpoint.json`
  - `compiler/drill/checkpoint.hexa::_ensure_dir()`       — was `mkdir($HOME/.hx/data)`

`checkpoint.hexa` now `use "compiler/atlas/overlay"` (the dep was
already transitive via `compiler/drill/round`, made explicit here so
the helper is reachable without indirection). `compiler/drill/drill.hexa`'s
Doctrine v2 룰 5 banner comment updated to name `hx_data_dir()` +
`HX_DATA_DIR` for downstream readers.

**Precedence rule** (documented in `hx_data_dir()` docstring):
`HX_DATA_DIR > $HOME/.hx/data > ".hx/data"`. Trailing slash is NOT
included; callers compose `"/<name>"`. Single helper, one rule, no
duplicated conditionals.

**Scope discipline (g3 / no over-claim)**:
  - SSOT fix only — the running `hexa_v2` binary still ships the old
    `env("HOME")`-only resolution until the next standard deploy step
    (the 22c27a05 promote pattern). Until then, phanes v1 keeps the
    per-job `$HOME`-jail workaround; nothing breaks.
  - No CLI flag (`--overlay`/`--checkpoint`) — resolution (a) is the
    minimum primitive phanes asked for; resolution (b) is a separate
    surface-expansion decision left to a future patch if needed.
  - No per-job sub-jail / locking / concurrency policy added — phanes
    keeps the `$HOME`-jail as defense-in-depth.

**Verification**: local OOM-free `hexa_real parse` gate on all three
edited files reported "parses cleanly":
  - `compiler/atlas/overlay.hexa` — OK
  - `compiler/drill/checkpoint.hexa` — OK
  - `compiler/drill/drill.hexa` — OK

Heavy compiled-path verification (drill run under `HX_DATA_DIR=/tmp/foo`
on the running `hexa_v2`) is gated on the standard separate binary
promote step (the 22c27a05 deploy pattern); not performed in this
worktree to avoid a full self-host rebuild.

## 4. Downstream workaround in place

`phanes` Decision 6 = **hybrid**: ship v1 on a per-job `$HOME`-jail /
sandbox (the same idiom drill's own tests use), and file this note as the
canonical-path handoff so the `$HOME` hijack can be retired once
`HX_DATA_DIR` lands (the sandbox is then kept only as defense-in-depth).
Not a blocker for phanes v1.
