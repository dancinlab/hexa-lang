# `hexa cloud` idle-autokill 미존재 — 사용자가 잊으면 무한 $$/h burn

**Reporter**: demiurge (RTSC 캠페인 · 2026-05-24)
**Severity**: high (passive money loss — 사용자가 destroy 안 하면 영구 burn)
**Affected**: `stdlib/cloud/*` (hexa cloud subverbs · no idle-kill verb), `sidecar/pod-monitor/0.1.2/` (advisory only)
**Discovered through**: RTSC 캠페인 진행 중 5 pods 가 18-27h 동안 GPU util 0% idle 상태로 burn ($1.14/h × 평균 22h = ~$25 누적). 사용자가 본 세션 들어와서 발견 후 수동 destroy 5건 일괄.

## TL;DR

`hexa cloud` 에는 **idle-autokill 메커니즘이 없다**. `sidecar/pod-monitor/0.1.2` 는 이름이 monitor 지만 실제로는 PreToolUse advisory hook 만 (SAVE_POD=1 / Monitor / walltime 권고 emit). 실제 idle 감지 + auto-destroy 는 어디에도 없음. 결과: 사용자가 manual destroy 안 하면 pod 가 SSH 종료 후에도 영구 burn.

## 증거

### (1) hexa cloud --help 에 idle/kill 관련 verb 0건

```
$ hexa cloud --help | grep -iE 'idle|auto|kill|destroy|reap|sweep'
(no output)
```

verbs: `run · nohup · poll · copy-to · copy-from · copy-dir-* · preflight · help · version`. lifecycle 은 명시적 `vast destroy` / `runpodctl stop` 만 — `hexa cloud` 가 wrapping 안 함.

### (2) `sidecar/pod-monitor/0.1.2/bin/_pod_monitor.hexa` = advisory only

```hexa
// _pod_monitor.hexa — PreToolUse(Bash) advisory for GPU pod fires.
//
// Fires whenever a Bash command contains `hexa cloud nohup` or `hexa cloud
// run` (the canonical pod-launch verbs per commons @D g8). When matched,
// emit non-blocking additionalContext reminding the agent of three
// invariants:
//   1. set `SAVE_POD=1` envar
//   2. attach the 🛰️ Monitor tool
//   3. ⏱ estimate walltime up front
```

→ 발사 시점의 권고만, 발사 후 idle 상태 감지 / kill 로직 ✗.

### (3) `vast` CLI 본체에는 per-instance idle-kill 옵션 없음

`vast --help` 에 idle-related 는 `workergroup` (autoscale 그룹용) 만. 단일 instance level 에서 "idle > N 시간 이면 destroy" 옵션 없음. RunPod 도 동일.

### (4) 본 캠페인 실제 피해

H3X 8-fanout 캠페인 (h3p · h3n · h3as · h3br · cah6) 의 5 pods 가 결과 회수 후 destroy 안 됨:
- pod 37378449 (Tesla V100, $0.22/h) — uptime 27h, GPU util 0% 내내
- pods 37424531/586/660/703 (RTX 5060Ti/3090, 합 $0.92/h) — uptime 18.6h × 4 평행, GPU util 0%
- **누적 burn ≈ $25 (sunk · 24일 동안 그대로면 $600+)**

본 세션 사용자가 발견 + 수동 destroy 일괄 처리. autokill 있었으면 $25 절약.

## Suggested fixes

### Fix A — `hexa cloud watchdog` 데몬 (recommended)

새 verb: `hexa cloud watchdog [--idle-threshold 30m] [--check-interval 5m] [--dry-run]`

- 백그라운드 데몬으로 launch (LaunchAgent on macOS, systemd on Linux — 단, plist 작성은 g37 사용자-요청만이므로 데몬화 자체는 옵션)
- 5분 간격으로 `vast show instances` + `runpodctl get pod` poll
- GPU util < 1% 이고 idle 시간 > threshold 면 `destroy <id>` 실행
- 로그 `~/.hexa/cloud/watchdog.log` 에 destroy 이력 append
- 첫 release 는 foreground / interactive 만 (사용자가 직접 `hexa cloud watchdog` 띄움), 데몬화는 follow-up

샘플 구현 스케치:

```hexa
fn cmd_watchdog(args: list) {
    let threshold_min = parse_arg("--idle-threshold", args, default="30m")
    let interval_sec = parse_arg("--check-interval", args, default="300")
    while true {
        let instances = vast_show_instances()
        for inst in instances {
            let util = inst["gpu_util"]
            let idle_min = (now() - inst["last_active_ts"]) / 60
            if util < 1.0 && idle_min > threshold_min {
                if !args.contains("--dry-run") {
                    vast_destroy(inst["id"])
                    log("destroyed " + inst["id"] + " (idle " + idle_min + "m)")
                }
            }
        }
        sleep(interval_sec)
    }
}
```

### Fix B — `hexa cloud nohup --max-idle <duration>` flag

발사 시점에 max-idle 박기 → pod-side cron 이 자기 자신 destroy. 더 가볍지만 pod 안에 cron + vast destroy-self 설치 필요.

```
hexa cloud nohup vast-foo log.out --port 16984 --insecure --max-idle 30m -- python train.py
```

- 내부: pod 에 cron 설치 `*/5 * * * * check-idle.sh` (nvidia-smi util 0 이면 self-destroy via curl Vast API)
- 단점: pod 안 작업이 잠시 idle (예: data load) 시 false-positive destroy 위험 → `--idle-threshold` 정밀 튜닝 필요

### Fix C — 세션-end 자동 reap (가벼움)

세션 종료시점 (Claude Code TUI 종료 / stop 신호) PostToolUse 또는 SessionEnd hook 에서 `~/.hexa/cloud/pods-this-session.list` 의 pod IDs 일괄 destroy.

- 추적: `hexa cloud nohup`/`run` 이 새 pod 생성하면 session-pod-list 에 append
- 세션 종료 hook 에서 list 의 pod id 모두 destroy (단, SAVE_POD=1 인 것은 제외)
- 장점: 단순. 단점: 세션 종료가 destroy 의 trigger 라 abnormal 종료시 누락 가능

### Fix 우선순위

1. **Fix A** (watchdog 데몬) — 가장 robust, 사용자가 켜기만 하면 무관심해도 idle pod 자동 reap
2. **Fix C** (session-end reap) — 빠른 구현, 90% 케이스 커버
3. **Fix B** (max-idle flag) — pod-side cron 의존, 가장 fragile

권고: **A + C 병행** 구현 (A 가 daemon · C 가 safety-net).

## Cross-references

- commons @D g8 — `hexa cloud {run|nohup|…}` canonical (현재 lifecycle verb 부재)
- commons @D g57 — pod fire → Monitor + SAVE_POD=1 + walltime ETA (idle 감지 미포함)
- sibling inbox: `pool-route-overaggressive-hexa-cloud-2026-05-24.md` (PR #628 LANDED), `pool-hexa-transpiler-ks-undeclared-2026-05-24.md` (PR #681 LANDED)
- pod-monitor sidecar `0.1.2` (현 advisory-only)
- 본 캠페인 실증: $25 누적 sunk · 24일 방치 시 $600+ projected

## Status

- [x] Discovered + reproduced (5 pods 18-27h idle on 2026-05-24)
- [ ] Fix A 또는 C 구현 (`stdlib/cloud/watchdog.hexa` 또는 `sidecar/pod-monitor/0.2.0` 확장)
- [ ] CHANGELOG + commons g60 (idle-autokill 의무화) 추가 후보
- [ ] 본 patch 의 sample skeleton 을 PoC 로 발전
