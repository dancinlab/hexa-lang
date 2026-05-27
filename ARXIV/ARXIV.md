# ARXIV — 논문 카탈로그 흡수 도메인 (도메인 SSOT)

@title: 📡 ARXIV — 논문 광맥 채굴기 ("arxiv claim 흡수기")
@goal: arxiv 논문에서 검증 가능한 claim/algorithm/formula 를 추출 → hexa verify g5 게이트 → atlas fold OR cross-repo INBOX handoff. 4 sibling 프로젝트(anima·demiurge·phanes·hexa-lang)가 필요로 하는 것을 흡수·검증·분배하는 catalogue-mirror lane.

> catalogue-mirror 도메인 family: OEIS(정수 sequence exact-hash) · DLMF(🔴 구조 불일치) · **ARXIV(논문 claim semantic ingest)**.
> 메커니즘 차이: OEIS=exact 정수 해시 / ARXIV=논문 추상→claim 추출→verify-gate (대부분 🟡 citation + cross-repo handoff, 소수만 🔵/🟢).

## 0 · 한 문단 상태 (2026-05-26 개시)

arxiv query → 논문 추상 → claim 추출 → 3갈래 분류:
(a) verify-able (numeric/formal) → hexa verify → atlas,
(b) citation-only → 🟡 atlas citation,
(c) project-specific → cross-repo INBOX handoff (g60).
4 axis = anima(의식/IIT/Φ) · demiurge(반물질 공정) · phanes(자율발견) · hexa-lang(컴파일러/수론). naive dump 금지 — verify-gate 또는 명시적 handoff 만.

> **진행 2026-05-26**: A1(POC, 12편) + A2(ANIMA, 11편 · 6 anima H 핸드오프) + A3(DEMIURGE axis, 12편 · 12 demiurge 7공정 핸드오프 g60) + A4(PHANES axis, 10편 흡수 · 10 phanes 4표면 핸드오프 g60) + **A5(HEXA-LANG axis, 13편 흡수 · 0 핸드오프 = IN-REPO)** DONE. A3 = ARXIV 첫 verify-able 축(정수-exact 물리상수 5종 🔵 LIVE). A4 = A2 동형(0 verify-able, 정직). **A5 = ARXIV 두 번째 verify-able 축이자 논문이 실제로 다루는 수론 폐형해 *값* recompute 첫 축** (A3 = 물리 factor/exponent, A2/A4 = 0). math.NT 8편 전부 verify-confirmed 🔵 — hexa atlas 가 σ/τ/φ/μ/nth_prime/catalan/partition 을 TECS-L Tier1 폐형해로 이미 보유 → math.NT 논문의 *대상* 이 곧 hexa atom = DIRECT recompute(citation 아님). 16종 fn · 30+ recompute 🔵 + 1 🔴 결정성 대조군. cs.PL/cs.LO 5편 🟡 = hexa 의 atlas-cite-at-compile 모델 = PCC 변종(증명서=atlas atom ref, 검사기=strict-lint stage)을 Lissom-PCC + CompCert-TCB + equality-saturation + Dafny-VCG 에 정박. A5 는 4-axis fan-out 의 IN-REPO 종착점 — math.NT finding 은 hexa 자신의 atlas 를 먹이고(handoff 없음), in-repo atlas-feed 가 A6 cross-repo handoff 메커니즘의 null/identity 케이스. **A6(cross-repo handoff 메커니즘 정립 + 3 handoff debt 정산) DONE** — g60 INBOX flow 정본화(ingest→triage→target INBOX 분배→target 세션 commit+ack g48) + A2/A3/A4 가 dirty non-main 트리에 working-copy edit 로만 남긴 3 핸드오프 부채를 **격리 worktree off origin/main 로 안전 정산**: anima(PR #576 admin-merge `4618d7c9`)·demiurge(`10f909ca` push main)·phanes(`22414be4` push main, 파일 신규). 4-axis = 3 cross-repo + 1 self-absorb null case(A5 in-repo atlas feed = 항등원). verify-density 상관 = handoff-axis verify-ability ∝ target-repo 폐형해 밀도(DEMIURGE/HEXA-LANG verify-native producer · ANIMA/PHANES consumer 0, 정직). 다음 = A7 (catalogue closure report + reuse edge g67 NEXUS.tape + 4-repo 흡수 ledger).

## 1 · 4 axis × arxiv 카테고리

| axis | 프로젝트 | arxiv cats | 흡수 대상 |
|---|---|---|---|
| ANIMA | 의식 엔진 (IIT 4.0·Φ·EEG) | q-bio.NC·cs.AI | integrated-information·Φ-structure |
| DEMIURGE | 반물질 공장 (7공정) | physics.atom-ph·acc-ph·hep-ex | antihydrogen·트랩·감속·냉각 |
| PHANES | 자율발견 SaaS (OUROBOROS) | cs.AI·cs.LG·cs.MA | self-improving agent·verifier loop |
| HEXA-LANG | 컴파일러·atlas·수론 | cs.PL·math.NT·cs.LO | codegen·number theory·형식검증 |

## 2 · 로드맵

- [x] A1 — ingest POC: 12 IIT-Φ 논문 triage (0 verify-able / 5 🟡 citation / 7 anima handoff). 파이프라인 검증. 다음 = A2 (ANIMA axis 본격 흡수).
- [x] A2 — ANIMA axis: consciousness/IIT 논문 11편 흡수 → anima LIFE H_xxx cross-link 6 handoff (g60). 0 verify-able (in-tree IIT primitive 부재 — V5 IIT 엔진 후 4 candidate → 첫 🟢). 7 🟡 citation. verdict=`.verdicts/arxiv-anima-absorb/triage_a2.txt` · docs=`docs/a2-anima-axis.md`. **2026-05-26 업데이트 (VERIFY-KIT V5 완료)**: PyPhi(Mayner et al. 2018, arXiv 1712.09644) verify-able-candidate 가 이제 앵커됨 — VERIFY-KIT V5.3 가 in-tree faithful-Φ 엔진(`stdlib/consciousness/iit4`)을 독립 레퍼런스 2종에 calibrate: Ref A(same-substrate Python MI-MIP 재구현) = 3.836592 ≈ hexa 3.83659 (|Δ|=1.67e-06, 🟢) + Ref B(PyPhi discrete-TPM canonical basic_network Φ=2.3125) = documented substrate-divergence(MI-MIP proxy ≠ IIT 4.0, 설계상 closed-negative). A2 의 "V5 IIT 엔진 후 첫 🟢" candidate 가 실현됨 (verdict `.verdicts/verify-kit-iit-calibrate/v5_3.txt`).
- [x] A3 — DEMIURGE axis: 반물질 공장 7공정 물리 논문 12편 흡수 → ANTIMATTER 7공정 cross-link 12 handoff (g60, ~/core/demiurge). **ARXIV 첫 verify-able 축** — 정수-exact 물리상수 5종 🔵 LIVE(pair_threshold_kinetic/total_factor ⓵ · cyclotron_cool_massexponent/bratio_exponent/bexponent ⓸; HEAD #1153) + 1 🔴 neg ctrl. 7 🟡 citation. Penning 3주파 float(`penning_invariance` @F 🟢)·1S-2S Rydberg = V9 float-driver candidate. **VERIFY-KIT V9 가 트랩/분광 verify coverage 5종 추가(demiurge 반물질-공장 축 boost)**: `cyclotron_freq_hz`(자유 cyclotron f_c=qB/(2πm) ⓺가둠)·`penning_axial_freq`(Penning 축방향 ω_z=√(qU/md²), 기존 `penning_omega_±` ω_z 앵커 6189938.0145 정확 재현 ⓺가둠)·`h_reduced_mass_factor`·`antihydrogen_1s_binding`(환산질량 보정 1S 결합 13.5983 eV ⓻측정)·`gbar_free_fall_time`(WEP 자유낙하 ⓼중력) — 전부 🟢 NUMERICAL via `--tol`, parse-gate PASS + 참조값 5/5 IEEE-754 일치(slug=`verify-kit-physics`, verdict=`.verdicts/verify-kit-physics/v9.txt`); binary verify 는 선존 V7 transpiler flatten 버그로 보류(V9 무관, inbox note). verdict=`.verdicts/arxiv-demiurge-absorb/triage_a3.txt` · docs=`docs/a3-demiurge-axis.md`.
- [x] A4 — PHANES axis: autonomous-discovery/OUROBOROS 논문 10편 흡수 → phanes 4표면 cross-link 10 handoff (g60, ~/core/phanes). **0 verify-able (정직·예상대로 — PHANES 는 systems/SaaS, OUROBOROS 엔진 소비자, 폐형해 atom 부재; A2 ANIMA 와 동형, A3 DEMIURGE verify-native 와 정반대)**. 5 🟡 citation (OE-essential-for-ASI · OMNI · AutoML-Zero · Sakana-eval · Native-Reasoning). 가장 강한 대응 = AlphaEvolve(2511.02864 Tao+) = phanes hosted LLM-propose+verify+refine 루프 직접 analog. 미래 후보 = net-novelty-rate/saturation-round 폐형해(엔진-instrumentation lane). verdict=`.verdicts/arxiv-phanes-absorb/triage_a4.txt` · docs=`docs/a4-phanes-axis.md`.
- [x] A5 — HEXA-LANG axis: compiler/number-theory 논문 13편 흡수 → **수론 atom verify (IN-REPO, handoff 없음)**. **ARXIV 두 번째 verify-able 축(A3 다음)이자, 논문이 실제로 다루는 수론 폐형해 *값*을 recompute 하는 첫 축** (A3 = 물리 factor/exponent, A2/A4 = 0). math.NT 8편 전부 verify-confirmed 🔵 — σ/τ/φ/μ/nth_prime/catalan/partition 등 16종 hexa-native fn · 30+ recompute 🔵 + 1 🔴 결정성 대조군 (HEAD #1153, mini arm64, POOL_DISABLE=1; 1309.0906 Dris·1011.6160 Shevelev·2202.06357 Mersenne-perfect-poly·1704.05595 Schmidt·0201265 Moree-Ramanujan·0210312 Ruiz-Sondow·0502532 Callan·1207.4446 Coleman). cs.PL/cs.LO 5편 🟡 citation (2201.10280 CompCert-TCB·2512.05262 Dafny-VCG·2111.13040+2511.20782 equality-saturation·0803.2317 Lissom-PCC) — hexa 의 atlas-cite-at-compile = PCC 변종(증명서=atlas atom ref, 검사기=strict-lint) 정박. 0 handoff (IN-REPO — 흡수 repo 자체가 대상; cross-repo handoff 메커니즘 = A6). verify-able-CANDIDATE = partition_coeff/sigma_k/dim_cusp_forms/jacobi/kronecker (2-arg --expr dispatch 배선 시 🔵/🟢). verdict=`.verdicts/arxiv-hexalang-absorb/triage_a5.txt` + headline 6편 · docs=`docs/a5-hexalang-axis.md`.
- [x] A6 — cross-repo handoff 메커니즘 정립 (g60 INBOX) + **3 handoff debt 정산 (g48 ack)**. 메커니즘 정본: ingest → triage → target-repo `INBOX.log.md` 분배(slug 앵커·stub-first·dedup) → target 세션 commit+소비+ack(g48). 4-axis 패턴 = 3 cross-repo handoff(anima/demiurge/phanes) + **1 self-absorb null case(A5 hexa-lang = in-repo atlas feed, INBOX hop 없음 = 항등원)**. dirty-tree commit hazard: target repo 들이 non-main feature 브랜치(anima orphan-recover·demiurge feat/rtsc-magnet-wheeler-v2·phanes domain/init-phanes) 위 dirty → A2/A3/A4 가 working-copy edit 로 filing 했으나 commit 불가(공유 dirty 트리 hazard) → **resolution = target repo 별 격리 worktree off origin/main**. **3 debt 정산 완료**: anima `arxiv-a2-iit-empirical-ingest` (PR #576, merge `4618d7c9`, protected main admin-merge) · demiurge `arxiv-a3-antimatter-factory-ingest` (`10f909ca`, 직접 push main) · phanes `arxiv-a4-autonomous-discovery-ingest` (`22414be4`, 직접 push main, 파일 신규 생성). verify-density 상관: handoff-axis verify-ability ∝ target-repo 폐형해 밀도 — DEMIURGE 5🔵·HEXA-LANG 30+🔵 = verify-native producer / ANIMA 0·PHANES 0 = consumer(정직). docs=`docs/a6-crossrepo-handoff.md` · `CLAIMS.tape` @C slug=arxiv-handoff-mechanism. 다음 = A7 (catalogue closure report).
- [ ] A7 — catalogue closure report + reuse edge (g67 NEXUS.tape) + 4-repo 흡수 ledger
- [ ] A8 — paper (paper_on_discovery: arxiv 흡수가 새 verified finding 을 낳은 경우만)

## 3 · 거버넌스 · 비범위
- verify 정본: `hexa verify` g5, 판정문 verbatim. LLM 자기판정 금지.
- naive 논문 dump 금지 — verify-gate 통과 또는 명시적 cross-repo handoff 만 흡수로 인정.
- arxiv = arxiv.org (open access). attribution = arxiv ID + 저자 + 제목 (atlas atom source 필드).
- 비범위: 논문 전문 재출판 · peer-review · paywalled 논문.
