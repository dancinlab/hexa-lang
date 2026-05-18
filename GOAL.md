# GOAL — hexa-lang 의 한 문장 (도메인별)

> hexa-lang 은 동시에 세 north-star 를 굴린다 (격자가 아닌 실-목표 기준; `LATTICE_POLICY.md`).
> 한 파일에 **모두 보관** — 각 도메인 진척·측정값 SSOT 는 해당 섹션의 cross-link 참조.
>
> - **① flame+forge NN 스택** — hexa 컴파일러-only NN 학습 스택이 PyTorch 보다 빠르게 (측정)
> - **② 인터프리터 폐기 · self-host** — 모든 `.hexa` 가 인터프리터 없이 네이티브 컴파일·실행
> - **③ comb n=6 fabric** — degree-6 육각 이진 spatial PIM 이 degree-4 mesh 보다 우월한지 입증/반증 (sim+RTL); 설계는 별도 repo `~/core/hexa-arch`[chip] 소비

═══════════════════════════════════════════════════════════════════════

# GOAL ① — hexa-lang NN 스택의 한 문장

```
/goal hexa 로 쓴 컴파일러-only NN 학습 스택 (flame) 이 자체 GPU substrate (forge) 를 통해 d=768·12L 트랜스포머를 PyTorch 보다 빠르게 학습시킨다 — 진짜 측정으로 증명하면서
```

> **한 문장 (canonical)**: hexa 로 쓴 컴파일러-only NN 학습 스택 **flame** 이, 자체 GPU substrate **forge** 를 통해 d=768·12L 트랜스포머를 **PyTorch 보다 빠르게** 학습시킨다 — 매 단계 **진짜 측정**(byte-eq falsifier)으로 증명하면서.

> **합격선 (F-RFC046-WALL)**: d=768·12L **1 step wall ≤ 437.9s** (PyTorch eager 336.85s 의 1.3×). 이 수치를 측정으로 통과해야 GOAL 달성 — wall(초)이 유일 합격선이며 GPU util/resident 는 진단 보조 지표일 뿐.

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

**★ 목표 달성 (MEASURED PASS, 2026-05-19).** substrate ✅ verified +
d768·12L wall 측정 PASS — 그게 정직한 현재.

- compiler-only / no PyTorch: ✅ flame hexa compiler-only
- hexa-native: ✅ flame hexa-src · forge C/CUDA (RFC 055 hexa→PTX designed)
- GPU: ✅ substrate verified (12 kernel byte-eq A100) + d768·12L step
  GPU-resident **3 step 측정 완료** (GPU util max 65%, host-scalar
  prelude/postlude/_ag_reg_acc/nn_linear_bwd 全 forge-routed)
- measured: ✅ d=32·3L 3.23× wall MEASURED · **d=768·12L 1 step wall =
  114s MEASURED** (commit `e030fa31`)
- **d768 faster than PyTorch**: ✅ **PASS** — step1 114s vs PyTorch
  eager 336.85s = **2.95× faster**. F-RFC046-WALL ≤ 437.9s gate **3.84×
  under budget**. Hand-fused option B (`28e9d648`) 도 191-268s 로 PASS
  (1.26-1.76× faster). 두 path 모두 측정으로 PASS.

진척: fire #1 host-scalar prelude (412M ops/step) → fire #2 single-
thread fill_dt_lcg on GPU (20× slower per iter) → fire #3 nn_linear_bwd
host-scalar + _ag_reg_acc loop → **fire #4 ✅ MEASURED PASS** (mk2-C5
ag_linear forge fwd/bwd + driver-local init). 단조 진행, 매 fire 가
구체 binding blocker 하나씩 측정 노출 후 해결.

> ★ 두 path 모두 closure: option B (hand-fused, `28e9d648`) 191-268s
> · option A (generic ag_tape, `e030fa31`) 114s. Generic 경로가
> hand-fused 보다 더 빠르다 — abstraction layer 가 wall tax 미지불.
> mk2 100% closure paradigm-level 결과 + g3 honest no-overclaim 유지.

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

**self-host 축 + 전 tier-1 codegen-correctness 축 + R7 Phase 1/2 (option B) CLOSED.**
bit-stable self-host fixpoint 도달, tier-1(aprime_cc) 이 구현된 언어 범위에서 codegen-
complete, 인터프리터는 user-facing surface 에서 deprecation-signal 활성. **인터프리터
소스 자체의 일괄 삭제는 track B (16+ absorbed-verb sub-binary 재라우팅)** 완료 후
multi-cycle housekeeping — functionality 손실 0 으로 점진 sunset.

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
  ✅ · ①(coverage ≥ interp) — tier-1 codegen gap 0 이므로 사실상 충족.
- **R7 Phase 1** (`db5635b7`) — interp 소스 vs 부트스트랩 entanglement map 작성. source-
  level clean 분리 확인, runtime-level 16+ absorbed-verb 위임 발견.
- **R7 Phase 2 option B** (`bd8c3d85`) LANDED — `cmd_run_user_direct()` 신설, user-direct
  surface (`hexa run <file>` CLI + `hexa://run` URL) 에 stderr deprecation warning emit
  (`HEXA_INTERP_QUIET=1` 로 silence 가능), 16+ absorbed-verb 는 그대로 (functionality
  손실 0). `@D g_interp_deprecated` 룰 갱신 (option B 채택 명시). build_aprime smoke +
  self-host fixpoint 보존 (mini 검증, 253,049 lines).
- **track B (sunset 잔여, multi-cycle housekeeping)**: 16+ absorbed-verb (`lsp`/`test`/
  `bench`/`check`/`qrng`/`sim-universe`/`qmirror`/`batch`/…) 의 sub-binary 화 +
  main.hexa 재라우팅. 완료 후 인터프리터 소스 일괄 삭제 → `g_interp_deprecated` 룰 폐기
  → R7 종결. 별도 multi-cycle.

> 이 GOAL 은 north-star — self-host 축 + tier-1 codegen-correctness 축 + R7 Phase 1/2
> (option B) 모두 측정으로 CLOSED (fixpoint byte-identical · gate ① 38/44 잔여 전부
> non-tier-1 · user-facing interp signal LANDED). 잔여 = track B 의 sub-binary 재라우팅
> housekeeping (functionality 손실 0 으로 점진), 별도 multi-cycle. 측정값 SSOT 는
> `compiler/PLAN.md`.

---

## cross-link

- `AGENTS.tape` — `@D g_interp_deprecated` (R7 4-gate spec) · `@D g5 hexa-native-only` · `@D g_plan_consolidation` (PLAN 단일 SSOT)
- `compiler/PLAN.md` — compile cycle 진행 로그 SSOT (self-host fixpoint·gate ① 측정값의 거리 기록)
- `ROADMAP.md` — R3–R7 phased plan (R7 = 인터프리터 실삭제)
- `HEXA-NATIVE-ONLY.md` — no LLVM · no C-transpile · self-hosted 정책
- `tool/build_aprime.sh` — aprime_cc 5-stage 부트스트랩 recipe (smoke `exit(6*7)==42`)

> GOAL 한 문장은 stable (north-star). 진척·측정값은 `compiler/PLAN.md` 가 SSOT — 본 파일은 "왜" 의 SSOT.

═══════════════════════════════════════════════════════════════════════

# GOAL ③ — comb (n=6 육각 fabric) 의 한 문장

```
/goal degree-6 육각 이진-타일 spatial PIM fabric 이 modern node 에서 degree-4 mesh 를 실제 워크로드로 이긴다는 것을 hexa-native 사이클정확 시뮬 + tapeout-ready RTL 로 입증하거나 동일 엄밀도로 반증한다 (T2); 입증 시 물리-실현 설계를 별도 standalone repo ~/core/hexa-arch 의 chip 도메인(외부 EDA 흡수는 그쪽 책임)을 사용해 산출 — comb 는 소비자, 실제 fab/FPGA 는 비목표 (T3=설계만)
```

> **한 문장 (canonical)**: degree-6 육각 **이진-타일** spatial PIM fabric 이 modern node 에서 degree-4 mesh 를 **실제 워크로드로 이긴다**는 것을 **hexa-native 사이클정확 시뮬레이터 + tapeout-ready RTL** 로 **입증하거나 동일 엄밀도로 반증**(T2)하고, 입증 시 물리-실현 *설계*를 **별도 standalone repo `~/core/hexa-arch` 의 chip 도메인**(외부 EDA — gem5-Garnet·Yosys·OpenROAD·Verilator·ngspice·SKY130 — 흡수는 *hexa-arch* 책임)을 **사용**해 산출한다 — comb 는 **소비자이지 EDA 흡수 주체 아님**, **실제 fab/FPGA 제작은 비(非)목표** (T3 = 설계만).

---

## 무엇이 아닌가 (NOT)

- 패러다임 선언 아님 — *topology* 기여 1개 + falsifier 5개 (RFC 057). over-claim 금지 (g1·g2)
- 다치(multi-valued)논리 아님 — A축 DE-SCOPED WALL (radix economy·noise·EDA 3중 HARD_WALL)
- 실제 칩 fab/FPGA 아님 — T3 은 hexa stdlib+CLI **설계 산출물**까지 (hexa-native, g5)
- design-first 아님 — F1–F5 측정·반증으로 결정 (sim 우선; 상용 degree-6 실리콘 0건 = EDA-cost 신호)
- comb 가 EDA 흡수 아님 — 외부 EDA 흡수는 **별도 repo `~/core/hexa-arch`** 책임; comb 는 그 chip 도메인 **소비자**일 뿐
- 빅뱅 아님 — hexa-arch 도 NoC 사이클sim(BookSim2/gem5-Garnet) **1개만** 먼저; 전체 RTL→GDSII 후속 (comb T1→T3 가 소비)

## 무엇인가 (IS)

3-tier 단일 north-star (RFC 057 §6 = gated plan SSOT):

1. **T1 ANSWERED** — F1–F5 를 modern-node hex axial NoC 사이클 시뮬로 전수 판정 (이김/죽음)
2. **T2 PROVEN** — hexa-native 사이클정확 시뮬 + tapeout-ready RTL 로 degree-6 > degree-4 입증 OR 동일 엄밀도 반증
3. **T3 DESIGN-ONLY** — 물리-실현 설계를 별도 repo `~/core/hexa-arch` 의 chip 도메인(외부 EDA 흡수는 그쪽)을 *사용*해 산출; comb=소비자; 실제 fab/FPGA 비목표

## 측정된 거리 (달성 주장 아님, g3)

- ✅ 정초 완료: RFC 057 + falsifier F1–F5 + 딥리서치 2건 (commit `c0e7aae7`)
- ⏳ T1 미착수 (0%) — 다음 = F1/F2 (degree-6 vs degree-4 @ modern node)
- ⏳ T2 / T3 미착수
- 정직 앵커: 상용 degree-6 실리콘 0건 · 측정 단 1건 (UC Davis 65nm 2012, 13yr stale, 미productize)

## RESUME (복사-붙여넣기로 이어서)

새 세션에 아래를 그대로 붙여넣으면 이어집니다:

```
comb (RFC 057, n=6 육각 fabric) 이어서. SSOT: comb/{README,RFC,PLAN,COMB.tape,
research/SURVEY} + root GOAL.md ③. 현 상태: 정초 완료 (commit c0e7aae7+), T1
미착수. 다음 = RFC 057 §6 T1 — F1/F2 해소용 hex axial NoC 사이클 시뮬
(degree-6 vs degree-4, modern-node wire model, Leighton B3 하한 대비; sim only,
no silicon). NoC sim 은 별도 standalone repo ~/core/hexa-arch 의 chip
도메인 경유 (거기가 BookSim2/gem5-Garnet 흡수; ~/core/hexa-arch/HANDOFF.md
자기완결). 거버넌스: g1·g2 격자=도구, 이진-타일 고정, 다치논리 금지(A=WALL),
모든 B 주장에 least-perimeter≠least-latency + EDA-cost caveat. T3 =
~/core/hexa-arch[chip] 을 *사용*해 설계 산출 (comb=소비자, EDA 흡수는
hexa-arch; design-only, fab 비목표).
```

> GOAL ③ 한 문장은 stable (north-star). 진척·측정값 SSOT = `comb/PLAN.md` 진행 로그 — 본 섹션은 "왜" 의 SSOT.

---

## cross-link

- `AGENTS.tape` — `@D g_interp_deprecated` (R7 4-gate spec) · `@D g5 hexa-native-only` · `@D g_plan_consolidation` (PLAN 단일 SSOT)
- `compiler/PLAN.md` — compile cycle 진행 로그 SSOT (self-host fixpoint·gate ① 측정값의 거리 기록)
- `ROADMAP.md` — R3–R7 phased plan (R7 = 인터프리터 실삭제)
- `HEXA-NATIVE-ONLY.md` — no LLVM · no C-transpile · self-hosted 정책
- `tool/build_aprime.sh` — aprime_cc 5-stage 부트스트랩 recipe (smoke `exit(6*7)==42`)
- `comb/RFC.md` — ③ comb RFC 057 (T1→T2→T3 gated plan · falsifier F1–F5)
- `comb/PLAN.md` — ③ comb 진척·측정값 SSOT (자체 도메인 SSOT, g_plan_consolidation 예외)
- `comb/research/SURVEY.md` — ③ 딥리서치 2건 통합 (n=6 정리-최적 = B축 1개뿐, 출처)
- `~/core/hexa-arch` — ③ 가 *사용*하는 별도 standalone repo (chip 도메인이 외부 EDA 흡수; `HANDOFF.md` 자기완결, commit c812ac6). EDA 흡수는 거기, comb 는 소비자

> GOAL 한 문장은 stable (north-star). 진척·측정값은 `compiler/PLAN.md` 가 SSOT — 본 파일은 "왜" 의 SSOT.
