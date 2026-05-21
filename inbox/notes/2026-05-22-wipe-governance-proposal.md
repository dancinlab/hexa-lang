# 2026-05-22 — Silent runtime/codegen wipe governance proposal

**Status**: PROPOSAL · awaiting user approval
**Branch**: main · doc-only (no hook installed yet)
**Author**: audit agent (read-only host pin = local)
**SSOT corollary**: memory `feedback_worktree_merge_silent_filedrop` +
`feedback_runtime_c_deploy_regen_wipe` (both pre-existing)

## 1. Findings — wipe inventory (since 2026-05-01)

Audit ran:

```
git log --since=2026-05-01 --format='COMMIT|%H|%s' --numstat -- \
  stdlib/runtime/ self/runtime.c self/runtime_core.c \
  self/codegen_c2.hexa compiler/check/bind.hexa self/rt/core.hexa
```

Filter: total deletions ≥50 lines AND subject mentions none of
`runtime|stdlib|codegen|restore|rt_|RUNTIME`. **10 suspect commits**:

| sha       | dels | declared scope (subject)                                                  |
|-----------|-----:|---------------------------------------------------------------------------|
| `c4c721bc`|   54 | docs(perf scoreboard): N141 v3 APPENDIX — Round 17-19                     |
| `724c38b3`|  152 | feat(gpu/RFC067): N127 warp specialization INTERFERES                     |
| `0d59c419`|  241 | feat(gpu/RFC067): N104 cuBLAS SASS-diff — top 3 micro-opts                |
| `c39afbbe`|  274 | feat: project.tape SSOT + Spec Kit removal + AGENTS.tape → archive        |
| `e9c89904`|  328 | feat(gpu/RFC067): N88 K-unroll 2x REGRESSION -20.1%                       |
| `9367334e`|  521 | feat(gpu/RFC067): N76-retry ldmatrix HGEMM — NEW HEXA RECORD              |
| `b4d45f9f`|  135 | feat(gpu/RFC067+RFC071): Round 13 rate-limit salvage                      |
| `88c00246`|  107 | feat(gpu/RFC067): N74 SGEMM cp.async size=16 vectorised                   |
| `01835ed5`|   56 | docs(GPU.md): §1f — N20 Metal transcendental + N18 Metal shim landed      |
| `362be4ed`|  159 | feat(flame): mk2-closure port — d768 ag_tape stack                        |

Of the 4 in the user's original prompt: `c39afbbe` + `0d59c419` + `724c38b3`
all confirmed, **plus `c4c721bc` is a NEW WIPE at HEAD~2 that re-wiped
the very builtins `61c7eb8d` had just restored from `724c38b3`**.

Working-tree verification at HEAD `78970343`:

```
grep -c __str_raw_len self/codegen_c2.hexa   → 0  (was 1 at 61c7eb8d)
grep -c __fd_write_bytes self/codegen_c2.hexa → 0  (was 1 at 61c7eb8d)
grep -c __str_raw_len compiler/check/bind.hexa → 0  (was 1 at 61c7eb8d)
```

Step 5 #2 (`rt_len` codegen-inline) + Step 5 #4 (`__fd_write_bytes`)
need a **third re-land** after this audit.

## 2. Mechanism — NOT 3-way merge

All 4 confirmed wipes are **single-parent non-merge commits**:

```
c4c721bc  parent=61c7eb8d
724c38b3  parent=a39988c9
0d59c419  parent=6ac8841c
c39afbbe  parent=f8082b97
```

The mechanism is **stale-worktree-replace**: a sub-agent operating in an
8-session shared worktree (per `feedback_hexa_lang_shared_worktree_branch_hazard`
+ `feedback_subagent_worktree_leak_pattern`) commits with `git add -A` or
explicit file paths while its working tree carries an older version of
`stdlib/runtime/*.hexa` + `self/runtime*.c` + `self/codegen_c2.hexa` than
main HEAD has. The commit then deletes lines that were added in the
intervening main commits the sub-agent never pulled.

c4c721bc is the textbook case: it's a SCOREBOARD-only docs commit but
its tree's `self/codegen_c2.hexa` is from before `61c7eb8d`, so the
commit "deletes" the Step 5 #2+#4 re-land.

This is exactly the pattern `feedback_runtime_c_deploy_regen_wipe`
describes for `runtime.c` — but it bites `codegen_c2.hexa` and
`stdlib/runtime/*.hexa` just as often, and 3 of the wipes are
from GPU-cycle sub-agents (RFC067 N-series) that have no business
touching runtime files at all.

## 3. Proposal — Option D (combination, layered)

### D1. Hard gate: pre-commit hook at `.githooks/pre-commit` (DEFAULT-OPT-IN)

Block any commit where:
- deletions in `stdlib/runtime/**`, `self/runtime.c`, `self/runtime_core.c`,
  `self/runtime_arena.c`, `self/codegen_c2.hexa`, `compiler/check/bind.hexa`,
  `self/rt/core.hexa` sum to **>50 lines**, AND
- commit subject (first line) does NOT mention `runtime|stdlib|codegen|rt_|RUNTIME|restore|re-land|recover`

The hook prints the offending file list and tells the user to either:
1. Restage without those files (`git restore --staged <file>` + re-commit), OR
2. Add `WIPE-OK: <reason>` trailer to the commit message (escape hatch).

Activation: `git config core.hooksPath .githooks` (one-line opt-in;
hook lives in-repo, no global install).

### D2. Soft gate: governance entry in project.tape

Add `@D` rule (replaces current `...` placeholders) telling sub-agents
NEVER to commit `stdlib/runtime/**` / `self/runtime*.c` /
`self/codegen_c2.hexa` / `compiler/check/bind.hexa` / `self/rt/core.hexa`
deletions unless the cycle declares it.

### D3. Audit helper: `tool/check_runtime_sync.sh`

Standalone script (no hook dependency) that can be run by the user or a
loop to scan recent commits for new wipes. Same predicate as D1, output
is a markdown table. Useful for catching wipes that slip through D1
(e.g. when `WIPE-OK` escape is misused).

## 4. Draft hook implementation

Path: `.githooks/pre-commit`

```sh
#!/usr/bin/env bash
# .githooks/pre-commit — runtime/codegen silent-wipe guard
# Background: see inbox/notes/2026-05-22-wipe-governance-proposal.md
# Opt-in via:  git config core.hooksPath .githooks
set -euo pipefail

# Paths we guard (newline-separated globs, matched against `git diff --cached`)
GUARD_GLOBS=(
  'stdlib/runtime/'
  'self/runtime.c'
  'self/runtime_core.c'
  'self/runtime_arena.c'
  'self/codegen_c2.hexa'
  'compiler/check/bind.hexa'
  'self/rt/core.hexa'
)

# Build a regex for path matching
guard_regex=$(printf '%s\n' "${GUARD_GLOBS[@]}" | paste -sd'|' -)

# Sum staged deletions in guarded paths
dels=$(git diff --cached --numstat -- "${GUARD_GLOBS[@]}" 2>/dev/null \
  | awk '{ sum += $2 } END { print sum+0 }')

if [ "${dels:-0}" -lt 50 ]; then
  exit 0
fi

# Read commit message (first line) — supplied via $1 by `commit-msg` hook,
# but here we use the working .git/COMMIT_EDITMSG (pre-commit phase).
msg_file="${1:-.git/COMMIT_EDITMSG}"
[ -f "$msg_file" ] || msg_file=$(git rev-parse --git-dir)/COMMIT_EDITMSG
subject=""
if [ -f "$msg_file" ]; then
  subject=$(grep -v '^#' "$msg_file" | head -n 1 || true)
fi
body=""
if [ -f "$msg_file" ]; then
  body=$(grep -v '^#' "$msg_file" || true)
fi

# Allow if subject mentions any expected scope keyword
if echo "$subject" | grep -qiE 'runtime|stdlib|codegen|rt_|RUNTIME|restore|re-land|recover'; then
  exit 0
fi

# Escape hatch: WIPE-OK: <reason> trailer
if echo "$body" | grep -qE '^WIPE-OK:'; then
  exit 0
fi

# Block
echo ""
echo "------------------------------------------------------------"
echo "BLOCKED: pre-commit silent-wipe guard"
echo "------------------------------------------------------------"
echo ""
echo "This commit deletes ${dels} lines in runtime/codegen guarded paths"
echo "but the subject line does not mention runtime/stdlib/codegen."
echo ""
echo "Subject: $subject"
echo ""
echo "Guarded files with staged deletions:"
git diff --cached --numstat -- "${GUARD_GLOBS[@]}" \
  | awk '$2 > 0 { printf "  -%-5d %s\n", $2, $3 }'
echo ""
echo "If this is intentional, add to commit message body:"
echo ""
echo "    WIPE-OK: <one-line reason>"
echo ""
echo "Otherwise restage without those files:"
echo ""
echo "    git restore --staged <file>"
echo ""
echo "Background: inbox/notes/2026-05-22-wipe-governance-proposal.md"
echo "------------------------------------------------------------"
exit 1
```

## 5. Draft project.tape governance text

Replace the placeholder `do/dont` in `project.tape` with (or merge alongside):

```
@D := "hexa-lang" :: governance [active]
  do   = "Subagent cycles MUST git diff <baseline>...HEAD on every guarded file BEFORE staging. Use the pre-commit hook (.githooks/pre-commit) — opt in via `git config core.hooksPath .githooks`."
  dont = "Never commit deletions in stdlib/runtime/** · self/runtime*.c · self/runtime_arena.c · self/codegen_c2.hexa · compiler/check/bind.hexa · self/rt/core.hexa unless the cycle declares 'runtime/stdlib/codegen' scope in the subject. Sub-agent worktrees are 8-session shared; a stale tree silently drops re-lands. WIPE-OK: <reason> trailer is the only escape."
```

## 6. Recommendation

Land in this order, each as its own commit:

1. **THIS file** (proposal, inbox/notes) — landed now, this audit cycle.
2. **`.githooks/pre-commit`** — separate PR. User reviews, opts in by
   `git config core.hooksPath .githooks` per local clone. NOT auto-installed.
3. **`project.tape` @D update** — separate commit after #2 lands.
4. **`tool/check_runtime_sync.sh`** — optional follow-up.
5. **Third re-land of Step 5 #2+#4** (`__str_raw_len`/`__arr_raw_len`/
   `__map_raw_len`/`__arr_set_cap`/`__fd_write_bytes`) — separate commit.
   This is the 4th attempt; the hook will protect it from being
   wiped a 5th time.

## 7. Why hook over memory-only

Memory governance (`feedback_runtime_c_deploy_regen_wipe`,
`feedback_worktree_merge_silent_filedrop`) has existed for weeks and the
wipes keep happening — 10 in 3 weeks, including 4 in the last 48 hours.
Sub-agents either don't read the memory or do `git add -A` so quickly
that the predicate never fires.

A pre-commit hook fires before the SHA exists — there's nothing to
silently land. The escape hatch (`WIPE-OK: <reason>`) keeps legitimate
refactors (mass rename, deprecation) one-line cheap.

## 8. Cost / risk

- Hook is opt-in per clone (`git config core.hooksPath .githooks`).
  Does NOT auto-install. User reviews this proposal before flipping the
  config.
- False-positive risk: legitimate `stdlib/runtime` deletion in a
  non-runtime-scoped commit (e.g. broad-scope refactor). Mitigated by
  `WIPE-OK:` trailer.
- False-negative risk: deletions below the 50-line threshold slip
  through. Acceptable — the campaign-killing wipes have been 54-521
  lines; a 30-line drop is recoverable from the next nearby commit
  in O(minutes).

## 9. Out of scope (for this proposal)

- Restoring the wiped `__str_raw_len` / `__fd_write_bytes` builtins —
  that's a code cycle, recommend doing AFTER the hook lands so the
  fourth attempt is protected.
- Adopting `.githooks/` for other guards (build artifact paths, etc.) —
  separable.
- Sub-agent worktree isolation policy (Claude harness) — out of
  scope; this is a git-layer guard, not a sandbox policy.
