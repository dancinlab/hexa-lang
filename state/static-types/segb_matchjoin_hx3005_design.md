실측 완료 — 설계를 확정 보고합니다.

---

# 설계: match arm-body join `_types_equal` → `_types_assignable` (HX3005 faithfulness rung)

## 1. 실측 — main HEAD 재앵커 (origin/main = 34e43d251, #4604; HX3003 #4603 포함)

- **좌표 이동 확인**: 당시 3705행 → 현재 **`compiler/check/types.hexa:3714`**. 현 코드 (3709–3717):
  ```hexa
  let bt = _infer_expr(e.children[i + 1], env, ctx, out)      // 3709
  if !have_first {
      first_t = bt
      have_first = true
  } else {
      if !_types_equal(first_t, bt) {                          // 3714 ← 타깃
          _emit_hx3005(arm_idx, first_t, bt, e.children[i + 1].span, out)  // 3715
      }
  }
  ```
  `_check_match`(3687행~) 내부, 여전히 **bare `_types_equal`** — 확인됨.
- **emit 코드 = HX3005** (`_emit_hx3005`, types.hexa:2076). catalog.hexa:339–346: "match arms have different types", **`Severity::Error` · stage S3**.
- **밴드 없음 — 중요**: HX3001/HX3011/HX3016은 `_types_strict_for` fixture carve-out(Warning 다운그레이드)이 있지만 `_emit_hx3005`는 **무조건 `diag_emit(b)` 직행 = Error everywhere**. 즉 이 사이트의 false-positive는 곧 **빌드 REJECT**(`_has_errors` → exit 1). HX3003보다 오히려 시급도가 높은 faithfulness-fix입니다.
- 참고: #4603의 3632행 주석 "closes the last bare-`_types_equal` value-flow site"는 이 match arm-body join을 누락한 채 쓰인 것 — 실제 마지막 value-flow bare 사이트는 여기입니다. 이 rung이 진짜로 그 계열을 닫습니다.

## 2. 안전성 판정 — 스왑은 옳고, strictly-loosening

**(a) 의미상 옳은가**: 예. match는 표현식이고 `_check_match`는 `return first_t` — 모든 arm body 값이 match의 타입으로 **join되어 value-flow**합니다. if-join(2704행 `_types_assignable(then_t, else_t, e.children[2])`)과 논리 구조가 1:1 동형(expected=첫 분기, actual=후속 분기, src=후속 분기 expr). Rust도 동일: match arm들은 E0308 `demand_coerce`로 공통 타입에 coerce되며, 문장 위치의 match도 arm 타입 일치를 요구.

**(b) strictly-loosening**: 구조적으로 보장. `_types_assignable`(2215행) 첫 줄이 `if _types_equal(expected, actual) { return true }` — **strict superset**. 스왑으로 emit이 늘어나는 입력은 존재 불가, 줄어들기만 함. 새 REJECT 불가.

**(c) 새로 통과하는 케이스** (assignable − equal 델타, 2215–2253행 실코드 기준):

| 케이스 | 예 | Rust-faithful? |
|---|---|---|
| HexaVal/any 어느 쪽이든 | `match c { A -> hv, B -> 1 }` | ✅ dynamic-any wildcard — HX3003(#4603)·전 value-flow 사이트와 동일 정책 |
| int-literal arm body + 양쪽 integer kind | `fn f(a: i32) { match a { 1 -> a, _ -> 3 } }` — 현재는 i32 vs i64로 **HX3005 Error REJECT** | ✅ rustc는 untyped int literal을 arm join에서 unify (E0308 안 냄) |
| float-literal arm body + 양쪽 float kind | `match .. { A -> x_f32, _ -> 0.0 }` | ✅ 동일 |
| array×array + ArrayLit src → per-element 재귀 (r9b arm) | `match .. { A -> xs_f32arr, _ -> [0.0] }` | ✅ per-element demand_coerce; 단 `kind:"array"`는 ARRAY_LOWER/r8 opt-in 분기만 생산 → 기본 빌드에선 dead arm |

**알려진 conservative 경계 (유지, 확장 금지)**: 방향 비대칭 — **첫 arm이 literal**이고 뒤 arm이 typed ident인 경우(`match c { A -> 3, B -> a_i32 }`)는 src=ident라 coercion arm이 안 걸려 여전히 REJECT. Rust는 통과시키지만, if-join(then-literal/else-ident)도 정확히 같은 경계를 갖고 있어 **대칭성 유지가 이 rung의 목적에 부합**. 양방향 literal 체크는 별도 rung(하지 않기를 권장 — if-join과 동시 설계 필요).

**unit 비대칭 (스왑과 별개, 이번 rung 범위 밖)**: if-join(2711)·HX3003(3642)은 unit-permissive guard가 있는데 match join엔 없음. if-join 주석대로 "unmodeled callee 호출은 unit을 infer"하므로 `match c { A -> some_call(), B -> 1 }`이 오늘도 HX3005 Error를 낼 수 있는 클래스. assignable은 unit을 tolerate하지 않으므로 **이 스왑이 그걸 고치지 않음** — 의도적으로 범위 밖(1-diff 유지). §5의 다음 후보로 명시.

## 3. impl 스펙 — 정확한 1-diff

**`compiler/check/types.hexa:3714`**, 1줄:

```diff
-            if !_types_equal(first_t, bt) {
+            if !_types_assignable(first_t, bt, e.children[i + 1]) {
```

- **src 조달 = zero-plumbing**: arm body Expr `e.children[i + 1]`은 바로 위 3709행에서 이미 사용 중이고 3715행 emit도 그 span을 씀. 새 변수·인자 배선 불필요.
- 3715행 emit·`arm_idx`·`first_t` 갱신·루프 구조 전부 불변. `_types_assignable`은 pure(env/out 미변경)이므로 반환 타입(`first_t`)·추론 상태 부작용 없음.
- 관례상 3714 위에 if-join(2698–2703)·HX3003(3626–3634) 스타일의 주석 블록(Rust E0308 인용 + loosening-only 논증 + "no-band=Error 사이트라 false-positive가 REJECT였다" 명시) 추가 — diff는 주석+1줄 스왑뿐.

## 4. byteeq중립 논증 + companion test + census

**byteeq중립 (구조 보장)**:
1. superset 1줄 논증: emit은 **감소만** 가능.
2. checker 산출(diags)은 codegen 입력이 아니고, `_check_match` 반환값(`first_t`)·추론 부작용은 스왑과 무관하게 동일 — emit 여부만 달라짐.
3. HX3005는 Error인데 main이 green = **현 corpus(전체 real source)에서 HX3005 발화 0** → 스왑 후에도 0 → 기본 빌드 diagnostic stream까지 byte-identical. 기존 fixture: case (u) 모듈은 arm body가 전부 int-literal(i64 동일)이라 HX3005 0으로 불변.
4. gen3≡gen4 fixpoint + byteeq 3-target은 평소 게이트 그대로 (types.hexa 소스 변경이므로 컴파일러 재빌드는 당연히 거침).

**companion test — types_test 신규 case (af)** (마지막 라벨 (ae) 실측 확인, types_test.hexa:2216):

- 빌더 `_build_case_hx3005_join_coerce()` — case (u) 빌더(`_build_case_static_types_r9c`, types_test.hexa:1275) idiom 그대로 hand-built AST:
  ```
  fn f(a: i32) {            // _param("a", "i32", ...)
      match a {
          1 -> a,           // first_t = i32 (typed param ident)
          2 -> "s",         // string vs i32 → HX3005 유지 (positive)
          _ -> 3            // int-lit vs i32 → 舊 HX3005 / 新 coerce clean
      }
  }
  ```
  `_match_expr(_ident_expr("a",…), arms, f, …)` + `_int_expr`/`_string_expr`/`_wildcard_expr`/`_fn_item`.
- **기대치**: `_count_code(diags_af, "HX3005") == 1` (arm_idx 1의 string arm만) — **pre-fix면 2**가 나오므로 이 단일 count가 positive-유지와 loosening을 동시에 핀. 추가로 `_count_code_sev(diags_af, "HX3005", "error") == 1`(밴드 없음=Error 불변 핀, case (v) idiom·helper 1659행 실존 확인) + `_count_code(diags_af, "HX3011") == 0`(패턴 `1`,`2`는 r9c에서 int-lit→i32 coerce clean — 교차발화 없음 증명).
- 선택(권장): HexaVal wildcard leg — arm body 하나를 `named:any` 반환 모델드 fn 호출로 넣어 0 HX3005 확인. 빌더 복잡도가 늘면 생략 가능(HX3003 case (ae)가 같은 arm을 이미 핀).

**census/corpus**: HX3005는 **기존 코드** — catalog 신규 등록·grep lockstep 불필요. 문서 lockstep 1건: `state/static-types/wall_a_endgame.md:18`의 census 문장("HX3005 match-arm body consistency … via `_types_equal`")을 assignable로 현행화 + "value-flow 사이트 전부 assignable 완결" 기재(#4603 주석의 '마지막' 표기 정정 포함).

## 5. 위험 / 미검증 / 다음 후보

**위험 (낮음)**:
- 이론상 새 REJECT 불가·기본 corpus 발화 0이라 사고 표면이 사실상 없음. 유일한 실질 위험은 array-재귀 arm에서의 `src.children` 접근인데, ArrayLit kind 체크가 선행되어 arm body가 ArrayLit일 때만 재귀 — 크래시 경로 없음(HX3003 때 이미 동일 경로 검증).
- 함정: worktree들(`.worktrees/sh-next` 등)에 types.hexa 사본 존재 — **반드시 main 기준 새 브랜치에서** ([[feedback_survey_branches_verdicts_before_deriving]] 관례).

**미검증 지점**: ① 실 corpus에 "match arm unmodeled-call→unit + 값 arm" 조합이 있는지(있다면 오늘도 Error였을 테니 없을 것으로 추정 — pool 빌드에서 HX3005 grep으로 0 확인 권장). ② types_test의 `_ident_expr` arm body가 i32 param을 정확히 infer하는지는 case (u) scrutinee 선례로 강하게 추정되나 구현 시 1회 로컬 실행으로 확정.

**다음 후보 (우선순위순)**:
1. **match-join unit-permissive guard** — if-join(2711)·HX3003(3642)과의 잔여 비대칭. 역시 loosening-only·Error 사이트라 가치 높음.
2. binop operand 비교(3446·3474)의 literal-aware 완화 — 단 이건 value-flow가 아니라 operand unification이라 assignable 방향성이 안 맞음. 별도 설계 필요.

이대로 구현 → PR → byteeq 3-target + pool(aiden/summer) 검증하시면 됩니다.
