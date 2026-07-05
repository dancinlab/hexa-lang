# R2 — HX3026 field-on-primitive REJECT (Rust E0610)

round-3 2-lane batch, 레인① static-types, 라벨 **(al)(am)**. anchor = origin/main
`ef0599b61` (#4615 · C/#4609 HX3025 착지 후).

## 요지
`n.foo`처럼 **KNOWN 스칼라**(int/float/bool/char) receiver의 필드 READ는 런타임에서
필드 슬롯이 없어 무의미/에러이므로 S3에서 REJECT한다 (HX3024/HX3025와 동일한
"known-runtime-error → REJECT" 계약). Rust E0610 (`` `{actual}` is a primitive type
and therefore doesn't have fields``) 미러.

## 구현 (전부 실코드 재-앵커, 스펙 좌표는 stale였음)
- **counter** `let mut _types_callee_depth: i64 = 0` — types.hexa (모듈-스코프,
  `_types_static_on` 직후. 스펙의 `pub let mut`는 파일 idiom(bare `let mut`)에 맞춤).
- **Field 암 emit** — types.hexa Field READ arm(실측 **:3361–3389**, 스펙 ~3335/3355는
  stale). receiver-infer while-loop 직후·ident-registry 블록(`_types_is_ident(recv.kind)…`)
  **앞**에 삽입:
  `_types_callee_depth == 0 && len(e.text) > 0 && !_is_builtin_method(e.text)
   && (_is_integer_kind(recv_t) || _is_float_kind(recv_t) || recv_t.kind=="bool" || recv_t.kind=="char")`.
- **counter wrap** — `_types_check_call`(실측 **:3579**) 의 callee child infer
  (`let callee_t = _infer_expr(callee, …)`, 실측 **:3582**) 를 inc/dec로 감쌈.
- **_emit_hx3026** — `_emit_hx3025`(:2048) 1:1 미러, 직후 삽입. args=`actual`+`field`,
  `_types_strict_for` real=Error/fixture=Warning.
- **catalog** — HX3026 DiagSpec, HX3025(catalog.hexa:498) 직후. E0610 인용 + 런타임
  보증 + under-reject 열거 + builtin carve-out + callee-position 면제 서술.

## §5.1 미검증 ② 실측 결과 (스펙이 명시 요구)
1. **callee-infer 정확 라인 = types.hexa:3582** (`let callee_t = _infer_expr(callee,…)`).
2. **counter 필요함 = YES.** `n.foo()`의 callee는 `Field{foo}` 노드이고 `_types_check_call`
   이 그 노드에 `_infer_expr`를 직접 호출(:3582) → Field 암(:3361)을 탄다. 따라서
   guard 없으면 READ 위치 HX3026이 callee HX2001과 **이중발화**. counter로 억제 필수.
   (스펙 §5.1 "callee-Field가 아예 infer를 안 타면 counter 불요"의 반증 — infer를 탐.)
3. **`(a+b).foo` recv_t** — receiver가 non-ident(BinOp)일 때: BinOp `a+b`(둘 다 스칼라
   ident)의 결과 타입은 `_types_check_binop`이 `lt`(=a의 타입, 예 i64)를 반환하므로
   recv_t = i64 (integer kind) → **HX3026 발화함**. ident-registry 블록은 non-ident
   receiver를 건너뛰지만(struct 필드 lookup 불가) HX3026 arm은 recv_t만 보므로 발화.
   → `(a+b).foo`도 REJECT (E0610-parity, 의도한 동작). 단, mixed-type binop 등
   recv_t가 unknown으로 degrade하면 침묵 (conservative).

## 테스트 (types_test.hexa · NON-CI · pool bare-run)
- **(al)** 단일 모듈: `n.foo`→1 HX3026(error) · `p.x`(p:Point)→0 · `n.len`(builtin)→0 ·
  `n.foo()` callee→0 HX3026 + 1 HX2001. 핀: `nHX3026==1 && err==1 && nHX2001==1`.
- **(am)** fixture: `case_hx3026_test.hexa` 경로 → 1 HX3026 **warning** (carve-out).

## byteeq 논증
신규 REJECT는 shipping source에서 발화 0이어야 함 → PR CI byteeq 3-target +
selfhost-gates가 빌드로 증명. corpus census: `HX30(1[167]|2[4-6])` grep 결과 compiler/
내 참조 0건, HX3026 코드 충돌 0건.

## 잔여/다음
- nested receiver(`s.inner.x`)는 type-erasure 천장으로 침묵 (r7+ 동벽, WALL-A 컨버전스).
- string receiver는 미포함 (HX3025와 동일 보수, `s.field` census 미완).
