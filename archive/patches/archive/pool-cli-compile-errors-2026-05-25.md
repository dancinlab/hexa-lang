---
slug: pool-cli-compile-errors
title: pool.hexa CLI compile errors — `ks` / `i` undefined at lines 703/710/720
source: demiurge ISR V3 numerical pipeline execution
status: resolved-already
discovered: 2026-05-25
resolved: 2026-05-24
priority: medium
---

> **Status (2026-05-24)**: 본 patch가 filing 되기 전에 이미 main 에서 해소됨.
> 동일 root cause (transpiler closure/iteration codegen → `ks`/`i` undeclared)
> 가 earlier patch [`pool-hexa-transpiler-ks-undeclared-2026-05-24.md`](pool-hexa-transpiler-ks-undeclared-2026-05-24.md)
> (PR #681) 에 선-filing 되었고, cold-cache race fix (`6567f8f2` → PR #687)
> 가 main 에 머지된 뒤 재현 시도시 모두 PASS:
>
> ```
> $ hexa parse /Users/ghost/.hx/packages/pool/bin/pool.hexa
> OK: parses cleanly
> $ hexa build /Users/ghost/.hx/packages/pool/bin/pool.hexa
> OK: built build/artifacts/app
> $ pool list
> mini       [ded]  mini  macos  3.00   2/16G  -  12Gi/460Gi  sudo
> ubu-1      [ded]  ubu-1 linux  6.01   2/30G  0% 748G/915G   sudo
> ubu-2      [ded]  ubu-2 linux  16.47  2/30G  0% 809G/915G   sudo
> pi5-akida  [ded]  ubuntu@192.168.50.155 linux  0.08  0/7G  - 56G/59G  sudo
> $ pool on ubu-2 "uptime"
> 08:03:09 up 2 days, 11:35, 3 users, load average: 16.47, 14.86, 8.72
> ```
>
> 직접 호출 (`pool list`) + 원격 dispatch (`pool on <host>`) 둘 다 정상.
> 본 patch는 archive 처리 (no separate fix needed).

# `pool` CLI compile errors

## Status: workable via `hexa cloud run <alias>` 우회, but blocks direct `pool list`

demiurge ISR V3 (numerical 🟢 push) 진행 중 `pool list` 직접 호출 시 compile error.

## 재현

```sh
pool list
# error: undefined identifier 'ks' at line 703
# error: undefined identifier 'i'  at line 710
# error: undefined identifier 'i'  at line 720
```

(정확한 메시지 형식은 hexa toolchain 에 의존; V3 agent 의 report 인용.)

## 우회 경로 (현재 사용 중)

`hexa cloud run <alias> -- <cmd>` 형식이 정상 동작 — V3 agent 가 `hexa cloud copy-to ubu-1` + `hexa cloud run ubu-1 -- python3 /tmp/...py` 패턴으로 3 pipeline 모두 성공.

## 영향

- `pool list` 직접 호출 불가 → demiurge V3 agent 가 `pool list` 출력을 §0 자산 매트릭스에 verbatim 인용하려는 시도 fail
- 우회 `hexa cloud run` 가능하므로 V3 자체는 진행 가능 — P1 priority
- demiurge `feedback_demiurge_assets_simulation_mandatory` 메모리 의 "pool ubu-1/2" 사용 정책에 약한 영향 (직접 `pool` 못 부르고 `hexa cloud` 우회)

## 추정 위치

`stdlib/pool/cli.hexa` (또는 비슷한 path) 의 line 703/710/720 부근. 변수 `ks` / `i` 가 declare 되지 않은 채 사용.

## 권고 수정 방향

- 우선 정확한 파일/라인 위치 grep 으로 확정
- `let ks = ...` / `let i = ...` 누락된 declaration 추가
- 또는 outer scope 의 `ks` / `i` reference 가 의도였다면 import / context 명시
- 회귀 방지: `pool list` smoke test 를 ci 에 추가

## 검증 시나리오

```sh
pool list
# expected: hosts roster table (mini · ubu-1 · ubu-2 · pi5-akida)
# actual currently: 3× undefined identifier errors
```

후속 demiurge V3 / V4 round 에서 `pool list` 의 직접 호출이 §0 documentation 의 cleaner 형태가 됨.
