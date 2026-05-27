# compound assignment 완성도 design RFC

**Status**: rfc-draft-deferred-2026-05-25 — design-only patch (not a fix). Promote via /inbox skill if RFC track wanted.
**Status**: design-level + part-surgical (r14 cycle 9, 2026-05-23)
**Priority**: P3 (편의 — 산술 5종 + 논리/nullish 3종 동작, 비트/거듭제곱 6종 부재)
**SSOT**: PROBE.log round 1 line 22 · 본 RFC

## 현재 동작 (probe + grep 검증)

`hexa parse /tmp/probe_ca_<kind>.hexa` 개별 probe + `self/lexer.hexa` · `self/parser.hexa` grep.

| 연산 | 토큰 (lexer) | parse | AST kind | 의미 |
|---|---|---|---|---|
| `+=` | `PlusEq` (L561) | OK | CompoundAssign | a = a + b |
| `-=` | `MinusEq` (L575) | OK | CompoundAssign | a = a - b |
| `*=` | `StarEq` (L589) | OK | CompoundAssign | a = a * b |
| `/=` | `SlashEq` (L599) | OK | CompoundAssign | a = a / b |
| `%=` | `PercentEq` (L609) | OK | CompoundAssign | a = a % b |
| `??=` | `NullCoalescingAssign` (L719) | OK | LogicalAssign | a = a ?? b (short-circuit) |
| `\|\|=` | `OrAssign` (L688) | OK | LogicalAssign | a = a \|\| b (short-circuit) |
| `&&=` | `AndAssign` (L672) | OK | LogicalAssign | a = a && b (short-circuit) |
| `**=` | 없음 | FAIL `unexpected Eq` | — | a = a ** b |
| `<<=` | 없음 | FAIL `unexpected Eq` | — | a = a << b |
| `>>=` | 없음 | FAIL `unexpected Eq` | — | a = a >> b |
| `\|=` | 없음 | FAIL `unexpected Eq` | — | a = a \| b |
| `&=` | 없음 | FAIL `unexpected Eq` | — | a = a & b |
| `^=` | 없음 | FAIL `unexpected Eq` | — | a = a ^ b |

probe 출력 (요약): baseline 5종 + `??=` 모두 OK · 나머지 6종 `Parse error at N:M: unexpected token Eq ('=')`.

## 캐노니컬 비교

| 언어 | 산술 5 | bitwise 5 | `**=` | nullish/logical |
|---|---|---|---|---|
| Rust | ✅ | ✅ | ❌ | ❌ |
| Python | ✅ | ✅ | ✅ | ❌ |
| JS (ES2021) | ✅ | ✅ | ✅ | `\|\|=` `&&=` `??=` |
| Swift | ✅ | ✅ | ❌ | ❌ |
| Kotlin | ✅ | ❌ | ❌ | ❌ |
| **hexa (현재)** | ✅ | ❌ | ❌ | `\|\|=` `&&=` `??=` ✅ |

hexa 의 logical 3종은 이미 JS-ES2021 수준. 결손은 **bitwise 5 + `**=`**.

→ Python+JS 합집합 모델 권장: bitwise 5 (Rust/JS/Python 공통) + `**=` (Python/JS).

## 결정 사항

| 연산 | 추가 여부 | 우선순위 |
|---|---|---|
| `<<=` `>>=` `\|=` `&=` `^=` | ✅ 추가 권장 (bitwise 5종 완성) | P1 |
| `**=` | ✅ 추가 권장 (산술 set 완성) | P1 |

`\|\|=` `&&=` `??=` 이미 동작 — 추가 작업 없음.

## desugar 규칙

신규 6종은 모두 단순 desugar: `lhs op= rhs` → `lhs = lhs op rhs`.

- 기존 CompoundAssign 분기 (parser.hexa L1465-1475) 재사용 가능 — `op_str` 만 매핑 확장.
- 거듭제곱 `**=` 만 codegen `hexa_pow` 호출 (기존 `**` 와 동일).
- bitwise 5종은 기존 binary op (`|` `&` `^` `<<` `>>`) 의 codegen 경로 통과.
- LHS 가 식 (member access, index) 이면 단일 eval 보장: `arr[i] |= 1` → `({ let __tmp = i; arr[__tmp] = arr[__tmp] | 1; })` — r14-AA scope · r14-HH match-arm bind 와 동일 패턴.

## 구현 단계 (stacked PRs)

1. **WWW-1**: lexer 6 새 토큰 (`PowerEq` · `ShlEq` · `ShrEq` · `OrEq` · `AndEq` · `XorEq`) — ~40줄
2. **WWW-2**: parser CompoundAssign 분기에 6 토큰 추가, `op_str` 매핑 확장 — ~20줄 (같은 분기 재사용)
3. **WWW-3**: codegen `**=` 만 별도 검증 (`hexa_pow` 호출 — 기존 `**` 와 동일 경로) — ~10줄
4. **WWW-4**: golden test 6 fixture — ~50줄

총 ~120줄, 3-4 PR stack.

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/lexer.hexa` | 6 새 토큰 emit (`**=` `<<=` `>>=` `\|=` `&=` `^=`) |
| `self/parser.hexa` | CompoundAssign `is_assign_tok` + `op_str` 매핑 확장 |
| `self/codegen.hexa` | 없음 (기존 CompoundAssign 경로 통과) |
| test corpus | 6 golden |

## 우회책 (지금)

모두 명시 형태로 작성 가능:
- `a = a ** b`
- `a = a << b` · `a = a >> b`
- `a = a \| b` · `a = a & b` · `a = a ^ b`

## 관계 RFC / PR

- r14-KK Option/Some/None prelude (PR #505): `??=` 의존 (이미 작동)
- r14-X postfix `?` (PR #494): nullish operator family
- r14-AA scope leak (PR #496): LHS single-eval 보장 패턴 동일
- r14-HH match-arm bind (PR #516): single-eval 패턴 동일
- PROBE.log round 1 line 22: 기본 `+=`/`-=`/`*=`/`/=`/`%=` 동작 확인

## 검증 명령

```
hexa parse /tmp/probe_ca_baseline.hexa   # OK (5종)
hexa parse /tmp/probe_ca_nullish.hexa    # OK (??=)
hexa parse /tmp/probe_ca_power.hexa      # FAIL → P1 closure 후 OK 기대
hexa parse /tmp/probe_ca_shl.hexa        # FAIL → P1
hexa parse /tmp/probe_ca_shr.hexa        # FAIL → P1
hexa parse /tmp/probe_ca_bitor.hexa      # FAIL → P1
hexa parse /tmp/probe_ca_bitand.hexa     # FAIL → P1
hexa parse /tmp/probe_ca_bitxor.hexa     # FAIL → P1
```
