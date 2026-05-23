# regex literal `/pattern/` design RFC

**Status**: design-level (r14 cycle 8, 2026-05-23)
**Priority**: P3 (편의 — `stdlib/regex` 이미 있으나 literal 신택스 부재)
**SSOT**: 본 RFC · `stdlib/regex/mod.hexa` (POSIX ERE wrapper, G3-REGEX 2026-05-06) · 캐노니컬 비교

## 현재 동작 (probe 검증)

probe 호스트 = `/Users/ghost/.hx/bin/hexa` (origin/main HEAD `0c3f9461`)

| 표현 | hexa 동작 (측정) |
|---|---|
| `let pat = /[a-z]+/` | `Parse error at 2:15: unexpected token Slash ('/')` |
| `let pat = re"[a-z]+"` (in `let` only) | parses — `re`는 식별자, `"[a-z]+"`은 인접 string literal (Adjacent-token artifact, prefix 아님) |
| `foo(re"abc")` | `Parse error at 2:11: expected RParen, got StringLit ('abc')` (call 인자 위치 fail) |
| `let pat = r"/abc/"` | parses — `r` 식별자 + string (raw-string prefix 미구현) |
| `regex_test("abc.*", "abcd")` | OK — `stdlib/regex/mod.hexa` 경유 POSIX ERE |

→ 결론: hexa lexer에 regex literal 개념 무. `/`는 `Slash`/`SlashEq` 전용 (lexer.hexa L597-606). `r"..."` raw-string prefix도 미구현 (lexer.hexa에 raw 키워드 없음). 즉 식별자+adjacent-string artifact는 prefix처럼 보일 뿐.

## 캐노니컬

| 언어 | literal | 컴파일 | flags |
|---|---|---|---|
| JS | `/pattern/gi` | engine runtime | `g`/`i`/`m`/`s`/`u`/`y` postfix |
| Perl | `/pattern/gi` | regex engine | 동일 |
| Ruby | `/pattern/i` | Onigmo | postfix |
| Rust | 없음 (proc-macro `regex!()` opt-in) | compile-time | `(?i)` inline |
| Python | 없음 (`re.compile(r"...")`) | runtime | `re.IGNORECASE` 등 enum |
| Swift 5.7+ | `/regex/` | compile-time | `(?i)` inline |

→ JS/Perl 모델 (`/pat/flags`)이 가장 ergonomic, 단 `/`가 divide operator와 충돌해 context-sensitive lexer 필요. Rust/Python은 lang 무변경 + stdlib 의존, Swift는 compile-time 검증을 살림.

## 디자인 결정 (4 옵션)

### 옵션 A: JS-style `/pattern/flags`
```hexa
let pat = /[a-z]+/i
let m = "hello".match(/h/)
```
- lexer가 expression-position의 `/` 다음 non-space 보면 regex 모드
- divide와 disambig: context (expression-position vs binary-op-position)
- 장점: well-known
- 단점: lexer 매우 복잡 (context-sensitive), hexa parser의 multi-line `Newline` 토큰 정책과 부딪힘

### 옵션 B: prefix `re"pattern"` (raw-prefix 패턴)
```hexa
let pat = re"[a-z]+"
let pat2 = re"[a-z]+"i  // flags postfix
```
- 장점: lexer 간단 (식별자 prefix lookahead + string lexer 재사용)
- 단점: 덜 표준
- 전제: raw-string prefix 인프라 (`r"..."`)가 먼저 필요 — 현재 미구현 (r14-RR raw string 작업과 묶음)

### 옵션 C: macro `regex!{pattern}` (Phase 2)
```hexa
let pat = regex!{ [a-z]+ }
```
- 장점: macro 인프라 재사용 (r14-W expander Phase 2 PR #462 후속)
- 단점: macro Phase 2 wait + brace-안 raw token stream policy 필요

### 옵션 D: stdlib only (현재 status quo)
- `regex_test("[a-z]+", "abc")` 또는 `regex_replace_all(pat, s, repl)` — 이미 가능
- 장점: lang 무변경
- 단점: ergonomic 떨어짐, flag 인자 별도 (POSIX `(?i)` inline 만 지원)

→ **옵션 B 권장** — `re"..."` prefix. raw-string `r"..."` 패턴과 mirror, lexer 변경 최소. 옵션 A의 context-sensitive `/`는 hexa lexer 정책 (Newline 토큰화) 재설계 필요. 옵션 C는 macro 인프라 의존성 큼.

## 동작 (옵션 B)

| 표현 | desugar |
|---|---|
| `re"[a-z]+"` | `Regex_new("[a-z]+", "")` |
| `re"[a-z]+"i` | `Regex_new("[a-z]+", "i")` |
| `re"[a-z]+"is` | `Regex_new("[a-z]+", "is")` |
| compile-time check | 패턴 syntax 검증 (선택 — Rust proc-macro 패턴) |

flags 세트 (POSIX ERE 한정): `i` (case-insensitive — 이미 `(?i)` 지원), `m` (multiline `^$`), `s` (dotall — POSIX ERE 미지원, 거절), `g` (global — call-site의 `_all` 변형으로 흡수).

## 구현 단계 (stacked PRs)

1. **MMM-1**: lexer raw-string `r"..."` 인식 (r14-RR 선행, ~50줄)
2. **MMM-2**: lexer `re"..."` regex prefix 인식 (`r"..."`와 동일 escape 정책 + 별도 토큰) (~30줄)
3. **MMM-3**: lexer flag postfix (i/m) — closing `"` 직후 alphanumeric run (~25줄)
4. **MMM-4**: parser RegexLit → `Regex_new(pattern, flags)` call desugar (~40줄)
5. **MMM-5**: stdlib/regex augment — `Regex` struct + `.new(pattern, flags)` constructor + `.match`/`.find_all` 메서드 (~80줄)
6. **MMM-6**: compile-time pattern syntax check (선택, 미니 POSIX ERE validator) (~120줄)

총 ~345줄, 5–6 PR stack. raw-string (MMM-1) 미선행 시 MMM-2가 raw-string-도-함께 도입하므로 +30줄.

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/lexer.hexa` | identifier prefix lookahead — `r`/`re` 다음 `"` 시 raw/regex 토큰 emit + flag postfix |
| `self/parser.hexa` | `RegexLit` AST → `Regex_new(pat, flags)` desugar (codegen 손대지 않음) |
| `self/codegen.hexa` | 무변경 (일반 fn call로 lower) |
| `stdlib/regex/mod.hexa` | `Regex` struct + `.new(pat, flags)` + 메서드 wrapping (`regex_test` 등 재사용) |

## 우회책 (지금)

- `regex_test("[a-z]+", "abcd")` — pattern을 일반 string으로 (escape `\\.` 두 번)
- `regex_test("(?i)[a-z]+", s)` — case-insensitive inline flag (POSIX `(?i)` 이미 지원)
- `regex_pcre_lite_translate("\\d+")` → POSIX ERE `[[:digit:]]+`로 사전 변환 후 `regex_test`

## 관계 RFC

- r14-RR raw string `r"..."` (논의 중, lexer prefix 인프라): re-prefix lexer 패턴 직접 mirror
- r14-W macro expander Phase 2 (PR #462 후속): `regex!{...}` macro 대안 (옵션 C)
- r14-III triple-quote `"""..."""` (sister cycle 8): multi-line regex 호환 prefix
- `stdlib/regex/mod.hexa` (G3-REGEX 2026-05-06 merged): existing API base, 옵션 B desugar 타깃
