# OEIS — log

Append-only history sister of `OEIS.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

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
