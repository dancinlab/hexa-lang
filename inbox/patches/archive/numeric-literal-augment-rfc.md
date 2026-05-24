# numeric literal augment (underscore separator + `0b`/`0o`) design RFC

**Status**: design-level (PROBE r14 cycle 9, 2026-05-23)
**Priority**: P3 (readability + 진수 literal — 최신 lang 공통 표면)
**SSOT**: 본 RFC · r14-B hex-float PR #473 · PROBE.log r14 round 1

## 현재 동작 (probe + grep 검증)

probe = `/tmp/probe_numeric_r14_*.hexa`, parsed with installed `hexa.real` (binary 0.1.0-dispatch) + cross-checked against `self/lexer.hexa` HEAD (origin/main `329d4b80`).

| 표현 | hexa 동작 | 비고 |
|---|---|---|
| `0x1F` (hex int) | ✅ OK | baseline (PROBE r1) |
| `0b1010` (binary) | ❌ lex error | `error: literal prefix \`0b\` (octal/binary) not supported … use decimal or \`0x\` hex` (lexer.hexa:230, 명시 reject) |
| `0o777` (octal) | ❌ lex error | 동일 reject path |
| `1_000_000` (underscore int) | ✅ OK | lexer.hexa:319 decimal underscore handling 존재 |
| `1_000.5_5` (underscore float) | ✅ OK | underscore가 fraction part도 통과 |
| `0xFF_FF` (hex + underscore) | ✅ OK | lexer.hexa:247 hex underscore handling |
| `0x1.8p+1` (hex float, dotted) | ❌ binary parse 오류 | source는 lexer.hexa:256-316 으로 land됨 (PR #473 merge 2026-05-23 13:22Z). 설치된 binary는 그 이전 빌드 → 재설치 시 해소 예상 |
| `0xFFp+0` (hex float, no dot) | ❌ binary parse 오류 | 동일 — bare `p`-suffix는 lexer.hexa:289 에서 `.<hex>` 없이도 처리하므로 source-level OK 예상 |
| `1__000` (double underscore) | ❌ lex error | "literal suffix `1_…` not supported" (보수적 reject) |
| `1000_` (trailing underscore) | ❌ lex error | 동일 |
| `_123` | (식별자 token) | numeric literal 아닌 ident — Rust/Python 동일 |

→ **gap**: `0b…` / `0o…` 두 가지가 land 必要. underscore 는 이미 작동.

## 캐노니컬

| 언어 | binary `0b` | octal `0o` | hex `0x` | underscore `1_000` |
|---|---|---|---|---|
| Rust | ✅ | ✅ | ✅ | ✅ (어디든) |
| Python | ✅ | ✅ | ✅ | ✅ (3.6+) |
| JS | ✅ | ✅ (ES6) | ✅ | ✅ (numeric separator, ES2021) |
| Java | ✅ | (옛 `0` prefix 만) | ✅ | ✅ (Java 7+) |
| Swift | ✅ | ✅ | ✅ | ✅ |
| Go | ✅ (1.13+) | ✅ `0o` (1.13+) | ✅ | ✅ (1.13+) |

→ Rust/Python/JS/Swift/Go 공통 — 모두 land 권장. 옛 C-style bare-`0123` octal 은 disallow (Python 2 함정).

## 디자인 결정

### 신택스
- `0b[01][01_]*` (binary)
- `0o[0-7][0-7_]*` (octal)
- `0x[0-9a-fA-F][0-9a-fA-F_]*` (hex, 이미 land)
- `[0-9][0-9_]*` (decimal with underscores, 이미 land)
- 부적격 underscore (`_123`, `123_`, `1__2`) → lex error (이미 land)

### 제약
- Underscore 가 prefix 직후 (`0b_1010`) — Rust/Python 허용 — **권장 허용** (Rust 캐노니컬)
- Underscore 가 마지막 자리 (`0b1010_`) — 모든 언어 disallow — error (현 정책 유지)
- Multiple consecutive (`1__000`) — Rust 허용, Python 금지, JS 금지 — **권장 disallow** (현 정책 유지, 보수적)
- Underscore in exponent (`1e1_0`) — Rust/Python 허용 — 권장 (decimal float 측, hex-float `p` exponent 동일 적용)

### 진수 prefix
- Lowercase 우선: `0b`/`0o`/`0x`
- Uppercase 도 허용: `0B`/`0O`/`0X` (Python style; hex lexer가 이미 `0X` 받음)
- 옛 C bare-`0…` octal 은 **계속 disallow** (Python 2 함정 방지) — `017` 은 decimal `17`

## 구현 단계 (stacked PRs)

| PR | 내용 | est. LOC |
|---|---|---|
| XXX-1 | lexer `0b` / `0o` prefix 인식 + 진수 변환 (lexer.hexa:230 reject 자리에 분기 추가) | ~60 |
| XXX-2 | underscore separator 를 binary/octal body 에도 적용 (decimal/hex 패턴 재사용) | ~30 |
| XXX-3 | 제약 검증 — leading/trailing/double underscore 가 신규 진수에도 동일하게 error | ~20 |
| XXX-4 | (선택) decimal-float 의 `e`-exponent underscore (`1e1_0`) + hex-float `p`-exponent underscore | ~40 |

총 ~150줄, 4-PR stack (g4 <200줄 PR-단위 충족).

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/lexer.hexa` | `scan_number` 진수 prefix 분기 + 진수 변환 (decimal int 으로 normalize 또는 prefix 보존 후 codegen 위임) |
| `self/parser.hexa` | 무변경 (token kind 그대로 IntLit/FloatLit) |
| `self/codegen_*.hexa` | C-backend 가 `0b`/`0o` literal 직접 emit 가능 (C23) — 단 portability 위해 lex 단계에서 decimal int 으로 normalize 권장 |

## 우회책 (지금)

- decimal: `1000000` (underscore 없이도, 있어도 OK)
- binary: `parseInt("1010", 2)` 류 런타임 헬퍼 또는 `0xA` 같은 hex 대체
- octal: `parseInt("777", 8)` 또는 `0x1FF` (= 511)
- hex: `0x1F` (이미 작동)

## 관계 RFC / PR

- r14-B hex-float PR #473: `0x1.8p+1` — XXX-4 의 exponent underscore 와 통합 surface 공유
- r14-A template-string warn PR #478: 무관 (string literal)
- r14-III multi-line string `"""…"""` PR #518: 무관 (string literal)
- 옛 `0o`/`0b` loud-reject PR #371: XXX-1 이 reject 분기를 land 분기로 전환
