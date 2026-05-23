# hexa wrapper — gitignore-vs-tracked recurrence guard (2026-05-23)

> Cycle-8 PR #444 side-finding (anima 2026-05-23 session): "hexa bash wrapper
> was missing on disk mid-session (only hexa.real + hxv2 present, hexa.shim-
> original template available). Used hexa.real directly. May be worth a
> follow-up to ensure the wrapper is consistently installed."

## Root cause

PR #421 (`042c32c2`, 2026-05-23) added the `hexa` bash wrapper to the repo via
`git add -f` — `hexa` was (and is) a gitignore match on line 2 of `.gitignore`.

Two recurrence vectors followed from that mismatch:

1. **Stale wrapper on pre-#421 branches.** Branches forked before `042c32c2`
   land carry the old May 10 5-line wrapper (`exec "/Users/ghost/core/hexa-
   lang/hexa.real" "$@"`, hardcoded path — g13 violation). `git pull` /
   `git checkout` does NOT overwrite the file because it's gitignored —
   gitignore-matched paths are skipped on tree-update for previously-untracked
   files. Confirmed in anima/`inbox/websocat-tool-discovery-2026-05-23`
   worktree this cycle (branched from `1ac0b51f`, pre-#421).
2. **Missing wrapper after `git clean -fdx`.** A clean cycle wipes gitignored
   files including the on-disk wrapper. `git checkout HEAD -- hexa` recovers
   it but is non-obvious. Likely what bit the cycle-8 PR #444 agent.

In both vectors the user falls back to `hexa.real` directly, losing the
`exec -a hexa hxv2` AMFI dodge that #421 was specifically introducing.

## Fix (this PR)

Add `!hexa` exception to `.gitignore` so the tracked blob materializes on
every checkout / fresh worktree:

```
build/
# baseline native interpreter source — must survive gitignore (SH-P3-1 소실 방지)
!build/artifacts/hexa_native_baseline.c
# bash wrapper shim — must survive gitignore so `git checkout` materializes
# the tracked blob (PR #421 added this via `git add -f`).  Recurrence guard
# vs (a) stale pre-#421 copies on older branches, (b) `git clean -fdx` wipe.
# Cycle-8 PR #444 side-finding (anima 2026-05-23) traced root cause here.
!hexa
```

`hexa_test`, `hexa.prev*`, `hexa_old`, `hexa.real`, `hexa.backup_*`, etc.
remain ignored (build outputs / local cache only — not tracked artifacts).

## Verification

```
cd /tmp/hexa-lang-wrapper-fix
git check-ignore -v hexa  # exit=1 (no longer ignored) — was exit=0 before fix
```

## What this does NOT fix

- The `~/.hx/bin/hexa` install symlink (separate install-script concern).
  This PR is repo-side only; install-time wrapper layout is a follow-up.
- Build cycles that regenerate `hexa` with a stale template (e.g. an old
  `tool/build_dispatch.hexa` writing the May-10 5-line form). If such a
  generator still exists, it would silently overwrite the tracked wrapper
  and the next `git add` would commit the regression. Suggest grep for
  `tool/build_dispatch` and `cli_wrappers.hexa --install` codegen paths
  to confirm they emit the #421 form, not the 5-line form.

## Cross-repo provenance

- Filed from: anima (`/Users/ghost/core/anima`) cycle 2026-05-23.
- Anima-side artifact restored locally: `git show origin/main:hexa > hexa`
  in `/Users/ghost/core/hexa-lang` worktree on
  `inbox/websocat-tool-discovery-2026-05-23` branch.
- AMFI/SIGKILL history: anima#169 inbox doc (referenced in wrapper header).
