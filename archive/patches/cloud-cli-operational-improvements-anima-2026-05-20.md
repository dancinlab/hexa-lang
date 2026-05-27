# `stdlib/cloud` operational improvements — anima 2026-05-20 cycle pain points

**Status**: near-CLOSED-2026-05-25 — 11-item anima cycle bundle. 번들1(2026-05-25, cloud 0.2.2): P5+P10. **번들2(2026-05-25, cloud 0.2.3): P3 (watch poll-loop + `--then-down` teardown) · P6 (copy `--verify-sha`) · P4 ssh-port verb CLOSED.** P1/P2/P4-list/P7-orphan/P9 = 이전 배치. **P8 DEFERRED** (run 시작 후 ssh detach 불가 — `nohup`+`--max-wall` 로 충족, 근거는 P8 bullet). 잔여 OPEN: P7 util-watchdog(부분) · P11(cosmetic) · P4 raw create-cascade(=`cloud rent` 가 search→create→wait→register 로 충족, 순수 create stub 만 미구현).

> **Status (2026-05-25 sync v2):** P1 · P2(#764) · P3 · P4(list/ssh-port/terminate=down/create-cascade=rent) · P5 · P6 · P10 = **CLOSED** · P7 partial(orphan✅ util-watchdog OPEN) · P8 **DEFERRED** · P9 superseded · P11 OPEN(cosmetic). **Net: 7 of 11 CLOSED, 1 partial, 1 deferred, 1 superseded, 1 cosmetic.**
>
> - **P1 (run hang) — CLOSED** by PR #423 `7b8e15b3` `fix(runtime): exec_capture select()-multiplexed drain — kill pipe deadlock`. Root cause was in `hexa_exec_capture` (`self/runtime.c`), not `cloud_cli.hexa`. Sibling patch `cloud-cli-run-hang.md` already marked FIXED.
> - **P2 (`--max-wall`) — OPEN.** No max-wall flag on `cloud run`. Now lower urgency since P1 hang is gone, but still useful for bounded predictable jobs. Out-of-scope for this sync.
> - **P3 (`cloud watch`) — CLOSED.** `cloud watch <host> <pid> [--interval N] [--max-wait S] [--then-down <id> [--provider P]]` — `cloud_poll_opts` 를 interval 마다 loop, pid 사망 시 exit 0(경과초 출력) / max-wait 초과 시 124. `--max-wait 0`(기본)=무한 babysit. `--then-down` 으로 완료 시 자동 teardown(`_cloud_down`) → R2 "auto-loop + 종료" 패턴 완성.
> - **P4 (runpod abstraction) — CLOSED (raw-create stub만 잔존):**
>   - `cloud list` — **CLOSED** by PR #388 + PR #612.
>   - create-cascade — **CLOSED (사실상).** `cloud rent <vast|runpod>` (#798) 가 search→create→wait-ssh→register cascade 수행. 순수 raw `create`(대기 없이 id만) 단독 verb 만 미구현 — 필요시 별도 slug.
>   - `cloud ssh-port <id> [--provider]` — **CLOSED.** 기존 `runpod_get_ssh_port`/`vast_ssh_endpoint` fn 을 verb 로 wiring (live host:port 출력).
>   - terminate — **CLOSED.** `cloud down <id> [--provider]` (#798) 가 `runpod_terminate`/`vast_destroy` + registry forget 수행.
> - **P5 (recursive copy-to) — CLOSED.** `copy-to -r`/`--recursive` → `cloud_copy_to_recursive_opts` (`scp -r` directory tree, same local-source pre-check / exit-102). `--batch` (multi-file one-shot) 은 미구현 — 디렉터리 트리로 대체 가능, 필요시 별도 slug.
> - **P6 (`--verify-sha`) — CLOSED.** `copy-to`/`copy-from --verify-sha`: 전송 후 local 과 remote 의 sha256 비교(`cloud_verify_sha`). exit 0 일치 / 103 불일치 / 104 sha 도구 부재. portable: `sha256sum` 우선, `shasum -a 256` 폴백(양측).
> - **P7 (`cloud monitor`) — PARTIAL:**
>   - Orphan detection (`::owner=<tag>` marker) — **CLOSED** by PR #614 (`cloud orphans` + `cloud owner-tag` read-only L2).
>   - GPU-util threshold watchdog with `--on-idle terminate` — **OPEN.** Diag verbs surface util data (PR #615) but no auto-action loop yet. Convergent with sibling PR #646 F5 (`owner_lock + protected_until`).
> - **P8 (`--auto-nohup-over`) — DEFERRED (근거 명시).** 깔끔한 구현 불가: `run` 은 ssh 세션에 묶인 foreground 프로세스라 시작 후 background 로 detach 할 방법이 없음(detach 하려면 처음부터 `nohup` 이어야 함). 또 "N초 초과 예상" 을 사전에 알 수 없어 휴리스틱 자체가 모호. 명시적 `nohup` verb + `--max-wall` 가 동일 니즈(장기 작업 background / 상한)를 이미 충족. 새 슬랙 없이 close.
> - **P9 (`--fallback=ssh-direct`) — SUPERSEDED.** Designed as a workaround for P1. Since P1 (PR #423) closed the hang at the transport layer, this flag is no longer load-bearing. Not pursuing.
> - **P10 (stderr propagation on non-zero) — CLOSED.** `run`/`exec` 가 비정상 종료 시 `_print_fail_tail` 로 마지막 30줄을 `[cloud] ── exit C · last N line(s) ──` 배너와 함께 화면 맨 아래에 재출력 (terminal 은 바닥으로 스크롤 → 실패가 바로 보임). 성공/빈 출력 시 no-op.
> - **P11 (tar provenance warning noise) — OPEN.** Cosmetic; no current filter or workaround doc.
>
> **Related merged work (not closing P-items directly):** PR #650 (`cloud help` text sync with diag verbs L1-L3) · PR #563 (RFC 088 hexa-cloud preflight + typed env-var, separate axis) · PR #653 (RFC 091 hexa-cloud preflight v2 DFT/HPC axis) · PR #429 (vast.ai backend mirror) · PR #629 (dispatcher bootstrap + wait + ssh-endpoint surface) · PR #646 (cloud-guard UX + pod-lock).
>
> Each remaining P-item is independently workaroundable today; no regression carried, only feature-request consolidation. Carry forward as standalone cycles (P2/P5/P6 are small surgical adds; P4 create-cascade/terminate is the largest remaining gap).

**Reporter**: anima (`dancinlab/anima` downstream consumer)
**Severity**: medium (workarounds exist, but consolidation needed)
**Affected**: `stdlib/cloud/cloud_cli.hexa`, `stdlib/cloud/cloud.hexa`,
`stdlib/cloud/runpod.hexa` (origin/main, post-PR #88)

This patch enumerates operational pain points hit by anima during a
single 2026-05-20 cycle (§184 ALL TAPS RELEASE + §182 4-tier retry +
§186 cross-ckpt fires; 5+ pods, ~$15-20 sunk in dispatch infrastructure
bugs). Each item below is from real measurement, not speculation.

## P1 — `run` mode EOF hang (already filed) — **CLOSED 2026-05-23**

See sibling file `cloud-cli-run-hang.md`. Summary: `cloud run` with a
remote process > ~1 min wall hangs indefinitely after the process
exits cleanly. Caused §184 v3 + §182 t1/t2/t3/t4 simultaneous hang.

**Anima workaround**: `cloud nohup` + `cloud poll` (functional today).

**Suggested fix** (from sibling file): per-stream EOF + timeout, OR
ssh exit-status primary signal, OR `--max-wall <sec>` flag.

**Resolution**: PR #423 — `hexa_exec_capture` rewritten with `select()`-multiplexed drain. Root cause was alternating blocking reads filling one pipe buffer. All `exec_capture` callers benefit. `--max-wall` ergonomic remains tracked as P2.

## P2 — no `--max-wall` on `cloud run`

Even if P1 is fixed by buffer-drain logic, callers need a hard upper
bound for any long-running step. Suggested:

```
hexa cloud run <host> --max-wall 600 -- python3 train.py
# → exits with code 124 (timeout) + message="max-wall exceeded" on hit
```

Lets dispatch scripts use `run` for predictable-length jobs (corpus
build, eval) without writing nohup+poll boilerplate.

## P3 — `cloud watch` (poll + tail combined)

Today's pattern after `cloud nohup`:

```bash
# launch
PID=$(hexa cloud nohup host log -- python3 train.py)

# manually poll AND tail
while hexa cloud poll host $PID; do
    hexa cloud run host -- tail -3 /workspace/log
    sleep 60
done
```

That's 3 separate SSH connections per loop iteration. A unified:

```
hexa cloud watch <host> <pid> <logfile> [--interval 60] [--max-wall N]
```

= one SSH connection (ControlMaster reused) per tick, exits when
remote pid dies, prints `ALIVE | last-3-log-lines` per tick. Saves
~2s per tick on SSH negotiation overhead AND removes the "did the
loop forget to check?" class of bugs.

## P4 — `cloud runpod create-cascade` (provider abstraction) — **PARTIAL (list CLOSED, create/ssh-port/terminate OPEN)**

`stdlib/cloud/runpod.hexa` has `runpod_create_cascade` API, but
cloud_cli doesn't expose it. Every anima dispatch script today
writes raw `curl https://api.runpod.io/graphql` with the cascade
loop inline (~30 lines of bash per script, with credential handling
via `secret get`). Suggested:

```
hexa cloud runpod create-cascade \
    --gpus "A100-SXM4-80GB,A100-80GB-PCIe,H100-80GB-HBM3" \
    --image runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04 \
    --container-disk 60 \
    --name "s186-phase1"
# → prints pod_id on stdout, exits 0 on success, 1 on full cascade fail
```

```
hexa cloud runpod ssh-port <pod_id> [--wait-tries 60] [--wait-interval 10]
# → prints "ip:port" when port 22 is publicly mapped + handshake OK
#   (the §79-RETRY pattern: ip+publicPort+isIpPublic + actual SSH probe,
#    NOT podHostId since that's a false-blocker per anima §79)
```

```
hexa cloud runpod terminate <pod_id>
# → idempotent, exits 0 even if already terminated
```

```
hexa cloud runpod list [--mine] [--json]
# → list all pods owned by current api_key, for orphan detection
```

Saves anima ~80-100 lines of bash per dispatch script.

## P5 — `cloud copy-to --batch` or directory copy

Today shipping 5 files = 5 separate `cloud copy-to` calls = 5 SSH
connection negotiates. Suggested:

```
hexa cloud copy-to <host> --batch \
    src1 dst1 \
    src2 dst2 \
    src3 dst3
# → single SSH session, ControlMaster reused
```

OR directory copy:

```
hexa cloud copy-to <host> --recursive <local_dir> <remote_dir>
```

Saves ~5-15s on each multi-file dispatch (anima ships 4-6 files
per fire typically).

## P6 — `cloud copy-to --verify-sha`

Silent SCP truncation has bitten anima twice this cycle (disk full
on dest, connection dropping mid-transfer). Post-transfer sha256
verify would catch:

```
hexa cloud copy-to <host> src dst --verify-sha
# → on completion, runs `sha256sum dst` remotely + compares with local
#   sha256(src); exits 1 + prints both hashes on mismatch
```

This is what anima writes manually now (post-copy `cloud run host --
sha256sum dst` + compare); built-in flag = one less foot-gun.

## P7 — `cloud monitor` — orphan-billing detection — **PARTIAL (orphan detection CLOSED via PR #614, util-watchdog OPEN)**

Today's biggest cost: 4 pods × 65 min idle = ~$10-13 because corpus
build failed (ModuleNotFoundError) and trap didn't fire while ssh was
hung in P1. Suggested:

```
hexa cloud monitor <host> <pod_id> \
    --gpu-util-min 5 \
    --max-idle-min 10 \
    --on-idle "terminate"
```

Polls runpod GraphQL for GPU utilization; if util stays below threshold
for max-idle-min, executes `--on-idle` action (terminate/warn/log).
Last-resort safety net against silent hang or zombie process.

## P8 — `cloud nohup --auto-promote-from-run`

Common dispatch pattern: "this command MIGHT take >1 min, so play
safe — use nohup". But then short commands (mkdir, ls) also pay nohup
overhead. Suggested:

```
hexa cloud run <host> --auto-nohup-over 60s -- python3 long_or_short.py
# → behaves as `run` for first 60s
# → silently transitions to nohup pattern if still running, printing pid
```

Caller code can use `run` everywhere; cloud_cli decides whether to
foreground or background based on actual runtime.

## P9 — `--fallback=ssh-direct` on hang — **SUPERSEDED by P1 fix (PR #423)**

Until P1 lands, anima dispatch scripts have to *manually* implement
"if cloud run hangs, kill it and ssh directly" fallback. Suggested:

```
hexa cloud run <host> --fallback=ssh-direct --max-wall 120 -- argv
# → if max-wall exceeded, drops to bare `ssh host -- argv` with same
#   structured-argv POSIX-quoting + exits with that ssh's code
```

= P1+P2 combined into one flag.

## P10 — cleaner stderr propagation on non-zero remote exit

When remote exits non-zero, cloud_cli currently:

```
[cloud] remote exit 1
```

Without surfacing what failed. Caller dispatch scripts then have to:

```
hexa cloud run host -- cmd || { hexa cloud run host -- tail -30 logfile; exit 1; }
```

Suggested: on `remote exit != 0`, cloud_cli automatically prints last
50 lines of `~/.last-cloud-run.stderr` (stashed during dispatch) to
local stderr before exiting.

## P11 — tar provenance warning noise suppression

Each tar transfer prints:

```
tar: Ignoring unknown extended header keyword 'LIBARCHIVE.xattr.com.apple.provenance'
```

11+ times (one per file in archive). macOS-side tar adds the xattr,
Linux tar warns. Cosmetic but spams logs. Either:
- cloud_cli filters these warnings from its output, OR
- documents the workaround (`gtar` flag, or strip xattrs pre-transfer)

## Priority for anima's perspective

If hexa-lang can prioritize, anima's pain ranking:

```
critical: P1 (hang), P7 (orphan watchdog)
high    : P4 (runpod abstract), P5 (batch copy), P9 (fallback)
medium  : P2 (max-wall), P6 (sha verify), P10 (stderr)
low     : P3 (watch), P8 (auto-promote), P11 (tar noise)
```

P1 + P7 + P4 would alone have prevented ~$15 of today's sunk cost.

## anima-side carry until landed

- All dispatch scripts use `cloud nohup` + `cloud poll` for any step
  >60s wall (P1 workaround)
- Pod create cascade hand-written in bash via raw GraphQL curl (P4
  workaround, ~30 lines per script)
- Orphan detection = manual `myself.pods` query + per-pod GPU util
  poll (P7 workaround, also ~20 lines per dispatch + an after-fire
  audit step)
- Copy verify = manual sha256sum probe after copy-to (P6 workaround)
- Single-file copy-to called N times for multi-file ships (P5
  workaround)

## Cross-link (anima side)

- `dancinlab/anima` `AGENTS.tape @D g_train_via_hexa_cloud_and_hexa_lang`
  (TOP MANDATE 2026-05-20)
- `dancinlab/anima` `AGENTS.tape @D g_fire_dispatch_robust`
  (legacy ssh+scp pattern carry)
- `dancinlab/anima` 2026-05-20 cycle artifacts:
    - `HEXAD/UNCLASSIFIED/state/all_taps_release_s184_2026_05_20/`
        (§184 retry v1/v2/v3 dispatch traces)
    - `HEXAD/NEUROMORPHIC/state/vspont_scale_ladder_s182_2026_05_20/`
        (§182 4-tier retry traces, 5-pod cascade incident)
    - `archive/PHILOSOPHY.tape § verdict_all_taps_release_s184_2026_05_20`
        (g6 ledger — operational findings carried)

## honest C3

- This is a feature-request list from a heavy downstream user
  (anima had 5+ pods in flight today); hexa-lang's other consumers
  may have different priorities
- Anima never edits hexa-lang source — this file lives in
  `inbox/patches/` per upstream-downstream invariant
  (`g_train_flame_not_pytorch.upstream_downstream_invariant`)
- Each P-item is functionally workable today; this is consolidation,
  not a blocker
- Cost numbers (~$15) include cascade-trigger from a zombie 7:28 PM
  dispatcher (anima-side bug class — not hexa-lang's fault). The
  pure hexa-lang attributable cost is ~$3-5 (P1 silent hang window).
