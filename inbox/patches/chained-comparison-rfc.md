# chained comparison `a < b < c` (Python) design RFC

**Status**: design-level (PROBE r14 cycle 6, 2026-05-23)
**Priority**: P2 (편의 기능이라기보다 **silent miscompile 함정 제거** — 현재 C-스타일 결과를 silent 로 반환)
**SSOT**: 본 RFC · 캐노니컬 비교 + verified probe

---

## TL;DR

- hexa 는 **현재 chained comparison 을 C/JS 스타일로 silently 평가** (`(a<b)<c`).
- self/parser.hexa:2963 의 `G16` chain 코드는 **dead** — 안쪽 `parse_bitwise` 가 cmp 를 좌결합으로 선소비.
- probe 5 케이스 중 3 silent miscompile, 2 우연 일치. g1 (no-silent-wrong) 위반.
- 권장: 옵션 B (진단) → 옵션 A (Python chain desugar) 2-phase.

---

## 현재 동작 (probe-verified, 2026-05-23 origin/main `2ebdcfa7`)

probe `/tmp/probe_chained_cmp_r14.hexa`, `hexa-run` 결과:

| 사이트 (let x=5; a=b=c=7; p=1,q=5,r=2) | hexa 출력 | C-style 의미 | Python 의미 | 판정 |
|---|---|---|---|---|
| `0 < x < 10` | `c1: in` | `(0<5)<10` = `1<10` = true | `0<5 && 5<10` = true | 우연히 같음 |
| `0 <= x <= 10` | `c2: in` | `(0<=5)<=10` = `1<=10` = true | `0<=5 && 5<=10` = true | 우연히 같음 |
| `a == b == c` (모두 7) | `c3: not-all-eq` | `(7==7)==7` = `1==7` = false | `7==7 && 7==7` = true | **silently WRONG** |
| `p < q > r` (1<5>2) | `c4: no-peak` | `(1<5)>2` = `1>2` = false | `1<5 && 5>2` = true | **silently WRONG** |
| `20 < x < 10` (x=5) | `c5: in` | `(20<5)<10` = `0<10` = true | `20<5 && 5<10` = false | **silently WRONG** |

→ **5케이스 중 3 silent miscompile, 2 우연 일치**. g1 canonical (no-silent-wrong) 위반.

### parser 구조 (G16 dead 이유)

`parse_comparison` (G16 chain @2964) → 안쪽 `parse_bitwise` (좌결합 cmp loop @2995) 가 `Lt|Gt|LtEq|GtEq|EqEq|NotEq` 를 모두 선소비 → 복귀 시 cmp 안 남음 → G16 안 들어감. 추가로 `is_comparison_op` (@763) 가 `Le`/`Ge` 쓰는데 토크나이저는 `LtEq`/`GtEq` emit → 토큰 이름 mismatch. 이중 dead.

---

## 캐노니컬 비교

| 언어 | `0 < x < 10` 의미 |
|---|---|
| Python | `0 < x and x < 10` (chain, x 단일 eval, short-circuit) |
| Julia | 동일 (Python chain) |
| Mathematica | 동일 |
| C/C++/Java/JS | `(0 < x) < 10` = `bool < 10` (silently 잘못된 의미) |
| Rust | parse error (chained cmp 금지, `comparison operators cannot be chained`) |
| Swift | parse error (`adjacent operators are in non-associative precedence group`) |
| Go | parse error |

→ **silently-wrong** 진영 (C/C++/Java/JS) 채택은 g1 canonical 위반.
→ 정직한 두 선택지: (A) Python chain · (B) Rust/Swift/Go parse-error.

---

## 옵션 비교

### 옵션 A: Python chain desugar (권장 최종)

```hexa
if 0 < x < 10 { ... }    // ≡ if (0 < x) && (x < 10) { ... }
if a == b == c { ... }   // ≡ if (a == b) && (b == c) { ... }
```

- parser 가 cmp+cmp 시퀀스를 ChainedCmp 노드로.
- 중간 식은 **let-bind 단일 eval** (`f()<g()<h()` 에서 `g()` 1회).
- short-circuit 표준 `&&` 시맨틱.
- 장점: Pythonic, g1 충족. 단점: 기존 `(a<b)<c` 그룹 의도 silent 변경.

### 옵션 B: parse-time 금지 (권장 phase 1)

```
error: chained comparison `a < b < c` is not allowed
hint: use `0 < x && x < 10` (explicit)
```

- Rust/Swift/Go 캐노니컬. silent miscompile 0.
- 단점: 편의 없음.

### 옵션 C: env-gate hybrid (비추)

`HEXA_CHAINED_CMP=1` opt-in. env 마법 → g1 single-meaning 위반.

→ **권장**: phase1 옵션 B → phase2 옵션 A. 옵션 B 가 모든 사용처를 명시화 → 옵션 A 채택 시 silent 변경 없음.

---

## 디자인 세부 (옵션 A, 단계 2)

### 인식 패턴

`parse_bitwise` 좌결합 loop 의 cmp 분기를 ChainedCmp 빌더로 교체. 첫 cmp 후 두 번째 cmp 가 나오면 operand/op 배열로 누적 → ops.len==1 이면 기존 BinOp, ≥2 이면 ChainedCmp.

### Desugar

```
a < b < c
→ ChainedCmp { operands=[a,b,c], ops=["<","<"] }
→ let __t1 = b; (a < __t1) && (__t1 < c)
```

길이 N → 중간 N-2 개 let-bind (양 끝은 1회 쓰이므로 skip). short-circuit `&&` 표준. 타입 호환성은 인접쌍별.

### 연산자/케이스

- `<`, `<=`, `>`, `>=`, `==`, `!=` 모두 chain. 방향 mix `a<b>c` 허용 (Python 동일).
- `a == b == c` = 3-way equality. `!=` chain 은 동일 desugar 이지만 lint 권고.
- 보존: `(a<b)<c` 명시 그룹은 C 의미 유지 (별도 cycle 에서 type-check), `a+b<c+d` 는 cmp 1회로 chain 아님.

---

## 구현 단계 (stacked PRs)

1. **MM-1 (옵션 B 진단)**: `parse_bitwise` 의 cmp loop 가 두 번째 cmp 만나면 즉시 진단 + hint. (~40줄)
2. **MM-2 (ChainedCmp AST)**: 진단 자리에 ChainedCmp 노드 빌드 + `is_comparison_op` 의 `Le`/`Ge` → `LtEq`/`GtEq` 정리. (~60줄)
3. **MM-3 (codegen desugar)**: ChainedCmp → let-bind + && chain emit. (~60줄)
4. **MM-4 (G16 dead code 정리)**: `parse_comparison` 의 dead chain loop 제거. (~30줄)
5. **MM-5 (selftests)**: 5케이스 + side-effect 단일-eval + short-circuit + 방향 mix. (~50줄)

총 ~240줄, 5-PR stack. (g4 PR 당 <200줄 충족.)

---

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/parser.hexa` | cmp+cmp 인식 + ChainedCmp AST + G16 dead code 정리 + `is_comparison_op` 토큰 이름 정합 |
| `self/codegen.hexa` | ChainedCmp desugar → let-bind + && chain |
| `self/type_checker.hexa` (있다면) | chain 각 인접 쌍 타입 호환성 |
| `selftests/parser/` | 새 케이스 5+α |
| `selftests/codegen/` | side-effect 단일-eval golden |

---

## 우회책 (지금)

- 명시 `&&`: `if 0 < x && x < 10 { ... }`
- 명시 괄호로 C 의미 강제 (드물지만): `if (0 < x) && (x < 10) { ... }` 또는 의도가 정말 `bool < int` 면 explicit cast.

---

## 관계 RFC

- r14-M `0...N` inclusive range (PR #491): 무관.
- r14-L print_val NaN/inf (PR #492): 무관.
- r14-EE panic 채널: 무관.
- r14-FF try-expr: 무관.
- r14-LL tuple type (sister RFC, this cycle): 무관.
- 잠재 시너지: type-checker 가 `bool < int` 를 거부하는 별도 RFC (현재 cycle 외) — 옵션 A 채택 후 group 형 `(a<b)<c` 의 silent miscompile 도 제거.

---

## 우려사항 (mitigation)

1. **C/JS 사용자 가정 변화**: `(a<b)<c` group 의도 시 silent 변경 → 옵션 B 먼저 ship 후 옵션 A.
2. **side-effect 단일-eval**: let-bind 잊으면 `g()` 가 두 번 호출 → golden test boxing.
3. **G16 dead code 잔존**: parser.hexa:2963 잘못된 주석 ("pure expressions") → MM-4 에서 제거.
4. **`==` chain 직관**: C 출신은 `(a==b)==c` 기대 → 진단 phase hint 로 교육.
