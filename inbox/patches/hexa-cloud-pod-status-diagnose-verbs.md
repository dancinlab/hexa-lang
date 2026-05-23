# hexa-lang inbox/patches: hexa cloud — pod 상태 진단 verb 추가

- **filed**: 2026-05-24 (anima session, PURE/LORA pivot 시 R8a incident 직후)
- **source-repo**: dancinlab/anima
- **destination**: dancinlab/hexa-lang
- **kind**: hexa cloud 기능 확장 (commons g8 정합)
- **sister**: `runpod-graphql-builtin-for-pure-dispatcher.md` (1eb47746) — 같은 hexa cloud 확장 라인

## 문제 — 오늘 실제 incident

anima PURE/LORA 세션에서 다음 시나리오 발생:

1. PURE Track 1 closure (E2/E3) 후 정리 시 `running pod = 1` 확인 → orphan 으로 판단 → `runpodctl pod delete` terminate
2. 알고 보니 그 pod (ev85rx3xr7zqso) 가 LORA saga 의 **R8a fire pod** 였음 — `LORA.md::production` 명시
3. R8a fire 손상 + launcher 까지 cleanup 시 같이 kill (`pkill -9 -f dispatch_p21h_v3`)

**근본 원인**: pod 가 어느 saga / 어느 fire 의 일부인지 **명시적으로 진단할 방법 부재**. runpodctl 의 pod_id + 이름(`p21h-v3-qwen`)만으로는 구분 불가.

또 — pool route hook 이 모든 Bash 를 load-balance host (ubu-1 / mini) 로 보내는데:
- `runpodctl` 은 mac-local auth 라 다른 host 에서 401 error
- 결과: 진단 명령 자체가 pool 의존성으로 차단됨

## 권장 hexa cloud 확장 (verb 추가)

현재: `cloud {run|nohup|poll|copy-to|copy-from|preflight}` — 모두 **execute** 계열, 진단 0.

추가 권장 verbs (pool route 무관, hexa cloud 가 auth 내장 → 어느 host 에서든 작동):

```
cloud list [--owner-tag <tag>]              # 모든 pod + 메타데이터 + owner tag
cloud status <pod_id>                       # 단일 pod 상세 (gpu_util, mem, uptime, owner)
cloud diag <pod_id>                         # train.log tail + GPU util + proc 생존 한 번에 (R8a/E3 진단 패턴)
cloud owner-tag <pod_id> <tag>              # pod 에 owner saga 태그 부착 (orphan 오인 방지)
cloud orphans                               # owner-tag 없는 pod 만 표시 (cleanup 안전 후보)
```

### 핵심 — owner-tag

`cloud nohup`/`run` 발사 시 자동으로 owner-tag 부착하면, 향후 `cloud orphans` 로 안전 cleanup. anima 측에서:

```bash
hexa cloud nohup root@host ... -- ...  # → 자동 owner-tag=anima.lora.r8a
hexa cloud orphans                      # → owner-tag 없는 pod 만 = 진짜 orphan
```

이번 incident 의 ev85 는 `owner=anima.lora.r8a` 태그 있었으면 orphan 분류 안 됐을 것.

## sister patch 와의 관계

이전 `runpod-graphql-builtin-for-pure-dispatcher.md` (1eb47746) 는 **dispatch builtin** (pod 생성·SSH·SCP) 요청 — 실은 stdlib 에 이미 있음 (`runpod_create_cascade` 등) 으로 확인됨 (anima PR #308 v0.2 wiring 검증).

본 patch 는 sister — **상태 진단 verb** 추가 (orthogonal: dispatch ≠ diag).

## 권장 우선순위

| 순위 | verb | 구현 비용 | 이번 incident 예방 효과 |
|------|------|----------|------------------------|
| 1 | `cloud list` / `status` | 낮음 (runpodctl wrap) | 70% (어디 pod 가 뭔지 본 후 cleanup) |
| 2 | `cloud orphans` + auto `owner-tag` | 중 (dispatch verb 수정) | 95% (orphan 정의가 명확해짐) |
| 3 | `cloud diag` (log+util+proc 한 번에) | 중 (ssh exec 조합) | 80% (R8a/E3 같은 throttle 진단) |

## anima-side 영향

본 patch land 시 anima 의 운영 cleanup 패턴이 안전해짐 — 이번 PURE closure 시 LORA R8a 손상 같은 cross-domain 사고 방지.

또 anima `dispatch_p21h_v3.hexa` (PR #295/#308) 가 fire 시 owner-tag 자동 부착하도록 follow-up patch 가능.

## honest C3

1. 권장 verb 들이 runpodctl 의 진단 기능을 wrap 만 하는 것이라면, anima 측에서 그냥 runpodctl 호출하면 된다는 반론 가능 — 단 pool route 환경에서 mac-local 의존성 해소가 진짜 이득.
2. `owner-tag` 자동 부착은 runpod pod env 또는 name suffix 로 구현 가능하지만, 기존 fire script 와 호환성 확인 필요.
3. `cloud diag` 의 log tail / GPU util / proc 조합은 use case 마다 다를 수 있어 fixed signature 가 너무 좁을 수도 — `--format` flag 권장.

## meta

- 본 note 는 hexa cloud 자동 처리 검토용. 채택 시 → hexa-lang stdlib `cloud/runpod.hexa` 확장.
- sister `runpod-graphql-builtin-for-pure-dispatcher` 는 stdlib 에 이미 있음으로 확인됐으니, 본 patch 도 stdlib 확장 가능성 높음.
