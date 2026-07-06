# round6 Rung B — HX3012 use-after-move 확장 (field/index base + binop operand)

## 기준
- origin/main `cc2e19a80` 분기. opt-in `HEXA_OWN_LINT` (default-OFF) → byteeq-neutral.
- 자매 rung: L2 r1/r2/r2b (bare-ident move: let-RHS·assign-RHS·return·call-arg).

## §0 mechanism (실측 재-anchor)
- `_own_lint_touch` (compiler/check/types.hexa:1434) 은 `_types_is_ident` 게이트(:1435)로
  bare ident 만 처리 → moved 값을 **field base(`x.f`) · index base(`x[i]`) · binop operand(`x + 1`)**
  로 READ 하면 use-after-move 미검출.
- move 등록/마킹은 그대로 `_own_lint_touch` (mark-first-warn-later). READ 위치는 **의미가 다름**
  (읽기는 move 아님) → 별도 warn-only helper 신설.

## 구현
1. `_own_lint_use_check(use_node, out)` 신설 (types.hexa, `_own_lint_touch` 직후):
   - WARN-ONLY: live 바인딩(newest entry state 0)은 침묵 — READ 는 절대 move 마킹 안 함
     → `let a = p.x; let b = p.y` (owned struct 2회 필드읽기) false-fire 방지.
   - **already-moved(state 1) 만** HX3012 (reuse `_emit_hx3012`, 신규 DiagSpec 無 → catalog 76/76 불변).
   - ONE-LEVEL: 즉시 base/operand ident 만; nested(`s.a.b`,`(x+1)+2`)는 각 sub-node arm 이 커버 →
     recursion 불필요 + 동일 use-span 중복emit 방지. move-site span dedup 유지.
2. 호출 3곳 (전부 `env("HEXA_OWN_LINT")=="1"` flag-first short-circuit):
   - index arm (`_types_is_index`, ~:3372): `_own_lint_use_check(e.children[0])` (base)
   - field arm (`_types_is_field`, ~:3427): `_own_lint_use_check(e.children[0])` (receiver)
   - `_types_check_binop` (operand infer 직후, ~:3516): children[0]·children[1]
     (`as`-cast 는 상단 early-return → conservative 제외)

## 보수성 (under-reject)
- registered @own-moved ident 만 fire. unknown/live/미등록 → silent.
- index 는 **base 만** (index value read 는 spec 밖 → 연기). `x as T` cast 제외.
- default build: 세 호출부 flag-first → 진단 스트림 byte-identical (byteeq 3-target 중립).

## 테스트 (compiler/check/types_test.hexa)
- `_build_case_own_lint_rungB` + runner case **(aq)**:
  - `@own let x=5; let a=x`(move); `x.f`·`x[0]`·`x+1` → ON: **3 HX3012**.
  - `@own let y=7`(never moved); `y.g` → live receiver → **0** (warn-only 증명).
  - OFF: **0** (byteeq-neutral).

## 검증
- NON-CI pool bare-run (aiden, hexa v0.577.0): `hexa run compiler/check/types_test.hexa`
  ON=3 / OFF=0 (case aq PASS). CI byteeq 불요 (default-OFF).
