# L3-M0 재측정 verdict — HEXA_BORROWCK (M3+M4) HX3014 vs #4088 walker

**Run**: aiden · `~/hx-m0` @ `f91712309` (feat/own-l3-m4-nll = M3 intra-block loan + M4 cross-block NLL) · 2026-07-04
**Compare**: `state/hexa-own/l3_m0_measurement.md` (원본 M0 · #4088 walker HX2007 column)

## Build (idle aiden)
- `release_build` rc=0 · **104s** (아이들 호스트 = 이전 포화 대비 급행)
- `build_aprime.sh` rc=0 · aprime_cc = 2,926,592 B

## Corpus tally — HEXA_BORROWCK=1 → HX3014

| file | rc(ON) | HX3014(ON) | HX3014(OFF·control) | #4088 HX2007(원본) |
|---|---|---|---|---|
| stdlib/argparse.hexa | 2 | 0 | 0 | 9 |
| stdlib/bigint.hexa | 2 | 0 | 0 | 39 |
| stdlib/bytes.hexa | 2 | 0 | 0 | 13 |
| stdlib/channel.hexa | 2 | 0 | 0 | 2 |
| stdlib/alloc/json.hexa | 2 | 0 | 0 | 12 |
| stdlib/alloc/collections.hexa | 1 | 0 | 0 | 31 |
| self/ast.hexa | 2 | 0 | 0 | 1 |
| self/attrs/own.hexa | 2 | **1** | 0 | 26 |
| compiler/check/types_test.hexa | 1 | 0 | 0 | 294 |
| compiler/check/bind.hexa | 2 | 0 | 0 | 260 |
| compiler/check/borrowck_test.hexa | 1 | 0 | 0 | 265 |
| **합계** | | **1** | **0** | **~950** |

- **branch canonical probes** (`compiler/check/borrowck_test.hexa`): flag ON rc=0 ALL PASS · flag OFF rc=0 ALL PASS — M3 판별기 + M4 cross-block liveness 계약 유지.
- **OFF-control 전부 0** → byteeq-neutral 재확인 (기본 경로 무접촉).

## Verdict — 정직 해석 (★ 카운트 대조는 like-for-like 아님)

**HX3014 합계 1 vs #4088 ~950**은 "M3+M4가 #4088의 FP 950개를 제거했다"는 **직접 증명이 아니다** — 두 검사기의 발화 조건이 다르기 때문:

- **#4088 walker**: `@own` 무관하게 **모든 move**를 검사 → 원본 M0에서 fp_callarg / fp_arr_alias_read 패턴으로 **FP 포화**(~950, HX2008=0). 실코퍼스 스팟체크가 전부 오탐(`_nlimb(a)` 같은 순수 length helper를 by-value move로 오인).
- **M3+M4 HEXA_BORROWCK**: **`@own`-gated** — 어노테이션된 move의 use-after-move + shared-XOR-mut만 발화. 원본 M0에서 측정된 **코퍼스 `@own` 채택 = 0** → 무어노테이션 코퍼스에서 HX3014=0은 **설계 정합**(L2 HX3012=0과 동일 구조), FP 제거의 증거가 아님.

따라서 재측정이 **확증하는 것**:
1. **byteeq-neutral** — OFF-control 전 파일 0.
2. **FP-flood 없음** — #4088처럼 무어노테이션 코퍼스에 950개를 쏟지 **않음**(gated 설계라 조용함). 사용자가 실수로 얻는 오탐 0.
3. **정밀도는 probe 계약으로 검증** — borrowck_test.hexa both-mode PASS가 판별기/cross-block liveness의 참발화·거짓미발화 오라클(코퍼스 카운트가 아니라 이쪽이 precision 증거).

**정직한 한계**: 무어노테이션 코퍼스 tally는 정밀도를 **직접** 보일 수 없다(발화 트리거인 `@own`이 없음). `@own` 주입 FP-probe 매트릭스(fp_callarg/fp_arr_alias_read를 `@own`으로)를 M3+M4에 돌려 #4088의 오탐이 사라지는지가 남은 정밀도 실측 — 후속.

**self/attrs/own.hexa=1**: 코퍼스 유일 `@own` 언급 파일의 1건 — TP/FP 판별은 rc=2(부분빌드)라 미확정, 후속 스팟체크 대상.
