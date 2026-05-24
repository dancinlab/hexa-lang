# shadowing scope leak — `_gen2_collect_lets` codegen 재설계 RFC

**Status**: rfc-draft-deferred-2026-05-25 — design-only patch (not a fix). Promote via /inbox skill if RFC track wanted.
**Status**: design-level (PROBE round 3 #6 carry-over, 2026-05-23)
**Priority**: P1 (silent miscompile 클러스터 — `let` 의 의미가 변형됨)
**SSOT**: PROBE.log.md round 3 Shadowing entry (line 74-78) · `self/codegen.hexa` `_gen2_collect_lets` (line 2470-2478) · `_gen2_collect_lets_stmt` (line 2434-2468)

## 현재 deviation

| 사이트 | 동작 |
|---|---|
| `_gen2_collect_lets_stmt` (self/codegen.hexa:2434) | nested body 재귀로 모든 `let` 이름을 함수 flat-pool 에 누적 |
| `_gen2_collect_lets` (self/codegen.hexa:2470) | stmts 순회하여 위를 호출 — 함수당 단일 `HexaVal x` declare |
| 같은 이름 nested `let` | 같은 C 변수 재사용 → outer scope mutate |
| match-arm `let` (2453-2462) | arms 까지 collect — arm 종료 후도 누출 |
| bare-block (r14-S) | 파싱 통과 후 동일 누출 (collect_lets 가 Block body 도 재귀 순회) |

ASCII illustration:

```
hexa source:                  codegen output (today):
fn f() {                       void f() {
    let x = 1                      HexaVal x;        // 1번 hoist
    {                              x = hexa_int(1);
        let x = 100                x = hexa_int(100); // 같은 변수!
    }
    print(x)                       hexa_call(u_print, x); // → 100 (WRONG)
}                              }
```

기대 동작 (canonical):

```
void f() {
    HexaVal x_outer = hexa_int(1);
    { HexaVal x_inner = hexa_int(100); }   // inner drop at }
    hexa_call(u_print, x_outer);            // → 1
}
```

## 캐노니컬 (g1)

- **Rust**: 각 `{}` 블록은 새 stack frame slot; inner `let x = 100` 은 outer `x` 가림 (shadow), 블록 종료 시 inner drop, outer 복원
- **Swift / C / Go / Zig**: 같은 lexical scope 모델
- **JavaScript `let`**: block-scoped (var 와 구분되는 핵심 동기)
- 즉 hexa 가 `var` 의미를 `let` 으로 emit 중 — 이름의 시멘틱이 깨져 있음

## 같은-블록 reshadow 는 이미 처리됨

self/codegen.hexa:2345 주변 주석:
> `let x = ...` shadow-rebind in the same block; C forbids it. gen2_fn_decl ...

→ 같은 블록에서 `let x = 1; let x = "two"` 는 단일 `HexaVal x` 에 재바인딩 (PROBE r3 #6 에서 "canonical" 로 확인). **누출은 nested-scope 케이스에서만 발생**.

## 재설계 옵션 (3 선택지)

### 옵션 1: per-scope unique 이름 (gensym)

- `_gen2_collect_lets` 를 scope-aware 로 rewrite
- 각 `let x` → C 이름 `x__<scope_id>` (gensym)
- 안쪽 `let x` = `x__inner_42`, 바깥 `let x` = `x__outer_3`
- 참조 site도 동일 scope_id 적용 (가장 가까운 enclosing let 의 `_id`)

**장점**: flat-hoist 유지, 이름만 unique
**단점**: scope-id 전파를 통한 lookup 이 모든 참조 사이트 통과 필요 (전반 grep + edit · `_gen2_emit_ident` 류 모든 emit 사이트 영향)

### 옵션 2: 진짜 C `{}` 블록 emit

- AST 의 Block node → C `{ ... }` 블록 그대로 emit (declarations 안에 inline)
- `let x = 100` → C `HexaVal x = hexa_int(100);` inside `{}`
- C 자체가 scope 처리

**장점**: canonical C scope, 가장 자연스러움
**단점**: `_gen2_collect_lets` 폐기/축소, 모든 let-emit 사이트 재배치, struct field nested HexaVal pattern, GCC statement-expression 으로 expr-context 에서 block 사용하는 패턴 (codegen.hexa:2480) 과 상호작용 까다로움

### 옵션 3 (권장): SSA-lite renaming pre-pass

- 새 AST-walk pass: `rename_shadowed_lets`
- 함수 body 순회 시 같은 이름 nested `let` 검출 → 두 번째 인스턴스를 `x_2`, `x_3`, ... 로 rename
- 같은 scope 안의 모든 참조 (변수 read · assignment LHS) 도 함께 rename
- `_gen2_collect_lets` 는 unique 이름만 보게 됨 → 무수정

**장점**: collect_lets 거의 무수정, surgical, AST 단일 pre-pass
**단점**: rename pass 별도 구현 필요 (~150줄), scope-aware traversal

→ **옵션 3 권장** (기존 flat-hoist 코드 보존, AST pre-pass 로 격리)

## 영향 surface (옵션 3 기준)

| 파일 | 변경 |
|---|---|
| `self/codegen.hexa` 또는 `self/type_checker.hexa` | 새 AST-walk pass `rename_shadowed_lets`; `_gen2_collect_lets` 호출 전 실행 |
| `self/codegen.hexa` `_gen2_collect_lets` (line 2470) | 무수정 (rename 후 충돌 없음) |
| `self/codegen.hexa` match-arm let (line 2453-2462) | 동일 rename pass 에서 처리 |

## 구현 단계 (stacked PRs)

1. **AA-1**: AST scope-walker — 함수 body 순회, 동일 이름 nested `let` 검출 (~100줄, dry-run no-op)
2. **AA-2**: rename pass — 검출된 inner 를 `x_<n>` 형태로 rename, 같은 scope 내 모든 참조 rewrite (~150줄)
3. **AA-3**: match-arm `let` 처리 통합 (~50줄)
4. **AA-4**: bare-block (r14-S land 후) 통합 (~30줄)

총 ~330줄, 4-PR stack.

## 호환성

- 의도적인 shadowing 사례는 거의 없음 (PROBE r3 에서 같은 함수 안 같은-블록 reshadow 는 canonical 로 작동 — `let x = 1; let x = "two"` PASS).
- 즉 outer-/inner- 구분이 깨진 케이스만 영향 — 누출은 silent miscompile 이라 모르고 작동 중인 코드는 거의 없음.
- 기존 회귀 테스트 모두 통과 예상.

## 부수 효과

- r14-S (bare-block stmt parse) 가 land 된 후 본 RFC 가 닫혀야 의미 완성 (parse 만 통과 + 누출 = 더 큰 silent miscompile 표면적)
- match-arm `let` 누출 (PROBE.log.md line 77) 이 함께 fix 됨
- PR #347 (round 1 non-exhaustive match) 클러스터의 sister silent-void issue 와 묶일 후보

## 참조

- PROBE.log.md round 3 Shadowing entry (line 74-78)
- PR #347 (round 1 `let` immutability + match exhaustiveness) — sister silent-cluster
- PR #489 (enum to_string codegen-emit RFC, r14-F follow-up) — sibling codegen-redesign RFC
- r14-S 시점 PR (bare-block parse acceptance, scope-limitation 명시) — 본 RFC 의 prerequisite
- self/codegen.hexa `_gen2_collect_lets_stmt` (2434) · `_gen2_collect_lets` (2470) · 같은-블록 reshadow 처리 주석 (2345)
