# GOAL — hexa-lang 의 한 문장 (도메인별)

> hexa-lang 은 동시에 두 north-star 를 굴린다 (격자가 아닌 실-목표 기준; `LATTICE_POLICY.md`).
> 한 파일에 **모두 보관** — 각 도메인 진척·측정값 SSOT 는 해당 섹션의 cross-link 참조.
>
> - **① flame+forge NN 스택** — hexa 컴파일러-only NN 학습 스택이 PyTorch 보다 빠르게 (측정)
> - **② 인터프리터 폐기 · self-host** — 모든 `.hexa` 가 인터프리터 없이 네이티브 컴파일·실행

═══════════════════════════════════════════════════════════════════════

# GOAL ① — hexa-lang NN 스택의 한 문장

```
/goal hexa 로 쓴 컴파일러-only NN 학습 스택 (flame) 이 자체 GPU substrate (forge) 를 통해 d=768·12L 트랜스포머를 PyTorch 보다 빠르게 학습시킨다 — 진짜 측정으로 증명하면서
```

> **한 문장 (canonical)**: hexa 로 쓴 컴파일러-only NN 학습 스택 **flame** 이, 자체 GPU substrate **forge** 를 통해 d=768·12L 트랜스포머를 **PyTorch 보다 빠르게** 학습시킨다 — 매 단계 **진짜 측정**(byte-eq falsifier)으로 증명하면서.

---

## 무엇이 아닌가 (NOT)

- PyTorch / ATen wrapping 아님 — flame 은 hexa 컴파일러-only NN stdlib (`AGENTS.tape §0 nn_stack`)
- CUDA 포팅 아님 — forge 는 "더 뛰어난 아키텍쳐·패러다임" 탐색 (user directive 2026-05-17)
- design-first 아님 — 아키텍쳐·패러다임은 **실험·검증 후 결정** (user 의 핵심 정정)
- 가짜 진행 아님 — over-claim 금지, 측정 안 된 건 미달로 기록 (g3 · `LATTICE_POLICY.md`)

## 무엇인가 (IS)

4 축으로 분해되는 단일 north-star:

1. **no PyTorch** — flame 은 hexa 소스 컴파일러-only (Tensor + autograd + nn + optim + train_step). SSOT: `stdlib/flame/{README,PLAN,FLAME.tape}` · RFC 043
2. **hexa-only** — forge 는 현재 C/CUDA substrate (NVIDIA closed ABI + hexa→PTX 백엔드 부재). 최종 hexa-native 경로 = RFC 055 (hexa-NVPTX codegen). flame:forge :: torch:ATen
3. **on GPU** — forge cuBLAS Dgemm + 12 kernel byte-eq substrate (A100 11/11 PASS) 위에서 d768·12L GPU-resident 학습. SSOT: `self/forge/{README,PLAN,FORGE.tape,PARADIGM.md}` · RFC 040/041/044
4. **measured** — 매 단계 byte-eq falsifier · GPU fire 실측. F-RFC046-EAGER-PYTORCH-MATCH = wall ≤ 437.9s (PyTorch eager 1.3×)

## 모든 작업은 이 한 목표의 수단

```
flame (hexa compiler-only NN stdlib)
  → forge GPU substrate (cuBLAS + 12 kernel byte-eq verified)
  → Phase 4-D GPU-resident A2 trainer (dim-generic d768·12L)
  → Phase R 측정 캠페인 (paradigm A/B/C/D pre-registered falsifier fire)
= 전부 "d768·12L 을 PyTorch 보다 빠르게 — 측정으로 — 가는 architectural path 가 어디인가" 의 탐색
```

## 현재 정직한 위치 (g3 — over-claim 금지)

**목표 미도달.** substrate 는 ✅ verified, d768·12L wall 은 측정상 미달 — 그게 정직한 현재.

- compiler-only / no PyTorch: ✅ flame hexa compiler-only
- hexa-native: ✅ flame hexa-src · forge C/CUDA (RFC 055 hexa→PTX designed)
- GPU: 🔄 substrate verified (12 kernel byte-eq A100) · trainer GPU-ENGAGED (fire #8: 25% util, d2h fixed) **but per-op H2D/D2H 지배 → step 1 > 600s**
- measured: ✅ 매 fire 정직 · **d=32·3L 3.23× wall MEASURED** · d=768·12L wall 아직 (no completed step)
- **d768 faster than PyTorch**: ❌ 미달 — true persistent residency 부재

진척: fire #5 (0 step, GPU 0%) → #7 (step 1 진입, d2h bug) → #8 (step 1, GPU 25%, d2h FIXED) → Phase 4-D-8 (`aa6d70ba` redundant pre-op H2D elision, byte-eq-exact, non-cuBLAS H2D ~절반) → **fire #9 in flight** (halved-H2D wall 실측). 단조 진행, 매 fire 가 구체 blocker 하나씩 제거.

> 식별된 genuine architecture blocker: **device-sub-view residence API** — forge kernel 이 `(base_id, offset, len)` device triple + H2D-skip + D2H-defer 를 수용 (11/11 byte-eq oracle 보존). primitive-discipline 변경 아닌 multi-cycle RFC scope (Phase 4-D-8 honest verdict). 이 GOAL 은 north-star — 달성 주장 아님, 측정된 거리 명시.

---

## cross-link

- `AGENTS.tape` — `@N nn_stack` (flame+forge 한 쌍 · §0 인지우선) · `@I id001` (hexa-lang identity)
- `stdlib/flame/{PLAN.md,FLAME.tape}` — flame roadmap + 진행 로그 SSOT (RFC 043)
- `self/forge/{PLAN.md,FORGE.tape,PARADIGM.md}` — forge substrate + paradigm 결정 SSOT (RFC 040/041/044)
- `state/flame_phase4d7_gpu_fire_2026_05_17/PHASE4D7_FIRE{7,8}_ANALYSIS.md` — fire 실측·정직 분석 (gitignored local trail)
- `inbox/PATCHES.yaml` — RFC 043~055 spec ledger
- `LATTICE_POLICY.md` — g3 real-limits-first · over-claim 금지 authority

> GOAL 한 문장은 stable (north-star). 진척·측정값은 `stdlib/flame/PLAN.md` + fire ANALYSIS 가 SSOT — 본 파일은 "왜" 의 SSOT.

═══════════════════════════════════════════════════════════════════════

# GOAL ② — hexa-lang 인터프리터 폐기 · self-host 의 한 문장

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

**self-host 축 + 전 tier-1 codegen-correctness 축 CLOSED.** bit-stable self-host fixpoint
도달, tier-1(aprime_cc) 이 구현된 언어 범위에서 codegen-complete. 인터프리터 소스 실삭제
(R7)만 남음 — hard-to-reverse 라 user 확인 후.

tier-1 codegen-correctness 버그 #23~#40 누적 종결 (self-host 7 + 정정 6 + 신기능 전스택):

| 군 | 항목 | main |
|---|------|------|
| self-host fixpoint 7 | #23 index_set · #24 loop-sentinel · #25 match-as-expr · #26 MFunc-arena · #27 call-overflow stride · #28 enum-eq · #29 bitwise-as-add | …`93ee4ecf` |
| codegen 정정 | atlas-verifier(index_of+bool-tag) · 메모리 builtin ×14 · @link/extern+*T 파서 · int↔float typecheck · math annotations · void-call type_of | …`63d2511c` |
| 신기능 전스택 | try/catch/throw · closure C1+C2+C3+capture-scope | `8f45d3d3`·`c5c3e9f8`·`f4f1225e` |

- **★ BIT-STABLE SELF-HOST FIXPOINT**: `ap1f → flat → ap2f → flat → ap3f`,
  `ap1f.s == ap2f.s == ap3f.s` byte-identical. aprime_cc 가 인터프리터·hexa_v2 없이
  자기 자신을 bit-for-bit 재현 (전 cycle 보존 재검증, 최신 253,049 lines).
- **gate ① 38/44**. 잔여 6 non-MATCH 는 **100% non-tier-1**:
  - `atlas_verify` — tier-2 codegen 잔여 발산 (tier-1 8/8 PASS; 별도 작업)
  - `t35`·`t36`·`t37` — ORAFAIL-class (tier-2 oracle 자체가 빌드/실행 실패: FFI dlsym·clang)
  - `repo_taxonomy_audit`·`t34_net_listen` — env-resource (OOM·socket)
  → tier-2 가 정확히 처리하는 모든 .hexa 를 tier-1 도 정확히 처리. **tier-1 codegen
    gap = 0.**
- **R7 deletion gate**: ②(CLI compiled) ③(atlas SIGSEGV) ④(module_loader interp-free)
  ✅ · ①(coverage ≥ interp) — tier-1 codegen gap 0 이므로 사실상 충족. 인터프리터 소스
  실삭제만 잔여 (`@D g_interp_deprecated`).

> 이 GOAL 은 north-star — self-host 축 + tier-1 codegen-correctness 축 모두 측정으로
> CLOSED (fixpoint byte-identical · gate ① 38/44, 잔여 전부 non-tier-1). "인터프리터
> 폐기" 의 마지막 = 인터프리터 소스 실삭제 (R7), hard-to-reverse 라 user 확인 후 실행.
> 측정값 SSOT 는 `compiler/PLAN.md`.

---

## cross-link

- `AGENTS.tape` — `@D g_interp_deprecated` (R7 4-gate spec) · `@D g5 hexa-native-only` · `@D g_plan_consolidation` (PLAN 단일 SSOT)
- `compiler/PLAN.md` — compile cycle 진행 로그 SSOT (self-host fixpoint·gate ① 측정값의 거리 기록)
- `ROADMAP.md` — R3–R7 phased plan (R7 = 인터프리터 실삭제)
- `HEXA-NATIVE-ONLY.md` — no LLVM · no C-transpile · self-hosted 정책
- `tool/build_aprime.sh` — aprime_cc 5-stage 부트스트랩 recipe (smoke `exit(6*7)==42`)

> GOAL 한 문장은 stable (north-star). 진척·측정값은 `compiler/PLAN.md` 가 SSOT — 본 파일은 "왜" 의 SSOT.
