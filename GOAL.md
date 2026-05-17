# GOAL — hexa-lang 의 한 문장

```
/goal hexa-lang 의 인터프리터를 폐기하고, 모든 .hexa 가 인터프리터 없이 네이티브로 컴파일·실행되는 self-hosted 컴파일러로 완성한다.
```

> **한 문장 (canonical)**: hexa-lang 의 인터프리터를 폐기하고, 모든 `.hexa` 가 인터프리터 없이 **네이티브로 컴파일·실행**되는 **self-hosted 컴파일러**로 완성한다.

---

## 무엇이 아닌가 (NOT)

- `hexa run` (트리워킹 인터프리터) 유지 아님 — 폐기예정·신규 의존 금지 (`AGENTS.tape @D g_interp_deprecated`)
- 인터프리터를 oracle 로 신뢰 아님 — interp 는 측정상 buggy-oracle (n6_uniqueness·sigma_phi_tau·atlas_cycle_append 에서 aprime≡hexa-build, interp 만 outlier)
- LLVM IR / C-transpile / 제3자 codegen 백엔드 아님 (`AGENTS.tape @D g5 hexa-native-only` · `HEXA-NATIVE-ONLY.md`) — C emission 은 portable artifact 일 뿐 architecture 아님
- hexa_v2 (부트스트랩 transpiler) 영구 의존 아님 — aprime_cc-direct 가 canonical path 가 되는 것이 목표

## 무엇인가 (IS)

- `compiler/main.hexa` (네이티브 컴파일러) 가 **자기 자신을 컴파일** (self-host fixpoint: ap1 → flat → ap2, ap2 가 ap1 산출을 재현)
- 모든 `.hexa` 가 `hexa build` (compiled path) 로 검증·실행 — frontend → check → HIR → MIR → LIR → arm64 asm, 인터프리터 경유 0
- aprime_cc-direct corpus 커버리지 ≥ interp (R7 deletion gate ①) — interp 삭제해도 회귀 없음을 측정으로 입증
- 인터프리터 소스의 실제 삭제 (R7) — 4 deletion gate 전부 close 후

## 모든 작업은 이 한 목표의 수단

```
RFC 034 autograd (✅) · 040 device-farr (✅)        ← 언어 표현력 (downstream 흡수 가능선)
  → interp-retirement R3–R7 (aprime_cc-direct 부트스트랩)
  → self-host fixpoint (#23 ✅ · #24 ✅ · #25 ⏳ ap2 empty-fn-body)
  → R7 deletion gate ①~④
       ① aprime-direct coverage ≥ interp
       ② hexa CLI 드라이버 compiled (✅ self/main.hexa · module_loader interp-free)
       ③ atlas SIGSEGV 종결 (✅ struct-array #5 · real-data #24)
       ④ module_loader flatten 경로 interp 비의존 (✅)
= 전부 "인터프리터 없이도 .hexa 가 전부 도는가" 의 폐쇄
```

## 현재 정직한 위치 (g3 — over-claim 금지)

**목표 미도달.** self-host fixpoint 미달 — codegen-correctness 버그 3개 중 2개 종결, 1개 잔존.

| # | self-host 버그 | 상태 | main |
|---|----------------|------|------|
| #23 | `index_set` 반환값 drop → stale array header | ✅ FIXED | `cceb0351` |
| #24 | `_patch_loop_sentinels` sibling-loop continue mis-bind | ✅ FIXED | `9223fe4a` |
| #25 | ap2 per-function emit loop 이 함수 body 0개 생성 | ⏳ 격리·진행 중 | — |

- **gate ①**: 33/44 MATCH (aprime_cc tier-1 ≡ hexa-build tier-2 oracle). frontend-CGFAIL 6 + env-resource 2 제외 시 effective ≈ 33/36 (92%).
- **잔여 실-aprime gap**: 3 atlas-verifier MISMATCH 한 클러스터로 수렴 (`doctrine`·`tecsl_verify`·`wave3` — verifier scan predicate 의 wrong truth-value, codegen bool-coercion 후보).
- **ap2 도달선**: real 6.4 MB atlas 15952 nodes 로드 크래시 0 + frontend/atlas-load/lex/parse/bind 통과 (이전엔 atlas-load 즉사) → 마지막 블로커 = #25 (emit loop).
- **인터프리터 삭제**: 미실행 — gate ①~④ 전부 close + #25 종결 후. 현재는 `폐기예정` 거버넌스 표시만 (`@D g_interp_deprecated`).

> 이 GOAL 은 north-star — 달성 주장 아님, 측정된 거리 명시. self-host fixpoint·gate 측정값의 SSOT 는 `compiler/PLAN.md` 진행 로그. 인터프리터는 이미 사용 금지(메모리 directive: `hexa run` 금지, 검증은 compiled path) 이나 *소스 삭제*는 별개 — 정직히 미실행으로 기록.

---

## cross-link

- `AGENTS.tape` — `@D g_interp_deprecated` (R7 4-gate spec) · `@D g5 hexa-native-only` · `@D g_plan_consolidation` (PLAN 단일 SSOT)
- `compiler/PLAN.md` — compile cycle 진행 로그 SSOT (self-host fixpoint·gate ① 측정값의 거리 기록)
- `ROADMAP.md` — R3–R7 phased plan (R7 = 인터프리터 실삭제)
- `HEXA-NATIVE-ONLY.md` — no LLVM · no C-transpile · self-hosted 정책
- `tool/build_aprime.sh` — aprime_cc 5-stage 부트스트랩 recipe (smoke `exit(6*7)==42`)

> GOAL 한 문장은 stable (north-star). 진척·측정값은 `compiler/PLAN.md` 가 SSOT — 본 파일은 "왜" 의 SSOT.
