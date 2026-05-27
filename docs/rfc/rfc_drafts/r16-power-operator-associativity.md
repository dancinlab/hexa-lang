# r16 RFC — `**` (power) 연산자 우결합성 + unary-power 우선순위

- **Status**: design-draft (구현 대상 명세 · 별도 surgical PR 가 본 문서에 대해 구현)
- **Date**: 2026-05-25
- **Severity**: MEDIUM (correctness-deviation · 수학/Python canonical 과 불일치 · silent wrong-answer)
- **Source**: PROBE r16 — "`**` associativity + unary-power precedence" deviation sweep
- **Lane**: docs-only. 본 문서는 명세이며 컴파일러 소스(`self/parser.hexa` / `self/codegen.hexa`)는 건드리지 않음.

---

## 1. 배경 — 현 동작 + 측정 evidence

hexa 는 `**` (power) 연산자를 지원하며 codegen 이 `hexa_pow(l, r)` 로 lower 한다
(`self/codegen.hexa:5028` · `2969` · `5368`). 그러나 **결합성(associativity)** 과
**unary-minus 와의 우선순위** 두 측면이 수학/Python canonical 과 어긋난다.

### 1.1 confirmed 현 동작 (probe evidence)

현 main (`origin/main` @ `3de45d9f`) 의 self-hosted transpiler (`hexa-cc`,
`self/native/hexa_v2`) 로 아래 probe 를 직접 transpile → `clang` 컴파일 → 실행:

```hexa
// /tmp/pow_probe.hexa
fn main() {
    println(2 ** 3 ** 2)      // [A]
    println(2 ** 2 ** 3)      // [B]
    println(-2 ** 2)          // [C]
    let a = -2
    println(a ** 2)           // [D] sanity
    println(0 - (2 ** 2))     // [E] sanity
    println((0 - 2) ** 2)     // [F] sanity
    println(2 ** 3)           // [G] base
    println(3 ** 2)           // [H] base
}
```

```
$ /tmp/v2pow /tmp/pow_probe.hexa /tmp/pow_probe.c
OK: /tmp/pow_probe.c
$ clang -O0 /tmp/pow_probe.c self/runtime.c -I self -o /tmp/pow_probe
$ /tmp/pow_probe
64       ← [A]  2 ** 3 ** 2
64       ← [B]  2 ** 2 ** 3
4        ← [C]  -2 ** 2
4        ← [D]  a ** 2   (a = -2)
-4       ← [E]  0 - (2 ** 2)
4        ← [F]  (0 - 2) ** 2
8        ← [G]  2 ** 3
9        ← [H]  3 ** 2
```

측정 해석:

| probe | hexa 출력 | hexa 가 parse 한 형태 | math/Python canonical | canonical 값 |
|---|---|---|---|---|
| `2 ** 3 ** 2` | **64** | `(2 ** 3) ** 2` (LEFT) | `2 ** (3 ** 2)` (RIGHT) | **512** |
| `2 ** 2 ** 3` | **64** | `(2 ** 2) ** 3` (LEFT) | `2 ** (2 ** 3)` (RIGHT) | **256** |
| `-2 ** 2` | **4** | `(-2) ** 2` (unary 가 tighter) | `-(2 ** 2)` (`**` 가 tighter) | **-4** |

두 deviation 은 **결합(coupled)** 되어 있다 — 둘 다 `**` 가 현 parser 의
precedence 표에서 잘못된 자리에 있기 때문이다.

### 1.2 진단 — 왜 이렇게 parse 되는가

근본 원인은 `self/parser.hexa` 의 precedence-climbing 구조에서 `**` 가
**multiplication 과 동일한 tier** 에 놓여 있고, 그 tier 가 좌결합 `while`-loop
폴딩이라는 점이다.

**(원인 1 — 좌결합)** `parse_multiplication()` (`self/parser.hexa:3281`, "Level 5.5"):

```hexa
fn parse_multiplication() {
    let mut left = parse_unary()
    while p_peek_kind() == "Star" || p_peek_kind() == "Slash"
       || p_peek_kind() == "Percent" || p_peek_kind() == "Power"   // ← ** 가 여기
       || (p_peek_kind() == "Newline" && p_continue_bin_op(["Star","Slash","Percent","Power"])) {
        let op_tok = p_advance()
        p_skip_newlines()
        let right = parse_unary()
        left = #{ "kind": "BinOp", "op": op_tok.value, "left": left, "right": right, ... }
                 // ← left 누적 = 좌결합 폴딩
    }
    return left
}
```

`Power` 가 `Star`/`Slash`/`Percent` 와 같은 `while` 안에서 처리되므로,
`2 ** 3 ** 2` 는 `left = BinOp(2, **, 3)` → `left = BinOp((2**3), **, 2)` 로
**좌결합 폴딩**된다 → `(2**3)**2 = 64`.

**(원인 2 — unary 가 `**` 보다 tighter)** `parse_unary()`
(`self/parser.hexa:3300`, "Level 5.6") 는 multiplication 보다 **아래**(=더 tight)
tier 다:

```hexa
fn parse_unary() {
    let k = p_peek_kind()
    if k == "Plus" || k == "Not" || k == "Minus" || k == "BitNot" {  // ← unary -
        let op_tok = p_advance()
        let operand = parse_unary()
        return #{ "kind": "UnaryOp", "op": op_tok.value, "left": operand, ... }
    }
    ...
    return parse_postfix()
}
```

`parse_multiplication` 의 `let mut left = parse_unary()` 가 `-2` 를 먼저
`UnaryOp(-, 2)` 로 통째로 흡수한 **뒤** `** 2` 가 그 결과에 붙는다 →
`(-2) ** 2 = 4`. Python 은 반대로 `**` 가 unary 보다 tighter → `-(2**2) = -4`.

요약: `**` 는 (a) 좌결합이고 (b) unary-minus 보다 느슨하다 — 둘 다 canonical 의 반대.

---

## 2. Canonical 조사표

| 언어 | `**` 존재 | 결합성 | `**` vs unary `-` | `-2 ** 2` 결과 | `2 ** 3 ** 2` 결과 |
|---|---|---|---|---|---|
| **Python** | ✅ | **RIGHT** | `**` tighter (단 좌측 unary 예외)¹ | **-4** | **512** |
| **Ruby** | ✅ | **RIGHT** | `**` tighter | **-4** | **512** |
| **F#** | ✅ | **RIGHT** | `**` tighter | **-4** | **512** |
| **JavaScript** (ES2016 `**`) | ✅ | **RIGHT** | ungrouped unary-base = **SyntaxError**² | (오류) | **512** |
| **Fortran** | ✅ | **RIGHT** | `**` tighter | **-4** | **512** |
| **Rust** | ❌ (`.pow()`/`.powi()`/`powf()`) | — | — | n/a | n/a |
| **Go** | ❌ (`math.Pow`) | — | — | n/a | n/a |
| **C/C++** | ❌ (`pow()`) | — | — | n/a | n/a |
| **현 hexa** | ✅ | **LEFT** ✗ | unary tighter ✗ | **4** ✗ | **64** ✗ |

¹ Python 미묘점: `**` 는 **우측** operand 의 unary 보다 느슨하다 (`2 ** -1` 정상,
`(2) ** (-1)`). 하지만 **좌측** base 의 unary 보다는 tighter — `-2 ** 2` =
`-(2**2)` = `-4`. 즉 `**` 는 좌측 unary 만 outrank 한다.

² JavaScript 는 모호성을 아예 금지: `-2 ** 2` 는 `SyntaxError: Unary operator used
immediately before exponentiation expression` — 사용자가 `(-2)**2` 또는
`-(2**2)` 로 명시하게 강제한다 (우측 unary `2 ** -1` 은 허용).

**핵심 합의**: `**` 를 가진 **모든** 수학-canonical 언어는 (1) **우결합**이고
(2) `**` 가 **좌측 unary-minus 보다 tighter** 다. hexa 만 둘 다 반대다.

---

## 3. 제안 — right-assoc + power-precedence (Option A 권고)

### 3.1 권고: Option A (Python/math canonical) — `**` 우결합 + `**` > 좌측 unary

| 항목 | 제안 |
|---|---|
| 결합성 | **RIGHT** — `a ** b ** c` = `a ** (b ** c)` |
| `**` vs 좌측 unary `-` | **`**` tighter** — `-2 ** 2` = `-(2 ** 2)` = **-4** |
| `**` vs 우측 unary `-` | `**` 느슨 (canonical) — `2 ** -1` = `2 ** (-1)` (정상) |
| 마이그레이션 | 기존 코드 영향 거의 0 (§5 측정) |

이유:
- hexa 의 `**` 는 이미 Python-style surface 다 (`**`, `**=`). 결합성/우선순위도
  Python 을 따르는 것이 **least-surprise**.
- §5 에서 측정한 대로 현 코드베이스에 chained `**` / unparenthesized unary-base
  `**` 가 **0건** → 깨질 코드가 없다.

### 3.2 대안: Option B (JavaScript) — 우결합 + ungrouped unary-base 금지

- `**` 우결합은 동일하게 채택.
- `-2 ** 2` 같은 **ungrouped 좌측 unary-base 는 parse error** 로 막고 사용자가
  `(-2)**2` / `-(2**2)` 명시 강제.
- 장점: 가장 모호성 없음. 단점: hexa 는 dynamically-typed + lint-light 지향이라
  새 syntax-error class 도입은 표면 비용. 또한 우측 unary (`2 ** -1`)는 허용해야
  해서 비대칭 규칙이 parser 에 추가됨.
- **판정**: B 보다 **A 권고**. A 는 추가 error-path 없이 precedence-table 한 칸
  이동만으로 canonical 달성. B 의 "강제 괄호" 안전성은 hexa 의 dynamic-lang
  ergonomic 철학(`?` RFC r15-D2, `+x` identity 등 looser 입장)과 결이 다르다.

### 3.3 precedence-table 변경 (정확한 편집 위치)

핵심: `**` 를 multiplication tier 에서 **꺼내** unary 보다 **위(더 tight)** 에
독립 tier 로 신설하고, 그 tier 를 **우결합**으로 구현.

현 tier 순서 (느슨 → tight):

```
... 5.4 addition (+ -)
    5.5 multiplication (* / % **)   ← ** 가 여기 (좌결합, * 와 동급)
    5.6 unary (! - ~ typeof)
    5.7 postfix (call/index/field)
    5.8 primary
```

제안 tier 순서:

```
... 5.4 addition (+ -)
    5.5 multiplication (* / %)      ← ** 제거
    5.6 unary (! - ~ typeof)        ← operand 가 parse_power() 호출하도록 변경
    5.7 power (**)                  ← 신규 tier, 우결합, unary 보다 tight
    5.8 postfix (call/index/field)
    5.9 primary
```

구체 편집 (모두 `self/parser.hexa`, **본 RFC 는 편집하지 않음**):

**(1)** `parse_multiplication()` (`:3281`) 의 `while` 조건에서 `Power` 두 군데
제거 → `* / %` 만 좌결합 처리:

```hexa
// AFTER
while p_peek_kind() == "Star" || p_peek_kind() == "Slash" || p_peek_kind() == "Percent"
   || (p_peek_kind() == "Newline" && p_continue_bin_op(["Star","Slash","Percent"])) {
    ...
    let right = parse_unary()   // 변경 없음
    ...
}
```

**(2)** `parse_unary()` (`:3300`) 의 `! - ~`·`await`·`typeof` 세 arm 의 재귀
operand 호출을 `parse_unary()` → `parse_power()` 로 바꿔, unary 가 power 를
operand 로 받게 한다 (이로써 `**` 가 unary 보다 tight 해짐). 또한 fall-through
`return parse_postfix()` → `return parse_power()`:

```hexa
// AFTER (대표 arm)
if k == "Plus" || k == "Not" || k == "Minus" || k == "BitNot" {
    let op_tok = p_advance()
    let operand = parse_power()    // ← parse_unary() 였음
    return #{ "kind": "UnaryOp", "op": op_tok.value, "left": operand, ... }
}
...
return parse_power()               // ← parse_postfix() 였음
```

**(3)** 신규 `parse_power()` tier 추가 (multiplication 과 unary 사이 호출 그래프,
구현은 우결합 — operand 로 다시 `parse_unary()` 를 호출해 **우측** unary 를 허용하고
재귀로 우결합 폴딩):

```hexa
// Level 5.7: ** (power) — RIGHT-associative, binds tighter than unary minus.
fn parse_power() {
    let base = parse_postfix()                 // 좌측 base = unary 없는 postfix
    if p_peek_kind() == "Power"
       || (p_peek_kind() == "Newline" && p_continue_bin_op(["Power"])) {
        p_skip_newlines_if_op("Power")          // (newline-continuation 헬퍼)
        let op_tok = p_advance()
        p_skip_newlines()
        let exp = parse_unary()                 // ← 우측은 unary 허용 (2 ** -1)
                                                //    parse_unary 가 다시 parse_power 호출 → 우결합
        return #{ "kind": "BinOp", "op": op_tok.value, "left": base, "right": exp, ... }
    }
    return base
}
```

호출 그래프 핵심:
- `parse_multiplication` → `parse_unary` (변경 없음).
- `parse_unary` 의 operand → `parse_power` (편집 2).
- `parse_power` 의 base → `parse_postfix`, exponent → `parse_unary`.

이 구조로:
- **우결합**: `2 ** 3 ** 2` → `parse_power` base=2, exp=`parse_unary`→`parse_power`
  base=3, exp=`parse_unary`→`parse_power` base=2 → `2 ** (3 ** 2)` = 512. ✅
- **`**` > 좌측 unary**: `-2 ** 2` → `parse_unary` 가 `-` 본 뒤 operand=`parse_power`
  → `parse_power` base=2, exp=2 → `2**2`, 그 위에 unary `-` → `-(2**2)` = -4. ✅
- **우측 unary 허용**: `2 ** -1` → `parse_power` base=2, exp=`parse_unary`→`-1` →
  `2 ** (-1)`. ✅

### 3.4 codegen 영향 — **없음** (parse-tree-shape only)

codegen 은 `op == "**"` BinOp 를 `hexa_pow(l, r)` 로 lower 할 뿐
(`self/codegen.hexa:5028` · `2969` · `5368`), 트리 모양에 무관하다. 즉 이번
변경은 **순수하게 parser 가 만드는 BinOp 트리의 중첩 방향** 문제이며,
`self/codegen.hexa` · `self/runtime.c` 는 **건드릴 필요 없다**. `**=`
(compound-assign, `PowerEq`) 도 별도 경로(`:1489`)라 무영향.

---

## 4. Acceptance probes (falsifiable — post-change 기대값)

각 probe = hexa source + 변경 후 기대 stdout. 구현 PR 은 이 표에 대해 구현+검증.

| ID | probe | **현 (LEFT) 출력** | **변경 후 기대 (RIGHT/canonical)** | 검증 대상 |
|---|---|---|---|---|
| **F-R16-1** | `println(2 ** 3 ** 2)` | `64` | **`512`** | 우결합 |
| **F-R16-2** | `println(2 ** 2 ** 3)` | `64` | **`256`** | 우결합 (비대칭 확인) |
| **F-R16-3** | `println(-2 ** 2)` | `4` | **`-4`** | `**` > 좌측 unary |
| **F-R16-4** | `println(2 ** -1)` 또는 float | (현재 `2 ** -1`) | `2 ** (-1)` (우측 unary 허용, parse OK) | 우측 unary 보존 |
| **F-R16-5** | `println((-2) ** 2)` | `4` | **`4`** (불변) | 명시 괄호 회귀 금지 |
| **F-R16-6** | `println(-(2 ** 2))` | `-4` | **`-4`** (불변) | 명시 괄호 회귀 금지 |
| **F-R16-7** | `println(2 ** 3)` / `println(3 ** 2)` | `8` / `9` | `8` / `9` (불변) | 단일 `**` base-case 회귀 금지 |
| **F-R16-8** | `println(2 * 3 ** 2)` | **`36`** (측정: `(2*3)**2`) | **`18`** (=`2 * (3**2)`, `**` > `*`) | `**` > multiplication tier 신설 |
| **F-R16-9** | self-host `hexa build self/main.hexa` gen1.s ≡ gen2.s | — | byte-eq | fixpoint 회귀 금지 |

회귀 gate (반드시 통과):

| ID | probe | 기대 |
|---|---|---|
| **F-R16-R1** | `x **= 2` (compound-assign) | parse+codegen OK — `PowerEq` 경로 무영향 |
| **F-R16-R2** | `a * b / c % d` | 좌결합 유지 (multiplication tier 변경 없음) |

> **F-R16-8 주의 (측정됨)**: `**` 는 현재 multiplication 과 **같은 tier** 라
> `2 * 3 ** 2` 가 좌결합으로 `(2*3)**2` = **36** 으로 계산된다 (측정 확인,
> `origin/main` @ `3de45d9f`). canonical 은 `**` 가 `*` 보다 tighter →
> `2 * (3**2)` = **18**. §3.3 의 신규 power-tier(=mul 아래, 더 tight) 가 이를
> 자동 해결한다. 참고로 `2 ** 3 * 2` 는 현재 `(2**3)*2` = `16` 으로 canonical 과
> 우연히 일치(측정 16) — 좌결합이 우연히 같은 값을 내는 경우.

---

## 5. Migration 위험 — 측정 결과 거의 0

현 main 전체 `.hexa` 코퍼스를 grep 으로 정적 조사 (markdown-bold `**text**`
문자열 리터럴 제외):

| 패턴 | 측정 | 영향 |
|---|---|---|
| arithmetic chained `a ** b ** c` (결합성 민감) | **0건** | 우결합 전환으로 깨질 코드 없음 |
| ungrouped 좌측 unary-base `-x ** y` (우선순위 민감) | **0건** | `**` > unary 전환으로 깨질 코드 없음 |
| 단일 `**` (e.g. `x ** 2`, `10.0 ** decade`) | 다수 (numerics·firmware) | **무영향** — 단일 연산은 결합성/우선순위 불변 |
| markdown `**bold**` in string-literals | 69+ 매치 | parser 와 무관 (string token 내부) — 무영향 |

조사 명령 (재현 가능):

```
# chained 산술 power (string-bold 제외): 결과 = atlas raw-body 내 "2**sopfr"/"[10**]"
#   문자열 2건뿐 → 실제 arithmetic chained = 0
grep -rnE '[0-9a-zA-Z_)\]] *\*\* *[0-9a-zA-Z_(].*[0-9a-zA-Z_)\]] *\*\* *[0-9a-zA-Z_(]' \
     --include='*.hexa' . | grep -vE '"\*\*|\*\*"|//|/\*'
```

**결론**: 본 변경은 기존 코드에 대해 **실질적으로 zero-risk** 다. 깨질 수 있는
유일한 경우는 (a) chained `**` 에 좌결합을 의도적으로 의존하거나 (b)
unparenthesized `-x ** y` 를 `(-x)**y` 로 의도한 코드인데, 둘 다 코퍼스에 0건.
혹시 외부(사용자) 코드가 의존한다면, 그 코드는 애초에 math/Python 직관과 반대로
동작하던 것이므로 canonical 전환이 오히려 잠재 버그를 드러낸다.

마이그레이션 안내(릴리즈 노트용): "기존에 chained `**` 또는 `-x ** y` 를 썼고
**좌결합/unary-tighter 동작에 의존했다면**, 명시 괄호 `(a**b)**c` / `(-x)**y` 로
바꿔라. 단일 `x ** y` 는 영향 없음."

---

## 6. Open questions

| # | 질문 | 잠정 입장 |
|---|---|---|
| Q1 | Option A (Python: `**` > 좌측 unary) vs Option B (JS: ungrouped unary-base 금지) | **A 권고** (§3.2) — 추가 error-path 없이 precedence-table 한 칸 이동. dynamic-lang ergonomic 일관성. |
| Q2 | 우측 unary `2 ** -1` 은 허용해야 하나 | **YES** — Python/Ruby/JS 모두 허용. `parse_power` 의 exponent 가 `parse_unary` 호출(§3.3) 이라 자연 보장. |
| Q3 | `**` 가 multiplication 보다 tighter 임을 명시 tier 로 분리하면 `2 * 3 ** 2` 동작이 바뀌나 | **측정됨**: 현재 `2*3**2` = `36` (=`(2*3)**2`, 같은-tier 좌결합) → 신규 power-tier 후 `2*(3**2)` = `18` (canonical). 이는 의도된 개선 (현재 `**`는 `*`보다 tighter 가 아니었음). §5 코퍼스에 `* … **` 혼용 산술도 0건이라 영향 없음. |
| Q4 | `**=` (PowerEq) compound-assign 결합성 | 무관 — 단일 assign, 우선순위 변경 없음 (F-R16-R1 가드). |
| Q5 | float vs int power (`2.0 ** 3` 등) | 본 RFC scope 밖 — `hexa_pow` 런타임 타입 처리는 별개. 결합성/우선순위만 다룸. |
| Q6 | 변경을 silent 로 할지, deprecation-window 줄지 | 코퍼스 영향 0건 → silent canonical 전환 가능. 릴리즈 노트에 §5 마이그레이션 안내만 기재. |

---

## 7. References

- 측정 대상: `origin/main` @ `3de45d9f` · self-hosted transpiler `self/native/hexa_v2`
  (hexa-cc) 직접 transpile (`/tmp/pow_probe.hexa` → `clang` → 실행).
- parser precedence 구조: `self/parser.hexa:3263` (`parse_addition`, Level 5.4) ·
  `:3281` (`parse_multiplication`, Level 5.5 — `**` 현 위치) ·
  `:3300` (`parse_unary`, Level 5.6) · `:3354` (`parse_postfix` fall-through).
- lexer 토큰: `self/lexer.hexa:900` (`PowerEq` `**=`) · `:904` (`Power` `**`).
- codegen lowering (트리-모양 무관, 무수정 대상):
  `self/codegen.hexa:5028` (`op == "**"` → `hexa_pow(l, r)`) · `:2969` (compound) ·
  `:5368` (builtin pow-call shape).
- canonical: Python Language Reference §6.5 (power operator, right-assoc, binds
  tighter than left unary) · Ruby `**` · F# `**` · ECMAScript 2016 `**`
  (right-assoc + ungrouped-unary-base SyntaxError) · Fortran `**`.
- 비-`**` 언어: Rust `i32::pow`/`f64::powi`/`powf` · Go `math.Pow` · C `pow()`.
- [[r15-d2-question-operator]] — 동일 docs-lane RFC 포맷 + dynamic-lang looser
  입장 선례.
- [[project_hexa_lang_english_only]] — 구현 후 diagnostic 은 영어 단일.

---

> Provenance: PROBE r16 · authored 2026-05-25 by Claude Opus 4.7 (1M context).
> evidence = current main `self/native/hexa_v2` (hexa-cc) 직접 transpile + clang +
> 실행 (`2**3**2`=64, `-2**2`=4 측정). migration-risk = 전체 `.hexa` 코퍼스 grep
> (arithmetic chained `**` 0건, ungrouped unary-base 0건). docs-only — 컴파일러
> 소스 무수정. 구현은 본 명세 §4 acceptance probe 에 대해 별도 surgical PR.
