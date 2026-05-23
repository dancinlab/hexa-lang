# raw string `r"..."` literal design RFC

**Status**: design-level (r14 cycle 7, 2026-05-23)
**Priority**: P3 (편의 기능 — regex/path/JSON 리터럴 작성 ergonomics)
**SSOT**: 본 RFC · 캐노니컬 비교

## 현재 동작 (probe 검증 결과)

probe — `/tmp/probe_raw_str_r14*.hexa` × 4 케이스, `hexa run` (compiled path) 실행.

| 표현 | hexa 동작 | 비고 |
|---|---|---|
| `let s = r"foo"` | clang error: `use of undeclared identifier 'r'` | `r` 가 별도 식별자 토큰 |
| `let s = r"path\to\file"` | clang error: `use of undeclared identifier 'r'` | 동일 — `r` 분리 |
| `let s = R"foo"` | clang error: `use of undeclared identifier 'R'` | 대문자도 동일 |
| `let s = r"\n is two chars"` | clang error: `use of undeclared identifier 'r'` | escape 처리 무관, lexer 단계에서 분리 |

→ lexer 가 `r` / `R` 을 prefix 로 인식하지 않음 → `r` 식별자 + `"..."` StringLit 두 토큰으로 분리됨 → codegen 단계에서 `HexaVal s = r; "..."; ` 같은 잘못된 C 가 emit 되어 clang 이 거부.

infra grep — `self/lexer.hexa` · `self/parser.hexa` 에 `raw_str` / `RawStringLit` / `r"` 어떤 식별자도 없음. raw string 인프라 전무.

## 캐노니컬

| 언어 | 신택스 | 동작 |
|---|---|---|
| Rust | `r"..."` · `r#"..."#` (다중 # 으로 quote 포함 가능) | NO escape, 그대로 |
| Python | `r"..."` · `r'...'` | NO escape (단 종결자 직전 `\"` 미묘 케이스 제외) |
| C# | `@"..."` | NO escape, `""` = literal `"` |
| C++ | `R"(...)"` · `R"delim(...)delim"` | NO escape, delim 매칭 |
| Swift | `#"..."#` · `##"..."##` | NO escape + 다중 # 으로 escape opt-in |

→ Rust 모델 권장 — `r"..."` 단순 + `r#"..."#` 다중-quote 확장.

## 디자인 결정

### 옵션 A: Rust 모델 (`r"..."` + `r#"..."#`)
- `r"..."` 기본 raw — 백슬래시 escape 해석 없음
- `r#"..."#` quote 포함 가능 (`r#"He said "hi"."#`)
- `r##"..."##` 등 다중 `#` (드물게 필요 — 본문에 `"#` 가 있을 때)
- 장점: well-known, Rust 사용자 친화, hexa 의 다른 prefix 와 충돌 없음
- 단점: lexer 구현 약간 복잡 (delim count + 매칭)

### 옵션 B: Python 모델 (`r"..."`)
- 단일 prefix
- `r"He said \"hi\"."` — quote escape 만 인정, 나머지 raw
- 장점: 단순
- 단점: quote escape 가 raw-string 개념과 모순 (반쪽 raw)

### 옵션 C: C# 모델 (`@"..."`)
- `@"He said ""hi""."` — `""` = literal `"`
- 장점: 단순, 모든 escape 무시
- 단점: hexa 의 `@` 가 이미 attribute prefix (`@derive` · `@cold` 등) — 충돌

→ **옵션 A 권장** — Rust 캐노니컬, hexa 의 `@` 충돌 회피, 점진 확장 (RR-1 단순 → RR-2 다중-#) 가능.

## 구현 단계 (stacked PRs)

1. **RR-1**: lexer `r"..."` 기본 raw 인식 (~60줄) — `r` + 직후 `"` 검출 시 raw 모드, escape 미해석, StringLit 토큰 emit (parser 무변경)
2. **RR-2**: lexer `r#"..."#` 다중-# delim (~80줄) — `r` + N×`#` + `"` 본문 `"` + N×`#` 매칭
3. **RR-3**: regression — 기존 `"..."` 경로 무변경 확인 + 신규 케이스 (~10줄 테스트)

총 ~150줄, 3-PR stack.

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/lexer.hexa` | `r` prefix 인식 후 raw string 모드 진입 + delim count + 종결자 매칭 |
| `self/parser.hexa` | 무변경 (lexer 가 일반 StringLit 토큰 emit → parser path 동일) |
| `self/codegen.hexa` | 무변경 (string literal codegen 동일) |
| `self/runtime.c` | 무변경 |

## 우회책 (지금)
- 명시 escape: `let s = "path\\to\\file"` (`\\` 으로 `\` 표현)
- 단점: regex/path 작성 어려움, 깊은 escape (`\\\\\\\\` 같은) 빈번 — 가독성 저하

## 관계 RFC / PR

- PR #381 (format brace-escape `{{`/`}}`) — escape 처리 인접 영역
- f-string r14-JJ (sibling cycle 6 in-flight) — string lexer 동일 영역, 머지 순서 조심
- multi-line `"""..."""` RFC (별도 RFC 후보 — Python/Swift 캐노니컬)

## probe 부록

- `/tmp/probe_raw_str_r14.hexa` — `r"foo"`
- `/tmp/probe_raw_str_r14_b.hexa` — `r"path\to\file"`
- `/tmp/probe_raw_str_r14_c.hexa` — `R"foo"` (대문자)
- `/tmp/probe_raw_str_r14_d.hexa` — `r"\n is two chars"`

4 케이스 모두 lexer `r` / `R` identifier 분리로 clang `use of undeclared identifier` 실패. raw string 인프라 zero.
