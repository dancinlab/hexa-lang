# try-as-expression + finally 절 design RFC

**Status**: design-level (PROBE round 3 INBOX line 37, r14 cycle 5 carry, 2026-05-23)
**Priority**: P3 (현재 `try`/`catch` 문은 작동; expression form + `finally` 은 enhancement)
**SSOT**: PROBE.log.md round 3 line 37 (Option/Result) · r14-X postfix `?` RFC (commit `2cf3e166`, `inbox/patches/postfix-question-result-abi-rfc.md`) · r14-EE panic 채널 RFC (sister, forward-ref)

## 현재 상태 (PROBE.log r3 line 37 확인)

| 형식 | 작동 |
|---|---|
| `try { ... } catch (e) { ... }` (stmt) | 작동 (parser.hexa:3839) |
| `let x = try { ... } catch (e) { ... }` (expr) | 거부 — `try` 는 statement-only dispatch (parser.hexa:1370) |
| `try { ... } finally { cleanup() }` | 미지원 — `parse_try_catch()` 가 `Catch` 를 hard-expect |
| `try { ... } catch (e) { ... } finally { cleanup() }` | 미지원 (동상) |

## 캐노니컬 비교

| 언어 | try-expr | finally |
|---|---|---|
| Java | stmt only | 표준 |
| JS/TS | stmt only | 표준 |
| Python | stmt only | 표준 (`else` 까지) |
| Swift | `try?` / `try!` prefix | 없음 (`defer` 패턴) |
| Rust | block-expr 자체가 expr | 없음 (`Drop`/RAII) |
| Kotlin | `val x = try { ... } catch ...` | 표준 |
| Scala | `val x = try { ... } catch ... finally ...` | 표준 |

→ Kotlin/Scala 모델 권장 — hexa 가 이미 block-expression 지향 (`let x = { stmt; expr }` 패턴) 이라 자연스럽다.

## 디자인 결정 (2 분리)

### Part 1: try-as-expression

```hexa
let x = try {
    parse(input)
} catch (e) {
    default_value
}
```

- try-block value = 마지막 expression (if 표현식 식과 동일 규칙)
- catch-block value = 마지막 expression (recover 의미)
- 둘 다 같은 type T 를 반환해야 함 (type-check)

### Part 2: finally 절

```hexa
try {
    file.open()
    process(file)
} catch (e) {
    log(e)
} finally {
    file.close()   // 항상 실행
}
```

- `finally` 는 try 와 catch 어느 경로든 마지막에 실행
- `finally` 자체는 value 없음 (cleanup channel)
- `finally` 안에서 throw 하면 outer 로 전파 (Java/JS 동일)
- `finally` 가 return 하면 try/catch 의 throw 가 swallow (Java 함정 — hexa 는 disallow 또는 warning 권장)

## 디자인 권장 (옵션 분기)

### 옵션 A: 두 가지 합쳐서 한 PR (large)

- 한 번에 try-expr + finally land
- 장점: 전체 error-handling surface 일관
- 단점: ~300줄, g4 위반 가능성

### 옵션 B: 분리 2 PR (권장)

1. `feat(parser+codegen): try-as-expression` — try/catch block value 추출 (~100줄)
2. `feat(parser+codegen): finally clause` — 항상-실행 cleanup block (~150줄)

### 옵션 C: defer 패턴 (Swift/Go 스타일)

- `defer { cleanup() }` 표현식, scope-end 실행
- `finally` 없이 cleanup 처리
- hexa 의 block-scope 모델과 잘 어울림
- 권장 follow-up: defer 를 panic 채널 RFC (r14-EE) 와 함께 closure

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/parser.hexa` | `parse_try_catch()` (L3839-L3865) 를 expression position 에서도 호출 가능하게 + `finally` 절 옵셔널 파싱 |
| `self/codegen.hexa` | try-expr 는 block-value 패턴 재사용 (`let x = { ... }`) · `finally` 는 setjmp/longjmp 또는 cleanup 콜백 등록 |
| `self/runtime_core.c` | exception unwind path 에 `finally` 콜백 실행 hook |
| `stdlib/io/file.hexa` 등 | defer-friendly 헬퍼 (옵션 C 채택 시) |

## 구현 단계 (옵션 B 기준)

1. **FF-1**: try-as-expression (parser+codegen, ~100줄)
2. **FF-2**: finally clause (parser+codegen+runtime, ~150줄)
3. **FF-3**: type-check try/catch arm type unification (~50줄)
4. (옵션) **FF-4**: defer 패턴 (별도 RFC 권장)

총 ~300줄, 3-4 PR stack.

## 우회책 (지금)

- try-expr 대신:
  ```hexa
  let mut x: T
  try { x = op() } catch (e) { x = default }
  ```
- finally 대신: 명시 듀얼-사이트
  ```hexa
  try {
      cleanup_register()
      op()
      cleanup_run()
  } catch (e) {
      cleanup_run()
      throw e
  }
  ```

## 관계 RFC

- r14-X postfix `?` + Result ABI (`inbox/patches/postfix-question-result-abi-rfc.md`, commit `2cf3e166`): try-expr 는 throw 짝
- r14-EE panic 채널 RFC (forward-ref, 미생성): try-expr 는 throw recover, panic 은 별도 채널
- r14-F/AA: silent miscompile silos (관련 없음)

## DUP-PRECHECK 결과

- `ls inbox/patches/ | grep -iE 'try.*expr|try.*expression|finally|cleanup'` → 매치 없음
- `git log origin/main --since='2026-05-23' --oneline -- inbox/patches/` → try-expr/finally 관련 신규 커밋 없음
- **결론**: 중복 없음 — 신규 RFC 진행 가능
