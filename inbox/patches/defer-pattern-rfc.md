# defer 패턴 (Swift/Go) design RFC

**Status**: design-level + 부분구현 audit (r14 cycle 10, 2026-05-24)
**Priority**: P2 (r14-FF try-expr/finally RFC #502 권장 alternative)
**SSOT**: 본 RFC · r14-FF (PR #502) · r14-EE panic 채널 (PR #501)

## 핵심 발견 — `defer` 는 이미 부분 구현됨

probe 결과 — hexa `defer` 는 **fn 본체 top-level** 에서 Swift/Go 동작 그대로 작동. 단 3 개 결함 surface 됨.

| surface | 위치 | 상태 |
|---|---|---|
| lexer keyword | `self/lexer.hexa:66` | 구현 |
| `parse_defer_stmt` (block + expr 형) | `self/parser.hexa:4354-4379` | 구현 (block + 단일 expr 양형 지원) |
| codegen — fn-exit drain | `self/codegen.hexa:1784-1951` (Plan B Phase 3) | fn-top-level 만 |
| LIFO 다중 defer | — | 검증됨 |
| 조기 return 시 fire | — | 검증됨 (`__ret_val` route) |
| nested scope (while/if) 안 defer | codegen | **결함**: 깨진 C 코드 emit |
| throw 시 fire | runtime | **결함**: defer drain 안 됨 |
| capture semantics | codegen | **by-reference** (Swift 와 다름) |

## probe 결과 (검증)

```hexa
fn open_and_use() {
    let file = 42
    defer { println("close: " + to_string(file)) }
    println("processing: " + to_string(file))
}
fn multi_defer() {
    defer { println("A") } ; defer { println("B") } ; defer { println("C") }
    println("body")
}
fn expr_form() { defer println("single") ; println("body") }
```

→ 출력 (PASS · Swift/Go 동일):

```
processing: 42 / close: 42                    # fn-exit fire
body / C / B / A                              # LIFO 다중
body / single                                 # expr-form
```

| 결함 probe | 결과 |
|---|---|
| `defer` inside `while`/`if` block | `__defer_0_active`, `__ret_val` undeclared identifier — **C 컴파일 실패** |
| `defer` + `throw` | `body before throw / caught: panic!` — **defer 메시지 출력 없음** (drain skip) |
| `defer` capture (mut 후 read) | `body: x=99 / defer sees x = 99` — **by-reference**, snapshot 안 됨 |

## 캐노니컬 비교

| 언어 | 신택스 | 의미 | 실행 시점 | capture |
|---|---|---|---|---|
| Swift | `defer { … }` | scope-exit | enclosing `{}` 종료 | by-ref (구문상 closure) |
| Go | `defer fn(args)` | fn-exit | 호출 fn return 시 (LIFO) | **인자 즉시 평가**, body 는 by-ref |
| Zig | `defer expr` / `errdefer expr` | scope-exit | scope 종료 (errdefer 는 err 경로만) | by-ref |
| Rust | `Drop::drop` | RAII | scope 종료 | struct ownership |

→ hexa 현황 = **Go-fn-exit + Swift-block-syntax 혼합** + nested scope 깨짐.

## 디자인 결정 (현 구현 confirm + 결함 fix)

### D1 — scope vs fn-exit 의미 잠금

**채택: fn-exit (Go 모델)**.
- 이유: 현 codegen 이미 fn-exit drain 으로 구현. nested scope 의미 추가는 break/continue/return 의 unwind chain 복잡도 큼.
- 대안 (Swift block scope-exit) 는 follow-up 후보 — `defer_scope { }` 별도 키워드로 분리 (D5 참고).

### D2 — nested 위치 허용 + 의미 명시

- `defer` 는 fn body **어디서나** 작성 가능 (while/if 내부 포함) — 단 **실행은 fn-exit**.
- 현 codegen 의 nested scope 결함은 **버그** — flag declaration 을 fn top 으로 hoist 해야 함.

### D3 — throw 시 defer fire (UNWIND HOOK)

**현재 결함 = canonical violation**. Swift/Go/Zig 모두 throw/panic 시 defer 실행.
- 구현: `hexa_throw` (setjmp/longjmp) 에 defer drain hook 추가 → catch 진입 전 active defers 역순 실행.
- r14-EE (PR #501) panic 채널 RFC 와 동시 land 필요.

### D4 — capture semantics

**채택: by-reference (현 동작 유지) + 문서화**.
- 이유: Go body 도 by-ref, Swift block syntax 동일. Go 의 `defer fn(args)` 인자 evaluation 만 즉시 평가는 hexa 의 block-only 형에는 불필요.
- 사용자 snapshot 원하면 explicit `let snapshot = x` 후 `defer { use(snapshot) }`.

### D5 — scope-exit defer (follow-up)

분리 RFC 후보. 현 사이클 out-of-scope.
- 옵션 — `defer_scope { ... }` 또는 `defer @scope { ... }` 어노테이션
- 의미 — 가장 가까운 enclosing block 종료 시 실행 (Swift 모델)

### D6 — defer 안 control flow 금지

- `defer { return x }` → compile error (fn return 변형 금지)
- `defer { break / continue }` → compile error
- `defer { throw e }` → 허용, outer 로 전파 (다른 defer 들도 계속 실행 · Go 동일)

## 구현 단계 (stacked PRs)

| PR | 작업 | 영향 줄수 |
|---|---|---|
| FFFF-1 | codegen — nested-scope defer flag hoist (`__defer_N_active` 를 fn top 에 항상 emit) | ~30 |
| FFFF-2 | runtime — `hexa_throw` 안 defer drain hook + setjmp/longjmp 통합 | ~50 |
| FFFF-3 | codegen — `defer { return / break / continue }` 진단 (parse 또는 type_checker layer) | ~20 |
| FFFF-4 | docs — defer 의미 spec lock (현 RFC + LANGUAGE.md 갱신) | ~15 |

총 ~115 줄, 4-PR stack. 거의 다 codegen + runtime 결함 fix · 신규 surface 추가 거의 없음.

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/codegen.hexa` | nested-scope flag hoist 보정 (1794-1799 부근) |
| `self/runtime.h` + `self/native/throw.c` | `hexa_throw` defer drain hook 등록 |
| `self/parser.hexa` 또는 `self/type_checker.hexa` | defer 안 return/break/continue 진단 |
| `LANGUAGE.md` 또는 별도 spec doc | defer 의미 명시 |

## 의미 분쟁 (sticky)

- **nested fn 안 defer** — 현 codegen `_prev_defer_*` push/pop 로 보호됨 (확인됨). closure 안 defer 는 미검증 (follow-up).
- **labeled loop break/continue** — defer fire 시점은? 권장: fn-exit 만 (loop break 는 fn return 아님).
- **panic vs throw 구분** — r14-EE 결정 의존. panic = abort 면 defer drain 불가; throw 면 drain 가능. EE-1 land 후 confirm.

## 우회책 (지금, FFFF-1/2 land 전)

- nested scope 안 defer 회피 — fn body top-level 만 사용
- throw 안전 cleanup 필요 시 — explicit try/catch + close 호출

## 관계 RFC / PR

- **r14-FF** try-expr/finally (PR #502) — `finally` 는 defer 와 의미 중복. defer 우선 land 후 `finally` 는 desugar 후보 (`try x finally y` ≡ `{ defer y ; try x }`).
- **r14-EE** panic 채널 (PR #501) — defer drain hook 의 unwind path 정의.
- **r14-X** postfix `?` (PR #494) — `try { op() }?` 와 `defer { cleanup() }` 자연 결합.
- struct destructor RFC (미래 후보) — defer 의 RAII 짝.

## 결론

`defer` 는 이미 80% 구현됨. 신규 design 보다 **결함 fix + 의미 잠금** 이 본 RFC 의 실질 기여. 캐노니컬 Swift/Go 와의 gap = (a) throw 시 drain (b) nested scope codegen (c) control-flow 금지 진단 — 셋 다 4 PR stack 으로 closure.
