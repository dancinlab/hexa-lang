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
- [x] O3 — 336 survivor per-hit verify (V2 compute): 8 🔵 direct (7 distinct theorem) / 41 🟡 citation / 287 🟠. 다음 = O4 (atlas auto-fold verified-만, 7 distinct).
  - **V7 mutual-feed (2026-05-26)**: VERIFY-KIT V7 의 `nth_prime`/`is_prime` (+catalan/factorial/bell/partition) 가 287 🟠 중 A000040 prime×67 hit 을 🔵 로 전환 가능케 함 (exact integer recompute 경로 신설). 검증: nth_prime 1 2/5 11/10 29/25 97/100 541 전부 🔵. n×190 은 trivial-identity(a(n)=n, fn 아님 → 비범위 유지). OEIS↔VERIFY-KIT mutual-feed 루프 실현 — proof: `.verdicts/verify-kit-combinatorial/v7.txt`.
- [x] O4 — atlas fold: 7 🔵 theorem (5 기존 present + OEIS attribution · 3 newly-folded). dedup vs 16K. sigma↔A000203·tau↔A000005·phi↔A000010·mu↔A008683 = @P 빌트인 present (중복 안 만듦) + sigma_0==tau alias. aliquot↔A001065·sigma_2↔A001157·sigma_3↔A001158 = atlas 부재 → OEIS-attributed @F fold (source+url+CC-BY-SA). 다음 = O5 (TECS-L F11 cross-link). **[VERIFY-KIT V6 자동화]** O4 가 손으로 fold 한 3개 @F 노드의 `source="OEIS Annnnnn"`+`url` 어트리뷰션은 이제 `hexa atlas register --from-verify <fn> <n> --source "OEIS Annnnnn" --url "https://oeis.org/Annnnnn"` 로 자동 생성됨 (VERIFY-KIT V6, `register --source`/`--url` 플래그). 향후 OEIS fold 는 hand-fold 대신 `--source`/`--url` 사용 — 노드 shape 동일(`verified-by` 와 `cite` 사이 `source =`/`url =`), `g_self_verify` 검증 cite 유지.
- [x] O5 — TECS-L F11 cross-link: 7 OEIS↔hexa provenance links → TECS-L cite + DOMAINS.tape reuse edge (g67). 4 @P 빌트인(sigma↔A000203·tau↔A000005·phi↔A000010·mu↔A008683) + 3 @F fold(aliquot↔A001065·sigma_2↔A001157·sigma_3↔A001158)이 TECS-L M1-M10/M4/F3 의 downstream cite 가 됨. cross-domain `@link TECS-L --reuses--> OEIS` 를 repo-root DOMAINS.tape connection graph 에 등록. docs `OEIS/docs/o5-tecs-crosslink.md` · ledger `.verdicts/oeis-tecs-crosslink/crosslink.txt`. docs+graph only (atlas fold 은 O4 소유). 다음 = O7 (catalogue closure report).
- [x] O6 — DLMF feasibility: 🔴 FALSIFIED (closed-negative). OEIS exact-integer hash-intersect 패턴은 DLMF 로 일반화 안 됨 — structurally incompatible (P1 bulk 수치 corpus 부재 + P3 hexa 고전 특수함수 0개, 2개 독립 fail). sampling-intersect 도 메커니즘 다르고 hexa 특수함수 라이브러리 부재로 차단. docs/o6-dlmf-feasibility.md.
- [x] O7 — catalogue closure report: 374K→1707→336→7 funnel + 78% coincidence-filter 측정. paper-gate: TRIGGER O8 — candidate (b) 78%-coincidence-rate 가 paper_significance 충족 (O1 pre-registered falsifier "K=10 prefix-match ⟹ sequence identity" + 374K real measurement + closed-negative "short-prefix-as-identity-test" ruled out @ 78.1%); candidates (a) A000926 anecdote + (c) sibling-locus(uniqueness 미증명) = SKIP (강제 paper 안 함). docs `OEIS/docs/o7-catalogue-closure.md` · `.verdicts/oeis-closure/closure_report.txt` · `CLAIMS.tape` slug=oeis-closure 🟢. 다음 = O8.
- [x] O8 — paper SHIPPED: oeis-prefix-collision-falsifier (78.1% closed-negative, g51 ≥10p + fal figure). OEIS 도메인 closure.

## 2 · 거버넌스

- catalogue mirror = atlas 의 핵심 fold 아니라 reference catalogue lane. fold scope = hexa-verify 가능한 것만.
- OEIS = CC-BY-SA. attribution 필수 (atlas atom 에 source="OEIS Annnnnn" + URL).
- naive dump 금지 (380K @C 무차별 = atlas 정체성 표류). 검증 통과만 fold.
- verify gate: `hexa verify --expr` (g5 rubric). 자체 LLM 판정 금지.

## 3 · 비범위

- conjectural sequence (formula unverified) — 🟠 deferred, 본 도메인 fold X.
- OEIS 외 catalogue (DLMF/MathWorld/arxiv) — sister 도메인 신설 후 진행 (O6 trigger).
- OEIS 전체 a(n) hexa fn 신설 — 비현실 (수만 fn). reuse 가능한 ~20-50 candidate fn 만.
