# `archive_legacy_glue/` — tombstoned legacy glue scripts (FIRMWARE.md G-T1/G-T2)

> Frozen archive of dead `.sh` / `.py` scripts whose live callers were
> removed or replaced. Tombstoned 2026-05-20 under FIRMWARE.md §1
> forbidden-source-class drain (g_T1/g_T2 cycle). Per FIRMWARE.md §3
> tombstone policy (mirroring the qrng / qmirror / sim-universe
> absorption pattern), the standalone repo for these files would be a
> "frozen archive" — but since they originated in-tree with no
> dedicated upstream, this directory is the in-place tombstone.

These files are **NOT executed** by any in-tree code path. They are
preserved here for historical reference only (audit log, cycle
provenance). The audit (`tool/audit_forbidden_exts.hexa`) classifies
this directory as ABSORBED so the FIRMWARE.md §1 ban does not flag
them.

## Entries (2026-05-20)

| file | previous location | reason for tombstone |
|---|---|---|
| `install_darwin_marker.sh` | `tool/` | Standalone wrapper of `install.hexa::install_darwin_marker()` and `install.sh::install_darwin_marker()` (both functions inline the same logic). The standalone .sh had no live caller — `git grep` showed only self-reference and the FIRMWARE.md citation. |
| `docs_gen.py` | `tool/` | Documentation generator, no live caller after the doc-pipeline migration. |
| `transpile_test.sh` | `tool/` | Transpile-test harness wrapper. No live caller (the new harness is `tool/transpile_*.hexa`). |
| `transpile_test_gen.py` | `tool/` | Transpile-test fixture generator. No live caller. |
| `hexa_to_py.py` | `tool/` | Hexa → Python converter; only caller was `tool/transpile_test.sh` (also tombstoned). |
| `_version_header_seed.sh` | `tool/` | Version-header seed shim; superseded by `tool/absolute_rules_embed_gen.hexa` + atlas-embed pipeline. |
| `version_lint.sh` | `tool/` | Version linter; no live caller (the lint surface is now strict-lint stage 4 + `@D g6 citation-enforced-strict-lint`). |
| `ubu_bootstrap.sh` | `tool/` | Ubuntu pool bootstrap script; replaced by `wilson-pool` plugin per memory `feedback_resource_routing_ubu`. |

## Reversal

If any of these are re-needed, restore with `git mv archive_legacy_glue/<file> <previous-location>`. The pre-tombstone git history is intact (this is a rename, not a delete).
