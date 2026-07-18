# L4 unbox — free-fn builtin call-result stamp (`len(x)` → i64) 설계

**측정 근거 (summer boxing census @b2f725216, VALID):** CALLTYPE producer 11250 사이트 중
UNSTAMPED-import=6046(callee ident=3395·field=2651)·fn-stamped=5111·builtin-stamped=93(현 레버 도달).
최대 단일 wasted-int KIND = **free-fn builtin `len(x)` ident-callee형 = 1475 UNSTAMPED int-producer**
(현 builtin-stamped 93 압도). 다음 단일 최대 언박싱 레버.

## 현 갭 (코드)
`compiler/lower/ast_to_hir.hexa` Call arm(~:2145-2168): `_hir_calltype_stamp_enabled()`(:137·`!= "0"`
= **default-ON**) 하에서 결과가 `"?"`이고 callee가 **builtin-METHOD(field-callee)**일 때만
`_hir_builtin_method_ret_prim`(:150 미러 테이블)로 스탬프. **free-fn builtin(ident-callee `len(s)`)은
미스탬프** — main.hexa가 TypeEnv 없이 RAW AST를 lower해(:105) builtin `len`의 callee.typ이 fn-type으로
미해결→:2152 fn-ret 스탬프 미스→`"?"`→type_id 0→codegen re-box.
- ⚠️ doc-drift: :104 주석 "default-OFF"인데 코드는 default-ON — lockstep 수정.

## 설계 (lab fable+sol 수렴 · grep-검증)

### ① 판별자 = whole-program(정확히는 per-module) bound-name census — **rank-1(DefId)은 DEAD**
- **rank-1 기각(grep 확정):** `DefId={module:string, index:i64}` (hir.hexa:21) — **builtin 마커 필드 없음**.
  resolve.hexa에 builtin 마킹 없음. builtin `len`의 `callee.def`=`_hir_miss_def_id()` = unresolved
  ident과 **동일한 sentinel** → "def==missing"은 builtin 증명이 못 됨(양쪽 lab 경고). name-only도 금지.
- **rank-2 채택(fable · sound):** pre-pass AST walk로 **모든 binding-position 이름**을 Set 수집 →
  `len`이 Set에 **없을 때만** 스탬프. `len`이 어디서도 바인딩 안 되면 모든 bare `len(x)`는 builtin
  (아니면 undefined-name = 빌드 실패)뿐. coarse(전역 1개 `let len`이 전역 비활성화)하나 그게 안전핀 —
  컴파일러는 `len`을 유저명으로 절대 안 씀(:2152 자체가 `len(ct.ret)`). 현재 트리 유저 `fn len` = 0(grep).
- binder 폼 **완전 열거 필수(누락=unsound):** fn decl(전 중첩), let/var, fn/closure param,
  for-binder(ExprKind::For), match-binder(ExprKind::Match), catch-binder. (ast.hexa 확인 필요.)

### ② 테이블 — checker SSOT 신설
- checker엔 `_types_builtin_method_ret`(types.hexa:4445)만 있고 **`_types_builtin_free_ret` 없음** →
  신설(SSOT, `len → i64`). `_hir_builtin_free_ret_prim = {len: i64}` 미러(method 미러와 동일 규율).
  HIR 테이블이 "이름이 builtin인가"의 권위가 되면 안 됨 — checker가 SSOT.

### ③ arm (ast_to_hir :2162 가드 안)
```
if bm_callee.kind == "field" { ...기존 method arm... }
else if bm_callee.kind == "ident" && _hir_free_calltype_enabled()
        && _hir_free_builtin_unshadowed(bm_callee)  // census 판별자
{ let br = _hir_builtin_free_ret_prim(bm_callee.text); if br.kind != "?" { t = br } }
```
`t.kind=="?"` 가드 아래라 :2152 fn-ret 스탬프(유저 `len` resolved-fn)를 절대 덮지 않음 — construction상 안전.

### ④ ★게이트 = 신규 sub-flag `HEXA_UNBOX_HIR_CALLTYPE_FREE` **default-OFF 머지**
- 부모 `HEXA_UNBOX_HIR_CALLTYPE`가 **default-ON**이라 bare 확장은 **머지일 shipping 바이트 변경** →
  릴리스 규율(bit-changing=opt-in-first) 위배. 신규 sub-flag default-OFF로 머지=byte-neutral,
  flip PR(default-ON)은 별도(#4964 RUNG 패턴).
- **flip 게이트 = byteeq-3target+nvptx GREEN + ★behavioral**(full suite + shipping smoke +
  실제 running gen-chain·전 config) + **A/B census 델타**(≈ −1475 ident:len·타 이동 0). ★byteeq는
  det miscompile을 못 잡음(gen3≡gen4 동일 오염 통과 = own-link flip 교훈 elf-x86-64-hexa-2/3) →
  behavioral 필수. self-host 오염 스테이크: mis-stamp가 컴파일러 바이너리 자체 손상.
- census pre-pass도 OFF-path byte-neutral 보장(read-only walk·방출 바이트 미교란).

### ⑤ lockstep: ast_to_hir:104 주석 default-OFF→default-ON 수정.

## 테이블 확장 순서 (측정 상위, checker 서명 확인 후에만)
`len→i64`(1475·round-1 단독) → `file_exists→bool`(130·round-2) → `exec`(322·**HOLD**: exit-code i64
vs output-string 미확정) · println(693·unit·제외) · to_string/env_var(string·제외).

## ★구현 전 확정 필요 (census soundness 전제 · grep 미해결)
1. **cross-module ref 모델**: lowering은 per-module(`lower(module)`:2811). bare `len(x)`가 **imported
   유저 fn**으로 해석 가능하면 per-module census 불건전(다른 모듈 `len`을 못 봄). hexa가 cross-module를
   qualified `Mod.fn`(field-callee)로만 부르면 per-module census 충분. **resolve.hexa/bind.hexa
   name-resolution 정독 또는 empirical(유저 `fn len`→string + 호출, flag-ON 컴파일→mis-stamp 여부)로
   확정.** 이 전제 확정 전 구현 착수 금지(unsound 위험).
2. binder 폼 완전 열거(위 ① 목록이 ast.hexa 전체를 커버하는지).
3. import가 unqualified 이름을 scope에 주입할 수 있는지(1과 연동).

## 상태
설계 완성·grep-검증. 구현 = 전제1 확정 후 착수(local 코드 + summer/ghost byteeq, default-OFF 머지 →
behavioral+byteeq flip). 관련 lab 원본 = 세션 scratchpad `lab_l4_freefn_builtin_stamp.md`.
