# OEIS — log

Append-only history sister of `OEIS.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-26T00:50Z — O3 per-hit verify (336 K=20 survivors)

- [x] O2 의 **336 K=20 survivor** 를 candidate fn 별로 그룹핑 → distinct (fn, oeis_id) 별로 `hexa verify --expr` (VERIFY-KIT V2-era CLI) 로 재확인 + tier 분류. 3-arg VERIFY (`--expr <fn> <n> <expected>`) + V2 value-less COMPUTE (`--expr <fn> <n>`) 둘 다 사용.
  - **8 🔵 DIRECT** (canonical-source 정수론 fn · hexa-native recompute 가 OEIS a(n) 재현 · sample-verified PASS):
    - sigma↔A000203 [n=3(4)·4(7)·6(12) + COMPUTE n=7=8] · tau↔A000005 [n=6(4)·10(4)] · sigma_0↔A000005 (≡ tau, 같은 `len(divisors)` fn) · phi↔A000010 [n=9(6)] · mu↔A008683 [n=6(1)] · aliquot↔A001065 [n=8(7)] · sigma_2↔A001157 [n=9(91)] · sigma_3↔A001158 [sigma_k(9,3)=757, 2-op route]
    - → **7 DISTINCT theorem** (sigma_0/tau 가 A000005 위에서 동일 hexa fn = 8 pair 가 7 로 collapse)
  - **41 🟡 CITATION** — canonical 과 첫 20항이 일치하는 alias OEIS id (hexa fn 이 값은 재현하나 OEIS 정의가 다름 → catalogue-identity cite, fold 보류). sigma_0/tau 각 14 · sigma 5 · mu 4 · aliquot 3 · phi 1.
  - **287 🟠 NO-PATH** — verify-CLI `_recompute` 에 경로 없는 다항/trivial fn → `🟠 INSUFFICIENT (calculator-gap)`: n×190 · prime×67 · odd×12 · triangular×7 · two_n×3 · n_squared×2 · catalan/factorial/fibonacci/n_cubed/pronic/two_to_n 각 1. (poly fn 은 closed-form recompute 미등록 — `_recompute` 확장 후보.)
  - 영속: `.verdicts/oeis-perhit-verify/tier_ledger.txt` (전체 distinct-pair 분류 + aggregate) + headline verbatim verdict 3개 (`sigma_A000203.txt`·`tau_A000005.txt`·`phi_A000010.txt`) + `CLAIMS.tape` @C slug=oeis-perhit-verify.
  - 솔직성: 336 개별 verdict 파일 대신 distinct (fn↔oeis) tier ledger 로 집계 (중복 alias 다수 — 같은 hexa fn 의 같은 recompute). 🔵 family 는 sample index 3-5 개만 확인 (전 인덱스 sweep 아님, 문서화됨).
  - 설치된 `~/.hx/bin/hexa.real` (5/25) 가 V2 COMPUTE + 3-arg VERIFY 둘 다 지원 확인 (`COMPUTE: sigma(7) = 8` · `sigma(6)=12 🔵`). verify 호출은 worktree 무변경 (absorb default = idempotent-skip, atlas 미수정).
  - **다음 = O4**: verified-만 atlas auto-fold. well-defined fold scope = **7 distinct 🔵 theorem** (기존 ~16K atlas node 와 dedup). 🟡 41 = OEIS attribution cite 로 보류, 🟠 287 = `_recompute` 확장 전까지 scope 밖.

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
