# multi-line string `"""..."""` literal design RFC

**Status**: design-level (r14 cycle 8, 2026-05-23)
**Priority**: P3 (ergonomic — JSON/SQL/HTML 임베드 사용 사례)
**SSOT**: 본 RFC · r14-RR raw string RFC (sister, lexer 동일 영역) · r14-JJ Python f-string RFC (sister, lexer 동일 영역)

## 요약

probe 결과 hexa lexer 는 **이미 `"""..."""` triple-quoted multi-line literal 을 지원한다** (`self/lexer.hexa:396-441`). 본 RFC 는 기존 구현의 (a) **escape 처리 비일관성** 과 (b) **prefix 변종 (r/f) 미지원** 두 gap 을 다룬다. 새 기능 도입이 아니라 기존 부분 구현의 closure RFC.

## 현재 동작 (probe 검증, 2026-05-23)

| 표현 | hexa 동작 | 비고 |
|---|---|---|
| `"""hello"""` 단일 줄 | OK → `hello` | 정상 |
| `"""line 1\nline 2\nline 3"""` 멀티 줄 (literal newlines) | OK → 3 줄 출력 | 정상 |
| `"""\n  indented\n  text\n"""` (open `"""` 다음 newline) | OK, 선행 newline strip · trailing newline 유지 | 정상 (Python-A semantics) |
| `"""value=${x}"""` (`${...}`) | OK, 리터럴 `${x}` 출력 (warning 미surface) | warning 코드는 있으나 트리거 안 됨 — 분리 PR |
| `"""has "inner" quotes"""` | OK → `has "inner" quotes` | 정상 |
| `"""has \n escape \t inside"""` | `has \n escape \t inside` (literal backslash) | **GAP A — escape 비처리** |
| `""""""` (empty) | OK → empty string | 정상 |
| `"""{"name":"hexa"}"""` (JSON 임베드) | OK, 줄바꿈 보존 | 정상 |
| `r"""raw"""` (raw + triple) | parser OK · codegen FAIL (clang compile error) | **GAP B — r-prefix 미통합** |
| `f"""val={x}"""` (f-string + triple) | parser OK · codegen FAIL | **GAP C — f-prefix 미통합** |

→ 기본 `"""..."""` 는 작동, **escape 의미론** 과 **prefix 통합** 두 갈래가 design-level 결정 대상.

## 캐노니컬

| 언어 | 신택스 | indent 처리 | escape | 변종 |
|---|---|---|---|---|
| Python | `"""..."""` · `'''...'''` | 사용자 자유 (`textwrap.dedent`) | 처리 (`\n`/`\t`) | `r"""..."""` · `f"""..."""` |
| Scala | `"""..."""` | `.stripMargin` 메서드 | **비처리 (raw)** | `s"""..."""` interp |
| Swift | `"""\n...\n"""` | 자동 strip leading whitespace | 처리 | `"""\(x)"""` interp |
| Kotlin | `"""..."""` | `.trimIndent()` / `.trimMargin()` | **비처리 (raw)** | (없음, 자체가 raw) |
| Rust | (없음) | — | — | `r"..."` 가 multi-line 가능 |
| 현 hexa | `"""..."""` | 사용자 자유 (선행 newline strip) | **비처리** | (없음) |

→ hexa 현 동작 = **Scala/Kotlin 계 (raw-by-default)**. Python 과는 escape 처리에서 갈림.

## GAP A — escape 의미론 결정

regular `"..."` 는 `\n`/`\t`/`\\`/`\"`/`\0`/`\r` 모두 처리. 반면 `"""..."""` 는 **모든 backslash 를 literal 통과**.

### 옵션 A1: Scala/Kotlin 계 유지 (raw-by-default) ★ 권장
- `"""..."""` = raw, `\n` 은 literal 두 글자
- 멀티라인 의도에서 escape 가 필요한 경우는 드묾
- raw 가 정확히 JSON/SQL/regex 임베드 ergonomic 목적과 일치
- 장점: 현 동작 보존 · regex 패턴 (`"""(\d+)"""`) 자연
- 단점: 다른 single-quote 와 의미론 비대칭 (가르치기 어려움)

### 옵션 A2: Python 계 (escape 처리)
- `"""..."""` 도 single-quote 와 동일 escape 처리
- 장점: 일관성
- 단점: regex/path 임베드 시 `\\` 이중백슬래시 필요, raw 변종 (`r"""..."""`) 별도 도입 강제

### 옵션 A3: 명시 토글 (status quo + 문서화)
- 현 raw 동작을 spec 으로 박고 RFC 명시
- escape 가 필요하면 `format("\n").join([line1, line2])` 또는 single-quote concat
- 장점: zero-change, 빠른 closure
- 단점: 사용자 혼란 누적

→ **옵션 A1 권장**. 1줄 lexer 변경 없이 명세화. `r"""..."""` prefix 는 (raw 자체가 default 이므로) **silent no-op** 으로 받기. f-string 만 별도 prefix 필요 (GAP C).

## GAP B+C — prefix 변종 통합

| 조합 | 신택스 | 동작 | lexer 위치 |
|---|---|---|---|
| 기본 | `"""..."""` | raw multi-line (현재) | `lexer.hexa:399-441` |
| r 명시 | `r"""..."""` | raw multi-line (option A1 하 동일) | 신규 — `r` prefix 인식 후 동일 처리 |
| f 명시 | `f"""val={x}"""` | multi-line + `{name}` interp | r14-JJ RFC 가 single-quote `f"..."` 작업 중 → triple-quote 연장 |

→ r-prefix 는 **silent accept** (semantic no-op), f-prefix 는 **r14-JJ 통합 후** 추가.

## 디자인 결정 요약

1. **escape**: 옵션 A1 (raw-by-default) 채택 — 현 동작 spec 화
2. **r 변종**: silent no-op 으로 인식 (사용자 의도 표명용)
3. **f 변종**: r14-JJ f-string RFC closure 후 triple-quote 연장
4. **indent**: Python-A (사용자 책임) — stdlib `str.trim_indent()` 헬퍼 추가 옵션
5. **`${x}`**: warning surface 안 되는 issue 는 별도 PR (코드 경로는 lexer.hexa:426 에 있음)

## 구현 단계 (stacked PRs)

1. **III-1**: spec 화 — escape raw-by-default 동작 문서화 + 회귀 테스트 (~30 줄, doc + test only)
2. **III-2**: `r"""..."""` silent no-op prefix lexer 통합 (~20 줄, lexer 분기)
3. **III-3**: stdlib `str.trim_indent()` 헬퍼 (~40 줄, 옵션)
4. **III-4**: `f"""..."""` 변종 — r14-JJ 통합 후 (~30 줄)
5. **III-5**: `${...}` warning surface 버그 수사 — 분리 PR

총 ~120 줄, 4 PR stack (III-5 별도).

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/lexer.hexa` | `r"""..."""` prefix 분기 (~15 줄) · escape 동작 spec 화 (변경 없음) |
| `self/parser.hexa` | 무변경 (StringLit 토큰 동일) |
| `self/codegen.hexa` | 무변경 |
| `stdlib/string.hexa` | `trim_indent` 헬퍼 (옵션 III-3) |
| `LANG.md` / spec | 동작 문서화 |

## 우회책 (지금)

- escape 필요: single-quote concat — `"line 1\n" + "line 2\n" + "line 3"`
- format 사용: `format("{}\n{}\n{}", "line 1", "line 2", "line 3")`
- indent strip 필요: 수동 — `s.replace("\n  ", "\n")` 등

## 관계 RFC

- **r14-RR raw string `r"..."`** (sister): single-quote raw 변종 작업, triple-quote raw 는 본 RFC option A1 으로 이미 default
- **r14-JJ Python f-string `f"..."`** (sister): single-quote f-string 작업, triple-quote 연장은 본 RFC III-4 에서 통합
- 셋 다 `self/lexer.hexa:396` 부근 영역 공유 — 머지 순서 조심 (rebase race 위험)

## probe 재현

```hexa
fn main() {
    let s = """has \n escape"""
    println(s)   // 출력: has \n escape  (backslash literal)
}
```

```hexa
fn main() {
    let s = r"""raw"""
    println(s)   // hexa build 실패 (clang compile error, codegen 미통합)
}
```
