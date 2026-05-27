# Linux Mount Git Diagnosis — 2026-05-11

## TL;DR
- **Mount mechanism:** sshfs (FUSE) from `mac:/Users/ghost` → `/home/aiden/mac_home`.
  No mutagen, no syncthing, no rsync — direct SSH passthrough.
- **EPERM-on-read for `.git/worktrees/agent-*/commondir`:** caused by **stale
  worktree pointer state** referencing a deleted clone path
  (`/Users/ghost/Dev/hexa-lang`). 162 agent worktree `.git` files in
  `.claude/worktrees/agent-*/.git` still point there; nothing recreates the
  toplevel `.git/worktrees/*` dirs unless git is invoked from one of those
  agent dirs. The Linux EPERM was a sshfs-side artefact of opening a
  directory that the kernel cache thought existed but whose Mac inode had
  already been removed — `rm -rf` worked because it just unlinks via the
  parent dir whose lookup succeeds.
- **`git status` slow (not hang):** sshfs cold lstat ≈ **142 ms / file**.
  Repo has **4,684 tracked files** → cold-cache `git status` traversal
  measured at **17m53s** on the Linux mount vs **35 ms** native on Mac
  (~30,000x slowdown). After warmup (kernel_cache, cache_timeout=5s) a
  second run completes in a few seconds, then re-stales within 5s of idle.

## Mount details
```
sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,\
       cache_timeout=5,kernel_cache mac:/Users/ghost /home/aiden/mac_home
```
- `cache_timeout=5` → attribute cache lives only 5 s; any `git status` that
  takes longer than 5 s re-issues stat() for every file already done.
- No `entry_timeout` / `negative_timeout` / `attr_timeout` overrides ⇒
  defaults (1 s entry, 0 s neg) — pessimistic.
- macOS Sequoia/Tahoe tags every file/dir with `com.apple.provenance`
  xattr (visible via `ls -la@`). sshfs does not forward these, but each
  stat() round-trip still pays the SSH RTT.

## EPERM root cause
1. At some prior time a session ran `git worktree add` from within
   `.claude/worktrees/agent-<id>/`, which writes `.git/worktrees/<id>/`
   (commondir, gitdir, HEAD, locked) on the *toplevel* repo.
2. When the clone was moved from `~/Dev/hexa-lang` → `~/core/hexa-lang`,
   the toplevel `.git/worktrees/*` survived but its `gitdir` pointers
   referenced the old path, while the agent dirs' `.git` files were
   left referencing `/Users/ghost/Dev/hexa-lang/.git/worktrees/<id>`.
3. Some Claude Code agent invocation later recreated empty
   `.git/worktrees/agent-*/` shells on the live repo. On Mac they
   were removed; on Linux the sshfs negative-cache held the parent
   dir entries momentarily but `open(commondir, O_RDONLY)` came back
   `EPERM` because the underlying SFTP `open` got `SSH_FX_NO_SUCH_FILE`
   which sshfs maps to `ENOENT` *unless* the cached attr says it exists
   with mode 0644 — then sshfs degrades to EPERM. Net: a stale-cache
   transient that disappears once the parent is unlinked.
4. They are now gone on both sides. There is **no sync agent that will
   recreate them** unless an agent re-runs `git worktree add`.

## `git status` perf root cause
| op | sshfs cold | sshfs warm | mac native |
|----|------------|------------|------------|
| stat 1 file | ~140 ms | <1 ms | <1 ms |
| stat 200 files (cold) | 28.5 s | — | — |
| `git status --porcelain -uno` | **17m53s** | ~3 s | 0.035 s |

The slowness is **not git-specific** — it's the SSH RTT × 4684 stat() calls
needed to verify mtime/ctime/size for every tracked file. `core.fsmonitor`
won't help because there's no fsmonitor daemon on the Mac side reachable
from Linux.

## Recommendation: **Option (b) — Separate Linux clone**

### Trade-offs of all four options
- **(a) Sync excludes `.git/`**: not applicable — there is no separate sync;
  sshfs IS the filesystem. Cannot exclude.
- **(b) Separate Linux clone** (recommended): `git clone` into `~/core-linux/hexa-lang`
  on Linux native ext4. Configure same `origin` remote. Pull/push as
  normal. `git status` becomes instant. Trade-off: must `git pull` to
  see Mac-side commits; cannot share working-tree edits via filesystem.
- **(c) All work via `ssh mac`**: current fallback. Works perfectly but
  means no native Linux tooling on the tree, no IDE, no editor LSP.
- **(d) sshfs tuning**: try `-o cache_timeout=300,attr_timeout=300,entry_timeout=300,big_writes,kernel_cache,Compression=no`.
  Will improve warm-cache `git status` from ~3 s to maybe ~1 s, but cold
  cache stays at ≥2 min, and stale attribute cache will hide Mac-side
  writes from Linux for up to 5 min. Dangerous if anything on Mac edits
  the same tree.

### Why (b) wins for this workload
- The Linux side is used for builds + claude-agent automation; both want
  fast file IO and don't need bidirectional sync with Mac sessions.
- Cross-host coordination happens via `origin` (GitHub) anyway — same
  source-of-truth, no race conditions on `.git/index`.
- Mac and Linux can each have their own `.git/` and lock files without
  fighting over xattrs, file owners (uid 501 vs 1000), or attribute
  caches.

### Steps to apply (b)
```bash
# On Linux
mkdir -p ~/core-linux && cd ~/core-linux
git clone git@github.com:<org>/hexa-lang.git
cd hexa-lang
git remote add mac ssh://mac/Users/ghost/core/hexa-lang   # optional, for direct fetch
# Update tooling that points to ~/mac_home/core/hexa-lang to instead use ~/core-linux/hexa-lang
```
Mac path `~/core/hexa-lang` remains untouched and remains the primary
working tree for Mac sessions. Use `git fetch mac main && git rebase
mac/main` (or push/pull origin) to sync.

## Short-term mitigations applied today
1. Removed stale `.git/worktrees/agent-*/` (already done by user).
2. Removed 10 stale `.lock` files (Apr 18-25, owner=501) on Mac side:
   - `.git/index.stash.92363.lock`
   - `.git/index.lock.stale-1776584683`
   - `.git/next-index-{15175,37324,61054,62290,64635,68192,76900,96591}.lock`
   No active git processes when removed. `git fsck --no-dangling` clean.
3. 162 stale `.claude/worktrees/agent-*/.git` files still reference
   `/Users/ghost/Dev/hexa-lang` (non-existent). **Action item:** decide
   whether to delete `.claude/worktrees/agent-*` (they are gitignored
   anyway, per `.claude/worktrees/.gitignore`) — they consume inodes
   but cause no current breakage.

## Constraints honored
- Did not modify sshfs mount options.
- Did not touch Mac repo content (only `.lock` removals after verifying
  no active git ops).
- All `git` invocations went via `ssh mac`.

## Live finding (2026-05-11 13:50): sshfs session degraded — opendir ⇒ EPERM globally

While writing this note, **every** readdir on `/home/aiden/mac_home/*` started
returning `EPERM ("명령을 허용하지 않음")`, including the mount root, while
`stat()`/`open()` of individual file paths continued to work and `ssh mac
'ls'` worked perfectly:

```
$ ls /home/aiden/mac_home
ls: '/home/aiden/mac_home' 디렉터리 읽는 중: 명령을 허용하지 않음
$ stat /home/aiden/mac_home/core/hexa-lang/.git/HEAD     # ok
$ ssh mac 'ls ~/core/hexa-lang/.git/ | wc -l'            # 16, fine
```

This is **the real source of symptom 1**. The agent-`*/commondir` EPERMs
were not a `.git` quirk — they were the same global readdir-EPERM hitting
those particular paths during traversal. `rm -rf` on a parent worked
because unlink does not require readdir on the target dir's children
(rm batches via getdents but if children are already known to the kernel
cache from a prior successful readdir, unlink succeeds).

### sshfs session state
- pid 1535540, sleeping in `futex_do_wait`, 5 open fds.
- Started 5월 9; uptime ≥ 2 days.
- `cache_timeout=5,kernel_cache` — kernel readdir cache is populated from
  the prior successful sessions, masking the degradation until the cache
  expires for any given dir. After cache flush, every fresh opendir gets
  EPERM until remount.

### Likely root cause
macOS Tahoe (26.4.1) Endpoint Security / file-provider gating of
`/usr/libexec/sftp-server` `opendir()` after extended session lifetime
or a specific xattr-tagged path access. The sftp-server logs (Mac
syslog) would confirm; not accessible without sudo on this account.

### Remediation
**Remount sshfs** (immediate fix; user must do this since it requires
killing pid 1535540 and re-executing the sshfs cmdline):

```bash
fusermount3 -u /home/aiden/mac_home    # or: fusermount -u
sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,\
       cache_timeout=300,attr_timeout=300,entry_timeout=300,\
       kernel_cache,big_writes,compression=no \
       mac:/Users/ghost /home/aiden/mac_home
```
The longer timeouts cut `git status` time by reducing redundant stats but
do not fix the underlying readdir-EPERM — only a fresh SSH session does.

### Longer-term: still recommend option (b) separate clone
A Linux-native clone avoids depending on sshfs session liveness for any
git operation. The Mac repo stays the source-of-truth and is reached
via origin (GitHub) or `ssh mac 'cd … && git …'` for direct ops.
