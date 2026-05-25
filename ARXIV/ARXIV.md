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

> **진행 2026-05-26**: A1(POC, 12편) + **A2(ANIMA axis, 11편 흡수 · 6 anima LIFE H 핸드오프 g60)** DONE. verify-able 누적 0 (in-tree IIT primitive 부재 — V5 IIT 엔진 랜딩 후 verify-able-CANDIDATE 회수). 다음 = A3 DEMIURGE axis.

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
- [ ] A3 — DEMIURGE axis: 반물질 7공정 물리 논문 흡수 → ANTIMATTER verify atom 보강 (handoff to ~/core/demiurge)
- [ ] A4 — PHANES axis: autonomous-discovery/OUROBOROS 논문 흡수 → loop 알고리즘 (handoff to ~/core/phanes)
- [ ] A5 — HEXA-LANG axis: compiler/number-theory 논문 흡수 → atlas/codegen 보강 (in-repo)
- [ ] A6 — cross-repo handoff 메커니즘 정립 (g60 INBOX) — 흡수 finding → 각 repo INBOX 분배 + ack 루프
- [ ] A7 — catalogue closure report + reuse edge (g67 NEXUS.tape) + 4-repo 흡수 ledger
- [ ] A8 — paper (paper_on_discovery: arxiv 흡수가 새 verified finding 을 낳은 경우만)

## 3 · 거버넌스 · 비범위
- verify 정본: `hexa verify` g5, 판정문 verbatim. LLM 자기판정 금지.
- naive 논문 dump 금지 — verify-gate 통과 또는 명시적 cross-repo handoff 만 흡수로 인정.
- arxiv = arxiv.org (open access). attribution = arxiv ID + 저자 + 제목 (atlas atom source 필드).
- 비범위: 논문 전문 재출판 · peer-review · paywalled 논문.
