# RFC — 컴파일 파이프라인 rate-distortion 계측 (2-클래스 모델)

- **상태**: **Draft** (미착수 promote; P1 MVP 코드는 랜딩·검증됨)
- **작성일**: 2026-05-18
- **RFC 번호**: 미할당 — `proposals/`와 `inbox/rfc_drafts_*`가 독립 numbering으로
  경합 중(공유 repo). promote 시 충돌 없는 번호 배정. 파일명은 서술형 고정.
- **트리거**: Google TurboQuant (2026-03, KV-cache post-training quantization,
  arXiv:2504.19874) — "표현을 의미 보존한 채 압축" 발상의 컴파일러 전이.
- **선행 연구 앵커**: Leroy CompCert (CACM 2009, observational equivalence) ·
  Keep & Dybvig nanopass (ICFP 2013) · Tishby Information Bottleneck
  (arXiv:1503.02406) · Kolmogorov full-employment theorem · MLIR dialect
  conversion legality.
- **영향 영역**: `compiler/quant_meter/` (신규) · `compiler/main.hexa` (verbose
  게이트 훅) · `self/module_loader.hexa` (경로 정규화 — 부수 수정, 랜딩됨) ·
  본 문서.

---

## 1. 동기

컴파일이란 **의미는 보존한 채 표현의 자유도(degrees of freedom)를 단계적으로
깎아내는 양자화(progressive quantization)** 과정이다. 소스 코드는 같은 의미를
무수히 많은 방법으로 표기할 수 있다(공백·이름·슈가·타입 추론·추상 제어구조).
기계어는 그 자유도가 거의 0이다. TurboQuant가 KV 캐시의 비트폭을 의미 손실
없이 깎듯, 컴파일러는 IR의 "표현 자유도"를 의미 손실 없이 깎는다.

이 RFC는 그 과정을 **측정 가능한 두 양**으로 계측하는 아키텍처를 제안한다.
선행 연구 조사 결과 이 프레이밍은 **통합 계측 도구로서는 신규**이나 각 부품은
다른 이름으로 이미 존재한다 — 정직한 포지셔닝(§7)을 명시한다.

## 2. 핵심: 2-클래스 모델

`compiler/main.hexa`(RFC-018 §2) 파이프라인 감사 결과, 단계는 **두 클래스**로
직교 분해된다 (MLIR dialect-conversion legality 모델로 교차 검증됨):

| 클래스 | 정의 | 본 파이프라인 사례 |
|---|---|---|
| **transform** | 표현을 바꿈. rate 하강. | lex · parse · ast_to_hir · hir_to_mir · optimize · codegen · emit |
| **gate** | 검증만. 표현 불변. distortion만 측정. | target_gate · resolve(S1) · bind(S2) · types(S3) · units(S5) · citation(S8) |

`compiler/main.hexa`에서 resolve/bind/types/units/citation은 **전부 `diags`
배열만 반환**(표현 미변경) — gate가 이미 코드로 존재한다. 즉 distortion 게이트
인프라의 절반은 발명이 아니라 *명시화*다.

## 3. 결정 (Decision 1–4)

### 결정 1 — 단일 스칼라 R 폐기, `S`(크기)와 `F`(자유도) 분리

HIR→MIR에서 표현이 *길어진다*(구조적 → SSA 3-주소). "크기"와 "자유도"가
발산하므로 단일 rate로는 둘 다 못 잡는다.

| | `S` — 크기/비용 | `F` — 자유도 (★불변량) |
|---|---|---|
| 정의 | IR 노드 수 (→P2: HXC 직렬화 바이트, `g_hxc` 정렬) | freedom-kind별 카운터 **벡터** |
| 단조? | **아니오** (HIR→MIR 증가 정상) | **예, 성분별 비증가** |
| 용도 | 관측성·회귀탐지·incremental-cache 입도 | transform/gate 불변량 계약 |

### 결정 2 — `F`는 스칼라 합이 아니라 벡터, 성분 ~9개 (6 아님)

성분 합산은 사과+오렌지(+bits 환산)이며 어느 자유도종이 회귀했는지 은폐한다.
**합산 금지 — 성분별 불변량**. "마법의 6"은 소멸: 자유도종 taxonomy에서
~9개가 창발(어휘·묶음·이름·타입·슈가·추상·중복·자원·인코딩). **고정 stage
수는 기각** — LLVM(~2)·MLIR(open-ended)·Swift(2) 전부 emergent. n=6은
*관찰적 일치*로만 기록(`g3` 준수: derivation 아님).

### 결정 3 — 단위는 bits 아닌 카운트. P1 = 분석 0짜리 3개

불변량(단조 비증가)에 카운트면 충분(카운트 단조 → 임의 단조함수 단조).
**simplicity-first**. P1 = `S`(노드수) + 분석 불필요한 순수 트리워크 3종:

| F성분 | 세는 것 | 죽이는 transform | Phase |
|---|---|---|---|
| `F_name` | DefId 미해소(문자열) ident 출현 | bind→DefId | **P1** |
| `F_type` | concrete monotype 미확정 expr | type-attach | **P1** |
| `F_ctrl` | 미하강 구조적 제어 (if/while/for/match) | hir_to_mir | **P1** |
| `F_redund` | 죽은·재계산가능 stmt | optimize (--opt 의존) | P2 |
| `F_sched` | 블록내 재배열가능 stmt (stmts − dep-chain) | codegen 스케줄링 | P2 |
| `F_res` | 물리레지스터 미바인딩 virtual local | regalloc | P2 |
| `F_lex`·`F_sugar`·`F_enc` | (퇴화적/registry 필요) | lex/desugar/emit | defer |

### 결정 4 — 측정 기계: `meter(ir) -> RateVec`

`compiler/quant_meter/meter.hexa`: 순수·결정론적 트리워크. `RateVec { stage,
s_nodes, f_name, f_type, f_ctrl }`. transform 경계 i→i+1에서
`RateVec[i+1].f_k <= RateVec[i].f_k` 전 성분 단언(위반 = 자유도 추가한 stage
= 설계 버그, P2에서 HX2600대 진단). gate 경계는 `RateVec` **불변**(identity)
— 이것이 "이 stage가 transform이 아니라 gate임"을 *검증*하는 방법.

결정론은 interp↔compiled 발산(`g_inbox_dual_track`) 국소화에 직결: 양쪽
`RateVec`가 byte-identical이어야 하며, 어긋나는 stage가 발산 지점.

## 4. 측정 (measurement-anchored)

합성 IR 검증(`compiler/quant_meter/meter_test.hexa`, `hexa build`→실행 PASS).
케이스: `fn classify { if (n) { a } else { while (b) { } } }`.

```
    stage   S(nodes)   F_name   F_type   F_ctrl
    -----------------------------------------------
    ast           10        3        9        2
    hir           10        0        0        2
    mir           13        0        0        0
```

설계 예측의 실증:
- `F_name` 3→0→0 · `F_type` 9→0→0 — **AST→HIR에서 사망**. 두 성분이 *같은*
  transform에서 동시 붕괴 = `ast_to_hir` **과부하의 정량화**(한 패스가 2개
  자유도종 제거 — nanopass single-task 위반, 패스 분할 후보).
- `F_ctrl` 2→**2**→0 — AST→HIR **평평**(HIR은 구조적 제어 보존), HIR→MIR에서
  사망. 자유도가 죽는 transform이 성분별로 다름을 입증.
- `S` 10→10→**13** — **상승**. S≠자유도 입증 → 결정 1의 2-트랙 분리가 필수였음.

합성 IR을 쓴 이유: 실코드 측정은 전체 `compiler/main.hexa` 자체빌드가 필요한데
이것이 **무관한 사전 결함**(§6 #1)으로 막혀 있다. 합성 anchor는 기대값이
정확히 알려져 RFC 용도로는 오히려 더 견고하다(RFC 044 measurement-anchored
패턴과 동일 정신).

## 5. 정직한 포지셔닝 (선행 연구)

| 우리 발상 | 이미 존재하는 이름 | 엄밀도 |
|---|---|---|
| transform/gate 2-클래스 | MLIR dialect-conversion legality | 엄밀(검증된 구조) |
| `D=0` (의미 보존) | CompCert forward-simulation on observable trace | **엄밀·증명가능** |
| "1 transform = 1 자유도종" | nanopass single-task 원칙 | 검증된 설계규칙 |
| stage당 (rate) 계측 | LLVM `Statistic`/`-stats` 플러밍 | 표준 |
| rate-distortion 어휘 | TurboQuant / RD 이론 | **느슨 — lens 전용** |

- **`D=0`은 RD-metric(MSE)이 아님**. distortion은 실수 손실이 아니라 0/1
  의미 술어 → "각 transform이 observable trace 보존 forward-simulation을
  허용한다"(CompCert 용어)로 진술. MSE 기계 수입 금지.
- **`R`(rate)은 비계산적**(Kolmogorov full-employment theorem) → `F`는
  명시적 operational proxy(카운트, 참 엔트로피 아님). `g3` real-limit 앵커.
- **Information Bottleneck은 느슨**: IB는 relevance를 compression과 *교환*하나
  올바른 컴파일러는 그 교환을 *금지*(D=0 hard constraint). 컴파일러 = IB의
  퇴화적 hard-constraint 코너.

권장 문구: *"RD 어휘는 TurboQuant에서 빌린 expository lens. 정합성 기반은
CompCert식 observational equivalence이며 증명 대상은 후자다."*

## 6. 구현 노트 — 빌드경로 사전 결함 3건 (격리 확인)

quant_meter 작업 중 발견. 전부 **quant_meter와 무관**, baseline 재현으로
사전 결함 확정.

1. **#1 `compiler/main.hexa` 전체 자체빌드 차단** — macOS가 interp 기반
   `module_loader`를 전체 컴파일러 번들 flatten 중 **OOM-kill**(`Killed: 9`,
   `HEXA_MEM_UNLIMITED`로도 OS가 죽임). preprocess 실패 → raw-src fallback →
   hexa_v2가 `Severity` enum의 `#define` 미생성 → clang undeclared. 알려진
   interp-retirement 벽이며 surgical fix 불가(macOS 한정). 진짜 해결: ubu
   (Linux, 31GB) 라우팅 또는 module_loader 메모리 footprint 축소 캠페인 —
   둘 다 본 RFC 스코프 밖. main.hexa 훅은 배선·parse-clean이나 end-to-end
   실측은 이 벽 너머.
2. **#2 flatten이 diamond import를 dedup 안 함** — `ml_resolve_full`이 경로
   미정규화(`../` 그대로) → 같은 파일이 다른 키로 보여 ① 이중 포함(C 구조체
   생성자 redefinition) ② 충돌 키 이후 도달 파일 누락. **수정 랜딩**:
   `self/module_loader.hexa`에 `@pure ml_canon_path` 추가(whitelist 연산만:
   len/substring/split/push/join/index — `.truncate` 회피), `ml_resolve_full`
   정규화 래핑. **검증**: `meter.hexa`를 올바른 diamond import로 되돌려도
   redefinition·path-traversal 경고 0, `meter_test` PASS. 부수효과: 기존
   `*_test.hexa`(다이아몬드로 interp 전용이던)들의 `hexa build` 해금 —
   interp-retirement 이득. module_loader는 빌드 시 *인터프리트*되므로 hexa_v2
   재빌드 불요(저위험·가역).
3. **#3 module_loader 4GB soft-cap** — `HEXA_MEM_UNLIMITED=1`이
   `module_loader_env_prefix`의 공인 operator override. 단 macOS의 진짜
   한계는 OS OOM-kill(env로 우회 불가). 기본 캡 변경은 고위험 → env override
   채택·기록(별도 결함 아님).

## 7. 스코프

- **P1 (랜딩·검증)**: `meter.hexa`(S + F_name/F_type/F_ctrl) · `main.hexa`
  verbose 게이트 훅 4곳 · `meter_test.hexa`(합성 검증 PASS) · `#2` canon 수정.
- **P2 (미래)**: `F_redund`/`F_sched`/`F_res`(경량 분석) · `S`의 HXC 직렬화
  (`g_hxc` 정렬) · transform-경계 단조 단언을 strict-lint에 HX2600대 진단으로
  배선 · gate-identity 자동검증 · interp↔compiled RateVec diff 국소화 도구.
- **비스코프**: `#1` macOS interp OOM 벽(interp-retirement 캠페인 소관) ·
  bits 환산 · 자유도종 9개 전수 카운터 · `ast_to_hir` nanopass 분할(별도 RFC).

## 8. 반증자 (principle 5)

"6 stage, 각자 1 자유도종"은 코드 감사 + 독립 2개 연구 에이전트가 **3중
반증**. 표현 전이는 6(text→tok→AST→HIR→MIR→LIR→asm)이나 자유도종은 ~9이며
정렬 안 됨. 본 RFC는 stage 수를 못 박지 않고 자유도종 taxonomy에서 *창발*
시키며, rate 측정값 자체로 "각 stage가 제 몫을 하는지"를 반증한다(rate를
안 떨구는 transform = 잉여).

---

## 9. 의사결정 게이트 (사용자)

- promote 시 RFC 번호 배정 (충돌 회피 — §머리말).
- P2 착수 우선순위: (a) strict-lint HX2600 게이트 (b) `ast_to_hir` nanopass
  분할 (c) interp↔compiled RateVec diff 도구 — 중 택.
- `#1` ubu 라우팅 승인 여부: 미커밋 변경의 공유 브랜치 commit/push 또는
  ubu /tmp fresh-clone 파일-ship 필요 (공유상태 액션 — 확인 요).
