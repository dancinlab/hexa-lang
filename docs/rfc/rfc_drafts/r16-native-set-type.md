# r16 RFC — 네이티브 `set` / `HashSet` 타입

- **Status**: design-draft (제안 명세 · 별도 surgical PR 들이 본 문서의 권고를 단계적으로 구현)
- **Date**: 2026-05-25
- **Severity**: MEDIUM (기능 결손 · 사용자-노출 자료구조 · literal 문법 결정 필요 → 작은 breaking 표면)
- **Source**: PROBE r16 sweep — "hexa 에 first-class set 타입 부재 — map-key idiom / 손수짠 bucket / bitset 3종으로 에뮬레이트 중"
- **Lane**: docs-only. 본 문서는 **설계 제안**이며 컴파일러 소스(`lexer.hexa` / `parser.hexa` / `codegen.hexa` / `runtime*.c`)는 **건드리지 않는다.** 본 사이클의 다른 agent 들이 인접 파일을 편집하므로 충돌 회피를 위해 docs-lane 으로 한정한다.

---

## 1. 배경 — 현 에뮬레이션 현황 + evidence

hexa 에는 **first-class set 타입이 없다.** 집합 의미론(중복 없는 멤버십 컨테이너 + union/intersect/difference/subset)은 세 가지 서로 다른 idiom 으로 손수 재현되고 있으며, 각각 별개의 footgun 을 가진다.

### 1.1 패턴 A — map-key idiom (element→unit)

가장 흔하다. 이미 `stdlib/hashset.hexa` 가 이를 canonical 화해 두었다 (`@since 2026-05-24`, `@stability preview`):

```hexa
// stdlib/hashset.hexa — map<T, bool> backing, value 는 항상 true
pub struct HashSet { items: any }
pub fn hashset_insert(s: HashSet, item) -> bool {
    let k = to_string(item)        // ← 모든 element 를 string 으로 정규화
    let m = s.items
    if has_key(m, k) { return false }
    m[k] = true
    return true
}
pub fn hashset_contains(s: HashSet, item) -> bool {
    return has_key(s.items, to_string(item))
}
pub fn hashset_len(s: HashSet) -> i64 { return len(dict_keys(s.items)) }
```

`evidence`: `stdlib/hashset.hexa:101-142`. capability surface = `new / from_array / insert / contains / remove / len / is_empty / clear / to_array` (9종). **`union` / `intersect` / `difference` / `is_subset` / `symmetric_difference` 는 없다.**

**아픈 점**:
- `to_string(item)` 정규화 때문에 `1` 과 `"1"` 이 **충돌**한다 (모듈 주석 L57-59 가 명시적으로 "Tradeoff: `1` and `"1"` collide" 라고 인정). 정수 set 과 문자열 set 을 섞으면 silent collision.
- 멤버십 ops (union 등)이 전혀 없어 호출자가 매번 직접 루프.
- struct-field generics 부재로 `items: any` — 타입 안전성 0.

### 1.2 패턴 B — 손수짠 64-bucket hashset

`self/module_loader.hexa:722-778` 의 `ml_hset_*`. 컴파일러 부트스트랩이 map 빌트인에 의존하지 못하던 시절의 잔재:

```hexa
fn ml_hset_new()  { /* 64개 빈 bucket 배열 */ }
fn ml_hset_hash(key) { /* h = (h*31 + ord(c)) % 64, string-only */ }
fn ml_hset_has(buckets, key) { /* bucket 선형탐색 */ }
fn ml_hset_add(buckets, key) { /* 전체 buckets 배열을 복제해 반환 (immutable) */ }
```

**아픈 점**:
- `ml_hset_add` 가 매 삽입마다 **64-bucket 배열 전체를 복제** → O(n) per add, GC 압력. self/flatten_imports 에도 동일한 `fl_hset` 복붙(주석이 인정).
- string-only (`ord(c)` 기반 해시). element 타입 일반화 불가.
- self 디렉토리에 중복 구현이 산재 — 단일 SSOT 부재.

### 1.3 패턴 C — bitset (정수 도메인 전용)

`self/test_bitset_pure.hexa` + `self/runtime/bitset_pure.hexa`. 32-bit word 배열에 비트 packing:

```hexa
let BS_WORD_BITS = 32
fn bs_or(a, b) { return (a + b) - (a & b) }   // word-level union
pub fn bitset_new_pure(nbits) { /* nbits/32 word 배열 */ }
```

**아픈 점**:
- 정수 인덱스 0..nbits 도메인에만 적용 — 임의 element 불가.
- `bs_shl` / `bs_shr` 가 곱셈/나눗셈 루프로 에뮬레이트(`r = r * 2`) — 진짜 비트시프트 미사용. 작긴 하나 비효율.
- union/intersect 가 word-level 비트연산이라 도메인 정렬(같은 nbits)이 강제됨.

### 1.4 패턴 D — array-based 집합 연산 (멤버십 ops 만)

`self/test_set_ext_pure.hexa` + `self/runtime/set_ext_pure.hexa` 가 ops 일부를 배열 위에 제공:

```hexa
fn set_symdiff_pure(a, b)   { /* 대칭차집합 → 배열 */ }
fn set_subset_pure(a, b)    { /* a ⊆ b */ }
fn set_equal_pure(a, b)     { /* 순서무관 동치 */ }
fn set_cartesian_pure(a, b) { /* 데카르트 곱 */ }
fn set_powerset_pure(s)     { /* 멱집합, n>16 guard */ }
```

**아픈 점**: 백킹이 **plain 배열**이라 `sx_has` 가 O(n) 선형탐색 → 모든 ops 가 O(n·m). union/intersect/difference 의 기본 3종은 **여기에도 없다** (symdiff/subset/equal/cartesian/powerset 만). hashset(패턴 A)와 별개 surface 라 두 idiom 이 분기.

### 1.5 `.unique()` adapter — 인접하지만 set 아님

`codegen.hexa:3983` 의 `.unique()` 는 `hexa_array_unique(obj)` 로 lower 되어 **dedup 된 배열을 반환**한다 (set 아님). `.collect()`(L3971)도 배열 collect. 즉 "중복 제거" 는 되지만 결과는 멤버십 컨테이너가 아니라 순서있는 배열 — `contains` 가 다시 O(n).

### 1.6 ★ 핵심 제약: map 은 근본적으로 string-keyed (#815)

PROBE r16 에서 막 랜딩한 `#815` (`8d22718c` / `027415ea`)가 이 RFC 의 구현 선택을 직접 규정한다:

> Maps are fundamentally **string-to-value** (interned c-string keys via `hexa_to_cstring`). The canonical-minimal fix ... is to **STRINGIFY non-string keys consistently on all paths**, so `m[5]`, `m["5"]`, and an int-key literal all address the same entry.

검증 인용 (commit body): `m[5]=100 -> 100`, `m["5"] -> 100` (int/str key **agree** = 같은 엔트리). 즉 **map-backed set 은 본질적으로 "stringified-element" set** 이다. `{1}` 과 `{"1"}` 가 합쳐진다. 이것은 패턴 A 의 `to_string` collision 과 정확히 동일한 근원 — runtime map 의 string-key 본성. **이 RFC 의 P1 은 이 제약을 수용**하고, P2 에서 element-type 태깅으로 분리하는 경로를 제안한다.

---

## 2. Canonical 비교 — 타 언어의 set

| 언어 | literal 문법 | add / remove / contains / len | union | intersect | difference | subset | 순서 |
|---|---|---|---|---|---|---|---|
| **Rust `HashSet<T>`** | 없음 — `HashSet::from([1,2,3])` | `insert` / `remove` / `contains` / `len` | `a \| &b` / `.union()` | `a & &b` / `.intersection()` | `a - &b` / `.difference()` | `.is_subset()` | unordered (hash) |
| **Rust `BTreeSet<T>`** | 없음 — `BTreeSet::from([..])` | 동일 | 동일 ops | 동일 | 동일 | `.is_subset()` | **sorted** |
| **Python `set`** | `{1, 2, 3}` (단, `{}` = dict!) · `set([..])` | `add` / `remove`·`discard` / `in` / `len()` | `a \| b` / `.union()` | `a & b` / `.intersection()` | `a - b` / `.difference()` | `a <= b` / `.issubset()` | unordered (hash) |
| **Python `frozenset`** | `frozenset([..])` (literal 없음) | immutable — contains/len 만 | `\|` | `&` | `-` | `<=` | unordered |
| **Swift `Set<T>`** | `[1, 2, 3]` (타입 어노테이션으로 array 와 구분) | `insert` / `remove` / `contains` / `count` | `.union(_:)` | `.intersection(_:)` | `.subtracting(_:)` | `.isSubset(of:)` | unordered (hash) |

핵심 관찰:
1. **literal 충돌은 보편적 문제**다. Python 의 `{}` 는 dict(set 아님), 빈 set 은 `set()` 으로만 만든다. Swift 는 `[1,2,3]` 가 array 와 동일 문법이라 **타입 컨텍스트로만** set 이 됨. → hexa 도 동일한 모호성을 피할 문법이 필요.
2. ops 는 **operator(`| & -`) + method 둘 다** 제공이 표준 (Rust/Python). Swift 는 method-only.
3. ordering 은 **hash(기본)** vs **sorted(BTreeSet)** 2-tier 가 표준. hexa map 은 현재 insertion-order(`stdlib/hashset.hexa:152` "insertion order for the current map implementation") → 첫 단계는 insertion-order set 으로 충분.

---

## 3. 제안

### 3.1 (a) Literal 문법 — `#{1, 2, 3}` 권장

hexa 의 제약 지형:
- `{ ... }` 는 **블록** (Python 의 `{}`=dict 와 달리 set/map 리터럴 아님).
- `#{ k: v }` 는 **이미 map 리터럴**이다 (`self/parser.hexa` 가 AstNode 를 `#{...}` map 으로 표현 — L55, L63-135 등 수십 곳).
- `[ ... ]` 는 array.

후보 비교:

| 후보 | 예시 | 장점 | 단점 |
|---|---|---|---|
| **A. `#{1, 2, 3}` (권장)** | `#{1, 2, 3}`, 빈 set `#{}`?  | map literal `#{k: v}` 의 **자매** — `:` 부재로 구분. lexer 의 `#{` 토큰 재사용. 시각적으로 "map 의 친척" 명확 | 빈 `#{}` 가 빈-map 과 모호 → 빈 set 은 `set()` 또는 `#{,}`/타입-어노테이션 필요. parser 가 첫 element 의 `:` 유무로 map/set 분기 |
| B. `set([1, 2, 3])` | `set([1,2,3])` | 모호성 0. 문법 추가 불필요(빌트인 fn) | literal 아님(verbose). Rust `HashSet::from` 스타일 |
| C. `#[1, 2, 3]` | `#[1,2,3]` | array `[..]` 의 자매로 직관적. 빈 set `#[]` 명확 | 새 lexer 토큰 `#[` 필요. map(`#{`)/set(`#[`) 접두 비대칭 |

**권장 = A (`#{1, 2, 3}`) + B(`set([..])`) 병행.** 근거:
- `#{` 토큰이 **이미 lexer/parser 에 존재**(map literal). set 은 parser 가 첫 항목 뒤 `:` 유무로 분기 — `#{a: b}` → map, `#{a, b}` 또는 `#{a}` → set. lexer 변경 0, parser 분기 1곳.
- 빈 컨테이너 모호성(`#{}` = 빈 map vs 빈 set)은 **`#{}` 를 빈 map 으로 유지**(기존 동작 보존, breaking 회피)하고 **빈 set 은 `set()` 빌트인**으로 만든다. 이래서 B 를 병행 권장 — `set()` / `set([..])` 가 빈-set 생성과 array→set 변환을 동시에 커버.
- 단일-element `#{x}` 는 set 으로 해석(map 은 최소 `#{k: v}` 형태라 `:` 필수).

> **이것이 본 RFC 의 핵심 open question** — §6 참조. 사용자 pick 필요.

### 3.2 (b) Ops surface — method 우선, operator 는 P3

P1/P2 는 **method 중심**(현 `stdlib/hashset.hexa` 표면을 확장):

```hexa
let a = #{1, 2, 3}
let b = #{3, 4, 5}
a.add(6)              // mutate, returns bool (newly-added?) — hashset_insert 시그니처 유지
a.remove(2)           // returns bool (was-present?)
a.contains(3)         // -> bool
a.len()               // -> i64
a.union(b)            // -> set {1,2,3,4,5,6}
a.intersect(b)        // -> set {3}
a.difference(b)       // -> set {1,2}
a.symmetric_difference(b)  // -> set {1,2,4,5,6}  (set_ext_pure 흡수)
a.is_subset(b)        // -> bool
a.is_superset(b)      // -> bool
a.to_array()          // -> array (dict_keys 순)
```

P3 에서 operator sugar (Rust/Python 표준):

```hexa
a | b    // union
a & b    // intersect
a - b    // difference
a ^ b    // symmetric_difference  (Python 표준)
a <= b   // is_subset
```

operator 는 codegen 의 BinOp 디스패치에서 피연산자 타입이 set 일 때 method 로 lower — P1/P2 의 method 가 SSOT 이므로 sugar 일 뿐.

### 3.3 (c) 구현 — 3단계 phasing

| 단계 | 내용 | 백킹 | element 타입 | 비용 |
|---|---|---|---|---|
| **P1 (string-set on map machinery)** | 현 `stdlib/hashset.hexa` 를 SSOT 로 승격 + `union/intersect/difference/symmetric_difference/is_subset/is_superset` 6 ops 추가 (set_ext_pure 흡수). `ml_hset_*` / 패턴 D 를 이 surface 로 점진 대체 | `HexaMapTable` (element→`true`), `to_string` 정규화 | **stringified** — `1`/`"1"` 충돌 수용 (#815 본성과 일치) | 가장 쌈. 신규 runtime 타입 0. stdlib 함수 추가만 |
| **P2 (generic element + literal 문법)** | `#{1,2,3}` literal parse → `set()` 생성자로 desugar. set wrapper 에 **element-tag** 필드 추가(`int`/`str`/`mixed`) — key 에 타입 접두("i:1" vs "s:1")를 붙여 `1`/`"1"` 분리 | map + typed-key prefix | **분리됨** (typed prefix) | 중간. parser 분기 + stdlib key 정규화 변경 |
| **P3 (operators + ordered set)** | `\| & - ^ <=` operator sugar (codegen BinOp). `BTreeSet` 대응 = `sorted_set()` (dict_keys 를 sort 후 노출) | 동일 | 동일 | codegen BinOp 디스패치 + sort wrapper |

**핵심 트레이드오프 (구현 선택)**:

| 선택지 | 장점 | 단점 |
|---|---|---|
| **map 재사용 (P1 권장)** | runtime 타입 추가 0, `has_key`/`map_remove`/`dict_keys` 이미 검증됨. #815 이후 int-key 도 동작(단 string 충돌). 즉시 ship 가능 | string-element 한계(P2 까지). O(1) 이나 c-string intern 오버헤드 |
| **전용 set runtime 타입** | 진짜 typed element, 해시 충돌 제어, 메모리 컴팩트 | 신규 `HexaSet` runtime struct + GC 통합 + codegen 분기 = 큰 표면. P1 의 "즉시 ship" 상실 |

권장 = **P1 에서 map 재사용**(`stdlib/hashset.hexa` 승격), P2 에서 typed-key prefix 로 element 분리, 전용 runtime 타입은 P2 의 prefix 가 성능 부족으로 판명될 때만 P4 로 escalate.

### 3.4 (d) `.unique()` / `.collect()` 연동

- `arr.unique()` 는 **현 동작 유지**(dedup 배열 반환) — breaking 없음.
- 신규 `arr.to_set()` adapter 추가: array → set (`hashset_from_array` 위에 lower). `arr.collect()` 의 set 변종.
- 역방향 `set.to_array()` 는 이미 `stdlib/hashset.hexa:155` 존재 — P1 에서 그대로.
- 즉 파이프라인: `arr.filter(...).to_set().union(other).to_array()` 가 자연스럽게 흐른다.

---

## 4. Falsifiable acceptance probes

각 단계가 만족해야 할 검증 (self-hosted transpile → clang → 실행; `stdlib/hashset.hexa` 확장본 + 신규 test 러너):

**P1 (string-set + 6 ops)** — `set()` 생성자 + method:
```
F-P1-LITERAL    set([1,2,3]).len()                 == 3
F-P1-ADD        s=set([1,2]); s.add(2); s.len()    == 2        // dedup
F-P1-CONTAINS   set([1,2,3]).contains(2)           == true
                set([1,2,3]).contains(9)           == false
F-P1-REMOVE     s=set([1,2]); s.remove(1); s.len() == 1
F-P1-UNION      set([1,2]).union(set([2,3])).len() == 3        // {1,2,3}
F-P1-INTERSECT  set([1,2,3]).intersect(set([2,3,4])).to_array() ~= [2,3]   // 순서무관
F-P1-DIFF       set([1,2,3]).difference(set([2,3])).to_array() ~= [1]
F-P1-SYMDIFF    set([1,2,3]).symmetric_difference(set([2,3,4])).len() == 2 // {1,4}
F-P1-SUBSET     set([1,2]).is_subset(set([1,2,3]))  == true
                set([1,4]).is_subset(set([1,2,3]))  == false
F-P1-COLLISION  set([1]).contains("1")              == true   // ★ stringified — 의도된 P1 한계 (회귀 아님)
```

**P2 (literal 문법 + element 분리)**:
```
F-P2-HASHLIT    #{1, 2, 3}.len()                    == 3
F-P2-SINGLE     #{42}.contains(42)                  == true
F-P2-MAP-STILL  (#{"k": 1})["k"]                    == 1       // map literal 회귀 없음
F-P2-EMPTYMAP   len(dict_keys(#{}))                 == 0       // #{} 는 여전히 빈 map
F-P2-TYPED      #{1}.contains("1")                  == false   // ★ P1 의 collision 이 P2 에서 해소
```

**P3 (operators)**:
```
F-P3-OR         (#{1,2} | #{2,3}).len()             == 3
F-P3-AND        (#{1,2,3} & #{2,3,4}).len()         == 2
F-P3-SUB        (#{1,2,3} - #{2,3}).to_array()      ~= [1]
F-P3-XOR        (#{1,2,3} ^ #{2,3,4}).len()         == 2
F-P3-LE         (#{1,2} <= #{1,2,3})                == true
```

(`~=` = 순서무관 집합 동치 — `set_equal_pure` 패턴.)

---

## 5. Open questions

1. **★ Literal 문법 (사용자 pick 필요)** — §3.1 의 A(`#{1,2,3}`) / B(`set([..])`) / C(`#[1,2,3]`) 중 무엇을, 빈-set 을 어떻게(`set()` vs `#{}` 재해석 vs `#[]`) 표기할지. 권장은 **A+B 병행** (lexer 무변경, breaking 회피). 단 C(`#[..]`)가 array `[..]` 와의 시각적 대칭에서 더 직관적이라는 반론 가능 → 결정 보류.
2. **`1`/`"1"` 충돌 처리 시점** — P1 에서 수용(문서화된 한계)할지, P2 typed-prefix 를 P1 에 당겨 처음부터 분리할지. typed-prefix 는 모든 key 에 1-2 byte 접두 → 약간의 메모리/속도 비용.
3. **ordering 보장** — insertion-order(현 map) 를 계약으로 명시할지, "unordered" 로 선언해 future hash-rehash 자유를 둘지. `sorted_set()`(P3)은 별개.
4. **mutability 모델** — 현 `hashset_insert` 는 inner map 을 reference mutate(`m[k]=true`). Rust `union` 은 새 set 반환(immutable-ish). P1 ops 가 mutate 인지 새 set 반환인지 — 본 RFC 는 **ops=새 set 반환, add/remove=mutate** 권장(Python 의 `|` vs `|=` 구분과 동형).
5. **frozenset 대응** — immutable set 이 필요한가 (map-key 로 set 을 쓰는 use-case). P3 이후 별도 검토.

---

## 6. Provenance

- emulation 측정: `stdlib/hashset.hexa:74-157` (패턴 A) · `self/module_loader.hexa:722-778` (패턴 B `ml_hset_*`) · `self/test_bitset_pure.hexa` + `self/runtime/bitset_pure.hexa` (패턴 C) · `self/test_set_ext_pure.hexa` + `self/runtime/set_ext_pure.hexa` (패턴 D, symdiff/subset/equal/cartesian/powerset).
- `.unique()` lowering: `self/codegen.hexa:3983` → `hexa_array_unique`. `.collect()`: `codegen.hexa:3971`.
- map literal `#{k: v}`: `self/parser.hexa:55, 63-135`. map string-key 본성: `#815` (`8d22718c` / `027415ea`, "Maps are fundamentally string-to-value (interned c-string keys via hexa_to_cstring)" + `m[5]`/`m["5"]` agree 검증).
- canonical 비교: Rust `HashSet`/`BTreeSet` std docs · Python `set`/`frozenset` data model · Swift `Set`.
- RFC 형식: `docs/rfc/rfc_drafts/r15-d9-string-len-unicode-policy.md` (자매 docs-lane RFC).
- PROBE r16 cycle. Lane = docs-only (컴파일러 소스 무수정).
