# ARXIV — log

Append-only history sister of `ARXIV.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

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
