# One-line `hexa` install should also link/clone the hexa-lang source repo

**Status:** resolved-ssot (2026-05-19) — `install.sh` now shallow-clones the
hexa-lang source into `$HX_HOME/src`, symlinks `stdlib/` + `self/` next to the
`hexa.real` binary (so the compiler's install-relative discovery, df9e7f6b,
finds them with no `HEXA_LANG`/`HEXA_STDLIB_ROOT`), and builds the compiled
`hexa_module_loader` flatten helper from that source. Measured: a fresh
simulated install into a temp `HX_HOME` builds + runs a `use "stdlib/..."`
program with zero env hints. The ask's (a) clone-to-known-location and (b)
wire support-tree links into `~/.hx/bin/` are done. The ask's (c) `hexa repo
path` subcommand and the optional `hexa update` verb are NOT done — they need a
compiler change and remain open as a follow-up (the source location is the
stable `$HX_HOME/src`, so it is discoverable, just not yet printable by a CLI
verb). Skip with `HEXA_SKIP_SRC=1`.

**From:** wilson (downstream) — 2026-05-12, while wilson's governance principle #2 codified
the upstream-fix mechanism as `update || PR` ("direct update if you own the hexa-lang repo,
else PR").

**One concept:** for `update || PR` to actually be possible on a fresh machine, the hexa
source repo has to be present. Today the one-liner install sets up `~/.hx/` (the toolchain),
but the source tree (`hexa-lang/self/`, `hexa-lang/tool/`, `compiler/`, `firmware/`, the
`atlas.*.n6` shards, `inbox/patches/`) has to be cloned + symlinked by hand — e.g. wilson's
AGENTS.md documents that `ln -s ~/core/hexa-lang/self ~/.hx/bin/self` and
`ln -s ~/core/hexa-lang/tool ~/.hx/bin/tool` are required for `hexa build` to work at all.

**Ask:** the one-line `hexa` install should also (a) clone the hexa-lang repo to a known
location (e.g. `~/core/hexa-lang` or `$XDG_DATA_HOME/hexa-lang`), (b) wire the `self/` + `tool/`
support-tree symlinks into `~/.hx/bin/` automatically, and (c) record where it landed so
`hexa --version` / a `hexa repo path` can print it. Then "fix it upstream" is a real option
for any installed user — `cd $(hexa repo path) && git switch -c fix && … && gh pr create`
(or, if they own the repo, just edit + `promote.hexa`) — without a manual clone-and-symlink dance.

Optional: `hexa update` to `git pull` the source repo + rebuild the toolchain in place.

No wilson-side change; filing per the AGENTS.md hexa-lang handoff protocol. Related:
`hexa-cli-help-stale-after-absorption.md`.
