---
slug: hexa-cloud-pod-registry-tracking-2026-05-24
status: resolved
---

**Status (2026-05-25)**: RESOLVED (MVP) by **PR #761** — `stdlib/cloud/pod_registry.hexa`
(persistent JSONL registry at `$HOME/.hexa-cloud/pods.jsonl`; write hook on `cloud run`/
`cloud nohup`; `hexa cloud orphans [--hours N]` lists tracked pods + flags stale, exit 1
on any stale). Closes the core orphan-burn gap. Deferred bonus (separate follow-up, not
blocking): `runpod_list_pods()` cross-reconcile (ORPHAN/GHOST detection) + `adopt`/`forget`
verbs. Corroborating 2nd-domain witness: [[cloud-registry-rtsc-witness-2026-05-24]].

# `hexa cloud` — 발사한 pod 추적/관리 부재 (pod registry 미존재) → orphan burn

**Reporter**: anima (`dancinlab/anima` · PURE Phase D fire 도메인)
**Severity**: high (passive money loss + 결과 회수 불가 — LOST 패턴 반복)
**Affected**: `stdlib/cloud/*` (hexa cloud subverbs) · 모든 dispatcher (`dispatch_*.hexa`)
**Siblings**:
- `hexa-cloud-idle-autokill-missing-2026-05-24.md` — idle pod **kill** (본 건과 보완: kill ≠ track)
- `cloud-runpod-session-findings-anima-2026-05-23.md` — R1 `runpod_list_pods()` (list 는 되나 ephemeral)
- `runpod-graphql-builtin-for-pure-dispatcher.md` — pod ssh-endpoint fetch builtin (`adopt` 의 전제)
- `runpod-r8-r8c-fire-orchestration-gaps-2026-05-24.md` — G4 fan-out aggregated SSOT

## TL;DR

`hexa cloud` 는 pod 를 **발사**는 하지만 **누가 / 언제 / 왜 발사했고 결과가 어디로 가는지** 를
로컬에 영구 기록하지 않는다. 발사 핸들은 발사한 쉘의 휘발성 상태(dispatch.log + Monitor 부착)에만
존재 → **재부팅 / 새 세션 / cross-machine** 이면 핸들이 통째로 소실된다. 그 순간 pod 는 poll 도
pull 도 못 하는 **orphan** 이 되어, 결과 회수 불가 + cost 무한 burn (사용자가 수동 발견 → blind
`stop` 외엔 방법 없음).

> idle-autokill (sibling) 은 "**죽이기**" 다. 본 건은 "**추적/관리**" — orphan 이 애초에 생기지
> 않게 하고, 이미 생긴 것도 `adopt` 해서 poll/pull/lifecycle 을 다시 잡게 하는 것.
> idle-autokill · watchdog · result-recovery 가 전부 이 registry 위에서만 타겟팅 가능 (전제 레이어).

## 증거 — 본 세션 실측 incident

재부팅 후 새 세션 진입 시:

```
$ runpodctl pod list
7× pod   name=p21h-v3-qwen   1×A100 SXM   RUNNING   $1.49/h each   →   합 $10.43/h
```

- 로컬에 v3 `dispatch.log` **없음** · pod manifest **없음** · `state/*p21h*` dir **없음**
- ubu-1 / ubu-2 에도 추적 흔적 0 (게다가 codegen regression 으로 pool 자체 미동작 → 확인조차 불가)
- → 이 7개가 무엇을 학습 중인지 / 결과가 어디로 가는지 / ssh 엔드포인트가 무엇인지 **알 방법이 없음**
- `runpodctl pod list` 가 주는 건 id · name · gpu · status 뿐 — launcher · purpose · result_path ·
  ssh · uptime · 누적 cost = ✗
- v1 LOST(stale-branch) · v2b LOST(cleanup terminate) 에 이은 **3번째 LOST 후보**

## Suggested fix

### Fix A — pod registry 파일 (recommended)

발사 시 append-only 레지스트리에 1행 기록: `~/.hexa-cloud/pods.jsonl`

```hexa
// stdlib/cloud/registry.hexa — pod registry record (1 line per pod)
#{
  "pod_id":      "abhomwjesah341",
  "provider":    "runpod",                     // runpod | vast
  "name":        "p21h-v3-qwen",
  "ssh_host":    "1.2.3.4",
  "ssh_port":    40123,
  "launched_at": "2026-05-24T10:14:02Z",
  "launcher":    "/Users/ghost/core/anima",    // 발사한 cwd/repo
  "purpose":     "PURE Phase D v3 fire",
  "result_path": ".../state/.../result.json",  // pull 대상
  "cost_per_hr": 1.49,
  "status":      "running",                     // running | closed | lost
  "remote_pid":  12345                          // nohup pid (poll 용)
}
```

`hexa cloud run|nohup` 이 runpod/vast 호스트 대상이면 **자동 append/update** — downstream dispatcher
가 ad-hoc 추적 파일을 만들 필요 없음 (단일 관문 = 단일 SSOT).

### Fix B — 신규 verb

| verb | 동작 |
|---|---|
| `hexa cloud ls` | 레지스트리 enumerate + **reconcile** (provider list 와 대조) |
| `hexa cloud adopt <pod_id> [--purpose .. --result-path .. --ssh h:p]` | 미추적 pod 를 레지스트리에 등록 (ssh 엔드포인트는 wrapped API 로 자동 fetch) |
| `hexa cloud forget <pod_id>` (teardown 시 자동) | status=closed 마킹 |
| `hexa cloud poll <pod_id>` | registry 핸들로 poll (host+pid 수동 전달 불필요) |

### reconcile 출력 (orphan / ghost 검출)

```
$ hexa cloud ls --reconcile
POD            NAME          STATUS   UPTIME  COST$  LAUNCHER    TRACKED
abhomwjesah341 p21h-v3-qwen  running  2h13m   3.30   (unknown)   ⚠ ORPHAN
a5kfvcchakimy2 p21h-v3-qwen  running  2h13m   3.30   (unknown)   ⚠ ORPHAN
zz-registry    some-fire     gone     —       —      anima       👻 GHOST
```

- **ORPHAN** = provider 에 RUNNING 인데 registry 에 없음 → `adopt` 하거나 `stop`
- **GHOST** = registry 엔 있는데 provider 에 없음 → `forget`

`adopt` 가 ssh 엔드포인트를 채우려면 runpod GraphQL pod-detail fetch 필요 → sibling
`runpod-graphql-builtin-for-pure-dispatcher.md` 의 builtin 이 전제 (raw curl 은 cloud-guard 가
차단하므로 **wrapped 경로 필수**).

## 왜 hexa cloud 측 gap 인가

downstream 이 매번 자체 추적 파일을 굴리는 건 중복 + 휴먼-에러. `hexa cloud` 는 pod 발사의 **단일
관문**이므로 발사 시점에 registry 에 append 하는 게 자연 SSOT. 발사한 모든 pod 가 자동으로 한 곳에
모이면 orphan 이 **구조적으로 불가능**해지고, idle-autokill·watchdog 도 그 위에서 비로소 동작한다.
