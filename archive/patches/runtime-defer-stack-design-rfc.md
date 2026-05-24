# runtime defer stack design RFC

**Status**: design-level (r14 KKKK STOP follow-up, 2026-05-24)
**Priority**: P1 — defer cleanup가 throw 시 leak (file/lock/resource handle 누수)
**SSOT**: PR #559 (r14-KKKK STOP) · PR #534 (r14-FFFF defer 80% impl) · PR #565 (r14-OOOO nested-hoist) · r14-EE panic 채널 (#501) · r14-FF try/finally (#502)

이 RFC 는 PR #559 (KKKK STOP) 의 "next cycle 의 design RFC" 자리를 채운다.
#559 는 *blocker finding* (probe deviation + root-cause trace + 옵션 스케치) 이고,
이 문서는 그 위에 **5-PR stacked landing plan** + **캐노니컬 비교** +
**OOOO(#565)/EE(#501)/FF(#502) 관계 매트릭스** 를 더한 full design 이다. #559 SUPERSEDES.

## 현재 모델 (C-static, throw-unsafe)

| 요소 | 위치 | 동작 |
|---|---|---|
| `__defer_<i>_active` flag | codegen.hexa:1786-1948 (Plan B Phase 3, `_gen2_defer_flag_count`) | per-fn local int |
| `__ret_val` slot | codegen.hexa:1796 | return value parking |
| defer body | inline at `__fn_exit:` label (LIFO) | fn-exit drain |
| early return | `__ret_val = …; goto __fn_exit;` | drains before return |
| **throw** | runtime_core.c:5445 `longjmp(*__hexa_try_stack[…], 1)` | **drain SKIPPED** (frame dies) |

문제: C-static locals 은 longjmp 으로 죽는 stack frame 에 산다 → `__fn_exit:` 도달 못 함.
`grep -i defer self/runtime_core.c` → 0 defer-registry (2 hit 전부 무관 코멘트). KKKK 확인.

## 캐노니컬 비교

| 언어 | defer 메커니즘 | throw/panic 시 |
|---|---|---|
| Go | runtime `g._defer` linked list (goroutine 별) | panic 시 unwind 가 defer list walk |
| Swift | compiler-emitted cleanup + runtime unwind tables | error throw 시 scope cleanup fires |
| Zig | compile-time `defer` + `errdefer` (error-path 전용) | error union return 시 errdefer fires |
| C++ | RAII destructors + stack unwinding tables | exception 시 destructor chain |

→ **Go 모델 권장** — runtime defer stack (per-thread linked list), throw/panic 시 catch frame 까지 unwind.
Zig errdefer 는 EE(#501) panic-vs-error 채널 분리 시 future-extension 후보 (정상 path drain 제외).

## 디자인 (3 옵션)

### 옵션 A — runtime defer stack (Go 모델, 권장)

```c
typedef struct HexaDeferEntry {
    void (*body)(void* env);     /* closure thunk ptr */
    void* env;                   /* captured locals (heap-boxed) */
    int   try_frame_depth;       /* __hexa_try_top at registration */
    struct HexaDeferEntry* prev; /* LIFO chain */
} HexaDeferEntry;
static __thread HexaDeferEntry* g_defer_top = NULL;

void hexa_defer_push(void (*body)(void*), void* env);
void hexa_defer_pop_one(void);                  /* 정상 fn-exit drain (1개) */
void hexa_defer_drain_to_try_frame(int saved);  /* hexa_throw 헬퍼: depth>saved 전부 fire */
```

`hexa_throw` hook:

```c
void hexa_throw(HexaVal err) {
    __hexa_error_val = err;
    if (__hexa_try_top > 0) {
        int target = __hexa_try_top - 1;
        hexa_defer_drain_to_try_frame(target);   /* NEW — longjmp 前 drain */
        __hexa_try_top--;
        longjmp(*__hexa_try_stack[target], 1);
    }
    hexa_defer_drain_to_try_frame(0);            /* uncaught — 전부 drain 후 exit(1) */
    /* … 기존 fprintf + exit … */
}
```

- defer 문 → `hexa_defer_push(&__defer_thunk_<N>, &__defer_env_<N>)` (flag flip 폐기 — 물리적 push 가 활성화)
- defer body → static `void __defer_thunk_<N>(void* env)` 로 lift + free-var 를 heap env struct 로 capture
  (codegen.hexa 의 `_gen2_boxed_cells` machinery 재사용 — closure mut-capture by-ref 인프라 #433 존재)
- fn-exit / early-return → 등록 수만큼 `hexa_defer_pop_one()` LIFO (flag 체크 불필요, 스택이 activation record)
- closure 가 by-ref capture 라 FFFF RFC 의 mutate-then-defer 시맨틱 유지

장점: throw-safe + nested-scope 자연 처리 (try_frame_depth 추적) + uncaught-throw 도 cleanup
단점: closure conversion 필요 (defer body → fn ptr + env struct), codegen 변경 큼 (~150-250 LOC)

### 옵션 B — setjmp-chain extension

각 defer 에 mini-setjmp, throw 시 chain 따라 실행. 장점: longjmp 인프라 재사용.
단점: defer 마다 setjmp 오버헤드 O(defer × try-depth), hot path 병리적. **Reject.**

### 옵션 C — keep C-static + throw-time scan

C-static 유지, `hexa_throw` 가 현 fn `__defer_*` 스캔. longjmp 후 frame 죽어서 스캔 불가
— **기술적으로 불가능** (KKKK 발견). **Reject.**

→ **옵션 A 권장** (runtime stack + closure conversion).

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/runtime_core.c` | HexaDeferEntry struct + g_defer_top + push/pop_one/drain_to_try_frame + hexa_throw hook |
| `self/codegen.hexa` (defer) | defer 문 → thunk lift + env struct capture + `hexa_defer_push` (flag flip 대체) |
| `self/codegen.hexa` (fn-exit) | `__defer_*_active` 드레인 → `hexa_defer_pop_one()` × count |
| `self/codegen.hexa` (try/catch) | catch frame depth (`__hexa_try_top`) push 시점 캡처 |
| `self/native/hexa_v2` | regen (~10 KB, mechanical) |

## 구현 단계 (stacked PRs, ~5 PR · ~360줄)

1. **SSSS-1**: runtime HexaDeferEntry + g_defer_top + push/pop_one/drain primitives (~80줄 runtime, no codegen)
2. **SSSS-2**: codegen defer body → closure conversion (thunk lift + heap env capture) (~100줄 codegen)
3. **SSSS-3**: fn-exit / early-return drain via `hexa_defer_pop_one` (replaces `__defer_*_active`) (~60줄)
4. **SSSS-4**: `hexa_throw` → `hexa_defer_drain_to_try_frame` hook (~40줄, **KKKK #559 closure**)
5. **SSSS-5**: nested-scope depth tracking + scope-exit drain (~80줄, **OOOO #565 의 superset 대체**)

각 PR 후 FFFF defer 테스트 + KKKK probe (`cleanup-2\ncleanup-1\ncaught: boom`) 회귀 검증.
SSSS-1 은 dead-code 로 land (codegen 이 아직 안 부름) → byte-eq audit 안전.

## 관계 PR/RFC

- **PR #559 (KKKK STOP)** — defer-throw 가 이 RFC 에 blocked. 이 문서가 #559 의 "design RFC" 자리.
- **PR #565 (OOOO defer nested-hoist)** — C-static 패치 (decl hoist). **SSSS-5 가 이것의 superset**:
  runtime stack 은 nested scope 를 try_frame_depth 로 자연 처리 → OOOO 의 hoist 가 불필요해짐.
  OOOO 는 stop-gap 으로 먼저 land 가능 (Option A 와 충돌 없음, SSSS-5 가 흡수).
- **PR #534 (FFFF defer RFC)** — defer keyword + parser + Plan B Phase 3 codegen. 이 RFC 의 base.
- **r14-EE panic 채널 (#501)** — panic 시 defer drain 정책 (Go: panic 도 defer fire).
  옵션 A 의 `drain_to_try_frame` 가 panic 채널에도 재사용 (throw/panic 통합 unwind).
- **r14-FF try-expr/finally (#502)** — `finally` = defer 의 try-scoped desugar 후보
  (finally body → 암묵 `defer` at try-block scope, SSSS-5 depth 추적 위에 desugar).

## 우회책 (지금)

- defer 를 throw 없는 함수에서만 사용 (fn-exit + early-return drain 은 정상 작동)
- 명시 try/catch + cleanup 듀얼-사이트 (cleanup 을 catch 와 정상 path 양쪽에 중복 기술)

## Provenance

- PROBE r14 cycle 13 (SSSS) — KKKK(#559 cycle 12) STOP follow-up
- 소스 확인: codegen.hexa:1786-1948 (`_gen2_count_defers`/`_gen2_defer_flag_count`/`__defer_N_active`) · runtime_core.c:5445 (`hexa_throw` longjmp, defer drain 없음)
- DUP-PRECHECK: `ls inbox/patches/ | grep -iE 'defer.*(stack|runtime|unwind|throw)'` → origin/main 에 0건 (#559 파일은 PR 브랜치에만, 미머지) · `git log origin/main --since='2026-05-24' -- inbox/patches/` → 0건
- 관계 PR 전수 OPEN 확인: #559 #565 #534 #501 #502
- 코드 미수정 (inbox/patches/ 단독) · auto-merge / protection toggle 없음

— probed by sub-agent on `probe-r14-SSSS-runtime-defer-stack-rfc-2026-05-24`
