---
slug: hexa-return-void-mistranslate-2026-05-24
status: archived
---

# hexa-lang `return void` mistranslate — bare void-literal return → undeclared identifier (B14 saga, 2026-05-24)

**Status**: archived-PR#733-2026-05-25 — not-reproducible (2 minimal repros lower correctly via __hexa_fn_arena_return)

**Status (2026-05-24)**: ARCHIVED — not-reproducible · agent misdiagnosis 추정 · `return void` parser/codegen 정상 동작 확인.

**Resolution**: 2 minimal repros (`return void` 단독 + `type_of(p)` 직전 stmt 결합) 모두 `./self/native/hexa_v2` 로 .c 생성 → `return __hexa_fn_arena_return(hexa_void());` 로 정상 lower. 보고된 "`return void` → `return type_of(p)` mistranslate" 패턴은 현재 컴파일러(`v0.1.0-dispatch`)에서 재현 안 됨. B14 agent 가 만났던 `undeclared identifier` 에러는 다른 원인(예: `void` 가 아닌 다른 token mistype, 또는 별도 type-check stage 메시지)에서 비롯되었을 가능성 — agent 가 minimal repro 안 만들고 즉시 sentinel workaround 로 우회했기 때문에 실제 원인 미확인. **No compiler fix needed.** 후속 anima 측 sentinel pattern 의 type-safety 평가는 별개 design 작업.

**Reporter**: anima (`dancinlab/anima` downstream consumer)
**Severity**: medium (작성자가 sentinel + caller gate workaround 로 우회 가능하나 type safety 손실)
**Affected**: hexa compiler parser/typer (`void` literal handling in return position) · `map`/`record` return-type fn 의 early-exit pattern 사용 코드 전반
**Sibling series**: prior 6 inbox patches (runpod-graphql-builtin · hexa-cloud-pod-status-diagnose-verbs · hexa-cloud-dispatcher-bootstrap-wait-endpoint · hexa-cloud-guard-ux-and-pod-lock · hexa-cloud-copy-from-verify-local · hexa-list-concat-o-n2-corpus-build-oom)

## Context — B14 saga 중 발견

anima HEXAD/PURE B14 cycle 에서 발견. `coffeshop_fire_sanity_hook.hexa` Phase 2 impl (PR #410, `dancinlab/anima`) 중 agent 가 정상 `return void;` syntax 를 작성했으나 hexa interp/compile 단에서 `return type_of(p)` 로 mistranslate 되어 undeclared identifier (`type_of` argument resolution) 에러로 빠짐.

agent verbatim:

> "hexa compiler mistranslates bare `return void` → `return type_of(p)` (undeclared identifier) in some contexts; replaced with `return []` sentinel since callers already gate on `type_of(...) != "map"`."

## Finding — bare `void` literal in return position

추정 root cause:

- hexa parser/typer 가 `void` 를 정식 literal 로 인식하지 못하고 identifier lookup 으로 빠짐.
- 일부 context 에서 직전 expression (e.g. `type_of(p)`) 와 결합되어 잘못된 AST 노드로 lower 되는 듯.
- 정확 trigger context 는 agent 가 specific syntactic pattern 을 확인 안 한 채 sentinel workaround 로 진행했으므로 미식별.
- 의심 trigger: `map` / `record` return-type fn 안 `if invalid(x) { return void; }` early-exit pattern.

## Repro path (best-effort)

⚠ 정확 minimal reproducer 미작성 (B14 worktree 이미 진행 추가). 추정 reproducer:

```hexa
// hypothesis — map-return fn 에서 early-exit void
fn maybe_parse(p: string) -> map {
    if p == "" {
        return void;   // ← mistranslate 의심 — type_of(p) 로 lower?
    }
    return #{ "ok": true, "payload": p }
}

fn main() {
    let r = maybe_parse("")
    if type_of(r) != "map" {
        print("invalid")
    } else {
        print(r["payload"])
    }
}
```

확인 절차:

1. `hexa run repro.hexa` 실행 → `undeclared identifier` 류 에러 메시지 캡쳐.
2. parser AST dump (가능하면) 로 `return void` 가 `return type_of(...)` 로 lower 되었는지 확인.
3. context 변형 (return type annotation 제거 / `void` literal 위치 변경 / 직전 stmt 변형) 으로 trigger surface 좁히기.

## Suggested fix

### Option A — `void` 를 정식 literal/keyword 로 처리 (parser-side, 최저 surgical)

- `void` 가 expression position 에서 type_of-style identifier 가 아니라 unit/void literal 로 lower 되도록 parser/typer 보정.
- `return void;` syntax 명시 지원 — return-type 이 `void` 또는 nullable map 인 fn 에서 early-exit 표현.

### Option B — bare `return;` syntax 대안 추가

- `return` keyword alone 을 void return 으로 해석 (C / Rust 류 convention).
- 작성자 입장에서 `return void;` 와 동일 의미, parser 가 void literal 처리 안 해도 syntactic shortcut 으로 우회.

### Option C — sentinel pattern (`return []`) 의 type-safety 평가 + 가이드

- 현재 workaround (`return []` + caller-side `type_of(x) != "map"` gate) 가 작동은 하나 list 가 fail case 와 valid result 둘 다 표현 가능 → type ambiguous.
- 작성자 가이드 또는 stdlib helper (`fail_map()` 같은 nominal-sentinel fn) 로 type-safety 회복 path 마련.

## Affected use cases

- `fn foo(x) -> map { if invalid(x) { return void; } ... }` 패턴 사용 hexa 코드 전체.
- 특히 B14-style hook/probe/sanity fn (map/record 반환 + early-exit on invalid input) 다수.
- anima HEXAD/PURE 사이클의 phase-hook 류 fn 전반 적용 가능성.

## Cross-refs

- anima `dancinlab/anima` PR #410 (`coffeshop_fire_sanity_hook.hexa` Phase 2 impl)
- prior hexa-lang inbox series (6 patches): runpod-graphql-builtin-for-pure-dispatcher · hexa-cloud-pod-status-diagnose-verbs · hexa-cloud-dispatcher-bootstrap-wait-endpoint-2026-05-24 · hexa-cloud-guard-ux-and-pod-lock-2026-05-24 · hexa-cloud-copy-from-verify-local-2026-05-24 · hexa-list-concat-o-n2-corpus-build-oom-2026-05-24

## C3 (honest residuals)

- 정확 trigger syntactic context 미식별 — agent 가 minimal reproducer 만들지 않고 sentinel workaround 로 즉시 진행.
- compiler version (B14 agent 시점 hexa interp build) 미명시.
- `return []` workaround 가 downstream type safety 에 미치는 영향 (caller 가 list 도 valid map 으로 오인할 가능성) 정량 평가 미실시.
- mistranslate 가 parser-stage 인지 typer-stage 인지 lower-stage 인지 미분리.
- `void` literal 의 다른 expression position (assignment RHS / fn arg / record field) 동작은 미점검 — return position 단독 bug 인지 broader void-literal 처리 결함인지 불분명.
