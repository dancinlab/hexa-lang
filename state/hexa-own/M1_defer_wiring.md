# HEXA-OWN M1 — `defer` 배선 계획서 (census workflow wrk4s86e9 · 6 agents · 578k tok)

## ★ 헤드라인 — M1은 "신규 키워드"가 아니라 native-경로 패리티 포트

`defer`는 이미 3개 실행기 중 **2개에 완비**되어 있다:

| 실행기 | 상태 | 근거 |
|---|---|---|
| gen2 C-transpile (self/) | ✅ 완비 | 키워드 `self/lexer.hexa:39,114` · `parse_defer_stmt` `self/parser.hexa:4749`(expr+block 두 형태) · fn-exit LIFO drain `self/codegen.hexa:2082-2303,3526`(`__defer_N_active` 플래그+`goto __fn_exit`) · **무사용 시 zero-emission 보장 기설계**(2737-2738) |
| **native aprime (compiler/)** | ❌ 전무 | 토큰·AST·lowering 없음 — **M1의 유일한 갭** |

⚠️ interp는 **삭제됨**(ab7015fa1 · R7 Cycle C · 25,548줄 · `g_interp_deprecated` self/main.hexa:2631) — 실행기 포크 없음, `hexa run`=compile-then-exec gen2. self/codegen.hexa:2725 등 interp 인용 주석은 stale 포인터. **2-lane**(gen2 default + aprime opt-in)이 전부.
⟹ 의미론 oracle = **gen2 단독**(reference-match·in-repo·byteeq 기판). 코퍼스에 defer 사용 0건(검증) → behavior-safe.

## 확정 verdicts (round-2 2-lane workflow w4gwzr7rz · 소스 추적 완료)

- **Q1 loop-defer**: gen2 at-most-once(컴파일타임 등록+idempotent 플래그) = 유일 canonical. 삭제된 interp의 per-iteration은 moot.
- **Q2 fn-exit vs per-block**: **fn-exit 확정** — `__fn_exit` 라벨 1개/fn·`_gen2_defer_flag_count>0`일 때만 return 재라우팅(무defer fn=오버헤드 0 직접 return).
- **Q3 `defer x = 1`**: **REJECT 확정** — 단 naive 포트는 조용히 수용해버림: native parse_expr==parse_assignment(compiler/parse/parser.hexa:480-481)이라 expr형은 `parse_logical_or()`(parser.hexa:513)로 파싱하고 다음 토큰이 Eq류면 HX0xxx 진단.
- **Q4 contextual 게이트**: **명시적 TokenKind 화이트리스트 필수** — parse_primary는 어떤 토큰도 거부 안 하고 placeholder Ident를 반환(parser.hexa:1156-1166)하므로 try-parse 게이트는 구조적으로 불가. 게이트 = stmt-위치 Ident('defer') ∧ next ∈ {LBrace, Number, String, Char, KwTrue, KwFalse, PNode, CNode, LNode, ENode, Ident, …식-시작 화이트리스트}.
- **carrier 정정**: match_guard 선례는 ExprKind::**If**+text (ast.hexa:172-178) — 그래도 Block+text carrier 유효(Block lowering이 e.text를 _mk_hexpr로 verbatim 전달 ast_to_hir.hexa:1954 · resolve/bind/types 3패스 모두 .text 투명 검증).
- **미결(사용자 콜)**: `defer (expr)`의 LParen 게이트 포함 여부(권고=포함) · pipe-closure `defer |x| body` 거부 문서화 vs 특례 · stale interp 주석 청소 PR 분리 vs 동봉.

## 확정 의미론 (gen2 준거)

- **fn-exit LIFO drain** (Go식) — break/continue/내부블록 탈출은 drain 안 함.
- reached-flag 등록: 실행 도달한 defer만 등록, 루프 내 defer는 **at-most-once**(gen2 플래그식 · Go의 N회와 다름 — 문서화).
- drain 시점 변수값 사용(등록시점 인자 캡처 없음 — Go와 다름 · 테스트로 박제).
- **throw는 drain 안 탐**(longjmp가 `__fn_exit` 우회 · 양 백엔드 동일) — M1 범위 밖, 문서화. try-lowering 연동은 후속 마일스톤.
- `defer free(p)`의 실효는 빌드경로 의존(native seed `hexa_ptr_free`=no-op `self/rt/alloc.hexa:187`) — **정직한 서사 = "defer는 scope-exit 액션 앵커·메모리 회수는 per-fn arena scope pop이 담당"**. drain은 반드시 `__hexa_fn_arena_return` **앞**(gen2 기존 순서 보존).

## 단계 (Step 0~7 · 상세 file:line은 wrk4s86e9 산출)

0. **특성화 먼저**: interp+gen2 양쪽에서 early-return/LIFO/loop/throw 케이스 실행·출력 캡처 → oracle 박제 (pool에서).
1. **PARSER-1 contextual `defer`** (`compiler/parse/parser.hexa:1744` parse_stmt · var #3681 관용구 미러 1756-1763): 신규 TokenKind 금지(`state/rfc_reseed_canonical_keywords.md:394` — contextual이 sanctioned·hard-kw 승격=~457 충돌+재프리즈), **신규 ExprKind도 금지** — carrier 관용구(`ExprKind::Block`+`text:"__defer__"`+`ast_is_defer()` 헬퍼, match_guard 선례 `ast.hexa:160-178`)로 ~92개 exhaustive-match 파급 회피. PARSER-2는 **무수정**.
2. **AST→HIR**: `ast_to_hir.hexa:1681` `_lower_expr`에서 carrier → HExpr kind="defer"(문자열 태그·enum 무변경). check/ 패스들은 Block으로 통과(무수정).
3. **HIR→MIR 단일-exit epilogue** (`hir_to_mir.hexa` `_lower_fn`): defer-count 프리스캔, **count==0이면 오늘과 완전 동일 lowering**(bit-identity의 전부). count>0일 때만 플래그 local+`__ret`+exit 블록, 기존 MIR stmt kind만 사용(신규 kind 금지 → dce·4개 타깃 emitter 무수정). return-site 인라인 drain 금지(루프 back-edge로 도달하는 textually-later defer 누락 함정) — 단일 exit 블록 필수.
4. **codegen 무수정 검증**: `git diff --stat`으로 compiler/codegen/+emit/ 빈 것 확인 + defer-free 코퍼스 .o byte-compare(pool·same-cwd — DWARF-cwd 함정). **신규 런타임 심볼 0**(frozen blob 151c52c8 금지) — gen2 flags+goto가 템플릿.
5. **selftest**: `stdlib/lang/defer_test.hexa`(`// @ci_gate`·aggregate 자동발견) + `self/test/miscompile_zero/` 코퍼스 케이스. 케이스=normal/early-return/LIFO/nested/defer-after-return/loop-break/조건등록. **3 실행기 출력 동일 캡처**(interp·gen2·native — aprime-only=FALSE-green의 역방향 함정 주의: 여기선 gen2-only green이 native 갭을 놓침).
6. **진단**: parse-stage → **HX0xxx 대역**(RFC-019 밴드 규칙 `compiler/diag/catalog.hexa:4-15`). ⚠️ HX9000-9003은 @grace/@discover가 이미 점유 — HX9xxx 신설 계획은 기각.
7. **게이트**: byteeq 3-target(gen3≡gen4 + nobaseline faithful 3잡) — 코퍼스 defer 0건이므로 **이 게이트가 곧 무사용 bit-identity 증명**. SELFHOST_SLOT_READY=1 실주행 필수(exit-2 neutral≠green). 양 백엔드 smoke + CHANGELOG 동체 + `tree-sitter-hexa/grammar.js:56` 키워드 수동 추가(stale·ungated).

## TOP 리스크 (bit-identity 3형제)

1. `_lower_fn`에서 count==0 게이트 밖의 어떤 변경(local/블록 id shift)도 **전 코퍼스 byteeq 파괴** — gen2 `_gen2_defer_flag_count>0` 게이팅과 @naked default-false 선례를 그대로.
2. 신규 ExprKind = 12파일 ~92 match 파급 + frozen bootstrap parser 파손 — carrier 관용구는 선택이 아니라 필수.
3. 신규 런타임 심볼(`__hexa_defer_*` 류) = frozen blob faithful 빌드 파괴 — 순수 MIR 제어흐름/플래그만.

## 미결(착수 전 결정)

- loop-defer oracle: gen2 at-most-once 채택 권고(interp가 갈리면 별도 byte-neutral PR로 정렬).
- "every scope exit"의 뜻: **fn-exit로 확정 권고**(per-block은 shipping gen2 의미론 변경 = 별개 결정).
- `defer x = 1`(assignment body): gen2가 거부 — native도 거부로 정렬 권고(문법 동일성).
- contextual 게이트 강도: strict lookahead 권고(next ∈ {LBrace, expr-start} ∧ ∉ {Eq,Colon,Dot,LBracket,binop}).

원본 전문(JSON·findings 95건): census workflow `wrk4s86e9` 산출 — 요지는 본 문서가 SSOT.
