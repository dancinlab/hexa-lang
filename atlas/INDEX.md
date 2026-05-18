# 🗺️ atlas — verification SSOT INDEX

> hexa-lang built-in atlas verdict ledger. anima 의 verdict 검증 기준 (2026-05-15) 을 atlas (compiler/atlas/embedded.gen.hexa ~410 entries) 에 적용.
> Self-verifying closure: atlas 로 들어오는 모든 entry 는 atlas 자체로 검증 (외부 sympy/PyPhi 의존 X) · 필요한 계산 시스템 모두 hexa-native 빌트인.

## 📊 현재 상태 (cycle 001-033, 2026-05-16)

> **139/139 PASS** · 120 🔵 closed (71 SUPPORTED-IDENTITY + 49 SUPPORTED-FORMAL) · 2 🟠 AT-RISK (§5 BIO anima A7 carry + §5 IIT 3.0 surrogate-vs-real Φ carry, cycle 033) · **+15 🟡 SUPPORTED-BY-CITATION literature anchors (cycle 033 — COSMO 5 + PHYS 5 + BIO 5, primary-source arXiv/journal provenance, 9 UNVERIFIED flags reviewer-pending)** · **+13 🔵 sim-universe module absorptions (cycle_038 §3 PHYS — supremacy-frontier · quantum-darwinism · ca-qm · mbs-revival · fock-prethermal-dtc · z2-gauge-prethermal · preheating-analog; +1 honest 🟡 carry)** · **+8 🔵 sim-universe 6-module absorptions (cycle_039 §3 PHYS — ssh-topology ×2 · hofstadter ×2 · dqpt-loschmidt · multipolar-prethermal · surface-code · wdw-minisuperspace)** · **18 falsifier-robust battery (90 falsifiers, 0 fired, sha256-frozen)** · 9 도메인 모두 covered · 13 verifier 모듈 + CI gate.
>
> 3-stage 전부 가동: **Stage 1** symbolic (integer/fraction, foundation/math/top/cosmo/bridges/chem/phys/eng/geo) · **Stage 2** numerical (libm sqrt/log/exp/lgamma + Newton, transcendental) · **Stage 3** cross-meta sibling consistency (cross.hexa, anima W9 hexa-native).
>
> 주요 closure: archive-TECS-L T-proofs (T0/T1/T2 ~17) · T2-01 χ→Monster **full 8-step chain** (modular.hexa) · §5 BIO **IIT closure ladder** (EI 2008 → Φ_SI 1994 → IIT 3.0 small-φ → big-Φ n=2 → n=3 genuine MIP search; anima many-node PyPhi 1.2.0 = carry).
>
> 실행: `HEXA_MEM_UNLIMITED=1 hexa run tool/atlas_verify.hexa [--domain D]` (full-suite 로컬 4GB memcap 초과 → mem-flag 필수) · CI gate: `hexa run test/atlas_verify_smoke.hexa`. `hexa atlas-verify` source-wired (정식 dispatcher binary rebuild 시 활성화).

## 🟢 핵심 파일

| 파일 | 한 줄 설명 |
|------|-----------|
| 🎯 **MAIN.tape** | 9 도메인 verdict SSOT (MATH / PHYS / CHEM / BIO / COSMO / GEO / TOP / ENG / FOUNDATION) + § BRIDGES + § 🔵 CLOSED INVENTORY + § FALSIFIED / PARTIAL / INSUFFICIENT / DEFERRED · architecture-current (g_arch_vs_log_split) |
| 📜 **MAIN.log.tape** | append-only cycle history (cycle 001-033) — verifier sprint · tier change · stdlib contribution · falsifier fire · governance check 기록 |
| 🔬 **VERIFY.tape** | 3-stage protocol · falsifier ≥5 pre-register declarative + executable (falsifier.hexa) · sha256 freeze · tier→stage mapping · phase_3_landed |
| 📖 **AGENTS.tape** | atlas-area governance (anima g1~g8 carry + g_self_verify + g_tier_default_insufficient + g_external_calc_forbidden) · `CLAUDE.md` 는 symlink |
| 📦 **inbox/** | 새 verdict 제출 통로 (downstream consumer 또는 external contributor 가 patch markdown 한 개 = 한 개념). project inbox/patches/ 와 동일 패턴. |

## 🧭 9 도메인 split

atlas 의 entry id prefix (MATH-/PHYS-/L0-L5/...) 와 archive-TECS-L 의 hypothesis prefix (CX/PH/MP/BIO/GEO/TOP/AI/CHEM) union 기반.

| § | 도메인 | atlas 안의 후보 entries | 예상 dominant tier |
|---|---|---|---|
| §1 | **N6-FOUNDATION** | n=6 + σ/τ/φ/sopfr/J2/μ/M3 primitives + perfect-number lattice (lattice-as-tool, internal arch only) | 🔵 SUPPORTED-IDENTITY 다수 |
| §2 | **MATH** | divisor identities · Basel π²/6 · Euler 항등 · Egyptian fraction unique · perfect-number cluster · Mersenne · sigma_minus1 · phi-sigma uniqueness | 🔵 SUPPORTED-IDENTITY 압도적 (T-proofs 43 anchor) |
| §3 | **PHYS** | CMB spectral · conservation laws · Maxwell · Lorentz · Weinberg angle · particle generations · gauge bosons · Kolmogorov scaling | 🔵 SUPPORTED-FORMAL + 🟢 SUPPORTED + 🟡 mixed |
| §4 | **CHEM** | periodic L1-L2 (boron/carbon/magnesium Z, valence) · graphene/diamond · materials_limits · neurotransmitter | 🟢 SUPPORTED + 🟡 PARTIAL |
| §5 | **BIO** | codon length (4) · stop codons (3) · double-helix · Krebs cycle · NMDA/STDP/HH (anima A7 carry) | 🟠 AT-RISK (anima 와 일관) + 🟡 PARTIAL |
| §6 | **COSMO** | Planck units · fine-structure α · Bekenstein bound · holographic · AdS/CFT · big-bang constants | 🔵 SUPPORTED-FORMAL + 🟡 SUPPORTED-BY-CITATION |
| §7 | **GEO** | earth layers · geological boundaries · planetary | 🟡 PARTIAL + ⚪ NOT-MEASURED |
| §8 | **TOP** | topology · knot · manifold · point groups · braid · Galois | 🟢 SUPPORTED + 🔵 (Galois closed) |
| §9 | **ENG** | GPU SM mapping (sm_blackwell, sm_amd, sm_ampere) · warp_size · NET protocol headers · compiler invariants | 🟢 SUPPORTED + ⚪ NOT-MEASURED |
| §10 | **BRIDGES** | cross-domain edges (T1-23 137-from-sigma-tau MATH↔PHYS · T1-30 ising-critical MATH↔PHYS · T2-01 chi-to-monster MATH↔SYMM) | meta-tier (carry from constituent verdicts) |

## 🎨 Verdict tier (14-class · 🔵 = math/physics closed-form)

| Tier | 의미 |
|------|------|
| 🔵 SUPPORTED-IDENTITY | hexa-native symbolic verifiable closed-form identity (수학적 closed) |
| 🔵 SUPPORTED-FORMAL | hexa-native formal sim deterministic 결과 (물리적 closed) |
| 🟢 SUPPORTED | 강한 evidence — numerical sim / cross-meta (closed-form 미확보) |
| 🟢 SUPPORTED-STRONG | 다중 evidence 일치 |
| 🟢 SUPPORTED-BY-PROXY | anchor entry carry |
| 🟡 SUPPORTED-BY-CITATION | literature anchor (internal 부재, 약함) |
| 🟡 PARTIAL | mixed evidence |
| 🟡 PARTIAL-CARRY | parent partial cascade |
| 🟠 INSUFFICIENT | Stage 2 sim / 별도 cycle 필요 (atlas 의 default tier) |
| 🟠 DEFERRED | 외부 hardware / data 의존 (g_external_calc_forbidden 적용 대상) |
| 🟠 AT-RISK | surrogate-vs-formal mismatch |
| 🔵 FALSIFIED-FORMAL | hexa-native sympy-equiv/formal sim 으로 닫혀 falsify (수학적/물리적 closed-by-disproof) |
| 🔴 FALSIFIED | evidence-against (measured but not formally closed) |
| ⚪ NOT-MEASURED | 측정 미실행 / no closed-form test (Phase 2 후보) |

🔵 closed 의 핵심 기준: hexa-native symbolic verifiable closed-form OR hexa-native formal sim deterministic. PASS/FAIL 무관 verified-closed (둘 다 🔵 가능).

## 🔬 3-stage verification protocol

| Stage | 방법 | hexa-native 빌트인 (Phase 2) |
|-------|------|------------------------------|
| Stage 1 symbolic | closed-form identity derivation · number-theoretic primitives | `compiler/atlas/symbolic/` (divisor_sum, totient, jordan, mobius, factorize · symbolic-eq simplification · closed-form rewrite) |
| Stage 2 numerical | Kuramoto / Onsager / Ginzburg-Landau / RG flow / QHO eigenvalue 의 hexa-native sim | `compiler/atlas/verify/{phys,chem,bio,cosmo}.hexa` (ODE/PDE solver 빌트인) |
| Stage 3 cross-meta | atlas edges (== / <- / ->) 로 sibling consistency / family cohesion 측정 | `compiler/atlas/verify/cross.hexa` (graph-traversal 빌트인) |

ROI 기준: Stage 1 hexa-native symbolic 이 가장 빠른 closure path (anima 결과 기준 A4 math 8/8 closed 모두 sympy-equiv 으로 도달).

## 🧪 Tier-aware build (CLI plan)

n6-replication tier 모델 carry:

| Tier | scope | command (Phase 2+) | 예상 시간 |
|------|-------|--------------------|----------|
| tier 1 | Stage 1 symbolic only · pure closed-form | `hexa atlas verify --tier 1` | ~30s |
| tier 2 | Stage 2 numerical sim · ODE/PDE | `hexa atlas verify --tier 2` | ~10min |
| tier 3 | external (hardware/data) — atlas 거부 (g_external_calc_forbidden) | n/a | n/a |

## 🛡️ Falsifier ≥5 pre-register

각 fire-eligible verdict entry 는 falsifier 5개 (pre-register) frozen. fire 후 추가/수정 금지 (W8 amendment 만, hash + commit). VERIFY.tape 의 declarative format + Phase 2 의 executable form (`pub fn falsifier_<id>_<n>() -> bool`) 동기화.

## 🔄 Lifecycle

| Stage | 단계 | 위치 |
|-------|------|------|
| 1 | submit | `atlas/inbox/<descriptive-name>.md` (한 개념 = 한 파일) |
| 2 | review | reviewer 가 verdict tier 부여 + falsifier ≥5 작성 |
| 3 | merge | `atlas/MAIN.tape` 의 해당 § 도메인 section append |
| 4 | log | `atlas/MAIN.log.tape` (auto, append-only · g_arch_vs_log_split 적용) |
| 5 | engine | Phase 2 시 `compiler/atlas/verify/<domain>.hexa` 에 verifier 등록 |

## 📐 Layer split

atlas verdict 는 두 layer 동시 보존:

| Layer | 위치 | 역할 | 누가 읽음 |
|-------|------|------|----------|
| **spec** | `atlas/*.tape` (this directory) | 사람 읽는 verdict ledger | reviewer · contributor · LLM agent |
| **engine** | `compiler/atlas/verify/*.hexa` (13 modules, LANDED) | hexa-native verifier | `hexa run tool/atlas_verify.hexa` · CI gate `test/atlas_verify_smoke.hexa` |

두 layer 사이 SSOT 동기화: spec (MAIN.tape entry) 가 verdict SSOT, engine (verify/*.hexa) 가 hand-written hexa-native verifier (codegen 아닌 직접 구현 — verifier field 가 cross-link). cycle 마다 verifier PASS → MAIN.tape tier upgrade + MAIN.log.tape append.

## 🔗 cross-links

| Path | 한 줄 설명 |
|------|-----------|
| 📁 `MAIN.tape` | 9-domain verdict SSOT |
| 📁 `VERIFY.tape` | 3-stage protocol + falsifier ≥5 spec |
| 📁 `AGENTS.tape` | atlas-area governance (`CLAUDE.md` symlink) |
| 📁 `inbox/` | submission 통로 |
| 🔧 `../compiler/atlas/embedded.gen.hexa` | atlas atom rodata (frozen, ~410 entries) |
| 🔧 `../compiler/atlas/verify/` | hexa-native verifier engines — 13 modules: foundation·math·top·cosmo·bridges·chem·phys·transcendental·eng·geo·bio·cross·modular·falsifier |
| 🔧 `../tool/atlas_verify.hexa` | CLI entry point — `hexa run tool/atlas_verify.hexa [--domain D]` (작동 중) |
| 🔧 `../test/atlas_verify_smoke.hexa` | CI gate (strict-lint stage 9 surrogate) — 14-module 회귀 gate, exit(1) on regression |
| 🌐 `~/core/wilson/plugins/governance/main.hexa` | wilson governance priority-1 `verification-via-hexa-cli-only` (atlas carry) |
| 🌐 `../AGENTS.tape` | project-level governance (g_arch_vs_log_split + lattice-as-tool + real-limits-first 기반) |
| 🌐 `../LATTICE_POLICY.md` | dancinlab-wide real-limits-first standard |
| 🌐 `../HEXA-NATIVE-ONLY.md` | self-hosted 정책 — atlas verifier 의 hexa-native 의무 근거 |
| 🌐 `~/core/anima/INDEX.md` | upstream verdict 검증 기준 (carry source) |
| 🌐 `~/core/archive-TECS-L/docs/proofs/` | T0/T1/T2 proofs 43 — MAIN.tape anchor seed source |

## 📊 Adoption phase

| Phase | scope | status |
|-------|-------|--------|
| **Phase 1** | spec layer (5 files + inbox/) · archive-TECS-L T-proofs anchor seed · default tier 🟠 INSUFFICIENT | ✅ 2026-05-15 LANDED |
| **Phase 2** | engine layer · Stage 1 hexa-native (stdlib/core/math) · Stage 2 libm transcendental · domain verifiers · `tool/atlas_verify.hexa` CLI · cycle 001-018 cumulative 82 | ✅ 2026-05-15 LANDED |
| **Phase 3** | Stage 3 cross-meta · falsifier executable + sha256 freeze (18 batteries) · CI gate (strict-lint stage 9 surrogate) · T2-01 full chain · §5 BIO IIT ladder · wilson governance priority-1 carry · cycle 019-033 cumulative 118 verifier PASS + 15 🟡 literature anchors (cycle 033) | ✅ 2026-05-15 LANDED · cycle 033 2026-05-16 |
| **Phase 3+ deferred** | anima-scale many-node MIP (Bell(n) super-exp, PyPhi 1.2.0 carry) · true 컴파일러 strict-lint stage 9 (build-time HX-code) · hexa dispatcher binary rebuild (`hexa atlas-verify` 활성화) · MAIN.log.tape append automation (commit hook) · ubu-1/2 current-interp build (원격 toolchain) | ⚪ deferred |
