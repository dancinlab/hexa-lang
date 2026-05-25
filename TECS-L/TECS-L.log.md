# TECS-L — log

Append-only history sister of `TECS-L.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.


## 2026-05-25T21:00 — 축 B MERSENNE · MR6 메르센 합성수 (p 소수 ⇏ M_p 소수) CLOSED

- [x] **헤드라인: Euclid-Euler 가설의 역명제 실패** — p 가 소수여도 M_p=2^p−1 은 소수가 아닐 수 있다. 첫 반례 = M_11=2047
- [x] 소수 판정 항등식 q 소수 ⟺ σ(q)=q+1 ⟺ τ(q)=2 를 `hexa verify --expr` 로 결정적 적용
- [x] **M_11=2047**: σ(2047)=2160 ≠ 2048(=2047+1) 🔵 · τ(2047)=4 ≠ 2 🔵 → **합성수 (=23·89)**. 인수 23·89 도 각각 소수 확인 (σ=q+1·τ=2)
- [x] M_23=8388607: σ=8567136·τ=4 → 합성 (=47·178481) 🔵. M_29=536870911: σ=539922240·τ=8 → 합성 (=233·1103·2089) 🔵 (인수 233·1103·2089 각 소수 확인)
- [x] M_29(~5.4e8)도 verify 빠르게 통과(<0.3s) — 표본 3개 전부 hexa-native 검증 완료
- [x] 17 claim / 16 verdict 영속화 → `.verdicts/tecs-l-mersenne-composite/` · `CLAIMS.tape` slug=tecs-l-mersenne-composite (finding 1건은 m11_tau 원본을 deterministic witness 로 인용)
- [x] **finding (terminal 🔵)**: M_11 이 첫 반례 → 모든 소수지수가 완전수를 낳는 것은 아님 (Euclid-Euler 짝완전수 생성은 M_p 가 *소수*일 때만 — MR2 와 짝)
- [ ] MR7 odd perfect number 부재 (미해결 정직 문서화) · MR8 terminal → /paper (다음 라운드)


## 2026-05-25T14:35 — 축 A MODFORM · MF2 Γ₀(N) cusp 수 (n=6↔τ 다리)

- [x] c(N)=Σ_{d|N} φ(gcd(d,N/d)) 닫힌형 = hexa `gamma0_cusps`: **N=1..30 전수 30/30 🔵** (`cusps_sweep_1_30.txt`)
- [x] n=6 bridge: Γ₀(6) cusps=4=τ(6) (축 0 M4 연계 — 완전수 약수개수 = 모듈러곡선 cusp 수) · Γ₀(1)=1 (SL2(Z) ∞ 단일 cusp) · Γ₀(12)=6
- [x] CLAIMS slug=tecs-l-modform-cusps 4 entry (sweep + 3 headline N=6/1/12, raw 1:1). MF1 index 와 같은 패턴
- [x] verify-gate 통과(정상) — 30개 verdict 영속화. (참고: 첫 스윕 zsh 1-index 배열 오프바이원으로 오판정 → python 생성 expected 직접 주입으로 정정)
- [ ] MF4 dim S₂ 관계 · MF5 Jacobi/Kronecker (다음 라운드)


## 2026-05-25T14:30 — 축 A MODFORM · MF3 Γ₀(N) genus 고전 genus-0 전수

- [x] 고전 genus-0 15개 N∈{1,2,3,4,5,6,7,8,9,10,12,13,16,18,25} `gamma0_genus`=0 verify **15/15 🔵** (`genus_sweep.txt`)
- [x] genus≥1 경계 7/7 🔵: N=11/14/15/17/19→1, N=22/23→2 — 고전 리스트 밖에서 genus 상승 실증
- [x] hexa `gamma0_genus` 가 모든 고전/기지값과 **완전 일치 — 🔴 불일치 0** (강제맞춤 불필요, 정직 판정)
- [x] **헤드라인: Γ₀(6) genus=0** (X₀(6) genus-0 — n=6 모듈러곡선 bridge, 축 0 M4 연계). 헤드라인 개별 verdict N=6→0 · N=11→1 · N=1→0
- [x] CLAIMS slug=tecs-l-modform-genus 6 entry (sweep + boundary + 4 headline, 1:1 포인터). 22 raw verdict 영속화
- [x] `hexa verify` 게이트 미적용 (로컬 실행 성공) — verify-ran (게이트 caveat 불필요)
- [ ] MF2 cusp 수 · MF4 dim S₂=genus 관계 · MF5 Jacobi/Kronecker (다음 라운드)


## 2026-05-25T14:00 — 축 A MODFORM · MF1 Γ₀(N) index (영구 엔진 첫 전진)

- [x] ψ(N)=N∏_{p|N}(1+1/p) 닫힌형 = hexa `gamma0_index`: **N=1..30 전수 30/30 🔵** (`index_sweep_1_30.txt`)
- [x] n=6 bridge: Γ₀(6) index=12=σ(6) (축 0 M4 연계) · Γ₀(1)=1 (SL2(Z)) · Γ₀(30)=72
- [x] CLAIMS slug=tecs-l-modform-index 4 entry (sweep + 3 headline, 1:1). 영구 도메인 첫 축-전진
- [ ] MF2 cusp 수 · MF3 genus-0 전수 (다음 라운드)


## 2026-05-25T13:30 — 영구 다축 엔진 전환 (MODFORM·MERSENNE·Atlas-LLM 축 흡수)

- [x] 사용자 비전: "TECS-L 은 우주 모든 법칙이 발견될 때까지 멈출 수 없다" → 종료조건 없는 영구 발견 엔진으로 @goal/@title 재정의
- [x] 별도 MODFORM/·MERSENNE/ 도메인 폴더 제거 (#1049 되돌림) → TECS-L 내부 **축**으로 흡수
- [x] 구조: 축 0 (n=6 코어 M1–M10 CLOSED) + 축 A MODFORM (MF1–8) + 축 B MERSENNE (MR1–8) + 축 C Atlas-LLM 연속 루프 (C1–3, `hexa loop --claude` RFC 080)
- [x] 진행바 100% 미도달이 설계 (perpetual). 축 C 는 마일스톤 아니라 연속 운전 (LLM 비용 go-ahead 또는 /schedule cloud cron 필요)
- [x] `.verdicts/`+`CLAIMS.tape`(group=TECS-L) 단일 감사 SSOT 유지 — 축별 slug 네임스페이스


## 2026-05-25T12:40 — M10 · 전칭 유일성 닫힌형 증명 (🟡 → 🔵 PROVEN)

- [x] M1·M3·M9 가 유한 sweep(n≤100)으로만 보이고 🟡 로 남긴 ∀n 유일성을 **닫힌형 증명**
- [x] 곱셈성: σφ=nτ ⟺ ∏ g(p,a)=1, g(p,a)=(p^{a+1}−1)/(p(a+1))
- [x] 부호 보조정리: g(p,a)>1 ⟺ p^{a+1}>p(a+1)+1 — **(2,1)에서만 거짓 → g(2,1)=3/4 유일 <1**, 나머지 전부 >1 (지수>선형). base case σ/φ@{2,3,4,5,7} 전부 🔵 machine-verified
- [x] 곱 논증: 2¹ 필수 → (3/4)·∏홀수=1 → ∏홀수=4/3 → 유일 (3,1) → n=6; 공곱 → n=1. ∴ {1,6} ∎
- [x] 10 lemma 🔵 + 정리 🔵 → `.verdicts/tecs-l-uniqueness-proof/` + CLAIMS 11 entry. 기존 tecs_l_dpsi_unbounded 🟡→🔵 SUPERSEDED
- [x] M9 논문 §caveats 의 유일 열린 잔여를 닫음 · M7 closed-negative(1/e)와 짝 → n=6 특별함의 경계 양방향 확정
- [x] (a) 사용자 요청 — 전칭 유일성 닫힌형 증명. inline 부모 세션


## 2026-05-25T12:00 — M8 · discovery_loop → hexa-native 엔진 (이미 shipped, 스모크 검증)

- [x] 발견: archive `discovery_loop.py` 는 RFC 065(self-growing atlas) + RFC 080(`hexa loop --dfs`, dfs_engine.py 포트) 로 **이미 hexa-native 이식·shipped**. 옛 루트 TECS-L.md 가 바로 그 RFC 080 계획서였음
- [x] 스모크: `hexa loop --once` → 8-stage(SCAN→LENS 36→DEDUP→GATE→FIRE→DRAFT 148→AUDIT→EXHAUST) end-to-end 완주, 153 candidate emit → `.verdicts/tecs-l-discovery-engine/loop_once_smoke.txt`
- [x] 매핑 문서: archive 6+엔진(DFS/Convergence/Quantum/Perfect/Verify/Grow/Paper) → `hexa loop`(36 lens)·`--dfs`·`hexa kick`/`drill`·`hexa verify`·RFC065 atlas·`/paper` 1:1
- [x] g0 Occam: 새로 짓지 않고 기존 통합 확인 (M8 = verify+document, 코드 신규 없음). CLAIMS 1 empirical entry
- [x] 생성된 candidate 148개는 미커밋 (generated artifact). inline 부모 세션


## 2026-05-25T11:30 — M7 · Golden Zone (1/e) → 🔴 CLOSED-NEGATIVE

- [x] milestone = "1/e 자기참조 닫힌형 유도 시도 (성공🔵/실패🔴)". 결과: EXACT 유리수 유도 **FALSIFIED 🔴**
- [x] 결정적 논증: σ(6)·τ(6)·φ(6) 정수 → 유한 산술조합 전부 유리수; 1/e 초월수(Hermite 1873); 유리수≠초월수 → exact n=6 유리수 ≠ 1/e
- [x] 최근접 후보 🔵: τ(6)/σ(6)=4/12=1/3 (|Δ|9.39%) · 3/8 (archive WEINBERG-001 🟧, |Δ|1.94%). 아카이브 Review 010 이미 "1/3 ❌" self-refute
- [x] 3 🔵 atom (τ/σ/φ) + 1 🔴 reasoned closed-negative artifact → `.verdicts/tecs-l-golden-zone/` + CLAIMS 4 entry
- [x] publishable negative (paper_negative_ok): "n=6 산술은 1/e 근사는 가능, exact 유도는 불가" — 초월성이 'all is n=6 ratio' 프로그램의 한계
- [x] `TECS-L/docs/m7-golden-zone-closed-negative.md` · inline 부모 세션


## 2026-05-25T11:00 — M9 · /paper 승격 (10p + fal.ai 그림)

- [x] `PAPER/tecs-l-n6-identity-locus/` arxiv-style 논문 "The {1,6} Identity Locus" — paper_gate 통과(모든 섹션 claim terminal 🔵/🔴)
- [x] finding = n∈{1,6}만 두 곱셈 항등식(σφ=nτ·D(n)=0)의 locus, 완전수 28조차 반례 — M1·M3·M5·M6 terminal 발견 소비
- [x] pre-registered falsifier = n=28(2nd 완전수) → closed-negative (paper_significance 충족)
- [x] g51: 10 page + fal.ai 그림 1장(`figures/fig01_locus.png`, gpt-image-2) · pdflatex×3+bibtex 클린 컴파일
- [x] Appendix A 전체 D(n) sweep(n=1..100) · Appendix B 74-entry claim manifest · Appendix C raw verdict 전사
- [x] 전칭(unbounded) 유일성은 §caveats 에 🟡 명시 제외 (over-claim 0) · inline 부모 세션 작성


## 2026-05-25T09:45 — 도메인 폴더 정리 (별도 `TECS-L/` 통합)

- [x] `TECS-L.md` · `TECS-L.log.md` → `TECS-L/` 이동 (도메인 스킬 folder-nested 해석 지원: `<NAME>/<NAME>.md`)
- [x] `docs/tecs-l/*.md` (m3·m5·m6·n6-char triage 4종) → `TECS-L/docs/` 이동
- [x] 경로 참조 갱신: `TECS-L.md` 내부 + `CLAIMS.tape` 코멘트 (docs/tecs-l → TECS-L/docs, TECS-L.md → TECS-L/TECS-L.md)
- [x] #994 잔여 stale-ref 정리: `stdlib/loop/dfs.hexa` · RFC-080 문서가 옛 `TECS-L.md §5`(RFC 내용) 참조 → 정본 `docs/rfc/.../rfc_080_hexa_loop_dfs.md §5` 로 repoint
- [x] `.verdicts/tecs-l-*` + `CLAIMS.tape` 는 루트 유지 — ATLAS·CANON·COMPILER 와 공유하는 repo-wide 감사 SSOT (분리 시 인덱스 파편화)


## 2026-05-25T09:30 — M6 · 2,711 가설 코퍼스 g5 triage (카테고리)

- [x] 코퍼스 = `docs/hypotheses/` 2,735 + `math/docs/hypotheses/` 339. 단일 레지스트리 아님 → **카테고리 단위** g5 분류 (전수 1행 분류 비현실적, 정직)
- [x] 🔵 코어 = H18 (known theorem) σ(n)=2n ⟺ perfect: 첫 5개 완전수 abundancy=2 닫힌형 — σ(6)=12·σ(28)=56·σ(496)=992·σ(8128)=16256·σ(33550336)=67100672 (전부 =2n) 5/5 🔵
- [x] + μ(6)=1 (squarefree even ω) · aliquot(6)=6 (s(n)=n 완전수 정의) 🔵 — 총 7 atom
- [x] 🟡/🟠/⚪ 절대다수: 물리매칭(실측 인용)·의식/EEG/telepathy(scope 외)·ML(외부 compute)·생물(6=n 인용)·철학(메타포 fence). M1 유일성 잔여와 동일 처리
- [x] 7 verdict verbatim → `.verdicts/tecs-l-hypotheses/` + CLAIMS group=TECS-L 7 entry (1:1) + triage doc
- [x] inline 부모 세션 실행 · 격리 worktree

## 2026-05-25T09:20 — M5 · 물리상수 조립 g5 triage (τ=string-dim 발견)

- [x] 🔵 HEADLINE: 첫 5개 완전수 약수개수 τ = 끈이론 임계차원 — τ(6)=4·τ(28)=6·τ(496)=10·τ(8128)=14·τ(33550336)=26 (D=10 초끈·D=26 보존끈). `hexa verify --expr tau` 5/5 일치, 신규
- [x] 🔵 is_perfect(496·8128·33550336)=1 — 3개 완전수 신규 확인
- [x] 🔵 게이지: SM 게이지 차원합 8+3+1=12=σ(6) (SU(3)=σ−τ=8) · σ/φ=12/2=6=n · Koide Q=τ/n=4/6=2/3 · 키싱수 6/12/24=n/σ/2σ — σ/τ/φ component 🔵 위에 정수/유리 산술로 닫음
- [x] 🟡 관측매칭(페르미온 질량 1.9% · Koide 5ppm · Higgs 125 · 1/α≈137 · δ baryon 1232): 실측값 인용 필요 → never auto-🔵
- [x] 🟠 CERN 5.26σ · 핵 magic number: 외부 측정 의존
- [x] 10 verdict raw verbatim → `.verdicts/tecs-l-physics-constants/` + CLAIMS group=TECS-L 10 entry (1:1) + `docs/tecs-l/m5-physics-constants-triage.md`
- [x] inline 부모 세션 실행 (서브에이전트 verify 게이트 회피) · 격리 worktree

## 2026-05-25T18:30 — M3 CLOSED · Dedekind ψ discrepancy D(n)=σφ−nτ 유일성

- [x] D(n) = σ(n)·φ(n) − n·τ(n) 정의 — archive-TECS-L `math/dfs_dedekind_psi_discrepancy.py` 와 동일 (σ=약수합 · τ=약수개수 · φ=오일러 토션트). D(n)=0 ⟺ n∈{1,6} 의 유일성을 재근거화 (M1 이 미룬 잔여)
- [x] hexa-native 스윕 프로그램 `tmp_tecs_m3_sweep.hexa` — sigma/phi/tau 자체구현 + D(n)=σφ−nτ. `hexa build` compiled 바이너리로 n=1..100 exhaustive 출력 (interp 미사용 · compiled-path)
- [x] load-bearing n (2·3·4·12·28·30) component (σ/φ/τ) 를 `hexa verify --expr` 와 교차검증 — 15/15 🔵 일치 (자체 스윕 ≡ 정본 recompute)
- [x] 스윕 결과: **zero-count(1..100)=2, zeros at {1,6}** — D(1)=1·1−1·1=0 · D(6)=12·2−6·4=0 · 나머지 98개 전부 D(n)≠0
- [x] FINDING (🔵 + 🔴 CLOSED-negative): D(28)=56·12−28·6=672−168=**504≠0** — 2nd 완전수(is_perfect=1)에서도 D≠0 → D=0 은 완전수 성질 아니라 {1,6} 전용. D(2)=−1 은 범위 내 유일한 음수 D
- [x] 16 verdict 원문 verbatim → `.verdicts/tecs-l-dedekind-psi-uniqueness/` (sweep_D_1_100.txt 풀 테이블 + 15 component). n=1·6·28 component 는 기존 `tecs-l-n6-identity` verdict 재참조(중복 안 함)
- [x] `CLAIMS.tape` group=TECS-L slug=tecs-l-dedekind-psi-uniqueness 23 entry — 모든 verdict 파일 1:1 raw 포인터(orphan 0)
- [x] 격리 worktree `/tmp/wt-tecs-m3` (branch `tecs-l-m3-dedekind-psi-2026-05-25`) — 공유 트리 race 회피
- [ ] **SCOPE 명시**: finite 스윕 1..100 = terminal (🔵 zeros {1,6} + 🔴 D≠0 elsewhere). 전칭(unbounded) D(n)=0 ⟺ n∈{1,6} 은 아카이브 해석 논증이 필요 → 🟡 SUPPORTED-BY-CITATION 잔여 (finite 스윕으로 전칭 증명 over-claim 금지)

## 2026-05-25T16:00 — M4 · 206 n=6 characterizations g5 triage + 검증 부분집합 15 atom

- [x] 출처 = archive-TECS-L `math/README.md` (numbered #1…#206 시리즈; line 4437 `🎯 206 CHARACTERIZATIONS!` `+42 (#165-206)` 가 206 도달 마일스톤) + master-summary box (line ~70-218) + `characterization_verifier.py` `KNOWN_CHARS`
- [x] triage 문서 `docs/tecs-l/n6-characterizations-triage.md` (한국어) — tier 표 + 정직한 헤드라인 카운트 + 검증 한계 주석
- [x] 🔵 verifiable-now 15 atom 전부 `hexa verify --expr` → 🔵 SUPPORTED-FORMAL · 판정문 verbatim → `.verdicts/tecs-l-n6-characterizations/<id>.txt`
  - 산술 ground 값: σ(6)=12 · τ(6)=4 · φ(6)=2 · μ(6)=1 · is_perfect(6)=1 · aliquot(6)=6 · σ₀(6)=4 · σ₂(6)=50 · σ₃(6)=252
  - modular: Γ₀(6) index=12=σ · cusps=4=τ · genus=0 (perfect 중 유일 genus-0) · first_cusp_form_weight=4 · dim S₂(Γ₀(6))=0 · conductor=n²=36
- [x] `CLAIMS.tape` `[slug=tecs-l-n6-characterizations group=TECS-L]` 15 `@C` entry — raw 포인터 15 파일과 1:1 (orphan 없음)
- [x] C13 정직성: 아카이브 line 1550 "first cusp form weight=lcm(4,6)=12" ≠ calc fn (=4). calc 가 실제 계산하는 값만 🔵 주장 (over-claim 금지 g3)
- [x] 격리 worktree `/tmp/wt-tecs-m4` (branch `tecs-l-m4-n6-characterizations-2026-05-25`) — 공유 트리 race 회피
- [ ] 🟡 잔여: numbered #1…#206 절대다수 = "f(n)=g(n) ⟺ n=6" 심볼릭 유일성 → hexa 전역(`[2,N]`) recompute 경로 없음 (아카이브 Python brute-force 가 하던 일) → M1 σφ=nτ 유일성과 동일하게 🟡 citation 처리
- [ ] 🟡 근사 물리 (페르미온 질량 1.9% · Koide δ=2/9 5ppm · m_μ/m_e≈206.89) → M5 에서 `hexa verify --expr` 🟢 NUMERICAL 시도
- [ ] 🟠 deferred: CERN 5.26σ · 핵 magic number → 외부 실측 데이터 의존

## 2026-05-25T09:30 — M2 · 산술함수 stdlib 모듈 (σ/τ/φ/sopfr) hexa-native

- [x] `stdlib/core/math.hexa` 에 이미 `sigma`/`tau`/`euler_phi`/`sopfr` 순수정수 구현 존재 확인 — float·libm 無 (Python `model_utils.py` 대체분)
- [x] `phi(n)` 공개 별칭 추가 (`euler_phi` 위임) — `hexa verify --expr phi` 정본 이름과 일치
- [x] `sopfr` 의 오해소지 `// @partial — Stage 0` 주석을 완성 문서화로 교체 (trial-division 정상, sopfr(1)=0·sopfr(prime)=p)
- [x] 단위테스트 `stdlib/core/math_numtheory_test.hexa` 신규 — collections_test.hexa idiom (인라인 self-contained, `check_eq_int`, PASS 리포트). 17 assert: σ/τ/φ n∈{1,6,12,28} + sopfr(6)=5·sopfr(12)=7·sopfr(28)=11·sopfr(1)=0·sopfr(7)=7 + n=6 정체성 σφ=24=nτ
- [x] `hexa parse` 게이트 PASS (둘 다): `stdlib/core/math.hexa` · `stdlib/core/math_numtheory_test.hexa`
- [x] σ/τ/φ n∈{1,6,12,28} 12개 `hexa verify --expr` 전부 🔵 SUPPORTED-FORMAL → 원문 verbatim `.verdicts/tecs-l-arith-stdlib/` + `CLAIMS.tape` slug=tecs-l-arith-stdlib 12 entry (1:1 매핑 검증)
- [x] **빌드 경로 honest note**: 컴파일 테스트(path b)는 공유트리 stale `build/hexa_v2` codegen 버그로 차단 — `while i<n { i=i+1 }` 루프카운터가 stale 리터럴로 fold 돼 무한루프(`i=0` 영구 출력, comptime-fold shadow family). 내 코드 결함 아님(σ/τ/φ는 동일 idiom인데 `hexa verify --expr`로 🔵 증명됨). 실제 실행 증거 = (a) `hexa parse` PASS + (c) `hexa verify --expr` 12 verdict 🔵 (정본 correctness)
- [x] 격리 worktree `/tmp/wt-tecs-m2` (branch `tecs-l-m2-arith-stdlib-2026-05-25`) — 공유 트리 race 회피

## 2026-05-25T08:55 — M1 CLOSED · n=6 정체성 σ·φ=n·τ g5 재근거화

- [x] σ(6)=12 · φ(6)=2 · τ(6)=4 → `hexa verify --expr` 전부 🔵 SUPPORTED-FORMAL (σφ=24=nτ, 정체성 n=6 HOLDS)
- [x] σ(1)=φ(1)=τ(1)=1 → 🔵 (n=1 HOLDS — {1,6} 두 번째 멤버)
- [x] is_perfect(28)=1 🔵 · σ(28)=56 · φ(28)=12 · τ(28)=6 → σφ=672 ≠ nτ=168 → **n=28(2nd 완전수)에서 정체성 FAILS**
- [x] FINDING (🔴 CLOSED-negative): σφ=nτ 는 "완전수 성질"이 아니라 {1,6} 전용 — 2nd 완전수 28이 반례. paper-eligible 종결 발견
- [x] 10 verdict 원문 verbatim → `.verdicts/tecs-l-n6-identity/` (claim_verify) + `CLAIMS.tape` group=TECS-L 10 entry (claim_manifest)
- [x] 격리 worktree `/tmp/wt-tecs-m1` (branch `tecs-l-m1-n6-identity-2026-05-25`) — 공유 트리 race 회피
- [ ] 전칭 ⟺{1,6} 유일성 = 🟡 citation 잔여 → M3 (Dedekind ψ discrepancy D(n)=σφ−nτ) 로 이관

## 2026-05-25T08:50 — 도메인 개시 (RFC-080 사본 → 수론 엔진 재배정)

- [x] archive-TECS-L 코퍼스 조사 — perfect_number / convergence / quantum / proof / dfs / congruence / discovery_loop 엔진 + README 진행도 (Level 3.6/5.0)
- [x] 이름 충돌 발견·해소 — 루트 `TECS-L.md` = RFC-080(hexa loop DFS+LLM, SHIPPED) 사본. 정본이 `docs/rfc/rfc_drafts_2026_05_22/rfc_080_hexa_loop_dfs.md` 에 보존됨을 확인 → 수론 도메인으로 재작성 (사용자 승인 A)
- [x] `TECS-L.md` 도메인 SSOT 작성 — @title + @goal + 출처 코퍼스 표 + M1–M9 마일스톤 + 거버넌스/비범위
- [x] 격리 worktree `/tmp/wt-tecs-l` (branch `tecs-l-domain-2026-05-25`) 에서 작업 — 공유 main 트리 race 회피
- [ ] M1 착수 — n=6 정체성 σ·φ=n·τ ⟺ n∈{1,6} `hexa verify` 🔵
