실측 완료. 설계 판정을 낸다.

---

# static-types 다음 rung 판정 + impl 스펙

기준 리비전: **origin/main `d750da959`** (HX3024 #4598 착지 커밋). 로컬 체크아웃(`fix/install-bare-cuda-pip`)은 main보다 뒤라서, 아래 모든 file:line은 **origin/main 블롭 기준**으로 실측했다 (프롬프트의 "3592"는 pre-HX3024 스냅샷 좌표 — 현 main에선 **3625**다).

## 1. 실측

### 후보 A — 미주석 로컬의 현 상태 (types.hexa)

- Block-case 레지스트리(`types.hexa:2575~2632`)는 `if len(nm) > 0 && len(tt) > 0` 게이트라 **주석 있는 let만** 기록한다. `let x = 0`(미주석)은 `tt`가 비어 아무것도 기록 안 됨 → `x`는 downstream 전부에서 unknown(kind="") → `_types_equal`의 tolerate-on-unknown 계약(2141)으로 전면 침묵. 이것이 현 커버리지 갭의 실체.
- **결정적 리스크 실측 ①**: 주석-스칼라 let은 **plain name** 키로 기록된다(`2589: benv = _types_env_define(benv, nm, …, declared)`). 즉 미주석 추론 타입도 plain name으로 넣으면 collision-free 우회 없이 곧장 legacy 소비자 전부에 공급된다. 그 소비자들은 **밴드 없는 always-on Error emitter**다 — 실측: `_emit_hx3003`(2057)·`_emit_hx3004`(2067)는 `_types_strict_for` 분기 자체가 없고, binop HX3001(3446·3474)·if-cond HX3001(2687)도 마찬가지. HX3011/3016/3017/3024만 밴드가 있다(1946~2052).
- **결정적 리스크 실측 ② (mut 무효화 문제)**: env는 first-hit-wins라 재대입이 재바인딩되지 않는다 — own-lint 주석이 이걸 명시한다(2645~2650: "encoding move state as an env redefinition would silently read stale"). `let mut x = 0; x = f()` 후 x의 기록 타입은 **stale i64** → 오진 소스. 미주석 추론은 annotated 케이스와 달리 이 무효화 설계 없이는 소리(sound)가 아니다.
- 리스크 규모: corpus census(`static-types-corpus.yml`)는 실소스 ~3.8k 파일이고, 미주석 let은 hexa 코드의 지배적 idiom — 새 KNOWN 타입을 무밴드 Error emitter 4곳+에 일괄 공급하는 순간의 RED 면적은 **무측정·무상한**.

### 후보 B — 3592(→현 3625) `_types_equal` 확인 (types.hexa)

- call-arg 검사 실체 — `_types_check_call`(3546) 내부:
  ```
  3623            let want = callee_t.args[k]
  3624            let got = arg_types[k]
  3625            if !_types_equal(want, got) {
  3633                let ku = "unit"
  3634                if got.kind != ku {
  3635                    _emit_hx3003(name, k + 1, want, got, e.children[1 + k].span, out)
  ```
  **확인**: 비강제 `_types_equal`(def 2139~2158, kind-string 비교) 사용. 리터럴 coercion 부재(`f(0)` → `p: i32` 오탐)·HexaVal 와일드카드 부재(`v: HexaVal` param에 known-type arg 넘기면 오탐) 둘 다 사실.
- `_types_assignable`(def **2215~2253**)은 첫 줄이 `if _types_equal(expected, actual) { return true }`(2216) — **수용집합이 엄격한 상위집합**. 추가 수용: HexaVal/any 와일드카드(2217, `_is_hexaval` 2213) · int-lit→int-kind(2247) · float-lit→float-kind(2250) · ArrayLit 원소 재귀(2237~2245, default 빌드에선 dead — kind:"array"는 opt-in lowering에서만 생산).
- **B는 캠페인 SSOT와 정합**: `state/static-types/wall_a_endgame.md:18`이 이 지점을 "Default-ON substrate … HX3003 call-arg check via `_types_equal`"로 이미 박제했고, r9b coercion을 "flip-BLOCKING false-positive source" 계열로 취급한 전례(§B.3 F0)가 있다.
- **value-flow 사이트 전수 확인**: let(2821·2864)·assign(3023)·return(2783·5033)·if-join(2704)·field-init(3173)·match scrutinee-vs-pattern(3694)·tail-expr(5033) 전부 `_types_assignable` — **call-arg(3625)가 유일하게 남은 bare `_types_equal` value-flow 사이트**다. (binop 3446/3474와 match arm-body join 3705는 value-flow가 아닌 operand/join 검사 — 별개.)

## 2. 선정: **B — HX3003 coercion-faithfulness-fix**

근거:
1. **A는 rung이 아니라 캠페인이다** (판정 요청에 대한 답): 안전한 A = ① collision-free 키(r4/r5 idiom)로 별도 레지스트리 → ② 소비자 rung을 하나씩 (밴드 있는 emitter 또는 corpus-census 선행 후) 배선 → ③ mut-재대입 무효화 설계. 최소 3~n개 rung + census 인프라 확장 + 미해결 설계문제(mut stale) 1개. plain-name 지름길은 무밴드 Error emitter 직결이라 self-compile/fixture RED가 무상한 — 네(오케스트레이터) 지적 그대로 "위험한 대공사"가 맞다.
2. **B는 정확히 1-site·1-diff·strictly-loosening**: 수용집합 상위집합이라 새 REJECT가 수학적으로 불가능 → fixture RED 리스크가 구조적으로 0에 수렴(아래 4에서 3개 기존 계약 생존 논증).
3. **가치 축**: `f(0)`→`p:i32` REJECT는 Rust(E0308 demand_coerce: 인자도 let처럼 coerce)와의 실 divergence — gold-standard(reference-match) 위반의 실오탐 제거. 완성도 축: 이 스왑으로 **모든 default-ON value-flow 사이트가 `_types_assignable`로 통일**되어 rung 사다리의 일관성 invariant가 닫힌다.
4. **표준 축**: HX코드 불요·catalog/corpus 무변경·census grep lockstep 불요 — 착지 비용 최소.

## 3. impl 스펙 (그대로 구현 가능)

**파일**: `compiler/check/types.hexa` (main `d750da959` 기준 좌표)

**교체 diff (유일한 코드 변경, 3625 1줄)**:
```diff
             let want = callee_t.args[k]
             let got = arg_types[k]
-            if !_types_equal(want, got) {
+            if !_types_assignable(want, got, e.children[1 + k]) {
```
- `src` 인자 = `e.children[1 + k]` — call Expr의 children[0]=callee, children[1..]=args (arg-infer 루프 3560이 `e.children[1 + i]`로 순회, emit도 `e.children[1 + k].span` 사용 — 동일 노드).
- 내부 `unit` carve-out(3633~3634)은 **그대로 유지** — `_types_assignable`은 unit actual을 tolerate하지 않으므로(unit은 non-empty·non-HexaVal·non-literal) 여전히 필요하다. 삭제 금지.
- `_emit_hx3003`(2057)·catalog(catalog.hexa:**304**, Severity::Error·S3)·템플릿 무변경.
- 3625 위 주석 블록(3626~3632, unit-carve-out 설명)에 coercion 계약 추가: "call-arg는 let/assign/return과 동일한 `_types_assignable` 계약 (Rust rustc_hir_typeck demand_coerce — 인자 전달 = let-binding과 동일 coercion; E0308) · HexaVal 와일드카드는 N5-pre 오탐 해소 계약(2205~2212 주석·`.verdicts/hexa-cc-native/F-HEXA-CC-NATIVE-N5PRE-STEP3-HEXAVAL.txt`)의 call-arg 확장".

**conservative 경계 (스왑 후에도 REJECT 유지되는 것)**:
- 비리터럴 스칼라 미스매치: `let a: f64; g(a)` vs `p:i32` — src가 리터럴 아님 → REJECT.
- string/char/bool vs numeric: case (c) `add(1,"hi")` → REJECT 유지.
- int-lit → float param (`g(0)` vs `p:f64`): int-lit arm은 both-integer 요구 → REJECT — Rust도 거부(E0308), faithful.
- float-lit → int param: 동일하게 REJECT.

## 4. byteeq중립 논증 + companion test + census 영향

**byteeq중립**:
1. 스왑은 emission 분기만 바꾼다 — `_types_check_call`의 **반환값**(callee_t.ret, 3641~3642)은 불변이라 S3→codegen으로 흐르는 타입 정보 변화 없음(S3는 diag-only).
2. `_types_assignable(want,got,src)` ⊇ `_types_equal(want,got)` (2216 첫 줄) → **diagnostic이 새로 생기는 건 불가능, 제거만 가능**.
3. 실소스: HX3003은 무밴드 Error·S3 fatal → main 빌드가 green이므로 현 실소스 HX3003 emission = **0** → loosening 후에도 0 → 셀프컴파일 diag stream·abort 동작 byte-identical → gen3≡gen4 fixpoint에 영향 없음.
4. fixture 3계약 생존 (main types_test 실측):
   - **(c)** 1587: `add(1,"hi")` — arg2 string-lit vs i64: 어느 coercion arm에도 안 걸림 → 1 HX3003 유지. arg1 `1` vs Int는 이미 equal.
   - **(o)** 1812: `g(ys)` `[f64]` vs `[i32]` — src가 **Ident**라 ArrayLit arm·리터럴 arm 모두 불발, flag-OFF 문자열 sentinel도 unequal → 양 모드 1 HX3003 유지.
   - **(q)** 1836: `g([1.5])` — ArrayLit arm 재귀 시 원소 src=float-lit인데 expected 원소 i64(integer)라 float-lit arm(both-float 요구) 불발 → 1 HX3003 유지; "matching g([1,2]) stays clean"도 불변.

**companion test** — `types_test.hexa` 신규 case **(ac)** (다음 free 문자; (q)가 이미 2회 재사용됐으니 주의), `_build_case_c` idiom 미러:
- 모듈: `fn take32(p: i32) -> i32 { return 0 }` (`_param("p","i32",…)`; body `return 0`은 int-lit coercion으로 HX3004 clean — **`return p`로 쓰면 비리터럴이라 HX3004가 터지니 금지**) + `fn dynp(v: HexaVal) -> Int { return 0 }` + `fn takef(q: f32) -> Int { return 0 }`; main에서 4 call:
  1. `take32(0)` → **0 HX3003** (스왑 전엔 1 — 핵심 회귀-락 assertion: int-lit→i32 coercion)
  2. `dynp(1)` → **0 HX3003** (HexaVal 와일드카드; 스왑 전엔 1)
  3. `take32("s")` → **1 HX3003** (negative control — loosening 경계)
  4. `takef(1)` → **1 HX3003** (int-lit→float param은 Rust-faithful REJECT 유지)
- 기대: `_count_code(diags,"HX3003") == 2`, HX3002 == 0. **기대 severity = Error** (catalog default·무밴드 — 이 rung은 severity를 건드리지 않음).

**census/corpus 영향**: 신규 HX코드 없음 → ① repo에 `corpus.yml` 파일은 없고 census 실체는 `.github/workflows/static-types-corpus.yml`인데 grep 패턴이 `HX30(1[167]|24)` — **HX3003은 census 비대상이라 lockstep 편집 불요**. ② `catalog-code-uniqueness.yml` 무영향. ③ loosening이므로 census 수치가 오를 수 없음.

## 5. 위험/함정 + 미검증

- **함정 1**: companion test에서 i32 param fn의 body를 `return p`로 쓰면 HX3004(비리터럴 i32→Int) 오폭 — 반드시 리터럴 return.
- **함정 2**: `_types_assignable`의 ArrayLit arm은 `src.children` 순회를 want/got 양쪽 `args[0]` 존재 전제로 함 — call-arg에선 kind:"array"가 opt-in lowering에서만 생산되므로 default 빌드 dead code. flag-ON 스모크((o)/(q) 케이스)가 커버.
- **잔여 divergence (이 rung 범위 밖, 정직 박제)**: `g(-1)` — `-1`은 UnOp라 리터럴 arm 불발 → i32 param에 여전히 REJECT (Rust는 수용). let/assign 사이트도 동일 한계라 일관적이며, 후속 micro-rung 후보(UnOp("-", int-lit)를 literal-src로 언랩).
- **후속 rung 후보**: match arm-body join(3705)이 여전히 bare `_types_equal` — if-join(2704)은 assignable인데 match join만 다름. value-flow는 아니지만 다음 faithfulness 후보.
- **미검증 ①**: fixture 생존 논증은 정적 대조다 — 구현 후 pool(aiden/summer)에서 `types_test.hexa`를 flag-OFF/ON 양 모드 실행 + 셀프컴파일 green 확인 필요 (mini에서 빌드 금지).
- **미검증 ②**: HexaVal-typed **got**이 typed param으로 흐르는 실소스 케이스가 corpus에 있는지(현재 0 HX3003이므로 없거나 unknown으로 추론될 것) — 스왑은 그 케이스를 침묵시키는데, 이는 다른 모든 value-flow 사이트가 이미 채택한 와일드카드 계약과 동일하므로 정합. 다만 "HexaVal→typed param 침묵 = 런타임 tag-throw 가능성 잔존"은 사실이며, 이건 legacy self/ 컴파일러 대비 관용 계약의 의도된 성질.
- **미검증 ③**: A 판정에 쓴 "Let Expr text가 mut를 인코딩하는지"는 확인 안 했다(`_types_let_name` 파싱까지 안 내려감) — A를 나중에 캠페인으로 열 때 immutable-only 1차 rung 여부 판단에 필요.

**요약**: B 선정. 코드 변경은 types.hexa:3625의 `_types_equal(want, got)` → `_types_assignable(want, got, e.children[1 + k])` 1줄 + 주석 + types_test 신규 case (ac) 4-assertion. 새 HX코드·catalog·census 변경 전무, strictly-loosening이라 byteeq중립은 구조적으로 보장된다.
