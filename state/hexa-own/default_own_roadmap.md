# HEXA-OWN L4 — default-ownership (Rust move-by-default) roadmap · SSOT

사용자 지시(2026-07-04): HEXA-OWN을 `@own` opt-in이 아니라 **기본(default) Rust-parity 소유권**으로. semantics 선택 = **A (풀 move-by-default)**. 설계 = Fable(bhuz1w6bl·full=`state/hexa-own/default_own_roadmap_fable.md`).

## 정직 프레이밍 (crux — arena-vacuous는 해결이 아니라 스케줄됨)
"Rust-standard safety by default"는 두 축으로 분해:
- **discipline 축**(무엇을 검사): move/aliasing-XOR-mutation 컴파일타임 강제·zero 런타임 — **지금 가능**(M3/M4 loan pass가 정밀·observe-only).
- **stakes 축**(위반의 대가): Rust=UB(메모리 안전). hexa bump-arena(scope 중 free 없음)에선 borrow 위반이 **use-after-free 불가** → enforcement는 지금 **correctness lint**(실 logic-bug 클래스, 진짜지만 메모리안전 아님). memory-safety로 승격 = **PREREQ-X**(비-arena free-tree `HEXA_STREAM_RECLAIM` default 착지)에서만. 상호의존: allocator flip은 강제된 aliasing discipline을 **선행조건**으로 요구.

## 2-lane 사다리 (각 렁 opt-in·byteeq-neutral OFF)

### Lane B — `HEXA_BORROWCK` default-ON, advisory→fatal (semantics 무변경·static-types flip 재현)
| 렁 | 내용 | 게이트 |
|---|---|---|
| **B0**(now) | `HEXA_BORROWCK_STRICT=1` opt-in fatal — HX3014 severity 승격(_emit_hx3014서 Severity::Error override·builder contract 허용). byteeq-neutral OFF | PR byteeq 3-target |
| **B0.5** | M4(feat/own-l3-m4-nll)+#4470 @own stack 머지 (cross-block·Rule 2 flip-blocking) | M4 probe matrix |
| **B1** | corpus census — loan pass가 자기 마이그레이션셋 열거(aprime_cc·~1.11M LOC pool). O(dozens) 기대(>100=분류실패). true hazard=일반 PR로 fix | 0 HX3014·수치 캡처 |
| **B2** | vehicle 배선(§vehicle) | gen2 build서 HX3014·OFF byte-id |
| **B3** | default-ON Warning band(`_bck_on = env != "0"` opt-OUT·polarity 유지) | B1 clean·byteeq 3+faithful+smoke·gen2-native parity |
| **B4** | Warning→Error(catalog severity·`@grace` waiver) | 별도 PR·revert-on-RED |

### Lane A — move-by-default + borrow (사용자 A·PREREQ-X gated)
| 렁 | 내용 | 게이트 |
|---|---|---|
| **★A1**(첫 렁) | `&T`/`&mut T` **surface** — type-pos name-fold(`*T` 선례 parser.hexa:374-399)·expr-pos parse_unary Amp `UnOp text="&"`. **양파서(self/parser.hexa 동시)**·신규 TokenKind/ExprKind 0. self-host이 "공유"를 말하는 수단 = move 전 필수 | byteeq(미사용 GREEN)·양백엔드 |
| **A2** | would-move census(`HEXA_BORROWCK_CENSUS=1`) — handle-copy edge 카운트=자기호스트 마이그레이션 worklist(측정) | worklist 파일 |
| **A3** | `HEXA_MOVE_DEFAULT=1` opt-in: aggregate `let b=a`가 a 무효화(Rule-2 재사용)·RHS `&a`면 예외. worklist file-by-file(self-host 우선·gen3≡gen4 매 커밋) | flag 하 clean·byteeq·parity |
| **PREREQ-X** | free-tree allocator default flip — 별도 캠페인. borrow≥B4 신뢰 필요(상호의존) | 별도 SSOT |
| **A4** | `HEXA_MOVE_DEFAULT` default-ON(F5 mechanics)·PREREQ-X 후에만 유의미. place projection(field-disjoint)=별도 schema-add | all-3-target+smoke·revert-on-RED |

## vehicle (gen2 ship 경로)
gen2 hexat는 MIR 없어 영원히 0 — 포트=영구 dual-frontend drift(기각). 정답=aprime advisory child(`fix/ownlint-shipping-advisory` 75a4c3724가 HEXA_OWN_LINT로 이미 구현): r1 그 branch 확장해 cmd_build advisory가 HEXA_BORROWCK도 트리거+양 env 자식 전달·`self/main.hexa:4431 _ne` un-swallow. r2 `--emit=check`(compiler/main.hexa·빈-atlas branch로 RSS 회피). r3 cmd_build default-invoke(advisory-rc·2/10 aprime rc=1 parse-parity 선census).

## 정직 walls
1. arena-vacuous = 스케줄됨(PREREQ-X). 모든 Lane-B=lint until then. PR에 명시.
2. move-by-default는 &-surface 전엔 **불가**(self-host `_add_edge` shared-handle 의존). A1→A3 순서 불변. A3 크기=A2 census로 측정(추정 금지).
3. whole-local granularity 천장(no place projection)→B4 fatal 시 FP원. B1 census가 field-disjoint hit 카운트 필수.
4. 의도적 false-neg 유지(fn return·field load·cross-param·`?`-typed). precision-first polarity 유지.
5. Rule 2 = #4470 머지 전 inert(default ownership = Rule 1만).
6. vehicle 비대칭 영구적(gen2=aprime child만·warm-cache/비-linux cold lag). B3 "default" 주장은 어느 verb/path인지 명시.

## 이번 세션 = ★A1 (first rung) 착수
`&T`/`&mut T` surface 양파서 — move 랜 foundation. B0(enforcement)는 병행 가능.
