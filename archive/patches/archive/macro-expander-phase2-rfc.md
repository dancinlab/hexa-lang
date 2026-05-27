# macro expander Phase 2 — user-defined macros design RFC

**Status**: rfc-draft-deferred-2026-05-25 — design-only patch (not a fix). Promote via /inbox skill if RFC track wanted.
**Status**: design-level (PR #462 Phase 1 follow-up, 2026-05-23)
**Priority**: P3 (Phase 1 covers ~80% practical use; Phase 2 = power-user feature)
**SSOT**: `inbox/patches/macro-expander-pass-design.md` (Phase 1 baseline)

## Phase 1 recap (landed PR #462)

- 3 hard-coded intrinsics: `println!`, `panic!`, `vec!`
- 파서가 `name!` 토큰을 인식해 고정된 expansion으로 dispatch
- declaration syntax 없음, pattern matching 없음, hygiene 없음
- ~80% 실용 coverage (println for stdout, panic for assertion, vec for literal collection)
- 신규 intrinsic 추가는 parser surgery 필요 → scaling이 안 됨

Phase 1 SSOT: `inbox/patches/macro-expander-pass-design.md` (97 lines, design) +
`macro-expander-pass-design-detailed.md` (290 lines, detailed).

## Phase 2 goal: user-defined macros

canonical reference: Rust `macro_rules!` (declarative, pattern-based, hygienic).
hexa는 Rust pattern syntax를 채택하되 keyword를 단축한다 (`macro_rules!` → `macro`).

### Syntactic surface (제안)

```hexa
macro vec_of!($($x:expr),*) {
    {
        let mut __v: [_] = []
        $( __v.push($x); )*
        __v
    }
}

fn main() {
    let xs = vec_of!(1, 2, 3)   // expands to block expr
}
```

`macro` keyword는 이미 lexer/parser에서 reserved 상태 (`self/lexer.hexa`,
`self/parser.hexa` L308·L576·L588). 즉 syntax-surface는 추가 keyword 0개로 land 가능.

## Phase 2 design choices (5 axes)

| axis | candidates | recommendation |
|---|---|---|
| Declaration | `macro name! { pat => expansion }` / `macro_rules! name { ... }` | hexa-canonical `macro name! { ... }` (no new keyword) |
| Pattern syntax | Rust `$name:fragment` (`expr`/`ident`/`ty`/`tt`) | adopt Rust as-is for familiarity |
| Repetition | `$( ... )*` / `$( ... ),*` / `$( ... )+` | adopt Rust syntax (`*` 0+, `+` 1+, separator optional) |
| Hygiene | full hygienic (Rust default) / unhygienic (C macros) | full hygienic (예측 가능, 명시적 capture 없음) |
| Recursive expansion | yes (Rust) / no (one-shot) | yes — power user expects, fixpoint loop + budget cap |

## 구현 단계 (subset, stacked PRs)

1. **Phase 2a — declaration parsing**: `macro name! { ... }` AST. expansion 없음;
   parser + typecheck stub만. 기존 `name!` invocation은 Phase 1 intrinsic이 우선,
   user macro는 그 다음 lookup table.
2. **Phase 2b — token-tree matcher**: `$x:expr` single-rule single-fragment 매칭.
   `expr`/`ident` 두 fragment부터.
3. **Phase 2c — repetition `$( … )*`**: 0-or-more matcher + cartesian expander.
   separator 처리 (`,`·`;`).
4. **Phase 2d — hygiene renaming**: gensym `__macro_<n>_<orig>` for `let`/`fn`
   introduced in expansion body. site-binding은 그대로.
5. **Phase 2e — recursive expansion**: expansion output을 re-tokenize → macro-pass
   재진입. fixpoint 또는 budget exhausted (default 128 단계).

각 단계는 falsifier 1개 이상 동반:
- 2a: declaration parse round-trip
- 2b: `macro id!($x:expr) { $x + 1 }`; `id!(2) == 3`
- 2c: `vec_of!(1,2,3).len() == 3`
- 2d: macro 내부 `let x =` ≠ 호출자 `x` (hygiene PASS)
- 2e: macro가 macro 호출 → fixpoint 도달

## 영향 surface

| 파일 | 변경 |
|---|---|
| `self/lexer.hexa` | `macro` keyword 이미 reserved (L97 추정) — 추가 변경 X |
| `self/parser.hexa` | `parse_macro_decl` 신규 + token-tree literal storage + invocation path에 user macro lookup hook (Phase 1 intrinsic 분기 이후) |
| `self/codegen.hexa` | macro expansion 결과는 일반 AST → 기존 codegen 그대로 통과 (별도 분기 X) |
| `self/macro_expand.hexa` | 신규 모듈 — matcher / repetition engine / hygiene gensym / fixpoint loop |

## 예상 PR 크기

5-PR stack (각 ~100-200줄, g4 한계 준수):

- 2a parser only ~100줄
- 2b matcher engine ~200줄
- 2c repetition ~150줄
- 2d hygiene ~100줄
- 2e recursion ~80줄

총 ~630줄, single-concern stacking으로 review surface 분산.

## 우회책 (지금, Phase 2 land 전)

- Phase 1 intrinsics (`println!` / `panic!` / `vec!`)
- 일반 fn / closure로 macro 흉내 (단, no syntactic-substitution semantics — eager
  eval, return type 고정)
- code-gen fn (string-template) — heavy, unhygienic, build step 분리

## Open questions (Phase 2 land 시 결정)

1. `tt` (token-tree) fragment 지원할 것인가? (Rust는 yes; hexa는 syntactic
   complexity 증가 → 2c 이후 별도 step)
2. macro export / import 규칙? (module boundary 가로지를 때 namespace는?)
   → Phase 2f로 분리 권장.
3. `proc_macro` (compile-time fn으로 작성되는 macro)는 scope 밖. Rust도 별도
   crate type. hexa는 Phase 3 이후로 미룬다.

## 참조

- PR #462 (Phase 1 commit, 2a9f8028)
- PR #451 / `inbox/patches/macro-expander-pass-design.md` (Phase 1 design baseline)
- `inbox/patches/macro-expander-pass-design-detailed.md` (Phase 1 detailed)
- Rust Reference, `macros-by-example.html` (Phase 2 canonical model)
- PROBE.log.md round 14 next-list "macro expander Phase 2"
