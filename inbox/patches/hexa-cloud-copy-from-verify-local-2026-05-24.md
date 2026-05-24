# `hexa cloud copy-from` exit 0 false-success — F6 extends #646 F2 (file-transfer verb · 2026-05-24)

> **Status**: resolved-PR#714-2026-05-24 — cloud_copy_from local file_exists+size>0 verify with exit markers 100/101/102 landed in stdlib/cloud/cloud.hexa

**Reporter**: anima (`dancinlab/anima` downstream consumer · HEXAD/PURE Phase D v2b corpus-axis fire)
**Severity**: medium (false-success → silent data loss; train 결과 손실이 운영자에게 "성공" 으로 보고됨)
**Affected**: `stdlib/cloud/runpod.hexa` (또는 cloud verb 가 정의된 어디든) `cloud_copy_from` · `cloud_copy_to` exit-code semantics
**Sibling patches (이미 filed, 중복 금지)**:
- `runpod-graphql-builtin-for-pure-dispatcher.md` (commit 1eb47746) — GraphQL surface, 직접 관계 X
- `hexa-cloud-pod-status-diagnose-verbs.md` (commit af558f3e) — `cloud list/status/diag/orphans`, F6 의 pod-status pre-check 가 그 verb 위에 layer 가능
- `hexa-cloud-dispatcher-bootstrap-wait-endpoint-2026-05-24.md` (hexa-lang [#629](https://github.com/dancinlab/hexa-lang/pull/629)) — ssh tuple 반환 surface
- `hexa-cloud-guard-ux-and-pod-lock-2026-05-24.md` (hexa-lang [#646](https://github.com/dancinlab/hexa-lang/pull/646)) — F1-F5; **본 patch F6 는 F2 의 file-transfer verb 자매**

## Context

오늘 anima HEXAD/PURE Phase D v2b fire dispatch — pod `b23g2abvbphz33` 가 ubu-2 carryover sweep 으로 train 완료 전 외부 terminate. Monitor `bbsrt11v9` 의 result-pull 단계가 다음 sequence 로 진행:

```sh
hexa cloud copy-from "$HOST" /workspace/.../result.json "$LR" \
    --port 11086 --insecure
# exit 0  <-- false success
echo "RESULT_PULLED size=$(stat -f %z $LR) sha=$(shasum -a 256 $LR | awk '{print $1}')"
# 출력: RESULT_PULLED size= sha=    <-- $LR 부재로 stat/shasum 둘 다 빈 문자열
```

직접 verify:

```sh
stat /tmp/.../result.json
# ls: ... No such file or directory
```

Monitor 의 success-path branch 가 exit 0 만 보고 "fire 성공" 으로 분류 → 운영자가 result 가 도착하지 않았음을 한참 후에야 발견. False-success class 가 silent data loss 로 propagate 한 명백 케이스.

이는 prior #646 F2 (`cloud_run: no exit-code marker — ssh transport failure or remote shell died` 가 5+ 원인을 단일 문자열로 처리) 와 동일 class — file-transfer verb 측에서는 한 단계 더 나아가 exit-code 자체가 잘못 (0 반환).

## Findings

### F6 — `cloud copy-from` exit 0 false-success when remote file missing OR pod unreachable

**Symptom**: 다음 4 가지 시나리오 모두 `hexa cloud copy-from` 이 exit 0 반환 + 로컬 파일 미생성 —

1. **Remote file missing**: pod 은 살아있지만 path 가 존재하지 않음 (예: train 미완료, save 단계 실패)
2. **Pod terminated externally**: pod 이 종료된 후 scp 시도, ssh refused 단계에서 silent fail
3. **Pod unreachable (transport)**: network refused / timeout / auth — scp 가 stderr 만 emit 후 wrapper 가 그것을 0 으로 변환
4. **Local write failure**: 권한 / 디스크 풀 / 경로 부재 — scp 가 부분-write 후 rollback 되지만 wrapper 가 0 반환

오늘 발생한 케이스는 (2) — pod terminated → scp connection refused → wrapper exit 0. 하지만 (1)/(3)/(4) 모두 같은 false-success class 에 속함을 운영자가 prior saga 에서 관찰.

**Root cause**: `cloud_copy_from` 의 wrapper 가 `scp` 호출의 raw exit code 만 chain 하지 않고 (또는 chain 하더라도 잘못 mask), 로컬 파일이 실제 도착했는지 — `exists(local) && size(local) > 0` — 확인하지 않음. scp 자체가 silent-fail 모드 (예: source-not-found 에서 stderr 만 emit, exit 0) 일 수 있어 wrapper 측 verify 가 필수.

**Suggested change** — `cloud_copy_from` (그리고 자매 `cloud_copy_to`) 에 local-side verify 추가:

```hexa
// stdlib/cloud/runpod.hexa (또는 verb 가 정의된 위치)
//
// 정상 path 에서도 transport-success ≠ file-arrived; 명시 verify 1-step 추가.
fn cloud_copy_from(
  host: string,
  remote: string,
  local: string,
  opts: map
) -> int {
  // 1. scp 호출
  let rc = scp_internal(host, remote, local, opts);
  if rc != 0 {
    // 기존 transport-error path — #646 F2 의 분류 패턴 적용
    return rc;
  }

  // 2. NEW: local-side verify (정상 path)
  if !file_exists(local) {
    // scp 가 silent success 했으나 파일 미생성 — remote 측 source-not-found 가능성
    return 100;   // reason = "remote_file_missing_or_scp_silent_fail"
  }
  if file_size(local) == 0 {
    // 0-byte 전송 — 일반적으로 remote 측 빈 파일이거나 mid-transfer 실패
    return 101;   // reason = "zero_byte_transfer"
  }

  return 0;
}

// 자매 cloud_copy_to — 같은 패턴 (remote 측 verify 는 ssh stat 1 회 필요, 추가 latency)
fn cloud_copy_to(
  host: string,
  local: string,
  remote: string,
  opts: map
) -> int {
  if !file_exists(local) { return 102; /* local_source_missing — pre-check */ }
  let rc = scp_internal(host, local, remote, opts);
  if rc != 0 { return rc; }

  // optional: ssh "stat -c %s <remote>" 로 remote-size verify
  // (cost: 1 ssh round-trip; opts.verify_remote=true 일 때만)
  if opts["verify_remote"] == true {
    let rsize = cloud_run_oneshot(host, fmt("stat -c %s {}", remote), opts);
    if rsize.exit != 0 { return 103; /* remote_verify_failed */ }
    if to_int(rsize.stdout) != file_size(local) {
      return 104;   // reason = "size_mismatch"
    }
  }
  return 0;
}
```

**Exit-code semantics 제안** (caller 가 분류 가능하도록):

| exit | 의미 |
|------|------|
| 0    | success (local file exists, size > 0) |
| 1-99 | scp 의 raw exit code (전통적 transport 실패 — refused/timeout/auth) |
| 100  | `remote_file_missing` — scp 성공이나 local 미생성 |
| 101  | `zero_byte_transfer` |
| 102  | `local_source_missing` (copy-to pre-check) |
| 103  | `remote_verify_failed` (copy-to optional) |
| 104  | `size_mismatch` (copy-to optional) |

Caller (Monitor pattern, anima dispatcher 등) 는 `exit==0` 만 신뢰; defensive `stat $LR` 후속 체크 불필요 → wrapper 의 책임 명확.

### F6.1 (sub-finding) — pod-status pre-check 가 cheap path

`copy-from` 호출 직전에 `cloud_pod_status(host)` (cf. `hexa-cloud-pod-status-diagnose-verbs.md`) 가 RUNNING 아닌 경우 즉시 exit 1 + reason `pod_not_running` 권장 — scp 호출 자체를 skip 하여 ssh refused timeout 의 latency 절약. 단, runpod GraphQL 호출 1 회 추가 (~200-500ms) — high-frequency invocation (예: monitor poll-loop) 에는 cache 필요.

## Cross-refs (prior patches)

- `hexa-cloud-guard-ux-and-pod-lock-2026-05-24.md` (#646) — **F2 와 직접 자매**; F2 = `cloud_run` 의 transport-error 단일 문자열 분류, F6 = file-transfer verb 의 exit-code false-success. 두 patch 가 함께 land 시 cloud verb 전체에 걸친 transport-failure semantics 일관성 확보.
- `hexa-cloud-pod-status-diagnose-verbs.md` (af558f3e) — F6.1 의 `cloud_pod_status` 가 그 verb 위 layer.
- `hexa-cloud-dispatcher-bootstrap-wait-endpoint-2026-05-24.md` (#629) — `cloud_create_pod_opts` 의 ssh tuple 반환 surface; F6 의 host 인자가 그것에서 유래.
- `runpod-graphql-builtin-for-pure-dispatcher.md` (1eb47746) — F6.1 의 pod-status pre-check 가 GraphQL surface 의존.
- `cloud-runpod-session-findings-anima-2026-05-23.md` (R1 fixed; R2-R4 open) — 어제 sibling, 같은 false-success class 의 다른 표면.

## C3 honesty

- F6 는 오늘 saga 1 회 + 운영자의 prior 관찰 — 통계적 prior 약함. 그러나 `cloud_copy_from` wrapper 가 scp raw exit 만 chain 하면 source-not-found 의 scp silent-success 는 spec-level 가능성.
- Suggested exit-code semantics 의 100-104 numeric assignment 는 bikeshed welcome — hexa-lang 측 컨벤션 (예: 모든 cloud verb 가 100-199 range reserve) 우선.
- F6.1 의 pod-status pre-check 는 latency-cost trade-off — high-frequency caller 는 opt-in (`opts["preflight_pod_status"]=true`) 으로 제한 권장. Default-on 시 monitor poll-loop 의 GraphQL rate-limit 위험.
- `copy-to` 의 remote-size verify 는 optional (`opts["verify_remote"]`) — symmetric coverage 위해 sketch 했으나 오늘 saga 는 `copy-from` 만 관찰됨. `copy-to` reverse case unverified.
- scp 의 silent-success 모드는 OpenSSH version / scp protocol (legacy vs sftp) 에 따라 다름 — 본 patch 는 wrapper 측 defensive verify 로 backend-agnostic 하게 처리. 만약 hexa-lang 이 sftp protocol 만 사용 (silent-success 없음) 한다면 F6 의 직접 root cause 는 wrapper 의 exit code 변환 측 — 그래도 local-side verify 는 cheap 한 belt-and-suspenders.
- stdlib pthread race / 동시 copy-from 호출의 race condition 은 본 patch scope 밖 — single-call 의 exit-code correctness 만 다룸.
- anima 는 본 patch 의 변경을 downstream vendor 하지 않음. inbox-only filing (`@D a_runpod_inbox`).
- 본 patch 1 finding (+ 1 sub) — F6/F6.1 모두 오늘 saga 단일 관찰. F2 의 patten 자매라는 cross-ref 가 prior 의 표면 density 를 시사.
