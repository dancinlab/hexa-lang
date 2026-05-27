# hexa verify 호스트 매트릭스 — ubu-1 `hexa.real` 누락 (net-new) + mini-bypass 확정

**Status (2026-05-25)**: ubu-2 `verify_cli.hexa` build segfault 은 [[sidecar-skill-root-arg-and-pool-route-escalate-2026-05-25]] #3 가 트래커 — 본 파일은 **그 형제 기록**으로 (A) ubu-1 `hexa.real` 누락 (기존 패치 미포함 · net-new) + (B) mini 가 유일 작동 verify 호스트임을 tier 실측으로 확정.

**Reporter**: demiurge (CARDIO+ 메타도메인 X2/X3 cross-domain verify push · 2026-05-25)
**Severity**: medium (verify 가능 호스트가 mini 1개로 좁혀짐 · pool 분산 verify 불가)
**Affected**: `hexa verify` / `hexa run` on pool hosts (ubu-1 wrapper · ubu-2 build)
**Discovered through**: CARDIO+ X2 🔵push / X3 🟢push — 4-domain numerical recompute 를 작동 호스트에서 재실행하려다 ubu-1/ubu-2 둘 다 불가 확인, mini 로 우회 성공

## TL;DR

verify 호스트 3개 중 **mini(local macOS)만 작동**. ubu-2 는 기존 #3 segfault, ubu-1 은 신규 `hexa.real` 누락. mini 에서 `POOL_DISABLE=1` 로 라우팅 시 🔵/🟢/🟠 tier 정상 산출 — segfault blocker 는 mini 로 완전 우회되며, 🔵 escalation 은 이제 "호스트 문제" 가 아니라 "atlas F-namespace 등록 PR" 문제로 환원됨.

```
host                  hexa verify --expr        원인
mini (local macOS)    ✅ 작동 (🔵/🟢/🟠 정상)    /Users/ghost/.hx/bin/hexa 0.1.0-dispatch
ubu-1 (linux)         ❌ 실행 불가               hexa.real 누락 (#A · net-new)
ubu-2 (linux)         ❌ segfault                verify_cli.hexa build (#3 sibling tracker)
```

## #A ubu-1 `hexa.real` 누락 (net-new)

### Reproduction
```
$ pool on ubu-1 'hexa verify rubric'
/home/aiden/.local/bin/hexa: 줄 22: /home/aiden/.local/bin/hexa.real: 그런 파일이나 디렉터리가 없습니다
```
`hexa` wrapper (`/home/aiden/.local/bin/hexa`) 가 line 22 에서 `hexa.real` 바이너리를 exec 하는데 파일이 없음 → ubu-1 에서 모든 hexa 서브커맨드 실행 불가.

### 영향 / 비영향
- ❌ `hexa verify` · `hexa run` · `hexa atlas` 등 전부 불가 (ubu-1).
- ✅ python3 3.12.3 + numpy 2.4.4 정상 → **pool python sim 은 ubu-1 가능** (예: LPA V3b MR/IVW bootstrap 은 ubu-1 numpy 로 정상 실행됨).

### Fix 후보
1. ubu-1 에 `hexa.real` 재배포 (wrapper 가 가리키는 실제 바이너리 install 누락 — `hx install` / build artifact 미동기).
2. wrapper 가 `hexa.real` 부재 시 명확한 에러 + self-heal hint 출력 (현재는 generic "파일 없음").

## #B mini = 유일 작동 verify 호스트 (tier 실측 확정)

`POOL_DISABLE=1` 로 mini 강제 시 verify tier 정상 산출 (VERBATIM stdout):

```
$ hexa verify --expr sigma_k 6 1 12
  calc=12 == expected 12
  tier = 🔵 SUPPORTED-FORMAL   (number-theory closed-form 작동)

$ hexa verify --expr hill 0.5 0.001 1 0.998003992015968
  calc=0.998004 ≈ expected (|Δ|=1.11e-16 ≤ ε=1e-9)
  tier = 🟢 SUPPORTED-NUMERICAL   (bio libm recompute)

$ hexa verify --expr ivw 3 1
  tier = 🟠 INSUFFICIENT
  reason = calculator system has NO path for 'ivw'
```

### 함의
- **ubu-2 segfault blocker (#3) 는 mini 로 완전 우회됨** — `--expr` 가 mini 에서 🔵 까지 도달.
- bio/clinical claim 의 🔵 (SUPPORTED-FORMAL) 천장 = **atlas F-namespace 등록 여부**. `hill`(🟢 libm) · `ivw`(🟠 no path) 는 atlas atom 등록 전엔 auto-🔵 불가 — 🔵 escalation 은 호스트가 아니라 **atlas 등록 PR** (#658 noreflow-clinical · #665 ivw · #711 bio kernel) merge 문제.

## 권고
1. ubu-1 `hexa.real` 재배포 (#A) + ubu-2 `verify_cli.hexa` build segfault 수정 (#3) → pool 분산 verify 복구.
2. 복구 전까지 **mini 를 canonical verify 호스트로 문서화** (`POOL_DISABLE=1 hexa verify …`).
3. atlas F-namespace 에 bio fn (hill · pk_2comp · power_2sample · ivw) 등록 PR → 🔵 trajectory enable (mini 에서 `--expr … --absorb` 로 등록 가능).

## ref
- demiurge `CARDIO+/X2_blue_push.md` · `CARDIO+/X3_green_push.md` (mini 실측 verbatim 전문)
- sibling: [[sidecar-skill-root-arg-and-pool-route-escalate-2026-05-25]] (#3 ubu-2 segfault) · [[bio-verify-kernel-extension-2026-05-25]] · [[verify-cli-supercon-fns-2026-05-24]]
