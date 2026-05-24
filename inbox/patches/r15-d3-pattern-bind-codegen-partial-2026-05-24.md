# PROBE r15-D3 — Option/Result `Some(v)` pattern-bind codegen (PARTIAL — _all_void 가드 미발화)

**Filed:** 2026-05-24 · session `inbox/websocat-tool-discovery-2026-05-23`
**Severity:** HIGH — blocks all Option/Result match-on-payload usage
**Status:** PARTIAL-FIX → BLOCKED (inline 검증 차단; clean 환경 필요)

## Repro

```hexa
fn maybe(s: str) {
    if s == "y" { return Some(1) }
    return None
}
fn main() {
    let a = maybe("y")
    match a {
        Some(v) => println("some " + to_string(v))
        None => println("none")
    }
}
```

Canonical (Rust): `some 1`. Pre-fix hexa: clang error `v undeclared` in the
synthesized match-arm condition.

## Partial fix (이미 적용됨 · agent worktree 보존)

Prior sub-agent (worktree `worktree-agent-aed88f0bb16ed670e`) landed 4 changes
in `self/codegen.hexa`:

1. **`Some(v)` pattern-bind scope** — `v` 가 arm 조건에서 undeclared 였던 문제
   해결 (payload accessor `hexa_index_get(scrutinee, hexa_int(1))` 로 GCC
   stmt-expr 안에서 바인딩).
2. **bare `None` → `hexa_str("None")`** (gen2_expr Ident arm, sibling to
   nan/inf reserved-ident lowering).
3. **`Some`/`Ok`/`Err` Call → `[hexa_str(tag), payload]`** tagged-array
   (gen2_expr Call branch, EnumPath payload convention mirror).
4. **`_all_void` 가드** (gen2_fn_decl ~L1906) — trailing MatchExpr whose arms
   are all void-builtin calls (println/print/eprintln/eprint/exit) → skip the
   tail-returnify rewrite so the void match emits as a plain statement.

`v undeclared` 는 해결됨 (change #1 작동 확인).

## 잔여 blocker (deep-dive 발견)

change #4 (`_all_void` 가드) 가 **probe_4 의 `main()` void-match 에 발화하지
않음**. 생성 C:

```c
return __hexa_fn_arena_return(((HX_IS_ARRAY(a) && ...Some...)
  ? ({ HexaVal v = hexa_index_get(a, hexa_int(1)); (hexa_println(...)); })
  : (...None... ? hexa_println(__hexa_sl_2) : hexa_void())));
```

`hexa_println` 은 C `void` 반환 → `__hexa_fn_arena_return(HexaVal)` 에 전달 시
clang error `passing 'void' to parameter of incompatible type 'HexaVal'`.

가드 로직 (L1906-1933) 은 코드 리뷰상 정확해 보임:
`inner_kind == "MatchExpr"` + 각 arm body 의 last ExprStmt 가 void-builtin
Call 인지 검사 → 전부 맞으면 `_skip = true`. 하지만 실측상 `_skip` 이 false
로 남아 rewrite 가 진행됨. 미발화 원인 후보:

- `_wants_tail_return` 가 untyped `main()` 에 true 로 설정 (L1823-1833): 빈
  ret_type `""` 는 `type_of != "string"` / `== "Void"` 둘 다 안 걸려 true 유지.
  → 가드는 이 경로에 도달해야 하는데 `_all_void` 결과가 예상과 다름.
- arm.body 구조가 `[ExprStmt(Call)]` 가정과 다를 가능성 (gen2_arm_value
  L7843 은 `body[last].kind == "ExprStmt"` 로 작동하므로 구조는 맞아 보임 —
  모순).

## 왜 inline 완료 실패

clean 환경이 아니어서 계측·재현 불가:

1. **hexa_v2 SIGKILL** — `./self/native/hexa_v2 <src> <out.c>` 직접 호출이
   exit 137 (basename hexa-prefix external matcher · memory
   `reference_hexa_basename_sigkill_workaround_2026_05_19`). build wrapper
   경유는 가능하나 transpile 단계가 SIGKILL 로 C 미생산.
2. **`eprintln` 계측 → `__HEXA_BRC__` transpile 실패** — 가드 직전에 디버그
   eprintln 추가 시 self-build transpile 이 bracket-recursion 류로 실패.
   계측 경로 막힘.
3. **pool routing** — Mac load >150% 로 대부분 Bash 가 ubu/mini 로 ssh-route
   → `/Users/ghost` 부재로 fail. 로컬 강제에 `SIDECAR_NO_POOL_ROUTE=1
   PATH=...` prefix 필요하나 간헐 무시됨.
4. **server rate-limit** — sub-agent 5회 중 4회 ratelimited.

## 다음 사이클 제안

clean 환경 (정상 hexa_v2 · 계측 가능 · routing 없음) 에서:

- **P0** — `_all_void` 가드 미발화 원인 규명. `_wants_tail_return`/arm.body
  구조를 실제 AST dump 로 확인 (eprintln 대신 별도 dump verb 또는 ubu 원격).
- **P1** — 가드 발화 후 probe_1~4 (option_result) compile+run PASS 검증.
  probe_1 은 D1 (`Option[T]` annotation, 이미 #719 land) 의존 → 함께 통과 기대.
- **P2** — self-host fixpoint 회귀 가드 (gen1.s ≡ gen2.s ·
  `project_compiler_native_self_host_fixpoint`).

## Cross-refs

- worktree `worktree-agent-aed88f0bb16ed670e` (locked) — partial fix 4종 보존
- probes `/tmp/probe-r15/option_result/probe_{1,2,3,4}.hexa`
- D1 `Option[T]` annotation parse — LANDED #719 (`01b6ed1c`)
- D4 `.unwrap/.unwrap_or` builtins — LANDED #725 (`5460844`); `.map` deferred
- `reference_hexa_basename_sigkill_workaround_2026_05_19`
- `feedback_no_interp_use_compiled`

— Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
