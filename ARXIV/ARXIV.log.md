# ARXIV — log

Append-only history sister of `ARXIV.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

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
