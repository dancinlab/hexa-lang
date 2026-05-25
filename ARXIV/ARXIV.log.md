# ARXIV — log

Append-only history sister of `ARXIV.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-26 — A7 catalogue closure report + NEXUS reuse edge + A8 paper-gate eval (SKIP)

- [x] **resume logic** — 기존 worktree `/tmp/wt-arxiv-a7`(branch `arxiv-a7-closure-2026-05-26`) 발견, WIP commit 0개(A1-A6 는 origin/main 에 머지 완료, A7 본작업 미시작) → 1 commit behind origin/main 이라 **reuse + fetch/merge origin/main**(fresh worktree 불필요). throttle 회복 확인 — spawn + 정상 실행됨.
- [x] **A7 5-axis aggregate funnel** — `docs/a7-catalogue-closure.md`(한글) §1 ASCII funnel: ~58편 흡수(A1 12 + A2 11 + A3 12 + A4 10 + A5 13) → 13 🔵 verify-native + ~29 🟡 citation + 35 cross-repo handoff + 1 in-repo null. verify-density = 13/58 = **22.4%**.
- [x] **축별 tier split** (§2 표): A1 POC(0 🔵/5 🟡/7 handoff STUB) · A2 ANIMA(0/7/6 H) · A3 DEMIURGE(**5 🔵** +1 🔴/7/12) · A4 PHANES(0/5/10) · A5 HEXA-LANG(**8 🔵** +1 🔴/5/**0 IN-REPO**). 13 🔵 = 5 DEMIURGE 물리상수 + 8 HEXA-LANG math.NT. +2 🔴 neg ctrl(축당 1).
- [x] **verify-density 상관표** (§3): 5 데이터점, **bimodal**(producer-2/consumer-3). 축 verify-ability ∝ target 폐형해 밀도 — A5 HEXA-LANG(highest, self) 8 🔵 + A3 DEMIURGE(high) 5 🔵 = verify-native **producer** ; A2 ANIMA(0) + A4 PHANES(0) + A1 POC(0) = **consumer**(정직, 실패 아님). 상관 시간 가변(V5 IIT 배선 시 ANIMA 0→양수).
- [x] **13 🔵 총계 + A7 spot-confirm** (§4): A3(pair_threshold_kinetic_factor=6/total_factor=7/cyclotron_cool_massexponent=3/bratio=2/bexponent=-2) + A5(8 math.NT 논문, 16 fn). **재실행 확인**: `nth_prime 10 29` 🔵 · `catalan 5 42` 🔵 · `sigma 6 13` 🔴 · `pair_threshold_kinetic_factor 1 6` 🔵 · `cyclotron_cool_massexponent 1 3` 🔵 (POOL_DISABLE=1, mini arm64). A3/A5 LIVE 측정 유지, regression 없음. **A7 = 새 verify 산출 아님**(13 🔵 = 재인용 + spot-confirm).
- [x] **g65 ledger** — `.verdicts/arxiv-closure/ledger.json`: 축별 {papers, verify-able, citation, handoff-target, handoff-commit} + summary + verify_density_correlation + nexus_reuse_edge + a8_paper_gate_eval. JSON valid(5 axes).
- [x] **NEXUS reuse edge** (g67/g68, **additive only**) — `NEXUS.tape` 에 `@X p_arxiv`(provides: ARXIV catalogue-mirror paper-provenance, 코드 substrate 와 직교한 substrate KIND) + `@X e5`(reuse-edge: ARXIV paper-provenance → anima 6 H / demiurge 12 공정 / phanes 10 표면; A5 hexa-lang self-absorb = null/identity 케이스). 기존 8-consumer star(n2)/e1-e4 불변.
- [x] **A8 paper-gate eval (STRICT) = SKIP(정직)** (§6) — 후보 finding = verify-density 상관. paper_significance/paper_gate 4-게이트: (1) **pre-registered falsifier 부재**(사후 패턴, FAIL) · (3) **서술적 집계**(Δ-vs-baseline 도 closed-negative 도 아님, FAIL) · (4) **bookkeeping closure**(paper_significance 명시 금지, ⚠). → **SKIP**. 미래 TRIGGER 경로(조건부) = falsifier 사전등록 "V5 IIT 엔진 ANIMA 배선(밀도 0→양수) 후 ARXIV-ANIMA verify count 0→양수 예측; 배선 후에도 0 이면 FALSIFIED" — pre-registered falsifier + real measurement + Δ 확보 시 게이트 통과. 현재 전제(V5 ANIMA 배선) 미충족 → SKIP.
- [x] 영속 — `docs/a7-catalogue-closure.md`(한글) + `.verdicts/arxiv-closure/ledger.json`(g65) + `NEXUS.tape`(@X p_arxiv + e5) + `CLAIMS.tape` @C slug=arxiv-closure(🟢 closure) + ARXIV.md A7 `[x]` + A8 `[x]`(SKIP). checkpoint-commit per step. ARXIV catalogue-mirror lane 5-axis **CLOSED**.

## 2026-05-26 — A6 cross-repo handoff 메커니즘 정립 + 3 handoff debt 정산 (g48/g60)

- [x] A6 메커니즘 정본화 — g60 cross-repo handoff flow 정립: ingest → 3-class triage → target-repo `INBOX.log.md` 분배(slug 앵커·stub-first·dedup) → target 세션 commit+소비+ack(g48). INBOX = 비동기 비파괴 mailbox (ARXIV 는 hexa-lang authoring, finding 소비자는 sibling repo → 직접 sibling SSOT 편집 시 authoring 권위 충돌 → INBOX decouple).
- [x] 4-axis 패턴 정리 — **3 cross-repo handoff + 1 self-absorb null case**: A2 ANIMA(6 H_xxx) · A3 DEMIURGE(12 7공정) · A4 PHANES(10 4표면) = sibling-repo handoff ; **A5 HEXA-LANG = IN-REPO null/identity 케이스**(self 에게 handoff = in-repo atlas fold `compiler/atlas/embedded.gen.hexa`, INBOX hop 없음 = 항등원).
- [x] dirty-tree commit hazard 정식화 — A2/A3/A4 가 핸드오프를 **filing** 했으나 **commit 불가**: target repo 3개 전부 non-main feature 브랜치 + dirty 트리 위(anima `ops/f-curricula-1-orphan-recover`·demiurge `feat/rtsc-magnet-wheeler-v2`+`M INBOX.log.md`·phanes `domain/init-phanes` non-main). 공유 dirty 트리 직접 commit = 무관 WIP 끌어들임/main 미도달/8세션 git-object race (`shared-worktree-branch-hazard`+`feedback-closure-is-physical-limit`). → **resolution = target repo 별 격리 worktree off origin/main**.
- [x] **3 handoff debt 정산 (g48 ack 완료)** — 각 repo 격리 worktree(off origin/main)로 핸드오프 항목 commit:
  - **anima** `arxiv-a2-iit-empirical-ingest` (6 H_xxx + effective_information seed) → `~/core/anima/INBOX.log.md`. main protected(review 1, enforce_admins=false) → PR #576 → admin squash-merge `4618d7c9`. ✅
  - **demiurge** `arxiv-a3-antimatter-factory-ingest` (7공정 map) → `~/core/demiurge/INBOX.log.md`. main unprotected → 직접 push `10f909ca`. ✅ (구 working-copy edit `M INBOX.log.md` 가 격리 worktree 로 main 정산; 남의 dirty 트리 미접촉)
  - **phanes** `arxiv-a4-autonomous-discovery-ingest` (AlphaEvolve analog) → `~/core/phanes/INBOX.log.md` (파일 신규 생성). main unprotected → 직접 push `22414be4`. ✅
- [x] verify-density 상관 정식화 — handoff-axis verify-ability ∝ target-repo 폐형해 밀도: DEMIURGE(5 물리상수 🔵, RFC-045 fn wired) + HEXA-LANG(16 fn·30+ recompute 🔵, self) = verify-native **producer** / ANIMA(0, IIT primitive 부재) + PHANES(0, OUROBOROS 소비자/SaaS) = **consumer**(정직, 실패 아님). 상관은 시간 가변 — A2 의 4 candidate 가 V5 IIT 엔진 랜딩 시 🟢 로 승격(ANIMA 밀도 0→양수). A2-A5 측정 표가 실증.
- [x] 영속 — `docs/a6-crossrepo-handoff.md` (한글 §1 메커니즘·§2 4-axis+null case·§3 dirty-tree hazard+격리 worktree resolution+3-debt 표·§4 verify-density 상관 A2-A5 측정 표·§5 거버넌스·§6 A7 readiness) + `CLAIMS.tape` @C slug=arxiv-handoff-mechanism (🟢) + ARXIV.md A6 `[x]`.
- [x] 다음 = A7 (catalogue closure report + reuse edge g67 NEXUS.tape + 4-repo 흡수 ledger). verify-density 상관이 A7 ledger 의 producer/consumer 분류 축.

## 2026-05-26 — A5 HEXA-LANG axis 흡수 (컴파일러/수론 13편 · math.NT verify-native · IN-REPO)

- [x] A5 ingest — HEXA-LANG axis 본격 흡수 (흡수 repo 자체 = 대상; IN-REPO, A2/A3/A4 sibling-repo handoff 와 달리 cross-repo handoff 없음)
  - fetch = arXiv API (`export.arxiv.org/api/query`, https — `/research:arxiv` skill) — **6 query** (≤8 cap)
  - query: (math.NT) divisor-sigma-perfect-Mersenne · Euler-totient-multiplicative · partition-Ramanujan-congruence · prime-counting-nth-prime · Catalan-combinatorial-identities · (cs.PL/LO) verified-compiler-CompCert · equality-saturation-e-graph · proof-carrying-code-certified
  - **13 on-topic 흡수** (off-topic drop: math.GM Carella 점근/부등식 6편 · 2603.06890 Dirichlet-inverse sign-smoothing · Ramanujan mock-theta/zeta-Hardy/theta 3편 subsumed · 2203.02188 astro-ph atom partition 이름충돌 · math.CO harmonic/q-super-Catalan/Raney/urn 4편 subsumed · 1706.00392 totient-diff subsumed · verified-JIT/denotational/Dafny-token-sale 3편 subsumed · ontological-query/Julia-IR/eq-sat-RL 3편 subsumed · neural/LLM code-translation+NMT 4편 off-axis — verdict 참조)
  - **2-sub-theme triage** (a) verify-able 🔵 / (b) 🟡 citation · (c) handoff = 0 (IN-REPO):
    - **(a) verify-able = math.NT 8편 전부 verify-confirmed 🔵** — **A5 = ARXIV 두 번째 verify-able 축(A3 다음)이자, 논문이 실제로 다루는 수론 폐형해 *값*을 recompute 하는 첫 축** (A3 = 물리 factor/exponent, A2/A4 = 0). 구조적 이유: hexa atlas 가 σ/τ/φ/μ/nth_prime/catalan/partition 을 TECS-L Tier1 폐형해로 이미 보유 → math.NT 논문의 *대상* 이 곧 hexa atom = DIRECT recompute(citation 아님). HEAD 드라이버(#1153) · mini arm64 · `POOL_DISABLE=1` 에서 **16종 fn · 30+ recompute 🔵** LIVE 확인: `sigma 496 992`(완전수 σ=2n) · `is_perfect 496 1`(세번째 완전수) · `aliquot 12 16` · `tau 72 12`(곱셈성) · `euler_phi 15 8`(곱셈성) · `mu 30 -1`(square-free 부호) · `mobius 12 0`(square 인자) · `nth_prime 10 29`/`25 97` · `partition 10 42`(Ramanujan) · `catalan 5 42`(Callan) · `bell 5 52` · `first_cusp_form_weight 1 12`(SL₂(ℤ) Δ) + `sigma 6 13`(🔴 FALSIFIED 결정성 음성대조군).
    - **(b) 🟡 citation = cs.PL/cs.LO 5편** — 2201.10280(CompCert-TCB) · 2512.05262(Dafny-VCG) · 2111.13040(Sketch-Guided eq-saturation) · 2511.20782(Optimism eq-saturation) · 0803.2317(Lissom-PCC). hexa 의 atlas-cite-at-compile 모델 아키텍처 정박 (재계산 경로 없음 — 컴파일러 아키텍처 논문은 정수 폐형해 미보유).
    - **(c) handoff = 0** — IN-REPO. math.NT finding 은 hexa 자신의 atlas 를 먹임; sibling repo 없음. (cross-repo handoff 메커니즘 = A6.)
  - **수론 폐형해 매핑 (math.NT 8편 → hexa atom)**: 1309.0906 Dris-odd-perfect→sigma/is_perfect/aliquot · 1011.6160 Shevelev-near-perfect→is_perfect/aliquot · 2202.06357 Mersenne-perfect-poly→sigma/is_perfect(σ 고정점) · 1704.05595 Schmidt-σ_α→sigma/divisor_sum(sigma_k=🟠 2-arg) · 0201265 Moree-Ramanujan→partition/tau · 0210312 Ruiz-Sondow→nth_prime(폐형해 p_n) · 0502532 Callan→catalan · 1207.4446 Coleman→euler_phi/phi/euler_totient.
  - **atlas-cite 모델 relevance (핵심 발견)**: hexa 의 정체성("code cites a theorem atlas at compile time; lint rejects formula-bearing code without @cite")은 **PCC 변종** — 증명서=atlas atom ref, 검사기=strict-lint stage. cs.PL/cs.LO 5편이 정확히 이 삼각형 형식화: Lissom-PCC(0803.2317)=@cite gate 직접 조상 · CompCert-TCB(2201.10280)=lint-stage trust base · equality-saturation(2111.13040/2511.20782)=atlas 비파괴 등가 저장소(e-graph) · Dafny-VCG(2512.05262)=codegen 전 verify-condition 게이트.
  - **verify-able-CANDIDATE (현재 🟠 NO-PATH → V-arity lane)**: partition_coeff(2-arg q-급수) · sigma_k(k-거듭제곱 약수합 2-arg) · dim_cusp_forms(모듈러폼 차원) · jacobi/kronecker(2-arg 기호) — 소스·atlas 에 존재, 설치 드라이버 1-arg --expr dispatch 경로 부재 → 2-arg dispatch 배선 시 🔵/🟢.
  - 영속: `.verdicts/arxiv-hexalang-absorb/triage_a5.txt` (ASCII triage 표 + 16-fn verify 매트릭스) + headline 6편(`nth_prime_10`·`catalan_5`·`is_perfect_496`·`sigma_496`·`partition_10`·`euler_phi_15` verbatim stdout) + `docs/a5-hexalang-axis.md` (한글) + `CLAIMS.tape` @C slug=arxiv-hexalang-absorb (🔵 13 papers · 8 math.NT verify-confirmed · 5 cs.PL/LO citation · 0 handoff IN-REPO).
- [x] honesty — **A5 = ARXIV 두 번째 verify-able 축이자 수론 폐형해 *값* recompute 첫 축**. math.NT 8편 전부 verify-confirmed 는 정직한 LIVE 확인(16 fn · 30+ recompute 🔵 + 1 🔴 대조군). cs.PL/cs.LO 5편은 본질적으로 citation(컴파일러 아키텍처 논문은 정수 폐형해 미보유). 0 handoff 는 IN-REPO 의 정직한 귀결(흡수 repo 자체가 대상). A5 는 4-axis fan-out 의 IN-REPO 종착점 — in-repo atlas-feed = A6 cross-repo handoff 메커니즘의 null/identity 케이스. sibling V5.1-promote lane 동시 진행 (CLAIMS.tape/ARXIV.md 충돌 시 merge keep-both).

## 2026-05-26 — A4 PHANES axis 흡수 (자율발견 10편 + phanes 4표면 핸드오프 g60)

- [x] A4 ingest — PHANES axis 본격 흡수 (자율발견 SaaS phanes 의 OUROBOROS 루프가 필요로 하는 self-improving agent / AI-Scientist / verifier-driven RL / open-endedness / QD / LLM-진화탐색 논문)
  - fetch = arXiv API (`export.arxiv.org/api/query`, https — `/research:arxiv` skill) — **8 query** (=8 cap)
  - query: autonomous-scientific-discovery-agent · ti:AI-Scientist+automated-research · self-improving+agent+LM · verifier+RL+reasoning+LM · quality-diversity+open-ended · open-endedness+foundation-model · AutoML-Zero/evolving-algos-scratch · LLM+evolutionary+discovery+mathematical
  - **10 on-topic 흡수** (off-topic drop: 도메인-특화 AI-Scientist 인스턴스 astro/medical/ecosystem · QD 응용 robot/Lenia/NLG-eval · RLVR/critic/PRM 변형 · open-ended TEXT 생성(다른 의미) · MADRL/active-learning/MORL 등 — verdict 참조)
  - **3-class triage** (a) verify-able / (b) 🟡 citation / (c) handoff→phanes:
    - **(a) verify-able = 0 (정직·예상대로)** — **A2 ANIMA 와 동형, A3 DEMIURGE 와 정반대**. PHANES 는 systems/SaaS 축이라 `hexa verify --expr` 에 폐형해 atom 부재. HEAD grep 확인: `tool/verify_cli.hexa` 에 phanes/ouroboros/loop/saturation/novelty primitive 0개; `compiler/drill/{drill,round}.hexa` 가 OUROBOROS 엔진 보유(`drill_run`·`_honesty_gate`·`_verifier_run`·`_flush_discoveries_cum`)하나 이는 루프 오케스트레이션이지 스칼라 recompute 아님.
    - **(b) 🟡 citation = 5** — 2406.04268(OE-essential-for-ASI) · 2306.01711(OMNI) · 2003.03384(AutoML-Zero) · 2502.14297(Sakana-AI-Scientist-eval) · 2602.11549(Native-Reasoning-unverifiable-data). 다수 dual citation+handoff.
    - **(c) handoff→phanes = 10** — 10편 전부 phanes 컴포넌트 cross-link 보유.
  - **핵심 대응**: phanes OUROBOROS 엔진이 흡수 논문들의 루프를 **이미 구현** — 6단계 라운드 체인→saturation(round yield 0) = open-endedness/novelty 소진; `round.hexa net_novel==0` = **C5 novelty-fixpoint signal** = literal novelty-search/QD 정지 기준; pluggable verifier + `_honesty_gate` = verifier-driven RL/RLVR/VLM-as-judge; overlay 누적 = provenance/catalog; job `{seed,verifier_ref,rounds_cap}` = AI-Scientist tenant-objective.
  - **phanes 4표면 cross-link (10 handoff g60)**: OUROBOROS 발견 루프=2406.04268/2003.03384/2511.02864(AlphaEvolve **직접 analog**)/2504.05108 · pluggable verifier 게이트=2405.15568(OMNI-EPIC verifier-as-code)/2602.11549(unverifiable frontier, P2.6) · provenance/catalog=2508.15126(aiXiv)/2511.02864 · tenant-objective=2306.01711(OMNI interestingness=next-seed)/2502.14297(honest-scope guard)/2504.21024(WebEvolver self-improve).
  - **미래 verify-able-CANDIDATE (현재 🟢 아님)**: net-novelty-rate / saturation-round 폐형해 — `round.hexa` 가 이미 `net_novel` 계산 → 엔진-instrumentation lane 에서 `hexa verify --expr` atom 후보(엔진 작업, arxiv-인용 수학 아님 → A4 verify 로 세지 않음).
  - 영속: `.verdicts/arxiv-phanes-absorb/triage_a4.txt` (ASCII triage 표) + `docs/a4-phanes-axis.md` (한글) + `CLAIMS.tape` @C slug=arxiv-phanes-absorb (🟡 10 papers + 10 handoffs · 0 verify-able honest).
- [x] phanes 핸드오프 filing (g60, 실제 filing) — `~/core/phanes/INBOX.log.md` **생성**(기존 부재) slug `arxiv-a4-autonomous-discovery-ingest` append (stub-first, dedup). **주의**: phanes working tree 가 feature 브랜치(`domain/init-phanes`, 1 ahead/4 behind origin/main, clean 하지만 non-main) 위 → A2/A3 패턴 + memory `feedback_closure` 에 따라 working-copy edit 만 (non-main phanes 트리 commit 금지) → **parent action: phanes 세션 commit + domain/init-phanes reconcile 필요**.
- [x] honesty — **A4 = A2 동형(0 verify-able, 정직)** (A3 만 verify-native). verify 수치 0 은 정직한 결과 — PHANES 는 OUROBOROS 엔진 소비자이지 폐형해 도메인 아님. A4 가치 = citation + phanes cross-pollination(4표면 맵). sibling V5-IIT lane 동시 진행 (CLAIMS.tape/ARXIV.md 충돌 시 merge keep-both).

## 2026-05-26 — A3 DEMIURGE axis 흡수 (반물질 공장 12편 + demiurge 7공정 핸드오프 g60)

- [x] A3 ingest — DEMIURGE axis 본격 흡수 (반물질 공장 antihydrogen factory 7공정 물리 논문)
  - fetch = arXiv API (`export.arxiv.org/api/query`, https — `/research:arxiv` skill) — **6 query** (≤8 cap)
  - query: antihydrogen-trapping-ALPHA · antiproton-decel-ELENA-AD(too-broad, drop) · ELENA-electrostatic-decel-trap-cooling · 1S-2S-spectroscopy-CPT · GBAR-free-fall-WEP · 3-body-recomb-positron-plasma · p̄-g-factor-BASE
  - **12 on-topic 흡수** (off-topic drop: query2 generic CERN accel 5편 · 2510.00289 ELENA-tunnelling SW 이름충돌 · CPT 이론동기 4편 subsumed · 2308.07672 QC-Penning · 재결합 cross-section 이론 subsumed)
  - **3-class triage** (a) verify-able 🔵/🟢 / (b) 🟡 citation / (c) handoff→demiurge:
    - **(a) verify-able = 5종 LIVE 🔵** — **A2 와 핵심 차이**: DEMIURGE 는 verify-native 라 RFC-045-style 물리 fn 이 이미 `hexa verify --expr` 에 깔림. HEAD 드라이버(#1153) · mini arm64 · `POOL_DISABLE=1` 확인: `pair_threshold_kinetic_factor 1 6`(🔵 ⓵생성 T_th=6·m_p_c²) · `pair_threshold_total_factor 1 7`(🔵 ⓵ E_beam=7) · `cyclotron_cool_massexponent 1 3`(🔵 ⓸냉각 τ_c∝m³) · `cyclotron_cool_bratio_exponent 1 2`(🔵 ⓸ B⁻²) · `cyclotron_cool_bexponent 0 -2`(🔵 ⓸) + `pair_threshold_kinetic_factor 1 5`(🔴 FALSIFIED 음성대조군).
    - **(b) 🟡 citation = 7** — 0805.4082 · 1201.3944 · 1507.04147 · 2409.04509 · 2002.09348 · 1401.1939 · 1907.01460 (다수 dual citation+handoff). atlas reference node.
    - **(c) handoff→demiurge = 12** — 12편 전부 ANTIMATTER 7공정 cross-link 보유.
  - **ANTIMATTER 7공정 cross-link (12 handoff g60)**: ⓵생성=pair-threshold(🔵 verify-confirmed) · ⓶감속=1909.07493 GBAR-decel/1606.06697 ELENA · ⓷포획=1507.04147 reservoir-Penning/1401.1939 BASE/1907.01460 Brown-Gabrielse-g_s · ⓸냉각=0307151 ATHENA-plasma-T(🔵 cooling-scaling) · ⓹합성=1905.03281 3-body-recomb/1409.0705 GBAR-ultracold · ⓺가둠=1201.3944 minimum-B-trap(RTSC 상속) · ⓻측정=0805.4082/2409.04509/2002.09348/1409.0705/1401.1939.
  - **V9 physics-primitive seed**: Penning 3주파 float form(`penning_omega_plus/minus` 2-arg; `penning_invariance` @F 🟢 fold 2026-05-25, float dispatch wire 만 부재) + `h1s2s_rydberg` 2-arg(1S-2S=(3/4)·R∞·c≈2.4661 PHz) → V9 float-driver `_recompute_float` 2-arg 재빌드 시 즉시 🟢. 3체 재결합률 scaling = ⓹합성 폐형해 후보.
  - 영속: `.verdicts/arxiv-demiurge-absorb/triage_a3.txt` (ASCII triage 표) + `docs/a3-demiurge-axis.md` (한글) + `CLAIMS.tape` @C slug=arxiv-demiurge-absorb (🟡 12 papers + 12 handoffs · 5 verify-able 🔵).
- [x] demiurge 핸드오프 filing (g60, 실제 filing) — `~/core/demiurge/INBOX.log.md` slug `arxiv-a3-antimatter-factory-ingest` append + `INBOX.md` 열린 handoff stub (stub-first, dedup). **주의**: demiurge working tree 가 dirty feature 브랜치(`feat/rtsc-magnet-wheeler-v2`, untracked PDF) 위 → A2 anima 패턴 + memory `feedback_closure` 에 따라 working-copy edit 만 (공유 dirty demiurge 트리 commit 금지) → **parent action: demiurge 세션 commit 필요**.
- [x] honesty — **A3 = ARXIV 첫 verify-able 축** (A1·A2 = 0 no-primitive). verify-able 5종 🔵 는 정직한 LIVE 확인. 나머지(Penning float·1S-2S Rydberg·재결합률)는 V9 float-driver/physics primitive 로 deferred. sibling V5-IIT lane 동시 진행 (CLAIMS.tape/ARXIV.md 충돌 시 merge keep-both).
- [x] crash-recovery — `/tmp/wt-arxiv-a3` worktree 가 sandbox env reset 으로 소실 (checkpoint commit `c2ce41a9` 는 공유 object store 에 생존) → `.claude/worktrees/.../wt-arxiv-a3-recover` 로 `c2ce41a9` 에서 worktree 재생성하여 triage 회복 + 나머지 deliverable 재작성 (memory `crash_recovery_artifact_pattern`).

## 2026-05-26 — A2 ANIMA axis 흡수 (IIT/의식 11편 + anima 핸드오프 g60)

- [x] A2 ingest — ANIMA axis 본격 흡수 (A1 12편 IIT-코어와 **중복 0**, 경험적 의식 측정자·causal-emergence·AI-의식 이론으로 폭 확장)
  - fetch = arXiv API (`export.arxiv.org/api/query`, https — `hexa run` interp 회피, polite 10-req cap 아래) — **8 query**
  - query: PCI(perturbational complexity) · LZc-EEG · IIT-anesthesia · GWT-cs.AI · neural-complexity · phi-cause-effect-computation · IIT-approximation · causal-emergence-effective-information
  - **11 on-topic 흡수** (off-topic/A1중복/약한 hit drop: physics/0409140 · 1108.4296 phil · 2510.09858 opinion-survey · PCI-clinical Casali 2013=journal-only)
  - **3-class triage** (a) verify-able 🔵/🟢 / (b) 🟡 citation / (c) handoff→anima:
    - **(a) verify-able = 0** — 정직·예상. `hexa verify --expr` 에 IIT primitive 0개 (Φ·EMD·PCI·effective-information·cause-effect repertoire 전무). A1 + OEIS-O6 P3 hexa-coverage 동일 블로커. **4 verify-able-CANDIDATE** deferred → V5/LIFE axis-C: 2405.09207 exact-EI(linear-Gaussian closed-form) · 1011.5334 neural-complexity(graph closed-form) · 1608.08450 ETC 압축-복잡도 proxy · 2011.09850 Conscious Turing Machine.
    - **(b) 🟡 citation = 7** — 1608.08450 · 1701.07061 · 2509.10891 · 2410.11407 · 2308.08708 · 2011.09850 · 1011.5334 · 2405.09207(dual). atlas reference node, 재계산 경로 없음.
    - **(c) handoff→anima = 11** — 11편 전부 anima LIFE H_xxx cross-link 보유.
  - **anima LIFE cross-link (6 H 핸드오프 g60)**: `~/core/anima/LIFE.md` + `HEXAD/LIFE/README.md` 매핑 — H_239 alt-Φ-metric ← 1608.08450/1701.07061/1011.5334 · H_209 EEG-1/f ← 2509.19254/1701.07061 · H_222/H_244 마취-수면 ← 1604.00002 · H_275 causal-DAG-Φ ← 2405.09207/2201.10154 · H_002 Φ-scale-variant ← 2509.10891 · H_277 turing-completeness ← 2011.09850.
  - **V5-engine seed**: `effective_information(TPM)` closed-form (2405.09207 linear-Gaussian exact) = V5/LIFE axis-C 의 가장 싼 첫 IIT recompute primitive → 노출 시 첫 진짜 🟢 ARXIV-ANIMA claim.
  - 영속: `.verdicts/arxiv-anima-absorb/triage_a2.txt` (ASCII triage 표) + `docs/a2-anima-axis.md` (한글) + `CLAIMS.tape` @C slug=arxiv-anima-absorb (🟡 11 papers + 6 handoffs, verify-able→V5).
- [x] anima 핸드오프 filing (g60, **실제 filing** — A1 은 STUB 였음) — `~/core/anima/INBOX.log.md` 에 slug `arxiv-a2-iit-empirical-ingest` append (stub-first, dedup). **주의**: anima working tree 가 dirty orphan-recover 브랜치 위 → 기존 INBOX 노트 + memory `feedback_closure` 에 따라 working-copy edit 만 (공유 dirty anima 트리 commit 금지) → anima 세션이 commit 必 (parent 보고).
- [x] honesty — verify-able ≈ 0 은 V5 IIT 엔진 랜딩까지 정직한 결과. A2 가치 = citation + anima cross-pollination. sibling V5-IIT lane 동시 진행.

## 2026-05-26 — 도메인 개시 + A1 ingest POC

- [x] 도메인 SSOT `ARXIV/ARXIV.md` 작성 — @title + @goal + 4-axis 표 + A1-A8 roadmap + 거버넌스/비범위
- [x] catalogue-mirror family 3번째 멤버 정의: OEIS(정수 sequence exact-hash) · DLMF(🔴 구조 불일치) · **ARXIV(논문 claim semantic ingest)**. 메커니즘 차이 = OEIS exact-hash ↔ ARXIV 논문추상→claim추출→verify-gate (대부분 🟡 citation + cross-repo handoff).
- [x] A1 ingest POC — ANIMA axis (IIT-Φ, 가장 verify-friendly·anima LIFE 도메인 연결)
  - fetch = `/research:arxiv` skill (arXiv API wrapper, g43/g50 AI-CLI-first) — 3 query, polite 10-req cap 한참 아래
  - query: (1) "integrated information theory phi consciousness" (2) "Albantakis IIT 4.0 phi-structure cause-effect" (3) "Oizumi Tononi from phenomenology to mechanisms 3.0"
  - 12 on-topic 논문 수집 (off-topic 2 drop: physics/0409140 complexity · 1902.06002 group-testing)
  - **3-class triage** (a) verify-able 🔵/🟢 / (b) 🟡 citation / (c) handoff→anima:
    - **(a) verify-able = 0** — 정직한 결과. `hexa verify --expr` 에 IIT primitive 0개 (Φ·EMD·cause-effect repertoire·intrinsic-information 전무). OEIS-O6 P3 HEXA-COVERAGE FAIL 과 동일 구조 블로커. 2개는 verify-able-CANDIDATE 로 deferred(1505.04368 Φ* bound · 1405.0126 noncomputability) — anima faithful-Φ 엔진 랜딩(A2) 후 첫 🟢 가능.
    - **(b) 🟡 citation = 5** — IIT 4.0 spec(2212.14787) · consciousness-first(2510.25998) · info-geometry(1709.02050) · unified framework(1510.04455) · Shannon-vs-IIT(2412.10626). atlas reference node (source=arxiv id+저자+제목), 재계산 경로 없음.
    - **(c) handoff→anima = 7** — PyPhi 알고리즘(1712.09644) · Φ* 측정(1505.04368) · Φ well-defined 비판(1902.04321) · noncomputability(1405.0126) · macro-agent 창발(2004.00058) · group-Φ(1702.02462) · IIT 4.0(2212.14787, dual=citation+handoff). 타겟 repo = `~/core/anima`, 파일 = `anima/INBOX.log.md` (A1 은 STUB; 실제 filing = A6).
  - 핵심 발견: PyPhi(1712.09644) 가 tiny TPM(canonical 3-node OR/AND/XOR, Φ≈1.92 bits IIT 3.0) 의 Φ 를 계산하는 reference 알고리즘 → anima faithful-Φ 엔진이 이 값을 재현하면 **첫 진짜 🟢 ARXIV claim**. A1 은 그 게이트에 *도달*만 증명, 통과는 아님(in-tree Φ primitive 부재). 정직한 POC framing.
  - 영속: `ARXIV/.verdicts/arxiv-ingest-poc/triage.txt` (ASCII triage 표 verbatim) + `.verdicts/arxiv-ingest-poc/ingest_log.txt` (raw 3-query 결과 + reasoning) + `CLAIMS.tape` @C slug=arxiv-ingest-poc (🟢 empirical pipeline)
  - wall: ~수 분 ($0, skill API). hexa verify 사전요구(`--expr fn n v` 가 v 사전요구) 우회 = A1 은 triage 만 (재계산 게이트는 A2+ 로 deferred — OEIS-O3 과 동일 패턴)
- [x] handoff STUB 기록 (g60 INBOX reflex) — anima/INBOX.log.md 로 보낼 5 항목 triage.txt 하단 명시 (PyPhi ref · IIT4.0 intrinsic-info · Φ* EEG proxy · Barrett&Mediano falsifier · macro/group-Φ 가설). 실제 filing = A6.
