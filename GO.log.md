# GO — domain log (append-only)

## 2026-05-25 · M4 · `hexa cache <subverb>` 1st-class verb

- **branch**: `go-m4-hexa-cache-verb` (base `origin/main`)
- **change**: `self/main.hexa` — new `cmd_cache(args)` + dispatcher branch for `sub == "cache"` + `cmd_help()` entry.
- **subverbs**:
  - `cache stat` — entries · total size · oldest · biggest
  - `cache list [--sort=mtime|size] [--limit=N]` — per-entry name/size/mtime
  - `cache verify` — `file_exists` + `size > 0` over every entry (rc=1 if any zero-size)
  - `cache clean [--prune] [--older-than=N(days)] [--cap-mb=M]` — dry-run unless `--prune`
- **test**: `tests/integration/14_cache_verb/test.hexa` (isolated `$HOME` via `mktemp -d`, seeds 2 entries incl. zero-size bait, walks all 4 subverbs)
- **self-contained**: does NOT depend on M1's `_hexa_cache_gc` helper — uses `find` / `ls` / `stat` / `du` / `xargs` shell pipelines directly, so the M1 and M4 worktrees can land in either order without conflict.
- **parity**: closes the `go clean -cache(-n)` gap — pre-M4 users had to `ls ~/.hexa-cache/ | wc -l` + `du -sh` + `rm` by hand.
