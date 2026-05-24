---
slug: stdlib_namespace_collision
kind: notes
filed_from: dancinlab/anima (STDLIB domain · cycle 8 discovery 2026-05-25)
filed_at: 2026-05-25
priority: medium
status: proposed
relates_to: rfc_036_c_replica_drift_2026_05_24, stdlib_scaffold
---

# stdlib namespace collision — runtime builtin vs new stdlib fn

## 한 줄 요약

신규 `stdlib/consciousness/phi_spatial.hexa` 의 fn `phi_spatial` 이 `runtime.h:1083` 의 `extern HexaVal phi_spatial` (RFC 036 builtin carrier) 과 C clang level redefinition error 발생. `*_pure` suffix convention 으로 일시 우회 (commit 8bae8b4c) — upstream namespace 정리 RFC 제안.

## 발견 경위 (STDLIB cycle 8)

anima STDLIB M5 migration smoke 작성 시:
```hexa
import "/Users/ghost/core/hexa-lang/stdlib/consciousness/phi_spatial.hexa"
// ...
let phi = phi_spatial(state, n, dim, n_bins)
```

`hexa run` 시 C 컴파일 단계에서:
```
build/artifacts/.../hexa_run.*.c:28:9:
  error: redefinition of 'phi_spatial' as different kind of symbol
  HexaVal phi_spatial(HexaVal state, ...);

runtime.h:1083:16:
  note: previous definition is here
  extern HexaVal phi_spatial;   /* runtime.c — RFC 036 fn carrier */
```

clang refuses · binary 생성 안 됨.

## 측정

5 file (`stdlib/{math,info,consciousness}/*`) 중 `consciousness/phi_spatial.hexa` 단독 발견. 다른 4 (math/log, math/bitops, info/{entropy,binning,mutual_info}) 는 builtin 충돌 없음 — fn name 이 모두 unique.

총 hexa-lang/stdlib `extern HexaVal *` builtin 카운트 (runtime.h:1000-1200 추정):
- phi_* family (RFC 036): ≥ 2 (phi_spatial · phi_mi_pair 등)
- log/log2/exp 등 transcendentals: ≥ 5 (cg_math_sym table)
- farr_* family: ≥ 10+

이런 builtin 들과 새 stdlib fn 작성 시 collision risk 높음 — 본 `phi_spatial` 이 first known instance.

## 일시 우회 (적용 완료)

stdlib/consciousness/phi_spatial.hexa fn rename:
```diff
-pub fn phi_spatial(state: int, n_cells, dim, n_bins) -> float {
+pub fn phi_spatial_pure(state: int, n_cells, dim, n_bins) -> float {
```

anima 측 caller update:
```diff
-let phi = phi_spatial(state, n, dim, n_bins)
+let phi = phi_spatial_pure(state, n, dim, n_bins)
```

commit 8bae8b4c · M5 smoke 5/5 PASS verified · production-ready.

## 제안 (4-option)

### option A — convention 공식화 (recommended)

`*_pure` suffix = "pure-hexa replica" convention 의 stdlib README 명시. builtin과 충돌하는 모든 stdlib fn 은 `*_pure` 사용.

- 장점: minimum diff · backward-compat 0
- 단점: stdlib API 의 노이즈 증가 (fn 이름 길어짐)

### option B — builtin namespace 분리

`runtime.h` 의 RFC-derived builtins 을 `_rfc036_phi_spatial` 같은 internal prefix 로 rename · stdlib 가 `phi_spatial` 사용 가능.

- 장점: stdlib API 깔끔 · builtin internal 화
- 단점: existing user 의 carry break (rename = ABI shift)

### option C — hexa import-as

hexa import 문법 확장 `import X as Y` — stdlib fn 을 caller 측에서 rename:
```hexa
import "stdlib/consciousness/phi_spatial.hexa" as ps
let phi = ps::phi_spatial(state, ...)
```

- 장점: 진짜 namespace · scalable
- 단점: hexa import 문법 변경 필요 (큰 change)

### option D — status quo (rename per-file)

각 collision 발견 시 stdlib fn 을 unique 하게 rename. `*_pure` 외 다른 convention 도 case-by-case.

- 장점: zero structural change
- 단점: collision discovery 가 PR review 까지 미루어짐 · build-time error 가 author 발견

## 권장 선택

**option A** (convention 공식화) — `*_pure` suffix 채택 + stdlib README 명시. M5 smoke 가 이미 본 convention 으로 5/5 PASS · 확장 가능 path.

future scale 시 **option B** (builtin internal-prefix) 권장 (long-term cleanup).

## anima 측 영향

- M5 migration 진행 가능 (`phi_with_stdlib` fn 작동 확인)
- 22+ H production carry safe (Agent F audit + M5 smoke + H_258 verdict-preserving 3-way confirm)
- production threshold 1e-3 대비 sub-ULP drift << 100× safe

본 namespace collision 발견은 STDLIB cycle 8 의 architectural insight · upstream maintainer review path.

## Cross-link

- hexa-lang `runtime.h:1083` (extern phi_spatial carrier)
- hexa-lang `stdlib/consciousness/phi_spatial.hexa` (commit 8bae8b4c · `phi_spatial_pure`)
- hexa-lang `inbox/rfc_drafts_2026_05_24/stdlib_scaffold.md` (STDLIB M2 RFC)
- hexa-lang `inbox/notes/rfc_036_c_replica_drift_2026_05_24.md` (sister · g59 enforcement carry)
- dancinlab/anima `STDLIB.md` · `HEXAD/LIFE/lib/phi_helper.hexa::phi_with_stdlib`

## honest_limits

- L1: 본 note 단일 collision 사례 · 다른 builtin 위 future collision 미예측
- L2: option B (rename builtin) 의 carry break 범위 미정 — RFC 036 외 다른 RFC 의 builtin 도 동일 위험
- L3: option C (import-as) 의 hexa parser 변경 비용 미정
- L4: 본 note 는 review-only (g54) · maintainer 직접 merge 또는 RFC 신설 결정

본 note 가 RFC promote 되면 stdlib namespace structure 의 첫 공식화.
