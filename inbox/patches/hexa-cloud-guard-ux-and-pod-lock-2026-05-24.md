# `hexa cloud` 가드 메시지 UX + pod-lock 보호 — anima Phase D v1→v2 fire saga 사후 (2026-05-24 · 5 findings)

> **Status (open):** 오늘 anima HEXAD/PURE Phase D v1 fire (PR #372 + #373 post-merge)에서 pod `7rhh18i1h1klcp` 가 `SAVE_POD=1 RETAINED` 로그를 남겼음에도 user-side carryover sweep 으로 train 완료 전 terminate → result.json 손실 · ~$1-2 burn. 직접 원인은 anima-side 운영 실수이나, 5 개 cross-tool gap 이 saga 를 길게 만들었음 — 가드 메시지 모호성 (F1) · ssh 실패 진단 (F2) · 폐기 verb 안내 (F3) · sidecar pool-route 충돌 (F4) · `SAVE_POD` 외부 보호 부재 (F5).

**Reporter**: anima (`dancinlab/anima` downstream consumer · HEXAD/PURE Phase D corpus-axis fire)
**Severity**: low-to-medium (운영 ergonomics; 데이터 손실은 1 회만 발생했고 anima 운영자 측 카운터-체크 부재가 직접 원인)
**Affected**: `commons.tape` cloud-guard 메시지 · `stdlib/cloud/runpod.hexa cloud_run` 진단 · `cloud_create_pod_opts` (PR #629 후속 확장)
**Sibling patches (이미 filed, 중복 금지)**:
- `runpod-graphql-builtin-for-pure-dispatcher.md` (commit 1eb47746 · 8 stub → stdlib import) — 다룸 X
- `hexa-cloud-pod-status-diagnose-verbs.md` (commit af558f3e · `cloud list/status/diag/orphans/owner-tag`) — F5 의 `owner_lock` 은 그 위 layer
- `hexa-cloud-dispatcher-bootstrap-wait-endpoint-2026-05-24.md` (commit 3abbab2d · hexa-lang [#629](https://github.com/dancinlab/hexa-lang/pull/629)) — `cloud_create_pod_opts` 의 ssh tuple 반환을 land 함. F5 는 그 다음 step (lock field 추가)

## Context

오늘 anima Phase D v1 dispatch ([#372](https://github.com/dancinlab/anima/pull/372) `--corpus-path` arg + [#373](https://github.com/dancinlab/anima/pull/373) `sources_upload` workaround) 는 정확히 작동했음 — `dispatch.log` 에 `sources_upload OK`, `corpus_scp_override OK`, `train pid 298`, `SAVE_POD=1 → pod RETAINED` 모두 기록. 이후 운영자가 7-RUNNING-pod carryover sweep 중 `runpodctl pod stop 7rhh18i1h1klcp` 를 실행 → train 미완료 상태에서 종료, `result.json` 손실. 직접 원인은 운영자측 sweep 의 SAVE_POD 미인식이지만, 그 sweep 자체가 F1-F4 gap 누적으로 의사결정이 흐려진 상태에서 발생.

5 개 gap 은 모두 PR #629 이후 새로 surface 한 것 — 즉 #629 의 ssh tuple + `cloud_poll_until` + `cloud_bootstrap_sources` land 후에도 남는 잔여 ergonomics 표면임.

## Findings

### F1 — cloud-guard 가드 메시지가 lifecycle vs remote-exec ambiguity 를 명시하지 않음

**Symptom**: 오늘 `runpodctl ssh start <pod>` 호출이 commons cloud-guard hook 에 의해 block. 가드가 emit 한 메시지:

> "Lifecycle verbs (create / get / start / stop / remove / show / search / launch / destroy) are NOT blocked — only remote exec / transfer / API calls."

하지만 `runpodctl ssh start <pod>` 는 사실 lifecycle (port mapping 설정만, exec 없음) — 가드의 `ssh` 토큰 매칭이 `ssh start` (lifecycle) 와 `ssh <cmd>` (remote exec) 를 구분하지 않고 일괄 차단. 메시지가 `ssh start` 의 lifecycle 성격을 인정하지 않아 운영자가 우회 경로 (hexa cloud run) 가 정말 적합한지 잠시 혼란.

**Suggested change**: 둘 중 하나 —
- (a) **regex 완화**: `runpodctl ssh start` 패턴을 allowlist 에 추가 (정확히 `ssh start` 만, 일반 `ssh` 토큰은 계속 차단).
- (b) **메시지 명확화**: ssh sub-verb 가 의도와 무관하게 전체 차단됨을 명시 — `"runpodctl ssh <any-sub-verb> is blocked as a class (lifecycle ssh-start included). Use hexa cloud {run|nohup|copy-from|copy-to} instead."`

(a) 가 cleaner — 운영자가 `hexa cloud` 의 ssh-tuple 반환 (#629) 없이 raw 한 port 만 잠시 보고 싶을 때 종종 필요한 verb.

### F2 — `hexa cloud run` ssh-transport 실패 진단이 단일 catch-all 문자열

**Symptom**: 오늘 `hexa cloud run` 호출 verbatim 에러:

```
[cloud] cloud_run: no exit-code marker — ssh transport failure or remote shell died
```

이 메시지는 다음 5 가지 원인 모두 동일 문자열을 emit —

1. pod stopped / terminated (오늘의 실제 원인)
2. network refused (intermittent)
3. ssh key auth failure
4. ssh handshake timeout
5. remote shell crashed mid-command

운영자는 매번 `runpodctl pod list` 를 manual 호출해 disambiguate. F1 가드 우회 외 별도 작업 추가.

**Suggested change**: `cloud_run` 의 transport-failure path 에서 1 회 `echo OK` heartbeat probe 추가 후 5 분류 중 1 개를 emit —

```hexa
// stdlib/cloud/runpod.hexa
// Transport-failure 분류 후 명시적 sub-error 반환
fn cloud_run_classify_transport_error(
  host: string,
  opts: map
) -> string {
  // 1. ssh -o ConnectTimeout=5 -o BatchMode=yes <host> "echo OK"
  // 2. exit code + stderr 패턴 매칭:
  //    - "Connection refused"           → "pod_unreachable_refused"
  //    - "Connection timed out"         → "pod_unreachable_timeout"
  //    - "Permission denied (publickey)" → "pod_unreachable_auth"
  //    - heartbeat OK + 원 exit-marker 부재 → "remote_shell_crash"
  //    - runpodctl pod list 에서 status != RUNNING → "pod_unreachable_terminated"
  //    - 그 외                          → "pod_unreachable_unknown"
}
```

`cloud_run` 결과 map 에 `transport_error: <sub-code>` 키 추가 — `cloud_run` 의 caller 가 retry vs abort 결정 가능.

### F3 — `runpodctl get pod` 폐기 안내가 cloud-guard 메시지 / hexa cloud docs 미반영

**Symptom**: 오늘 `runpodctl get pod` 호출 stderr 에 `warning: 'runpodctl get pod' is deprecated, use 'runpodctl pod list' instead` 가 emit 되었음. 그러나:

- `commons.tape` cloud-guard hook 의 helper 메시지에 여전히 `runpodctl get pod` 가 언급되어 있음
- `hexa cloud --help` (또는 cloud subverb 의 docstring) 가 `get pod` 표면을 그대로 노출

**Suggested change**:
- `commons.tape` cloud-guard helper 메시지에서 `get pod` → `pod list` 로 치환
- `stdlib/cloud/runpod.hexa` 내부에서 `runpodctl get pod` 호출 site 가 있으면 `pod list` 로 migrate (이미 prior #629 가 일부 처리했을 가능성, audit 필요)
- 둘 다 1 sed-pass 수준의 mechanical 작업이지만, 가드 메시지가 stale 인 채로 운영자에게 deprecated verb 를 권유하면 매 fire 마다 2-step learning curve 추가됨

### F4 — Monitor + raw ssh 가 sidecar pool-route 후크에 의해 silently 가로채짐 (cross-tool, cross-ref)

**Symptom**: Claude Code Monitor tool 에 raw `ssh -p 38144 root@185.216.23.188 "stat result.json"` 형태 명령을 주면, sidecar pool-route hook 이 다른 host 로 routing → ssh key 부재 → silent refused. 운영자는 (i) refused 가 pod 측 문제인지 routing 측 문제인지 모름 → 시간 소비. 우회는 `hexa cloud copy-from` / `hexa cloud run` 사용 — 이들은 ssh 를 wrapper 안에서 invoke 하여 pool-route 를 bypass.

**Status**: 이는 1 차 sidecar 측 gap (sidecar 의 inbox 으로 별도 file 권장 — 향후). 그러나 **hexa-lang docs 측 보강**도 권장:
- `stdlib/cloud/runpod.hexa` 의 `cloud_run` / `cloud_copy_from` / `cloud_copy_to` docstring 에 `// pool-route bypass: this wrapper invokes ssh/scp directly via stdlib_cli, NOT via shell — pool-route hooks do not intercept` 한 줄 추가
- Monitor 사용자가 어느 verb 가 안전한지 즉시 알 수 있도록

### F5 — `SAVE_POD=1` 가 dispatcher 측 convention 뿐, runpod 측 lock 없음 (PR #629 확장)

**Symptom**: 오늘 dispatcher 가 `SAVE_POD=1` 환경변수 받고 `pod RETAINED` 로그 emit, 그러나 user-side `runpodctl pod stop <id>` (carryover sweep) 가 그대로 종료 처리. SAVE_POD 는 dispatcher 측 "pod 삭제 routine 을 skip" 의미일 뿐, runpod cluster 측에는 어떤 marker 도 남지 않음.

**Root cause**: `cloud_create_pod_opts` (PR #629 ssh tuple 반환) 가 runpod tag system 을 활용하지 않음. runpod 의 `podTagBatch` GraphQL mutation 으로 pod 에 `{owner: <token>, protected_until: <epoch>}` 같은 tag 를 attach 가능.

**Suggested builtin extension** (PR #629 의 `cloud_create_pod_opts` 위에 layer):

```hexa
// stdlib/cloud/runpod.hexa
// Pod 보호 lock — 외부 sweep 도구가 lock 을 honor 하면 실수 종료 방지.
// owner_lock: 임의 token (dispatcher 가 생성, sweep 측이 일치 확인)
// protected_until: epoch seconds (이전엔 sweep 거부, 이후엔 일반 sweep 대상)
fn cloud_create_pod_opts_with_lock(
  // ... 기존 #629 args ...
  owner_lock: string,        // 예: "anima-phase-d-v2-{epoch}"
  protected_until: int       // 예: now + 7200 (2 시간)
) -> map {
  // 1. 기존 cloud_create_pod_opts 호출
  // 2. 성공 시 podTagBatch mutation:
  //    tags = [{key: "owner_lock", value: <owner_lock>},
  //            {key: "protected_until", value: to_string(<protected_until>)}]
  // 3. 반환 map 에 owner_lock + protected_until 키 추가
}

// Sweep 측 helper — `hexa-cloud-pod-status-diagnose-verbs.md` 의 cloud_sweep_orphans 가 honor
fn cloud_sweep_orphans_honor_lock(
  dry_run: bool,
  now_epoch: int
) -> array[map] {
  // 1. 모든 pod 에 대해 tag 조회
  // 2. owner_lock 존재 + protected_until > now_epoch 인 pod 는 skip
  // 3. 그 외 orphan 후보만 반환 (dry_run=true 시 stop 호출 안 함)
}
```

운영자 측 sweep CLI 도 `--honor-locks` 플래그를 default-on 으로 운영하면 오늘 같은 실수 종료 class 가 사라짐. anima dispatcher 는 fire 시점에 `owner_lock = "anima-phase-d-v2-{timestamp}"`, `protected_until = now + estimated_train_seconds + 1800 buffer` 를 set 하여 train 완료 + 30 min buffer 동안 보호.

**Cost impact**: 오늘 손실은 ~$1-2 (terminated 시점까지의 GPU-시간만) + result.json 미회수로 인한 fire 재실행 ~$3-5. 누적 ~$5-7 saga 단일 케이스 — sweep 도구만 lock-honor 하면 0.

## Cross-refs (prior patches)

- `runpod-graphql-builtin-for-pure-dispatcher.md` (commit 1eb47746) — F2/F5 모두 GraphQL surface 가 prerequisite
- `hexa-cloud-pod-status-diagnose-verbs.md` (commit af558f3e) — F5 의 `cloud_sweep_orphans_honor_lock` 는 이 patch 의 `cloud_sweep_orphans` 위 layer
- `hexa-cloud-dispatcher-bootstrap-wait-endpoint-2026-05-24.md` (commit 3abbab2d · hexa-lang #629) — F5 의 `cloud_create_pod_opts_with_lock` 는 #629 의 `cloud_create_pod_opts` 직접 확장
- `cloud-runpod-session-findings-anima-2026-05-23.md` (R1 fixed; R2-R4 open) — 어제 sibling, 메시지 UX 측면 (F1/F3) 의 sibling
- `runpod-r8-r8c-fire-orchestration-gaps-2026-05-24.md` (G1-G4 open) — 같은 날 sibling, lock semantics 가 G1 (`cloud_dispatch_with_code`) 와 자연스럽게 결합

## C3 honesty

- 5 finding 모두 운영 ergonomics — safety bug 아님. 오늘의 ~$1-2 burn 도 직접 원인은 운영자측 sweep 의 SAVE_POD 미인식이지 hexa-lang 측 결함은 아님.
- F1 (가드 regex 완화) 는 보안 영향 0 — `ssh start` 는 port mapping 만 노출, exec 안 함. 그러나 regex 잘못 풀면 `ssh` 일반 verb 도 leak 가능 — 패턴은 정확히 `ssh start <pod-id>$` 끝 anchored 필요.
- F2 (transport 분류) 는 매 `cloud_run` 호출에 1 회 추가 heartbeat = 추가 latency ~200ms — 이미 transport 실패 path 에 진입한 후이므로 사용자 영향 적음. 정상 path 에는 cost 0.
- F3 (deprecated verb) 는 1-pass sed 수준 — 단순 maintenance.
- F4 는 hexa-lang 측 documentation 보강만, fundamental 변경 X. 1 차 sidecar 측 patch 가 별도 필요 (anima 가 사이드카 inbox 으로 follow-up).
- F5 (pod-lock) 가 가장 substantive — runpod GraphQL `podTagBatch` 가 정말 존재하는지 / latency 가 dispatcher 측에 영향 없는지 prior #629 wave 의 GraphQL audit 단계에서 추가 확인 필요. 만약 runpod 측에 pod-tagging 미지원이면 (확률 낮음), `protected_until` 을 pod name 의 suffix 로 우회 — `<base>-prot<epoch>` 패턴, sweep 측 regex parse.
- 5 sketch 시그니처 모두 bikeshed welcome — hexa-lang 측 권한이 우선 (`@D a_runpod_inbox`).
- anima 는 이 patch 의 변경을 downstream vendor 하지 않음. inbox-only filing.
- 5 finding 모두 오늘 saga 1 회 관찰 — 통계적 prior 약함. 그러나 5 개가 동시 surface 한 사실 자체가 surface 의 density 를 시사.
