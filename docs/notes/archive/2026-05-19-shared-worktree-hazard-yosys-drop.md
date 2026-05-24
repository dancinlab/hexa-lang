# Shared-worktree-hazard fire: yosys scaffold silently dropped + re-landed

**Date:** 2026-05-19
**Branch:** `rfc043-hexa-torch` (shared worktree, ≥2 concurrent sessions)
**Severity:** medium — recoverable; no permanent data loss; honest
audit-trail entry kept here because the failure mode is well-known
(memory `shared worktree branch hazard`) and a measured instance is
worth filing.

## TL;DR

This session attempted to land an atomic 8-file scaffold under
`stdlib/yosys/` plus a new entry in `inbox/PATCHES.yaml`. While the
files sat in the working tree (post-`Write`, pre-`git add`), a parallel
session in the same working tree was mid-`git cherry-pick 234063d1`
(parser own/borrow/move/drop surface) with several `UU` files. The
parallel session's conflict-resolution `git add` (likely `git add .` or
`git add -A`) swept this session's `stdlib/yosys/` + `PATCHES.yaml`
edits into the cherry-pick's index, then `git cherry-pick --continue`
committed them all under the parser-surface commit message
(`f880c425`). The parallel session then **rewrote history** to clean
its own diff (likely `git reset` + re-commit or `git rebase -i`),
producing a new SHA `a6e5ac95` for the same parser change — and in
doing so, **silently dropped this session's 8 files + PATCHES entry**.

Working tree state after the rewrite:

- `stdlib/yosys/` directory: **gone** (not tracked, not on disk).
- `inbox/PATCHES.yaml` `stdlib-yosys-rfc006-scaffold` entry: **gone**.
- `component/` scaffold + booksim PATCHES flip (this session's earlier
  two atomic commits `ca4827a4` + `0daf707b`): **preserved** (they
  landed cleanly before the cherry-pick started).
- 6 commits ahead of `origin/rfc043-hexa-torch` (two of which are this
  session's preserved commits).

This session detected the drop (`git ls-tree HEAD stdlib/yosys/` empty
+ `ls` "No such file") and re-created the 8 files + PATCHES entry from
in-context content, committing them in a fresh explicit-path commit to
preserve the work cleanly.

## Sequence of events (re-derived from `git reflog` / `git log` /
session transcript)

1. **t0**: This session writes 8 files under `stdlib/yosys/`
   (untracked) + edits `inbox/PATCHES.yaml` (modified-uncommitted).
2. **t0+ε**: Parallel session starts `git cherry-pick 234063d1`,
   hits `UU` on `compiler/PLAN.md`, `self/formatter.hexa`,
   `self/parser.hexa`.
3. **t1**: This session runs `git add stdlib/yosys/* inbox/PATCHES.yaml`
   — files land in index, alongside the parallel session's still-staged
   cherry-pick auto-merge.
4. **t1+ε**: Parallel session resolves UU files, runs `git add` of
   broad scope, then `git cherry-pick --continue`. Commit `f880c425`
   is created with title "feat(parser): own/borrow/move/drop bare-stmt
   surface" but containing 14 files — including the 8 `stdlib/yosys/`
   files + the PATCHES.yaml entry from this session.
5. **t2**: This session's `git reset HEAD stdlib/yosys/
   inbox/PATCHES.yaml component/` unstages but does not undo the
   already-completed commit (the parallel session has already
   committed).
6. **t2+δ**: Parallel session (apparently dissatisfied with the
   bloated diff) rewrites history — `f880c425` → `a6e5ac95`, removing
   the yosys + PATCHES.yaml additions. The history now shows a clean
   parser-surface commit. The yosys/ tree + PATCHES entry are gone.
7. **t3**: This session detects the drop and re-lands the work in a
   fresh atomic commit.

## What was preserved vs lost

| Artifact | Original commit | Status after parallel rewrite |
|---|---|---|
| `0daf707b` booksim PATCHES flip | this session | ✅ preserved |
| `ca4827a4` component/ scaffold (3 files) | this session | ✅ preserved |
| `f880c425` parser surface + yosys scaffold (bundled) | parallel session (cherry-pick) | ❌ rewritten to `a6e5ac95` (yosys files removed) |
| `stdlib/yosys/` 8 files (README + 7 stubs) | f880c425 (transient) | ❌ dropped on rewrite — re-landed in this note's commit |
| `inbox/PATCHES.yaml` yosys entry | f880c425 (transient) | ❌ dropped on rewrite — re-landed in this note's commit |

## Why the safety guard didn't fire

The session's `git branch --show-current` check passed (correct branch).
The hazard memory's guidance is "commit 전 `git branch --show-current`
필수. 자율 interval 커밋 금지." But the failure mode here was not a
wrong-branch commit — it was a **concurrent index mutation** between
this session's `git add` and the parallel session's `git cherry-pick
--continue`, in the same working tree.

The g_inbox_processing_loop SOP recommends `isolation=worktree` for
sub-agents specifically to prevent this. This session is the main
session, not a sub-agent — and was not running under `isolation=worktree`.

## Lesson for memory + AGENTS.tape

The hazard memory should be amended (or a sibling memory written) to
note:

- **Index-sharing window** is the dangerous window — between `git add`
  and `git commit`, any concurrent `git add` / `git cherry-pick
  --continue` / `git stash` in the same working tree can sweep your
  files into another commit.
- **Atomic commits** (`git add + git commit` in a single shell
  invocation, no intervening tool calls or thinking) shorten the window
  but cannot eliminate it.
- **The safe pattern** for main-session work on shared worktree:
  - either run under `isolation=worktree` (sub-agent pattern), or
  - use `git stash push -m <slug> <paths>` immediately after Write to
    take the files out of the working tree, then `git stash pop` +
    `git commit` in a tight window, or
  - accept the hazard and audit history after each commit (this
    session's pattern, with this note as evidence).

## Recovery action taken this session

1. Re-created the 8 `stdlib/yosys/` files from in-context content
   (README + rtlil + read_verilog + passes + liberty + abc_map +
   write_verilog + yosys.hexa.stub).
2. Re-added the `stdlib-yosys-rfc006-scaffold` entry to
   `inbox/PATCHES.yaml` (status: pending, gate §5 OPEN).
3. Filed this note as audit trail.
4. Committed all of the above as a single atomic explicit-path commit.

Re-landed commit message: `feat(stdlib/yosys): re-land rfc_006 §4
scaffold after shared-worktree-hazard drop`. See that commit for the
restored artifact.

## g3 honesty

This note does NOT claim:

- That the parallel session acted in bad faith. The rewrite was almost
  certainly a well-intended diff-cleanup.
- That the hazard memory failed. It correctly described the failure
  class; the operational pattern in this session simply did not avoid
  the index-sharing window.
- That the recovery is byte-identical to the original drop. It was
  re-typed from in-context content; minor whitespace / ordering
  differences possible but content equivalent.

This note IS:

- A measured instance of the shared-worktree-hazard for future
  pattern-matching.
- A pointer to where the safer pattern (worktree isolation) should be
  applied.
- An audit trail so a future reader can reconstruct what happened from
  `git log` + this note + `f880c425`'s reflog entry (if still present).

## Cross-link

- Memory: `shared worktree branch hazard`
- AGENTS.tape: `@D g_inbox_processing_loop` (worktree isolation pattern
  for sub-agents)
- Handoff origin: `inbox/notes/2026-05-19-hexa-arch-rfc006-yosys-handoff.md`
- PATCHES.yaml entry: `stdlib-yosys-rfc006-scaffold` (this note's commit)
