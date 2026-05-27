# r15-D19 RFC — for-loop 바인딩 / 루프변수 스코핑 정책 (`for i in 0..3` 의 `i` 수명)

- **Status**: design-draft (정책 명세 · 별도 surgical PR 가 본 문서의 권고를 구현)
- **Date**: 2026-05-24
- **Severity**: HIGH (정확성 버그 — 측정상 루프 본문이 루프변수가 아니라 stale 상수를 인쇄 · §1.1)
- **Source**: PROBE r15 cycle-1 sweep — "D19 for-loop binding semantics — `let i=100; for i in 0..3 {…}` 외부 i 유지" (루프변수 `i` 가 외부 `i` 를 rebind/leak 하는가, 아니면 fresh 루프-스코프 바인딩이고 루프 후 외부 `i` 가 보존되는가?)
- **선행 surface**: D17 `{}` block-scope (#724) + D18 type-changing shadow let-rebind (#766) — 둘 다 같은 `_gen2_collect_lets` flat-hoist + comptime-const fold table 머신을 건드린다. 본 항목은 그 짝(loop-var 바인딩 path).
- **Lane**: docs-only. 본 문서는 정책 명세이며 컴파일러 소스(`codegen.hexa` / `parser.hexa` / `runtime*.c`)는 **건드리지 않음**. (in-flight codegen PR 와의 충돌 회피 — 권고 구현은 별도 surgical PR.)

---

## 1. 배경 — 현 동작 + 측정 evidence

질문은 두 갈래다:

1. **스코프 구조** — `for i in 0..3` 의 `i` 는 fresh 루프-스코프 바인딩인가(Rust/Go/Swift), 아니면 enclosing `i` 를 rebind 하고 leak 하는가(Python)?
2. **값 정확성** — 외부 동명(同名) 바인딩(`let i = 100`)이 있을 때, 루프 본문 안에서 `i` 가 루프 카운터(0,1,2)로 보이는가?

측정 결과 hexa 의 **C-레벨 스코프 구조는 이미 Rust/Go 식(fresh, no-leak)** 으로 emit 되지만, **comptime-const fold 패스가 그 shadow 를 무시해서 루프 본문이 stale 상수를 인쇄하는 정확성 버그**가 있다. 둘은 별개의 layer 이며 evidence 가 분리해 보여준다.

### 1.1 측정 evidence (probe 직접 실행)

현 main(`origin/main` `bf59cae7`)의 self-hosted transpiler(`self/native/hexa_v2`)를 `hexa` 가 아닌 이름(`/tmp/v2tool-d19`)으로 복사 → 직접 transpile → `clang -O0 -w -I self … self/runtime.c` 컴파일 → 실행.

| # | probe (hexa source) | 생성 C 핵심 | 실행 출력 | 판정 |
|---|---|---|---|---|
| P1 | `let i = 100; for i in 0..3 { println(to_string(i)) }; println("after "+to_string(i))` | 본문 `hexa_to_string(hexa_int(100))` · post `hexa_int(100)` | `100 / 100 / 100 / after 100` | ❌ 본문 = stale 100 (기대 0/1/2). post = 100 (정답) |
| P2 | (외부 바인딩 없음) `for j in 0..3 { println(to_string(j)) }; println("leak "+to_string(j))` | post 가 `hexa_to_string(j)` 인데 `j` 가 블록 밖에서 **미선언** | **컴파일 FAIL**: `use of undeclared identifier 'j'` | ✅ no-leak (루프-스코프 · Rust/Go식) |
| P3 | `for i in 0..2 { for i in 10..12 { println("inner "+to_string(i)) }; println("outer "+to_string(i)) }` | 중첩 `{ … HexaVal i = …; { … HexaVal i = …; } … }` (C-블록 shadow) | `inner 10 / inner 11 / outer 0 / inner 10 / inner 11 / outer 1` | ✅ 중첩 동명 정확 (inner 가 outer shadow, 복원됨) |
| P4 | `let mut i = 100; let mut sum = 0; for i in 0..3 { sum = sum+i; println(to_string(i)) }; println("sum "+to_string(sum)); println("after "+to_string(i))` | 본문 `HexaVal i = hexa_int(__hx_ni_i)` 실제 read · post `i` = 외부 슬롯 | `0 / 1 / 2 / sum 3 / after 100` | ✅ `let mut` 외부 → fold 안 됨 → 본문 정확 + 외부 100 보존 |

핵심 해석:

- **스코프 구조 자체는 올바르다.** P2 가 결정적: 외부 동명 바인딩이 없으면 루프변수 `j` 는 루프 후 **미선언**(컴파일 FAIL) — 즉 Python 식 leak 이 **아니다**. P3 은 중첩 동명에서 inner 가 outer 를 C-블록으로 shadow 하고 루프 후 복원됨을 보인다("outer 0/1"). P4 는 외부 `let mut i = 100` 이 루프 후 `after 100` 으로 정확히 보존됨을 보인다.
- **그러나 P1 은 정확성 버그다.** 외부가 `let i = 100`(immutable)일 때, 루프 본문의 `i` 가 루프 카운터(0,1,2)가 아니라 **stale 상수 100** 으로 인쇄된다. P4(`let mut`)에서는 안 나타난다 → 원인은 **immutable `let` 에만 적용되는 comptime-const fold**.

### 1.2 root cause (codegen 정밀 위치)

생성 C(P1)가 root cause 를 드러낸다:

```c
HexaVal i = hexa_int(100);                  // 외부 let i = 100 (function-flat hoist)
{
    int64_t __hx_ne_i = HX_INT(hexa_int(3));
    for (int64_t __hx_ni_i = HX_INT(hexa_int(0)); __hx_ni_i < __hx_ne_i; __hx_ni_i++) {
        HexaVal i = hexa_int(__hx_ni_i);    // ← fresh 루프-스코프 i (C-블록 shadow) — 구조는 정확
        hexa_println(hexa_to_string(hexa_int(100)));   // ← BUG: i 가 stale 100 으로 fold (기대 __hx_ni_i)
    }
}
hexa_println(hexa_add(__hexa_sl_0, hexa_to_string(hexa_int(100))));  // post: 100 (정답)
```

- `let i = 100` 은 `codegen.hexa:2817-2834` 의 "PROBE r11 B3" 경로에서 `comptime_eval` → `_register_comptime_const("i", 100)` 으로 fold table 에 등록된다. 이후 `i` 의 모든 Ident read(`codegen.hexa:4726` `_lookup_comptime_const`)는 live 변수 read 대신 **literal `hexa_int(100)`** 으로 inline 된다.
- for-loop emit(`codegen.hexa:3161-3208`)은 fresh C-블록 + `HexaVal i = hexa_int(__hx_ni_i)`(L3195) 을 올바르게 만들고 `_known_int_add(node.name)`(L3199)도 부른다. **그러나 `_invalidate_comptime_const(node.name)` 을 호출하지 않고, comptime-const scope mark/restore 로 본문을 감싸지도 않는다.** 따라서 stale `i → 100` fold 가 루프 본문 안에서도 살아남아 카운터를 가린다.
- D18(`codegen.hexa:2802-2813`)은 정확히 같은 위험을 re-`let` shadow 에 대해 `_invalidate_comptime_const(node.name)` 으로 막았다. for-loop 바인딩은 또 다른 shadow path 인데 그 invalidation 이 누락됐다.
- D17 block-scope 가 쓰는 `_comptime_const_scope_mark()`/`_comptime_const_scope_restore()`(`codegen.hexa:8579-8596`, match arm/`{}` body 격리용 — `codegen.hexa:2630/2650`)도 for-loop 본문에는 적용돼 있지 않다.

> 요약: **스코프 구조(layer 1)는 Rust/Go식 fresh-no-leak 으로 이미 맞다. 깨진 건 comptime-const fold(layer 2)가 그 shadow 를 인지 못 하는 것이다.** 정책 결정(어느 스코핑 모델?)과 별개로, 어느 정책을 택하든 P1 의 fold-stale 는 버그다.

---

## 2. Canonical 비교 — 타 언어의 for-loop 변수 스코핑

| 언어 | 루프변수 스코프 | 루프 후 leak | 외부 동명 바인딩 처리 | 반복마다 fresh(클로저 캡처) | 비고 |
|---|---|---|---|---|---|
| **Rust** | 루프-스코프(fresh) | ❌ no-leak | 외부 `i` 를 **shadow**, 루프 후 복원 | 반복마다 fresh binding | `for i in 0..3` 는 새 `i` 도입 |
| **Go** | 루프-스코프(`:=` 식) | ❌ no-leak | 외부 `i` shadow | **1.22+ 부터 반복마다 fresh** (이전엔 공유 → 유명한 클로저 함정) | 1.22 에서 의도적 breaking |
| **Swift** | 루프-스코프(`for i in`) | ❌ no-leak | 외부 `i` shadow | 반복마다 fresh(`let` 상수) | 루프변수는 암묵 `let` |
| **C** (`for(int i…)`) | 루프-스코프(C99 블록) | ❌ no-leak | 외부 `i` shadow(C 블록 규칙) | (클로저 없음 — N/A) | hexa 의 emit 타깃과 동일 모델 |
| **Python** | enclosing-스코프 rebind | ✅ **leak** (`i == 2` 잔존) | 외부 `i` 를 **rebind/덮어씀** | ❌ 단일 변수 공유(late-binding 함정) | 유일한 leak 진영 |
| **JavaScript** | `let`=블록·`var`=함수 | `let` ❌ / `var` ✅ | `let` shadow / `var` rebind | `let` 반복마다 fresh / `var` 공유 | 키워드 의존 |

요약:

- **루프-스코프 + no-leak**: Rust · Go · Swift · C · JS(`let`) — **압도적 다수**. "for 가 새 변수를 만든다, 루프 끝나면 사라진다."
- **enclosing rebind + leak**: Python · JS(`var`) — 소수. 입문자엔 직관적이나(`for` 뒤 마지막 값 참조 가능) 함정 다발(클로저 late-binding, 우발적 외부변수 파괴).
- **per-iteration freshness**: 클로저가 루프변수를 캡처할 때 각 반복이 독립 binding 을 잡느냐. Go 1.22 가 이걸 위해 의도적 breaking 을 감행한 만큼 중요한 축이다. hexa 는 P3 의 C-블록 emit(`HexaVal i = …` 가 본문 안에서 매 반복 새로 선언)상 **이미 per-iteration fresh** 에 가깝다(클로저 캡처가 그 시점 값을 box 한다는 전제 — §3(c) 참고).

hexa 는 **no-LLVM native + C-emit** 정체성상 C/Rust/Go 모델에 자연 정합한다(emit 이 C 블록 그 자체). Python-leak 은 C-emit 모델과도, D17/D18 의 shadow-우선 방향과도 어긋난다.

---

## 3. 제안 — 정책 + 권고

### 3.1 정책 선언 (canonical semantics)

**for-loop 변수는 루프-스코프 fresh 바인딩이다.**

- **(a) 외부 동명 바인딩과의 상호작용 — shadow (rebind 아님).** `let i = 100; for i in 0..3 {…}` 에서 루프의 `i` 는 외부 `i` 를 **shadow** 하는 새 바인딩이다. 루프 본문 안에서 `i` 는 루프 카운터(0,1,2)다. (D17/D18 의 shadow-우선 정책과 일관.)
- **(b) 루프 후 외부 값 복원.** 루프 종료 후 외부 `i` 는 **루프 진입 전 값으로 복원**된다(`100`). 루프변수가 외부를 파괴하지 않는다(Python-leak 거부). 외부 바인딩이 없었다면 루프변수는 루프 후 미선언(참조 시 컴파일 에러).
- **(c) per-iteration freshness.** 루프변수는 매 반복 fresh 바인딩이다. 본문 안에서 루프변수에 대입(`i = …`)하면 그 반복에 한해 alias 를 rebind 하며(`codegen.hexa:3168-3171` 주석의 기존 계약), 다음 반복의 카운터 materialize 에는 영향 없다. 클로저가 루프변수를 캡처하면 캡처 시점 값을 잡는다(box-by-value).

이는 P2/P3/P4 가 이미 보이는 **C-레벨 구조와 일치**한다. 정책 선언은 그 구조를 SSOT 로 못 박고, §1.1 P1 의 fold-stale 를 그 정책에 대한 **버그**로 규정한다.

### 3.2 옵션 trade-off

| 옵션 | 스코핑 모델 | 장점 | 단점 | breaking? |
|---|---|---|---|---|
| **A** | **루프-스코프 fresh + shadow + no-leak** (Rust/Go/Swift/C — **권고**) | canonical 다수 · C-emit 모델과 자연 정합 · D17/D18 shadow 정책과 일관 · 우발적 외부변수 파괴 없음 | "루프 후 마지막 값" 을 외부에서 읽으려면 명시적 `let mut last`; 입문자엔 약간 덜 직관적 | 구조는 **NO**(이미 emit 됨) · fold-stale fix 는 **버그 수정**(거동 교정, breaking 아님) |
| **B** | **Python-leak** (enclosing rebind + leak) | 루프 후 마지막 값 즉시 참조 가능 · 단순 멘탈모델 | 외부 동명변수 silent 파괴 · 클로저 late-binding 함정 · C-emit 모델/D17/D18 와 충돌 · 소수 진영 | **YES** (P2/P3/P4 거동 전부 변경 + flat-hoist 대수술) |
| **C** | **status-quo** (구조는 A, fold-stale 버그 잔존) | 구현 변경 0 | **P1 류 silent 오답** — immutable 외부 동명변수 + 루프 시 루프 본문이 stale 상수 인쇄. 데이터-손상급 footgun | — (버그 유지) |

추가 고려 — 왜 A 인가:

1. **C-emit 정합**: hexa 는 루프를 C `for(…){ … }` 블록으로 내린다. C 블록 스코프 = 옵션 A. B 를 하려면 emit 을 일부러 비틀어야 하고(함수-flat 슬롯으로 카운터 승격) D17/D18 이 막 정리한 flat-hoist 를 역행한다.
2. **shadow 정책 일관**: D17(`{}` block-scope)·D18(type-changing shadow)이 "안쪽 바인딩이 바깥을 shadow, 블록 후 복원" 을 이미 정책으로 land 했다. for-loop 변수는 그 규칙의 한 사례여야 한다(특례 아님).
3. **footgun 의 위치**: P1 의 진짜 위험은 스코핑 모델이 아니라 fold-stale(layer 2)다. A 를 택하고 fold invalidation 만 고치면 footgun 0. B/C 는 footgun 을 못 없애거나 키운다.

### 3.3 권고 — **옵션 A** + comptime-const fold 를 loop-var shadow 에 invalidate/scope

권고 delta(구현 PR 이 할 일):

1. **스코핑 모델 = 루프-스코프 fresh + shadow + no-leak (옵션 A) 를 정책 SSOT 로 선언.** 구조 emit 은 이미 맞으므로 변경 없음.
2. **fold-stale 버그 fix**: for-loop emit(`codegen.hexa:3161-3208`, 그리고 `ForInStmt`/`ForDestructStmt` 도 동일)에서 루프변수 바인딩 직전에
   - **`_invalidate_comptime_const(node.name)`** 호출 — enclosing `let i = 100` 의 stale fold 를 죽임(D18 가 re-`let` 에 한 것과 동일).
   - **`_comptime_const_scope_mark()` … 본문 emit … `_comptime_const_scope_restore(mark)`** 로 본문을 감쌈 — 루프 안에서 생긴 fold 가 새지 않고, 루프 후 enclosing 상태가 복원됨(D17 block-scope 와 동일 패턴). ※주의: `scope_restore` 는 *마크 이후* 추가분만 truncate 하므로, enclosing 의 `i → 100` 자체는 `invalidate` 로 별도 제거해야 한다(restore 만으론 부족). 둘 다 필요.
3. **`ForDestructStmt`(tuple destructuring, `codegen.hexa:3231`)** 의 각 destructure name 에도 동일 invalidate/scope 적용.
4. (정책 문서화) leak 거부 + 외부 복원 + per-iteration fresh 를 SPEC 의 scoping 절 또는 본 RFC 를 cite 하는 곳에 명문화.

### 3.4 before / after C-codegen 스케치

`let i = 100; for i in 0..3 { println(to_string(i)) }; println(to_string(i))`

**before (현 main — P1, ❌):**

```c
HexaVal i = hexa_int(100);
{
    int64_t __hx_ne_i = HX_INT(hexa_int(3));
    for (int64_t __hx_ni_i = HX_INT(hexa_int(0)); __hx_ni_i < __hx_ne_i; __hx_ni_i++) {
        HexaVal i = hexa_int(__hx_ni_i);
        hexa_println(hexa_to_string(hexa_int(100)));   // BUG: fold-stale 100
    }
}
hexa_println(hexa_to_string(hexa_int(100)));            // 100 (정답)
```

**after (권고 fix — fold invalidate + scope mark/restore):**

```c
HexaVal i = hexa_int(100);
{
    int64_t __hx_ne_i = HX_INT(hexa_int(3));
    for (int64_t __hx_ni_i = HX_INT(hexa_int(0)); __hx_ni_i < __hx_ne_i; __hx_ni_i++) {
        HexaVal i = hexa_int(__hx_ni_i);               // shadow (변경 없음)
        hexa_println(hexa_to_string(i));               // FIX: live read → 0/1/2
    }
}
hexa_println(hexa_to_string(hexa_int(100)));           // post: 외부 fold 복원 → 100
```

C 구조(블록·shadow)는 그대로. 바뀌는 건 본문 안 Ident `i` 가 `hexa_int(100)` literal 이 아니라 live `i`(=`hexa_int(__hx_ni_i)`)로 emit 되는 것뿐이다. post-loop 의 `i` 는 scope_restore 로 외부 fold 가 복원돼 여전히 `100`.

---

## 4. acceptance probe set (falsifiable)

구현 PR 은 아래를 정확히 재현해야 한다. (self-host transpile → `clang -O0 -w -I self … self/runtime.c` 실행. 재현 명령 §4 끝.)

| # | probe | 기대 출력 (옵션 A) | 현 main | falsifier |
|---|---|---|---|---|
| A1 | `let i=100; for i in 0..3 { println(to_string(i)) }; println("after "+to_string(i))` | `0` `1` `2` `after 100` | `100`×3 `after 100` ❌ | **F-FOLD**: 본문 = 0/1/2 (현재 stale 100 → FAIL = fix 미완 증명) · post = 100 |
| A2 | (외부 없음) `for j in 0..3 { println(to_string(j)) }; println(to_string(j))` | **컴파일 에러**(`j` undeclared) — no-leak | 컴파일 FAIL ✅ | **F-NOLEAK**: 루프 후 `j` 참조가 미선언 에러여야 함(leak 금지) |
| A3 | `for i in 0..2 { for i in 10..12 { println("inner "+to_string(i)) }; println("outer "+to_string(i)) }` | `inner 10` `inner 11` `outer 0` `inner 10` `inner 11` `outer 1` | ✅ | **F-NEST**: 중첩 동명 — inner=10/11, outer=0/1 (inner 가 outer shadow + 복원) |
| A4 | `let mut i=100; let mut sum=0; for i in 0..3 { sum=sum+i; println(to_string(i)) }; println("sum "+to_string(sum)); println("after "+to_string(i))` | `0` `1` `2` `sum 3` `after 100` | ✅ | **F-MUT**: 외부 `let mut` regression guard (현재 정확 — fix 가 깨면 안 됨) |
| A5 | `let i="hi"; for i in 0..2 { println(to_string(i)) }; println(i)` | `0` `1` `hi` | (D18 invalidate 가 일부 처리 가능 — 측정 필요) | **F-TYPESHADOW**: 외부 string + 루프 int shadow → 본문 0/1, post `hi` (타입 변경 shadow 일관) |
| A6 | `let mut acc=[]; for i in 0..3 { acc.push(i) }; println(to_string(acc))` | `[0, 1, 2]` | (F-FOLD 와 동일 root → 측정 시 `[100,100,100]` 의심) | **F-CAPTURE-LITE**: 본문이 루프변수를 자료구조에 축적 시 per-iteration 값 보존 |
| A7 | `for i in 0..=3 { println(to_string(i)) }` | `0` `1` `2` `3` | ✅(inclusive 기존 fix t42) | **F-INCL**: inclusive range regression guard |

재현 명령(참고):

```sh
SIDECAR_NO_POOL_ROUTE=1 cp self/native/hexa_v2 /tmp/v2tool-d19
SIDECAR_NO_POOL_ROUTE=1 /tmp/v2tool-d19 /tmp/probe.hexa /tmp/probe.c
SIDECAR_NO_POOL_ROUTE=1 clang -O0 -w -I self -o /tmp/probe /tmp/probe.c self/runtime.c -lm
/tmp/probe
```

핵심 게이트: **F-FOLD (A1)** — 이것이 빨간색이면 fix 미완. **F-NOLEAK (A2)** · **F-MUT (A4)** · **F-INCL (A7)** 은 현 거동 보존 regression guard.

---

## 5. codegen 매핑 (D17 / D18 연계)

| 항목 | 위치 | 현 상태 | 권고 delta |
|---|---|---|---|
| for-range emit (loop-var 바인딩) | `codegen.hexa:3161-3208` | fresh C-블록 + `HexaVal <name>` shadow ✅ · `_known_int_add` ✅ · **fold invalidate/scope ❌** | 루프변수 바인딩 직전 `_invalidate_comptime_const(node.name)` + 본문을 `_comptime_const_scope_mark()`/`_restore()` 로 wrap |
| for-in emit | `codegen.hexa:3209-3227` (`ForInStmt`) | 동일 구조 · 동일 누락 | 동일 delta |
| for-destruct emit | `codegen.hexa:3231-3257` (`ForDestructStmt`) | destructure name 별 `HexaVal` · 동일 누락 | 각 name 에 invalidate + body scope wrap |
| comptime-const fold 등록 | `codegen.hexa:2817-2834` ("PROBE r11 B3") | immutable `let` 만 fold (P4 `let mut` 가 안 깨지는 이유) | 변경 없음 |
| re-`let` shadow invalidate (**D18**) | `codegen.hexa:2802-2813` | re-`let` 시 `_invalidate_comptime_const` ✅ | **이 패턴을 for-loop path 에 그대로 적용** |
| block-scope mark/restore (**D17**) | `codegen.hexa:2630/2650` · 정의 `8579-8596` | match arm/`{}` body 격리 ✅ | **이 패턴을 for-loop body 에 그대로 적용** |
| `_invalidate_comptime_const` | `codegen.hexa:8552-8565` | name 별 fold 제거 | 재사용(신규 함수 불필요) |
| flat-hoist (`_gen2_collect_lets_stmt`) | `codegen.hexa:2531-2589` | loop-var 를 hoist 풀에 **넣지 않음**(루프변수는 emit 시점 C-local) → no-leak 의 구조적 근거 | 변경 없음 (오히려 A 정책의 근거) |

핵심: 구현 PR 은 **신규 머신을 만들 필요가 없다.** D18 의 invalidate + D17 의 scope mark/restore 라는 기존 2개 패턴을 for-loop(+for-in+for-destruct) 의 루프변수 바인딩 지점에 합성하면 끝난다. ~3 지점 × (1 invalidate 호출 + 1 mark + 1 restore). flat-hoist 는 손대지 않는다(loop-var 는 애초에 hoist 풀 밖이라 no-leak 가 공짜로 보장됨).

ASCII layer 그림:

```
  layer 1: 스코프 구조 (C-블록 emit)          layer 2: comptime-const fold
  ──────────────────────────────────          ─────────────────────────────
  let i=100   → HexaVal i (hoist)              register  i→100   ┐
  for i ...   → { HexaVal i = counter; … }     (loop-var 가      │ stale!
                  ^ fresh shadow ✅              invalidate 안 함) ┘ → 본문에서 100 inline ❌
  } 후         → 외부 i 복원 ✅                  (restore 안 함)   → post 는 우연히 정답(외부=100)

  권고: layer 1 그대로 + layer 2 에 invalidate(루프변수명) + scope mark/restore(본문)
```

---

## 6. 요약 (구현 PR 용 권고 4줄)

1. **정책 = 옵션 A**: for-loop 변수는 **루프-스코프 fresh + 외부 동명 shadow + no-leak + 루프 후 외부 복원 + per-iteration fresh** (Rust/Go/Swift/C 다수 · Python-leak 거부). C-emit 구조가 이미 이렇게 동작(P2/P3/P4 측정 ✅).
2. **버그 fix (HIGH)**: `let i=100; for i in 0..3` 에서 루프 본문이 카운터(0/1/2) 대신 **stale 상수 100** 을 인쇄(P1 측정). 원인 = comptime-const fold(`codegen.hexa:2817-2834`)가 loop-var shadow 를 invalidate 안 함.
3. **fix 방법 = 기존 패턴 합성**: for-loop emit(`codegen.hexa:3161-3208`+`ForInStmt`+`ForDestructStmt`)에서 루프변수 바인딩 직전 **D18 식 `_invalidate_comptime_const(name)`** + 본문을 **D17 식 `_comptime_const_scope_mark()`/`_restore()`** 로 wrap. 신규 머신 불필요.
4. **검증 = §4 7-row** — 게이트 **F-FOLD(A1, 0/1/2/after 100)**; regression guard **F-NOLEAK(A2)·F-MUT(A4)·F-INCL(A7)**.

---

## 7. open questions

- **Q1 (per-iteration & 클로저)**: hexa 가 클로저로 루프변수를 캡처할 때(예: `let fns=[]; for i in 0..3 { fns.push(|| i) }`) 각 클로저가 그 반복의 값을 box 하는가, 마지막 값을 공유하는가? §3(c)는 box-by-value 를 전제했으나 **측정 미수행**(A6 가 자료구조 축적은 커버하나 클로저 캡처는 별도). Go 1.22 breaking 의 핵심 축이므로 구현 PR 에서 클로저-캡처 probe 추가 권고.
- **Q2 (A5 타입변경 shadow)**: 외부 `let i = "hi"` + 루프 `i`(int) 조합에서 D18 의 invalidate 가 이미 일부 작동하는지 측정 필요. fold-stale 가 string 에도 적용되면 `to_string` 타입 mismatch 가능.
- **Q3 (for-in over array)**: `for x in [arr]` 의 element 바인딩(`codegen.hexa:3219` `hexa_iter_get`)도 동일 fold-stale 위험인지 — range 가 아니라 element 라 literal-fold 가능성은 낮지만 동명 외부 + immutable element 패턴에서 확인 필요.
- **Q4 (assignment-to-loop-var)**: 본문 안 `i = 99`(루프변수 재대입) 시 그 반복 alias 만 바뀌고 다음 반복 카운터엔 영향 없음(`codegen.hexa:3168-3171` 계약). 이게 정책으로 의도된 것인지 명문화할지 — Rust 는 `mut` 루프변수 허용, Swift 는 루프변수 immutable. hexa 정책 선택 필요.
- **Q5 (SPEC 등재)**: 본 정책을 SPEC.yaml scoping 절에 등재할지, 아니면 D17/D18 과 묶어 통합 "shadow/scope" 절로 둘지.

---

*Provenance: PROBE r15-D19 — for-loop 바인딩 / 루프변수 스코프 정책 RFC. 측정 evidence = `origin/main bf59cae7` 의 `self/native/hexa_v2` self-host transpile(`/tmp/v2tool-d19`) + `clang -O0 -w -I self … self/runtime.c` 실행, 7 probe(P1 fold-stale 버그 + P2 no-leak + P3 nested + P4 let-mut + acceptance set). root cause = comptime-const fold(`codegen.hexa:2817-2834`)가 loop-var shadow 미invalidate; fix = D18 invalidate(`codegen.hexa:2802-2813`) + D17 scope mark/restore(`codegen.hexa:2630/2650·8579-8596`) 패턴 합성. docs-only lane(컴파일러 소스 무변경 · in-flight codegen PR 충돌 회피). 2026-05-24.*
