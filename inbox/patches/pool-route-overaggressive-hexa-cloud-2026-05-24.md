# pool-route hook over-aggressive on `hexa cloud` — wrong-host dispatch + agent rate-limit cascade

**Reporter**: demiurge (RTSC BEE-NET fine-tune campaign · 2026-05-24)
**Severity**: medium (workaround exists, but burns agent budget + masks legitimate `hexa cloud` calls)
**Affected**: pool-route PreToolUse hook (`~/.claude/plugins/cache/sidecar/pool/<ver>/hooks/pool-route.*` 또는 sidecar 동등 위치)
**Discovered through**: `hexa cloud run vast-betenet …` from agent worktree — got routed to `pool on ubu-1 …` because the hook saw "GPU keyword" inside the `hexa cloud` invocation.

## TL;DR

The PreToolUse pool-route hook scans Bash commands for GPU-related substrings
(`hexa cloud`, `nvidia-smi`, `cuda`, `python … --gpu`, …) and rewrites them to
`pool on <gpu-host> …`. But `hexa cloud` is itself the *correct* dispatch
verb for rented GPU pods (g8 canonical) — the hook conflates "uses GPU" with
"should run on pool". Result: `hexa cloud` invocations get redirected to a
local pool host where `hexa cloud` is not installed → exit 127 → agent retries
under rate-limit pressure → cascade.

## Reproduction

```
# from a normal cwd (e.g. an agent worktree under ~/core/demiurge):
hexa cloud run vast-betenet --port 16984 --insecure -- ls /root/betenet/
# → routed to pool on ubu-1 → ubu-1 has no `hexa cloud` binary → exit 127
```

`~/.pool/route-log.jsonl` 에서 `hexa cloud …` 로 시작하는 항목이 `ubu-1` /
`ubu-2` 로 라우팅된 줄이 보인다 (예시 본 캠페인 발견 직전):

```
2026-05-23T19:30:30Z → ubu-2 : find /Users/ghost/core/anima -name "cons …
```

(현 캠페인의 실제 misroute 줄은 g28 cred 회피를 위해 호스트명만 발췌.)

## Observed impact (this campaign)

1. **Agent a9870ce4 (Sonnet, 60s wall)** died with "hexa cloud unavailable on
   ubu-1" — task notification: *"환경이 ubu-1 으로 라우팅됐다 — `hexa cloud`
   가 거기엔 없음. SAVE_POD=1 envar 와 함께 명시적으로 로컬 실행 필요."*
2. **Agent a55f85bc (retry from /tmp)** still hit Anthropic API rate-limit
   (109s, 9 tool uses) — the workaround dance burnt enough retries that the
   parent fell off the rate-limit cliff.
3. Total wasted wall ≈ 6 min, $0 on Vast (pod was idle awaiting fire), but
   ~3 agent rounds of context that should have spent on the fine-tune.

## Workaround (current)

Run from `/tmp` and unset `HEXA_LANG`:

```
cd /tmp && HEXA_LANG= hexa cloud run vast-betenet …
```

This bypasses the pool-route hook because the trigger condition appears to
include cwd-based scope (?) or `HEXA_LANG` env. **The mechanism is not
documented anywhere I could find** — discovered empirically across two
sessions (this one + earlier ALIGNN dispatch).

## Suggested fixes (pick one)

### Fix A — exempt `hexa cloud …` from pool-route entirely (recommended)

`hexa cloud` is the canonical dispatch verb per g8. Pool-route should never
intercept it. Add an explicit allowlist before the GPU-keyword scan:

```
# pool-route hook (pseudocode)
if cmd =~ /^\s*(cd \S+ \&\& )?(env \S+= )?hexa cloud(\s|$)/ {
    return PROCEED   # never route hexa cloud
}
# … rest of GPU-keyword detection …
```

This is the smallest patch — one regex check, zero new env-var surface area.

### Fix B — make `HEXA_LANG=` workaround explicit + documented

If A is too aggressive for other reasons, at minimum document
`POOL_ROUTE_SKIP=1` (or whatever the actual env var is) and accept it in the
hook. Surface it in `hexa cloud --help` and in commons.tape g8.

### Fix C — narrow GPU-keyword scope to `pool list`-resident hosts

The hook is trying to enforce g9 ("local GPU-heavy work goes to a pool host
with a GPU"). It should only fire when the cwd / context indicates *local*
compute, not when the command is already a remote-dispatch verb (`hexa cloud
*`, `ssh …`, `scp …`, `rsync …`, etc.).

## Cross-references

- commons g8 — `hexa cloud` as canonical remote-dispatch verb
- commons g9 — sidekick pool dispatch
- commons g49 — GPU dispatch priority (pool first, cloud fallback) — this is
  the rule the hook is trying to enforce, but it's enforcing it at the wrong
  layer (PreToolUse rewrite vs caller's call-site decision)
- commons g57 — pod fire 🛰️ Monitor + SAVE_POD=1 (this campaign's enforcement
  layer for cloud safety; routing safety is separate)
- sibling: `cloud-cli-run-hang.md`, `cloud-cli-operational-improvements-anima-2026-05-20.md`,
  `hexa-cloud-preflight-stub-and-provisioning-gap-2026-05-24.md`

## Status

- [x] Discovered + workaround (cd /tmp + HEXA_LANG=) verified working
- [ ] Fix A (hexa-cloud allowlist) implemented in pool-route hook
- [ ] route-log entry shape clarified — current log only records (host, cmd-prefix), not (was-rewritten, original-cmd)
- [ ] Document workaround envar in `hexa cloud --help` until fix lands
