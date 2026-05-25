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

> **진행 2026-05-26**: A1(POC, 12편) + A2(ANIMA, 11편 · 6 anima H 핸드오프) + A3(DEMIURGE axis, 12편 · 12 demiurge 7공정 핸드오프 g60) + **A4(PHANES axis, 10편 흡수 · 10 phanes 4표면 핸드오프 g60)** DONE. A3 = ARXIV 첫 verify-able 축(정수-exact 물리상수 5종 🔵 LIVE). **A4 = A2 동형(0 verify-able, 정직)** — PHANES 는 systems/SaaS·OUROBOROS 엔진 소비자라 폐형해 atom 부재(A3 verify-native 와 정반대). A4 가치 = citation 5 🟡 + phanes 4표면 아키텍처 맵(발견 루프·verifier 게이트·provenance·tenant-objective). 핵심: phanes 엔진(`compiler/drill/{drill,round}.hexa`)이 흡수 논문들의 OUROBOROS 루프를 이미 구현(net_novel==0 = C5 novelty-fixpoint = QD/novelty-search 정지 기준). 다음 = A5 HEXA-LANG axis(compiler/수론, in-repo, A3 처럼 verify-native 가능성 높음).

## 1 · 4 axis × arxiv 카테고리

| axis | 프로젝트 | arxiv cats | 흡수 대상 |
|---|---|---|---|
| ANIMA | 의식 엔진 (IIT 4.0·Φ·EEG) | q-bio.NC·cs.AI | integrated-information·Φ-structure |
| DEMIURGE | 반물질 공장 (7공정) | physics.atom-ph·acc-ph·hep-ex | antihydrogen·트랩·감속·냉각 |
| PHANES | 자율발견 SaaS (OUROBOROS) | cs.AI·cs.LG·cs.MA | self-improving agent·verifier loop |
| HEXA-LANG | 컴파일러·atlas·수론 | cs.PL·math.NT·cs.LO | codegen·number theory·형식검증 |

## 2 · 로드맵

- [x] A1 — ingest POC: 12 IIT-Φ 논문 triage (0 verify-able / 5 🟡 citation / 7 anima handoff). 파이프라인 검증. 다음 = A2 (ANIMA axis 본격 흡수).
- [x] A2 — ANIMA axis: consciousness/IIT 논문 11편 흡수 → anima LIFE H_xxx cross-link 6 handoff (g60). 0 verify-able (in-tree IIT primitive 부재 — V5 IIT 엔진 후 4 candidate → 첫 🟢). 7 🟡 citation. verdict=`.verdicts/arxiv-anima-absorb/triage_a2.txt` · docs=`docs/a2-anima-axis.md`.
- [x] A3 — DEMIURGE axis: 반물질 공장 7공정 물리 논문 12편 흡수 → ANTIMATTER 7공정 cross-link 12 handoff (g60, ~/core/demiurge). **ARXIV 첫 verify-able 축** — 정수-exact 물리상수 5종 🔵 LIVE(pair_threshold_kinetic/total_factor ⓵ · cyclotron_cool_massexponent/bratio_exponent/bexponent ⓸; HEAD #1153) + 1 🔴 neg ctrl. 7 🟡 citation. Penning 3주파 float(`penning_invariance` @F 🟢)·1S-2S Rydberg = V9 float-driver candidate. verdict=`.verdicts/arxiv-demiurge-absorb/triage_a3.txt` · docs=`docs/a3-demiurge-axis.md`.
- [x] A4 — PHANES axis: autonomous-discovery/OUROBOROS 논문 10편 흡수 → phanes 4표면 cross-link 10 handoff (g60, ~/core/phanes). **0 verify-able (정직·예상대로 — PHANES 는 systems/SaaS, OUROBOROS 엔진 소비자, 폐형해 atom 부재; A2 ANIMA 와 동형, A3 DEMIURGE verify-native 와 정반대)**. 5 🟡 citation (OE-essential-for-ASI · OMNI · AutoML-Zero · Sakana-eval · Native-Reasoning). 가장 강한 대응 = AlphaEvolve(2511.02864 Tao+) = phanes hosted LLM-propose+verify+refine 루프 직접 analog. 미래 후보 = net-novelty-rate/saturation-round 폐형해(엔진-instrumentation lane). verdict=`.verdicts/arxiv-phanes-absorb/triage_a4.txt` · docs=`docs/a4-phanes-axis.md`.
- [ ] A5 — HEXA-LANG axis: compiler/number-theory 논문 흡수 → atlas/codegen 보강 (in-repo)
- [ ] A6 — cross-repo handoff 메커니즘 정립 (g60 INBOX) — 흡수 finding → 각 repo INBOX 분배 + ack 루프
- [ ] A7 — catalogue closure report + reuse edge (g67 NEXUS.tape) + 4-repo 흡수 ledger
- [ ] A8 — paper (paper_on_discovery: arxiv 흡수가 새 verified finding 을 낳은 경우만)

## 3 · 거버넌스 · 비범위
- verify 정본: `hexa verify` g5, 판정문 verbatim. LLM 자기판정 금지.
- naive 논문 dump 금지 — verify-gate 통과 또는 명시적 cross-repo handoff 만 흡수로 인정.
- arxiv = arxiv.org (open access). attribution = arxiv ID + 저자 + 제목 (atlas atom source 필드).
- 비범위: 논문 전문 재출판 · peer-review · paywalled 논문.
