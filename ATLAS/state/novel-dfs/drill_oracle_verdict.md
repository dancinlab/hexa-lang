# drill `--verifier` exact-int oracle — 측정 verdict (2026-06-26)

`hexa kick`(=`hexa drill`)이 "진짜 새것을 찾는가" 검증의 마무리 — drill의 미배선 `--verifier`
훅에 **진짜 exact-integer 검증 oracle**(`drill_verifier_oracle.py`)을 붙여 live 측정했다.

## oracle = 진짜 검증엔진 (rubber-stamp 아님)

`--selftest 20000` 게이트 (산술함수 = `blue_harvest_12fn.py:12-21` 정확복제):

| 게이트 | expr | 결과 |
|---|---|---|
| G1 (ATLAS @F 재발견) | `phi*J2 = n*psi` | PASS · solset=[4] bounded-unique |
| G2 | `phi*J2 = sopfr*psi` | PASS · solset=[4] |
| G3 | `phi*phi = rad*Om` | PASS · solset=[4] |
| C1 (universal → 거부) | `n*n = n*n` | PASS · solset=[2,3,4,5,6] non-unique |
| C2 (미파싱 → 거부) | `sig = bogusfn` | PASS · 거부됨 |
| C3 (무해 → 거부) | `phi*tau = sig*sig` | PASS · solset=[] |

→ `RESULT: PASS` — 참 항등식은 잡고 거짓/universal/미파싱은 거른다. 진짜 verifier.

## live drill 측정 = drill은 verifiable 발견 0

`hexa drill --seed "twin_prime_gap_conjecture_density" --rounds 1 --verifier <oracle> --verifier-cand-cap 1000`:

```
DRILL_VERIFIER {"round":1,"verdict":"continue","rationale":"0_verified/0_identity/625_noise_of_625"}
```

| 후보 total | identity(파싱됨) | VERIFIED(bounded-unique) | noise(비-항등식) |
|---:|---:|---:|---:|
| 625 | 0 | **0** | 625 |

drill 후보는 전부 `closure(sigma.sigma_n6 = 12.0, …)` 류 = seed-hash·고정상수의 산술조합
문자열 → 산술함수-of-n 항등식 문법에 하나도 안 맞음 → exact-int 검증 대상 0개.

## end-to-end pass 경로도 작동 (loop는 멀쩡, 입력이 노이즈)

| 케이스 | 입력 | verdict |
|---|---|---|
| A | drill 실제 후보(noise) | `continue` |
| B | 진짜 항등식 `phi*J2 = n*psi` 주입 | **`pass`** (1_verified_of_2) |
| C | `--verifier-strict` + pass | `VERIFIER_PASS` · `verifier_stopped:true saturated:true` (authoritative halt) |

## 결론

🧱 측정 벽: **verifier는 진짜인데 drill 생성기가 verifiable한 걸 안 내놓는다.** 검증부가
부재해서 발견을 못 하는 게 아니라, **생성기가 노이즈를 낸다.** 진짜 발견 루프를 완성하려면
다음 레버는 verifier가 아니라 **생성기 측** — smash가 산술함수-of-n 항등식 문법의 후보를
emit하도록(즉 `state/novel-dfs/*_hunt.py`가 하는 일을 drill 안에서) 고쳐야 한다(aiden 빌드 ·
codegen 변경 · 별 캠페인).

## 배선 상태 (wire-to-prod)

- oracle = `--verifier "python3 …/drill_verifier_oracle.py"` 로 **opt-in 배선 작동**(측정 완료).
- default flip(plain `hexa kick`이 자동으로 이 oracle을 타게)은 `drill_default_opts()`
  (`compiler/drill/drill.hexa:98`) 편집 = **aiden 빌드 + byteeq 필요**(미배선 default · follow-on).
- native-canonical-default polarity 준수: 외부 oracle은 opt-in 플래그로만, default는 native 유지.
