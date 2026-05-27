# compiler/quant_meter — rate-distortion compile-pipeline instrumentation

컴파일을 *progressive quantization* 으로 모델링하는 계측 서브시스템. 각
transform 경계마다 표현 자유도(F)가 **단조 비증가**해야 하며, 위반은
`HX2600` 진단으로 빌드를 실패시킨다(strict-lint).

설계·연구 근거 전체는 [`RFC.md`](./RFC.md). 이 README 는 오리엔테이션.

## 디렉터리

| 파일 | 역할 |
|---|---|
| `meter.hexa` | 코어 API — `RateVec` · `QuantViolation` · `meter_ast/hir/mir` · `quant_check_pair` / `quant_ok` · `quant_report`. tree-shaped import(자족, stock loader 로 빌드). |
| `meter_test.hexa` | 합성 IR 단위테스트. RateVec 측정 + HX2600 게이트 회귀(6/6 PASS). **Decision A 최종 산출** 검증 진입점. |
| `meter_probe.hexa` | 슬림 실코드 probe (lex+parse+lower+meter only). 인프라 가용 시 재사용. |
| `RFC.md` | 설계 SSOT — 2-class 모델 · 정직한 포지셔닝 · 라운드-2 선행연구 (Cousot-Cousot transformation-by-abstraction · nanopass · MLIR verifier · TurboQuant/PolarQuant) · P2 정식 앵커. |
| `README.md` | 이 파일. |

## 2-class 모델 (요약 — 자세히는 RFC.md §2)

| class | 정의 | 예 |
|---|---|---|
| **transform** | IR 변형, rate↓ | lex · parse · ast_to_hir · hir_to_mir · codegen · emit |
| **gate** | 검증만, 표현 불변(identity) | target_gate · resolve · bind · types · units · citation |

## 두 트랙 (RFC.md §3)

- **S** — 크기 (P1: node count · P2: HXC serialized bytes). **NOT monotone**
  (SSA elaboration 이 증가시킴). 관측 · 회귀 신호만.
- **F** — *벡터*: `F_name` · `F_type` · `F_ctrl` (P1) + `F_redund` · `F_sched`
  · `F_res` (P2). **transform 경계마다 성분별 단조 비증가** = HX2600 불변량.
  스칼라 합산 금지(어느 자유도종이 회귀했는지 은폐 + 단위 혼합).

## 빌드·검증

import 그래프가 작고(meter + IR 구조체만, no diag/atlas) tree-shaped 라
stock `hexa build` 로 빌드된다. macOS 는 `HEXA_MAC_BUILD_OK=1` 필요.

```bash
HEXA_MAC_BUILD_OK=1 hexa build compiler/quant_meter/meter_test.hexa -o ~/qm_build/meter_test
~/qm_build/meter_test
```

기대 출력 (Decision A 최종 측정 — 합성 IR `fn classify { if (n) { a } else { while (b) { } } }`):

```
    stage   S(nodes)  F_name  F_type  F_ctrl
    ast          10       3       9       2
    hir          10       0       0       2     ← F_name·F_type die at ast_to_hir
    mir          13       0       0       0     ← F_ctrl dies at hir_to_mir; S RISES

  PASS  AST/HIR/MIR RateVec
  PASS  F-monotonicity (non-increasing across transforms)
  PASS  gate: ast->hir clean · hir->mir clean · F_ctrl rise flagged ·
        F_name rise flagged · F_type rise flagged · quant_ok flat
PASS: quant_meter P1 counts verified.
```

`S` 10→10→**13** 상승이 `S≠자유도` 입증 → 2-track 분리가 필수였음.
`F_name`+`F_type` 동시붕괴(AST→HIR)가 `ast_to_hir` 과부하의 정량화 (nanopass
single-task 위반 — P2-b 분할 후보).

## API (pub 시그니처)

| 함수/타입 | 용도 |
|---|---|
| `meter_ast(m: Module) -> RateVec` | AST 단계 측정 |
| `meter_hir(m: HModule) -> RateVec` | HIR 단계 측정 |
| `meter_mir(m: MModule) -> RateVec` | MIR 단계 측정 |
| `quant_check_pair(prev, cur) -> QuantViolation` | HX2600 게이트 로직 — 첫 회귀 성분 반환 |
| `quant_ok(prev, cur) -> bool` | 위 결과 boolean 래퍼 |
| `quant_report(a, h, m)` | 3-row 테이블 stderr 출력 + 회귀 경고 |
| `pub struct RateVec` | `{stage, s_nodes, f_name, f_type, f_ctrl}` |
| `pub struct QuantViolation` | `{hit, component, from_stage, to_stage, before, after}` |

## 상태 (2026-05-19)

| 항목 | 상태 |
|---|---|
| P1 MVP code | LANDED `ce431e2f` |
| meter.hexa 자족 import (drift-fix) | LANDED `76d38693` |
| RFC.md (라운드-2 연구 통합) | LANDED `4331befa` |
| 합성 IR 검증 | meter_test 빌드+실행 PASS = **Decision A 최종 산출** |
| 풀 self-build 실측 | **별도 사이클로 이관** — ≤31GB pool 호스트 全 interp OOM (RFC.md §6, [[compiler-selfbuild-blockers]]). >31GB 또는 streaming module_loader 필요. |
| `compiler/main.hexa` HX2600 strict-lint 라이브 배선 | sibling-branch drift, 별도 사이클 |

## 다음 (RFC.md §10 결정 게이트)

P2 권장 우선순위:

1. **`F_sched`** — #P-complete(Brightwell-Winkler), 가장 깔끔한 정식 앵커.
2. `ast_to_hir` nanopass 분할 — P1 측정으로 정량화된 과부하 해소
   (Patterson-Ahmed ICFP'19 + CakeML one-IL-per-feature).
3. interp ↔ compiled RateVec diff 도구 — interp 재폐기 가속.

풀-빌드 실측은 인프라(>31GB 호스트) 또는 module_loader 메모리 footprint
축소 별도 캠페인 — 사용자 결정 사항.

## 거버넌스 앵커 (g3 real-limit)

- Kolmogorov full-employment theorem → R 비계산성 → F 는 명시적 카운트 proxy
- Brightwell-Winkler 1991 #P-completeness (F_sched 정의)
- Pereira-Palsberg post-SSA NP-completeness (F_res 정의)
- CompCert observational equivalence (D=0 의미)
- Cousot-Cousot POPL'02 transformation-by-abstraction (단조-F = α-monotonicity)
