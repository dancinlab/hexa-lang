# OEIS — 정수 sequence 카탈로그 미러 (도메인 SSOT)

@title: 📚 OEIS — 카탈로그 미러 ("산술 도서관 자동 분류")
@goal: OEIS 380K+ sequence 의 첫 K 항을 hexa-native 산술 fn precompute 와 hash-intersect → match 만 hexa verify 재확인 → atlas 에 자동 fold. catalogue mirror lane 신설 (TECS-L 의 NOVEL upstream).

> 자매 도메인:
> - **TECS-L** (n=6 perfect-number 발견 엔진, narrow/deep) — F11 = OEIS reuse cite (downstream)
> - **OEIS** (catalogue mirror, broad/shallow) — TECS-L 의 upstream provider

## 0 · 한 문단 상태 (2026-05-25 개시)

OEIS (Online Encyclopedia of Integer Sequences) 의 stripped.gz bulk dump (~14MB) 을
local 으로 다운 + parse → hexa 산술 fn (σ/τ/φ/μ/σ_k/aliquot/…) 의 첫 K 항
precompute → hash 교집합 으로 match candidate 선별 → 각 candidate 의 a(n) hexa verify
재확인 → atlas 에 fold (slug=oeis-Annnnnn). naive 380K×50fn×K naive 비교 (≈11일) 대신
precompute + hash 교집합 (O(N), 수 초) 으로 wall-time 절감. fold scope = hexa-verify
가능한 것 만 (자체 정의 catalogue mirror = X, hexa atlas integrity 보존).

## 1 · 로드맵

- [x] O1 — scanner POC: 6/899 seq match (0.67%). 20 candidate fn precompute + hash-intersect K=10. 다음 = O2 (full 380K sweep).
- [x] O2 — full 380K sweep: 1707 hit (K=10), 1334 coincidence filtered at K=20 (e.g. A000926 Idoneal vs `n`; 336 survive · 37 na). ledger.json + CLAIMS. 다음 = O3 (per-hit verify — INBOX verify-compute gap filed).
- [ ] O3 — match 별 hexa verify 재확인 (~수백~수천 hit 예상) + 🔵/🟡 tier 분류
- [ ] O4 — atlas auto-fold (verified 만) + dedup against existing atlas 16K nodes
- [ ] O5 — TECS-L F11 cross-link PR (OEIS atlas → TECS-L cite) + reuse edge 등록 (g67 NEXUS.tape)
- [ ] O6 — DLMF 카탈로그 family 확장 시도 (특수함수 ID + 항등식) — same 패턴 재사용
- [ ] O7 — catalogue closure report + 미러 unique pattern 발견 시 closed-negative / closed-positive paper
- [ ] O8 — paper (paper_on_discovery: catalogue mirror 가 새 identity 를 surface 한 경우만)

## 2 · 거버넌스

- catalogue mirror = atlas 의 핵심 fold 아니라 reference catalogue lane. fold scope = hexa-verify 가능한 것만.
- OEIS = CC-BY-SA. attribution 필수 (atlas atom 에 source="OEIS Annnnnn" + URL).
- naive dump 금지 (380K @C 무차별 = atlas 정체성 표류). 검증 통과만 fold.
- verify gate: `hexa verify --expr` (g5 rubric). 자체 LLM 판정 금지.

## 3 · 비범위

- conjectural sequence (formula unverified) — 🟠 deferred, 본 도메인 fold X.
- OEIS 외 catalogue (DLMF/MathWorld/arxiv) — sister 도메인 신설 후 진행 (O6 trigger).
- OEIS 전체 a(n) hexa fn 신설 — 비현실 (수만 fn). reuse 가능한 ~20-50 candidate fn 만.
