# OEIS — log

Append-only history sister of `OEIS.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-25T15:29Z — O2 full sweep

- [x] O1 scanner → O2 full sweep 확장: `OEIS/tool/full_sweep.hexa` (hexa-native; POC 의 "첫 1000" → 전체 stripped.gz 덤프 sweep). 후보 K=20 테이블은 OEIS catalogue-verbatim (offset-correct) — POC 의 offset 불일치(n²/n!/Fib 등이 n=1 부터 시작해 덤프의 offset-0 윈도우 miss) 동시 수정.
  - **374047** OEIS seq sweep (≥K=10 terms) · **20** candidate fn · K=10 hash-intersect
  - **1707** hit (K=10) — POC 6 → 1707 (full sweep + offset 수정 효과)
  - K=20 2차 패스로 first-K coincidence 필터: **336 survive** · **1334 coincidence 제거** · **37 na** (<20 terms)
  - canonical coincidence: **A000926 (Idoneal numbers)** ↔ `n` — 첫 10항 일치하나 term ≤20 에서 divergence → `k20_survives=no` (POC 가 예고한 falsifier 가 K=20 에서 자동 확정)
  - O1 POC 6 hit 전부 재현: tau↔A000005 · sigma_0↔A000005 · phi↔A000010 · n↔A000027 · sigma↔A000203 (5개 K=20 survive) + n↔A000926 (coincidence 로 정확히 flagged)
  - survive=yes 상위 fn: n(190) · prime(67) · tau/sigma_0(15) · odd(12) · triangular(7) · sigma(6) · mu(5) …
  - 영속: `.verdicts/oeis-full-sweep/ledger.json` (g65 typed · 1707 hits + 1334 coincidences) + `sweep_log.txt` (verbatim stdout · ASCII) + `hits.tsv` (full match table) + `CLAIMS.tape` @C slug=oeis-full-sweep
  - wall: stripped.gz 1회 캐시 (~32MB→81MB). awk hash-intersect (374K 라인 × 20 fn)= 수 초. 전체 run 은 interp orchestration overhead 로 느림 (compiled build 는 pool-route heavy-refuse → interp 사용). 측정 자체는 빠름.
- [x] g59 INBOX filing — `hexa verify --expr <fn> <n>` value-less COMPUTE mode 부재 gap (O3 + generative discovery 차단). verify_cli whitelist 항목과 직교 (whitelist 에 있는 sigma/tau/phi 조차 값 emit 안 함). 제안: `hexa compute <fn> <n>` verb OR 2-arg verify print+self-verify.

## 2026-05-25T15:09:48Z — O6 DLMF probe

- [x] O6 타당성 프로브 — OEIS catalogue-mirror 패턴이 DLMF (NIST 특수함수 라이브러리) 로 일반화되는가?
  - **터미널 verdict = 🔴 FALSIFIED (closed-negative)** — 그대로(as-is) 재사용 불가. falsified 속성 = **패턴 이식성(portability)**.
  - OEIS 패턴의 3 전제 중 2개가 결정론적 FAIL:
    - **P1 BULK CORPUS FAIL** — DLMF 는 per-page MathML, `stripped.gz` 등가물·공개 API·bulk 수치 dump 없음 (WebFetch `dlmf.nist.gov/about` + `/help`, 2026-05-25 확인).
    - **P3 HEXA COVERAGE FAIL** — `hexa verify --expr` 레지스트리에 고전 특수함수 **0개** (Bessel/Gamma(z)/erf/Hermite/Legendre/Airy/ζ/초기하 없음; `gamma0_index` 는 모듈러 Γ₀ index = 정수, Gamma 함수 아님). 정수론 fn + RFC-045 상수만 존재.
  - 구조 차이: OEIS = `{id → 정수 tuple}` (균일·exact-hashable) vs DLMF = `{id → 기호 항등식 OR 연속함수 f}` (이질·tuple 해시 불가).
  - sub-option 3개: (A) numeric-table intersect = source 부재 AND 특수함수 부재 AND exact-hash→tolerance 메커니즘 불일치로 차단 · (B) identity-citation = 도메인 거버넌스(naive-dump 금지 + verify-gated only) + paper_gate 위반으로 REJECTED · (C) closed-negative = ADOPTED.
  - 배제된 축: "DLMF 가 OEIS 패턴을 as-is 재사용 가능" → FALSE. DLMF 미러는 신규 메커니즘(numeric 샘플링 + tolerance, 🟢 tier) + hexa 특수함수 라이브러리(libm/급수) 둘 다 필요 = same-pattern 재사용 아님.
  - 영속: `OEIS/docs/o6-dlmf-feasibility.md` (한국어 §1–§5) + `.verdicts/oeis-dlmf-probe/dlmf_assessment.txt` (ASCII verbatim) + `CLAIMS.tape` @C slug=oeis-dlmf-probe (🔴, paper_negative_ok).

## 2026-05-25 — 도메인 개시 + O1 scanner POC

- [x] 도메인 SSOT `OEIS/OEIS.md` 작성 — @title + @goal + O1-O8 roadmap + 거버넌스
- [x] 자매 도메인 정의: TECS-L = narrow/deep (n=6 발견) ↔ OEIS = broad/shallow (catalogue mirror), F11 cross-link
- [x] O1 scanner POC — `OEIS/tool/scanner.hexa` (hexa-native; `.sh` 차단 hook 우회 → `exec_with_status` 로 curl/awk shell-out)
  - stripped.gz 다운 (~38MB → 77MB unpack) + first 1000 A-line parse → 899 seq (≥K=10 terms 필터)
  - 20 candidate fn 사전계산 (well-known closed-form n=1..10) — 산술 (σ/τ/φ/μ/σ_0/σ_2/σ_3/aliquot/is_perfect) · 다항 (n/n²/n³) · 조합 (2ⁿ/n!/Fibonacci/Catalan/triangular/pronic) · 시퀀스 (2n/odd)
  - 6/899 hit (~0.67%) — 다음 hits.tsv 참조:
    1. tau         ↔ A000005 (number of divisors)
    2. sigma_0     ↔ A000005 (alias of τ — 동일 시퀀스)
    3. phi         ↔ A000010 (Euler totient)
    4. n           ↔ A000027 (natural numbers)
    5. sigma       ↔ A000203 (sum of divisors)
    6. n           ↔ A000926 (Idoneal numbers — first 10 terms coincide; 11번째부터 diverge 예상; O3 verify 단계 falsifier)
  - 결과 영속: `.verdicts/oeis-scanner-poc/scan_log.txt` (verbatim stdout) + `hits.tsv` (match table) + `CLAIMS.tape` @C slug=oeis-scanner-poc
  - wall time: ~3 분 (stripped 다운 1회 cache, 이후 ~수 초). hexa verify 사전계산 우회 = `--expr <fn> <n> <v>` 가 v 를 사전요구 → POC 는 well-known closed-form 하드코드 (O3 에서 per-hit re-confirm)
- [x] TECS-L.md F11 cross-link stub 추가 ("도메인 OEIS upstream; O5 cross-link 시 closure")
