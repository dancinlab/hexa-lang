# BG agents racing on `git commit` via `ssh mac` — serialization policy

**Date:** 2026-05-11
**Status:** advisory (no enforcement mechanism yet)

## What happened (2026-05-11)

Multiple concurrent Claude sessions/sub-agents all run their git operations
through `ssh mac 'cd ~/core/hexa-lang && git ...'` because the local Linux
sshfs mount is in a degraded EPERM state (`git status` is also pathologically
slow on the mount). With several agents committing within the same minute:

- One agent ran `git reset --hard <sha>^` to undo its own staged work and
  inadvertently moved `HEAD` back past **two other agents' commits**
  (`f1386bd7` http_sse v1.1, `46e0d9c5` Linux-mount diagnosis), dangling them.
  Recovered: the Linux-diag content was re-committed (`457ffd66`); the
  http_sse content was still in the working tree → `git commit -C f1386bd7`
  → `d8b44ccf`.
- Plain `git commit` vs `git commit` races just produce
  `fatal: Unable to create '.git/index.lock': File exists` — annoying but
  recoverable (clear the stale lock *after* confirming no op is in progress,
  then retry).

## Policy for agents committing via `ssh mac`

1. **Never `git reset --hard` (or `git reset` to a prior commit) on `main`.**
   It can dangle commits other agents just made. To unstage, use
   `git restore --staged <path>`; to drop a bad commit you *just* made and
   are certain nothing followed it, prefer `git revert` or, if truly alone,
   `git reset --soft HEAD^`.
2. **Stage explicit paths, not `git add -A`.** Other agents may have
   unrelated files modified in the working tree (they do edits on the shared
   mount). `git add SPEC.yaml stdlib/http_sse.hexa` — not `git add -A`.
3. **Commit messages with shell-special chars** (`(`, `)`, `<`, `>`, `'`,
   backticks): write the message to `.git/_commit_msg_<name>.txt` (via a
   Mac-side `python3 - <<'PY' ... PY` heredoc, since even the heredoc body
   gets re-eval'd by the remote shell when passed through `ssh`), then
   `git commit -F .git/_commit_msg_<name>.txt`. Use a unique `<name>` per
   agent so two agents don't clobber each other's message file.
4. **On `index.lock` collision:** `git status` first; only if it shows no
   operation in progress, `rm -f .git/index.lock` and retry once. Do not
   loop-retry blindly.
5. **Keep commits small and topic-scoped** so a race that does happen is
   easy to untangle.

## Wishlist (not implemented)

- A `tool/git_commit_serialized.sh` that takes a lock under
  `~/.hx/locks/hexa-lang.gitcommit` (flock) before any commit, so agents
  block instead of racing. Until then, this note is the contract.
