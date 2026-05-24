# hx install — reinstall blocked by runtime artifacts in package dir

> **Status:** resolved (2026-05-23) — the recommended Option 1 (recursive pre-clean) is already the current behavior: `tool/pkg/hx:288` does `rm -rf "$dest"` at the head of `cmd_install` (and `rm -rf "$HX_PKG/$pkg"` in `cmd_remove`). `rm -rf` removes hidden runtime artifacts (`.hook-watch.*.log`) without choking; the reported `rm: Directory not empty` was against a pre-`-rf` hx revision. Option 2 (LaunchAgent bootout before clear) is intentionally NOT adopted — it would couple the generic package manager to per-package agent labels, violating commons g20 (no per-instance branches); stopping a package's own running agent before reinstall is the consumer's responsibility. The only residual is the macOS-specific race where a live agent recreates a file mid-recurse — vanishingly rare, and not generically solvable without that coupling.

**From:** airgenome (downstream)
**Component:** hx package manager (`hexa-lang/tool/pkg/hx`)

## Problem (one concept)

`hx install <pkg>` fails its pre-clean step when the existing package dir contains runtime artifacts written by the package's OWN running processes:

```
$ hx install airgenome
⬡ resolving 'airgenome' via convention orgs...
rm: /Users/ghost/.hx/packages/airgenome: Directory not empty
```

Root cause: a running agent of the installed package (here `com.airgenome.hook-watch`) writes logs INTO the package dir:

```
~/.hx/packages/airgenome/.hook-watch.stderr.log
~/.hx/packages/airgenome/.hook-watch.stdout.log
```

hx's pre-install clean uses a non-recursive `rm` (or `rmdir`-style removal) that chokes on "Directory not empty" because those runtime files were not part of the tracked install.

## Workaround (manual, not ideal)

```
rm -f ~/.hx/packages/<pkg>/.*.log
hx install <pkg>   # then succeeds
```

Filed as upstream gap per cross-project g11 (don't paper over — fix at source).

## Ask

In `hexa-lang/tool/pkg/hx` (the install/reinstall path):

1. Pre-clean the package dir with a recursive remove (`rm -rf <dir>`) rather than a non-recursive `rm` — OR
2. Stop the package's LaunchAgents (bootout) BEFORE clearing the dir, so nothing is writing into it during reinstall — OR
3. Install into a fresh temp dir and atomically swap, leaving runtime artifacts untouched until the swap.

Option 1 is the smallest fix; option 3 is the most robust (atomic, no window where the package dir is half-removed while an agent writes to it).

## Acceptance

```
# with a running agent writing logs into the package dir:
$ hx install airgenome
⬡ installed: airgenome      # succeeds without manual log cleanup
```

## Related

- airgenome scope-reduce PR `dancinlab/airgenome#89` (the reinstall that surfaced this)
- `~/.hx/packages/<pkg>/.hook-watch.*.log` — the runtime artifacts that block the clean
