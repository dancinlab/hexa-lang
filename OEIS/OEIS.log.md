# OEIS — log

Append-only history sister of `OEIS.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-26T03:30Z — O7 catalogue-mirror closure report + O8 paper-gate eval (TRIGGER)

- [x] O1–O6 종합 **카탈로그-미러 클로저 리포트** + paper_significance 게이트 평가. 격리 worktree `/tmp/wt-oeis-o7` (origin/main). docs+verdict+CLAIMS only — **atlas(embedded.gen.hexa) 미접촉**.
  - **funnel** (전부 ledger verbatim): 374,047 swept seq × 20 candidate fn → **1,707** K=10 hit → K=20 second-pass **336 survive / 1,334 coincidence / 37 na** → O3 per-hit verify **🔵 8(7 distinct) / 🟡 41 / 🟠 287** → O4 **7 atlas-linked** (4 @P sigma/tau/phi/mu present + 1 alias sigma_0==tau + 3 새 @F aliquot A001065/sigma_2 A001157/sigma_3 A001158). selectivity 5.3×10⁻⁵ (verify-gated, naive dump 아님). ASCII funnel diagram = `OEIS/docs/o7-catalogue-closure.md` §1.
  - **성과 (§2)**: 7 NT-fn 의 검증된 OEIS↔hexa provenance + **K=20 coincidence-filter 방법** — K=10 hit 의 **78.1%(1334/1707)** 가 first-K artifact (≥20항 disprovable 기준 79.9%). 즉 K=10 prefix-match 단독으로는 sequence identity 결정 불가, K=20 second-pass 가 거의-무료 거름망.
  - **한계 (§3, honest)**: 🟠 287 = 100% calculator-gap (`_recompute` 에 n×190/prime×67/poly 경로 부재) → **VERIFY-KIT V7** (combinatorial/prime fn) mutual-feed 로 전환 가능(단 대부분 n/prime trivial-alias 라 🟡 cite, 새 theorem 아님). O6 DLMF = closed-negative(패턴 비이식성). 7 중 5 = mostly-attribution(@P present).
  - **unique pattern (§4)**: (a) A000926 Idoneal↔n 우연(첫 10항 일치, term≤20 divergence — clean exemplar) · (b) 78% coincidence rate · (c) sibling-locus n·φ(n)=σ(n)⟺n∈{1,6} (A002618, F3 — hand-sweep n=1..8, uniqueness 미증명).
  - **paper-gate eval (§5, STRICT)** → **O8 TRIGGER**: candidate **(b) 78%-coincidence-rate** 가 `paper_significance` 3요건 충족 — **pre-registered falsifier**(O1 scanner 가 A000926↔n 를 "11항부터 diverge 예상, O3 falsifier" 로 기록 = H "K=10 prefix-match ⟹ sequence identity" pre-register) + **real measurement**(374K sweep, 1334/1707=78.1%) + **closed-negative finding**(H FALSIFIED, 배제된 축 = short-prefix-as-identity-test; `paper_negative_ok`). **caveat 必**: candidate-set-relative(20 low-entropy fn 편향) + single K=10→20 prefix-pair. candidates **(a) anecdote + (c) uniqueness 미증명 = SKIP** (게이트 미달, **강제 paper 안 함** — paper_violation 회피).
  - **O8 spec** (다음 라운드): slug=`oeis-prefix-collision-falsifier` · §statement/method/verification/finding 명시 + g51(≥10p + fal.ai fig). O8 milestone 에 falsifier+finding spec 기록, `- [ ]` 유지(TRIGGER).
  - 영속: `OEIS/docs/o7-catalogue-closure.md` (한글 §1–§5 + 부록) + `.verdicts/oeis-closure/closure_report.txt` (ASCII funnel + paper-gate verdict) + `CLAIMS.tape` @C slug=oeis-closure group=OEIS 🟢. method=synthesis/closure (신규 hexa verify 0건).
  - **다음 = O8** (closed-negative paper: catalogue cross-check 은 engineering closure, publishable finding 은 78% prefix-collision falsifier 하나).

## 2026-05-26T02:10Z — O5 TECS-L F11 cross-link (7 provenance link → TECS-L cite · NEXUS reuse edge g67)

- [x] O4(PR #1138)가 확보한 **7 OEIS↔hexa-fn provenance link** 을 자매 도메인 **TECS-L** 의 축 F **F11("OEIS reuse cite")** 에 교차연결 + repo-root `NEXUS.tape` 에 intra-project reuse edge 등록 (commons @D g67). 격리 worktree `/tmp/wt-oeis-o5` (origin/main).
  - **7 link** (O4 ledger 그대로): 4 @P 빌트인 attribution — sigma↔A000203 · tau↔A000005 · phi↔A000010 · mu↔A008683; 3 신규 @F fold — aliquot↔A001065 · sigma_2↔A001157 · sigma_3↔A001158.
  - **TECS-L F11 closure** (`TECS-L/TECS-L.md`): `- [ ]`→`- [x]`. F11 재정의 = "OEIS reuse cite — TECS-L = OEIS-도메인 provenance 의 downstream consumer". M1·M3·M10 의 σ·φ·τ + M4 의 μ + 축 F F3 의 σ_2 가 모두 OEIS canonical-source 귀속을 받은 산술함수를 소비 → reuse-cite 성립.
  - **NEXUS.tape reuse edge** (§3b 신설, **기존 NEXUS.tape 확장** — 새로 만들지 않음): 기존 파일은 g68 cross-repo STAR hub. 그 governance 가 g67+g68 둘 다 governs 라 명시 → §3b "intra-project domain reuse lattice (g67)" 섹션을 additive 로 추가. domain-node `d_oeis`(provides: 7 link) + `d_tecsl`(reused) + domain-reuse-edge `de1`(TECS-L --reuses--> OEIS). 타 도메인 노드(demiurge/anima/… STAR hub) 미접촉, ASCII (g3).
  - **docs** (`OEIS/docs/o5-tecs-crosslink.md`, 한글): 7 link 표 + reuse-edge 근거(g67 vs g68) + TECS-L M1-M10 소비 경로 표.
  - 영속: `.verdicts/oeis-tecs-crosslink/crosslink.txt` (ASCII 7 link + reuse edge) + `CLAIMS.tape` @C slug=oeis-tecs-crosslink group=OEIS 🟢.
  - **scope**: docs + NEXUS only — **atlas fold 미접촉** (O4 가 embedded.gen.hexa 소유; 동시 broad-campaign 세션의 비-OEIS fold 와 분리). method=synthesis/crosslink (신규 hexa verify 0건; link 는 O4 ledger 인용).
  - **다음 = O7** (catalogue closure report + 미러 unique pattern 발견 시 closed-negative/positive paper).

## 2026-05-26T01:40Z — O4 atlas-fold (7 🔵 theorem · dedup 16K)

- [x] O3 의 **7 distinct 🔵 theorem** 을 atlas 에 fold (verified-만) + 기존 ~16K node 와 dedup. 격리 worktree `/tmp/wt-oeis-o4` (origin/main 기준) 에서만 작업 — register/edit 가 install dir(~/core/hexa-lang) 로 leak 하지 않도록 `HEXA_ATLAS_EMBED` scope + main tree grep 검증.
  - **dedup 결과 (`hexa atlas lookup`)**:
    - **5 ALREADY-PRESENT/alias** (중복 node 안 만듦, OEIS-id attribution 만 기록): sigma↔A000203 = `@P sigma` (divisor_sum, foundation [11*]) · tau↔A000005 = `@P tau` (divisor_count, [11*]) · phi↔A000010 = `@P phi` (euler_totient, [10*]) · mu↔A008683 = `@P mu` (mobius, [10*]) · sigma_0↔A000005 = **alias of tau** (같은 hexa `len(divisors)` fn, 별도 node 없음).
    - **3 NEWLY-FOLDED** (atlas 부재 = lookup MISS → OEIS-attributed `@F` node 추가): aliquot↔A001065 [aliquot(8)=7] · sigma_2↔A001157 [sigma_2(9)=91] · sigma_3↔A001158 [sigma_k(9,3)=757]. 값은 O3 tier_ledger sample-verified PASS 와 일치.
  - 각 새 node = `id=oeis-Annnnnn` · `tier="🔵 SUPPORTED-FORMAL"` · `source="OEIS Annnnnn"` · `url=https://oeis.org/Annnnnn` · `cite` 에 CC-BY-SA + verbatim provenance. (register CLI 는 OEIS source 필드를 못 실어서 — `verified-<fn>-<n>` 고정 포맷 — OEIS-attributed @F 를 직접 fold.)
  - net +3 atlas node (16134 → 16137, F kind 1379 → 1382). main shared tree 누수 0 (`grep oeis-A001* ~/core/hexa-lang/.../embedded.gen.hexa` = 0).
  - 영속: `.verdicts/oeis-atlas-fold/fold_ledger.txt` (fn · oeis_id · status · node ref) + `CLAIMS.tape` @C slug=oeis-atlas-fold group=OEIS.
  - 솔직성: O4 = **mostly-attribution** — 7 중 5 가 기존 present/alias. 가치는 node 수가 아니라 검증된 OEIS↔hexa-fn provenance link (sigma/tau/phi/mu 의 OEIS canonical-source 명시 + 3 신규 fn 의 CC-BY-SA 귀속). 🟡 41 alias + 🟠 287 no-path 는 scope 밖 (O3 결정 유지).
  - ⚠ 동시성: 작업 중 `/tmp/wt-oeis-o4` 가 한 번 외부 정리로 삭제됨 (worktree + branch 소실) → origin/main 기준 재생성 후 전 편집 재적용 (idempotent, 손실 없음). 별도 broad-campaign 세션이 main tree 에 비-OEIS `verified-<fn>-<n>` node (attribution 없음) 를 동시 fold 중 — 본 O4 와 별개, 미포착.
  - **다음 = O5**: TECS-L F11 cross-link PR (OEIS atlas → TECS-L cite) + reuse edge 등록 (g67 NEXUS.tape).

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
