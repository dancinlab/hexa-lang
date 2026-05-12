# One-line `hexa` install should also link/clone the hexa-lang source repo

**From:** wilson (downstream) — 2026-05-12, while wilson's governance principle #2 codified
the upstream-fix mechanism as `update || PR` ("direct update if you own the hexa-lang repo,
else PR").

**One concept:** for `update || PR` to actually be possible on a fresh machine, the hexa
source repo has to be present. Today the one-liner install sets up `~/.hx/` (the toolchain),
but the source tree (`hexa-lang/self/`, `hexa-lang/tool/`, `compiler/`, `firmware/`, the
`atlas.*.n6` shards, `incoming/patches/`) has to be cloned + symlinked by hand — e.g. wilson's
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
