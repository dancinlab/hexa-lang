# incoming patch: phanes-hx-data-dir-per-tenant-isolation — drill overlay+checkpoint dir is `$HOME`-derived only; no explicit per-tenant data-dir knob for multi-tenant isolation

> **id**: `phanes-hx-data-dir-per-tenant-isolation` · **opened**: 2026-05-19 KST · **status**: `reported (downstream phanes — hybrid workaround in place: per-job $HOME-jail)`
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

## 4. Downstream workaround in place

`phanes` Decision 6 = **hybrid**: ship v1 on a per-job `$HOME`-jail /
sandbox (the same idiom drill's own tests use), and file this note as the
canonical-path handoff so the `$HOME` hijack can be retired once
`HX_DATA_DIR` lands (the sandbox is then kept only as defense-in-depth).
Not a blocker for phanes v1.
