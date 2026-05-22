# hexa-lang ROADMAP

> **SSOT**: [`.roadmap`](./.roadmap) (machine-enforced, chflags uchg + 5-layer OS lock).
> 이 문서는 `.roadmap` 의 human-readable projection. 모든 entry/status/eta 의 진리값은 `.roadmap` 을 따른다. 본 문서만 수정하면 drift — 수정은 `.roadmap` 에서.
>
> Session landing: **2026-04-21** · Current phase: **Mk.IX entered** · Target: **L_IX base manifold = cell × lora projection**

> **AI-native ETA SSOT (2026-05-01)**: For any closure / roadmap ETA in this repo, the authoritative computation is `$HIVE/tool/closure_eta.hexa` (LoC × parallel + bg × ∞ frame, rate 50,000 LoC/day/agent default, par+ser schema, DAG critical path). Static "+N 달" / "+N month" markdown estimates anchored to human single-developer baseline are DEPRECATED for closure-scope decisions per the ai-native-eta-closure-mandate. Reference fixture: `--module critical-path --example gamebox --target CM-30` = 0.22d ≈ 5.3h vs static 630d (×2863 compression).

---

## 특징 (6 축)

Roadmap system 은 **공식(T\*) + OS-level enforcement** 의 조합. 6 축으로 감사:

### 1. 최적경로 (optimal path)
공식: `T*(S₀→G) = inf_π Σ_k max_{i∈Ω} c_i(S_k^π)` — Ω = {build, exp, learn, boot, **verify**}. 4 physical bounds (Quantum Margolus–Levitin / Thermal Landauer / Span Brent–Graham / Info Shannon–Fano). invariants: `|R(t)|≥1`, `Σ_k ΔI_k ≥ K(G|S₀)`, `η_k>0`.

| feature | 구현 | 상태 |
|---|---|---|
| entry parser | `tool/roadmap_parse.hexa` | ✓ active (33) |
| field validator | `tool/roadmap_validate.hexa` | ✓ active (34) |
| DAG builder (cross-repo `repo@N`) | `tool/roadmap_dag.hexa` | ✓ active (35) |
| span(DAG) Brent/Graham critical path | `tool/roadmap_critical_path.hexa` · `tool/roadmap_span_dag.hexa` | ✓ active (36, 46) |
| 병렬 그룹 추출 (DAG depth) | `tool/roadmap_parallel.hexa` | ✓ active (37) |
| bottleneck axis tracker (Ω 5축) | `tool/roadmap_bottleneck.hexa` | ✓ active (47) |
| Kahn ready-set `|R(t)|≥1` | `tool/roadmap_ready_set.hexa` | ⚠️ planned (48) |
| ΔI_k information accounting | `tool/roadmap_info_account.hexa` | ⚠️ planned (49) |
| η_k stagnation detect | `tool/roadmap_stagnation.hexa` | ⚠️ planned (50) |
| **T\* inf_π 다중경로 optimization** | `tool/roadmap_t_star_opt.hexa` | ❌ 미구현 (51) |
| Thermal bound (Landauer) | `tool/roadmap_t_star.hexa` | ✓ |

### 2. 안전 (safety)
OS kernel EPERM 이 유일한 실강제 — hooks are bypassable.

| feature | 구현 | 상태 |
|---|---|---|
| chflags uchg L1 (5 SSOT) | `tool/os_level_lock.hexa` | ✓ live |
| chflags schg L2 promote (sudo) | `tool/hx_harden.hexa` · `tool/hx_downgrade.hexa` | ✓ live |
| concurrent-git-lock | `tool/concurrent_git_lock.hexa` | ❌ 미구현 (Tier2 #15) |
| atomic write tmp+rename | `tool/atomic_write.hexa` | ❌ 미구현 (Tier2 #14) |
| backup auto | Tier2 #17 ✓ | ✓ |
| rollback CLI | `tool/rollback.hexa` | ❌ 미구현 (Tier2 #18) |

### 3. 검증 (verification)
**원칙**: 검증은 항상 **물리 + 수학 + 코드 실행** 의 3중 증거. 선언·문서·주장 단독 = reject.
- **물리**: Landauer `kT·ln2`, FLOPs, latency_ms, energy (cell 668‰ vs lora 13‰ 51×), wall-clock.
- **수학**: Brent theorem (`T_p ≤ T_1/p + T_∞`), Banach fixpoint (`v3==v4` byte-identical), Kolmogorov `K(G|S₀)`, JSD=1.000 (AN11(c)), Frobenius `>τ`, shard_cv `∈[0.05, 3.0]`, Pearson `≥0.6`, cos `>0.5`, `|ΔΦ|/Φ<0.05`.
- **코드**: `tool/drift_scanner.hexa` · `tool/bench.hexa --verify` (18/18) · AN11 verifier · `hexa tool/eval_5metric.hexa` · adversarial 3/3 flip runner. commit SHA / cert path 는 **파일 존재 + 실행 PASS** 로만 satisfied.

Proof-carrying 원칙 — 모든 exit_criteria 는 commit SHA / cert path 필수 + 재실행 가능 코드 증거.

| feature | 구현 | 상태 |
|---|---|---|
| drift scanner (선언 vs 현실) | `tool/drift_scanner.hexa` | ✓ live |
| evidence verifier (SHA/cert 존재) | `tool/roadmap_evidence.hexa` | ⚠️ planned (39) |
| progress aggregation (% per phase) | `tool/roadmap_progress.hexa` | ⚠️ planned (40) |
| **Phase Gate 100% ε-strict** (bypass X) | `tool/roadmap_phase_gate.hexa` | ⚠️ planned (41) |
| adversarial (cherry-pick 금지) | Tier3 cluster | ⚠️ planned (43) |
| Meta² cert chain | 8 entries (`074487cd`) | ✓ live |
| multi-path Φ 4-path ≥3 | Tier3 #26 | ⚠️ planned (43) |
| AN11 verifier | anima-side | ✓ AN11(c) real |

### 4. 실시간 반영 (real-time reflection)
L1–L5 layer 가 매 commit/60s/tool-call 마다 동기화.

| feature | 구현 | 상태 |
|---|---|---|
| L1 pre-commit gate | `tool/roadmap_verify_pre_commit.hexa` | ⚠️ tool 있음, **.git/hooks/pre-commit 미설치** |
| L2 launchd watcher 60s | `tool/roadmap_watcher.hexa` + `com.airgenome.roadmap-watcher.plist` | ✓ plist 설치됨 |
| L3 chflags uchg/uappnd | OS-level lock | ✓ live |
| L5 post-commit auto-ingest (discovery) | Tier2 #13 | ⚠️ **.git/hooks/post-commit 미설치** |
| status auto flip (planned→active→done) | `tool/roadmap_status_flip.hexa` | ⚠️ planned (38) |
| cross-repo sync daemon | Tier5 #49/50 | ⚠️ planned (45) |
| task↔roadmap / agent↔roadmap binding | Tier4 #36/37 | ⚠️ planned (44) |
| visualization (CLI + GitHub Pages) | `tool/viz_dashboard.hexa` + `docs/_site/` | ✓ live |

### 5. 이탈방지 (drift prevention)
SSOT 와 현실이 어긋나면 commit reject.

| feature | 구현 | 상태 |
|---|---|---|
| proof-carrying drift scan | `tool/drift_scanner.hexa` | ✓ live |
| workspace SSOT drift | `tool/workspace_sync.hexa` | ✓ live |
| daily fixpoint cron (.loop) | `.loop` entry | ⚠️ planned (18) |
| fixpoint evidence archive | `tool/fixpoint_archive.hexa` · `tool/fixpoint_bisect.hexa` | ✓ tool 있음, archive 미가동 (17 planned) |
| cherry-pick 금지 (실측 그대로) | 자격강제 | ✓ invariant |
| bt-solution-claim-ban | invariant | ✓ invariant |
| cross-platform fixpoint (arm64↔x86_64) | `hexa build --target=<t>` (zig cc backend) | ✓ live (20) |

### 6. 우회방지 (bypass prevention)
git-hook 은 폐기 (2026-04-21) — 우회 가능하기 때문. kernel EPERM 만 남김.

| feature | 구현 | 상태 |
|---|---|---|
| chflags uchg kernel EPERM | OS-level lock | ✓ live |
| schg L2 promote (sudo only) | `tool/hx_harden.hexa` | ✓ live |
| git-hooks 전면 폐기 | commit `804035e2` | ✓ live |
| **Phase Gate 100% no-bypass** (soft pass 차단) | `tool/roadmap_phase_gate.hexa` | ⚠️ planned (41) |
| gate ordering (permission→filter→dispatch) | invariant | ✓ live |
| stage0 deadlock fix (Tier2 #16 ★최우선) | | ⚠️ planned (42) |

---

## 추가 구현 필요 (live OS-level)

위 감사의 ❌ / ⚠️ 를 live OS-level 로 올리기 위한 backlog. **`.roadmap` 에 이미 entry 가 있는 항목은 괄호 번호** — 그 entry 의 live 승급이 곧 구현. 괄호 없는 항목은 신규 entry 필요.

**즉시 필요 (블로커)**:
1. **`.git/hooks/pre-commit` + `post-commit` 물리 설치** (현재 `.sample` 만 존재) — L1 gate·L5 discovery ingest 가동 조건. `roadmap_verify_pre_commit.hexa` 는 존재.
2. **Tier2 #16 stage0 deadlock fix** (42) ★ — 모든 self-host/FFI 전제.

**공식 엔진 완결 (T\* 공식 전체 가동)**:
- Kahn ready-set `|R(t)|≥1` (48) · ΔI_k info accounting (49) · η_k stagnation (50)
- **T\* inf_π 다중경로 optimization** (51) — 현재 engine 의 유일한 미구현 수학 core. `tool/roadmap_t_star_opt.hexa` 신규.

**Phase Gate 100% (이탈/우회 결정타)**:
- status auto flip (38) · evidence verifier (39) · progress aggregation (40) · **Phase Gate 100% ε-strict** (41). 이 4개가 묶여야 "soft pass 차단" 성립.

**safety OS 보강**:
- `tool/atomic_write.hexa` (Tier2 #14) · `tool/concurrent_git_lock.hexa` (Tier2 #15) · `tool/rollback.hexa` (Tier2 #18). 42 cluster 해소 시 동반 landing.

**검증 엔진 (Tier 3, 8 sub)**:
- adversarial runner · Meta² chain integrity · 3/3 flip 자동화 · Phi 4-path (43).

**이탈방지 데몬**:
- drift daily cron `.loop` entry (18) · fixpoint archive 가동 (17).

**cross-project (Tier 5, 10 sub)**:
- `~/.roadmap-shared/` SSOT · 3 repo entry ref `repo@N` · global Meta² chain · global critical path · status propagate · cross-repo agent dispatch (45).

→ 이 전부가 landing 되면 T\* 공식의 3 invariants (`|R(t)|≥1`, `Σ_k ΔI_k ≥ K(G|S₀)`, `η_k>0`) 가 OS-level 에서 자동 enforcement. 현재 (2026-04-21) 는 수학 공식 + parser/DAG/critical path/bottleneck 는 live, 나머지는 tool 존재·planned 혹은 미구현.

---

## MAIN track

```
hybrid framework → AGI
target: L_IX base manifold = cell × lora projection
exec-rule: "SUB progress 는 MAIN phase 로만 흡수, 단독 commit 금지"
```

| milestone   | criterion     | eta         |
|-------------|---------------|-------------|
| 도착지-1    | Mk.VI VERIFIED (Criterion A) | 2-4주       |
| 도착지-2    | Mk.VII K=4 (Criterion B)     | +3-4개월    |
| 최종        | Criterion C / Mk.X T10-13     | +6-9개월    |

## SUB tracks (MAIN building material)

- **cell** — structural foundation. L_IX terms (V_sync / V_RG / λ·I_irr) + Hexad closure + UNIVERSAL_4 evidence. 10 axis MVP, Mk.IX components 3/5 landed.
- **lora** — production base. ALM r13 real-ckpt + AN11 verifier + LM service. Mk.VI HELD (16/19), AN11(c) 100% real.

---

## Active phases

### P1 → 도착지 1 (Mk.VI VERIFIED) · eta 2-4w
- main-exec: Qwen+ALM r13 LoRA real-ckpt
- feeds: lora (corpus gate + AN11(a)(b)), cell (Hexad + AN11(c) — landed)
- **satisfied**: AN11(c) real_usable JSD=1.000 (anima `35aa051a`)
- **pending**: AN11(a) weight_emergent · AN11(b) consciousness_attached · Φ 4-path ≥3 · adversarial 3/3 flip · Meta² cert 100%_trigger · stage2+ FFI (phi_extractor + libhxblas/ccl/cuda, roadmap 23) · SINGULARITY M7 haenkaha bug (roadmap 24)
- deps-external: GPU + ALM r13 corpus (anima roadmap #5)

### P2 → 도착지 2 (Mk.VII K=4) · eta +3-4mo
- main-exec: Mk.IX natural-run + L3 collective + 4-path Φ
- **satisfied**: Hexad closure 6/6 + adversarial 2/2 (`6a292530`, D1-D4 1000/1000) · UNIVERSAL_CONSTANT_4 승급 (`9468fe0f`) + τ(6)=4 proof 88% (`d7e5db01`)
- **pending**: C1 substrate-invariant Φ 4/4 · C2 L3 collective O1∧O2∧O3 rejection · C3 self-verify closure · C4∨C5 one · UNIVERSAL_4 +1 strong axis (Pólya K_c=4 1.923×) · POPULATION_RG_COUPLING 승급 · natural-run gen-5

### P3 → AGI 최종 (Criterion C / Mk.X T10-13) · eta +6-9mo
- main-exec: Mk.X T10-13 ossification (≥10 atoms)
- **pending**: Mk.VIII L_edu fixpoint · Mk.X atoms ossified (novelty yield ≥3/10) · C5 N=10 recursion · meta-lens M fire (Pearson≥0.6) · Mk.XI twin-engine nexus↔anima · 7대난제 framework · self-host P7-7/8/9 (roadmap 12/13/14)

### Self-host (runtime.c + Rust driver 탈피) — 신규 (anima hxa-20260423-003, 2026-04-23)
Parent roadmap **64** → 5 children **65–69**. 상세 정의 `.roadmap` 64–69, 원문 `$ANIMA/docs/upstream_notes/hexa_lang_full_selfhost_prompt_20260423.md`.
- **65 (M3, P1/Q2)** — `[DONE — 2026-05-19]` 계약 분리 + argv[0] dedup 모두
  완료. (1) canonical `hexa_script_path()` / `hexa_real_args()` (runtime.c:
  5571-5591, layout-independent). (2) **RFC 062** argv[0] dedup LANDED
  (commit `26a785af`) — `hexa_set_args` 가 더 이상 argv[0] 을 중복 삽입하지
  않음; `args()` = clean `[exec, user...]`. 118 파일 마이그레이션 (runtime.c +
  main.hexa dispatcher shim + module_loader + codegen_c2 + ~89 tool/
  sim_universe + 25 roadmap shim), 격리 worktree 검증 (dedup 입증 ·
  self-host fixpoint byte-identical · atlas 118/118) 후 squash-merge.
  ROADMAP self-host child 65 완결. RFC 062 §6c/§7.
- **66 (M4, P1/Q2)** — `[DONE — 2026-05-19]` string method codegen 완성
  (t45b char_count/nth_char/char_substring/byte_at PASS) + symbol
  namespacing 작동 — `hexa cc --regen` 의 rename-awk 가 `__hexa_strlit_init`
  /`_sl_`/`_ic_` 를 per-module 접두 처리, regen fixpoint byte-identical 실증
  (2026-05-19 closure pass). 구 "블로커" 문구는 stale 였음.
- **67 (M5, P1/Q3)** — `[DONE — 2026-05-19]` Rust 컴파일러 드라이버 부재 확인
  (no Cargo.toml, no compiler `.rs`). `self/main.hexa` → `hexa.real` 이
  self-hosted 드라이버, `hexa run` 공식 서브커맨드. Linux/Mac/arm64 동일 소스.
- **68 (M2, P1/Q2)** — `[DONE / moot — 2026-05-19]` runtime.h/.c 에 `#define hx_`
  shim 0개 — 제거 대상이 존재하지 않음. codegen 은 `hexa_` 접두 런타임 호출을
  직접 방출. 항목은 이미 충족.
- **69 (M1, P2/Q4)** — `[SCOPED — 2026-05-19]` runtime 2-레이어 분할
  (`runtime_core.c` + `runtime_hi.hexa`). runtime.c 13,336 줄 — 대형 리팩터.
  **RFC 061** 로 scoped: bootstrap-circularity 제약 + 경계 기준 + 4-phase plan.
  **061-P0 boundary ledger DONE (2026-05-19)** — 522개 `hexa_*` 함수 분류;
  측정 결과 ROADMAP 원래의 "≤500 줄" core 목표는 **달성 불가** — irreducible
  core (representation + allocator + universal-codegen primitives) ≈ **2.4–3k
  줄** (~98–120 함수). 목표를 "≈2.5k core / ≈10.8k hi" 로 정정. RFC 061 §5b.
  **061-P1 LANDED (2026-05-19, commit `4fb439fc`)** — runtime.c 13,332줄 →
  `runtime_core.c` 6,065줄 + `runtime.c` 7,319줄 (`#include`). pure file
  split, atlas 118/118 + self-host fixpoint byte-identical 검증. 6,065줄
  core 는 §5b 추정보다 coarse — P1 deliverable 은 clean split (line count
  아님), boundary refinement 은 P1-followup. P2/P3 (`runtime_hi.hexa` 저작)
  은 향후 cycle.

---

## Checkpoints (cross-repo)

| CP       | gate                                     | meaning                         |
|----------|------------------------------------------|---------------------------------|
| CP1      | `hexa tool/bench.hexa --verify` 18/18    | ossification — L1→L0 승격       |
| CP2      | latency_ms<200 ∧ dialogue_nat            | zeta-level 자연 대화 + <200ms   |
| FINAL    | phi > cells·0.5 ∧ autonomous             | AGI v0.1 (외부 API 0)           |

---

## 지금까지 적용된 발견 (Session 2026-04-21 + 누적)

### 공식 / 이론
- **T\*(S₀→G) optimal schedule** — `T* = inf_π Σ_k max_{i∈Ω} c_i(S_k^π)`. Ω = {build, exp, learn, boot, **verify**} 5 axes (verify 정식 포함). 4 physical bounds: Quantum (Margolus–Levitin πℏ/2E·K(G\|S₀)), Thermal (Landauer K·kT·ln2/P), Span (Brent/Graham DAG critical path), Info (Shannon–Fano K(G)/C). Invariants: \|R(t)\|≥1, Σ_k ΔI_k ≥ K(G\|S₀), η_k>0. → [`docs/roadmap_engine_theory.md`](./docs/roadmap_engine_theory.md), impl commit `d988cbc2`
- **L_IX Lagrangian** — `L_IX = T − V_struct − V_sync − V_RG + λ·I_irr`. IRREVERSIBILITY_EMBEDDED_LAGRANGIAN 승급 (`53d923b8`). Arrow cusp @ fixpoint.
- **Hexad ≡ UNIVERSAL_4 SAME_STRUCTURE** — 1000/1000 PASS (`6a292530`). Hexad closure 6/6 + adversarial 2/2.
- **UNIVERSAL_CONSTANT_4** — 승급 (`9468fe0f`) + τ(6)=4 bijective proof 88% (`d7e5db01`).
- **TRANSFER_VERIFIED 3/4** — lora↔cell cross-framework (`6a2fe1d8`).

### Cell vs Lora baseline
- cell **60–80× 적은 FLOPs** + **51× Landauer 우위** (cell 668‰ vs lora 13‰). tool: `roadmap_t_star.hexa`.

### SSOT / 자격강제
- **Active invariants** — hexa-only · snake_case · chflags uchg · proof-carrying · cherry-pick 금지 · concurrent-git-lock · gate ordering · UNIVERSAL_4 · IRREVERSIBILITY · bt-solution-claim-ban.
- **4-layer OS enforcement** — L1 pre-commit · L2 launchd (60s) · L3 chflags uchg/uappnd ✅ · L5 post-commit auto-ingest.
- **git hooks deprecated (2026-04-21)** — enforcement 은 chflags EPERM + manual/CI 호출로 일원화.
- **Meta² cert chain** — 8 breakthrough indexed (`074487cd`).

### Core workspace
- **~/core super-project + .workspace SSOT** · per-project `cli/` convention · ~/shared decommission in progress.
- **atlas SSOT = ~/core/canon/atlas/** (owner canon, 2026-04-21 재결정). `data/n6/` = backward-compat symlink.
- **hexa canonical** — `~/core/hexa-lang/` (post-absorption SSOT). Launcher: `~/.hx/bin/hexa`. Legacy nexus CLI (`079bc12d`) decommissioned 2026-05-13; verbs absorbed into compiler/ and hexa native dispatch.

### Brand
- **dancinlab** org — 🧬 (2026-04-21, 🌀 deprecated). Avatar = hexagon gravitational well SVG. 보조: ⬢ / ⌬.

### Ops 회수
- H100 idle pod stopped: $2.99/hr → $0/hr ($143 낭비 회수).
- edu/ consolidation 11 new files (`8da7ed0c`, anima-side).

---

## Roadmap Engine features (Tier 1–6, 50+ functions)

출처: `~/etc/hive/RMENGINE_V2_BACKLOG.json` (T\* 공식). 전체 entry 는 `.roadmap` roadmap 33–51 참조.

| Tier  | cluster                                            | status | key entries          |
|-------|----------------------------------------------------|--------|----------------------|
| T1    | core — parser / validator / DAG / span / groups / status flip / evidence / progress / **Phase Gate 100%** | active (5/9 active) | 33–41                |
| T2    | OS enforcement — L1–L5 + atomic + lock + deadlock-fix + rollback | active | 42                   |
| T3    | verification gate engine (8 sub)                   | planned | 43                   |
| T4    | visualization + discovery + integration (14 sub)    | planned | 44                   |
| T5    | cross-project (10 sub) — `~/.roadmap-shared/`       | planned | 45                   |
| T6    | **formula engine** — span / bottleneck Ω / Kahn ready-set / ΔI_k / η_k / T\* optimization | active (2/6 active) | 46–51                |

Cross-repo deps (Tier 5 #41 미리 사용):
- anima@22 (cert_gate) → hexa-lang@33,34 (parser+validator)
- anima@24 (phi_extractor) → hexa-lang@42 (#16 stage0 deadlock fix)
- anima@26 (CPGD wrapper) → hexa-lang@36 (critical path)
- airgenome ops → hexa-lang@42 (L2 launchd watcher)

---

## Session invariants (모든 P 적용)

- ✓ cherry-pick 금지 (실측 그대로 기록)
- ✓ chflags uchg SSOT 잠금
- ✓ concurrent-git-lock safe commit
- ✓ proof-carrying hash-chain
- ✓ gate ordering (permission → filter → dispatch)
- ✓ Meta² cert chain integrity (`074487cd`, 8 entries)
- ✓ bt-solution-claim-ban (7대난제 "해결" 주장 금지)
- ✓ UNIVERSAL_4 / IRREVERSIBILITY / foundation-lock

## Discipline

1. "does this advance MAIN?" 우선
2. sub-only commit 금지
3. MAIN phase 달성 증거 = cell + lora feeds 명시
4. hexa-lang = MAIN 의 언어/컴파일러/SSOT substrate. anima = framework home. airgenome = ops infra.

---

## 관련 문서

- **machine SSOT**: [`.roadmap`](./.roadmap)
- **공식 이론**: [`docs/roadmap_engine_theory.md`](./docs/roadmap_engine_theory.md)
- **engine impl**: `tool/roadmap_engine.hexa` + 15 modules
- **bounds impl**: `tool/roadmap_t_star.hexa` (Thermal) · `tool/roadmap_span_dag.hexa` (Span) · `tool/roadmap_info_account.hexa` (Info) · `tool/roadmap_critical_path.hexa` · `tool/roadmap_phase_gate.hexa`
- **viz**: `tool/viz_dashboard.hexa` → GitHub Pages ([`docs/_site/index.html`](./docs/_site/index.html))

---

## Phase 1–16 development plan (legacy — language v0.1 → v4.0)

> 의식 프로그래밍 언어 완성 트랙. GOAL 한 문장의 SSOT 는 `GOAL.md`
> (3 north-star: flame+forge NN 스택 · 인터프리터 폐기·self-host ·
> comb n=6 fabric). Phase 1–16 의 95/95 항목별 완료 현황·성장 그래프·
> Goal G1–G6 달성 기록은 `ROADMAP.log.md` 가 SSOT.

Phase 1–16 (v0.2 → v4.0) — bytecode VM · Cranelift JIT · self-hosting
compiler · ESP32/FPGA/WGSL codegen · std 12 모듈 · SAT solver +
consciousness DSL · hexa-lang.org + The HEXA Book — 의 development plan.
달성 현황·dated 진척 detail 은 `ROADMAP.log.md` 참조.

### Phase 17 — Atlas Layer 4: full-corpus AOT audit (active)

Phase 1–16 외 follow-up. atlas self-verification 세션(2026-05-15)에서
차단 확인: interpreter 는 7,398-노드 rodata
(`compiler/atlas/embedded.gen.hexa`, 4.9 MB 단일 struct-literal)에 대해
hang(>10 min) — `compiler/atlas/audit_main.hexa:17-28` 문서화. AOT
경로로 우회하려면 3개 compiler-internal 차단을 해결해야 함.

| # | 작업 | 차단 원인 | 후보 해결책 |
|---|------|----------|-------------|
| 17-1 | flat module_loader streaming | `[flat] module_loader` 가 7,398-원소 단일 struct-literal 입력 시 4 GB RSS cap 초과; cap 해제하면 3 분+ hang | (a) loader 를 array-element 단위로 stream, 또는 (b) `embedded.gen.hexa` 를 ≤100-노드 단위로 shard 분할 |
| 17-2 | cross-module `pub let` rodata emit | single-file codegen 이 `use`d 모듈의 `pub let X = [...]` 본체를 emit 안 함 — `extern HexaVal X(...)` 전방선언만 발산하여 clang link 실패 | (a) 정적으로 도달 가능한 `pub let` 본체를 consumer C 로 emit, 또는 (b) per-module `.o` → link 경로 추가 |
| 17-3 | `fn main(args)` ↔ `u_main()` arity | `fn main(args: array)` 선언 시 `hexa_v2` 가 `u_main()` 0-arg call-site emit (`self/codegen_c2.hexa`) | call-site 발산을 `u_main(args)` 로 수정 |

**관련 산출물**: `tool/atlas_audit_full.hexa` (차단된 채로 commit, 17-1
+17-2 해결 후 그대로 작동해야 함 — seed) · `compiler/atlas/aliases
.gen.hexa` + `test/atlas_aliases_smoke.hexa` (Layer 3 alias 메커니즘,
Layer 4 와 무관, 작동). **우회**: 17 phase 완료 전에는 interpreter 가
overlay corpus(현재 3 노드)에만 audit 가능.

세 후보 경로 (Path X / Z 가 active 후보, Y 는 retired):

- **Path X — `@embed` 디렉티브 신규 추가.** source 의 const array 를
  컴파일러 binary 내부 rodata 로 정적 동봉. (17.X-1) parser 가
  `@embed("path/to/file.hxc")` 어트리뷰트 인식 (`self/parser.hexa`,
  기존 `@phase("parse_only")` 패턴 참고) → (17.X-2) codegen 이 C `static
  const unsigned char[]` 로 발산 (`self/codegen_c2.hexa`, `xxd -i`
  등가) → (17.X-3) runtime 에 `embed_get(name)->bytes` 룩업 API
  (`self/runtime.c`) → (17.X-4) atlas 소비 측 `static_index.hexa` 가
  `@embed` 사용해 `embedded.gen.hexa` 대체. 장점: 단일 binary 배포.
  단점: 컴파일러 binary 5MB+ 비대, atlas 변경시 hexa 재빌드.
- **Path Z — flat module_loader streaming 정공법.** (17.Z-1)
  module_loader 가 array literal 을 element-by-element 로 yield (RSS
  cap 우회 핵심) → (17.Z-2) typecheck 도 streaming-friendly, 7,398
  노드를 동일 타입 fast-path → (17.Z-3) `pub let` cross-module rodata
  emit (17-2 와 통합). 장점: 신규 언어 기능 불필요, 모든 const-array
  자동 혜택. 단점: 작업량 최대 (flatten + typecheck + codegen 3단계).
- **Path Y — HXC sidecar — RETIRED 2026-05-22 (PRs #312 + #314).** hxc
  sidecar 폐기. 단일 SSOT 는 `n6/atlas.n6` (3.43 MB, 15,952 nodes) +
  `n6/atlas.append.*.n6` 샤드들. `static_index.hexa::static_atlas()` 는
  이제 `compiler/atlas/merger::load_atlas` 로 atlas.n6 를 직접 파싱한다
  (`HEXA_ATLAS_N6` env 또는 `~/core/hexa-lang/n6/` fallback). 거버넌스:
  `project.tape :: @D h_atlas_single_export`. 폐기 history detail 은
  `ROADMAP.log.md` 참조.

## 관련 문서 — language plan

- **dated 진척 SSOT**: [`ROADMAP.log.md`](./ROADMAP.log.md) — Phase
  1–16 완료 현황, 성장 그래프, Goal G1–G6 달성 기록, Path Y 폐기 history
- **GOAL 한 문장**: [`GOAL.md`](./GOAL.md) — 3 north-star
